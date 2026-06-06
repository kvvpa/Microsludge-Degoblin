Option Explicit

Dim shell
Dim fso
Dim scriptDir
Dim guiScript
Dim command
Dim i

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
guiScript = fso.BuildPath(scriptDir, "Start-Microsludge-Degoblin-GUI.ps1")

command = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File " & QuoteArg(guiScript)

For i = 0 To WScript.Arguments.Count - 1
    command = command & " " & QuoteArg(WScript.Arguments(i))
Next

shell.Run command, 0, False

Function QuoteArg(value)
    QuoteArg = """" & Replace(CStr(value), """", """""") & """"
End Function
