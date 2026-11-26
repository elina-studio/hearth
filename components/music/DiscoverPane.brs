' Music > Discover. Zones: "chips", then for the artist views "list" (artists), "btns" (Get albums / Hide) and
' "grid" (that artist's albums); for New releases "rows". Keys come in through handleKey(key), which answers "left"
' or "up" when focus should leave the pane. Rows and tiles are made once and refilled, never rebuilt per key press.
sub init()
    m.chips = m.top.findNode("chips")
    m.list = m.top.findNode("list")
    m.detail = m.top.findNode("detail")
    m.kick = m.top.findNode("kick")
    m.kick.font = hFont("caps", 22)
    m.title = m.top.findNode("title")
    m.title.font = hFont("bold", 44)
    m.meta = m.top.findNode("meta")
    m.meta.font = hFont("regular", 23)
    m.btns = m.top.findNode("btns")
    m.grid = m.top.findNode("grid")
    m.gridNote = m.top.findNode("gridNote")
    m.gridNote.font = hFont("regular", 23)
    m.rel = m.top.findNode("rel")
    m.note = m.top.findNode("note")
    m.note.font = hFont("regular", 26)
    m.countLbl = m.top.findNode("count")
    m.countLbl.font = hFont("regular", 21)
    m.toast = m.top.findNode("toast")
    m.toast.font = hFont("bold", 24)
    m.hints = m.top.findNode("hints")
    m.toastTimer = m.top.findNode("toastTimer")
    m.toastTimer.observeField("fire", "hideToast")
    m.recheck = m.top.findNode("recheck")
    m.recheck.observeField("fire", "onRecheck")
    m.pvTimer = m.top.findNode("pvTimer")
    m.pvTimer.observeField("fire", "loadAlbums")
    m.chipNodes = []
    m.MODES = ["loved", "recs", "releases", "missing"]
    for each t in [["Artists you love", "star"], ["Recommended", "wave"], ["New releases", "clock"], ["Missing", "plus"]]
        c = m.chips.createChild("MusicChip")
        c.icon = t[1]
        c.text = t[0]
        m.chipNodes.push(c)
    end for
    x = 0
    for each c in m.chipNodes
        c.translation = [x, 12]
        x = x + c.width + 18
    end for
    m.LROWS = 8      ' artists on screen
    m.LPITCH = 84
    m.GCOLS = 3      ' album tiles across
    m.GROWS = 2      ' and down
    m.RROWS = 7      ' new releases on screen
    m.RPITCH = 96
    m.rowPool = []
    for i = 0 to m.LROWS - 1
        m.rowPool.push(makeRow(i))
    end for
    m.tilePool = []
    for i = 0 to m.GCOLS * m.GROWS - 1
        m.tilePool.push(makeTile(i))
    end for
    m.relPool = []
    for i = 0 to m.RROWS - 1
        m.relPool.push(makeRel(i))
    end for
    m.btnNodes = []
    m.btnDefs = []
    m.btnSig = ""
    m.mode = "loved"
    m.zone = "list"
    m.sel = 0        ' index in the current list (artists or releases)
    m.top0 = 0       ' first one on screen
    m.btn = 0
    m.gsel = 0       ' index in the focused artist's albums
    m.gtop = 0       ' first album row on screen
    m.data = invalid
    m.asking = false
    m.gone = {}      ' artists hidden since the lists were last read (lower case)
    m.albumCache = {}
    m.curArtist = ""
    m.lastHid = ""
    m.confirm = ""
    m.hintSig = ""
    m.reqFor = {}
    m.busy = false
    m.askedAt = 0
end sub

' ---------------------------------------------------------------- pooled nodes
function makeRow(i as integer) as object
    g = m.list.createChild("Group")
    g.translation = [0, i * m.LPITCH]
    g.visible = false
    r = { g: g }
    r.sel = g.createChild("Rectangle")
    r.sel.translation = [-4, 2]
    r.sel.width = 432
    r.sel.height = 76
    r.sel.color = "0xE0B34A14"
    r.ring = g.createChild("Poster")
    r.ring.translation = [-16, -10]
    r.ring.width = 456
    r.ring.height = 100
    r.ring.uri = "pkg:/images/w/button-outline" + hVar(i) + ".9.png"
    r.ring.blendColor = "0xD9A066FF"
    av = g.createChild("Rectangle")
    av.translation = [6, 10]
    av.width = 60
    av.height = 60
    av.color = "0x23291EFF"
    r.letter = g.createChild("Label")
    r.letter.font = hFont("pica", 30)
    r.letter.translation = [6, 10]
    r.letter.width = 60
    r.letter.height = 60
    r.letter.horizAlign = "center"
    r.letter.vertAlign = "center"
    r.letter.color = "0xB5AF8CFF"
    r.photo = g.createChild("Poster")
    r.photo.translation = [6, 10]
    r.photo.width = 60
    r.photo.height = 60
    r.photo.loadWidth = 120
    r.photo.loadHeight = 120
    r.photo.loadDisplayMode = "scaleToZoom"
    mk = g.createChild("Poster")
    mk.translation = [6, 10]
    mk.width = 60
    mk.height = 60
    mk.uri = "pkg:/images/music/round-mask.png"
    r.name = g.createChild("Label")
    r.name.font = hFont("bold", 25)
    r.name.translation = [84, 9]
    r.name.width = 330
    r.name.maxLines = 1
    r.name.color = "0xEDE6CAFF"
    r.line2 = g.createChild("Label")
    r.line2.font = hFont("regular", 19)
    r.line2.translation = [84, 44]
    r.line2.width = 216
    r.line2.maxLines = 1
    r.line2.color = "0xB5AF8CFF"
    r.togo = g.createChild("Label")
    r.togo.font = hFont("bold", 19)
    r.togo.translation = [300, 44]
    r.togo.width = 114
    r.togo.horizAlign = "right"
    r.togo.maxLines = 1
    r.togo.color = "0xE0B34AFF"
    return r
