# A simple test to see if the victim can write and the attacker recieve

# Open file handle to device
$cs =@" 
using System;
using System.IO;
using Microsoft.Win32.SafeHandles;
using System.Runtime.InteropServices;
namespace foo {
	public class bar {
		[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern SafeFileHandle CreateFile(String fn, UInt32 da, Int32 sm, IntPtr sa, Int32 cd, uint fa, IntPtr tf);

		public static FileStream open(string fn) {
			return new FileStream(CreateFile(fn, 0XC0000000U, 3, IntPtr.Zero, 3, 0x40000000, IntPtr.Zero), FileAccess.ReadWrite, 9, true);
		}
	}
}
"@
Add-Type -TypeDefinition $cs
#Find device
$devs = gwmi Win32_USBControllerDevice
foreach ($dev in $devs) {
	$wmidev = [wmi]$dev.Dependent
	if ($wmidev.GetPropertyValue('DeviceID') -match ('03EB&PID_2066') -and ($wmidev.GetPropertyValue('Service') -eq $null)) {
		$devicestring = ([char]92+[char]92+'?'+[char]92 + $wmidev.GetPropertyValue('DeviceID').ToString().Replace([char]92,[char]35) + [char]35+'{4d1e55b2-f16f-11cf-88cb-001111000030}')
	}
}
$filehandle = [foo.bar]::open($devicestring)

#Send a simple string of text, we send 65 bytes [0] is HID report ID, [1] is length of the payload, [2-65] is the payload
$bytes = New-Object Byte[] (65)
#Write an initial blank packet to start the comms
$filehandle.Write($bytes,0,65)
$bytes[1] = 0x04 #Set payload length to 4
$bytes[2] = 0x41 #Set next 4 bytes to A
$bytes[3] = 0x41
$bytes[4] = 0x41
$bytes[5] = 0x41
$filehandle.Write($bytes,0,65) #You should see AAAA on the telnet channel
$filehandle.Close()
