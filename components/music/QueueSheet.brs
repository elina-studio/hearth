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
    drawHeader(g, p, q)
    if n = 0
        label(g, "Nothing is queued yet. Add songs from an album or artist.", [40, 170], 800, "regular", 26, "0xB5AF8CFF")
        return
    end if
    if p.index < 0 or p.index >= n then return
    label(g, "Now playing", [40, 160], 400, "regular", 22, "0xB5AF8CFF")
    drawRow(900, 192, q[p.index], false, true, "")
    cnt = upCount()
    label(g, "Coming up", [40, 286], 400, "regular", 22, "0xB5AF8CFF")
    rows = 6
    if m.sel >= cnt then m.sel = cnt - 1
    if m.sel < 0 then m.sel = 0
    if m.sel < m.topRow then m.topRow = m.sel
    if m.sel > m.topRow + rows - 1 then m.topRow = m.sel - rows + 1
    for r = 0 to rows - 1
        k = m.topRow + r
        if k >= cnt then exit for
        drawRow(k, 322 + r * 78, q[p.index + 1 + k], (m.zone = "list" and k = m.sel), false, (k + 1).toStr())
    end for
    if cnt = 0 then label(g, "That's the last song.", [40, 334], 600, "regular", 24, "0xB5AF8CFF")
    if cnt > rows
        label(g, "▲ ▼", [800, 286], 70, "regular", 20, "0xB5AF8CFF").horizAlign = "right"
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

' "Up next · from" the album, playlist or radio the queue came from, with its cover and how many songs are left
sub drawHeader(g as object, p as object, q as object)
    n = q.count()
    src = p.source
    name = ""
    kind = ""
    if src <> invalid
        name = pxStr(src.label)
        kind = pxStr(src.kind)
    end if
    first = invalid
    if n > 0 then first = q[0]
    ' a list of songs from one album (played from the artist page) counts as that album
    if kind = "" and n > 0 and first.albumId <> "" and q[n - 1].albumId = first.albumId then kind = "album"
    title = name
    sub2 = ""
    thumb = ""
    if first <> invalid then thumb = first.thumb
    if p.radioOn
        title = p.radioName
        if title = "" then title = "Radio"
        sub2 = "Radio"
    else if kind = "album"
        if title = "" and first <> invalid then title = first.album
        if first <> invalid then sub2 = first.artist
    else if kind = "playlist"
        sub2 = "Playlist"
    else if kind = "artist"
        sub2 = "All their songs"
    else if kind = "all"
        title = "All your music"
        sub2 = "Shuffled"
        thumb = ""
    else if kind = "nearest"
        sub2 = "Songs that sound alike"
    end if
    if title = "" then title = "Your queue"
    rest = upCount()
    if n = 0
        cnt = ""
    else if rest = 0
        cnt = "Last song"
    else if rest = 1
        cnt = "1 song left"
    else
        cnt = rest.toStr() + " songs left"
    end if
    if sub2 <> "" and cnt <> "" then sub2 = sub2 + " · " + cnt else sub2 = sub2 + cnt
    bx = g.createChild("Rectangle")
    bx.translation = [40, 26]
    bx.width = 110
    bx.height = 110
    bx.color = "0x1D2418FF"
    if thumb <> ""
        ap = g.createChild("Poster")
        ap.translation = [40, 26]
        ap.width = 110
        ap.height = 110
        ap.loadDisplayMode = "scaleToZoom"
        ap.uri = pxImage(thumb, 110, 110)
    else
        ic = g.createChild("Poster")
        if p.radioOn then ic.uri = "pkg:/images/music/icons/radio.png" else ic.uri = "pkg:/images/music/icons/queue.png"
        ic.translation = [73, 59]
        ic.width = 44
        ic.height = 44
        ic.blendColor = "0xE0B34AFF"
    end if
    label(g, "Up next · from", [172, 28], 680, "fell", 26, "0xD9A066FF")
    label(g, title, [172, 60], 690, "bold", 34, "0xEDE6CAFF")
    label(g, sub2, [172, 106], 690, "regular", 20, "0xB5AF8CFF")
end sub