end function

function makeTile(i as integer) as object
    g = m.grid.createChild("Group")
    g.translation = [(i mod m.GCOLS) * 194, Int(i / m.GCOLS) * 232]
    g.visible = false
    t = { g: g }
    bg = g.createChild("Rectangle")
    bg.width = 172
    bg.height = 172
    bg.color = "0x1A2016FF"
    disc = g.createChild("Poster")
    disc.translation = [62, 62]
    disc.width = 48
    disc.height = 48
    disc.uri = "pkg:/images/music/icons/disc.png"
    disc.blendColor = "0xB5AF8C66"
    t.cover = g.createChild("Poster")
    t.cover.width = 172
    t.cover.height = 172
    t.cover.loadWidth = 320
    t.cover.loadHeight = 320
    t.cover.loadDisplayMode = "scaleToZoom"
    t.band = g.createChild("Rectangle")
    t.band.translation = [0, 140]
    t.band.width = 172
    t.band.height = 32
    t.bandText = g.createChild("Label")
    t.bandText.font = hFont("bold", 17)
    t.bandText.translation = [0, 140]
    t.bandText.width = 172
    t.bandText.height = 32
    t.bandText.horizAlign = "center"
    t.bandText.vertAlign = "center"
    t.ring = g.createChild("Poster")
    t.ring.translation = [-20, -20]
    t.ring.width = 212
    t.ring.height = 212
    t.ring.uri = "pkg:/images/w/button-outline" + hVar(i + 2) + ".9.png"
    t.ring.blendColor = "0xD9A066FF"
    t.name = g.createChild("Label")
    t.name.font = hFont("bold", 21)
    t.name.translation = [0, 178]
    t.name.width = 172
    t.name.maxLines = 1
    t.name.color = "0xEDE6CAFF"
    t.line2 = g.createChild("Label")
    t.line2.font = hFont("regular", 18)
    t.line2.translation = [0, 204]
    t.line2.width = 172
    t.line2.maxLines = 1
    t.line2.color = "0xB5AF8CFF"
    return t
end function

function makeRel(i as integer) as object
    g = m.rel.createChild("Group")
    g.translation = [0, i * m.RPITCH]
    g.visible = false
    r = { g: g }
    bg = g.createChild("Poster")
    bg.translation = [-12, -12]
    bg.width = 1174
    bg.height = 112
    bg.uri = "pkg:/images/w/panel-v3.9.png"
    bg.blendColor = "0x141A11FF"
    r.ring = g.createChild("Poster")
    r.ring.translation = [-12, -12]
    r.ring.width = 1174
    r.ring.height = 112
    r.ring.uri = "pkg:/images/w/button-outline" + hVar(i) + ".9.png"
    r.ring.blendColor = "0xD9A066FF"
    ph = g.createChild("Rectangle")
    ph.translation = [14, 12]
    ph.width = 64
    ph.height = 64
    ph.color = "0x23291EFF"
    disc = g.createChild("Poster")
    disc.translation = [30, 28]
    disc.width = 32
    disc.height = 32
    disc.uri = "pkg:/images/music/icons/disc.png"
    disc.blendColor = "0xB5AF8C66"
    r.cover = g.createChild("Poster")
    r.cover.translation = [14, 12]
    r.cover.width = 64
    r.cover.height = 64
    r.cover.loadWidth = 128
    r.cover.loadHeight = 128
    r.cover.loadDisplayMode = "scaleToZoom"
    r.name = g.createChild("Label")
    r.name.font = hFont("bold", 28)
    r.name.translation = [96, 8]
    r.name.width = 640
    r.name.maxLines = 1
    r.name.color = "0xEDE6CAFF"
    r.line2 = g.createChild("Label")
    r.line2.font = hFont("regular", 21)
    r.line2.translation = [96, 46]
    r.line2.width = 640
    r.line2.maxLines = 1
    r.line2.color = "0xB5AF8CFF"
    r.date = g.createChild("Label")
    r.date.font = hFont("regular", 23)
    r.date.translation = [740, 28]
    r.date.width = 190
    r.date.horizAlign = "right"
    r.date.color = "0xB5AF8CFF"
    r.act = g.createChild("Label")
    r.act.font = hFont("bold", 22)
    r.act.translation = [940, 28]
    r.act.width = 196
    r.act.horizAlign = "right"
    return r
