Option Explicit
If WScript.Arguments.Count = 0 Then WScript.Quit 1
Dim fso, sh, psExe, cmd, i, arg
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
psExe = sh.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
If Not fso.FileExists(psExe) Then psExe = "powershell.exe"
cmd = """" & psExe & """"
For i = 0 To WScript.Arguments.Count - 1
    arg = WScript.Arguments(i)
    If InStr(arg, " ") > 0 Or InStr(arg, vbTab) > 0 Or InStr(arg, """") > 0 Or Len(arg) = 0 Then
        cmd = cmd & " """ & Replace(arg, """", """""") & """"
    Else
        cmd = cmd & " " & arg
    End If
Next
sh.Run cmd, 0, False
