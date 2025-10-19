# Mouse Presentation Controller

A AutoHotkey v2 script for controlling presentations (like Figma) using only your mouse when you don't have access to a keyboard or surface to move the mouse freely.

## Features

- **Mouse Click Navigation**: Use left/right clicks for horizontal navigation
- **Scroll Navigation**: Use mouse wheel for vertical navigation
- **Control Modifier**: XButton1/2 acts as Control key for resizing
- **Visual Feedback**: 
  - Input list showing all mappings (right side of screen)
  - Input detector showing real-time button presses (bottom right)

## Controls

### Mouse Mappings

| Mouse Input | Action | With Control (XButton) |
|------------|---------|----------------------|
| **Left Click** | Left Arrow (←) | Ctrl+Left Arrow |
| **Right Click** | Right Arrow (→) | Ctrl+Right Arrow |
| **Scroll Up** | Up Arrow (↑) | Ctrl+Up Arrow |
| **Scroll Down** | Down Arrow (↓) | Ctrl+Down Arrow |
| **XButton1** | Enable Control modifier | - |
| **XButton2** | Enable Control modifier | - |

### Keyboard Shortcuts

- **F8**: Toggle presentation mode ON/OFF
- **Escape**: Exit the script

## Usage

1. Run `mousePresentation.ahk`
2. Two UI panels will appear:
   - **Input List** (right side): Shows all available mappings
   - **Input Detector** (bottom right): Shows real-time input feedback
3. Press **F8** to activate presentation mode
   - "Mode: ACTIVE" will show in green when enabled
4. Use your mouse to navigate:
   - Click left/right to move between slides
   - Scroll to move up/down
   - Hold XButton1 or XButton2 and click/scroll to use Control modifier (for zoom/resize)
5. Press **F8** again to deactivate when done

## Visual Indicators

- **Green highlight**: Input is detected and active
- **Gray**: Normal/inactive state
- **Flashing**: Button press detected (150ms flash duration)

## Use Cases

- Figma presentations without keyboard
- PowerPoint/Google Slides presentations
- Any presentation software that uses arrow keys for navigation
- Situations where you need hands-free keyboard operation

## Requirements

- AutoHotkey v2.0 or higher
- Windows OS
- Mouse with XButton1/XButton2 (side buttons)

## Notes

- The Control modifier (XButton press) stays active for 2 seconds after pressing
- Script uses non-blocking hotkeys (`~` prefix) so original mouse functions still work
- Both UI panels stay on top of other windows for visibility