end function

' ---------------------------------------------------------------- data
sub load(unused as dynamic)
    if m.asking then return
    ' what's on the shelf changes as Lidarr downloads: read the lists again when they are 5 minutes old
    fresh = (CreateObject("roDateTime").AsSeconds() - m.askedAt < 300)
    if m.data <> invalid and fresh and not needsRecheck() then return
    ask()
end sub

sub ask()
    if m.asking then return
    m.asking = true
    m.askedAt = CreateObject("roDateTime").AsSeconds()
    if m.data = invalid then m.note.text = "Asking the NAS" + Chr(8230)
    nasCall("GET", "/api/discover", "", "onData", "discover")
end sub

' the NAS is still building the lists or reading Lidarr: look again in a moment
function needsRecheck() as boolean
    d = m.data
    if d = invalid then return true
    return d.building = true or d.filling = true or d.built = 0
end function

sub onRecheck()
    if not m.top.visible then return
    ask()
end sub

sub onData(event as object)
    t = hTaskFrom(event)
    m.asking = false
    if not t.ok
        if m.data <> invalid then return   ' keep what is on screen
        if t.status = 401 or t.status = 403
            m.note.text = "The NAS helper didn't let the TV in. Run the setup command again."
        else
            m.note.text = "Can't reach the Hearth helper on the NAS right now."
        end if
        return
    end if
    keep = currentName()
    d = t.response
    for each k in ["loved", "recs", "missing", "releases", "hidden"]
        if type(d[k]) <> "roArray" then d[k] = []
    end for
    if d.built = invalid then d.built = 0
    if d.error = invalid then d.error = ""
    if d.shelferr = invalid then d.shelferr = ""
    if d.user = invalid then d.user = ""
    m.data = d
    m.gone = {}
    migrateHidden()
    ' stay on the artist that was focused when the list changed underneath
    if keep <> ""
        lst = curList()
        for i = 0 to lst.Count() - 1
            if itemName(lst[i]) = keep
                m.sel = i
                exit for
            end if
        end for
    end if
    redraw()
    if needsRecheck() and m.top.visible then m.recheck.control = "start"
end sub

' artists hidden by an older build were kept on the TV: hand them to the NAS once, then forget them here
sub migrateHidden()
    reg = CreateObject("roRegistrySection", "hearth")
    old = reg.Read("discRelHide")
    if old = "" then return
    j = ParseJson(old)
    if type(j) = "roArray"
        for each n in j
            if type(n) = "roString" or type(n) = "String"
                nasCall("POST", "/api/discover/hide", FormatJson({ "name": n }), "onQuiet", "")
                m.gone[LCase(n)] = true
            end if
        end for
    end if
    reg.Delete("discRelHide")
    reg.Flush()
end sub

sub onQuiet(event as object)
    hTaskFrom(event)
end sub

function isArtists() as boolean
    return m.mode <> "releases"
end function

' the current list, minus anything hidden since it was read
function curList() as object
    if m.data = invalid then return []
    src = m.data[m.mode]
    if src = invalid then return []
    n = 0
    for each k in m.gone
        n = n + 1
    end for
    if n = 0 then return src
    out = []
    for each e in src
        if m.gone[LCase(itemName(e))] = invalid then out.push(e)
    end for
    return out
end function

' the artist a row belongs to (a release row carries "artist", an artist row "name")
function itemName(e as object) as string
    if e.artist <> invalid then return e.artist
    if e.name <> invalid then return e.name
    return ""
end function

function currentName() as string
    lst = curList()
    if m.sel < 0 or m.sel >= lst.Count() then return ""
    if not isArtists() then return ""
    return itemName(lst[m.sel])
end function

function txt(v as dynamic) as string
    if type(v) = "roString" or type(v) = "String" then return v
    if v = invalid then return ""
    if type(v) = "roInt" or type(v) = "Integer" or type(v) = "roInteger" or type(v) = "LongInteger" then return v.toStr()
    if type(v) = "roFloat" or type(v) = "Float" or type(v) = "Double" or type(v) = "roDouble" then return Int(v).toStr()
    return ""
end function

function num(v as dynamic) as integer
    if v = invalid then return 0
    t = type(v)
    if t = "roInt" or t = "Integer" or t = "roInteger" or t = "LongInteger" then return v
    if t = "roFloat" or t = "Float" or t = "Double" or t = "roDouble" then return Int(v)
    if t = "roString" or t = "String" then return Val(v, 10)
    return 0
end function

