sub init()
    m.bg = m.top.findNode("bg")
    m.rule = m.top.findNode("rule")
    m.artBg = m.top.findNode("artBg")
    m.art = m.top.findNode("art")
    m.eyebrow = m.top.findNode("eyebrow")
    m.title = m.top.findNode("title")
    m.sub = m.top.findNode("sub")
    m.track = m.top.findNode("track")
    m.fill = m.top.findNode("fill")
    m.elapsed = m.top.findNode("elapsed")
    m.total = m.top.findNode("total")
    m.chips = m.top.findNode("chips")
    m.chipName = m.top.findNode("chipName")
    m.castList = m.top.findNode("castList")
    m.scrobTick = m.top.findNode("scrobTick")
    m.scrobText = m.top.findNode("scrobText")
    m.scrobText.font = hFont("regular", 22)
    m.idle = m.top.findNode("idle")
    m.idleOn = false
    m.idleSel = 0
    m.idleItems = []
    m.castTop = 0
    m.names = { more: "More", prev: "Previous", toggle: "Play", next: "Next", shuffle: "Shuffle", repeat: "Repeat", cover: "Cover", milk: "Visualizer", hearth: "Hearth fire", big: "Big view", library: "Back to the library", cast: "Play in other rooms", like: "Like", dislike: "Dislike", queue: "Queue" }
    m.r = 0
    m.c = 1
    p = muPlayer()
    for each f in ["track", "state", "shuffle", "repeat", "queue", "liked"]
        p.observeFieldScoped(f, "showNow")
    end for
    p.observeFieldScoped("position", "showTime")
    p.observeFieldScoped("castCount", "showNow")
    p.observeFieldScoped("lfmState", "showScrob")
    p.observeFieldScoped("rooms", "drawCast")
    p.observeFieldScoped("castDelay", "drawCast")
    if p.hasField("castLagShown") then p.observeFieldScoped("castLagShown", "drawCast")
    build()
end sub

