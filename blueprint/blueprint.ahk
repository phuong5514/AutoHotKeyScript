#Requires AutoHotkey v2.0

global splitCharacter := A_Space
global paramValueSeperator := ":"
global backgroundColor := "ccccccc"
global textColor := "f9f9f9"
global fontSettings := "s10 c000000"
global prefferedFont := "Segoe UI"
global altFontSettings := "s14 c000000"

; ultility
StrJoin(char, list) {
    result := ""
        
    for index, item in list {
        if index > 1
            result .= char
        result .= item
    }
    return result
}


class Blueprint {
    __New(params, defaults, template) {
        this.params := params
        this.defaults := defaults
        this.template := template
    }

    ; Main expansion
    ExpandTemplate(inputs, prefix := "") {
        paramInputs := this.GetParamLine(inputs)
        tokens := this.ParseArgs(paramInputs)

        filled := Map()
        outputTemplate := this.template

        ; Fill in from flags + positional order
        posIndex := 1
        for key in this.params {
            if tokens.Has(key) { ; from --key=value
                val := tokens[key]
            } else if (posIndex <= tokens["_pos"].Length) {
                val := tokens["_pos"][posIndex]
                posIndex++
            } else {
                val := this.defaults[key]
            }

            filled[key] := val
        }

        ; Replace placeholders in template
        for k, v in filled
            outputTemplate := StrReplace(outputTemplate, "{" k "}", v)

        ; Restore prefix indentation
        result := ""
        for line in StrSplit(outputTemplate, "`n")
            result .= prefix line "`n"

        return result
    }

    GetParamLine(input) {
        ; remove the initial /{name} from the input line
        if (input = "" || !RegExMatch(input, "^/\S+"))
            return ""  ; Return empty if input is invalid
            
        ; Find the first space after the command
        spacePos := InStr(input, A_Space)
        if (!spacePos)
            return ""  ; No parameters found
            
        ; Return everything after the first space
        return SubStr(input, spacePos + 1)
    }

    ; --- Parser that supports quoted args + flags ---
    ParseArgs(input) {
        tokens := Map()
        tokens["_pos"] := []  ; ordered positional args

        i := 1
        while (i <= StrLen(input)) {
            ch := SubStr(input, i, 1)

            if (ch = " " || ch = "`t") {
                i++
                continue
            }

            if (ch = "'" || ch = "`"") {
                quote := ch
                j := i + 1
                arg := ""
                while (j <= StrLen(input)) {
                    ch2 := SubStr(input, j, 1)
                    if (ch2 = quote) {
                        break
                    }
                    arg .= ch2
                    j++
                }
                i := j + 1
                this.AddToken(tokens, arg)
                continue
            }

            ; detect flag: --key=value
            if (SubStr(input, i, 2) = "--") {
                j := i + 2
                key := ""
                val := ""
                while (j <= StrLen(input)) {
                    ch2 := SubStr(input, j, 1)
                    if (ch2 = "=") {
                        val := SubStr(input, j + 1)
                        break
                    }
                    key .= ch2
                    j++
                }

                ; strip surrounding quotes if any
                if (SubStr(val, 1, 1) = "`"") {
                    val := RegExReplace(val, "`"", "")
                } else if (SubStr(val, 1, 1) = "'") {
                    val := RegExReplace(val, "`'", "")
                }

                tokens[key] := val
                break
            }

            ; fallback: normal unquoted token
            j := i
            arg := ""
            while (j <= StrLen(input)) {
                ch2 := SubStr(input, j, 1)
                if (ch2 = " " || ch2 = "`t")
                    break
                arg .= ch2
                j++
            }
            i := j
            this.AddToken(tokens, arg)
        }

        return tokens
    }

    AddToken(tokens, value) {
        tokens["_pos"].Push(value)
    }
}

class BlueprintWarehouse {
    static DEFAULT_CONFIG_FILE := "blueprintConfig.txt"
    __New() {
        this.blueprintSetConfigFiles := Map() ; Map set name - file path
        this.names := Array()
        this.blueprints := Map() ; Map commandstring - blueprint object
        this.setKeys := Array()
        this.ReadConfigFile() 
        this.ready := false   
    }

