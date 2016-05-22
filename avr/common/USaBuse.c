#include <LUFA/Drivers/Peripheral/Serial.h>

#include "USaBuse.h"

// #define DEBUG

void UART_Init(uint32_t baud);
void tlv_send_fc(bool enabled);
void tlv_send_uart(void);

static RingBuffer_t *Debug_Buffer;

void tlv_initDebugBuffer(RingBuffer_t *buffer) {
	Debug_Buffer = buffer;
}

static inline void
RingBuffer_InsertString(RingBuffer_t * Buffer,
			char *Data)ATTR_NON_NULL_PTR_ARG(1);

static inline void RingBuffer_InsertString(RingBuffer_t * Buffer, char *Data)
{
	char           *c = Data;
	if (RingBuffer_GetFreeCount(Buffer) > strlen(Data)) {
		while (*c) {
			RingBuffer_Insert(Buffer, *c++);
		}
	}
}

static inline void cm_debug(char *Data) {
	if (Debug_Buffer != NULL)
		RingBuffer_InsertString(Debug_Buffer, Data);
}

/** Circular buffer to hold data from the serial port, plus underlying data buffer */
static RingBuffer_t USARTtoUC_Buffer;
static uint8_t USARTtoUC_Buffer_Data[TLV_MAX_PACKET * 4];

/** Circular buffer to hold data being sent to the serial port, plus underlying buffer. */
static RingBuffer_t UCtoUSART_Buffer;
static uint8_t UCtoUSART_Buffer_Data[TLV_MAX_PACKET * 4];

// defines the end of ESP boot loader messages, and start of ESP application messages
// this is just `echo -n "" | md5`
char boot_message[] = "d41d8cd98f00b204e9800998ecf8427e";
uint8_t boot_match = 0;

static enum {
	CHANNEL = 0, LENGTH = 1, DATA = 2
} tlv_read_state = CHANNEL, tlv_send_state = CHANNEL;

static bool tlv_send_flow_paused = false, tlv_recv_flow_paused = false;

void initESP(uint32_t baud) {
	memset(&UCtoUSART_Buffer_Data, 0, sizeof(UCtoUSART_Buffer_Data));
	memset(&USARTtoUC_Buffer_Data, 0, sizeof(USARTtoUC_Buffer_Data));

	RingBuffer_InitBuffer(&UCtoUSART_Buffer, UCtoUSART_Buffer_Data,
			sizeof(UCtoUSART_Buffer_Data));
	RingBuffer_InitBuffer(&USARTtoUC_Buffer, USARTtoUC_Buffer_Data,
			sizeof(USARTtoUC_Buffer_Data));

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

	// read the bootloader messages
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

//	cm_debug("FC on\n");
//	tlv_send_fc(true);
//	tlv_recv_flow_paused = true;

}

#define DEBUG
tlv_data_t* tlv_read() {
	static tlv_data_t tlv_data;
	static uint8_t tlv_data_read = 0;
	static bool err = false;

#define FLOW_COUNTER 32768
	static uint16_t flow_control_counter = FLOW_COUNTER;

#ifdef DEBUG
	char buf[32];
#endif

	uint16_t available = RingBuffer_GetCount(&USARTtoUC_Buffer);

	if (available == 0 && ++flow_control_counter == 0) {
		// periodic reminder to disable flow control in case things get stuck
		tlv_send_fc(false);
		flow_control_counter = FLOW_COUNTER;
	}

	if (err) {
		if (available > 0) {
			sprintf(buf, "B: %d\n", available);
			cm_debug(buf);
		}
	    while (available-- > 0) {
	    	RingBuffer_Remove(&USARTtoUC_Buffer);
	    }
		return NULL;
	}

	if (tlv_recv_flow_paused && RingBuffer_GetCount(&USARTtoUC_Buffer) == 0) {
		tlv_send_fc(false);
		tlv_recv_flow_paused = false;
	}
	tlv_send_uart();
	while ((available = RingBuffer_GetCount(&USARTtoUC_Buffer)) > 0) {
		// reset the flow control counter
		flow_control_counter = FLOW_COUNTER;

		if (available == sizeof(USARTtoUC_Buffer_Data)) {
			sprintf(buf, "C: %d\n", available);
		    cm_debug(buf);
		}
		if (available > TLV_MAX_PACKET && !tlv_recv_flow_paused) {
			cm_debug("FC on\n");
			tlv_send_fc(true);
			tlv_recv_flow_paused = true;
		}
		uint8_t b = RingBuffer_Remove(&USARTtoUC_Buffer);
		switch (tlv_read_state) {
		case CHANNEL:
			tlv_data.channel = b;
			tlv_read_state = LENGTH;
			break;
		case LENGTH:
			tlv_data.length = b;
			tlv_data_read = 0;
			tlv_read_state = DATA;

			break;
		case DATA:
			tlv_data.data[tlv_data_read++] = b;

			if (tlv_data_read == tlv_data.length) {
				tlv_read_state = CHANNEL;

				if (!tlv_recv_flow_paused) {
//					tlv_send_fc(true); // implicit on the ESP
					tlv_recv_flow_paused = true;
				}

				return &tlv_data;
			}
			break;
		}
	}
	return NULL;
}

bool tlv_send_queue(uint8_t channel, uint8_t length, uint8_t *data) {
	if (tlv_send_flow_paused || RingBuffer_GetFreeCount(&UCtoUSART_Buffer) < length + 2) {
		cm_debug("Paused or no space in tlv_send_queue\r\n");
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
	if (tlv_send_state != CHANNEL) {
		cm_debug("XOn?");
	}
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
	else
		cm_debug("Z");
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