' rows of [icon, word, action]; "sep" draws a divider
sub build()
    m.chips.removeChildrenIndex(m.chips.getChildCount(), 0)
    m.grid = []
    m.capLabels = invalid
    m.rule.visible = false
    m.elapsed.visible = true
    m.total.visible = true
    m.track.height = 8
    m.fill.height = 8
    m.castList.visible = false
    if m.top.layout = "bar"
        ' 1920 x 130 along the bottom of a screen
        m.bg.visible = true
        m.bg.width = 1920
        m.bg.height = 130
        m.bg.color = "0x141A11FF"
        m.rule.visible = true
        m.artSize = 100
        place(m.artBg, [96, 15], 100, 100)
        place(m.art, [96, 15], 100, 100)
        x = 224
        w = 560
        setText(m.eyebrow, [x, 14], w, "caps", 22)
        setText(m.title, [x, 40], w, "bold", 30)
        setText(m.sub, [x, 80], w, "regular", 22)
        m.barX = x
        m.barW = w
        m.track.translation = [x, 116]
        m.fill.translation = [x, 116]
        m.track.height = 6
        m.fill.height = 6
        setText(m.elapsed, [x + w + 16, 104], 120, "regular", 20)
        m.total.visible = false
        addRow([860, 23], [["prev", "", "prev"], ["play", "", "toggle"], ["next", "", "next"], ["shuffle", "", "shuffle"], ["repeat", "", "repeat"], ["", "", "sep"], ["expand", "Big view", "big"]], 0)
        setText(m.chipName, [1560, 50], 300, "regular", 22)
    else if m.top.layout = "big"
        m.bg.visible = false
        m.artSize = 600
        place(m.artBg, [96, 110], 600, 600)
        place(m.art, [96, 110], 600, 600)
        x = 780
        w = 1040
        setText(m.eyebrow, [x, 200], w, "caps", 30)
        setText(m.title, [x, 238], w, "bold", 56)
        setText(m.sub, [x, 318], w, "regular", 32)
        m.barX = x
        m.barW = w
        m.track.translation = [x, 420]
        m.fill.translation = [x, 420]
        setText(m.elapsed, [x, 438], 300, "regular", 24)
        setText(m.total, [x + w - 300, 438], 300, "regular", 24)
        addRow([x, 490], [["prev", "", "prev"], ["play", "", "toggle"], ["next", "", "next"], ["shuffle", "", "shuffle"], ["repeat", "", "repeat"], ["", "", "sep"], ["cover", "", "cover"], ["viz", "", "milk"], ["fire", "", "hearth"]], 0)
        ' the Library button sits at the right end of the same row
        lib = m.chips.createChild("MusicChip")
        lib.icon = "collapse"
        lib.text = "Library"
        lib.translation = [x + w - lib.width, 500]
        m.grid[0].push({ node: lib, action: "library" })
        setText(m.chipName, [x, 598], 600, "regular", 24)
    else if m.top.castOpen
        ' the column with the room list: small art and titles side by side, then the rooms
        m.bg.visible = true
        m.artSize = 170
        place(m.artBg, [96, 36], 170, 170)
        place(m.art, [96, 36], 170, 170)
        x = 290
        w = 266
        setText(m.eyebrow, [x, 48], w, "caps", 22)
        setText(m.title, [x, 78], w, "bold", 34)
        setText(m.sub, [x, 128], w, "regular", 22)
        m.barX = x
        m.barW = w
        m.track.translation = [x, 186]
        m.fill.translation = [x, 186]
        m.track.height = 6
        m.fill.height = 6
        m.elapsed.visible = false
        m.total.visible = false
        addRow([96, 232], [["prev", "", "prev"], ["play", "", "toggle"], ["next", "", "next"], ["cast", "", "cast"]], 0)
        setText(m.chipName, [96, 930], 10, "regular", 22)
        m.castList.visible = true
    else
        m.bg.visible = true
        m.artSize = 440
        place(m.artBg, [96, 40], 440, 440)
        place(m.art, [96, 40], 440, 440)
        x = 96
        w = 440
        setText(m.eyebrow, [x, 504], w, "caps", 26)
        setText(m.title, [x, 538], w, "bold", 44)
        setText(m.sub, [x, 600], w, "regular", 26)
        m.barX = x
        m.barW = w
        m.track.translation = [x, 652]
        m.fill.translation = [x, 652]
        setText(m.elapsed, [x, 668], 200, "regular", 24)
        setText(m.total, [x + w - 200, 668], 200, "regular", 24)
        ' five big controls with a word under each (UX review item 4); everything else is under More
        addRow([x, 714], [["prev", "", "prev"], ["play", "", "toggle"], ["next", "", "next"], ["shuffle", "", "shuffle"], ["more", "", "more"]], 0)
        slot = Int(w / 5)
        m.capLabels = {}
        for i = 0 to m.grid[0].Count() - 1
            it = m.grid[0][i]
            c = it.node
            c.translation = [x + i * slot + Int((slot - c.width) / 2), c.translation[1]]
            l = m.chips.createChild("Label")
            l.translation = [x + i * slot - 10, 806]
            l.width = slot + 20
            l.horizAlign = "center"
            l.font = hFont("regular", 24)
            l.color = "0xB5AF8CFF"
            m.capLabels[it.action] = l
        end for
        setText(m.chipName, [x, 888], 10, "regular", 22)
    end if
    m.track.width = m.barW
    ' Last.fm: a tick where the song counts (half way), and a word once it has
    m.scrobTick.translation = [m.track.translation[0] + m.barW / 2 - 2, m.track.translation[1] - 12]
    m.scrobText.translation = [m.track.translation[0] + m.barW / 2 - 110, m.track.translation[1] + 16]
    m.scrobText.width = 220
    m.track.visible = false
    m.fill.visible = false
    if m.braid <> invalid then m.top.removeChild(m.braid)
    m.braid = hBraid(m.top, m.barW, 0)
    m.braid.translation = [m.track.translation[0], m.track.translation[1] + m.track.height / 2 - 6]
    if m.top.castOpen and m.top.layout = "column"
        drawCast()
    else
        if m.r >= m.grid.Count() then m.r = 0
        if m.c >= m.grid[m.r].Count() then m.c = 0
    end if
    showNow()
end sub

sub place(n as object, xy as object, w as integer, h as integer)
    n.translation = xy
    n.width = w
    n.height = h
end sub

sub setText(l as object, xy as object, w as integer, kind as string, size as integer)
    l.translation = xy
    if l.subtype() = "ScrollingLabel"
        l.maxWidth = w
        l.height = size + 12
    else
        l.width = w
    end if
    l.font = hFont(kind, size)
