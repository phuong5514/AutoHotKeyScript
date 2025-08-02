#Requires AutoHotkey v2.0

global activate := true
global settingsOn := false
minSpeed := 5, maxSpeed := 25, step := 1
global speed := maxSpeed
global configFileName := "keyboardMouseConfig.txt"
; global settingsButtonPositionXs := Array()
; global settingsButtonPositionYs := Array()
global settingsButtons := Array()

; Appearance
backgroundColor := "Black"
fontSettings := "s14 cWhite"
prefferedFont := "Segoe UI"

; GUI for speed indicator
mouseSpeedIndicator := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
mouseSpeedIndicator.BackColor := backgroundColor
mouseSpeedIndicator.SetFont(fontSettings, prefferedFont)
text := mouseSpeedIndicator.AddText("w100 Center", "")

; GUI for rebinding
bindingSettings := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
bindingSettings.BackColor := backgroundColor
bindingSettings.SetFont(fontSettings, prefferedFont)

; --- BINDING CONFIGURATION ---
global bindings := Map(
    "moveUp", "i",
    "moveDown", "k",
    "moveLeft", "j",
    "moveRight", "l",
    "scrollUp", "u",
    "scrollDown", "o",
    "speedUp", "!F3",
    "speedDown", "!F4",
    "toggle", "!F5",
    "showSettings", "!F6",
    "up", "Up",
    "down", "Down",
    "confirm", "Enter"
)

ReadConfiguration() ; read custom binding (only use key from the below map)

; -- HOTKEY FUNCTION MAP --
bindingFunctions := Map(
    "moveUp", (*) => {},    ; the movement keys are not binded the traditional way
    "moveDown", (*) => {},  ; so the original function of those keys still work 
    "moveLeft", (*) => {},  ; so the band-aid is to bind it to nothing at all
    "moveRight", (*) => {},

    "scrollUp", (*) => Send("{WheelUp}"),
    "scrollDown", (*) => Send("{WheelDown}"),
    "speedUp", IncreaseMouseMoveSpeed,
    "speedDown", DecreaseMouseMoveSpeed
)

; these key can not be deactivated via toggle (important buttons, the toggle button itself, etc...)
specialBindingFunctions := Map(
    "toggle", ToggleActivation,
    "showSettings", ToggleSettings 
)

; default unmodifiable keys, used for navigating settings
staticBindingFunctions := Map(
    "up", SettingsMoveUp,
    "down", SettingsMoveDown,
    "confirm", (*) => Click("left")
)

; Register all hotkeys
; normal keys
for name, function in bindingFunctions
    Hotkey(bindings[name], function)

; special non togglable keys
for name, function in specialBindingFunctions
    Hotkey(bindings[name], function)

; tried to bind these dynamically via Hotkey (bind when down and up) and including them in the mouse movement loop
; both did not emulate the hold function as well as this way
; cons of the Hotkey way: only do clicks if single binded, can emulate hold but can be interrupted randomly if bind on down and up
; cons of the movement loop: wierd global status values usage, affect performance, and still encounter problems when trying to hold
F1::LButton
F2::RButton

; --- REGISTER SETTINGS UI ---
for name, function in bindingFunctions {
    key := bindings[name]
    bindingSettings.AddText("w100", name)  ; key name
    btn := bindingSettings.AddButton("x+10 w80", key)
    btn.BindingName := name  ; Store binding name as metadata
    btn.OnEvent("Click", (ctrl, *) => ChangeBinding(ctrl))
    bindingSettings.AddText("xs y+10", "")  ; New row

    settingsButtons.Push(btn)
}

ToggleSettings(*) {
    global bindingSettings, settingsOn, activate, bindings, staticBindingFunctions
    
    if (settingsOn) {
        bindingSettings.Hide()
        settingsOn := false
        if (!activate) {
            ToggleActivation()
        }
    } else {
        bindingSettings.Show()
        settingsOn := true
        if (activate) {
            ToggleActivation()
        }
    }

    ToggleHotkeys(settingsOn, bindings, staticBindingFunctions)
}


ChangeBinding(button) {
    global bindings, bindingFunctions, activate
    name := button.BindingName
    ToolTip("Press a key to bind for " name "...")
    ih := InputHook("L1")
    ih.Start()
    ih.Wait()
    newKey := ih.Input
    
    if (newKey = "") {
        return
    }
    
    ; Check if key is already used by another binding
    for existingName, existingKey in bindings {
        if (existingName != name && newKey = existingKey) {
            ToolTip("Key already bound to " existingName)
            return
        }
    }
    
    ; Apply the new binding
    try Hotkey(bindings[name], "Off")
    bindings[name] := newKey
    ; change button's text to reflect new binding
    button.Text := newKey
    
    ; Only attempt to bind if this is a function we have
    if bindingFunctions.Has(name) {
        try Hotkey(newKey, bindingFunctions[name], activate ? "On" : "Off")
    }
    WriteConfiguration()
    ToolTip()
}


