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
    m.sel = { kind: "movie", genres: [], provider: "", minRating: 0, sort: "popular" }
    if f <> invalid
        if f.kind <> invalid then m.sel.kind = f.kind
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

' Built once per open: every chip, with its place on screen. Pressing a chip only recolours chips (no nodes are made or fonts loaded).
sub draw()
    m.content.removeChildrenIndex(m.content.getChildCount(), 0)
    m.items = []
    m.rows = []
    cfg = m.cfg
    maxW = 800
    t = m.content.createChild("Label")
    t.font = hFontCached("fell", 42)
    t.text = cfg.title
    t.color = "0xEDE6CAFF"
    t.width = maxW
    y = 62
    if cfg.pickKind = true
        y = section("Show", y)
        list = [{ kind: "kind", value: "all", label: "Trending now" }, { kind: "kind", value: "movie", label: "Movies" }, { kind: "kind", value: "tv", label: "Shows" }]
        y = flow(list, y, maxW)
    end if
    ek = m.sel.kind
    if ek = "all"
        l = m.content.createChild("Label")
        l.font = hFontCached("regular", 24)
        l.color = "0xB5AF8CFF"
        l.text = "Pick Movies or Shows to narrow Trending by genre, streaming service, rating or sort."
        l.width = maxW
        l.wrap = true
        l.lineSpacing = 2
        l.translation = [0, y + 6]
        y = y + 90
        list = [{ kind: "done", label: "Show results", wide: 560 }]
        y = flow(list, y, maxW)
        for each it in m.items
            makeChip(it)
        end for
        refresh()
        return
    end if
    ' Genre (several can be on at once: both must match)
    y = section("Genre", y)
    list = [{ kind: "genreAny", label: "Any" }]
    for each g in cfg.genresBy[ek]
        list.push({ kind: "genre", value: g, label: g, icon: "pkg:/images/requests/genre/" + genreIcon(g) + ".png" })
    end for
    y = flow(list, y, maxW)
    provs = cfg.providersBy[ek]
    if provs <> invalid and provs.count() > 0
        y = section("Streaming on", y)
        list = [{ kind: "provider", value: "", label: "Any" }]
        for each p in provs
            list.push({ kind: "provider", value: p.id.toStr(), label: p.name, logo: p.logo })
        end for
        y = flow(list, y, maxW)
    end if
    y = section("Rating (TMDB)", y)
    list = []
    for each r in [{ v: 0, t: "Any" }, { v: 6, t: "6.0+" }, { v: 7, t: "7.0+" }, { v: 8, t: "8.0+" }]
        list.push({ kind: "rating", value: r.v, label: r.t, star: (r.v > 0) })
    end for
    y = flow(list, y, maxW)
    y = section("Sort", y)
    list = []
    for each s in [{ v: "popular", t: "Popular" }, { v: "rating", t: "Top rated" }, { v: "newest", t: "Newest" }, { v: "az", t: "A to Z" }]
        list.push({ kind: "sort", value: s.v, label: s.t })
    end for
    y = flow(list, y, maxW)
    y = y + 14
    list = [{ kind: "done", label: "Show results", wide: 560 }, { kind: "reset", label: "Reset" }]
    y = flow(list, y, maxW)
    for each it in m.items
        makeChip(it)
    end for
    refresh()
end sub

function isOn(it as object) as boolean
    k = it.kind
    if k = "kind" then return m.sel.kind = it.value
    if k = "genreAny" then return m.sel.genres.count() = 0
    if k = "genre" then return hasGenre(it.value)
    if k = "provider" then return m.sel.provider = it.value
    if k = "rating" then return m.sel.minRating = it.value
    if k = "sort" then return m.sel.sort = it.value
    return k = "done"
end function

function hasGenre(name as string) as boolean
    for each g in m.sel.genres
        if g = name then return true
    end for
    return false
end function

function section(text as string, y as integer) as integer
    l = m.content.createChild("Label")
    l.font = hFontCached("fell", 30)
    l.color = "0xD9A066FF"
    l.text = text
    l.translation = [0, y + 4]
    return y + 50
end function

