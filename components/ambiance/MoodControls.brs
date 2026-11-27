' Geometry is in the bar's own space (1728 x 120, placed at 96, 850).
sub init()
    m.row = m.top.findNode("row")
    m.GOLD = "0xE0B34AFF"
    m.CREAM = "0xEDE6CAFF"
    m.MUTED = "0xB5AF8CFF"
    m.DARK = "0x1A1408FF"
    ' focus stops, left to right
    m.stops = [
        { id: "sound", x: 1148, y: 30, w: 170, h: 60 },
        { id: "dim", x: 1338, y: 30, w: 150, h: 60 },
        { id: "timer", x: 1508, y: 30, w: 194, h: 60 }
    ]
    m.focus = 0
end sub

function musicNode() as dynamic
    if not m.global.hasField("music") then return invalid
    return m.global.music
end function

sub open(unused as dynamic)
    m.focus = 0
    paint()
    m.top.setFocus(true)
end sub

function bx(x as integer, y as integer, w as integer, h as integer, uri as string, col as string, op = 1.0 as float) as object
    p = m.row.createChild("Poster")
    p.uri = uri
    p.translation = [x, y]
    p.width = w
    p.height = h
    p.blendColor = col
    p.opacity = op
    return p
end function

function icon(name as string, x as integer, y as integer, size as integer, col as string) as object
    return bx(x, y, size, size, "pkg:/images/amb/mix-" + name + ".png", col)
end function

function text(t as string, x as integer, y as integer, w as integer, font as object, col as string) as object
    l = m.row.createChild("Label")
    l.text = t
    l.translation = [x, y]
    l.width = w
    l.font = font
    l.color = col
    return l
end function

sub paint()
    ' music events arrive while the bar is hidden: nothing to draw then
    if not m.top.visible then return
    m.row.removeChildrenIndex(m.row.getChildCount(), 0)
    bx(0, 0, 1728, 120, "pkg:/images/amb/mix-round.9.png", "0x0A0C09FF", 0.85)
    bx(0, 0, 1728, 120, "pkg:/images/amb/mix-roundring.9.png", m.GOLD, 0.35)
    ' the mood: its name and its own line
    it = m.top.item
    lab = ambSoundLabel(it)
    bx(26, 24, 72, 72, "pkg:/images/amb/mix-fill.9.png", "0x3A3322FF")
    icon(lab.icon, 44, 42, 36, m.GOLD)
    title = ""
    subt = ""
    if it <> invalid
        if it.title <> invalid then title = it.title
        if it.sub <> invalid then subt = it.sub
    end if
    tl = text(UCase(title), 116, 20, 990, hFont("caps", 30), m.CREAM)
    tl.maxLines = 1
    sl = text(subt, 116, 62, 990, hFont("fell", 26), m.MUTED)
    sl.maxLines = 1
    bx(1128, 30, 2, 60, "pkg:/images/amb/mix-fill.9.png", "0x3A3A2EFF")
    ' sound, dim and timer: each value sits beside its icon
    for each b in [[lab.icon, 1148, 170, "Sound " + m.top.soundText], ["sun", 1338, 150, m.top.dimText], ["timer", 1508, 194, "Timer " + m.top.timerText]]
        bx(b[1], 30, b[2], 60, "pkg:/images/amb/mix-fill.9.png", "0xEDE6CAFF", 0.09)
        icon(b[0], b[1] + 12, 46, 28, m.CREAM)
        l = text(b[3], b[1] + 48, 46, b[2] - 58, hFont("regular", 24), m.CREAM)
        l.maxLines = 1
    end for
    ' focus ring
    s = m.stops[m.focus]
    bx(s.x - 4, s.y - 4, s.w + 8, s.h + 8, "pkg:/images/amb/mix-ring.9.png", m.GOLD)
end sub

function fmt1(v as float) as string
    t = Int(v * 10 + 0.5)
    return (t \ 10).toStr() + "." + (t mod 10).toStr()
end function

sub activate()
    id = m.stops[m.focus].id
    if id = "sound"
        m.top.request = { act: "sound" }
    else if id = "dim"
        m.top.request = { act: "dim" }
    else if id = "timer"
        m.top.request = { act: "timer" }
    end if
end sub

function hKeyInner(key as string, press as boolean) as boolean
    ' hidden but still holding focus (Roku keeps focus on a hidden child): let the screen behind take the key
    if not m.top.visible then return false
    if not press then return false
    if key = "left" or key = "right"
        if key = "left" then d = -1 else d = 1
        f = m.focus + d
        if f >= 0 and f < m.stops.count()
            m.focus = f
            paint()
        end if
        return true
    else if key = "OK"
        activate()
        return true
    else if key = "up" or key = "back"
        m.top.request = { act: "close" }
        return true
    else if key = "down"
        return true
    end if
    return false
end function

' menu sound for whatever the handler above took (source/util.brs hKeySfx)
function onKeyEvent(key as string, press as boolean) as boolean
    return hKeySfx(key, press, hKeyInner(key, press))
end function
