#include <LUFA/Drivers/Peripheral/Serial.h>

#include "USaBuse.h"

void UART_Init(uint32_t baud);
void tlv_send_fc(bool enabled);
void tlv_send_uart(void);

/** Circular buffer to hold data from the serial port, plus underlying data buffer */
static RingBuffer_t USARTtoUC_Buffer;
static uint8_t USARTtoUC_Buffer_Data[TLV_MAX_PACKET * 4];

/** Circular buffer to hold data being sent to the serial port, plus underlying buffer. */
static RingBuffer_t UCtoUSART_Buffer;
static uint8_t UCtoUSART_Buffer_Data[TLV_MAX_PACKET * 4];

/** Circular buffer to hold HID events, plus underlying buffer. */
static RingBuffer_t HID_Buffer;
// 1 byte type, up to 7 bytes data, plus 1 extra for the type of the next report
// this implies that there will either always be space for the data (since the
// HID report generating routine will always remove in chunks of 8), or only the
// type. This means we don't have to check if there is space when inserting
// padding, as there will always be enough room if we get to that point.
static uint8_t HID_Buffer_Data[8 * 10 + 1];

/** Circular buffer to hold data sent to the target, plus underlying buffer. */
static RingBuffer_t PipeTX_Buffer;
static uint8_t PipeTX_Buffer_Data[256];

// defines the end of ESP boot loader messages, and start of ESP application messages
// this is just `echo -n "" | md5`
char boot_message[] = "d41d8cd98f00b204e9800998ecf8427e";
uint8_t boot_match = 0;

static enum {
	CHANNEL = 0, LENGTH = 1, DATA = 2
} tlv_read_state = CHANNEL, tlv_send_state = CHANNEL;

static bool tlv_send_flow_paused = false, tlv_recv_flow_paused = false;

#define JIGGLER_LOOP_COUNT 50
static bool jiggler = true;
static uint16_t jiggler_counter = JIGGLER_LOOP_COUNT;
static int8_t jiggler_state = 10;

void initESP(uint32_t baud) {
	memset(&UCtoUSART_Buffer_Data, 0, sizeof(UCtoUSART_Buffer_Data));
	memset(&USARTtoUC_Buffer_Data, 0, sizeof(USARTtoUC_Buffer_Data));
	memset(&HID_Buffer_Data, 0, sizeof(HID_Buffer_Data));
	memset(&PipeTX_Buffer_Data, 0, sizeof(PipeTX_Buffer_Data));

	RingBuffer_InitBuffer(&UCtoUSART_Buffer, UCtoUSART_Buffer_Data,
		sizeof(UCtoUSART_Buffer_Data));
	RingBuffer_InitBuffer(&USARTtoUC_Buffer, USARTtoUC_Buffer_Data,
		sizeof(USARTtoUC_Buffer_Data));
	RingBuffer_InitBuffer(&HID_Buffer, HID_Buffer_Data,
		sizeof(HID_Buffer_Data));
	RingBuffer_InitBuffer(&PipeTX_Buffer, PipeTX_Buffer_Data,
		sizeof(PipeTX_Buffer_Data));

	// Set the UART to the rate required for the boot loader
	UART_Init(baud);

	GlobalInterruptEnable();

	/*
	 * Enable the ESP8266, which is connected to Arduino Digital Pin 13
	 * aka PC7
	 */
	// Set pin 13 to output
	DDRC |= (1 << PC7);
	// set pin 13 to high
	PORTC |= (1 << PC7);

	// read the bootloader messages, until we see the startup message from our code
	while (boot_match < strlen(boot_message)) {
		while (RingBuffer_GetCount(&USARTtoUC_Buffer) > 0) {
			uint8_t b = RingBuffer_Remove(&USARTtoUC_Buffer);
			if (b == boot_message[boot_match]) {
				boot_match++;
			} else {
				boot_match = 0;
			}
		}
	}
}

