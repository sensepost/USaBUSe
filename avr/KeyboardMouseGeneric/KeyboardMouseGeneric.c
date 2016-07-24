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

/** Main program entry point. This routine contains the overall program flow, including initial
 *  setup of all components and the main program loop.
 */
int main(void)
{
	SetupHardware();
	USB_Init();

	GlobalInterruptEnable();

	initESP(250000);
	for (;;)
	{
		usabuse_task();

		HID_Device_USBTask(&Device_HID_Interface);
		HID_Device_USBTask(&Generic_HID_Interface);
		USB_USBTask();
	}
}

/** Configures the board hardware and chip peripherals for the demo's functionality. */
void SetupHardware()
{
	/* Disable watchdog if enabled by bootloader/fuses */
	MCUSR &= ~(1 << WDRF);
	wdt_disable();

	/* Disable clock division */
	clock_prescale_set(clock_div_1);
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

	switch (HIDInterfaceInfo->Config.InterfaceNumber)
	{
	case INTERFACE_ID_KeyboardAndMouse:
	  {
			uint8_t data[7];
			uint8_t type = usabuse_get_hid(data);
			switch (type) {
				case 1:
				{ // keyboard
					USB_KeyboardReport_Data_t* KeyboardReport = (USB_KeyboardReport_Data_t*)ReportData;

					KeyboardReport->Modifier = data[0];
					for (uint8_t i = 1; i<7; i++)
						KeyboardReport->KeyCode[i-1] = data[i];

					*ReportID   = HID_REPORTID_KeyboardReport;
					*ReportSize = sizeof(USB_KeyboardReport_Data_t);
					return true;
				}
				case 2:
				{ // mouse
					USB_MouseReport_Data_t* MouseReport = (USB_MouseReport_Data_t*)ReportData;

					MouseReport->Button = data[0];
					MouseReport->X = (int8_t) data[1];
					MouseReport->Y = (int8_t) data[2];
					// TODO: put the wheel report in here too

					*ReportID   = HID_REPORTID_MouseReport;
					*ReportSize = sizeof(USB_MouseReport_Data_t);
					return true;
				}
			}
			return false;
		}
		break;
	case INTERFACE_ID_GenericHID:
		{
			uint8_t* data = (uint8_t *) ReportData;

			uint8_t count = usabuse_get_pipe(&data[1], GENERIC_REPORT_SIZE - 1);
			data[0] = count | (usabuse_pipe_write_is_blocked() << 7);
			*ReportSize = GENERIC_REPORT_SIZE;
			return true;
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
			if (data[0] > 0 && data[0] < GENERIC_REPORT_SIZE) {
				if (!usabuse_put_pipe(&data[1], data[0]))
					usabuse_debug("Can't send!");
			} else if (data[0] == 0) {
				usabuse_pipe_opened(data[1] != 0);
			}
		}
	}
}
