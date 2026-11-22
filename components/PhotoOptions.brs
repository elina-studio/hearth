sub init()
    m.top.findNode("eyebrow").font = hFont("caps", 28)
    m.top.findNode("caption").font = hFont("bold", 30)
    m.top.findNode("help").keys = [{ icon: "lr", label: "Choose" }, { text: "OK", label: "Change" }, { icon: "back", label: "Close" }]
    m.chipsGroup = m.top.findNode("chips")
    m.chipFont = hFont("bold", 24)
    ' each chip: icon, registry key, choices (value, shown text)
    m.rows = [
        { key: "fav", icon: "star" },
        { key: "photoSeconds", icon: "timer", values: ["5", "8", "15", "30"], texts: ["5 s", "8 s", "15 s", "30 s"], fallback: "8" },
        { key: "photoOrder", icon: "shuffle", values: ["shuffle", "order"], texts: ["Shuffle", "Oldest first"], fallback: "shuffle" },
        { key: "photoPan", icon: "pan", values: ["on", "off"], texts: ["Pan on", "Pan off"], fallback: "on" },
        { key: "photoSaver", icon: "moon", values: ["", "this"], texts: ["Saver off", "Saver on"], fallback: "" }
    ]
    m.sel = 0
end sub

' Called once the fields are set
sub setup(unused as dynamic)
    m.top.findNode("eyebrow").text = m.top.eyebrowText
    m.top.findNode("caption").text = m.top.captionText
    paint()
end sub

function current(r as object) as integer
    if r.values = invalid then return 0
    v = pPref(r.key, r.fallback)
    if r.key = "photoSaver" and v <> "" then v = "this"
    for i = 0 to r.values.count() - 1
        if r.values[i] = v then return i
    end for
    return 0
end function

function chipText(r as object) as string
    if r.key = "fav"
        if m.top.favourite then return "Favourite" else return "Add to favourites"
    end if
    return r.texts[current(r)]
end function

' Chips flow left to right and wrap inside the card; the focused one is gold
sub paint()
    m.chipsGroup.removeChildrenIndex(m.chipsGroup.getChildCount(), 0)
    x = 0
    y = 0
    maxW = 692
    for i = 0 to m.rows.count() - 1
        r = m.rows[i]
        focused = (i = m.sel)
        lit = (r.key = "fav" and m.top.favourite)
        lab = CreateObject("roSGNode", "Label")
        lab.font = m.chipFont
        lab.text = chipText(r)
        w = lab.boundingRect().width + 22 + 26 + 10 + 22
        if x > 0 and x + w > maxW
            x = 0
            y = y + 72
        end if
        g = m.chipsGroup.createChild("Group")
        g.translation = [x, y]
        bg = g.createChild("Poster")
        bg.uri = "pkg:/images/pill.9.png"
        bg.width = w
        bg.height = 60
        if focused then bg.blendColor = "0xE0B34AFF" else bg.blendColor = "0xEDE6CA1E"
        if focused
            ring = g.createChild("Poster")
            ring.uri = "pkg:/images/pill-ring.9.png"
            ring.blendColor = "0xE0B34AFF"
            ring.translation = [-6, -6]
            ring.width = w + 12
            ring.height = 72
        end if
        ic = g.createChild("Poster")
        ic.uri = "pkg:/images/icons/icon-" + r.icon + ".png"
        ic.width = 26
        ic.height = 26
        ic.translation = [22, 17]
        if focused then ic.blendColor = "0x1F1606FF" else if lit or r.key <> "fav" then ic.blendColor = "0xE0B34AFF" else ic.blendColor = "0xB5AF8CFF"
        lab.translation = [58, 0]
        lab.height = 60
        lab.vertAlign = "center"
        if focused then lab.color = "0x1F1606FF" else lab.color = "0xEDE6CAFF"
        g.appendChild(lab)
        x = x + w + 12
    end for
    ' size the card to its chips and sit it above the bottom edge
    h = 140 + y + 60 + 34
    m.top.findNode("cardBg").height = h
    m.top.findNode("cardRing").height = h + 20
    m.top.findNode("card").translation = [96, 1080 - 170 - h]
end sub

sub change(d as integer)
    r = m.rows[m.sel]
    if r.key = "fav"
        m.top.favourite = not m.top.favourite
        m.top.changed = { key: "fav", value: m.top.favourite }
        paint()
        return
    end if
    n = r.values.count()
    k = (current(r) + d + n) mod n
    v = r.values[k]
    if r.key = "photoSaver" and v = "this" then v = m.top.saverChoice
    pSetPref(r.key, v)
    m.top.changed = { key: r.key, value: v }
    paint()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
    n = m.rows.count()
    if key = "left" and m.sel > 0
        m.sel = m.sel - 1
        paint()
    else if key = "right" and m.sel < n - 1
        m.sel = m.sel + 1
        paint()
    else if key = "up" or key = "down"
        ' jump between the two chip rows
        if key = "up" then m.sel = 0 else m.sel = n - 1
        paint()
    else if key = "OK"
        change(1)
    else if key = "back" or key = "options"
        m.top.closed = true
    end if
    return true
end function