end sub

' Chips in one row, vertically centred on the big Play button (84 high).
sub addRow(xy as object, defs as object, r as integer)
    row = []
    x = xy[0]
    for each d in defs
        if d[2] = "sep"
            line = m.chips.createChild("Rectangle")
            line.translation = [x + 12, xy[1] + 22]
            line.width = 2
            line.height = 40
            line.color = "0xD9A06655"
            x = x + 38
        else
            if d.Count() > 3 then x = d[3]
            c = m.chips.createChild("MusicChip")
            c.icon = d[0]
            c.text = d[1]
            c.big = (d[2] = "toggle")
            c.translation = [x, xy[1] + (84 - c.height) / 2]
            x = x + c.width + 12
            row.push({ node: c, action: d[2] })
        end if
    end for
    m.grid[r] = row
end sub

sub showNow()
    n = muNow()
    p = muPlayer()
    m.eyebrow.text = n.eyebrow
    ' set the scrolling title only when it changes: setting it again restarts the scroll, which showed the
    ' title twice on top of itself (live walk Nov 27)
    hFontText(m.title, n.title, "bold")
    hFontText(m.sub, n.sub, "regular")
    if m.title.text <> n.title then m.title.text = n.title
    m.sub.text = n.sub
    if n.track <> invalid
        place(m.art, m.artBg.translation, m.artSize, m.artSize)
        m.art.uri = pxImage(n.track.thumb, m.artSize, m.artSize)
    else
        ' nothing queued: a small lantern in the middle of the art box, not one that fills the panel
        sm = Int(m.artSize / 2)
        place(m.art, [m.artBg.translation[0] + Int(sm / 2), m.artBg.translation[1] + Int(sm / 2)], sm, sm)
        m.art.uri = "pkg:/images/lantern.png"
    end if
    if not pxReady()
        m.eyebrow.text = "PLEX ISN'T LINKED"
        if m.title.text <> "Sign in to Plex" then m.title.text = "Sign in to Plex"
        m.sub.text = "Hearth's setup links Plex at plex.tv/link."
    end if
    playing = (p.state = "playing" or p.state = "buffering")
    if playing then m.names.toggle = "Pause" else m.names.toggle = "Play"
    if p.repeat = "one" then m.names.repeat = "Repeat one" else if p.repeat = "all" then m.names.repeat = "Repeat all" else m.names.repeat = "Repeat"
    if p.shuffle then m.names.shuffle = "Shuffle on" else m.names.shuffle = "Shuffle"
    for each row in m.grid
        for each it in row
            c = it.node
            if it.action = "toggle"
                if playing then c.icon = "pause" else c.icon = "play"
            else if it.action = "shuffle"
                c.on = p.shuffle
            else if it.action = "repeat"
                c.on = (p.repeat <> "off")
                if p.repeat = "one" then c.badge = "1" else c.badge = ""
            else if it.action = "like"
                c.on = (p.liked = "like")
            else if it.action = "dislike"
                c.on = (p.liked = "dislike")
            else if it.action = "cast"
                c.on = (p.castCount > 0)
                if p.castCount > 0 then c.badge = p.castCount.toStr() else c.badge = ""
            end if
        end for
    end for
    if m.capLabels <> invalid
        for each k in m.capLabels
            if m.names[k] <> invalid then m.capLabels[k].text = m.names[k]
        end for
    end if
    showTime()
    idleNow = (m.top.layout = "column" and not m.top.castOpen and n.track = invalid and pxReady())
    m.idleOn = idleNow
    paint()
end sub

' ---------- nothing queued ----------
function idleLast() as dynamic
    reg = CreateObject("roRegistrySection", "hearth")
    v = reg.Read("lastPlay")
    if v = invalid or v = "" then return invalid
    bits = v.Split("|")
    if bits.count() < 4 or bits[3] = "" then return invalid
    if bits[0] <> "c" and bits[0] <> "r" then return invalid
    return { mode: bits[0], kind: bits[1], id: bits[2], label: bits[3] }
end function

sub onRecent()
    drawIdle()
end sub

