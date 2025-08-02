*** List of scripts ***
- keyboardMouse.ahk: perform basic mouse functions using keyboard control
default configuration: 
i j k l: up left down right
u o: scroll up / down
F1 F2: left right click
alt + F3 / F4: adjust mouse speed up/down
alt + F5: toggle keyboard control (except left right click, this button, and alt+F6)
alt + F6: toggle control map / bind settings
* while in bind settings: up down arrows for up/down, enter for click (confirm)

keyboardmouse.ahk support optional custom configuration, the format is in the supplied config file

- keyboardMouse_statebased.ahk: a much more primitive version of keyboardMouse.ahk, supporting only basic functions
control: 
Home End Del PgDn: up left down right
F1 F2: left right click
Shift + F1/F2: scroll up / down
alt + F3 / F4: adjust mouse speed up/down
moveUpKey := "Home"
moveDownKey := "End"
moveLeftKey := "Del"
moveRightKey := "PgDn"
alt + F5: toggle keyboard control 

- appShortCut.ahk: a hot key to provide quick access to applications
add program to the menu via config file
control:
ctrl + F7: toggle quick access menu