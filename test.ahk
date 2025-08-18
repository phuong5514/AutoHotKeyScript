#Requires AutoHotkey v2.0

Run("notepad", , , &pid)
WinWait("ahk_class Notepad")

winPID := WinGetPID("Notepad")
MsgBox("Launched Notepad with PID: " pid)
Sleep(3000)

all_pids := ""
for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where Name='notepad.exe'")
    all_pids .= process.ProcessId "`n"

MsgBox("Run() gave PID: " pid "`nAll Notepad PIDs: `n" all_pids)

Sleep(3000)

MsgBox("Closing Notepad with PID: " pid)
if (!ProcessExist(pid)) {
    MsgBox("PID " pid " does not exist")
}

all_pids_list := StrSplit(all_pids, "`n")

for pid in all_pids_list {
    ProcessClose(pid)
}

; ProcessClose(pid)
; ProcessClose(winPID)  ; reliably closes the GUI instance
