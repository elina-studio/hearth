sub init()
    m.fill = m.top.findNode("fill")
    m.line = m.top.findNode("line")
    m.icon = m.top.findNode("icon")
    m.label = m.top.findNode("label")
    m.label.font = hFont("bold", 24)
end sub

sub update()
    h = 56
    hasText = m.top.text <> ""
    m.icon.uri = "pkg:/images/icons/d-" + m.top.icon + ".png"
    m.label.text = m.top.text
    w = 64
    if hasText
        tw = m.label.boundingRect().width
        w = 22 + 28 + 10 + tw + 22
        m.icon.translation = [22, 14]
        m.label.translation = [60, 0]
    else
        m.icon.translation = [18, 14]
    end if
    m.label.height = h
    w = Int(w)
    for each p in [m.fill, m.line]
        p.width = w + 24
        p.height = h + 24
    end for
    f = m.top.focused
    m.fill.visible = f
    m.line.visible = not f
    if f
        m.icon.blendColor = "0x1F1606FF"
        m.label.color = "0x1F1606FF"
    else
        m.icon.blendColor = "0xE0B34AFF"
        m.label.color = "0xEDE6CAFF"
    end if
    m.top.width = w
end sub
