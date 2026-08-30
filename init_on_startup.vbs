' Hidden launcher with explicit working directory (Startup folder friendly).
' Do not rely on the process CWD — always set CurrentDirectory to this script's folder.

Option Explicit
Dim shell, fso, scriptDir, runBat, cmd
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
runBat = scriptDir & "\run.bat"
If Not fso.FileExists(runBat) Then
  WScript.Echo "run.bat not found next to init_on_startup.vbs"
  WScript.Quit 1
End If
shell.CurrentDirectory = scriptDir
cmd = "cmd.exe /c """ & runBat & """"
' 0 = hidden window, False = do not wait
shell.Run cmd, 0, False
