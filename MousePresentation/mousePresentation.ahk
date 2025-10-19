#Requires AutoHotkey v2.0

; Mouse Presentation Controller
; For Figma presentations when only mouse is available
; Left/Right Click = Left/Right arrows
; Scroll = Up/Down arrows
; XButton1/2 = Control modifier for resizing

global isActive := false
global controlPressed := false
global shiftPressed := false

; UI Configuration
global backgroundColor := "1a1a1a"
global highlightColor := "00ff00"
global normalColor := "666666"
global textColor := "ffffff"
global fontSettings := "s10 cFFFFFF"
global prefferedFont := "Segoe UI"

; Input List UI (right side of screen)
global inputListUI := Gui("+AlwaysOnTop -Caption +ToolWindow")
inputListUI.BackColor := backgroundColor
inputListUI.SetFont(fontSettings, prefferedFont)
inputListUI.MarginX := 10
inputListUI.MarginY := 10

; Input Detector UI (bottom right)
global inputDetectorUI := Gui("+AlwaysOnTop -Caption +ToolWindow")
inputDetectorUI.BackColor := backgroundColor
inputDetectorUI.SetFont(fontSettings, prefferedFont)
inputDetectorUI.MarginX := 5
inputDetectorUI.MarginY := 5

; Input list labels
global inputListItems := []
global detectorIndicators := Map()

; Build Input List UI
BuildInputListUI() {
    global inputListUI, inputListItems
    
    ; Title
    inputListUI.AddText("w180 Center c" textColor, "Mouse Presentation")
    inputListUI.AddText("w180 Center c" normalColor, "───────────────")
    
    ; Input mappings
    inputs := [
        "Left Click → Left",
        "Right Click → Right",
        "Scroll Up → Up",
        "Scroll Down → Down",
        "XButton1 → Zoom Modifier",
        "XButton2 → Toggle",
        "XButton1 + Scroll → Zoom",
        "MButton → Exit",

    ]
    
    for input in inputs {
        txt := inputListUI.AddText("w180 c" normalColor, input)
        inputListItems.Push(txt)
    }
    
    inputListUI.AddText("w180 Center c" normalColor, "───────────────")
    global toggleText := inputListUI.AddText("w180 Center c" highlightColor, "XButton2 to Toggle")
    
    ; Position at right side of screen
    x := A_ScreenWidth - 420
    y := 100
    inputListUI.Show("x" x " y" y " AutoSize")
}

; Build Input Detector UI
BuildInputDetectorUI() {
    global inputDetectorUI, detectorIndicators
    
    inputDetectorUI.AddText("w200 Center c" textColor, "Input Detector")
    
    ; Create indicator boxes for each input
    indicators := [
        {name: "LClick", label: "Left Click"},
        {name: "RClick", label: "Right Click"},
        {name: "ScrollUp", label: "Scroll Up"},
        {name: "ScrollDown", label: "Scroll Down"},
        {name: "XButton1", label: "XButton1"},
        {name: "XButton2", label: "XButton2"}
    ]
    
    for indicator in indicators {
        box := inputDetectorUI.AddProgress("w190 h25 Background" normalColor " -Smooth", 0)
        label := inputDetectorUI.AddText("xp yp w190 h25 Center BackgroundTrans c" textColor, indicator.label)
        detectorIndicators[indicator.name] := {box: box, label: label, timer: 0}
    }
    
    ; Position at bottom right
    x := A_ScreenWidth - 420
    y := A_ScreenHeight - 450
    inputDetectorUI.Show("x" x " y" y " AutoSize")
}

; Flash indicator when input detected
FlashIndicator(indicatorName) {
    global detectorIndicators, highlightColor, normalColor
    
    if (detectorIndicators.Has(indicatorName)) {
        indicator := detectorIndicators[indicatorName]
        
        ; Set to highlighted state
        indicator.box.Opt("Background" highlightColor)
        indicator.box.Value := 100
        ; Redraw the label to ensure it stays visible
        indicator.label.Redraw()
        
        ; Reset after 150ms
        SetTimer(() => ResetIndicator(indicatorName), -150)
    }
}

ResetIndicator(indicatorName) {
    global detectorIndicators, normalColor
    
    if (detectorIndicators.Has(indicatorName)) {
        indicator := detectorIndicators[indicatorName]
        indicator.box.Opt("Background" normalColor)
        indicator.box.Value := 0
        ; Redraw the label to ensure it stays visible
        indicator.label.Redraw()
    }
}