' Lays chips out left to right, wrapping at maxW; records each one's place for the focus map
function flow(list as object, y as integer, maxW as integer) as integer
    x = 0
    row = []
    probe = CreateObject("roSGNode", "Label")
    probe.font = hFontCached("bold", 22)
    for each it in list
        probe.text = it.label
        w = probe.boundingRect().width + 40
        if it.logo <> invalid and it.logo <> "" then w = w + 38
        if it.star = true then w = w + 28
        if it.icon <> invalid then w = w + 34
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

sub makeChip(it as object)
    g = m.content.createChild("Group")
    g.translation = [it.x, it.y]
    it.bg = g.createChild("Poster")
    it.bg.uri = "pkg:/images/pill.9.png"
    it.bg.width = it.w
    it.bg.height = 48
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
        it.st = g.createChild("Poster")
        it.st.uri = "pkg:/images/requests/star.png"
        it.st.width = 20
        it.st.height = 20
        it.st.translation = [18, 14]
        tx = 46
    end if
    if it.icon <> invalid
        it.ic = g.createChild("Poster")
        it.ic.uri = it.icon
        it.ic.width = 26
        it.ic.height = 26
        it.ic.translation = [16, 11]
        tx = 50
    end if
    it.lab = g.createChild("Label")
    it.lab.font = hFontCached("bold", 22)
    it.lab.text = it.label
    it.lab.height = 48
    it.lab.vertAlign = "center"
    if it.wide <> invalid
        it.lab.width = it.w
        it.lab.horizAlign = "center"
    else
        it.lab.translation = [tx, 0]
    end if
    it.ring = g.createChild("Poster")
    it.ring.uri = "pkg:/images/pill-ring.9.png"
    it.ring.blendColor = "0xFFF3D0FF"
    it.ring.translation = [-5, -5]
    it.ring.width = it.w + 10
    it.ring.height = 58
    it.ring.visible = false
end sub

' Recolour every chip for the current choices and focus
sub refresh()
    for i = 0 to m.items.count() - 1
        it = m.items[i]
        ink = "0xEDE6CAFF"
        if isOn(it) and it.kind <> "reset"
            it.bg.blendColor = "0xE0B34AFF"
            ink = "0x1F1606FF"
        else
            it.bg.blendColor = "0xFFFFFF12"
        end if
        it.lab.color = ink
        if it.st <> invalid then it.st.blendColor = ink
        if it.ic <> invalid then it.ic.blendColor = ink
        it.ring.visible = (i = m.focus)
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
    refresh()
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
    if k = "kind"
        if m.sel.kind <> it.value
            m.sel.kind = it.value
            m.sel.genres = []
            m.sel.provider = ""
            if it.value = "all"
                m.sel.minRating = 0
                m.sel.sort = "popular"
            end if
            m.focus = 0
            draw()
            m.focus = indexOfKind(it.value)
            refresh()
        end if
        return
    else if k = "genreAny"
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
        m.sel.genres = []
        m.sel.provider = ""
        m.sel.minRating = 0
        m.sel.sort = "popular"
        if m.cfg.pickKind = true then m.sel.kind = "all"
        if m.cfg.pickKind = true
            m.focus = 0
            draw()
            refresh()
            return
        end if
    else if k = "done"
        finish()
        return
    end if
    refresh()
end sub

function indexOfKind(v as string) as integer
    for i = 0 to m.items.count() - 1
        if m.items[i].kind = "kind" and m.items[i].value = v then return i
    end for
    return 0
end function

sub finish()
    m.top.result = { kind: m.sel.kind, genres: m.sel.genres, provider: m.sel.provider, minRating: m.sel.minRating, sort: m.sel.sort }
end sub

' Which line icon a genre gets (shows have a few genres movies don't); anything unknown gets the tag
function genreIcon(name as string) as string
    n = LCase(name)
    for each k in ["action", "adventure", "animation", "comedy", "crime", "documentary", "drama", "family", "fantasy", "history", "horror", "music", "mystery", "romance", "thriller", "war", "western", "kids", "news"]
        if Instr(1, n, k) > 0 then return k
    end for
    if Instr(1, n, "sci") > 0 then return "scifi"
    return "tag"
end function
