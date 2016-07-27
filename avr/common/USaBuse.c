#include <LUFA/Drivers/Peripheral/Serial.h>
#include "USaBuse.h"

void UART_Init(uint32_t baud);
void tlv_send_fc(bool enabled);

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
static enum {
	PIPE_DISCONNECTED = 0,
	CONNECT_REQUESTED = 1,
	PIPE_CONNECTED = 2,
	DISCONNECT_REQUESTED = 3
} pipe_state = PIPE_DISCONNECTED;

#define JIGGLER_LOOP_COUNT 5000
static bool jiggler = true;
static uint32_t jiggler_counter = JIGGLER_LOOP_COUNT;
static int8_t jiggler_jump = 1;

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
	 * aka PC7 and Arduino Digital Pin 12, aka PD6
	 */
	 // Set pin 13 to output
	 // Set pin 12 to output
 	DDRC |= (1 << PC7);
	DDRD |= (1 << PD6);
	// Set pin 11 (PB7) to input
	DDRB &= ~(1 << PB7);
	if (PORTB & ~(1<<PB7)) {
		// LED is present, indicates Blackbox hardware with pin 12 and 13 swapped
		PORTC |= (1 << PC7);
		PORTD |= (1 << PD6);
	} else { // not present, Cactus Micro Rev2, or something else
		PORTC |= (1 << PC7);
		PORTD &= ~(1 << PD6);
	}

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
					// tlv_send_fc(true); // implicit on the ESP
					tlv_recv_flow_paused = true;
				}
			}
			break;
		}
	}
	if (jiggler && --jiggler_counter == 0) {
		if (RingBuffer_GetFreeCount(&HID_Buffer) > 7) {
			RingBuffer_Insert(&HID_Buffer, 2); // mouse data
			RingBuffer_Insert(&HID_Buffer, 0); // mouse buttons
			RingBuffer_Insert(&HID_Buffer, jiggler_jump); // mouse x
			RingBuffer_Insert(&HID_Buffer, 0); // mouse y
			RingBuffer_Insert(&HID_Buffer, 0); // mouse z
			RingBuffer_Insert(&HID_Buffer, 0); // padding
			RingBuffer_Insert(&HID_Buffer, 0); // padding
			RingBuffer_Insert(&HID_Buffer, 0); // padding
			jiggler_jump = -jiggler_jump;
		}
		jiggler_counter = JIGGLER_LOOP_COUNT;
	}
}

bool tlv_send_queue(uint8_t channel, uint8_t length, uint8_t *data) {
	length = MIN(length, TLV_MAX_PACKET);
	if (tlv_send_flow_paused || RingBuffer_GetFreeCount(&UCtoUSART_Buffer) < length + 2) {
		return false;
	}
	RingBuffer_Insert(&UCtoUSART_Buffer, channel);
	RingBuffer_Insert(&UCtoUSART_Buffer, length);
	for (uint8_t i = 0; i < length; i++) {
		RingBuffer_Insert(&UCtoUSART_Buffer, data[i]);
	}
	UCSR1B |= (1 << UDRIE1);
	return true;
}

void tlv_send_fc(bool enabled) {
	uint8_t data[] = {TLV_CONTROL_FLOW, enabled ? 1 : 0};
	tlv_send_queue(TLV_CONTROL, 2, data);
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

bool usabuse_put_pipe(uint8_t count, uint8_t *data) {
	return tlv_send_queue(TLV_PIPE, count, data);
}

bool usabuse_pipe_write_is_blocked() {
	return pipe_state != PIPE_CONNECTED || (RingBuffer_GetFreeCount(&UCtoUSART_Buffer) < TLV_MAX_PACKET + 2);
}

void usabuse_victim_ready(bool ready) {
	uint8_t data[] = {TLV_CONTROL_CONNECT, ready ? 1 : 0};
	if (ready && pipe_state == PIPE_DISCONNECTED) {
		tlv_send_queue(TLV_CONTROL, 2, data);
		pipe_state = CONNECT_REQUESTED;
		// for debugging only, until implemented in the ESP
		pipe_state = PIPE_CONNECTED;
	} else if (!ready && pipe_state == PIPE_CONNECTED) {
		tlv_send_queue(TLV_CONTROL, 2, data);
		pipe_state = DISCONNECT_REQUESTED;
		// drain the buffered characters
		uint16_t count = RingBuffer_GetCount(&HID_Buffer);
		while (count-- > 0)
			RingBuffer_Remove(&HID_Buffer);

		// for debugging only, until implemented in the ESP
		pipe_state = PIPE_DISCONNECTED;
	}
}

void usabuse_debug(char *message) {
	uint8_t length = strlen(message);
	tlv_send_queue(TLV_DEBUG, length, (uint8_t *) message);
}

/** ISR to manage the reception of data from the serial port, placing received bytes into a circular buffer
 *  for later parsing into HID reports.
 */
ISR(USART1_RX_vect, ISR_BLOCK) {
	uint8_t ReceivedByte = UDR1;

	if (!(RingBuffer_IsFull(&USARTtoUC_Buffer)))
		RingBuffer_Insert(&USARTtoUC_Buffer, ReceivedByte);
}

/** ISR to manage sending of data via the serial port, taking data from a
 * circular buffer
 *
 * When adding data to the TX Ringbuffer, enable the UDRE interrupt:
 * UCSR1B |= (1 << UDRIE1);
*/
ISR(USART1_UDRE_vect, ISR_BLOCK) {
	if (RingBuffer_GetCount(&UCtoUSART_Buffer) > 0) {
		UDR1 = RingBuffer_Remove(&UCtoUSART_Buffer);
	} else {
	  // disable interrupt
		UCSR1B &= ~(1 << UDRIE1);
	}
}

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
