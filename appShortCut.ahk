#Requires AutoHotkey v2.0

global apps := Map()
global appRunningCounts := Map()
global appPIDs := Map()

global configFileName := "appShortCutConfig.txt"
global searchTypes := Map(
    "google", "https://www.google.com/search?q=",
)
global currentSearchType := "google"

backgroundColor := "ccccccc"
textColor := "f9f9f9"
fontSettings := "s10 c000000"
prefferedFont := "Segoe UI"
altFontSettings := "s14 c000000"

; Menu UI
global menuUiOn := false
shortcutList := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
shortcutList.BackColor := backgroundColor
shortcutList.SetFont(fontSettings, prefferedFont)
shortcutList.MarginX := 0
shortcutList.MarginY := 0

global appRunningCounters := Map()
global closeAllInstanceButtons := Map()

; Search Settings UI
global searchSettingOn := false
engineSelector := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
engineSelector.BackColor := backgroundColor
engineSelector.SetFont(fontSettings, prefferedFont)
engineSelector.MarginX := 0
engineSelector.MarginY := 0

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
        ; MsgBox("Error reading configuration: " e.Message)
        CreateConfigFile()
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
        configFile.WriteLine("; 3rd part: search_type=query_href")

        configFile.WriteLine()
        configFile.Close()
    } catch Error as e {
        MsgBox("Error writing configuration: " e.Message)
    }
}

Execute(name , path) {
    global appPIDs
    try {
        pid := 0
        Run(path, , , &pid)

        if (pid = 0) {
            return
        }

        if (!IsStringAWebLink(path)) {
            if (appPIDs.Has(name)) {
                appPIDs[name].Push(pid)
            } else {
                appPIDs[name] = [pid]
            }
            UpdateCounter(name)
        }
    } catch Error as e{
        MsgBox(e.Message)
        ; MsgBox("File does not exist! Please check if the path in the configfile is an exe file, a shortcut/link to an exe file, a system programs e.g notepad")
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

KillAllInstance(app_name) {
    global appPIDs
    try {
        list := appPIDs[app_name]
        if (!list) {
            return
        }
        Loop list.Length {
            MsgBox("closing " list[A_Index])
            pid := list[A_Index]
            ProcessClose(pid)
            WinClose("ahk_pid " pid)
        }

        Loop list.Length {
            list.Pop()
        }

        ResetCounter(app_name)
    } catch Error as e {
        MsgBox(e.Message)
    }
}

IsStringAWebLink(str) {
    return RegExMatch(str, "i)^(https?:\/\/)?(www\.)?[a-z0-9\-]+\.[a-z]{2,}([\/?#].*)?$")
}

UpdateCounter(app_name) {
    global appRunningCounters
    instanceRunningCount := appRunningCounts[app_name]
    if (!instanceRunningCount) {
        return
    }
    instanceRunningCount.counter += 1
    instanceRunningCount.Text := instanceRunningCount.counter

}

ResetCounter(app_name) {
    global appRunningCounters
    instanceRunningCount := appRunningCounts[app_name]
    if (!instanceRunningCount) {
        return
    }
    instanceRunningCount.counter := 0
    instanceRunningCount.Text := instanceRunningCount.counter
}

; Flow

; Read Configuration
ReadConfiguration()



; Register UI
; menu
for app_name, path in apps {
    if (!IsStringAWebLink(path)) {
        button := shortcutList.AddButton("xs w142 h30 +BackgroundTrans +0x0100", "    " app_name)
        button.SetFont(fontSettings, prefferedFont)

        button.path_to_program := path    
        button.program_name := app_name
        button.OnEvent("Click", (ctrl, *) => Execute(ctrl.program_name, ctrl.path_to_program))

        appPIDs[app_name] := Array()

        instanceRunningCount := shortcutList.AddText("w34 h30 x+0 +Center", "0")
        instanceRunningCount.SetFont(altFontSettings, prefferedFont)
        instanceRunningCount.counter := 0
        appRunningCounts[app_name] := instanceRunningCount

        closeAllButton := shortcutList.AddButton("w24 h30 x+0 +BackgroundTrans", "X")
        closeAllButton.path_to_program := path
        closeAllButton.program_name := app_name
        closeAllButton.OnEvent("Click", (ctrl, *) => KillAllInstance(ctrl.program_name))
    } else {
        button := shortcutList.AddButton("xs w200 h30 +BackgroundTrans +0x0100", "    " app_name)
        button.SetFont(fontSettings, prefferedFont)

        button.path_to_program := path    
        button.program_name := app_name
        button.OnEvent("Click", (ctrl, *) => Execute(ctrl.program_name, ctrl.path_to_program))
    }
}

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