sub drawIdle()
    m.idle.visible = m.idleOn
    m.idle.removeChildrenIndex(m.idle.getChildCount(), 0)
    m.idleItems = []
    if not m.idleOn then return
    ' covers the empty player underneath; the same tone as the panel
    cover = m.idle.createChild("Rectangle")
    cover.width = 620
    cover.height = 930
    cover.color = "0x131611FF"
    k = m.idle.createChild("Label")
    k.font = hFont("caps", 24)
    k.color = "0xE0B34AFF"
    k.text = "NOTHING PLAYING"
    k.translation = [96, 40]
    h = m.idle.createChild("Label")
    h.font = hFont("bold", 44)
    h.color = "0xEDE6CAFF"
    h.text = "What shall we hear?"
    h.width = 460
    h.translation = [96, 72]
    y = 152
    m.idleItems.push({ kind: "btn", y: y, h: 84, icon: "shuffle", caption: "Shuffle my music", act: "shuffleAll" })
    y = y + 84 + 14
    lp = idleLast()
    if lp <> invalid
        m.idleItems.push({ kind: "btn", y: y, h: 72, icon: "play", caption: "Carry on: " + lp.label, act: "carry", last: lp })
        y = y + 72 + 14
    end if
    rec = m.top.recent
    if rec <> invalid and rec.count() > 0
        y = y + 22
        t = m.idle.createChild("Label")
        t.font = hFont("fell", 30)
        t.color = "0xEDE6CAFF"
        t.text = "Played lately"
        t.translation = [96, y]
        y = y + 50
        for i = 0 to rec.count() - 1
            if i < 4
                m.idleItems.push({ kind: "row", y: y, h: 84, md: rec[i], act: "recent" })
                y = y + 84
            end if
        end for
    end if
    if m.idleSel >= m.idleItems.count() then m.idleSel = 0
    for i = 0 to m.idleItems.count() - 1
        it = m.idleItems[i]
        g = m.idle.createChild("Group")
        g.translation = [96, it.y]
        focused = (m.top.active and i = m.idleSel)
        if it.kind = "btn"
            bg = g.createChild("Poster")
            bg.translation = [-12, -12]
            bg.width = 460 + 24
            bg.height = it.h + 24
            ink = "0xEDE6CAFF"
            if focused
                bg.uri = "pkg:/images/w/button-fill-v2.9.png"
                bg.blendColor = "0xE0B34AFF"
                ink = "0x1F1606FF"
            else
                bg.uri = "pkg:/images/w/button-outline-v2.9.png"
                ' the first choice keeps a gold edge so it reads as the main one
                if i = 0 then bg.blendColor = "0xE0B34AFF" else bg.blendColor = "0x5F6E45FF"
            end if
            ic = g.createChild("Poster")
            ic.uri = "pkg:/images/music/icons/" + it.icon + ".png"
            ic.width = 32
            ic.height = 32
            ic.blendColor = ink
            ic.translation = [28, Int(it.h / 2) - 16]
            l = g.createChild("Label")
            if i = 0 then l.font = hFont("bold", 32) else l.font = hFont("bold", 26)
            l.text = it.caption
            l.color = ink
            l.width = 460 - 78 - 20
            l.maxLines = 1
            l.height = it.h
            l.vertAlign = "center"
            l.translation = [78, 0]
        else
            if focused
                bg = g.createChild("Poster")
                bg.uri = "pkg:/images/w/panel.9.png"
                bg.blendColor = "0x1E2716FF"
                bg.translation = [-24, -8]
                bg.width = 460 + 36
                bg.height = 72 + 16
                ring = g.createChild("Poster")
                ring.uri = "pkg:/images/w/focus-ring.9.png"
                ring.translation = [-39, -23]
                ring.width = 460 + 66
                ring.height = 72 + 46
            end if
            ab = g.createChild("Rectangle")
            ab.width = 64
            ab.height = 64
            ab.color = "0x1D2418FF"
            ab.translation = [0, 4]
            art = g.createChild("Poster")
            art.width = 64
            art.height = 64
            art.loadDisplayMode = "scaleToZoom"
            art.translation = [0, 4]
            if it.md.thumb <> invalid then art.uri = pxImage(it.md.thumb, 128, 128)
            l = g.createChild("Label")
            l.font = hFont("bold", 28)
            if hOutsideFont(it.md.title) then l.font = hSysFont("bold", 28)
            l.text = pxStr(it.md.title)
            if focused then l.color = "0xFFE7A0FF" else l.color = "0xEDE6CAFF"
            l.width = 372
            l.maxLines = 1
            l.translation = [82, 2]
            sb = g.createChild("Label")
            sb.font = hFont("regular", 24)
            sb.color = "0xB5AF8CFF"
            who = pxStr(it.md.parentTitle)
            if who = "" and pxStr(it.md.type) = "playlist" then who = "Playlist"
            if who = "" and pxStr(it.md.type) = "artist" then who = "Artist"
            sb.text = who
            sb.width = 372
            sb.maxLines = 1
            sb.translation = [82, 38]
        end if
    end for
