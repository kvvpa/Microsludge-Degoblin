Option Explicit

Dim shell
Dim fso
Dim scriptDir
Dim uninstallerScript
Dim command
Dim i

Set shell = CreateObject("Shell.Application")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
uninstallerScript = fso.BuildPath(fso.BuildPath(scriptDir, "Scripts"), "Uninstall-Microsludge-DegoblinTask.ps1")

command = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File " & QuoteArg(uninstallerScript)

For i = 0 To WScript.Arguments.Count - 1
    command = command & " " & QuoteArg(WScript.Arguments(i))
Next

shell.ShellExecute "powershell.exe", command, scriptDir, "runas", 0

Function QuoteArg(value)
    QuoteArg = """" & Replace(CStr(value), """", """""") & """"
End Function
