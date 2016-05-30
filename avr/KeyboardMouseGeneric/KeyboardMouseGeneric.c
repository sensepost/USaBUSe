/*
             LUFA Library
     Copyright (C) Dean Camera, 2015.

  dean [at] fourwalledcubicle [dot] com
           www.lufa-lib.org
*/

/*
  Copyright 2015  Dean Camera (dean [at] fourwalledcubicle [dot] com)

  Permission to use, copy, modify, distribute, and sell this
  software and its documentation for any purpose is hereby granted
  without fee, provided that the above copyright notice appear in
  all copies and that both that the copyright notice and this
  permission notice and warranty disclaimer appear in supporting
  documentation, and that the name of the author not be used in
  advertising or publicity pertaining to distribution of the
  software without specific, written prior permission.

  The author disclaims all warranties with regard to this
  software, including all implied warranties of merchantability
  and fitness.  In no event shall the author be liable for any
  special, indirect or consequential damages or any damages
  whatsoever resulting from loss of use, data or profits, whether
  in an action of contract, negligence or other tortious action,
  arising out of or in connection with the use or performance of
  this software.
*/

/** \file
 *
 *  Main source file for the KeyboardMouseMultiReport demo. This file contains the main tasks of
 *  the demo and is responsible for the initial application hardware configuration.
 */

#include "KeyboardMouseGeneric.h"
#include "../common/USaBuse.h"

/** Circular buffer to hold data from the serial port before it is relayed to the USB Serial interface
 * plus underlying data buffer */
static RingBuffer_t Debug_Buffer;
static uint8_t	Debug_Buffer_Data[256];

/** Circular buffer to hold data from the serial port before it is relayed to the USB Serial interface
 * plus underlying data buffer */
static RingBuffer_t HID_Buffer;
static uint8_t	HID_Buffer_Data[TLV_MAX_PACKET];

/** Buffer to hold the previously generated HID report, for comparison purposes inside the HID class driver. */
static uint8_t PrevHIDReportBuffer[MAX(sizeof(USB_KeyboardReport_Data_t), sizeof(USB_MouseReport_Data_t))];

/** Buffer to hold the previously generated HID report, for comparison purposes inside the HID class driver. */
static uint8_t PrevGenericHIDReportBuffer[GENERIC_REPORT_SIZE];

/** LUFA HID Class driver interface configuration and state information. This structure is
 *  passed to all HID Class driver functions, so that multiple instances of the same class
 *  within a device can be differentiated from one another.
 */
USB_ClassInfo_HID_Device_t Device_HID_Interface =
	{
		.Config =
			{
				.InterfaceNumber              = INTERFACE_ID_KeyboardAndMouse,
				.ReportINEndpoint             =
					{
						.Address              = HID1_IN_EPADDR,
						.Size                 = HID_EPSIZE,
						.Banks                = 1,
					},
				.PrevReportINBuffer           = PrevHIDReportBuffer,
				.PrevReportINBufferSize       = sizeof(PrevHIDReportBuffer),
			},
	};

USB_ClassInfo_HID_Device_t Generic_HID_Interface =
	{
		.Config =
			{
				.InterfaceNumber              = INTERFACE_ID_GenericHID,
				.ReportINEndpoint             =
					{
						.Address              = GENERIC_IN_EPADDR,
						.Size                 = GENERIC_EPSIZE,
						.Banks                = 1,
					},
				.PrevReportINBuffer           = PrevGenericHIDReportBuffer,
				.PrevReportINBufferSize       = sizeof(PrevGenericHIDReportBuffer),
			},
	};

static void debug(char *buf) {
	uint8_t len = strlen(buf);
	while (len > 0) {
		uint8_t l = MIN(len, TLV_MAX_PACKET);
		tlv_send_queue(3, l, (uint8_t *) buf);
		buf += l;
		len -= l;
	}
}

static tlv_data_t* tlv_data = NULL;
static bool hid_active = false;

/** Main program entry point. This routine contains the overall program flow, including initial
 *  setup of all components and the main program loop.
 */