function plural(n as integer, one as string, many as string) as string
    if n = 1 then return "1 " + one
    return n.toStr() + " " + many
end function

' ---------------------------------------------------------------- drawing
sub redraw()
    lst = curList()
    if m.sel >= lst.Count() then m.sel = lst.Count() - 1
    if m.sel < 0 then m.sel = 0
    m.note.text = ""
    if lst.Count() = 0
        m.note.text = emptyText()
        m.detail.visible = false
        if m.zone <> "chips" then m.zone = "chips"
    else if isArtists()
        showDetail(lst[m.sel])
    else
        m.detail.visible = false
    end if
    paint()
end sub

function emptyText() as string
    d = m.data
    if d = invalid then return ""
    if m.mode = "missing"
        if d.shelferr <> "" then return "The NAS couldn't read Lidarr: " + d.shelferr + ". Run the setup command again."
        if d.filling = true then return "Reading your Lidarr library" + Chr(8230)
        return "Nothing is missing: you have every album by the artists in Lidarr."
    end if
    if m.mode = "releases"
        if d.filling = true or num(d.freshbuilt) = 0 then return "Looking for new releases. The first look takes a few minutes; this page updates by itself."
        return "No new albums from your artists in the last two months."
    end if
    if d.building <> true and d.built = 0 and d.error <> "" then return "The NAS couldn't build your lists: " + d.error + ". It tries again each time you open this tab."
    if d.building = true or d.built = 0 then return "The NAS is working out your lists. This page updates by itself."
    if d.user = "" then return "Pair Last.fm first (Music > * options > Last.fm), then your lists appear here."
    if d.filling = true then return "Checking which albums you already have" + Chr(8230)
    if m.mode = "loved" then return "You already have every album by the artists you play most."
    return "No recommendations yet."
end function

sub paint()
    for i = 0 to m.chipNodes.Count() - 1
        c = m.chipNodes[i]
        c.on = (m.MODES[i] = m.mode)
        c.focused = (m.top.active and m.zone = "chips" and m.MODES[i] = m.mode)
    end for
    lst = curList()
    m.list.visible = isArtists()
    m.rel.visible = not isArtists()
    if isArtists()
        drawRows(lst)
        for i = 0 to m.btnNodes.Count() - 1
            m.btnNodes[i].focused = (m.top.active and m.zone = "btns" and i = m.btn)
        end for
        drawGrid()
    else
        drawRel(lst)
    end if
    drawFoot(lst)
end sub

function photoFor(e as object) as string
    o = m.top.owned
    if o <> invalid
        v = o[LCase(e.name)]
        if v <> invalid and v <> "" then return v
    end if
    if e.img <> invalid and e.img <> "" then return nasBase() + e.img
    return ""
end function

sub setUri(p as object, uri as string)
    if p.uri <> uri then p.uri = uri
end sub

sub drawRows(lst as object)
    if m.sel < m.top0 then m.top0 = m.sel
    if m.sel >= m.top0 + m.LROWS then m.top0 = m.sel - m.LROWS + 1
    if m.top0 < 0 then m.top0 = 0
    inList = (m.top.active and m.zone = "list")
    for i = 0 to m.LROWS - 1
        r = m.rowPool[i]
        idx = m.top0 + i
        if idx >= lst.Count()
            r.g.visible = false
        else
            e = lst[idx]
            r.g.visible = true
            r.ring.visible = (idx = m.sel and inList)
            r.sel.visible = (idx = m.sel and not inList)
            r.name.text = e.name
            r.letter.text = UCase(Left(e.name, 1))
            setUri(r.photo, photoFor(e))
            if m.mode = "recs"
                if txt(e.because) <> "" then r.line2.text = "like " + e.because else r.line2.text = "recommended"
                r.line2.width = 330
                r.togo.text = ""
            else
                p = num(e.plays)
                if p > 0 then r.line2.text = plural(p, "play", "plays") else r.line2.text = "never played"
                r.line2.width = 216
                if num(e.togo) > 0 then r.togo.text = num(e.togo).toStr() + " to get" else r.togo.text = ""
            end if
        end if
    end for
end sub

sub showDetail(e as object)
    m.detail.visible = true
    changed = (m.curArtist <> e.name)
    m.curArtist = e.name
    if m.mode = "recs"
        m.kick.text = "RECOMMENDED"
    else if m.mode = "missing"
        m.kick.text = "MISSING FROM YOUR LIBRARY"
    else
        m.kick.text = "ARTISTS YOU LOVE"
    end if
    m.title.text = e.name
    if changed
        m.gsel = 0
        m.gtop = 0
        m.confirm = ""
    end if
    c = m.albumCache[LCase(e.name)]
    if c <> invalid and c.failed = true and changed
        ' the NAS didn't answer last time: ask again now that you're back on this artist
        m.albumCache.Delete(LCase(e.name))
        c = invalid
    end if
    setMeta(e, c)
    setButtons(e, c)
    if c = invalid and changed
        m.pvTimer.control = "stop"
        m.pvTimer.control = "start"
    end if
