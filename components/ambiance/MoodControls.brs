' Geometry is in the bar's own space (1728 x 120, placed at 96, 850).
sub init()
    m.row = m.top.findNode("row")
    m.GOLD = "0xE0B34AFF"
    m.CREAM = "0xEDE6CAFF"
    m.MUTED = "0xB5AF8CFF"
    m.DARK = "0x1A1408FF"
    ' focus stops, left to right
    m.stops = [
        { id: "prev", x: 404, y: 30, w: 68, h: 60 },
        { id: "play", x: 492, y: 30, w: 68, h: 60 },
        { id: "next", x: 580, y: 30, w: 68, h: 60 },
        { id: "minus", x: 670, y: 34, w: 48, h: 52 },
        { id: "plus", x: 898, y: 34, w: 48, h: 52 },
        { id: "fire", x: 982, y: 34, w: 136, h: 52 },
        { id: "music", x: 1120, y: 34, w: 136, h: 52 },
        { id: "both", x: 1258, y: 34, w: 136, h: 52 },
        { id: "dim", x: 1422, y: 30, w: 134, h: 60 },
        { id: "timer", x: 1564, y: 30, w: 138, h: 60 }
    ]
    m.focus = 1
    mp = musicNode()
    if mp <> invalid
        mp.observeFieldScoped("state", "paint")
        mp.observeFieldScoped("track", "paint")
        mp.observeFieldScoped("castDelay", "paint")
    end if
end sub

function musicNode() as dynamic
    if not m.global.hasField("music") then return invalid
    return m.global.music
end function

sub open(unused as dynamic)
    m.focus = 1
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
    mp = musicNode()
    ' now playing
    bx(26, 24, 72, 72, "pkg:/images/amb/mix-fill.9.png", "0x3A3322FF")
    icon("note", 44, 42, 36, m.GOLD)
    title = "No music playing"
    subt = "Choose Music to start a shuffle"
    playing = false
    if mp <> invalid
        tr = mp.track
        if tr <> invalid and tr.title <> invalid
            title = hClean(tr.title)
            subt = hArtist(tr.artist)
            if mp.castCount > 0
                n = mp.castCount
                w = " speakers"
                if n = 1 then w = " speaker"
                subt = subt + "  ·  on " + n.toStr() + w
            end if
        end if
        playing = (mp.state = "playing" or mp.state = "buffering")
    end if
    text(UCase(title), 116, 20, 266, hFont("caps", 30), m.CREAM)
    text(subt, 116, 62, 266, hFont("fell", 26), m.MUTED)
    ' transport
    for each b in [["prev", 404], ["play", 492], ["next", 580]]
        bx(b[1], 30, 68, 60, "pkg:/images/amb/mix-fill.9.png", "0xEDE6CAFF", 0.09)
        nm = b[0]
        if nm = "play" and playing then nm = "pause"
        icon(nm, b[1] + 18, 44, 32, m.CREAM)
    end for
    ' TV timing (only matters while the TV plays the music with the speakers)
    bx(666, 34, 284, 52, "pkg:/images/amb/mix-fill.9.png", "0xEDE6CAFF", 0.09)
    icon("minus", 680, 46, 28, m.GOLD)
    icon("sync", 724, 46, 28, m.CREAM)
    d = 1.5
    if mp <> invalid and mp.castDelay <> invalid then d = mp.castDelay
    text("Timing " + fmt1(d) + " s", 758, 46, 136, hFont("regular", 24), m.CREAM)
    icon("plus", 908, 46, 28, m.GOLD)
    bx(964, 30, 2, 60, "pkg:/images/amb/mix-fill.9.png", "0x3A3A2EFF")
    ' sound switch
    bx(978, 30, 420, 60, "pkg:/images/amb/mix-roundring.9.png", m.GOLD, 0.5)
    lab = ambSoundLabel(m.top.item)
    segs = [["fire", lab.word, [lab.icon]], ["music", "Music", ["note"]], ["both", "Both", [lab.icon, "note"]]]
    for i = 0 to 2
        x = 982 + i * 138
        on = (segs[i][0] = m.top.mode)
        col = m.CREAM
        if on
            bx(x, 34, 136, 52, "pkg:/images/amb/mix-round.9.png", m.GOLD)
            col = m.DARK
        end if
        ix = x + 14
        for each ic in segs[i][2]
            icon(ic, ix, 46, 28, col)
            ix = ix + 30
        end for
        text(segs[i][1], ix + 4, 46, 136 - (ix + 4 - x), hFont("regular", 24), col)
    end for
    bx(1410, 30, 2, 60, "pkg:/images/amb/mix-fill.9.png", "0x3A3A2EFF")
    ' dim and timer: the value sits beside its icon at the same size as every other word on the bar (walk 2, item 19)
    for each b in [["sun", 1422, 134, m.top.dimText], ["timer", 1564, 138, m.top.timerText]]
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
    mp = musicNode()
    if id = "prev" or id = "next" or id = "play"
        if mp <> invalid
            if id = "play" then mp.command = { cmd: "toggle" } else mp.command = { cmd: id }
        end if
    else if id = "minus" or id = "plus"
        if mp <> invalid
            dl = 0.1
            if id = "minus" then dl = -0.1
            mp.command = { cmd: "castNudge", delta: dl }
        end if
    else if id = "fire" or id = "music" or id = "both"
        m.top.request = { act: "mix", mode: id }
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