; --- MOUSE MOVEMENT LOOP ---
SetTimer(MoveMouse, 10)
MoveMouse() {
    global activate, speed, bindings
    dx := dy := 0
    if !activate
        return
    if KeyDown(bindings["moveUp"])
        dy -= speed
    if KeyDown(bindings["moveDown"])
        dy += speed
    if KeyDown(bindings["moveLeft"])
        dx -= speed
    if KeyDown(bindings["moveRight"])
        dx += speed
    if dx || dy
        MouseMove(dx, dy, 0, "R")
}
KeyDown(key) => GetKeyState(key, "P")


; --- UTILITY FUNCTIONS ---
ToggleActivation(*) {
    global activate, bindings, bindingFunctions
    activate := !activate
    ToggleHotkeys(activate, bindings, bindingFunctions)
    ToolTip("Mouse Movement: " (activate ? "ON" : "OFF"))
    SetTimer(() => ToolTip(), -1000)
}

ToggleHotkeys(state, bindings, bindingFunctions) {
    for name, function in bindingFunctions
        Hotkey(bindings[name], function, state ? "On" : "Off")
}



IncreaseMouseMoveSpeed(*) {
    global speed
    if speed < maxSpeed {
        speed += step
        ShowSpeed()
    }
}

DecreaseMouseMoveSpeed(*) {
    global speed
    if speed > minSpeed {
        speed -= step
        ShowSpeed()
    }
}

ShowSpeed() {
    global text, speed, mouseSpeedIndicator
    text.Value := "Speed: " speed
    mouseSpeedIndicator.Show("x10 y10 AutoSize NoActivate")
    SetTimer(() => mouseSpeedIndicator.Hide(), -1000)
}

ReadConfiguration() {
    global configFileName, bindings
    
    try {
        configFile := FileOpen(configFileName, "r")
        if !configFile {
            return  ; File doesn't exist yet, use defaults
        }
        
        while !configFile.AtEOF {
            line := Trim(configFile.ReadLine())
            if (line = "" || SubStr(line, 1, 1) = ";")
                continue  ; Skip empty lines and comments
                
            parts := StrSplit(line, "=", , 2)
            if (parts.Length = 2) {
                name := Trim(parts[1])
                key := Trim(parts[2])
                if bindings.Has(name)
                    bindings[name] := key
            }
        }
        configFile.Close()
    } catch Error as e {
        MsgBox("Error reading configuration: " e.Message)
    }
}

WriteConfiguration() {
    global configFileName, bindings
    
    try {
        configFile := FileOpen(configFileName, "w")
        if !configFile {
            MsgBox("Could not create configuration file.")
            return
        }
        
        configFile.WriteLine("; Keyboard Mouse Configuration")
        configFile.WriteLine("; Format: binding_name=key")
        configFile.WriteLine()
        
        for name, key in bindings {
            configFile.WriteLine(name "=" key)
        }
        configFile.Close()
    } catch Error as e {
        MsgBox("Error writing configuration: " e.Message)
    }
}

SettingsMoveUp(*) {
    cursorX := 0
    cursorY := 0
    MouseGetPos &cursorX, &cursorY
    global settingsButtons
    ; Find the current or closest button below cursor
    currentIndex := 1
    minDistance := 9999999
    
    Loop settingsButtons.Length {
        btn := settingsButtons[A_Index]
        x := y := w := h := 0
        btn.GetPos(&x, &y, &w, &h)
        btnY := y + (h/2)
        
        ; Find the closest button that's below or at the cursor
        if (btnY <= cursorY && (cursorY - btnY) < minDistance) {
            minDistance := cursorY - btnY
            currentIndex := A_Index
        }
    }
    
    ; Move to the button above the current one
    if (currentIndex > 1) {
        targetBtn := settingsButtons[currentIndex - 1]
        x := y := w := h := 0
        targetBtn.GetPos(&x, &y, &w, &h)
        MouseMove(x + (w/2), y + (h/2))
    } else {
        targetBtn := settingsButtons[currentIndex]
        x := y := w := h := 0
        targetBtn.GetPos(&x, &y, &w, &h)
        MouseMove(x + (w/2), y + (h/2))
    }


}

SettingsMoveDown(*) {
    cursorX := 0
    cursorY := 0
    MouseGetPos &cursorX, &cursorY
    global settingsButtons
    
    ; Find the current or closest button below cursor
    currentIndex := 1
    minDistance := 9999999
    
    Loop settingsButtons.Length {
        btn := settingsButtons[A_Index]
        x := y := w := h := 0
        btn.GetPos(&x, &y, &w, &h)
        btnY := y + (h/2)
        
        ; Find the closest button that's above or at the cursor
        if (btnY >= cursorY && (btnY - cursorY) < minDistance) {
            minDistance := btnY - cursorY
            currentIndex := A_Index
        }
    }
    
    ; Move to the button below the current one
    if (currentIndex < settingsButtons.Length) {
        targetBtn := settingsButtons[currentIndex + 1]
        x := y := w := h := 0
        targetBtn.GetPos(&x, &y, &w, &h)
        MouseMove(x + (w/2), y + (h/2))
    } else {
        targetBtn := settingsButtons[currentIndex]
        x := y := w := h := 0
        targetBtn.GetPos(&x, &y, &w, &h)
        MouseMove(x + (w/2), y + (h/2))
    }
}