    IsLineComment(line) {
        if (line = "" || SubStr(line, 1, 1) = ";") {
            return true
        }
    }

    ApplyConfig(configurableMap, key, val) {
        configurableMap[key] := val
    }

    ReadConfigFile() {
        ; Read the config file, load the data 
        try {
            configFile := FileOpen(BlueprintWarehouse.DEFAULT_CONFIG_FILE, "r")
            while !configFile.AtEOF {
                line := Trim(configFile.ReadLine())
                if this.IsLineComment(line) {
                    continue
                }

                parts := StrSplit(line, "=", , 2)
                if (parts.Length = 2) {
                    key := Trim(parts[1])
                    val := Trim(parts[2])

                    this.ApplyConfig(this.blueprintSetConfigFiles, key, val)
                    this.setKeys.Push(key)
                }
            }

            configFile.Close()
        } catch {
            this.WriteDefaultConfigFile()
        }
    }

    WriteDefaultConfigFile() {
        try {
            configFile := FileOpen(BlueprintWarehouse.DEFAULT_CONFIG_FILE, "w")
            if !configFile {
                MsgBox("Could not create configuration file.")
                return
            }

            configFile.WriteLine("; Blueprint configuration")
            configFile.WriteLine("; This file define what template sets (config files) the program use")
            configFile.WriteLine("; Format:") 
            configFile.WriteLine("; {set name}={path to set config file}")
            configFile.WriteLine()

            configFile.WriteLine("; ----------------------------------------------------------------")
            configFile.WriteLine("; TEMPLATE SET FILE FORMAT (referenced by the set config file)")
            configFile.WriteLine("; ----------------------------------------------------------------")
            configFile.WriteLine("; Each template block must follow the structure below:")
            configFile.WriteLine(";")
            configFile.WriteLine("; <command>")
            configFile.WriteLine(";     <name>command-name</name>")
            configFile.WriteLine(";     <params>param1=default1, param2=default2</params>")
            configFile.WriteLine(";     <template>")
            configFile.WriteLine(";         Your template content here, using {param1}, {param2}, etc.")
            configFile.WriteLine(";         Supports multiline templates as well.")
            configFile.WriteLine(";     </template>")
            configFile.WriteLine("; </command>")
            configFile.WriteLine(";")
            configFile.WriteLine("; Example:")
            configFile.WriteLine("; <command>")
            configFile.WriteLine(";     <name>for-loop</name>")
            configFile.WriteLine(";     <params>var=i, start=0, end=10, step=++</params>")
            configFile.WriteLine(";     <template>")
            configFile.WriteLine(";         for (let {var} = {start}; {var} < {end}; {var}{step}) {")
            configFile.WriteLine(";             // body")
            configFile.WriteLine(";         }")
            configFile.WriteLine(";     </template>")
            configFile.WriteLine("; </command>")
            configFile.WriteLine()

            configFile.WriteLine()
            configFile.Close()
        } catch Error as e {
            MsgBox("Error writing configuration: " e.Message)
        }
    }

    ReadBlueprintSet(setName) {
        try {
            if !this.blueprintSetConfigFiles.Has(setName)
                throw Error("Blueprint set not found: " . setName)
                
            path := this.blueprintSetConfigFiles[setName]
            configFile := FileOpen(path, "r")
            if !configFile {
                throw Error("Could not open blueprint set file")
            }

            content := configFile.Read()
            configFile.Close()

            startPos := 1
            while (startPos := RegExMatch(content, "<command>([\s\S]*?)</command>", &match, startPos)) {
                commandBlock := match[1]
                startPos += match.Len

                name := this.RegexExtract(commandBlock, "<name>([\s\S]*?)</name>")
                paramsString := this.RegexExtract(commandBlock, "<params>([\s\S]*?)</params>")
                template := this.RegexExtract(commandBlock, "<template>([\s\S]*?)</template>")
                processedTemplate := this.ProcessTemplate(template)

                if (!name || !template) {
                    continue  ; Skip invalid commands
                }

                defaultValueMap := Map()
                params := Array()
                for param in StrSplit(paramsString, ",") {
                    if !param
                        continue
                        
                    parts := StrSplit(Trim(param), ":")
                    
                    if parts.Length >= 2 {
                        key := Trim(parts[1])
                        value := Trim(parts[2])
                        params.Push(key)
                        defaultValueMap[key] := value
                    }
                }

                ; create a new blueprint and add it to blueprints
                newBlueprint := Blueprint(params, defaultValueMap, processedTemplate)
                this.blueprints[name] := newBlueprint
                this.names.Push(name)
            }
        } catch Error as e {
            this.WriteDefaultBlueprintSet(setName)
        }
    }

