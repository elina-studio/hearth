sub init()
    m.top.findNode("kicker").font = hFont("caps", 26)
    m.title = m.top.findNode("title")
    m.title.font = hFont("bold", 52)
    m.sub = m.top.findNode("sub")
    m.sub.font = hFont("regular", 28)
    m.top.findNode("hint").font = hFont("regular", 24)
    m.grid = m.top.findNode("grid")
    ' four rows show at a time; the grid scrolls a row at a time to keep the focus in view
    m.rows = 4
    m.rowTop = 0
    m.top.findNode("clip").clippingRect = [-24, -24, 1704, 3 * 181 + 105 + 84]
    m.cols = 8
    m.tw = 186
    m.th = 105
    m.gx = 24
    m.gy = 76
    m.items = []
    m.tiles = []
    m.focus = 0
    m.clock = CreateObject("roTimespan")
    m.lastKey = -1000
end sub

' open({ current: "57" }): draws the tiles and puts focus on the look in use
sub open(args as object)
    m.items = [{ n: "shuffle", label: "Shuffle" }]
    for each l in vizLooks()
        m.items.push(l)
    end for
    m.grid.removeChildrenIndex(m.grid.getChildCount(), 0)
    m.tiles = []
    m.stars = vizStars()
    for i = 0 to m.items.Count() - 1
        m.tiles.push(makeTile(i, m.items[i]))
    end for
    choice = vizChoice()
    m.focus = 0
    if choice <> "shuffle"
        for i = 1 to m.items.Count() - 1
            if m.items[i].n = choice then m.focus = i
        end for
    end if
    redraw()
end sub

function makeTile(i as integer, it as object) as object
    t = m.grid.createChild("Group")
    t.translation = [(i mod m.cols) * (m.tw + m.gx), Int(i / m.cols) * (m.th + m.gy)]
    ' focus: a solid gold frame around the picture, so the look in focus is plain to see
    ring = t.createChild("Group")
    ring.visible = false
    b = 6
    for each r in [[-b - 4, -b - 4, m.tw + 2 * b + 8, b], [-b - 4, m.th + 4, m.tw + 2 * b + 8, b], [-b - 4, -4, b, m.th + 8], [m.tw + 4, -4, b, m.th + 8]]
        e = ring.createChild("Rectangle")
        e.translation = [r[0], r[1]]
        e.width = r[2]
        e.height = r[3]
        e.color = "0xE0B34AFF"
    end for
    bg = t.createChild("Rectangle")
    bg.width = m.tw
    bg.height = m.th
    bg.color = "0x1D2418FF"
    pic = invalid
    if it.n = "shuffle"
        ic = t.createChild("Poster")
        ic.uri = "pkg:/images/music/icons/shuffle.png"
        ic.width = 56
        ic.height = 56
        ic.translation = [(m.tw - 56) / 2, (m.th - 56) / 2]
        ic.blendColor = "0xE0B34AFF"
    pic = invalid
    else
        ' the picture is loaded only while its row is on screen (see redraw): 68 pictures at once,
        ' with the visualizer video playing behind, ran the TV out of picture memory when scrolling fast
        pic = t.createChild("Poster")
        pic.width = m.tw
        pic.height = m.th
        pic.loadDisplayMode = "scaleToZoom"
    end if
    starBg = t.createChild("Rectangle")
    starBg.translation = [m.tw - 40, 6]
    starBg.width = 34
    starBg.height = 34
    starBg.color = "0x0B0E09B3"
    star = t.createChild("Poster")
    star.uri = "pkg:/images/music/icons/heart.png"
    star.translation = [m.tw - 37, 9]
    star.width = 28
    star.height = 28
    star.blendColor = "0xE0B34AFF"
    inUse = t.createChild("Rectangle")
    inUse.translation = [0, m.th - 6]
    inUse.width = m.tw
    inUse.height = 6
    inUse.color = "0xE0B34AFF"
    name = t.createChild("Label")
    name.translation = [0, m.th + 24]
    name.width = m.tw
    name.horizAlign = "center"
    name.maxLines = 1
    name.font = hFont("regular", 22)
    name.color = "0xB5AF8CFF"
    name.text = it.label
    return { ring: ring, star: star, starBg: starBg, inUse: inUse, name: name, pic: pic, row: Int(i / m.cols) }
end function

sub redraw()
    stars = m.stars
    choice = vizChoice()
    row = Int(m.focus / m.cols)
    if row < m.rowTop then m.rowTop = row
    if row > m.rowTop + m.rows - 1 then m.rowTop = row - m.rows + 1
    for i = 0 to m.tiles.Count() - 1
        it = m.items[i]
        t = m.tiles[i]
        f = (i = m.focus)
        t.ring.visible = f
        starred = (it.n <> "shuffle" and stars[it.n] = true)
        t.star.visible = starred
        t.starBg.visible = starred
        t.inUse.visible = (it.n = choice)
        if f then t.name.color = "0xEDE6CAFF" else t.name.color = "0xB5AF8CFF"
        if t.pic <> invalid
            want = ""
            if t.row >= m.rowTop - 1 and t.row <= m.rowTop + m.rows then want = "pkg:/images/music/viz/" + it.n + ".jpg"
            if t.pic.uri <> want then t.pic.uri = want
        end if
    end for
    m.grid.translation = [0, -m.rowTop * (m.th + m.gy)]
    it = m.items[m.focus]
    n = stars.Count()
    if it.n = "shuffle"
        m.title.text = "Shuffle"
        if vizPlayMode() = "hearted" and n > 0
            m.sub.text = "A different look for every song, from your " + n.toStr() + " hearted looks."
        else
            m.sub.text = "A different look for every song, from all " + vizLooks().Count().toStr() + " looks."
        end if
    else
        m.title.text = it.label
        if stars[it.n] = true then s = "Hearted" else s = "Not hearted"
        if it.n = choice then s = s + "  ·  In use for every song"
        m.sub.text = s
    end if
end sub

function handleKey(key as string) as boolean
    ' a held arrow repeats faster than the TV can redraw; take at most one step every 90 ms
    if key = "up" or key = "down" or key = "left" or key = "right"
        now = m.clock.TotalMilliseconds()
        if now - m.lastKey < 90 then return true
        m.lastKey = now
    end if
    last = m.items.Count() - 1
    f = m.focus
    if key = "back"
        m.top.chosen = "close"
    else if key = "OK"
        m.top.chosen = m.items[f].n
    else if key = "play"
        it = m.items[f]
        if it.n <> "shuffle"
            vizSetStar(it.n, vizStars()[it.n] <> true)
            m.stars = vizStars()
            redraw()
        end if
    else if key = "left"
        if f mod m.cols > 0 then f = f - 1
    else if key = "right"
        if f mod m.cols < m.cols - 1 and f < last then f = f + 1
    else if key = "up"
        if f >= m.cols then f = f - m.cols
    else if key = "down"
        if f + m.cols <= last then f = f + m.cols
    end if
    if f <> m.focus
        m.focus = f
        redraw()
    end if
    return true
end function