end sub

sub setMeta(e as object, c as dynamic)
    togo = num(e.togo)
    total = num(e.albums)
    if c <> invalid
        togo = num(c.togo)
        total = num(c.total)
    end if
    if m.mode = "recs"
        s = "Because you play " + txt(e.because)
        if txt(e.because) = "" then s = "Like the artists you play"
        if total > 0 then s = s + "  " + Chr(183) + "  " + plural(total, "album", "albums")
    else
        p = num(e.plays)
        if p > 0 then s = plural(p, "play", "plays") else s = "Never played"
        if total > 0 and togo >= 0
            s = s + "  " + Chr(183) + "  " + togo.toStr() + " of " + plural(total, "album", "albums") + " to get"
        else if c = invalid
            s = s + "  " + Chr(183) + "  checking albums" + Chr(8230)
        end if
    end if
    m.meta.text = s
end sub

' how many albums "Get all" would ask Lidarr for (0 = Lidarr doesn't manage this artist, or nothing is missing)
function getAllCount(e as object, c as dynamic) as integer
    if c <> invalid
        if num(c.lid) = 0 or txt(c.source) <> "lidarr" then return 0
        return num(c.togo)
    end if
    if num(e.lid) = 0 then return 0
    if num(e.togo) > 0 then return num(e.togo)
    return 0
end function

sub setButtons(e as object, c as dynamic)
    n = getAllCount(e, c)
    defs = []
    if n > 1
        defs.push(["request", "Get all " + n.toStr(), "all"])
    else if n = 1
        defs.push(["request", "Get it", "all"])
    else
        defs.push(["request", "Get albums", "open"])
    end if
    if m.mode = "recs" then defs.push(["thumbdown", "Not for me", "hide"]) else defs.push(["hide", "Hide artist", "hide"])
    sig = ""
    for each d in defs
        sig = sig + d[1] + "|"
    end for
    m.btnDefs = defs
    if sig = m.btnSig then return
    m.btnSig = sig
    m.btns.removeChildrenIndex(m.btns.getChildCount(), 0)
    m.btnNodes = []
    x = 0
    for each d in defs
        b = m.btns.createChild("MusicChip")
        b.icon = d[0]
        b.text = d[1]
        b.translation = [x, 0]
        x = x + b.width + 16
        m.btnNodes.push(b)
    end for
    if m.btn >= m.btnNodes.Count() then m.btn = 0
end sub

sub loadAlbums()
    if m.curArtist = "" then return
    nasCall("GET", "/api/discover/albums?artist=" + pxEscape(m.curArtist), "", "onAlbums", m.curArtist)
end sub

sub onAlbums(event as object)
    t = hTaskFrom(event)
    r = t.response
    if not t.ok or type(r.albums) <> "roArray"
        ' say so instead of spinning for ever
        if t.tag = m.curArtist then m.albumCache[LCase(t.tag)] = { albums: [], togo: 0, total: 0, lid: 0, source: "", failed: true }
    else
        m.albumCache[LCase(t.tag)] = r
    end if
    if t.tag <> m.curArtist or not isArtists() then return
    lst = curList()
    if m.sel < lst.Count() then showDetail(lst[m.sel])
    paint()
end sub

function curAlbums() as object
    c = m.albumCache[LCase(m.curArtist)]
    if c = invalid or type(c.albums) <> "roArray" then return []
    return c.albums
end function

sub drawGrid()
    c = m.albumCache[LCase(m.curArtist)]
    al = curAlbums()
    m.gridNote.text = ""
    if not m.detail.visible
        return
    else if c = invalid
        m.gridNote.text = "Looking up albums" + Chr(8230)
    else if c.failed = true
        m.gridNote.text = "Couldn't get the albums from the NAS just now. Move to another artist and back to try again."
    else if al.Count() = 0
        m.gridNote.text = "No albums found for this artist. Get albums searches by name instead."
    end if
    if m.gsel >= al.Count() then m.gsel = al.Count() - 1
    if m.gsel < 0 then m.gsel = 0
    row = Int(m.gsel / m.GCOLS)
    if row < m.gtop then m.gtop = row
    if row >= m.gtop + m.GROWS then m.gtop = row - m.GROWS + 1
    inGrid = (m.top.active and m.zone = "grid")
    for i = 0 to m.tilePool.Count() - 1
        t = m.tilePool[i]
        idx = m.gtop * m.GCOLS + i
        if idx >= al.Count()
            t.g.visible = false
        else
            a = al[idx]
            t.g.visible = true
            t.ring.visible = (inGrid and idx = m.gsel)
            if txt(a.img) <> "" then setUri(t.cover, nasBase() + a.img) else setUri(t.cover, "")
            st = txt(a.state)
            t.name.text = txt(a.title)
            k = txt(a.kind)
            if k = "ep" then k = "EP" else k = "Album"
            if txt(a.year) <> "" then t.line2.text = a.year + " " + Chr(183) + " " + k else t.line2.text = k
            band = ""
            if st = "have"
                band = "IN LIBRARY"
                t.band.color = "0x26301CF2"
                t.bandText.color = "0xC2CB86FF"
            else if st = "req"
                band = "REQUESTED"
                t.band.color = "0x3A2E10F2"
                t.bandText.color = "0xE0B34AFF"
            else if st = "soon"
                band = "COMING SOON"
                t.band.color = "0x1B2530F2"
                t.bandText.color = "0xB9CDE0FF"
            end if
            t.band.visible = (band <> "")
            t.bandText.text = band
            ' what you own steps back so the missing ones stand out
            if st = "have"
                t.cover.opacity = 0.5
                t.name.color = "0xEDE6CA99"
            else
                t.cover.opacity = 1
                t.name.color = "0xEDE6CAFF"
            end if
        end if
    end for
