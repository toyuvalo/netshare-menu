' launcher.vbs -- Collects multi-selected files from Explorer and launches net-share.ps1

Dim sScript, sLock, sList, oShell, oFSO, oFile, oFolder, oItems, oItem, oWSH

Set oWSH = CreateObject("WScript.Shell")

sScript = WScript.ScriptFullName
sScript = Left(sScript, InStrRev(sScript, "\")) & "net-share.ps1"
sLock   = oWSH.ExpandEnvironmentStrings("%TEMP%") & "\netshare_lock.tmp"
sList   = oWSH.ExpandEnvironmentStrings("%TEMP%") & "\netshare_files.tmp"

Set oShell = CreateObject("Shell.Application")
Set oFSO   = CreateObject("Scripting.FileSystemObject")

If oFSO.FileExists(sLock) Then
    ' Another instance is already collecting -- just append our file
    Set oFile = oFSO.OpenTextFile(sList, 8, True)
    oFile.WriteLine WScript.Arguments(0)
    oFile.Close
    WScript.Quit
End If

' First instance: create lock, write first file
Set oFile = oFSO.OpenTextFile(sLock, 2, True)
oFile.Close

Set oFile = oFSO.OpenTextFile(sList, 2, True)
oFile.WriteLine WScript.Arguments(0)
oFile.Close

' Wait for other concurrent instances to append their files
WScript.Sleep 200

' Also sweep Explorer's current selection (catches files not yet appended)
On Error Resume Next
For Each oFolder In oShell.Windows
    If Not IsNull(oFolder.Document) Then
        Set oItems = oFolder.Document.SelectedItems()
        If Err.Number = 0 And Not IsNull(oItems) Then
            Set oFile = oFSO.OpenTextFile(sList, 8, True)
            For Each oItem In oItems
                If oItem.Path <> WScript.Arguments(0) Then
                    oFile.WriteLine oItem.Path
                End If
            Next
            oFile.Close
        End If
    End If
Next
On Error GoTo 0

oFSO.DeleteFile sLock

oWSH.Run _
    "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden" & _
    " -File """ & sScript & """ -Mode share -ListFile """ & sList & """", _
    0, False