    ProcessTemplate(rawString) {
        ; Remove leading and trailing whitespace/newlines
        rawString := Trim(rawString, "`r`n")
        
        ; Split into lines
        lines := StrSplit(rawString, "`n")
        if (lines.Length = 0) {
            return ""
        }
        
        ; Find the minimum indentation level across all non-empty lines
        minIndent := -1  ; -1 means not set yet
        
        for _, line in lines {
            if (Trim(line) = "") {
                continue  ; Skip empty lines when calculating indentation
            }
            
            ; Count leading whitespace
            leadingSpaces := StrLen(line) - StrLen(LTrim(line))
            
            if (minIndent = -1 || leadingSpaces < minIndent) {
                minIndent := leadingSpaces
            }
        }

        ; If no minimum indentation found or it's 0, return original
        if (minIndent <= 0) {
            return rawString
        }
        
        ; Process all lines to remove the common indentation
        result := ""
        for i, line in lines {
            if (i > 1) {
                result .= "`n"  ; Add newline before all lines except the first
            }
            
            if (Trim(line) = "") {
                ; Keep empty lines as empty
                result .= ""
            } else {
                ; Remove the minimum indentation
                result .= SubStr(line, minIndent + 1)
            }
        }
        
        return result
    }

    RegexExtract(haystack, regex) {
        if RegExMatch(haystack, regex, &m, 1)  
            return Trim(m[1])
        return ""
    }

    GetBluePrint(commandString) {
        ; format {command Start char}{name} param1 param2 param3 paramx
        ; only get the name and return

        parts := StrSplit(commandString, splitCharacter)
        if (parts.Length >= 1) {
            commandName := SubStr(parts[1], 2)  ; Remove the command Start char (default is "/") from the front
            if this.blueprints.Has(commandName) {
                return this.blueprints[commandName]
            }
        }
        return ""  ; Return empty if command not found 
    }

    SwitchBlueprintSet(setName) {
        ; a bit inefficient but it's either this or having to handle a "current set" value and it's default value 
        this.blueprints.Clear()
        this.names := Array()
        this.ReadBlueprintSet(setName)
        this.ready := true
    }

    GetBluePrintSetNames() {
        return this.setKeys
    }

    GetBluePrintNames() {
        return this.names
    }

    IsSetLoaded() {
        return this.ready
    }
    
}

class AutoCompletionBox {
    static IsUiOn := false

    __New(controller) {
        this.controller := controller
        this.buffer := ""
        this.matchedSuggestions := Array()
        this.matchLimit := 10

        this.acceptKeys := ["Enter", "Tab"]
        this.suggestedItemsCount := 0
    }

    GetBuffer() {
        return this.buffer
    }

    GetUIPosition(&x, &y) {
        if (!CaretGetPos(&x, &y)) {
            MouseGetPos(&x, &y) ; fallback incase ahk can not found the caret location (vscode)
        } else {
            ; Get the handle of the active window
            activeHwnd := WinExist("A")
            
            ; Get the absolute position of the active window
            winX := 0
            winY := 0
            WinGetPos(&winX, &winY, , , activeHwnd)
            
            ; Add window position to caret position for absolute screen coordinates
            x += winX
            y += winY + 20
        }
    }

