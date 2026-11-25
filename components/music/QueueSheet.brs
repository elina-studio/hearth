sub init()
    m.body = m.top.findNode("body")
    m.sel = 0
    m.topRow = 0
    m.zone = "list"
    m.foot = 0
    m.grab = false
    p = muPlayer()
    p.observeFieldScoped("queue", "draw")
    p.observeFieldScoped("index", "draw")
end sub

sub open()
    m.sel = 0
    m.topRow = 0
    m.zone = "list"
    m.foot = 0
    m.grab = false
    if upCount() = 0 then m.zone = "foot"
    draw()
end sub

function upCount() as integer
    p = muPlayer()
    if p.queue = invalid then return 0
    n = p.queue.count() - p.index - 1
    if n < 0 then n = 0
    return n
end function

function label(parent as object, text as string, xy as object, w as integer, kind as string, size as integer, color as string) as object
    l = parent.createChild("Label")
    l.font = hFont(kind, size)
    l.text = text
    l.translation = xy
    l.width = w
    l.maxLines = 1
    l.color = color
    return l
end function

sub drawRow(i as integer, y as integer, tr as object, focused as boolean, isNow as boolean, numText as string)
    g = m.body
    ink = "0xEDE6CAFF"
    mut = "0xB5AF8CFF"
    if focused
        ink = "0x1F1606FF"
        mut = "0x1F1606FF"
        bgp = g.createChild("Poster")
        bgp.uri = "pkg:/images/w/button-fill" + hVar(i * 7 + 3) + ".9.png"
        bgp.translation = [28, y - 12]
        bgp.width = 854
        bgp.height = 102
        bgp.blendColor = "0xE0B34AFF"
    else if isNow
        bgp = g.createChild("Poster")
        bgp.uri = "pkg:/images/w/button-fill" + hVar(i * 7 + 3) + ".9.png"
        bgp.translation = [28, y - 12]
        bgp.width = 854
        bgp.height = 102
        bgp.blendColor = "0xE0B34A24"
    end if
    if isNow
        ic = g.createChild("Poster")
        ic.uri = "pkg:/images/music/icons/play.png"
        ic.translation = [52, y + 22]
        ic.width = 28
        ic.height = 28
        ic.blendColor = "0xE0B34AFF"
    else
        label(g, numText, [40, y + 20], 56, "bold", 26, mut).horizAlign = "center"
    end if
    ab = g.createChild("Rectangle")
    ab.translation = [104, y + 8]
    ab.width = 54
    ab.height = 54
    ab.color = "0x1D2418FF"
    ap = g.createChild("Poster")
    ap.translation = [104, y + 8]
    ap.width = 54
    ap.height = 54
    ap.loadDisplayMode = "scaleToZoom"
    ap.uri = pxImage(tr.thumb, 54, 54)
    label(g, tr.title, [178, y + 4], 560, "bold", 26, ink)
    label(g, tr.artist, [178, y + 38], 560, "regular", 21, mut)
    if focused and m.grab
        label(g, "Moving", [700, y + 20], 150, "bold", 24, ink).horizAlign = "right"
    else
        label(g, pxClock(tr.duration), [700, y + 20], 150, "regular", 22, mut).horizAlign = "right"
    end if
end sub

