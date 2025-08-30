#Requires AutoHotkey v2.0

global splitCharacter := A_Space
global paramValueSeperator := ":"

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
                this.names := name
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
    }

    GetBluePrintSetNames() {
        return this.setKeys
    }

    GetBluePrintNames() {
        return this.names
    }
    
}

class App {
    static DEFAULT_CONFIG_FILE := "blueprintAppConfig.txt"
    static IsSelectorUIOn := false
    static IsSuggestionUIOn := false

    static backgroundColor := "ccccccc"
    static textColor := "f9f9f9"
    static fontSettings := "s10 c000000"
    static prefferedFont := "Segoe UI"
    static altFontSettings := "s14 c000000"

    __New() {
        this.bindings := Map(
            "toggleSelector", "!s",
            "runCommand", "!a",
            "commandStart", "/"
        )

        this.SuggestionBuffer := "" ; capture inputs after the commandStart character
        this.SuggestionList := []

        this.matchLimit := 6

        this.InitialUiSetup()
        this.InitialWarehouseSetup()
        this.ReadConfigFile()
        this.SetBinding()

        this.SelectorUiSetup()
    }

    InitialUiSetup() {
        this.SelectorUI := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")
        this.SelectorUI.BackColor := App.backgroundColor
        this.SelectorUI.SetFont(App.fontSettings, App.prefferedFont)
        this.SelectorUI.MarginX := 0
        this.SelectorUI.MarginY := 0

        this.SuggestionUI := Gui("+AlwaysOnTop -Caption +ToolWindow + Border", "Autocomplete")
        this.SuggestionUI.BackColor := App.backgroundColor
        this.SuggestionUI.SetFont(App.fontSettings, App.prefferedFont)
        this.SuggestionUI.MarginX := 0
        this.SuggestionUI.MarginY := 0
    }

    SelectorUiSetup() {
        try {
            this.SelectorUI.Add("DropDownList", "vColorChoice", this.warehouse.GetBluePrintSetNames())
            this.SelectorUI["ColorChoice"].OnEvent("Change", ObjBindMethod(this, "OnBlueprintSetChange"))
        } catch Error as e{
            MsgBox(e.Message)
        }
    }

    ; ClearSuggestion() {
    ;     for item in this.SuggestionList {
    ;         item.Destroy()
    ;     }
    ; }

    ; SuggestionUiUpdate() {
    ;     try {
    ;         ClearSuggestion()
    ;         suggestedBlueprints := FetchSuggestionList()

    ;         this.SuggestionUI.Add("ListBox", "vChoice r5 w200 OnSelect", StrJoin("`n", suggestedBlueprints*))
    ;     } catch Error as e {
    ;         MsgBox(e.Message)
    ;     }
    ; }

    OnSelect(ctrl, info) {
        if (info.Event = "DoubleClick") {
            this.InsertSelection(ctrl)
        }
    }

    CaptureCharacter(char) {
        this.SuggestionBuffer .= char
        commands := this.warehouse.GetBluePrintNames()

        filtered := []
        for cmd in commands {
            if InStr(cmd, this.SuggestionBuffer) {
                filtered.Push(cmd)
                if (filtered.Length >= this.matchLimit)
                    break
            }
        }

        list := filtered.Length ? StrJoin("`n", filtered*) : "<no match>"

        choiceCtrl := this.SuggestionUI["Choice"]
        choiceCtrl.Delete()
        choiceCtrl.Add(list)
        choiceCtrl.Choose(1)
    }

    StartAutocomplete() {
        CaretGetPos &x, &y

        this.SuggestionUI.Destroy()  ; make sure no leftovers
        this.SuggestionUI := Gui("+AlwaysOnTop -Caption +ToolWindow", "Autocomplete")
        this.SuggestionUI.SetFont(App.fontSettings, App.prefferedFont)
        this.SuggestionUI.MarginX := 0, this.SuggestionUI.MarginY := 0
        this.SuggestionUI.Add("ListBox", "vChoice r5 w200 gOnSelect")
        this.SuggestionUI.Show("x" x " y" y " AutoSize")

        ; Start listening for keys after "/"
        iHook := InputHook("V")   ; V = visible text mode
        iHook.KeyOpt("{Enter}{Esc}{Tab}{Space}", "E") ; End keys
        iHook.OnChar := (ih, char) => this.CaptureCharacter(char)
        iHook.OnEnd  := (ih) => this.EndAutocomplete(ih)
        iHook.Start()
    }

    EndAutocomplete(ih) {
        choiceCtrl := this.SuggestionUI["Choice"]
        if (ih.EndKey = "Enter") {
            this.InsertSelection(choiceCtrl)
        }
        this.SuggestionUI.Destroy()
        this.SuggestionBuffer := ""
    }

    InsertSelection(ctrl) {
        choice := ctrl.Text
        if (choice != "" && choice != "<no match>") {
            DeleteLine(false)
            SendText "/" choice " "
        }
    }

    OnBlueprintSetChange(ctrl, *) {
        this.warehouse.SwitchBlueprintSet(ctrl.Text)
        ToolTip("current selected set: " ctrl.Text)
        SetTimer () => ToolTip(), -3000
    }

    InitialWarehouseSetup() {
        this.warehouse := BlueprintWarehouse()
    }

    ToggleUI(*) {
        if (App.IsSelectorUIOn) {
            this.SelectorUI.Hide()
        } else {
            cursorX := 0
            cursorY := 0
            MouseGetPos &cursorX, &cursorY
            this.SelectorUI.Show("x" cursorX " y" cursorY " AutoSize")
        }

        App.IsSelectorUIOn := !App.IsSelectorUIOn
    }

    SetBinding() {
        Hotkey(this.bindings["toggleSelector"], ObjBindMethod(this, "ToggleUI"))
        hotkey(this.bindings["runCommand"], ObjBindMethod(this, "RunCommand"))
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
        if (SubStr(trimmedLine, 1, 1) = this.bindings["commandStart"]) { ; detect begining of command
            blueprint := this.warehouse.GetBluePrint(trimmedLine)
            commandStartPos := InStr(line, trimmedLine)
            prefix := SubStr(line, 1, commandStartPos - 1)
            ; prefix := Substr(line, 1, StrLen(RTrim(line)) - StrLen(trimmedLine)) ; get the spaces / tabs before the starting character 
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
}

program := App()
#HotIf WinActive("Code.exe")
/::{
    ; Function to get text before caret
    GetTextBeforeCaret(n) {
        saved := ClipboardAll()
        A_Clipboard := ""
        Send "+{Left " n "}"
        Send "^c"
        Send "{Right " n "}"
        ClipWait(0.5)
        text := A_Clipboard
        A_Clipboard := saved
        return text
    }
    
    text := GetTextBeforeCaret(7)  ; get chars before caret
    if RegExMatch(text, "i)https?:|</") {
        SendText("/")  ; just type it
    } else {
        program.StartAutocomplete()
    }
    return
}

#HotIf