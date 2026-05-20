Add-Type @"

using System;using System.Runtime.InteropServices;

public class W{

[DllImport("user32.dll")]public static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int c,int d,uint f);

[DllImport("user32.dll")]public static extern IntPtr GetForegroundWindow();}

"@

sleep 5

[W]::SetWindowPos([W]::GetForegroundWindow(),-1,0,0,0,0,3)
