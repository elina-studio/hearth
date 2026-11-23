sub init()
    m.base = m.top.findNode("base")
    m.fill = m.top.findNode("fill")
    m.ring = m.top.findNode("ring")
    m.label = m.top.findNode("label")
    m.label.font = hFont("bold", 26)
    update()
end sub

sub update()
    w = m.top.width
    if w = 0 then w = Len(m.top.text) * 18 + 64
    h = m.top.height
    for each p in [m.base, m.fill, m.ring]
        p.width = w
        p.height = h
    end for
    m.label.width = w
    m.label.height = h
    m.label.text = m.top.text
    if m.top.variant > 0
        v = hVar(m.top.variant - 1)
        m.base.uri = "pkg:/images/pill" + v + ".9.png"
        m.fill.uri = "pkg:/images/pill" + v + ".9.png"
        m.ring.uri = "pkg:/images/pill-ring" + v + ".9.png"
    end if
    m.base.visible = m.top.button and not m.top.focused
    m.fill.visible = m.top.focused
    m.ring.visible = m.top.current and not m.top.focused
    if m.top.focused
        m.label.color = "0x1F1606FF"
    else if m.top.current or m.top.button
        m.label.color = "0xEDE6CAFF"
    else
        m.label.color = "0xB5AF8CFF"
    end if
end sub