end sub

function dayText(iso as string) as string
    if Len(iso) < 10 then return ""
    dt = CreateObject("roDateTime")
    dt.FromISO8601String(Left(iso, 10) + "T12:00:00Z")
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    today = Left(now.ToISOString(), 10)
    if Left(iso, 10) = today then return "Today"
    mon = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    s = mon[dt.GetMonth() - 1] + " " + dt.GetDayOfMonth().toStr()
    if Left(iso, 4) <> Left(today, 4) then s = s + ", " + Left(iso, 4)
    return s
end function

sub drawRel(lst as object)
    if m.sel < m.top0 then m.top0 = m.sel
    if m.sel >= m.top0 + m.RROWS then m.top0 = m.sel - m.RROWS + 1
    if m.top0 < 0 then m.top0 = 0
    inRows = (m.top.active and m.zone = "rows")
    for i = 0 to m.RROWS - 1
        r = m.relPool[i]
        idx = m.top0 + i
        if idx >= lst.Count()
            r.g.visible = false
        else
            x = lst[idx]
            foc = (inRows and idx = m.sel)
            r.g.visible = true
            r.ring.visible = foc
            r.name.text = txt(x.title)
            k = txt(x.kind)
            if k = "ep" then k = "EP"
            s = txt(x.artist) + " " + Chr(183) + " " + k
            if txt(x.why) = "recommended" then s = s + " " + Chr(183) + " recommended"
            r.line2.text = s
            r.date.text = dayText(txt(x.date))
            if txt(x.img) <> "" then setUri(r.cover, nasBase() + x.img) else setUri(r.cover, "")
            st = txt(x.state)
            if st = "have"
                r.act.color = "0xA3A35AFF"
                r.act.text = "IN LIBRARY"
            else if st = "req"
                r.act.color = "0xE0B34AFF"
                r.act.text = "REQUESTED"
            else
                if foc then r.act.color = "0xE0B34AFF" else r.act.color = "0xEDE6CAFF"
                if st = "soon" then r.act.text = "GET WHEN OUT" else r.act.text = "REQUEST"
            end if
        end if
    end for
end sub

' the bottom line: where you are in the list on the left, what the keys do on the right
sub drawFoot(lst as object)
    s = ""
    if lst.Count() > 0
        if m.zone = "grid"
            al = curAlbums()
            if al.Count() > 0 then s = "Album " + (m.gsel + 1).toStr() + " of " + al.Count().toStr()
        else
            s = (m.sel + 1).toStr() + " of " + lst.Count().toStr()
            if m.mode = "missing" then s = s + "  " + Chr(183) + "  most played first"
            if m.mode = "loved" then s = s + "  " + Chr(183) + "  artists with albums you don't have"
            if m.mode = "releases" then s = s + "  " + Chr(183) + "  newest first"
        end if
    end if
    m.countLbl.text = s
    m.countLbl.visible = (m.toast.text = "")
    keys = []
    if m.top.active and lst.Count() > 0
        if m.zone = "list"
            keys.push({ text: "OK", label: "Albums" })
            if m.mode = "recs" then keys.push({ icon: "asterisk", label: "Not for me" }) else keys.push({ icon: "asterisk", label: "Hide artist" })
        else if m.zone = "grid"
            al = curAlbums()
            if m.gsel < al.Count()
                st = txt(al[m.gsel].state)
                if st = "miss" or st = "soon"
                    keys.push({ text: "OK", label: "Request this album" })
                else if st = "ext"
                    keys.push({ text: "OK", label: "Find it in Request" })
                end if
            end if
        else if m.zone = "rows" and m.sel < lst.Count()
            st = txt(lst[m.sel].state)
            if st <> "have" and st <> "req" then keys.push({ text: "OK", label: "Request" })
            keys.push({ icon: "asterisk", label: "Hide artist" })
        end if
    end if
    sig = ""
    for each k in keys
        sig = sig + k.label + "|"
    end for
    if sig <> m.hintSig
        m.hintSig = sig
        m.hints.keys = keys
    end if
    m.hints.visible = (keys.Count() > 0)