end sub

function idleKey(key as string) as string
    n = m.idleItems.count()
    edge = ""
    if key = "up"
        if m.idleSel > 0 then m.idleSel = m.idleSel - 1 else edge = "up"
    else if key = "down"
        if m.idleSel < n - 1 then m.idleSel = m.idleSel + 1 else edge = "down"
    else if key = "left" or key = "right"
        edge = key
    else if key = "OK" and n > 0
        it = m.idleItems[m.idleSel]
        if it.act = "shuffleAll"
            muSend("shuffleAll")
        else if it.act = "carry"
            if it.last.mode = "c"
                muSend("playContainer", { kind: it.last.kind, id: it.last.id, shuffle: false, label: it.last.label })
            else
                muSend("radioStart", { kind: it.last.kind, mood: it.last.id, moodName: it.last.label })
            end if
        else
            muSend("playContainer", { kind: pxStr(it.md.type), id: pxStr(it.md.ratingKey), shuffle: false, label: pxStr(it.md.title) })
        end if
    else if key = "options"
        muOptions(true)
    end if
    drawIdle()
    return edge
end function

sub showScrob()
    s = muPlayer().lfmState
    show = (s <> "off" and (m.top.layout = "column" or m.top.layout = "big") and not m.top.castOpen)
    m.scrobTick.visible = show
    m.scrobText.visible = show
    if s = "counted"
        m.scrobTick.color = "0xFFE7A0FF"
        m.scrobText.color = "0xE0B34AFF"
        m.scrobText.text = "Scrobbled"
    else if s = "queued"
        m.scrobTick.color = "0x5E5A44FF"
        m.scrobText.color = "0xB5AF8CFF"
        m.scrobText.text = "Last.fm: will retry"
    else
        m.scrobTick.color = "0x5E5A44FF"
        m.scrobText.text = ""
    end if
end sub

sub showTime()
    showScrob()
    p = muPlayer()
    if p.track = invalid
        m.fill.width = 0
        setBraid(0)
        m.elapsed.text = ""
        m.total.text = ""
        return
    end if
    d = p.duration
    if d > 0 then m.fill.width = m.barW * p.position / d else m.fill.width = 0
    setBraid(m.fill.width)
    m.elapsed.text = pxClock(p.position)
    m.total.text = pxClock(d)
    if m.top.layout = "bar" then m.elapsed.text = pxClock(p.position) + " / " + pxClock(d)
end sub

sub paint()
    name = ""
    drawIdle()
    if m.top.castOpen and m.top.layout = "column" then drawCast()
    for r = 0 to m.grid.Count() - 1
        for c = 0 to m.grid[r].Count() - 1
            on = (m.top.active and r = m.r and c = m.c)
            m.grid[r][c].node.focused = on
            if on then name = m.names[m.grid[r][c].action]
        end for
    end for
    if name = invalid then name = ""
    m.chipName.text = name
end sub

function handleKey(key as string) as string
    if m.top.castOpen and m.top.layout = "column"
        edge = castKey(key)
        paint()
        return edge
    end if
    if m.idleOn then return idleKey(key)
    row = m.grid[m.r]
    edge = ""
    if key = "left"
        if m.c > 0 then m.c = m.c - 1 else edge = "left"
    else if key = "right"
        if m.c < row.Count() - 1 then m.c = m.c + 1 else edge = "right"
    else if key = "up"
        if m.r > 0
            m.r = m.r - 1
            if m.c >= m.grid[m.r].Count() then m.c = m.grid[m.r].Count() - 1
        else
            edge = "up"
        end if
    else if key = "down"
        if m.r < m.grid.Count() - 1
            m.r = m.r + 1
            if m.c >= m.grid[m.r].Count() then m.c = m.grid[m.r].Count() - 1
        else
            edge = "down"
        end if
    else if key = "OK"
        act(row[m.c].action)
    else if key = "options"
        muOptions(true)
    end if
    paint()
    return edge
