#Requires AutoHotkey v2.0

Run("notepad", , , &pid)
MsgBox("Launched Notepad with PID: " pid)
Sleep(3000)
MsgBox("Closing Notepad with PID: " pid)
if (!ProcessExist(pid)) {
    MsgBox("PID " pid " does not exist")
}

ProcessClose(pid)
WinClose("ahk_pid " pid)
Sleep(1000)
if (WinExist("ahk_pid " pid))
    WinKill("ahk_pid " pid)