end sub

sub onOwned()
    if m.data <> invalid and isArtists() then paint()
end sub

' ---------------------------------------------------------------- keys
function modeIndex() as integer
    for i = 0 to m.MODES.Count() - 1
        if m.MODES[i] = m.mode then return i
    end for
    return 0
end function

sub switchMode(mode as string)
    if mode = m.mode then return
    m.mode = mode
    m.sel = 0
    m.top0 = 0
    m.zone = "chips"
    m.curArtist = ""
    m.btnSig = ""
    redraw()
end sub

' returns "up" or "left" when focus should leave the pane, "" otherwise
function handleKey(key as string) as string
    lst = curList()
    if m.zone <> "chips" and lst.Count() = 0 then m.zone = "chips"
    if m.zone = "chips"
        if key = "up" then return "up"
        i = modeIndex()
        if key = "left"
            if i > 0 then switchMode(m.MODES[i - 1]) else return "left"
            return ""
        else if key = "right"
            if i < m.MODES.Count() - 1 then switchMode(m.MODES[i + 1])
            return ""
        else if key = "down" or key = "OK"
            if lst.Count() > 0
                if isArtists() then m.zone = "list" else m.zone = "rows"
            end if
        end if
    else if m.zone = "rows"
        if key = "up"
            if m.sel > 0 then m.sel = m.sel - 1 else m.zone = "chips"
        else if key = "down"
            if m.sel < lst.Count() - 1 then m.sel = m.sel + 1
        else if key = "left"
            return "left"
        else if key = "OK"
            requestRelease(lst[m.sel])
        else if key = "options"
            hideArtist(txt(lst[m.sel].artist))
            return ""
        end if
    else if m.zone = "list"
        if key = "up"
            if m.sel > 0
                m.sel = m.sel - 1
                showDetail(lst[m.sel])
            else
                m.zone = "chips"
            end if
        else if key = "down"
            if m.sel < lst.Count() - 1
                m.sel = m.sel + 1
                showDetail(lst[m.sel])
            end if
        else if key = "left"
            return "left"
        else if key = "right" or key = "OK"
            if curAlbums().Count() > 0 then m.zone = "grid" else m.zone = "btns"
            m.btn = 0
        else if key = "options"
            hideArtist(lst[m.sel].name)
            return ""
        end if
    else if m.zone = "btns"
        if key = "left"
            if m.btn > 0 then m.btn = m.btn - 1 else m.zone = "list"
        else if key = "right"
            if m.btn < m.btnNodes.Count() - 1 then m.btn = m.btn + 1
        else if key = "up"
            m.zone = "chips"
        else if key = "down"
            if curAlbums().Count() > 0 then m.zone = "grid"
        else if key = "OK"
            doButton(lst[m.sel])
            return ""
        else if key = "options"
            hideArtist(lst[m.sel].name)
            return ""
        end if
    else if m.zone = "grid"
        al = curAlbums()
        col = m.gsel mod m.GCOLS
        if key = "left"
            if col > 0 then m.gsel = m.gsel - 1 else m.zone = "list"
        else if key = "right"
            if col < m.GCOLS - 1 and m.gsel < al.Count() - 1 then m.gsel = m.gsel + 1
        else if key = "up"
            if m.gsel >= m.GCOLS then m.gsel = m.gsel - m.GCOLS else m.zone = "btns"
        else if key = "down"
            if m.gsel + m.GCOLS < al.Count()
                m.gsel = m.gsel + m.GCOLS
            else if Int(m.gsel / m.GCOLS) < Int((al.Count() - 1) / m.GCOLS)
                m.gsel = al.Count() - 1     ' a short last row: land on its last album
            end if
        else if key = "OK"
            if m.gsel < al.Count() then requestAlbum(al[m.gsel])
            return ""
        else if key = "options"
            hideArtist(lst[m.sel].name)
            return ""
        end if
    end if
    if key <> "OK" and key <> "options" then m.confirm = ""
    paint()
    return ""
end function

' ---------------------------------------------------------------- actions
sub openRequest(artist as string)
    m.top.request = { action: "musicView", mode: "request", term: artist }
end sub

sub doButton(e as object)
    if m.btn >= m.btnDefs.Count() then return
    what = m.btnDefs[m.btn][2]
    if what = "hide"
        hideArtist(e.name)
    else if what = "open"
        openRequest(e.name)
    else
        n = getAllCount(e, m.albumCache[LCase(e.name)])
        ' a whole discography is a lot to ask for on one press: make sure
        if n > 5 and m.confirm <> e.name
            m.confirm = e.name
            say("Press OK again to ask Lidarr for all " + n.toStr() + " albums.")
            return
        end if
        m.confirm = ""
        if m.busy then return
        m.busy = true
        say("Asking Lidarr" + Chr(8230))
        nasCall("POST", "/api/discover/request", FormatJson({ "artist": e.name }), "onGotAll", e.name)
    end if