    StartAutoComplete() {
        if (AutoCompletionBox.IsUiOn) {
            return
        }

        x := -1
        y := -1
        this.GetUIPosition(&x, &y)

        this.CreateUI(x, y)
        this.SetupInputHook()
    }

    CreateUI(x, y) {
        global fontSettings, prefferedFont
        AutoCompletionBox.IsUiOn := true
        ; Add +E0x08000000 style to prevent focus stealing
        this.SuggestionUI := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000", "Autocomplete")
        this.SuggestionUI.SetFont(fontSettings, prefferedFont)
        this.SuggestionUI.MarginX := 0, this.SuggestionUI.MarginY := 0

        ; Add ListBox for suggestions with 6 visible rows and width of 200
        this.SuggestionUI.Add("ListBox", "vChoice w200", ["<no result>"])
        
        ; Create handler for selection
        OnSelect := ObjBindMethod(this, "AcceptSelection")
        this.SuggestionUI["Choice"].OnEvent("Change", OnSelect)
        
        ; Use NoActivate option to show window without focusing it
        this.SuggestionUI.Show("x" x " y" y " AutoSize NoActivate")
    }

    SetupInputHook() {
        ; Start listening for keys after "/"
        this.iHook := InputHook("V")   ; V = visible text mode
        ; Add arrow keys to the monitored keys
        this.iHook.KeyOpt("{Enter}{Esc}{Tab}{Space}", "E") ; End keys
        this.iHook.KeyOpt("{BackSpace}{Up}{Down}", "N")  ; N = notify when this key is pressed
        this.iHook.OnChar := (ih, char) => this.CaptureCharacter(char)
        this.iHook.OnKeyDown := (ih, vk, sc) => this.HandleHookVK(vk)

        this.iHook.OnEnd := (ih) => this.HandleInputEnd(ih)
        this.iHook.Start()
    }

    HandleHookVK(vk) {
        switch vk {
            case 8: this.PopCharacter() ; VK_BACKSPACE
            case 38: this.MoveSelection(-1) ; VK_UP
            case 40: this.MoveSelection(1) ; VK_DOWN
        }   
    }

    MoveSelection(direction) {
        if (!AutoCompletionBox.IsUiOn)
            return
            
        choiceCtrl := this.SuggestionUI["Choice"]
        currentIndex := choiceCtrl.Value
        
        if (this.suggestedItemsCount = 0)
            return
            
        ; Calculate the new index with wrapping
        newIndex := currentIndex + direction
        if (newIndex < 1)
            newIndex := this.suggestedItemsCount
        else if (newIndex > this.suggestedItemsCount)
            newIndex := 1
            
        ; Set the new selection
        choiceCtrl.Choose(newIndex)
    }

    PopCharacter() {
        if (StrLen(this.buffer) > 0) {
            this.buffer := SubStr(this.buffer, 1, -1)  ; Remove the last character
            this.UpdateList()
        } else if (StrLen(this.buffer) = 0) {
            ; End the suggestion after deleting the initial character
            this.CancelAutocomplete()
        }
    }

    CaptureCharacter(char) {
        this.buffer .= char
        this.UpdateList()
    }

    UpdateList() {
        if ("" = this.buffer) {
            return
        }
        commands := this.controller.GetBluePrintNames()
        
        filtered := [this.buffer]

        for cmd in commands {
            if InStr(cmd, this.buffer) {
                filtered.Push(cmd)
                if (filtered.Length >= this.matchLimit)
                    break
            }
        }

        choiceCtrl := this.SuggestionUI["Choice"]
        choiceCtrl.Delete()
        choiceCtrl.Add(filtered)
        this.suggestedItemsCount := filtered.Length

        if (this.suggestedItemsCount > 0) {
            choiceCtrl.Choose(1)
        }
    }

    HandleInputEnd(ih) {
        if (!AutoCompletionBox.IsUiOn) {
            return  ; Already destroyed, don't proceed
        }
        
        ; Check if the end was triggered by an accept key
        for acceptKey in this.acceptKeys {
            if (ih.EndKey = acceptKey) {
                Send("{BackSpace}") ; negate the keys normal function
                this.AcceptSelection()
                return
            }
        }
        
        ; If we get here, it wasn't an accept key, so cancel
        this.CancelAutocomplete()
    }