end function

sub act(a as string)
    if not pxReady() and a <> "cover" and a <> "milk" and a <> "hearth" and a <> "library" and a <> "big" and a <> "more" then return
    if a = "cast"
        if m.top.castOpen
            closeCast()
        else
            muSend("castRefresh")
            m.castTop = 0
            m.r = 2
            m.top.castOpen = true
        end if
    else if a = "more"
        panelMore()
    else if a = "queue"
        m.top.request = { action: "queue" }
    else if a = "big"
        m.top.request = { action: "musicView", mode: "big" }
    else if a = "library"
        m.top.request = { action: "back" }
    else if a = "prev" or a = "next"
        muSend(a)
    else if a = "like" or a = "dislike"
        muSend("rate", { value: a })
    else
        muDo(a)
    end if
end sub

sub muRestoreFocus()
    ' the dialog closing hands focus back to the scene; the parent screen takes it again
    m.top.request = { action: "refocus" }
end sub

' ---------- the room list (castOpen) ----------
' m.r: 0 = the chip row, 1 = "TV timing", 2..n = the rooms, n + 1 = Whole house

function castItems() as object
    items = [{ id: "timing", name: "TV timing", kind: "timing", on: false, vol: -1 }]
    rooms = muPlayer().rooms
    if rooms <> invalid then items.append(rooms)
    return items
end function

sub closeCast()
    m.r = 1
    m.c = 0
    m.top.castOpen = false
end sub

function castKey(key as string) as string
    items = castItems()
    n = items.Count()
    if key = "back"
        closeCast()
        return ""
    end if
    if m.r = 0
        row = m.grid[0]
        if key = "left"
            if m.c > 0 then m.c = m.c - 1 else return "left"
        else if key = "right"
            if m.c < row.Count() - 1 then m.c = m.c + 1 else return "right"
        else if key = "up"
            return "up"
        else if key = "down"
            m.r = 1
        else if key = "OK"
            act(row[m.c].action)
        end if
        return ""
    end if
    if m.r > n
        if key = "up"
            m.r = n
        else if key = "OK"
            muSend("castAll")
        else if key = "right"
            return "right"
        end if
        return ""
    end if
    it = items[m.r - 1]
    if key = "up"
        m.r = m.r - 1
    else if key = "down"
        m.r = m.r + 1
    else if key = "OK"
        if it.kind = "timing" then muSend("castResync") else muSend("castToggle", { id: it.id })
    else if key = "left" or key = "right"
        d = 1
        if key = "left" then d = -1
        if it.kind = "speaker"
            muSend("castVolume", { id: it.id, delta: 5 * d })
        else if it.kind = "timing"
            muSend("castNudge", { delta: 0.1 * d })
        else if key = "right"
            return "right"
        end if
    else if key = "options"
        muOptions(true)
    end if
    ' keep the focused room on screen (6 rows fit, 5 while the speaker-lag line takes a row)
    fit = castFit()
    if m.r >= 1 and m.r <= n
        if m.r - 1 < m.castTop then m.castTop = m.r - 1
        if m.r - 1 > m.castTop + fit - 1 then m.castTop = m.r - fit
    end if
    return ""
end function

' the measured speaker lag as "1.8", or "" while it is unknown (nothing cast yet this song)
function castTrailText() as string
    p = muPlayer()
    if not p.hasField("castLagShown") or p.castCount < 1 then return ""
    v = p.castLagShown
    if v = invalid or v < 0 then return ""
    t = Int(v * 10 + 0.5)
    return (t \ 10).toStr() + "." + (t mod 10).toStr()
end function

' rows of the room list that fit on screen
function castFit() as integer
    if castTrailText() <> "" then return 5
    return 6
end function

