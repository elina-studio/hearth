' Small rough-outlined tags (file info, warnings) for the details page.
' kind: "plain" (olive line, muted text), "gold" (gold line and text), "warn" (ember), "green" (no frame)
function hTag(parent as object, text as string, icon as string, kind as string) as object
    g = parent.createChild("Group")
    lineColor = "0x5F6E45FF"
    ink = "0xB5AF8CFF"
    if kind = "gold"
        lineColor = "0xE0B34AFF"
        ink = "0xE0B34AFF"
    else if kind = "warn"
        lineColor = "0xC4673AFF"
        ink = "0xE8946AFF"
    else if kind = "green"
        ink = "0x9DB878FF"
    end if
    frame = invalid
    if kind <> "green"
        frame = g.createChild("Poster")
        frame.uri = "pkg:/images/w/button-outline.9.png"
        frame.blendColor = lineColor
        frame.translation = [-12, -12]
    end if
    x = 10
    if kind = "green" then x = 0
    if icon <> ""
        ic = g.createChild("Poster")
        ic.uri = "pkg:/images/icons/d-" + icon + ".png"
        ic.width = 20
        ic.height = 20
        ic.translation = [x, 6]
        ic.blendColor = ink
        x = x + 26
    end if
    lab = g.createChild("Label")
    if kind = "green"
        lab.font = hFont("regular", 22)
        lab.text = text
    else
        lab.font = hFont("caps", 22)
        lab.text = UCase(text)
    end if
    lab.color = ink
    lab.height = 32
    lab.vertAlign = "center"
    lab.translation = [x, 0]
    w = x + lab.boundingRect().width + 10
    if frame <> invalid
        frame.width = Int(w) + 24
        frame.height = 32 + 24
    end if
    return g
end function

' A score: small caps source name and a big number ("IMDB 8.4")
function hRating(parent as object, label as string, value as string) as object
    g = parent.createChild("Group")
    a = g.createChild("Label")
    a.font = hFont("caps", 22)
    a.color = "0xB5AF8CFF"
    a.text = UCase(label)
    a.height = 32
    a.vertAlign = "bottom"
    b = g.createChild("Label")
    b.font = hFont("bold", 26)
    b.color = "0xEDE6CAFF"
    b.text = value
    b.height = 32
    b.vertAlign = "bottom"
    b.translation = [a.boundingRect().width + 8, 3]
    return g
end function
