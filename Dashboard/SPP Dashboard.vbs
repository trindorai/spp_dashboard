' Starts the SPP Dashboard desktop app (app.ps1) with no console window.
' Optional argument: -Tray  (start in the tray without opening the window)
Set sh = CreateObject("WScript.Shell")
dir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
args = ""
If WScript.Arguments.Count > 0 Then args = " " & WScript.Arguments(0)
sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dir & "\app.ps1""" & args, 0, False