sub drawCast()
    if not m.top.castOpen or m.top.layout <> "column" then return
    g = m.castList
    g.removeChildrenIndex(g.getChildCount(), 0)
    gold = "0xE0B34AFF"
    dark = "0x1F1606FF"
    light = "0xEDE6CAFF"
    dimC = "0x5E5A44FF"
    ic = g.createChild("Poster")
    ic.uri = "pkg:/images/music/icons/cast.png"
    ic.translation = [96, 334]
    ic.width = 32
    ic.height = 32
    ic.blendColor = gold
    hd = g.createChild("Label")
    hd.text = "PLAYING IN"
    hd.font = hFont("caps", 26)
    hd.color = "0xD9A066FF"
    hd.translation = [140, 334]
    rl = g.createChild("Rectangle")
    rl.translation = [310, 350]
    rl.width = 246
    rl.height = 2
    rl.color = "0xD9A06655"
    items = castItems()
    n = items.Count()
    delay = muPlayer().castDelay
    trail = castTrailText()
    fit = castFit()
    slot = 0
    for k = 0 to fit - 1
        i = m.castTop + k
        if i >= n then exit for
        it = items[i]
        y = 380 + slot * 66
        slot = slot + 1
        if it.kind = "timing" and trail <> ""
            ' one muted line under TV timing with the lag measured this song, so a nudge has a starting point
            tl = g.createChild("Label")
            tl.text = "Speakers trail the TV by " + trail + " s · nudge until they meet"
            tl.font = hFont("regular", 22)
            tl.color = "0xB5AF8CFF"
            tl.translation = [112, y + 64]
            tl.width = 440
            tl.wrap = true
            tl.maxLines = 2
            tl.lineSpacing = 0
            slot = slot + 1
        end if
        f = (m.top.active and m.r = i + 1)
        on = (it.on = true)
        if f
            fg = dark
            accent = dark
        else if on or it.kind = "timing"
            fg = light
            accent = gold
        else
            fg = "0xB5AF8CFF"
            accent = dimC
        end if
        bg = g.createChild("Rectangle")
        bg.translation = [96, y]
        bg.width = 460
        bg.height = 62
        if f then bg.color = gold else bg.color = "0x00000000"
        icon = g.createChild("Poster")
        if it.kind = "tv" then icon.uri = "pkg:/images/music/icons/tv.png" else if it.kind = "timing" then icon.uri = "pkg:/images/music/icons/timing.png" else icon.uri = "pkg:/images/music/icons/speaker.png"
        icon.translation = [112, y + 15]
        icon.width = 32
        icon.height = 32
        icon.blendColor = accent
        lb = g.createChild("Label")
        lb.text = it.name
        lb.font = hFont("bold", 26)
        lb.color = fg
        lb.translation = [160, y]
        lb.width = 200
        lb.height = 62
        lb.vertAlign = "center"
        if it.kind = "speaker" and it.vol >= 0
            tr = g.createChild("Rectangle")
            tr.translation = [372, y + 28]
            tr.width = 110
            tr.height = 6
            if f then tr.color = "0x1F160633" else tr.color = "0xFFFFFF1A"
            fl = g.createChild("Rectangle")
            fl.translation = [372, y + 28]
            fl.width = 110 * it.vol / 100
            fl.height = 6
            fl.color = accent
        else if it.kind = "timing"
            v = g.createChild("Label")
            v.text = "<  " + Str(delay).Trim() + " s  >"
            v.font = hFont("regular", 24)
            v.color = fg
            v.translation = [372, y]
            v.width = 170
            v.height = 62
            v.vertAlign = "center"
        end if
        if on
            ck = g.createChild("Poster")
            ck.uri = "pkg:/images/music/icons/check.png"
            ck.translation = [510, y + 17]
            ck.width = 28
            ck.height = 28
            ck.blendColor = accent
        end if
    end for
    ' a short hint for the focused row
    hint = ""
    if m.top.active and m.r >= 1 and m.r <= n
        it = items[m.r - 1]
        if it.kind = "timing"
            hint = "Left/Right moves the TV earlier or later right away, so you can line it up by ear."
        else if it.kind = "speaker"
            hint = "OK: add or remove. Left/Right: volume."
        else
            hint = "OK: the TV plays along or goes quiet."
        end if
    else if muPlayer().rooms <> invalid and muPlayer().rooms.Count() = 1
        hint = "Looking for speakers in Home Assistant..."
    end if
    ht = g.createChild("Label")
    ht.text = hint
    ht.font = hFont("regular", 22)
    ht.color = "0xB5AF8CFF"
    ht.translation = [96, 782]
    ht.width = 460
    ht.wrap = true
    ht.lineSpacing = 2
    ht.maxLines = 2
    wh = g.createChild("MusicChip")
    wh.icon = "house"
    wh.text = "Whole house"
    wh.translation = [96, 852]
    wh.focused = (m.top.active and m.r = n + 1)
