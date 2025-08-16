#Requires AutoHotkey v2.0

global apps := Map()
; global appIcons := Map()
global configFileName := "appShortCutConfig.txt"
global searchTypes := Map(
    "google", "https://www.google.com/search?q=",
)
global currentSearchType := "google"

; Appearance
; backgroundColor := "Black"
; fontSettings := "s14 cWhite"
; prefferedFont := "Segoe UI"

backgroundColor := "242323"
textColor := "f9f9f9"
fontSettings := "s10 c000000"
prefferedFont := "Segoe UI"

; Menu UI
global menuUiOn := false
shortcutList := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
shortcutList.BackColor := backgroundColor
shortcutList.SetFont(fontSettings, prefferedFont)
shortcutList.MarginX := 0
shortcutList.MarginY := 0

; Search Settings UI
global searchSettingOn := false
engineSelector := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
engineSelector.BackColor := backgroundColor
engineSelector.SetFont(fontSettings, prefferedFont)
engineSelector.MarginX := 0
engineSelector.MarginY := 0

; icons
; global iconList := IL_Create()

; bindings
global bindings := Map(
    "toggleShortcutList", "!F7",
    "quickSearch", "!g",
    "toggleSearchEngineSelector", "!G"
)

bindingFunctions := Map(
    "toggleShortcutList", ToggleMenuUI,
    "quickSearch", QuickSearch,
    "toggleSearchEngineSelector", ToggleSearchEngineSelector
)

; Utilities
ToggleMenuUI(*) {
    global menuUiOn

    if (!menuUiOn) {
        ShowMenuUI()
    } else {
        HideMenuUI()
    }
}

ShowMenuUI() {
    global menuUiOn
    menuUiOn := true
    cursorX := 0
    cursorY := 0
    MouseGetPos &cursorX, &cursorY
    shortcutList.Show("x" cursorX " y" cursorY " AutoSize")
}

HideMenuUI() {
    global menuUiOn
    menuUiOn := false
    shortcutList.Hide()
}

ApplyConfig(configurableMap, key, val) {
    configurableMap[key] := val
}

IsLineComment(line) {
    if (line = "" || SubStr(line, 1, 1) = ";") {
        return true
    }
}

IsSwitchMap(line) {
    if (line = "*" || SubStr(line,1,1) = "*") {
        return true
    }
}

global configurableMaps := [apps , bindings, searchTypes]
ReadConfiguration() {
    global configFileName, apps, configurableMaps
    currentMapIndex := 1
    try {
        configFile := FileOpen(configFileName, "r")
        if !configFile {
            CreateConfigFile()
        }

        while !configFile.AtEOF {
            line := Trim(configFile.ReadLine())
            if IsLineComment(line) {
                continue
            }

            If IsSwitchMap(line) {
                currentMapIndex := currentMapIndex + 1
                if (currentMapIndex > configurableMaps.Length) {
                    break
                } else {
                    continue
                }
            }

            parts := StrSplit(line, "=", , 2)

            if (parts.Length = 2) {
                key := Trim(parts[1])
                val := Trim(parts[2])

                ApplyConfig(configurableMaps[currentMapIndex], key, val)
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

ExecuteOrSearch(path) {
    try {
        Run (path)
    } catch {
        Search(path)
    }
}

Search(query) {
    global currentSearchType, searchTypes
    query := StrReplace(query, " ", "+")  ; simple space to +
    url := searchTypes[currentSearchType] query
    run url
}

GetSelectedText() {
    selected := ""
    ClipSaved := ClipboardAll()   ; Save original clipboard (including formats)
    A_Clipboard := ""               ; Clear clipboard
    Send "^c"                  ; Copy selection
    
    if (ClipWait(2)) {
        selected := A_Clipboard
    }
    A_Clipboard := ClipSaved        ; Restore old clipboard
    return selected
}

QuickSearch(*) {
    text := GetSelectedText()
    ExecuteOrSearch(text)
}

OnSearchEngineChange(ctrl, *) {
    global currentSearchType
    currentSearchType := ctrl.Text
}

ToggleSearchEngineSelector(*) {
    global searchSettingOn

    if (!searchSettingOn) {
        ShowSearchEngineSelector()
    } else {
        HideSearchEngineSelector()
    }
}

ShowSearchEngineSelector() {
    global searchSettingOn
    searchSettingOn := true
    cursorX := 0
    cursorY := 0
    MouseGetPos &cursorX, &cursorY
    engineSelector.Show("x" cursorX " y" cursorY " AutoSize")
}

HideSearchEngineSelector() {
    global searchSettingOn
    searchSettingOn := false
    engineSelector.Hide()
}

; Flow

; Read Configuration
ReadConfiguration()



; Register UI
; menu
for app_name, path in apps {
    button := shortcutList.AddButton("w200 h30 +BackgroundTrans +0x0100", "    " app_name)
    button.SetFont(fontSettings, prefferedFont)

    button.path_to_program := path    
    button.OnEvent("Click", (ctrl, *) => Execute(ctrl.path_to_program))
}

; search engine selector
; searchSettingOn.Add("DropDownList", "vColorChoice", searchTypes)
; searchsettingOn.OnEvent(" Change", (ctrl, *) => currentSearchType := ctrl.Value)

searchEngineOptionsString := ""
for key, val in searchTypes
    searchEngineOptionsString .= key "|"
searchEngineOptions := StrSplit(searchEngineOptionsString, "|")
searchEngineOptions.Pop()

engineSelector.Add("DropDownList", "vColorChoice Choose1", searchEngineOptions)
engineSelector["ColorChoice"].OnEvent("Change", OnSearchEngineChange)

; bind hotkeys
for name, function in bindingFunctions {
    Hotkey(bindings[name], function)
}

shortcutList.OnEvent("Escape", (*) => HideMenuUI())