void usabuse_task(void) {
	static uint8_t tlv_channel = 0;
	static uint8_t tlv_length = 0;
	static uint8_t tlv_data_read = 0;

	uint16_t available = RingBuffer_GetCount(&USARTtoUC_Buffer);

	if (tlv_recv_flow_paused && available == 0) {
		tlv_send_fc(false);
		tlv_recv_flow_paused = false;
	}
	tlv_send_uart();
	while ((available = RingBuffer_GetCount(&USARTtoUC_Buffer)) > 0) {
		switch (tlv_read_state) {
		case CHANNEL:
			tlv_channel = RingBuffer_Remove(&USARTtoUC_Buffer);
			tlv_read_state = LENGTH;
			break;
		case LENGTH:
			tlv_length = RingBuffer_Remove(&USARTtoUC_Buffer);
			tlv_data_read = 0;
			tlv_read_state = DATA;
			if (tlv_channel == TLV_HID) {
				if (tlv_length == 2 || tlv_length == 7) { // keyboard data
					RingBuffer_Insert(&HID_Buffer, 1);
				} else if (tlv_length == 4) { // mouse data
					RingBuffer_Insert(&HID_Buffer, 2);
				}
			}
			break;
		case DATA:
		  switch (tlv_channel) {
				case TLV_HID:
					if (!RingBuffer_IsFull(&HID_Buffer)) {
						uint8_t b = RingBuffer_Remove(&USARTtoUC_Buffer);
						RingBuffer_Insert(&HID_Buffer, b);
						tlv_data_read++;
					} else
						return;
					break;
				case TLV_PIPE:
					if (!RingBuffer_IsFull(&PipeTX_Buffer)) {
						uint8_t b = RingBuffer_Remove(&USARTtoUC_Buffer);
						RingBuffer_Insert(&PipeTX_Buffer, b);
						tlv_data_read++;
					} else
						return;
					break;
				default:
					// discard the message
					RingBuffer_Remove(&USARTtoUC_Buffer);
					tlv_data_read++;
					break;
		  }

			if (tlv_data_read == tlv_length) {
				tlv_read_state = CHANNEL;
				if (tlv_channel == TLV_HID && tlv_length < 7) {
					// pad it to 1 + 7 characters
					for (uint8_t i = tlv_length; i < 7; i++) {
						RingBuffer_Insert(&HID_Buffer, 0);
					}
				}

				if (!tlv_recv_flow_paused) {
//					tlv_send_fc(true); // implicit on the ESP
					tlv_recv_flow_paused = true;
				}
			}
			break;
		}
	}
	if (jiggler && jiggler_counter-- == 0) {
		if (RingBuffer_GetFreeCount(&HID_Buffer) > 7) {
			RingBuffer_Insert(&HID_Buffer, 2); // mouse data
			RingBuffer_Insert(&HID_Buffer, 0); // mouse buttons
			RingBuffer_Insert(&HID_Buffer, jiggler_state); // mouse x
			RingBuffer_Insert(&HID_Buffer, jiggler_state); // mouse y
			RingBuffer_Insert(&HID_Buffer, 0); // mouse z
			RingBuffer_Insert(&HID_Buffer, 0); // padding
			RingBuffer_Insert(&HID_Buffer, 0); // padding
			RingBuffer_Insert(&HID_Buffer, 0); // padding
			jiggler_state = - jiggler_state;
			jiggler_counter = JIGGLER_LOOP_COUNT;
		}
	}
}

bool tlv_send_queue(uint8_t channel, uint8_t length, uint8_t *data) {
	if (tlv_send_flow_paused || RingBuffer_GetFreeCount(&UCtoUSART_Buffer) < length + 2) {
		return false;
	}
	RingBuffer_Insert(&UCtoUSART_Buffer, channel);
	RingBuffer_Insert(&UCtoUSART_Buffer, length);
	for (uint8_t i = 0; i < length; i++) {
		RingBuffer_Insert(&UCtoUSART_Buffer, data[i]);
	}
	return true;
}

