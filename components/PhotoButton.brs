sub init()
    m.bg = m.top.findNode("bg")
    m.ring = m.top.findNode("ring")
    m.icon = m.top.findNode("icon")
    m.label = m.top.findNode("label")
    m.label.font = hFont("bold", 30)
end sub

sub paint()
    m.label.text = m.top.text
    if m.top.iconName <> "" then m.icon.uri = "pkg:/images/icons/icon-" + m.top.iconName + ".png"
    w = m.label.boundingRect().width + 76 + 34
    m.top.buttonWidth = w
    m.bg.width = w
    m.ring.width = w
    lit = m.top.focused
    if lit
        m.bg.blendColor = "0xE0B34AFF"
        m.label.color = "0x1F1606FF"
        m.icon.blendColor = "0x1F1606FF"
    else
        m.bg.blendColor = "0xEDE6CA22"
        m.label.color = "0xEDE6CAFF"
        m.icon.blendColor = "0xE0B34AFF"
    end if
    ' a focused button also gets the glow ring, so it reads even next to the gold primary
    m.ring.visible = m.top.focused
end sub
