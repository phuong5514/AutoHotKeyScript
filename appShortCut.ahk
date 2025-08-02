#Requires AutoHotkey v2.0

global apps := Map()
global configFileName := "appShortCutConfig.txt"

; Appearance
backgroundColor := "Black"
fontSettings := "s14 cWhite"
prefferedFont := "Segoe UI"

; Menu UI
global uiOn := false
shortcutList := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
shortcutList.BackColor := backgroundColor
shortcutList.SetFont(fontSettings, prefferedFont)

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
            if (parts.Length = 2) {
                key := Trim(parts[1])
                val := Trim(parts[2])
                if (bindingConfig) {
                    if (bindings.Has(key)) {
                        bindings[key] := val
                    }
                } else {    
                    apps[key] := val
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

; Flow

; Read Configuration
ReadConfiguration()

; Register UI
for app_name, path in apps {
    button := shortcutList.AddButton("w200", app_name)
    button.path_to_program := path    
    button.OnEvent("Click", (ctrl, *) => Run(ctrl.path_to_program))
}

; bind hotkeys
for name, function in bindingFunctions {
    Hotkey(bindings[name], function)
}