void tlv_send_fc(bool enabled) {
	while (tlv_send_state != CHANNEL) {
		// flush any in progress message
		while (!Serial_IsSendReady());
		tlv_send_uart();
	}

	while (!Serial_IsSendReady());
	Serial_SendByte(0); // Control channel
	while (!Serial_IsSendReady());
	Serial_SendByte(2); // 2 bytes
	while (!Serial_IsSendReady());
	Serial_SendByte(0); // Flow control
	while (!Serial_IsSendReady());
	Serial_SendByte(enabled ? 1 : 0); // enabled
}

// This could be made more intelligent to make sure that there is always a key-up
// event pending.
uint8_t usabuse_get_hid(uint8_t *data) {
	if (RingBuffer_GetCount(&HID_Buffer) < 8)
	 	return 0;
	uint8_t report_type = RingBuffer_Remove(&HID_Buffer);
	for (uint8_t i=0; i<7; i++)
		data[i] = RingBuffer_Remove(&HID_Buffer);
	return report_type;
}

uint8_t usabuse_get_pipe(uint8_t *data, uint8_t max) {
	uint8_t count = MIN(max, RingBuffer_GetCount(&PipeTX_Buffer));
	for (uint8_t i = 0; i < count; i++)
		data[i] = RingBuffer_Remove(&PipeTX_Buffer);
	return count;
}

bool usabuse_put_pipe(uint8_t *data, uint8_t count) {
	return tlv_send_queue(TLV_PIPE, count, data);
}

void tlv_send_uart() {
	static uint8_t length;
	/*
	 * Load the next byte from the USART transmit buffer into the
	 * USART if transmit buffer space is available
	 */
	if (Serial_IsSendReady()) {
		uint16_t available = RingBuffer_GetCount(&UCtoUSART_Buffer);
		if (available > 0) {
			uint8_t b = RingBuffer_Remove(&UCtoUSART_Buffer);
			Serial_SendByte(b);
			switch (tlv_send_state) {
			case CHANNEL:
				tlv_send_state = LENGTH;
				break;
			case LENGTH:
				tlv_send_state = DATA;
				length = b;
				break;
			case DATA:
				length--;
				if (length == 0) {
					tlv_send_state = CHANNEL;
				}
				break;
			}
		}
	}
}

/** ISR to manage the reception of data from the serial port, placing received bytes into a circular buffer
 *  for later parsing into HID reports.
 */
ISR(USART1_RX_vect, ISR_BLOCK) {
	uint8_t ReceivedByte = UDR1;

	if (!(RingBuffer_IsFull(&USARTtoUC_Buffer)))
		RingBuffer_Insert(&USARTtoUC_Buffer, ReceivedByte);
}

/* TODO: Explore this for better performance

When adding data to the TX Ringbuffer, enable the UDRE interrupt:
	UCSR1B |= _BV(UDRIE1);

ISR(USART1_UDRE_vect, ISR_BLOCK) {
	if (RingBuffer_GetCount(&UCtoUSART_Buffer) > 0) {
		UDR1 = RingBuffer_Remove(&UCtoUSART_Buffer);
	} else {
	  // disable interrupt
		UCSR1B &= ~(1 << UDRIE1);
	}
}
*/

void UART_Init(uint32_t baud) {
	uint8_t ConfigMask = 0;

	//No parity is the default, so no code required
	// 8 bits
	ConfigMask |= ((1 << UCSZ11) | (1 << UCSZ10));
	//1 stop bit is the default, so no code required

	/*
	 * Keep the TX line held high (idle) while the USART is reconfigured
	 */
	PORTD |= (1 << 3);

	/*
	 * Must turn off USART before reconfiguring it, otherwise incorrect
	 * operation may occur
	 */
	UCSR1B = 0;
	UCSR1A = 0;
	UCSR1C = 0;

	/* Set the new baud rate before configuring the USART */
	UBRR1 = SERIAL_2X_UBBRVAL(baud);

	/*
	 * Reconfigure the USART in double speed mode for a wider baud rate
	 * range at the expense of accuracy
	 */
	UCSR1C = ConfigMask;
	UCSR1A = (1 << U2X1);
	UCSR1B = ((1 << RXCIE1) | (1 << TXEN1) | (1 << RXEN1));

	/* Release the TX line after the USART has been reconfigured */
	PORTD &= ~(1 << 3);
}
