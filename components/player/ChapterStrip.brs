sub init()
    m.top.visible = false
    m.c = hColors()
    m.top.findNode("head").font = hFont("fell", 36)
    m.top.findNode("count").font = hFont("bold", 22)
    m.row = m.top.findNode("row")
    m.bar = hBraid(m.top.findNode("barHolder"), 1720, 0)
    m.top.findNode("hints").keys = [{ icon: "lr", label: "Chapter" }, { text: "OK", label: "Jump" }, { icon: "back", label: "Back" }]
    m.f = 0
    m.cells = []
end sub

function mmss(s as float) as string
    s = Int(s)
    h = Int(s / 3600)
    mi = Int((s mod 3600) / 60)
    se = s mod 60
    ss = se.toStr()
    if se < 10 then ss = "0" + ss
    if h > 0
        ms = mi.toStr()
        if mi < 10 then ms = "0" + ms
        return h.toStr() + ":" + ms + ":" + ss
    end if
    return mi.toStr() + ":" + ss
end function

sub build()
    m.row.removeChildrenIndex(m.row.getChildCount(), 0)
    ticks = m.top.findNode("ticks")
    ticks.removeChildrenIndex(ticks.getChildCount(), 0)
    m.cells = []
    ch = m.top.chapters
    if ch = invalid then return
    m.top.findNode("count").text = ch.count().toStr()
    x = 0
    for i = 0 to ch.count() - 1
        c = ch[i]
        g = m.row.createChild("Group")
        g.translation = [x, 0]
        bg = g.createChild("Rectangle")
        bg.width = 272
        bg.height = 153
        bg.color = "0x1A2214FF"
        if c.thumb <> invalid and c.thumb <> ""
            p = g.createChild("Poster")
            p.uri = c.thumb
            p.width = 272
            p.height = 153
            p.loadDisplayMode = "scaleToZoom"
        else
            n = g.createChild("Label")
            n.font = hFont("bold", 64)
            n.color = "0x404B2DFF"
            n.text = (i + 1).toStr()
            n.width = 272
            n.height = 153
            n.horizAlign = "center"
            n.vertAlign = "center"
        end if
        done = g.createChild("Group")
        done.translation = [0, 166]
        t = g.createChild("Label")
        t.font = hFont("bold", 21)
        t.color = m.c.ink
        t.text = c.title
        t.width = 200
        t.maxLines = 1
        t.translation = [0, 186]
        tm = g.createChild("Label")
        tm.font = hFont("regular", 19)
        tm.color = m.c.muted
        tm.text = mmss(c.start)
        tm.width = 272
        tm.horizAlign = "right"
        tm.translation = [0, 188]
        ring = g.createChild("Poster")
        ring.uri = "pkg:/images/w/focus-ring" + hVar(i) + ".9.png"
        ring.translation = [-20, -20]
        ring.width = 312
        ring.height = 193
        moss = g.createChild("Poster")
        hMossHug(moss, 0, 0, 272, "chap" + i.toStr())
        m.cells.push({ ring: ring, moss: moss, title: t, prog: done })
        x = x + 292
        if m.top.duration > 0
            tk = ticks.createChild("Rectangle")
            tk.width = 2
            tk.height = 22
            tk.color = "0xB5AF8C8C"
            tk.translation = [100 + Int(1720 * c.start / m.top.duration), 935]
        end if
    end for
end sub

sub open(unused = invalid as dynamic)
    ch = m.top.chapters
    if ch = invalid or ch.count() = 0 then return
    cur = m.top.position
    m.f = 0
    for i = 0 to ch.count() - 1
        if ch[i].start <= cur then m.f = i
    end for
    ' progress under the chapters already watched
    for i = 0 to m.cells.count() - 1
        pg = m.cells[i].prog
        pg.removeChildrenIndex(pg.getChildCount(), 0)
        st = ch[i].start
        en = m.top.duration
        if i + 1 < ch.count() then en = ch[i + 1].start
        amt = 0
        if cur >= en
            amt = 100
        else if cur > st and en > st
            amt = 100.0 * (cur - st) / (en - st)
        end if
        if amt > 0
            b = hBraid(pg, 272, 0)
            hBraidSet(b, amt)
        end if
    end for
    if m.top.duration > 0 then hBraidSet(m.bar, 100.0 * cur / m.top.duration)
    m.top.visible = true
    m.top.setFocus(true)
    paint()
end sub

sub paint()
    for i = 0 to m.cells.count() - 1
        on = (i = m.f)
        m.cells[i].ring.visible = on
        m.cells[i].moss.visible = on
        if on then m.cells[i].title.color = "0xFFE7A0FF" else m.cells[i].title.color = m.c.ink
    end for
    ' keep the focused chapter on screen (6 fit)
    first = m.f - 4
    if first < 0 then first = 0
    m.row.translation = [100 - first * 292, 680]
end sub

function hKeyInner(key as string, press as boolean) as boolean
    if not press then return false
    if key = "left"
        if m.f > 0 then m.f = m.f - 1
        paint()
    else if key = "right"
        if m.f < m.cells.count() - 1 then m.f = m.f + 1
        paint()
    else if key = "OK"
        m.top.visible = false
        m.top.action = { cmd: "jump", to: m.top.chapters[m.f].start }
    else if key = "back" or key = "up"
        m.top.visible = false
        m.top.action = { cmd: "close" }
    else
        return false
    end if
    return true
end function

' menu sound for whatever the handler above took (source/util.brs hKeySfx)
function onKeyEvent(key as string, press as boolean) as boolean
    return hKeySfx(key, press, hKeyInner(key, press))
end function