; Toggle presentation mode
TogglePresentationMode(*) {
    global isActive, toggleText
    
    isActive := !isActive
    
    if (isActive) {
        toggleText.Text := "Mode: ACTIVE"
        toggleText.Opt("c00ff00")
        EnableMouseHooks()
    } else {
        toggleText.Text := "Mode: INACTIVE"
        toggleText.Opt("c" normalColor)
        DisableMouseHooks()
    }
}

; Enable mouse hooks
EnableMouseHooks() {
    ; Left Click -> Left Arrow ($ prevents triggering itself)
    Hotkey("$LButton", LeftClickHandler, "On")
    
    ; Right Click -> Right Arrow
    Hotkey("$RButton", RightClickHandler, "On")
    
    ; Scroll -> Up/Down Arrows ($ prevents infinite loop)
    Hotkey("$WheelUp", ScrollUpHandler, "On")
    Hotkey("$WheelDown", ScrollDownHandler, "On")
    
    ; XButtons -> Control/Shift modifiers
    Hotkey("$XButton1", XButton1Handler, "On")
}

; Disable mouse hooks
DisableMouseHooks() {
    Hotkey("$LButton", "Off")
    Hotkey("$RButton", "Off")
    Hotkey("$WheelUp", "Off")
    Hotkey("$WheelDown", "Off")
    Hotkey("$XButton1", "Off")
    
    ; Reset modifier states immediately
    global controlPressed, shiftPressed
    controlPressed := false
    shiftPressed := false
    
    ; Clear any pending timers
    SetTimer(() => (controlPressed := false), 0)
    SetTimer(() => (shiftPressed := false), 0)
}

; Input Handlers
LeftClickHandler(*) {
    global isActive, controlPressed
    if (!isActive)
        return
    
    FlashIndicator("LClick")
    
    if (controlPressed) {
        Send("^{Left}")  ; Ctrl+Left
    } else if (shiftPressed) {
        Send("+{Left}")
    } else {
        Send("{Left}")
    }
}

RightClickHandler(*) {
    global isActive, controlPressed
    if (!isActive)
        return
    
    FlashIndicator("RClick")
    
    if (controlPressed) {
        Send("^{Right}")  ; Ctrl+Right
    } else if (shiftPressed) {
        Send("+{Right}")
    }
    else {
        Send("{Right}")
    }
}

ScrollUpHandler(*) {
    global isActive, controlPressed, shiftPressed
    if (!isActive)
        return
    
    ; Check if user is holding actual Ctrl key - allow default zoom behavior
    if (GetKeyState("Ctrl", "P")) {
        Click("WheelUp")  ; Perform actual scroll (not intercepted)
        return
    }
    
    FlashIndicator("ScrollUp")
    
    if (controlPressed) {
        Send("^{WheelUp}")  ; XButton1+Scroll = Zoom in (Ctrl+WheelUp)
    } else if (shiftPressed) {
        Send("+{Up}")
    } else {
        Send("{Up}")
    }
}

ScrollDownHandler(*) {
    global isActive, controlPressed, shiftPressed
    if (!isActive)
        return
    
    ; Check if user is holding actual Ctrl key - allow default zoom behavior
    if (GetKeyState("Ctrl", "P")) {
        Click("WheelDown")  ; Perform actual scroll (not intercepted)
        return
    }
    
    FlashIndicator("ScrollDown")
    
    if (controlPressed) {
        Send("^{WheelDown}")  ; XButton1+Scroll = Zoom out (Ctrl+WheelDown)
    } else if (shiftPressed) {
        Send("+{Down}")
    } else {
        Send("{Down}")
    }
}

XButton1Handler(*) {
    global isActive, controlPressed
    if (!isActive)
        return
    
    FlashIndicator("XButton1")
    controlPressed := true
    
    ; Release control after 2 seconds or when XButton is released
    SetTimer(() => (controlPressed := false), -2000)
}


; Build UIs
BuildInputListUI()
BuildInputDetectorUI()

; Hotkey to toggle
Hotkey("$XButton2", TogglePresentationMode)

; Allow Escape or middle mouse click to exit
inputListUI.OnEvent("Escape", (*) => ExitApp())
inputDetectorUI.OnEvent("Escape", (*) => ExitApp())

Hotkey("$MButton", (*) => ExitApp())