    AcceptSelection(*) {
        if (!AutoCompletionBox.IsUiOn) {
            return
        }
        
        choiceCtrl := this.SuggestionUI["Choice"]
        this.InsertSelection(choiceCtrl)
        this.CancelAutocomplete() ; weird naming choice I know
    }

    CancelAutocomplete() {
        this.EndInputHook()
        this.EndAutocomplete()
    }

    EndInputHook() {
        if (this.iHook) {
            this.iHook.Stop()
            this.iHook := ""
        }
    }

    EndAutocomplete() {
        if (AutoCompletionBox.IsUiOn) {
            this.SuggestionUI.Destroy()
            this.buffer := ""
            AutoCompletionBox.IsUIOn := false
        }
    }

    InsertSelection(ctrl, *) {
        choice := ctrl.Text
        resultStr := choice " "
        ClipSaved := ClipboardAll()  
        A_Clipboard := resultStr
        
        if (ClipWait(1)) {  ; Wait for clipboard to contain data
            if (choice != "" && choice != "<no match>") {
                Send "+^{Left}"
                Send "^v"
            }
            Sleep 500  ; Small delay to ensure paste completes before restoring clipboard
        }
        
        A_Clipboard := ClipSaved  ; Restore original clipboard
    }
}

class App {
    static DEFAULT_CONFIG_FILE := "blueprintAppConfig.txt"
    static IsUiOn := false

    __New() {
        this.bindings := Map(
            "toggleSelector", "!s",
            "runCommand", "!a",
            "commandStart", "/"
        )

        this.InitialUiSetup()
        this.InitialWarehouseSetup()
        this.ReadConfigFile()
        this.SetBinding()
        this.AutoCompletionBoxSetup()
        this.SelectorUiSetup()
    }

    AutoCompletionBoxSetup() {
        this.autoComplete := AutoCompletionBox(this)
    }

    InitialUiSetup() {
        global backgroundColor, prefferedFont, fontSettings
        this.SelectorUI := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
        this.SelectorUI.BackColor := backgroundColor
        this.SelectorUI.SetFont(fontSettings, prefferedFont)
        this.SelectorUI.MarginX := 12
        this.SelectorUI.MarginY := 12
    }

    SelectorUiSetup() {
        try {
            this.SelectorUI.AddText(, "Set:     ")
            this.SelectorUI.Add("DropDownList", "x+10 vSetChoice w650", this.warehouse.GetBluePrintSetNames())
            this.SelectorUI["SetChoice"].OnEvent("Change", ObjBindMethod(this, "OnBlueprintSetChange"))
            this.SearchUiSetup()
            this.ListUiSetup()
            
            ; Select first set by default
            setNames := this.warehouse.GetBluePrintSetNames()
            if (setNames.Length > 0) {
                this.SelectorUI["SetChoice"].Choose(1)
                this.warehouse.SwitchBlueprintSet(setNames[1])
                this.RefreshBlueprintList()
            }
        } catch Error as e {
            MsgBox(e.Message)
        }
    }

    SearchUiSetup() {
        try {
            this.SelectorUI.AddText("xm y+10", "Search: ")
            this.SelectorUI.AddEdit("x+5 vSearchBar r1 w605 h24", "")
            searchButton := this.SelectorUI.AddButton("Default w40 x+5 h24 yp", "🔍")

            OnSearch := ObjBindMethod(this, "SearchTemplate")
            searchButton.OnEvent("Click", OnSearch)
            this.SelectorUI["SearchBar"].OnEvent("Change", OnSearch)
        } catch Error as e {
            MsgBox(e.Message)
        }
    }

