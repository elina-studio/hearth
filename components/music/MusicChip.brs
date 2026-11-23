sub init()
    m.base = m.top.findNode("base")
    m.fill = m.top.findNode("fill")
    m.ring = m.top.findNode("ring")
    m.icon = m.top.findNode("icon")
    m.label = m.top.findNode("label")
    m.label.font = hFont("bold", 28)
    m.badgeL = m.top.findNode("badge")
    m.badgeL.font = hFont("bold", 22)
    update()
end sub

sub update()
    if m.top.big then h = 84 else h = 64
    ic = 34
    if m.top.big then ic = 40
    text = m.top.text
    badge = m.top.badge
    if text = "" and badge = ""
        w = h
        ix = (h - ic) / 2
    else
        ix = 22
        w = ix + ic
        if text <> "" then w = w + 12 + Len(text) * 15
        if badge <> "" then w = w + 8 + Len(badge) * 13
        w = w + 24
    end if
    m.top.width = w
    m.top.height = h
    for each p in [m.base, m.fill, m.ring]
        p.width = w
        p.height = h
    end for
    if m.top.icon <> "" then m.icon.uri = "pkg:/images/music/icons/" + m.top.icon + ".png" else m.icon.uri = ""
    m.icon.width = ic
    m.icon.height = ic
    m.icon.translation = [ix, (h - ic) / 2]
    m.label.text = text
    m.label.translation = [ix + ic + 12, 0]
    m.label.height = h
    m.badgeL.text = badge
    m.badgeL.height = h
    if text <> "" then m.badgeL.translation = [ix + ic + 12 + Len(text) * 15 + 8, 0] else m.badgeL.translation = [ix + ic + 4, 0]
    ' focused: a warm gold glow with a gold ring, and the icon and word stay white so they read on the TV
    f = m.top.focused
    m.base.visible = not f
    m.fill.visible = f
    m.fill.blendColor = "0xE0B34A80"
    m.ring.visible = f or m.top.on
    if f
        c = "0xFFFFFFFF"
    else if m.top.on
        c = "0xE0B34AFF"
    else
        c = "0xFFFFFFFF"
    end if
    m.icon.blendColor = c
    m.label.color = c
    m.badgeL.color = c
end sub
