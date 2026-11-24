sub init()
    m.content = m.top.findNode("content")
    m.focus = 0
    m.items = []
    m.rows = []
end sub

sub build()
    cfg = m.top.config
    if cfg = invalid then return
    m.cfg = cfg
    f = cfg.filters
    m.sel = { genres: [], provider: "", minRating: 0, sort: "popular" }
    if f <> invalid
        for each g in f.genres
            m.sel.genres.push(g)
        end for
        if f.provider <> invalid then m.sel.provider = f.provider
        if f.minRating <> invalid then m.sel.minRating = f.minRating
        if f.sort <> invalid then m.sel.sort = f.sort
    end if
    m.focus = 0
    draw()
end sub

sub draw()
    m.content.removeChildrenIndex(m.content.getChildCount(), 0)
    m.items = []
    m.rows = []
    cfg = m.cfg
    maxW = 800
    t = m.content.createChild("Label")
    t.font = hFont("fell", 42)
    t.text = cfg.title
    t.color = "0xEDE6CAFF"
    t.width = maxW
    y = 62
    ' Genre (several can be on at once: both must match)
    y = section("Genre", y)
    list = [{ kind: "genreAny", label: "Any", on: m.sel.genres.count() = 0 }]
    for each g in cfg.genres
        list.push({ kind: "genre", value: g.name, label: g.name, on: hasGenre(g.name) })
    end for
    y = flow(list, y, maxW)
    if cfg.providers <> invalid and cfg.providers.count() > 0
        y = section("Streaming on", y)
        list = [{ kind: "provider", value: "", label: "Any", on: m.sel.provider = "" }]
        for each p in cfg.providers
            list.push({ kind: "provider", value: p.id.toStr(), label: p.name, logo: p.logo, on: m.sel.provider = p.id.toStr() })
        end for
        y = flow(list, y, maxW)
    end if
    y = section("Rating (TMDB)", y)
    list = []
    for each r in [{ v: 0, t: "Any" }, { v: 6, t: "6.0+" }, { v: 7, t: "7.0+" }, { v: 8, t: "8.0+" }]
        list.push({ kind: "rating", value: r.v, label: r.t, star: (r.v > 0), on: m.sel.minRating = r.v })
    end for
    y = flow(list, y, maxW)
    y = section("Sort", y)
    list = []
    for each s in [{ v: "popular", t: "Popular" }, { v: "rating", t: "Top rated" }, { v: "newest", t: "Newest" }, { v: "az", t: "A to Z" }]
        list.push({ kind: "sort", value: s.v, label: s.t, on: m.sel.sort = s.v })
    end for
    y = flow(list, y, maxW)
    y = y + 14
    list = [{ kind: "done", label: "Show results", on: true, wide: 560 }, { kind: "reset", label: "Reset", on: false }]
    y = flow(list, y, maxW)
    paint()
end sub

function hasGenre(name as string) as boolean
    for each g in m.sel.genres
        if g = name then return true
    end for
    return false
end function

function section(text as string, y as integer) as integer
    l = m.content.createChild("Label")
    l.font = hFont("fell", 30)
    l.color = "0xD9A066FF"
    l.text = text
    l.translation = [0, y + 4]
    return y + 50
end function

' Lays chips out left to right, wrapping at maxW; records each one's place for the focus map
function flow(list as object, y as integer, maxW as integer) as integer
    x = 0
    row = []
    for each it in list
        probe = m.content.createChild("Label")
        probe.font = hFont("bold", 22)
        probe.text = it.label
        w = probe.boundingRect().width + 40
        m.content.removeChild(probe)
        if it.logo <> invalid and it.logo <> "" then w = w + 38
        if it.star = true then w = w + 28
        if it.wide <> invalid and it.wide > w then w = it.wide
        if x + w > maxW and x > 0
            m.rows.push(row)
            row = []
            x = 0
            y = y + 58
        end if
        it.x = x
        it.y = y
        it.w = w
        idx = m.items.count()
        it.row = m.rows.count()
        m.items.push(it)
        row.push(idx)
        x = x + w + 12
    end for
    m.rows.push(row)
    return y + 58