int main(void)
{
	SetupHardware();

	GlobalInterruptEnable();

	initESP(38400);
	RingBuffer_InitBuffer(&Debug_Buffer, Debug_Buffer_Data, sizeof(Debug_Buffer_Data));
	RingBuffer_InitBuffer(&HID_Buffer, HID_Buffer_Data, sizeof(HID_Buffer_Data));
#ifdef DEBUG_DESCRIPTORS
	dsc_initDebugBuffer(&Debug_Buffer);
#endif
	tlv_initDebugBuffer(&Debug_Buffer);

	for (;;)
	{
		uint16_t debug_bytes = MIN(TLV_MAX_PACKET,RingBuffer_GetCount(&Debug_Buffer));
		if (debug_bytes > 0) {
			uint8_t buff[debug_bytes];
			for (uint16_t i=0; i<debug_bytes; i++) {
				buff[i] = RingBuffer_Remove(&Debug_Buffer);
			}
			tlv_send_queue(1, debug_bytes, buff);
		}
		if (tlv_data == NULL) {
			tlv_data = tlv_read();
#if 0
			if (tlv_data != NULL) {
				debug_tlv("P: ", tlv_data->channel, tlv_data->length, tlv_data->data);
			}
#endif

		} else {
			tlv_send_uart();
		}

		if (tlv_data != NULL) {
			if (tlv_data->channel == 0 && tlv_data->length == 2) { // control message
				// there are no important control messages that we act on currently
				tlv_data = NULL;
			} else if (tlv_data->channel == TLV_GENERIC) {
				uint16_t hid_free = RingBuffer_GetFreeCount(&HID_Buffer);
				if ( hid_free >= tlv_data->length) {
					for (uint16_t i = 0; i< tlv_data->length; i++)
						RingBuffer_Insert(&HID_Buffer, tlv_data->data[i]);
					tlv_data = NULL;
				}
			}
		}

		HID_Device_USBTask(&Device_HID_Interface);
		HID_Device_USBTask(&Generic_HID_Interface);
		USB_USBTask();
	}
}

/** Configures the board hardware and chip peripherals for the demo's functionality. */
void SetupHardware()
{
#if (ARCH == ARCH_AVR8)
	/* Disable watchdog if enabled by bootloader/fuses */
	MCUSR &= ~(1 << WDRF);
	wdt_disable();

	/* Disable clock division */
	clock_prescale_set(clock_div_1);
#elif (ARCH == ARCH_XMEGA)
	/* Start the PLL to multiply the 2MHz RC oscillator to 32MHz and switch the CPU core to run from it */
	XMEGACLK_StartPLL(CLOCK_SRC_INT_RC2MHZ, 2000000, F_CPU);
	XMEGACLK_SetCPUClockSource(CLOCK_SRC_PLL);

	/* Start the 32MHz internal RC oscillator and start the DFLL to increase it to 48MHz using the USB SOF as a reference */
	XMEGACLK_StartInternalOscillator(CLOCK_SRC_INT_RC32MHZ);
	XMEGACLK_StartDFLL(CLOCK_SRC_INT_RC32MHZ, DFLL_REF_INT_USBSOF, F_USB);

	PMIC.CTRL = PMIC_LOLVLEN_bm | PMIC_MEDLVLEN_bm | PMIC_HILVLEN_bm;
#endif

	/* Hardware Initialization */
	USB_Init();
}

/** Event handler for the library USB Connection event. */
void EVENT_USB_Device_Connect(void)
{
}

/** Event handler for the library USB Disconnection event. */
void EVENT_USB_Device_Disconnect(void)
{
}

/** Event handler for the library USB Configuration Changed event. */
void EVENT_USB_Device_ConfigurationChanged(void)
{
	bool ConfigSuccess = true;

	ConfigSuccess &= HID_Device_ConfigureEndpoints(&Device_HID_Interface);
	ConfigSuccess &= HID_Device_ConfigureEndpoints(&Generic_HID_Interface);

	USB_Device_EnableSOFEvents();
}

/** Event handler for the library USB Control Request reception event. */
void EVENT_USB_Device_ControlRequest(void)
{
	HID_Device_ProcessControlRequest(&Device_HID_Interface);
	HID_Device_ProcessControlRequest(&Generic_HID_Interface);
}

/** Event handler for the USB device Start Of Frame event. */
void EVENT_USB_Device_StartOfFrame(void)
{
	HID_Device_MillisecondElapsed(&Device_HID_Interface);
	HID_Device_MillisecondElapsed(&Generic_HID_Interface);
}