end sub

sub onGotAll(event as object)
    t = hTaskFrom(event)
    m.busy = false
    r = t.response
    if not t.ok or r.ok <> true
        say(failText(t, "Lidarr didn't take the request."))
        return
    end if
    c = m.albumCache[LCase(t.tag)]
    if c <> invalid and type(c.albums) = "roArray"
        for each a in c.albums
            if txt(a.state) = "miss" then a.state = "req"
        end for
        c.togo = 0
    end if
    setTogo(t.tag, 0)
    say("Asked Lidarr for " + plural(num(r.asked), "album", "albums") + " by " + t.tag + ".")
    refreshDetail()
end sub

function failText(t as object, fallback as string) as string
    if t.status = -1 or t.status = 0 then return "The NAS didn't answer. Try again in a moment."
    if t.response <> invalid and txt(t.response.error) <> "" then return t.response.error
    return fallback
end function

' keep the list's "N to get" in step with what was just asked for
sub setTogo(artist as string, n as integer)
    if m.data = invalid then return
    for each k in ["loved", "missing"]
        for each e in m.data[k]
            if e.name = artist then e.togo = n
        end for
    end for
end sub

sub refreshDetail()
    if not isArtists()
        paint()
        return
    end if
    lst = curList()
    if m.sel < lst.Count() then showDetail(lst[m.sel])
    paint()
end sub

sub requestAlbum(a as object)
    st = txt(a.state)
    if st = "have"
        say("That one is already in your library.")
    else if st = "req"
        say("Already asked for. Lidarr is looking for it.")
    else if st = "ext" or num(a.id) = 0
        openRequest(m.curArtist)
    else if not m.busy
        m.busy = true
        say("Asking Lidarr" + Chr(8230))
        nasCall("POST", "/api/discover/request", FormatJson({ "albumid": num(a.id) }), "onGotAlbum", num(a.id).toStr())
        m.reqFor[num(a.id).toStr()] = m.curArtist
    end if
end sub

sub onGotAlbum(event as object)
    t = hTaskFrom(event)
    m.busy = false
    if not t.ok or t.response.ok <> true
        say(failText(t, "Lidarr didn't take the request."))
        return
    end if
    artist = txt(m.reqFor[t.tag])
    id = Val(t.tag, 10)
    name = "that album"
    c = m.albumCache[LCase(artist)]
    if c <> invalid and type(c.albums) = "roArray"
        for each a in c.albums
            if num(a.id) = id
                if txt(a.state) = "miss"
                    c.togo = num(c.togo) - 1
                    if c.togo < 0 then c.togo = 0
                    setTogo(artist, c.togo)
                end if
                a.state = "req"
                name = txt(a.title)
            end if
        end for
    end if
    say("Asked Lidarr for " + name + ".")
    refreshDetail()
end sub

sub requestRelease(x as object)
    st = txt(x.state)
    if st = "have"
        say("That one is already in your library.")
    else if st = "req"
        say("Already asked for. Lidarr is looking for it.")
    else if num(x.id) = 0
        openRequest(txt(x.artist))
    else if not m.busy
        m.busy = true
        say("Asking Lidarr" + Chr(8230))
        nasCall("POST", "/api/discover/request", FormatJson({ "albumid": num(x.id) }), "onGotRelease", num(x.id).toStr())
    end if
end sub

sub onGotRelease(event as object)
    t = hTaskFrom(event)
    m.busy = false
    if not t.ok or t.response.ok <> true
        say(failText(t, "Lidarr didn't take the request."))
        return
    end if
    id = Val(t.tag, 10)
    name = "that album"
    if m.data <> invalid
        for each x in m.data.releases
            if num(x.id) = id
                x.state = "req"
                name = txt(x.title)
            end if
        end for
    end if
    say("Asked Lidarr for " + name + ".")
    paint()
end sub

' * hides an artist from every Discover list (kept on the NAS); * again while the message is up brings them back
sub hideArtist(name as string)
    if name = "" then return
    if m.lastHid <> "" and m.toast.text <> ""
        back = m.lastHid
        m.lastHid = ""
        m.gone.Delete(LCase(back))
        nasCall("POST", "/api/discover/unhide", FormatJson({ "name": back }), "onQuiet", "")
        say(back + " is back.")
        redraw()
        return
    end if
    m.gone[LCase(name)] = true
    nasCall("POST", "/api/discover/hide", FormatJson({ "name": name }), "onQuiet", "")
    if m.zone = "btns" or m.zone = "grid" then m.zone = "list"
    say("Hid " + name + ". Press * again to undo.")
    m.lastHid = name
    m.curArtist = ""
    redraw()
end sub

sub say(text as string)
    m.toast.text = text
    m.lastHid = ""
    m.countLbl.visible = false
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub hideToast()
    m.toast.text = ""
    m.lastHid = ""
    m.confirm = ""
    m.countLbl.visible = true
end sub
