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
    m.castTop = 0
    m.names = { prev: "Previous", toggle: "Play", next: "Next", shuffle: "Shuffle", repeat: "Repeat", cover: "Cover", milk: "Visualizer", hearth: "Hearth fire", big: "Big view", library: "Back to the library", cast: "Play in other rooms" }
    m.r = 0
    m.c = 1
    p = muPlayer()
    for each f in ["track", "state", "shuffle", "repeat", "queue"]
        p.observeFieldScoped(f, "showNow")
    end for
    p.observeFieldScoped("position", "showTime")
    p.observeFieldScoped("castCount", "showNow")
    p.observeFieldScoped("rooms", "drawCast")
    p.observeFieldScoped("castDelay", "drawCast")
    build()
end sub

' rows of [icon, word, action]; "sep" draws a divider
sub build()
    m.chips.removeChildrenIndex(m.chips.getChildCount(), 0)
    m.grid = []
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
        setText(m.title, [x, 236], w, "bold", 92)
        setText(m.sub, [x, 352], w, "regular", 38)
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
        addRow([x, 714], [["prev", "", "prev"], ["play", "", "toggle"], ["next", "", "next"], ["cast", "", "cast"]], 0)
        addRow([x, 812], [["shuffle", "", "shuffle"], ["repeat", "", "repeat"], ["cover", "", "cover"], ["viz", "", "milk"], ["fire", "", "hearth"], ["expand", "", "big"]], 1)
        setText(m.chipName, [x, 888], w, "regular", 22)
    end if
    m.track.width = m.barW
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
    m.title.text = n.title
    m.sub.text = n.sub
    if n.track <> invalid
        m.art.uri = pxImage(n.track.thumb, m.artSize, m.artSize)
    else
        m.art.uri = "pkg:/images/lantern.png"
    end if
    if not pxReady()
        m.eyebrow.text = "PLEX ISN'T LINKED"
        m.title.text = "Sign in to Plex"
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
            else if it.action = "cast"
                c.on = (p.castCount > 0)
                if p.castCount > 0 then c.badge = p.castCount.toStr() else c.badge = ""
            end if
        end for
    end for
    showTime()
    paint()
end sub

sub showTime()
    p = muPlayer()
    if p.track = invalid
        m.fill.width = 0
        m.elapsed.text = ""
        m.total.text = ""
        return
    end if
    d = p.duration
    if d > 0 then m.fill.width = m.barW * p.position / d else m.fill.width = 0
    m.elapsed.text = pxClock(p.position)
    m.total.text = pxClock(d)
    if m.top.layout = "bar" then m.elapsed.text = pxClock(p.position) + " / " + pxClock(d)
end sub

sub paint()
    name = ""
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
    if not pxReady() and a <> "cover" and a <> "milk" and a <> "hearth" and a <> "library" and a <> "big" then return
    if a = "cast"
        if m.top.castOpen
            closeCast()
        else
            muSend("castRefresh")
            m.castTop = 0
            m.r = 2
            m.top.castOpen = true
        end if
    else if a = "big"
        m.top.request = { action: "musicView", mode: "big" }
    else if a = "library"
        m.top.request = { action: "back" }
    else if a = "prev" or a = "next"
        muSend(a)
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
    m.r = 0
    m.c = 3
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
    ' keep the focused room on screen (6 rows fit)
    if m.r >= 1 and m.r <= n
        if m.r - 1 < m.castTop then m.castTop = m.r - 1
        if m.r - 1 > m.castTop + 5 then m.castTop = m.r - 6
    end if
    return ""
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
    for k = 0 to 5
        i = m.castTop + k
        if i >= n then exit for
        it = items[i]
        y = 380 + k * 66
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
    ht.font = hFont("regular", 20)
    ht.color = "0xB5AF8CFF"
    ht.translation = [96, 782]
    ht.width = 460
    ht.wrap = true
    ht.maxLines = 2
    wh = g.createChild("MusicChip")
    wh.icon = "house"
    wh.text = "Whole house"
    wh.translation = [96, 852]
    wh.focused = (m.top.active and m.r = n + 1)
end sub
