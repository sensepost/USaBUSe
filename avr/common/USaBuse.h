#ifndef __USABUSE_H
#define __USABUSE_H
#include <LUFA/Drivers/Misc/RingBuffer.h>

#define TLV_MAX_PACKET 64

#define TLV_CONTROL 0
#define TLV_HID 1
#define TLV_GENERIC 2

/**
 * Enables the ESP8266 portion of the Cactus Micro Rev2, configures the UART to the specified baud rate, and
 * reads until it encounters a magic string of "d41d8cd98f00b204e9800998ecf8427e", signifying the beginning of
 * execution of the ESP code.
 *
 * Assumes that interrupts are not yet enabled, so it enables them to be able to receive UART characters,
 * and disables interrupts again on exit, to allow any USB initialisation to take place
 */
void initESP(uint32_t baud);

typedef struct {
	uint8_t channel;
	uint8_t length;
	uint8_t data[TLV_MAX_PACKET];
} ATTR_PACKED tlv_data_t;

tlv_data_t* tlv_read(void);

bool tlv_send_queue(uint8_t channel, uint8_t length, uint8_t *data);
void tlv_send_uart(void);

void tlv_initDebugBuffer(RingBuffer_t *buffer);

#endif
