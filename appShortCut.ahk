#Requires AutoHotkey v2.0

global apps := Map()
global appIcons := Map()
global configFileName := "appShortCutConfig.txt"

; Appearance
; backgroundColor := "Black"
; fontSettings := "s14 cWhite"
; prefferedFont := "Segoe UI"

backgroundColor := "242323"
textColor := "f9f9f9"
fontSettings := "s10 c000000"
prefferedFont := "Segoe UI"

; Menu UI
global uiOn := false
shortcutList := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
shortcutList.BackColor := backgroundColor
shortcutList.SetFont(fontSettings, prefferedFont)
shortcutList.MarginX := 0
shortcutList.MarginY := 0

; icons
global iconList := IL_Create()

; bindings
global bindings := Map(
    "toggleShortcutList", "!F7",
)

bindingFunctions := Map(
    "toggleShortcutList", ToggleUI
)

; Utilities
ToggleUI(*) {
    global uiOn

    if (!uiOn) {
        ShowUI()
    } else {
        HideUI()
    }
}

ShowUI() {
    global uiOn
    uiOn := true
    cursorX := 0
    cursorY := 0
    MouseGetPos &cursorX, &cursorY
    shortcutList.Show("x" cursorX " y" cursorY " AutoSize")
}

HideUI() {
    global uiOn
    uiOn := false
    shortcutList.Hide()
}

ReadConfiguration() {
    global configFileName, apps
    bindingConfig := false
    try {
        configFile := FileOpen(configFileName, "r")
        if !configFile {
            CreateConfigFile()
        }

        while !configFile.AtEOF {
            line := Trim(configFile.ReadLine())
            if (line = "" || SubStr(line, 1, 1) = ";")
                continue
            if (line = "*" || SubStr(line,1,1) = "*") {
                bindingConfig := true
                continue
            }

            parts := StrSplit(line, "=", , 2)

            if (!bindingConfig) {
                
            }
            if (parts.Length = 2) {
                key := Trim(parts[1])
                val := Trim(parts[2])
                if (bindingConfig) {
                    if (bindings.Has(key)) {
                        bindings[key] := val
                    }
                } else {    
                    apps[key] := val
                    appIcons[key] := GetIcon(val)
                }
            }
        }

        configFile.Close()

    } catch Error as e {
        MsgBox("Error reading configuration: " e.Message)
    }
}

CreateConfigFile() {
    global configFileName
    try {
        configFile := FileOpen(configFileName, "w")
        if !configFile {
            MsgBox("Could not create configuration file.")
            return
        }

        configFile.WriteLine("; App Shortcut Configuration")
        configFile.WriteLine("; There are two parts, seperated by '*' character")
        configFile.WriteLine("; Format:") 
        configFile.WriteLine("; 1st part: application_name=path_to_program")
        configFile.WriteLine("; 2nd part: function=key")
        configFile.WriteLine()
        configFile.Close()
    } catch Error as e {
        MsgBox("Error writing configuration: " e.Message)
    }
}

Execute(path) {
    try {
        Run (path)
    } catch {
        MsgBox("File does not exist! Please check if the path in the configfile is an exe file, a shortcut/link to an exe file, a system programs e.g notepad")
    }
}

GetIcon(path) {
    global iconList
    if (RegExMatch(path, "i)^https?://")) {
        ; Attempt to find default browser
        out := ""
        RunWait "reg query HKCU\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\http\UserChoice /v ProgId", , "Hide", &out
        if RegExMatch(out, "ProgId\s+REG_SZ\s+(.+)", &match) {
            progId := match[1]
            cmdOut := ""
            RunWait 'reg query "HKCR\' progId '\shell\open\command" /ve', , "Hide", &cmdOut
            if RegExMatch(cmdOut, 'REG_SZ\s+"?([^"]+\.exe)', &cmdMatch) {
                browserExe := cmdMatch[1]
                iconIndex := IL_Add(iconList, browserExe)
                return iconIndex
            }
        }
        return -1  ; failed to resolve
    } else {
        ; Assume it's a file path
        iconIndex := IL_Add(iconList, path)
        return iconIndex
    }
}

; Flow

; Read Configuration
ReadConfiguration()



; Register UI
for app_name, path in apps {
    ; Set up ImageList for the button icons
    if (iconList && appIcons.Has(app_name)) {
        ; Create button with icon on the left
        button := shortcutList.AddButton("w200 h30 +BackgroundTrans +0x0100", "  " app_name)
        button.SetFont(fontSettings, prefferedFont)
        
        ; Apply icon to button
        SendMessage(0x1607, 1, iconList, button) ; BCM_SETIMAGELIST
        SendMessage(0x160C, 0, appIcons[app_name], button) ; BM_SETIMAGE
    } else {
        ; Fallback for when icon isn't available
        button := shortcutList.AddButton("w200 h30 +BackgroundTrans +0x0100", "    " app_name)
        button.SetFont(fontSettings, prefferedFont)
    }

    button.path_to_program := path    
    button.OnEvent("Click", (ctrl, *) => Execute(ctrl.path_to_program))
}

; bind hotkeys
for name, function in bindingFunctions {
    Hotkey(bindings[name], function)
}

shortcutList.OnEvent("Escape", (*) => HideUI())