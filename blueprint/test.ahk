#Requires AutoHotkey v2.0

ParseTemplateFile(filePath) {
    content := FileRead(filePath, "UTF-8")

    commands := Map()
    startPos := 1
    MsgBox("running")
    MsgBox(content)


    while (startPos := RegExMatch(content, "<command>([\s\S]*?)</command>", &match, startPos)) {
        commandBlock := match[1]
        MsgBox(commandBlock)
        startPos += match.Len  ; Move past the current match

        name := RegexExtract(commandBlock, "<name>([\s\S]*?)</name>")
        params := RegexExtract(commandBlock, "<params>([\s\S]*?)</params>")
        template := RegexExtract(commandBlock, "<template>([\s\S]*?)</template>")

        MsgBox(name)
        MsgBox(params)
        MsgBox(template)


        paramMap := Map()
        for param in StrSplit(params, ",") {
            parts := StrSplit(Trim(param), ":")
            paramMap[Trim(parts[1])] := Trim(parts[2])
        }

        commands[name] := Map(
            "params", paramMap,
            "template", template
        )
    }
    return commands
}

RegexExtract(haystack, regex) {
    if RegExMatch(haystack, regex, &m, 1)  
        return m[1]
    return ""
}

commands := ParseTemplateFile("test.xml")
MsgBox "Loop template:`n" commands["for-loop"]["template"] "`n" 