end function

sub paint()
    ' remove old chip nodes, keep title and section labels
    for i = m.content.getChildCount() - 1 to 0 step -1
        c = m.content.getChild(i)
        if c.id = "chip" then m.content.removeChild(c)
    end for
    for i = 0 to m.items.count() - 1
        it = m.items[i]
        g = m.content.createChild("Group")
        g.id = "chip"
        g.translation = [it.x, it.y]
        bg = g.createChild("Poster")
        bg.uri = "pkg:/images/pill.9.png"
        bg.width = it.w
        bg.height = 48
        ink = "0xEDE6CAFF"
        if it.on and it.kind <> "reset"
            bg.blendColor = "0xE0B34AFF"
            ink = "0x1F1606FF"
        else
            bg.blendColor = "0xFFFFFF12"
        end if
        tx = 20
        if it.logo <> invalid and it.logo <> ""
            lg = g.createChild("Poster")
            lg.uri = it.logo
            lg.width = 30
            lg.height = 30
            lg.loadDisplayMode = "scaleToFit"
            lg.translation = [14, 9]
            tx = 54
        end if
        if it.star = true
            st = g.createChild("Poster")
            st.uri = "pkg:/images/requests/star.png"
            st.width = 20
            st.height = 20
            st.blendColor = ink
            st.translation = [18, 14]
            tx = 46
        end if
        lab = g.createChild("Label")
        lab.font = hFont("bold", 22)
        lab.text = it.label
        lab.color = ink
        lab.height = 48
        lab.vertAlign = "center"
        if it.wide <> invalid
            lab.width = it.w
            lab.horizAlign = "center"
        else
            lab.translation = [tx, 0]
        end if
        if i = m.focus
            ring = g.createChild("Poster")
            ring.uri = "pkg:/images/pill-ring.9.png"
            ring.blendColor = "0xFFF3D0FF"
            ring.translation = [-5, -5]
            ring.width = it.w + 10
            ring.height = 58
        end if
    end for
end sub

function handleKey(key as string) as boolean
    it = m.items[m.focus]
    if key = "left"
        if m.focus > 0 and m.items[m.focus - 1].row = it.row then m.focus = m.focus - 1
    else if key = "right"
        if m.focus < m.items.count() - 1 and m.items[m.focus + 1].row = it.row then m.focus = m.focus + 1
    else if key = "up"
        moveRow(it, -1)
    else if key = "down"
        moveRow(it, 1)
    else if key = "OK"
        press(it)
        return true
    else if key = "back"
        finish()
        return true
    end if
    paint()
    return true
end function

' Go to the chip in the next row whose middle is nearest to this chip's middle
sub moveRow(it as object, dir as integer)
    r = it.row + dir
    if r < 0 or r >= m.rows.count() then return
    mid = it.x + it.w / 2
    best = m.rows[r][0]
    bd = 100000
    for each idx in m.rows[r]
        c = m.items[idx]
        d = Abs(c.x + c.w / 2 - mid)
        if d < bd
            bd = d
            best = idx
        end if
    end for
    m.focus = best
end sub

sub press(it as object)
    k = it.kind
    if k = "genreAny"
        m.sel.genres = []
    else if k = "genre"
        out = []
        found = false
        for each g in m.sel.genres
            if g = it.value then found = true else out.push(g)
        end for
        if not found then out.push(it.value)
        m.sel.genres = out
    else if k = "provider"
        m.sel.provider = it.value
    else if k = "rating"
        m.sel.minRating = it.value
    else if k = "sort"
        m.sel.sort = it.value
    else if k = "reset"
        m.sel = { genres: [], provider: "", minRating: 0, sort: "popular" }
    else if k = "done"
        finish()
        return
    end if
    draw()
end sub

sub finish()
    m.top.result = { genres: m.sel.genres, provider: m.sel.provider, minRating: m.sel.minRating, sort: m.sel.sort }
end sub