    ListUiSetup() {
        try {
            ; Create ListView with columns for commands, parameters, and templates
            this.SelectorUI.AddText("xm y+10", "Available Blueprints:")
            this.SelectorUI.Add("ListView", "xm y+5 r10 w700 vBlueprintList Grid", ["Command", "Parameters", "Template"])
            
            ; Set column widths
            LV := this.SelectorUI["BlueprintList"]
            LV.ModifyCol(1, 150)  ; Command column
            LV.ModifyCol(2, 200)  ; Parameters column
            LV.ModifyCol(3, 350)  ; Template column (preview)

            ; Add double-click handler to insert the selected blueprint
            LV.OnEvent("DoubleClick", ObjBindMethod(this, "InsertSelectedBlueprint"))

            ; Create buttons under the list
            this.SelectorUI.AddButton("xm y+10 w100", "Insert").OnEvent("Click", ObjBindMethod(this, "InsertSelectedBlueprint"))
        } catch Error as e {
            MsgBox(e.Message)
        }
    }

    RefreshBlueprintList() {
        LV := this.SelectorUI["BlueprintList"]
        LV.Delete()  ; Clear existing items
        
        ; Get blueprints from warehouse
        names := this.warehouse.GetBluePrintNames()
        filter := this.SelectorUI["SearchBar"].Value
        
        for name in names {
            ; Filter by search term if provided
            if (filter && !InStr(name, filter))
                continue
                
            bp := this.warehouse.blueprints[name]
            
            ; Format parameters
            paramStr := ""
            for i, param in bp.params {
                if (i > 1)
                    paramStr .= ", "
                defaultVal := bp.defaults.Has(param) ? bp.defaults[param] : ""
                paramStr .= param . ":" . defaultVal
            }
            
            ; Get template preview (first line or truncated)
            ; templatePreview := bp.template
            ; if (StrLen(templatePreview) > 50)
            ;     templatePreview := SubStr(templatePreview, 1, 47) . "..."
                
            ; Replace newlines with spaces for display
            ; templatePreview := StrReplace(templatePreview, "`n", " ")
            LV.Add(, name, paramStr, bp.template)
        }
    }

    InsertSelectedBlueprint(*) {
        LV := this.SelectorUI["BlueprintList"]
        selectedRow := LV.GetNext(0)
        
        if (selectedRow > 0) {
            commandName := LV.GetText(selectedRow, 1)
            commandStr := "/" . commandName . " "
            
            ; Hide the UI
            this.ToggleUI()
            
            ; Insert the command at cursor position
            this.WriteText(commandStr)
        }
    }

    SearchTemplate(*) {
        this.RefreshBlueprintList()
    }

    OnBlueprintSetChange(ctrl, *) {
        this.warehouse.SwitchBlueprintSet(ctrl.Text)
        ToolTip("current selected set: " ctrl.Text)
        ; SetTimer () => ToolTip(), -3000

        this.RefreshBlueprintList()
    }

    InitialWarehouseSetup() {
        this.warehouse := BlueprintWarehouse()
    }

    ToggleUI(*) {
        if (App.IsUiOn) {
            this.SelectorUI.Hide()
        } else {
            ; cursorX := 0
            ; cursorY := 0
            ; MouseGetPos &cursorX, &cursorY
            ; this.SelectorUI.Show("x" cursorX " y" cursorY " AutoSize")
            this.SelectorUI.Show()
        }

        App.IsUiOn := !App.IsUiOn
    }

    SetBinding() {
        Hotkey(this.bindings["toggleSelector"], ObjBindMethod(this, "ToggleUI"))
        hotkey(this.bindings["runCommand"], ObjBindMethod(this, "RunCommand"))
        Hotkey("~" this.bindings["commandStart"], ObjBindMethod(this, "InputCommandStartCharacter"))
    }

    ApplyConfig(configurableMap, key, val) {
        configurableMap[key] := val
    }

    IsLineComment(line) {
        if (line = "" || SubStr(line, 1, 1) = ";") {
            return true
        }
    }


