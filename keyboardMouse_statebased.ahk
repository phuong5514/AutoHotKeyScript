#Requires AutoHotkey v2.0
; globals
global speed := 5
global activate := true

global moveUpKey := "Home"
global moveDownKey := "End"
global moveLeftKey := "Del"
global moveRightKey := "PgDn"
global leftClickKey := "F1"
global rightClickKey := "F2"
global scrollUpKey := "+F1"
global scrollDownKey := "+F2"
global adjustMouseSpeedUpKey := "!F3"
global adjustMouseSpeedDownKey := "!F4"
global toggleMouseKeyboardMovementKey := "!F5"
global keylist := [leftClickKey, rightClickKey, scrollUpKey, scrollDownKey, adjustMouseSpeedUpKey, adjustMouseSpeedDownKey, moveUpKey, moveDownKey, moveLeftKey, moveRightKey]

; Constants
minSpeed := 5
maxSpeed := 25
step := 1
backgroundColor := "Black"
fontSettings := "s14 cWhite"
prefferedFont := "Segoe UI"

; gui to display current mousespeed value
mouseSpeedIndicator := Gui("AlwaysOnTop")
mouseSpeedIndicator.BackColor := backgroundColor
mouseSpeedIndicator.SetFont(fontSettings, prefferedFont)
text := mouseSpeedIndicator.AddText("w100 Center", "")

bindSettings := Gui("AlwaysOnTop")
bindSettings.BackColor := backgroundColor
bindSettings.SetFont(fontSettings, prefferedFont)


; Set up the timer loop (runs every 10 ms)
SetTimer(MoveMouse, 10)

MoveMouse() {
    global speed, activate
    global moveUpKey, moveDownKey, moveLeftKey, moveRightKey
    dx := 0
    dy := 0

    if activate {
        if KeyDown(moveUpKey)
            dy := dy - speed  ; "Up"
        if KeyDown(moveDownKey)   
            dy := dy + speed  ; "Down"
        if KeyDown(moveLeftKey)
            dx := dx - speed  ; "Left"
        if KeyDown(moveRightKey)
            dx := dx + speed  ; "Right"

        if dx != 0 || dy != 0
            MouseMove(dx, dy, 0, "R") ; Relative move, 0 speed = instant
    }
}
; Helper to detect key press
KeyDown(key) => GetKeyState(key, "P")

; Suppress original function of movement keys 
Hotkey(moveUpKey, (*) => {})
Hotkey(moveDownKey, (*) => {})
Hotkey(moveRightKey, (*) => {})
Hotkey(moveLeftKey, (*) => {})


; Helper to toggle state
ToggleActivation(*) {
    global activate
    activate := !activate
    ToggleHotkeys(activate)
    MsgBox(activate ? "Movement activated" : "Movement deactivated")
}

ToggleHotkeys(state) {
    global keylist
    Loop keylist.Length
        Hotkey(keylist[A_Index], state ? "On" : "Off")
    ; Add other hotkeys here
}


IncreaseMouseMoveSpeed(*) {
    global speed, step

    if speed < maxSpeed {
        speed := speed + step
        ShowSpeed(speed)
    }
}

DecreaseMouseMoveSpeed(*) {
    global speed, step
    if speed > minSpeed {
        speed := speed - step
        ShowSpeed(speed)
    }
}


ShowSpeed(speed) {
    global mouseSpeedIndicator, text
    text.Value := "Speed: " speed
    mouseSpeedIndicator.Show("x10 y10 AutoSize NoActivate")

    SetTimer(() => mouseSpeedIndicator.Hide(), -1000) ; Auto-hide after 1 second
}

Hotkey(toggleMouseKeyboardMovementKey, ToggleActivation)


Hotkey(adjustMouseSpeedUpKey, IncreaseMouseMoveSpeed)
Hotkey(adjustMouseSpeedDownKey, DecreaseMouseMoveSpeed)

Hotkey(leftClickKey, (*) => Click("left"))
Hotkey(rightClickKey, (*) => Click("right"))
Hotkey(scrollUpKey, (*) =>  Send("{WheelUp}"))
Hotkey(scrollDownKey, (*) => Send("{WheelDown}"))