end sub

' the braid bar keeps its empty track showing; only the fill hides at zero
sub setBraid(fillPx as float)
    if m.braid = invalid then return
    on = fillPx > 0
    m.braid.clip.visible = on
    m.braid.tip.visible = on
    if not on then return
    fillW = Int((m.braid.w - 2) * fillPx / m.barW)
    if fillW < 15 then fillW = 15
    m.braid.clip.clippingRect = [0, 0, fillW - 12, 10]
    m.braid.tip.translation = [1 + fillW - 12, 1]
end sub

' More (UX review item 4): what used to be nine small icons, as one list
sub panelMore()
    p = muPlayer()
    m.moreActs = []
    ic = "pkg:/images/music/icons/"
    labels = []
    subs = []
    icons = []
    kinds = []
    pics = []
    if p.castCount > 0 then labels.push("Play in other rooms: " + p.castCount.toStr() + " on") else labels.push("Play in other rooms...")
    m.moreActs.push("cast") : subs.push("Send this music to your speakers") : icons.push(ic + "speaker.png")
    labels.push("Queue...") : m.moreActs.push("queue") : subs.push("What plays next") : icons.push(ic + "queue.png")
    r = "Off"
    if p.repeat = "all" then r = "All"
    if p.repeat = "one" then r = "One song"
    labels.push("Repeat: " + r) : m.moreActs.push("repeat") : subs.push("Off, all, or one song") : icons.push(ic + "repeat.png")
    if p.liked = "like" then labels.push("Like this song: On") else labels.push("Like this song: Off")
    m.moreActs.push("like") : subs.push("Plays more like it in mixes") : icons.push(ic + "thumbup.png")
    labels.push("Dislike this song") : m.moreActs.push("dislike") : subs.push("Keeps it out of mixes") : icons.push(ic + "thumbdown.png")
    labels.push("Big view") : m.moreActs.push("big") : subs.push("The player, full screen") : icons.push(ic + "expand.png")
    for each x in labels
        kinds.push("")
        pics.push("")
    end for
    n = muNow()
    coverPic = ""
    if n.track <> invalid then coverPic = pxImage(n.track.thumb, 360, 240)
    viewsAt = labels.count()
    labels.push("Hearth fire") : m.moreActs.push("hearth") : pics.push("pkg:/images/amb/tile-hearth.jpg")
    labels.push("Cover") : m.moreActs.push("cover") : pics.push(coverPic)
    labels.push("Visualizer") : m.moreActs.push("milk") : pics.push("pkg:/images/music/viz/201.jpg")
    for k = 0 to 2
        kinds.push("pic")
        subs.push("")
        icons.push("")
    end for
    labels.push("More music options...") : m.moreActs.push("options") : subs.push("Shuffle, radio, Last.fm, schedules") : icons.push(ic + "more.png") : kinds.push("") : pics.push("")
    labels.push("Close") : m.moreActs.push("close") : subs.push("") : icons.push("") : kinds.push("") : pics.push("")
    d = CreateObject("roSGNode", "HearthDialog")
    d.title = "Music"
    d.icon = ic + "disc.png"
    if n.track <> invalid
        d.now = { art: pxImage(n.track.thumb, 208, 208), kicker: "Playing now", title: n.title, sub: n.sub }
    else
        d.message = [n.title]
    end if
    d.buttons = labels
    d.subs = subs
    d.icons = icons
    d.kinds = kinds
    d.pics = pics
    hd = {}
    hd[viewsAt.toStr()] = "On screen"
    d.heads = hd
    d.split = viewsAt
    d.observeField("buttonSelected", "onPanelMore")
    d.observeField("wasClosed", "onMuClosed")
    m.moreDialog = d
    hShowDialog(d)
end sub

sub onPanelMore()
    a = m.moreActs[m.moreDialog.buttonSelected]
    m.moreDialog.close = true
    if a = "close" then return
    if a = "options"
        muOptions(true)
    else
        act(a)
    end if
end sub