    ReadConfigFile() {
        try {
            configFile := FileOpen(App.DEFAULT_CONFIG_FILE, "r")

            while !configFile.AtEOF {
                line := Trim(configFile.ReadLine())
                if this.IsLineComment(line) {
                    continue
                }

                parts := StrSplit(line, "=", , 2)

                if (parts.Length = 2) {
                    key := Trim(parts[1])
                    val := Trim(parts[2])

                    this.ApplyConfig(this.bindings, key, val)
                }
            }

            configFile.Close()
        } catch Error as e {
            ; MsgBox("Error reading configuration: " e.Message)
            this.WriteDefaultConfigFile()
        }
    }

    GetLineText() {
        selected := ""
        ClipSaved := ClipboardAll()   ; Save original clipboard (including formats)
        A_Clipboard := ""             ; Clear clipboard
        
        ; Select the current line of text
        Send "{Home}"
        Send "{Home}"                 ; Go to beginning of line
        Send "+{End}"                 ; Select to end of line

        Send "^c"                     ; Copy selection
        
        if (ClipWait(2)) {
            selected := A_Clipboard
        }
        A_Clipboard := ClipSaved      ; Restore old clipboard
        return selected
    }

    RunCommand(*) {
        line := this.GetLineText()    ; Added this. prefix
        if ("" = line) {
            return
        }

        trimmedLine := Trim(line) ; we want to preserve the initial number of tab / spaces before the starting character '/'
        if ("/" = SubStr(trimmedLine, 1, 1)) { ; detect begining of command
            blueprint := this.warehouse.GetBluePrint(trimmedLine)
            commandStartPos := InStr(line, trimmedLine)
            prefix := SubStr(line, 1, commandStartPos - 1)
            ; prefix := Substr(line, 1, StrLen(RTrim(line)) - StrLen(trimmedLine)) ; get the spaces / tabs before the starting character '/'
            if (blueprint = "") {
                ToolTip("No items matched the comand")
                SetTimer () => ToolTip(), -3000
                return
            } else {
                result := blueprint.ExpandTemplate(line, prefix)
                ; write the result
                this.DeleteLine()     ; Added this. prefix
                this.WriteText(result) ; Added this. prefix
            }
        } else {
            ; do nothing
        }
    }

    DeleteLine(full := true) {
        if (full) {
            Send "{Home}"
        }
        Send "{Home}"             ; Go to beginning of line
        Send "+{End}"    
        Send "{Del}"
    }

    WriteText(str) {
        ClipSaved := ClipboardAll()  
        A_Clipboard := str
        
        if (ClipWait(1)) {  ; Wait for clipboard to contain data
            Send "^v"
            Sleep 500  ; Small delay to ensure paste completes before restoring clipboard
        }
        
        A_Clipboard := ClipSaved  ; Restore original clipboard
    }

    WriteDefaultConfigFile() {
        try {
            configFile := FileOpen(App.DEFAULT_CONFIG_FILE, "w")
            if !configFile {
                MsgBox("Could not create configuration file.")
                return
            }

            configFile.WriteLine("; Blueprint App Configuration")
            configFile.WriteLine("; This file defines hotkeys and other settings")
            configFile.WriteLine("; Format: key=value")
            configFile.WriteLine()
            
            configFile.WriteLine("; Keyboard Shortcuts")
            configFile.WriteLine("; Alt+S to toggle the selector UI")
            configFile.WriteLine("toggleSelector=!s")
            configFile.WriteLine("; Alt+A to execute the current command")
            configFile.WriteLine("runCommand=!a")
            configFile.WriteLine()
            
            configFile.Close()
        } catch Error as e {
            MsgBox("Error writing configuration: " e.Message)
        }
    }

    GetBluePrintNames() {
        return this.warehouse.GetBluePrintNames()
    }

    InputCommandStartCharacter(*) {
        SetTimer(() => this.CheckCommandStart(), -50)  ; Call after 50ms
    }

    CheckCommandStart() {
        line := this.GetLineText()
        Send "{Right}" 
        raw := Trim(line)
        if (raw = this.bindings["commandStart"] && this.warehouse.IsSetLoaded()) {
            this.StartAutoComplete()
        }
    }

    StartAutoComplete() {
        this.autoComplete.StartAutoComplete()
    }
}

program := App()