sub draw()
    g = m.body
    g.removeChildrenIndex(g.getChildCount(), 0)
    p = muPlayer()
    q = p.queue
    if q = invalid then q = []
    n = q.count()
    gold = "0xE0B34AFF"
    ic = g.createChild("Poster")
    ic.uri = "pkg:/images/music/icons/queue.png"
    ic.translation = [40, 28]
    ic.width = 32
    ic.height = 32
    ic.blendColor = gold
    label(g, "QUEUE", [84, 26], 200, "caps", 28, "0xD9A066FF")
    rl = g.createChild("Rectangle")
    rl.translation = [220, 44]
    rl.width = 400
    rl.height = 2
    rl.color = "0xD9A06655"
    total = 0
    for each t in q
        total = total + t.duration
    end for
    mins = Int(total / 60)
    txt = n.toStr() + " songs"
    if n = 1 then txt = "1 song"
    if mins >= 60 then txt = txt + " · " + Int(mins / 60).toStr() + " hr " + (mins mod 60).toStr() + " min" else txt = txt + " · " + mins.toStr() + " min"
    label(g, txt, [560, 30], 310, "regular", 22, "0xB5AF8CFF").horizAlign = "right"
    if n = 0
        label(g, "Nothing is queued yet. Add songs from an album or artist.", [40, 120], 800, "regular", 26, "0xB5AF8CFF")
        return
    end if
    if p.index < 0 or p.index >= n then return
    label(g, "Now playing", [40, 84], 400, "regular", 22, "0xB5AF8CFF")
    drawRow(900, 118, q[p.index], false, true, "")
    cnt = upCount()
    label(g, "Up next · " + cnt.toStr(), [40, 214], 400, "regular", 22, "0xB5AF8CFF")
    if m.sel >= cnt then m.sel = cnt - 1
    if m.sel < 0 then m.sel = 0
    if m.sel < m.topRow then m.topRow = m.sel
    if m.sel > m.topRow + 6 then m.topRow = m.sel - 6
    for r = 0 to 6
        k = m.topRow + r
        if k >= cnt then exit for
        drawRow(k, 250 + r * 78, q[p.index + 1 + k], (m.zone = "list" and k = m.sel), false, (k + 1).toStr())
    end for
    if cnt = 0 then label(g, "That's the last song.", [40, 262], 600, "regular", 24, "0xB5AF8CFF")
    if cnt > 7
        label(g, "▲ ▼", [800, 214], 70, "regular", 20, "0xB5AF8CFF").horizAlign = "right"
    end if
    labels = [["close", "Clear queue"], ["shuffle", "Shuffle rest"]]
    x = 40
    for i = 0 to 1
        c = g.createChild("MusicChip")
        c.icon = labels[i][0]
        c.text = labels[i][1]
        c.translation = [x, 830]
        c.focused = (m.zone = "foot" and m.foot = i)
        x = x + c.width + 14
    end for
    if m.grab
        hint = "Up and Down move the song · OK to drop it"
    else
        hint = "OK jump to song · * pick up to move · Right removes"
    end if
    label(g, hint, [40, 900], 850, "regular", 22, "0xB5AF8CFF")
end sub

function handleKey(key as string) as string
    cnt = upCount()
    base = muPlayer().index + 1
    if m.zone = "foot"
        if key = "back" or (key = "left" and m.foot = 0)
            return "close"
        else if key = "left"
            m.foot = 0
        else if key = "right"
            if m.foot < 1 then m.foot = m.foot + 1
        else if key = "up" and cnt > 0
            m.zone = "list"
        else if key = "OK"
            if m.foot = 0
                muSend("queueClear")
                m.sel = 0
                m.topRow = 0
            else
                muSend("queueShuffleRest")
            end if
        end if
        draw()
        return ""
    end if
    if key = "back"
        if m.grab then m.grab = false else return "close"
    else if key = "left"
        if m.grab then m.grab = false else return "close"
    else if key = "up"
        if m.grab
            if m.sel > 0
                muSend("queueMove", { from: base + m.sel, to: base + m.sel - 1 })
                m.sel = m.sel - 1
            end if
        else if m.sel > 0
            m.sel = m.sel - 1
        end if
    else if key = "down"
        if m.grab
            if m.sel < cnt - 1
                muSend("queueMove", { from: base + m.sel, to: base + m.sel + 1 })
                m.sel = m.sel + 1
            end if
        else if m.sel < cnt - 1
            m.sel = m.sel + 1
        else
            m.zone = "foot"
        end if
    else if key = "OK"
        if m.grab
            m.grab = false
        else if cnt > 0
            muSend("queueJump", { i: base + m.sel })
            m.sel = 0
            m.topRow = 0
        end if
    else if key = "options"
        if cnt > 0 then m.grab = not m.grab
    else if key = "right"
        if cnt > 0 and not m.grab then muSend("queueRemove", { i: base + m.sel })
    end if
    draw()
    return ""
end function

sub muRestoreFocus()
    m.top.getParent().setFocus(true)
end sub