/** HID class driver callback function for the creation of HID reports to the host.
 *
 *  \param[in]     HIDInterfaceInfo  Pointer to the HID class interface configuration structure being referenced
 *  \param[in,out] ReportID    Report ID requested by the host if non-zero, otherwise callback should set to the generated report ID
 *  \param[in]     ReportType  Type of the report to create, either HID_REPORT_ITEM_In or HID_REPORT_ITEM_Feature
 *  \param[out]    ReportData  Pointer to a buffer where the created report should be stored
 *  \param[out]    ReportSize  Number of bytes written in the report (or zero if no report is to be sent)
 *
 *  \return Boolean \c true to force the sending of the report, \c false to let the library determine if it needs to be sent
 */
bool CALLBACK_HID_Device_CreateHIDReport(USB_ClassInfo_HID_Device_t* const HIDInterfaceInfo,
                                         uint8_t* const ReportID,
                                         const uint8_t ReportType,
                                         void* ReportData,
                                         uint16_t* const ReportSize)
{

	uint8_t* data = (uint8_t *) ReportData;

	switch (HIDInterfaceInfo->Config.InterfaceNumber)
	{
	case INTERFACE_ID_KeyboardAndMouse:
		if (tlv_data == NULL)
			return false;

		if (tlv_data->channel == TLV_HID && (tlv_data->length == 2 || tlv_data->length == 7)) {

// #define DEBUG
#ifdef DEBUG
			debug_tlv("K: ", tlv_data->channel, tlv_data->length, tlv_data->data);
#endif

			USB_KeyboardReport_Data_t* KeyboardReport = (USB_KeyboardReport_Data_t*)ReportData;
			KeyboardReport->Modifier = tlv_data->data[0];

			for (uint8_t i = 1; i<tlv_data->length; i++)
				KeyboardReport->KeyCode[i-1] = tlv_data->data[i];

			*ReportID   = HID_REPORTID_KeyboardReport;
			*ReportSize = sizeof(USB_KeyboardReport_Data_t);
			tlv_data = NULL;
			return true;
		} else if (tlv_data->channel == TLV_HID && tlv_data->length == 4)	{
	// #define DEBUG
	#ifdef DEBUG
			debug_tlv("Mouse: ", tlv_data->channel, tlv_data->length, tlv_data->data);
	#endif

			USB_MouseReport_Data_t* MouseReport = (USB_MouseReport_Data_t*)ReportData;

			MouseReport->Button = tlv_data->data[0];
			MouseReport->X = (int8_t) tlv_data->data[1];
			MouseReport->Y = (int8_t) tlv_data->data[2];
			// TODO: put the wheel report in here too

			*ReportID   = HID_REPORTID_MouseReport;
			*ReportSize = sizeof(USB_MouseReport_Data_t);
			tlv_data = NULL;
			return true;
		}
		return false;
		break;
	case INTERFACE_ID_GenericHID:
		{
			uint16_t available = MIN(GENERIC_REPORT_SIZE - 1, RingBuffer_GetCount(&HID_Buffer));
			if (available > 0) {
				char buff[32];
				sprintf(buff, "%d bytes", available);
				debug(buff);

				data[0] = (uint8_t) (available & 0xFF);
				for (uint8_t i=0; i< available; i++) {
					data[i+1] = RingBuffer_Remove(&HID_Buffer);
				}
				*ReportSize = 8;
				return true;
			}
		}
		break;
	}
	return false;
}

/** HID class driver callback function for the processing of HID reports from the host.
 *
 *  \param[in] HIDInterfaceInfo  Pointer to the HID class interface configuration structure being referenced
 *  \param[in] ReportID    Report ID of the received report from the host
 *  \param[in] ReportType  The type of report that the host has sent, either HID_REPORT_ITEM_Out or HID_REPORT_ITEM_Feature
 *  \param[in] ReportData  Pointer to a buffer where the received report has been stored
 *  \param[in] ReportSize  Size in bytes of the received HID report
 */
void CALLBACK_HID_Device_ProcessHIDReport(USB_ClassInfo_HID_Device_t* const HIDInterfaceInfo,
                                          const uint8_t ReportID,
                                          const uint8_t ReportType,
                                          const void* ReportData,
                                          const uint16_t ReportSize)
{
	switch (HIDInterfaceInfo->Config.InterfaceNumber)
	{
	case INTERFACE_ID_KeyboardAndMouse:
		// we don't care about keyboard LED's
		break;
	case INTERFACE_ID_GenericHID:
		{
			uint8_t *data = (uint8_t *) ReportData;
			tlv_send_queue(TLV_GENERIC, data[0], &data[1]);
		}
	}
}

