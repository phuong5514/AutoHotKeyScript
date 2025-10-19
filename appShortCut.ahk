#Requires AutoHotkey v2.0

global apps := Map()

global configFileName := "appShortCutConfig.txt"
global searchTypes := Map(
    "google", "https://www.google.com/search?q=",
)
global currentSearchType := "google"

backgroundColor := "363636"
textColor := "f9f9f9"
fontSettings := "s10 c000000"
prefferedFont := "Segoe UI"
altFontSettings := "s14 c000000"

; Radial Menu UI Configuration
global menuUiOn := false
global baseMenuRadius := 150  ; Base radius for small number of items
global centerRadius := 80
global minMenuRadius := 150
global maxMenuRadius := 600

; Create main radial menu GUI
shortcutList := Gui("+AlwaysOnTop -Caption +ToolWindow")
shortcutList.BackColor := backgroundColor
WinSetTransColor(backgroundColor, shortcutList)
shortcutList.SetFont(fontSettings, prefferedFont)
shortcutList.MarginX := 0
shortcutList.MarginY := 0

global appRunningCounters := Map()
global closeAllInstanceButtons := Map()
global radialSliceControls := []
global radialButtonControls := []
global processTracker := ProcessTrackerTimer(apps, appRunningCounters)

; Search Settings UI
global searchSettingOn := false
engineSelector := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
engineSelector.BackColor := backgroundColor
WinSetTransColor(backgroundColor, engineSelector)
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
    global menuUiOn, baseMenuRadius, centerRadius, minMenuRadius, maxMenuRadius, apps, radialSliceControls, radialButtonControls, appRunningCounters
    menuUiOn := true
    
    ; Get app count
    appCount := apps.Count
    
    ; Calculate ring distribution based on item count
    ; Strategy: Keep 6-8 items per ring for optimal spacing
    itemsPerRing := 8
    
    if (appCount = 0) {
        menuRadius := minMenuRadius
        numRings := 0
    } else if (appCount <= itemsPerRing) {
        ; Single ring for small lists
        numRings := 1
        menuRadius := 180
    } else if (appCount <= itemsPerRing * 2) {
        ; Two rings
        numRings := 2
        menuRadius := 250
    } else if (appCount <= itemsPerRing * 3) {
        ; Three rings
        numRings := 3
        menuRadius := 300
    } else {
        ; Four or more rings (calculate dynamically)
        numRings := Ceil(appCount / itemsPerRing)
        menuRadius := Min(200 + numRings * 50, maxMenuRadius)
    }
    
    menuSize := menuRadius * 2 + 50
    
    ; Center on screen
    centerX := (A_ScreenWidth) // 2 - menuSize
    centerY := (A_ScreenHeight) // 2 - menuSize
    
    ; Clear previous controls
    ClearRadialMenu()
    
    if (appCount = 0) {
        shortcutList.AddText("x" (menuSize//2 - 60) " y" (menuSize//2 - 15) " w120 h30 Center cWhite", "No apps configured")
        shortcutList.Show("x" centerX " y" centerY " w" menuSize " h" menuSize)
        return
    }
    
    centerOffsetX := menuSize // 2
    centerOffsetY := menuSize // 2
    
    ; Color palette for slices
    colors := ["3a3a3a", "4a4a4a", "353535", "404040", "3d3d3d", "424242", "383838", "454545"]
    
    ; Distribute items across rings
    ; Calculate items per ring to distribute evenly
    itemsDistribution := []
    remainingItems := appCount
    
    if (numRings = 1) {
        itemsDistribution.Push(appCount)
    } else {
        ; Distribute items across rings (inner rings get fewer items)
        Loop numRings {
            if (A_Index = numRings) {
                ; Last ring gets all remaining items
                itemsDistribution.Push(remainingItems)
            } else {
                ; Inner rings get proportionally fewer items
                itemsInThisRing := Max(6, Floor(itemsPerRing * (A_Index / numRings)))
                itemsInThisRing := Min(itemsInThisRing, remainingItems)
                itemsDistribution.Push(itemsInThisRing)
                remainingItems -= itemsInThisRing
            }
        }
    }
    
    ; Draw items in rings
    itemIndex := 0
    Loop numRings {
        itemsInRing := itemsDistribution[A_Index]
        anglePerSlice := 360.0 / itemsInRing
        
        ; Calculate radius for this ring (inner rings are closer to center)
        ringRadius := (menuRadius - centerRadius) * (A_Index / numRings) + centerRadius * 0.5
        
        Loop itemsInRing {
            itemIndex++
            if (itemIndex > appCount)
                break
            
            ; Get app info
            appArray := []
            for app_name, path in apps {
                appArray.Push({name: app_name, path: path})
            }
            appInfo := appArray[itemIndex]
            app_name := appInfo.name
            path := appInfo.path
            
            ; Calculate angle for this item
            startAngle := (A_Index - 1) * anglePerSlice - 90  ; Start from top
            midAngle := startAngle + (anglePerSlice / 2)
            
            ; Get color for this item
            colorIndex := Mod(itemIndex - 1, colors.Length) + 1
            sliceColor := colors[colorIndex]
            
            ; Calculate button position
            angleRad := midAngle * 3.14159265359 / 180
            btnX := centerOffsetX + Round(ringRadius * Cos(angleRad)) - 45
            btnY := centerOffsetY + Round(ringRadius * Sin(angleRad)) - 20
            
            ; Clean up display name
            isSpecialApp := SubStr(app_name, -1) = "*"
            displayName := isSpecialApp ? SubStr(app_name, 1, StrLen(app_name) - 1) : app_name
            
            ; Create button
            btn := shortcutList.AddButton("x" btnX " y" btnY " w90 h40 cWhite Background" sliceColor, displayName)
            btn.SetFont("s9 cWhite Bold", prefferedFont)
            btn.path_to_program := path
            btn.program_name := app_name
            btn.OnEvent("Click", (ctrl, *) => Execute(ctrl.path_to_program))
            radialButtonControls.Push(btn)
            
            ; Add running counter for non-web apps
            if (!IsStringAWebLink(path) && !isSpecialApp) {
                counterX := btnX + 57
                counterY := btnY - 15
                counter := shortcutList.AddText("x" counterX " y" counterY " w16 h16 Center cYellow Background" sliceColor, "0")
                counter.SetFont("s7 cYellow Bold", prefferedFont)
                appRunningCounters[app_name] := counter
            }
            
            ; Add close button for non-special apps
            if (!IsStringAWebLink(path) && !isSpecialApp) {
                closeX := btnX + 73
                closeY := btnY - 15
                closeBtn := shortcutList.AddButton("x" closeX " y" closeY " w16 h16 cRed", "×")
                closeBtn.SetFont("s8 cRed Bold", prefferedFont)
                closeBtn.program_name := app_name
                closeBtn.OnEvent("Click", (ctrl, *) => KillAllInstance(ctrl.program_name))
                radialButtonControls.Push(closeBtn)
            }
        }
    }
    
    ; Draw center circle
    centerX_circle := centerOffsetX - centerRadius//2
    centerY_circle := centerOffsetY - centerRadius//2
    ; centerCircle := shortcutList.AddProgress("x" centerX_circle " y" centerY_circle " w" centerRadius " h" centerRadius " Backgroundcccccc -Smooth", 100)
    ; radialSliceControls.Push(centerCircle)
    
    ; Center control
    editButton := shortcutList.AddButton("x" (centerOffsetX - 45) " y" (centerOffsetY - 40) " w90 h40 cWhite Background Center Background" sliceColor, "✒️")
    editButton.SetFont("s9 cWhite Bold", prefferedFont)
    global configFileName
    editButton.OnEvent("Click", (ctrl, *) => Execute(configFileName))
    radialButtonControls.Push(editButton)

    refreshButton := shortcutList.AddButton("x" (centerOffsetX - 45) " y" (centerOffsetY) " w90 h40 cWhite Background Center Background" sliceColor, "🔄️")
    refreshButton.SetFont("s9 cWhite Bold", prefferedFont)
    refreshButton.OnEvent("Click", (ctrl, *) => Reconfigure())
    radialButtonControls.Push(refreshButton)
    
    ; centerText := shortcutList.AddText("x" (centerOffsetX - 35) " y" (centerOffsetY - 12) " w70 h24 Center c333333 BackgroundTrans", "MENU")
    ; centerText.SetFont("s11 c333333 Bold", prefferedFont)
    
    shortcutList.Show("x" centerX " y" centerY " w" menuSize " h" menuSize)
    processTracker.Start()
}

RefreshRadialMenu() {
    global menuUiOn
    
    ; Stop the process tracker
    processTracker.Stop()
    
    ; Clear and hide the current menu
    ClearRadialMenu()
    shortcutList.Hide()
    
    ; Rebuild the search engine selector with new config
    RebuildSearchEngineSelector()
    
    ; Show the menu again with new configuration
    menuUiOn := false  ; Reset state
    ShowMenuUI()
}

Reconfigure() {
    ReadConfiguration()
    RefreshRadialMenu()
}

RebuildSearchEngineSelector() {
    global searchTypes, engineSelector
    
    ; Clear existing dropdown
    try {
        engineSelector.Destroy()
    }
    
    ; Recreate the engine selector GUI
    engineSelector := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
    engineSelector.BackColor := backgroundColor
    WinSetTransColor(backgroundColor, engineSelector)
    engineSelector.SetFont(fontSettings, prefferedFont)
    engineSelector.MarginX := 0
    engineSelector.MarginY := 0
    
    ; Build search engine options from updated config
    searchEngineOptionsString := ""
    for key, val in searchTypes
        searchEngineOptionsString .= key "|"
    searchEngineOptions := StrSplit(searchEngineOptionsString, "|")
    searchEngineOptions.Pop()
    
    engineSelector.Add("DropDownList", "vColorChoice Choose1", searchEngineOptions)
    engineSelector["ColorChoice"].OnEvent("Change", OnSearchEngineChange)
}

ClearRadialMenu() {
    global radialSliceControls, radialButtonControls, appRunningCounters, shortcutList
    
    ; Simply destroy all controls by recreating the GUI
    ; This is the cleanest way in AutoHotkey v2
    try {
        shortcutList.Destroy()
    }
    
    ; Recreate the shortcutList GUI
    shortcutList := Gui("+AlwaysOnTop -Caption +ToolWindow")
    shortcutList.BackColor := backgroundColor
    WinSetTransColor(backgroundColor, shortcutList)
    shortcutList.SetFont(fontSettings, prefferedFont)
    shortcutList.MarginX := 0
    shortcutList.MarginY := 0
    shortcutList.OnEvent("Escape", (*) => HideMenuUI())
    
    ; Clear the arrays
    radialSliceControls := []
    radialButtonControls := []
    
    ; Clear running counters map
    appRunningCounters := Map()
}


HideMenuUI() {
    global menuUiOn
    menuUiOn := false
    shortcutList.Hide()

    processTracker.Stop()
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
    ClearConfiguration()

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

ClearConfiguration() {
    global apps, bindings, searchTypes
    
    ; Clear all configuration maps
    apps.Clear()
    
    ; Reset bindings to defaults (keep the core hotkeys)
    bindings.Clear()
    bindings["toggleShortcutList"] := "!F7"
    bindings["quickSearch"] := "!g"
    bindings["toggleSearchEngineSelector"] := "!G"
    
    ; Reset search types to default
    searchTypes.Clear()
    searchTypes["google"] := "https://www.google.com/search?q="
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
        configFile.WriteLine("; There are three (3) parts, seperated by '*' line")
        configFile.WriteLine("; Format:") 
        configFile.WriteLine("; 1st part: application_name=path_to_program")
        configFile.WriteLine("; 1st part note: path_to_program need to be a path to an exe file, or a shortcut (.lnk file of an exe)")
        configFile.WriteLine("; 1st part note: be careful when adding and using some system program like explorer, closing all instance of those programs can be harmful to your computer (notepad is safe though), you should add an aterisk * at the end of application_name to disable the close button")
        configFile.WriteLine("; 2nd part: function=key")
        configFile.WriteLine("; 3rd part: search_type=query_href")

        configFile.WriteLine()
        configFile.Close()
    } catch Error as e {
        MsgBox("Error writing configuration: " e.Message)
    }
}

Execute(path) {
    try {
        ; check if path is a folder and not an executable file
        if (DirExist(path)) {
            CreateSubFolderMenu(path)
        } else {
            Run(path)
        }

    } catch Error as e{
        MsgBox(e.Message)   
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
    global apps
    try {
        processName := convertToProcessName(apps[app_name])
        all_pids := GetAllProcessInstancePIDs(processName)

        for pid in all_pids {
            ProcessClose(pid)
        }
    } catch Error as e {
        MsgBox(e.Message)
    }
}

IsStringAWebLink(str) {
    ; return RegExMatch(str, "i)^((https?|ftp|smtp):\/\/)?(www\.)?[a-z0-9\-]+(\.[a-z0-9\-]+)+(\/([\w\-\._~:/?#\[\]@!$&'()*+,;=])*)?$")
    return RegExMatch(str, "i)^(https?|ftp|smtp|mailto|data):\/\/|^(www\.)")
}

GetAllProcessInstancePIDs(processName) {
    all_pids := Array()
    for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process where Name='" processName "'")
        all_pids.Push(process.ProcessId)
    return all_pids
}

CountProcessInstance(path) {
    processName := convertToProcessName(path)
    all_pids := GetAllProcessInstancePIDs(processName)
    return all_pids.Length
}

convertToProcessName(path) {
    trimmedPath := TrimPath(path)
    if (!RegExMatch(trimmedPath, "\.exe$"))
        return trimmedPath ".exe"
    return trimmedPath
}

TrimPath(path) {
    ; Extract just the filename from the full path
    trimmedPath := StrSplit(path, '\').Pop()
    
    ; Remove .lnk extension if present
    if (RegExMatch(trimmedPath, "\.lnk$"))
        trimmedPath := SubStr(trimmedPath, 1, StrLen(trimmedPath) - 4)
        
    return trimmedPath
}

class ProcessTrackerTimer {
    __New(apps, counters) {
        this.counters := counters
        this.apps := apps
        this.interval := 1000
        this.timer := ObjBindMethod(this, "Tick")
    }

    Start() {
        SetTimer this.timer, this.interval
    }
    Stop() {
        ; To turn off the timer, we must pass the same object as before:
        SetTimer this.timer, 0
    }

    UpdateCounter(app_name, path) {
        if (this.counters.Has(app_name)) {
            instanceRunningCounter := this.counters[app_name]
            runningProcessCount := CountProcessInstance(path)
            instanceRunningCounter.Text := runningProcessCount > 99 ? "99+" : runningProcessCount
        }
    }

    ; In this example, the timer calls this method:
    Tick() {
        for app_name, path in this.apps {
            if (!IsStringAWebLink(path)) {
                this.UpdateCounter(app_name, path)
            }
        }
    }
}


CreateSubFolderMenu(path) {
    SubFolderUI := Gui()
    LV := SubFolderUI.Add("ListView", "r20 w400", ["Name"])
    LV.path := path

    ; Notify the script whenever the user double clicks a row:
    LV.OnEvent("DoubleClick", SubFolderMenuDoubleClick)

    ; Gather a list of file names from a folder and put them into the ListView:
    Loop Files, path "\*"
        LV.Add(, A_LoopFileName)

    ; Display the window:
    SubFolderUI.Show()
}

SubFolderMenuDoubleClick(LV, RowNumber) {
    RowText := LV.GetText(RowNumber) 
    FullPath := LV.path "\" RowText

    Execute(FullPath)
}

; Flow

; Read Configuration
ReadConfiguration()

; Register UI - Radial menu is built dynamically in ShowMenuUI()
; No pre-building needed, everything is created on-demand

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