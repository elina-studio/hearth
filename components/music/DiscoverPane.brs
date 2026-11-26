' Music > Discover. Zones: "chips" (the two chips), "list" (artists), "btns" (Get albums / Not for me).
' Keys go in through handleKey(key); it answers "left" or "up" when focus should leave the pane.
sub init()
    m.chips = m.top.findNode("chips")
    m.list = m.top.findNode("list")
    m.detail = m.top.findNode("detail")
    m.kick = m.top.findNode("kick")
    m.kick.font = hFont("caps", 24)
    m.title = m.top.findNode("title")
    m.title.font = hFont("bold", 44)
    m.meta = m.top.findNode("meta")
    m.meta.font = hFont("regular", 23)
    m.btns = m.top.findNode("btns")
    m.albums = m.top.findNode("albums")
    m.note = m.top.findNode("note")
    m.note.font = hFont("regular", 26)
    m.toast = m.top.findNode("toast")
    m.toast.font = hFont("bold", 26)
    m.toastTimer = m.top.findNode("toastTimer")
    m.toastTimer.observeField("fire", "hideToast")
    m.recheck = m.top.findNode("recheck")
    m.recheck.observeField("fire", "onRecheck")
    m.pvTimer = m.top.findNode("pvTimer")
    m.pvTimer.observeField("fire", "loadAlbums")
    m.chipNodes = []
    m.MODES = ["loved", "recs", "new", "missing"]
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
    m.rel = m.top.findNode("rel")
    m.relHints = m.top.findNode("relHints")
    m.relHints.keys = [{ text: "OK", label: "Request" }, { icon: "asterisk", label: "Hide this artist" }]
    m.relEmpty = m.top.findNode("relEmpty")
    m.relEmpty.font = hFont("regular", 26)
    m.relRows = []
    m.relSel = 0
    m.relTop = 0
    m.relData = {}
    m.requested = {}
    m.btnNodes = []
    m.ROWS = 6
    m.mode = "loved"     ' or "recs"
    m.zone = "list"
    m.sel = 0
    m.top0 = 0
    m.btn = 0
    m.data = invalid
    m.loaded = false
    m.hidden = {}
    m.albumCache = {}
    m.curArtist = ""
end sub

sub load(unused as dynamic)
    ' ask again when the NAS had nothing the first time (it was still building, or Last.fm wasn't paired yet)
    if m.loaded and m.data <> invalid and (m.data.built <> invalid and m.data.built > 0) then return
    if m.loaded and m.data = invalid then return
    m.loaded = true
    if m.data = invalid then m.note.text = "Asking the NAS" + Chr(8230)
    nasCall("GET", "/api/discover", "", "onData", "discover")
end sub

' while the NAS is still building, ask again every 15 s as long as the tab is on screen
sub onRecheck()
    if not m.top.visible then return
    m.loaded = false
    load(invalid)
end sub

sub onData(event as object)
    t = hTaskFrom(event)
    if not t.ok
        m.loaded = false
        if t.status = 401 or t.status = 403
            m.note.text = "The NAS helper didn't let the TV in. Run the security deploy again."
        else
            m.note.text = "Can't reach the Hearth helper on the NAS right now."
        end if
        return
    end if
    m.data = t.response
    if m.data.loved = invalid then m.data.loved = []
    if m.data.recs = invalid then m.data.recs = []
    if m.data.fresh = invalid then m.data.fresh = []
    if m.data.plays = invalid then m.data.plays = {}
    mergeNew()
    if m.missAll <> invalid then m.missAll = sortMissing(m.missAll)
    applyHide()
    redraw()
end sub

function names() as object
    if m.mode = "loved" then return m.data.loved
    return filtered()
end function

' recommended artists, minus the ones already in the Plex library or hidden this session
function filtered() as object
    if m.recsF <> invalid then return m.recsF
    known = {}
    if m.top.known <> invalid
        for each k in m.top.known
            known[LCase(k)] = true
        end for
    end if
    out = []
    for each e in m.data.recs
        n = LCase(e.name)
        if known[n] = invalid and m.hidden[n] = invalid then out.push(e)
    end for
    m.recsF = out
    return out
end function

function isRel() as boolean
    return m.mode = "new" or m.mode = "missing"
end function

sub redraw()
    m.recsF = invalid
    if isRel()
        m.list.removeChildrenIndex(m.list.getChildCount(), 0)
        m.detail.visible = false
        m.note.text = ""
        loadRel()
        paint()
        return
    end if
    m.rel.removeChildrenIndex(m.rel.getChildCount(), 0)
    m.relEmpty.text = ""
    m.list.removeChildrenIndex(m.list.getChildCount(), 0)
    items = invalid
    if m.data <> invalid then items = names()
    if items = invalid or items.Count() = 0
        m.detail.visible = false
        if m.data = invalid then return
        err = ""
        if m.data.error <> invalid then err = m.data.error
        if m.data.building <> true and m.data.built = 0 and err <> ""
            m.note.text = "The NAS couldn't build your lists from Last.fm: " + err + ". It tries again each time you open this tab."
        else if m.data.building = true or m.data.built = 0
            m.note.text = "The NAS is working out your lists from Last.fm. This page updates by itself."
            m.recheck.control = "start"
        else if m.data.user = ""
            m.note.text = "Pair Last.fm first (Music > * options > Last.fm), then your lists appear here."
        else
            m.note.text = "Nothing to show here yet."
        end if
        paint()
        return
    end if
    m.note.text = ""
    if m.sel >= items.Count() then m.sel = items.Count() - 1
    if m.sel < 0 then m.sel = 0
    drawRows(items)
    showDetail(items)
    paint()
end sub

sub drawRows(items as object)
    m.list.removeChildrenIndex(m.list.getChildCount(), 0)
    if m.sel < m.top0 then m.top0 = m.sel
    if m.sel >= m.top0 + m.ROWS then m.top0 = m.sel - m.ROWS + 1
    for i = 0 to m.ROWS - 1
        idx = m.top0 + i
        if idx >= items.Count() then exit for
        e = items[idx]
        g = m.list.createChild("Group")
        g.translation = [0, i * 96]
        ring = g.createChild("Poster")
        ring.translation = [-12, -4]
        ring.width = 444
        ring.height = 112
        ring.uri = "pkg:/images/w/button-outline" + hVar(idx) + ".9.png"
        ring.blendColor = "0xD9A066FF"
        ring.visible = (idx = m.sel and m.top.active and m.zone = "list")
        sel = g.createChild("Rectangle")
        sel.translation = [-4, 4]
        sel.width = 428
        sel.height = 88
        sel.color = "0xE0B34A14"
        sel.visible = (idx = m.sel and not ring.visible)
        ' artists in the Plex library show their round Plex photo; the rest a lettered disc
        av = g.createChild("Rectangle")
        av.translation = [4, 10]
        av.width = 68
        av.height = 68
        av.color = "0x23291EFF"
        img = ownedImage(e.name)
        if img <> ""
            ph = g.createChild("Poster")
            ph.translation = [4, 10]
            ph.width = 68
            ph.height = 68
            ph.loadDisplayMode = "scaleToZoom"
            ph.uri = img
        else
            lt = g.createChild("Label")
            lt.font = hFont("pica", 34)
            lt.translation = [4, 10]
            lt.width = 68
            lt.height = 68
            lt.horizAlign = "center"
            lt.vertAlign = "center"
            lt.color = "0xB5AF8CFF"
            lt.text = UCase(Left(e.name, 1))
        end if
        mk = g.createChild("Poster")
        mk.translation = [4, 10]
        mk.width = 68
        mk.height = 68
        mk.uri = "pkg:/images/music/round-mask.png"
        nm = g.createChild("Label")
        nm.font = hFont("bold", 26)
        nm.translation = [92, 12]
        nm.width = 230
        nm.maxLines = 1
        nm.color = "0xEDE6CAFF"
        nm.text = e.name
        sub2 = g.createChild("Label")
        sub2.font = hFont("regular", 19)
        sub2.translation = [92, 48]
        sub2.width = 250
        sub2.maxLines = 1
        sub2.color = "0xB5AF8CFF"
        if m.mode = "recs"
            if e.because <> invalid then sub2.text = "like " + e.because
        else if e.plays <> invalid
            sub2.text = e.plays.toStr() + " plays"
        end if
        if m.mode = "recs"
            b = g.createChild("Label")
            b.font = hFont("bold", 17)
            b.translation = [340, 28]
            b.color = "0xA3A35AFF"
            b.text = "NEW"
        end if
    end for
end sub

' the round Plex photo for an artist in the library, or ""
function ownedImage(name as string) as string
    o = m.top.owned
    if o = invalid then return ""
    v = o[LCase(name)]
    if v = invalid then return ""
    return v
end function

' the room sends the Plex artist list once it has it: drop owned artists from Recommended and redraw
sub onKnown()
    m.recsF = invalid
    if m.data <> invalid then redraw()
end sub

function avatarColor(name as string) as string
    h = 0
    for i = 1 to Len(name)
        h = (h * 31 + Asc(Mid(name, i, 1))) mod 997
    end for
    pal = ["0x5C5A2AFF", "0x2A5A33FF", "0x2A4A5AFF", "0x3A2A5AFF", "0x5A2A4AFF", "0x5A3A2AFF"]
    return pal[h mod 6]
end function

sub showDetail(items as object)
    e = items[m.sel]
    m.detail.visible = true
    m.curArtist = e.name
    if m.mode = "recs"
        m.kick.text = "RECOMMENDED"
        m.title.text = e.name
        because = "artists you play"
        if e.because <> invalid then because = e.because
        m.meta.text = "Because you play " + because + ". Not in your library yet."
    else
        m.kick.text = "ARTISTS YOU LOVE"
        m.title.text = e.name
        if e.plays <> invalid then m.meta.text = e.plays.toStr() + " plays on Last.fm" else m.meta.text = "On Last.fm"
        o = m.top.owned
        if o <> invalid and o[LCase(e.name)] <> invalid then m.meta.text = m.meta.text + "  ·  In your library"
    end if
    buildButtons()
    m.albums.removeChildrenIndex(m.albums.getChildCount(), 0)
    c = m.albumCache[LCase(e.name)]
    if c <> invalid then drawAlbums(c) else m.pvTimer.control = "start"
end sub

sub buildButtons()
    m.btns.removeChildrenIndex(m.btns.getChildCount(), 0)
    m.btnNodes = []
    defs = [["request", "Get albums"]]
    if m.mode = "recs" then defs.push(["thumbdown", "Not for me"])
    x = 0
    for each d in defs
        c = m.btns.createChild("MusicChip")
        c.icon = d[0]
        c.text = d[1]
        c.translation = [x, 0]
        x = x + c.width + 16
        m.btnNodes.push(c)
    end for
end sub

sub loadAlbums()
    nasCall("GET", "/api/discover/albums?artist=" + pxEscape(m.curArtist), "", "onAlbums", m.curArtist)
end sub

sub onAlbums(event as object)
    t = hTaskFrom(event)
    if not t.ok or t.response.albums = invalid then return
    m.albumCache[LCase(t.tag)] = t.response.albums
    if t.tag = m.curArtist then drawAlbums(t.response.albums)
end sub

' no cover art here (Last.fm doesn't give any), so each album is a plain tile with its name
sub drawAlbums(list as object)
    m.albums.removeChildrenIndex(m.albums.getChildCount(), 0)
    n = 0
    for each a in list
        if n >= 5 then exit for
        col = n mod 3
        row = Int(n / 3)
        g = m.albums.createChild("Group")
        g.translation = [col * 216, row * 250]
        r = g.createChild("Rectangle")
        r.width = 196
        r.height = 196
        r.color = avatarColor(a.name + "x")
        t = g.createChild("Label")
        t.font = hFont("bold", 22)
        t.translation = [10, 120]
        t.width = 176
        t.height = 70
        t.wrap = true
        t.maxLines = 3
        t.vertAlign = "bottom"
        t.color = "0xFFFFFFCC"
        t.text = a.name
        n = n + 1
    end for
end sub

sub paint()
    for i = 0 to m.chipNodes.Count() - 1
        c = m.chipNodes[i]
        c.on = (m.MODES[i] = m.mode)
        c.focused = (m.top.active and m.zone = "chips" and m.MODES[i] = m.mode)
    end for
    if isRel()
        drawRel()
        return
    end if
    for i = 0 to m.btnNodes.Count() - 1
        m.btnNodes[i].focused = (m.top.active and m.zone = "btns" and i = m.btn)
    end for
    if m.data <> invalid and m.list.getChildCount() > 0
        items = names()
        if items.Count() > 0 then drawRows(items)
    end if
end sub

' returns "up" or "left" when focus should leave the pane, "" otherwise
function handleKey(key as string) as string
    if m.data = invalid and not isRel()
        if key = "up" then return "up"
        if key = "left" then return "left"
        return ""
    end if
    if m.zone = "chips"
        if key = "up" then return "up"
        i = modeIndex()
        if key = "left"
            if i > 0 then switchMode(m.MODES[i - 1]) else return "left"
        else if key = "right"
            if i < m.MODES.Count() - 1 then switchMode(m.MODES[i + 1])
        else if key = "down" or key = "OK"
            if isRel()
                if relItems().Count() > 0 then m.zone = "rows"
            else if names().Count() > 0
                m.zone = "list"
            end if
        end if
    else if m.zone = "rows"
        items = relItems()
        if key = "up"
            if m.relSel > 0 then m.relSel = m.relSel - 1 else m.zone = "chips"
        else if key = "down"
            if m.relSel < items.Count() - 1 then m.relSel = m.relSel + 1
        else if key = "left"
            m.zone = "chips"
        else if key = "OK"
            requestRel()
        else if key = "options"
            toggleRelHide()
        end if
    else if m.zone = "list"
        items = names()
        if key = "up"
            if m.sel > 0 then m.sel = m.sel - 1 else m.zone = "chips"
            if m.zone = "list" then showDetail(items)
        else if key = "down"
            if m.sel < items.Count() - 1
                m.sel = m.sel + 1
                showDetail(items)
            end if
        else if key = "left"
            return "left"
        else if key = "right" or key = "OK"
            if items.Count() > 0 then m.zone = "btns" : m.btn = 0
        end if
    else if m.zone = "btns"
        if key = "left"
            if m.btn > 0 then m.btn = m.btn - 1 else m.zone = "list"
        else if key = "right"
            if m.btn < m.btnNodes.Count() - 1 then m.btn = m.btn + 1
        else if key = "up"
            m.zone = "chips"
        else if key = "OK"
            doButton()
        end if
    end if
    paint()
    return ""
end function

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
    m.relSel = 0
    m.relTop = 0
    m.zone = "chips"
    redraw()
end sub

' ---------- New releases and Missing: straight from Lidarr ----------
' New releases = Lidarr's calendar for artists you follow (45 days back, 120 ahead).
' Missing = albums of artists Lidarr has that nobody is looking for (unmonitored, no files).
' OK on a row asks Lidarr for it: monitor the album, and search now unless it isn't out yet.
function lidarrKeyOk() as boolean
    return CreateObject("roRegistrySection", "hearth").Read("lidarrKey") <> ""
end function

function relItems() as object
    d = m.relData[m.mode]
    if d = invalid then return []
    return d
end function

sub loadRel()
    if not lidarrKeyOk()
        if m.mode = "new" then mergeNew()
        if m.mode = "new" and relItems().Count() > 0
            m.relEmpty.text = ""
        else
            m.relEmpty.text = "Connect Lidarr first (Music > Request shows the one-time steps)."
        end if
        return
    end if
    asked = m.relData[m.mode] <> invalid
    if m.mode = "new" then asked = (m.lidarrNew <> invalid)
    if asked
        m.relEmpty.text = ""
        return
    end if
    if m.relAsk = invalid then m.relAsk = {}
    if m.relAsk[m.mode] = true then return
    m.relAsk[m.mode] = true
    if relItems().Count() = 0 then m.relEmpty.text = "Asking Lidarr" + Chr(8230)
    if m.mode = "new"
        q = { "start": isoDay(-45), "end": isoDay(120), "unmonitored": "true", "includeArtist": "true" }
        dApi("GET", "/calendar", q, invalid, "onRel", "new")
    else
        q = { page: "1", pageSize: "400", sortKey: "releaseDate", sortDirection: "descending", includeArtist: "true", monitored: "false" }
        dApi("GET", "/wanted/missing", q, invalid, "onRel", "missing")
    end if
end sub

function isoDay(offset as integer) as string
    dt = CreateObject("roDateTime")
    dt.FromSeconds(dt.AsSeconds() + offset * 86400)
    return dt.ToISOString().Left(10)
end function

function dApi(method as string, path as string, query as object, body as dynamic, cb as string, tag = "" as string) as object
    t = CreateObject("roSGNode", "LidarrTask")
    t.method = method
    qs = pxQuery(query)
    if qs <> "" then path = path + "?" + qs
    t.path = path
    if method <> "GET" then t.timeout = 60000
    if body <> invalid then t.bodyText = FormatJson(body)
    t.tag = tag
    t.observeField("done", cb)
    if m.hTasks = invalid then m.hTasks = {}
    key = "d" + Rnd(1000000).toStr()
    m.hTasks[key] = t
    t.key = key
    t.control = "RUN"
    return t
end function

sub onRel(event as object)
    t = hTaskFrom(event)
    if m.relAsk <> invalid then m.relAsk[t.tag] = false
    if not t.ok and t.tag = "new" and relItems().Count() > 0 and m.mode = "new"
        m.lidarrNew = []
        return
    end if
    if t.status = 401
        m.relEmpty.text = "Lidarr didn't accept the saved key."
        return
    end if
    if not t.ok
        m.relEmpty.text = "Can't reach Lidarr right now (error " + t.status.toStr() + ")."
        return
    end if
    raw = invalid
    if t.response.Items <> invalid then raw = t.response.Items else raw = t.response.records
    if raw = invalid then raw = []
    now = CreateObject("roDateTime").AsSeconds()
    out = []
    for each al in raw
        kind = LCase(pxStr(al.albumType))
        if kind = "album" or kind = "ep" or kind = ""
            have = 0
            if al.statistics <> invalid and al.statistics.trackFileCount <> invalid then have = al.statistics.trackFileCount
            when = dateSecs(pxStr(al.releaseDate))
            artist = ""
            if al.artist <> invalid then artist = pxStr(al.artist.artistName)
            st = "req"
            if have > 0 then st = "have"
            if st = "req" and al.monitored = true then st = "pend"
            if st = "req" and when > now then st = "pre"
            if not (t.tag = "new" and st = "have" and when < now - 21 * 86400)
                rating = 0
                if al.ratings <> invalid and al.ratings.value <> invalid then rating = al.ratings.value
                out.push({ id: al.id, key: al.id.toStr(), title: pxStr(al.title), artist: artist, kind: kind, when: when, state: st, cover: coverUrl(al), future: (when > now), rating: rating, why: "" })
            end if
        end if
    end for
    if t.tag = "new"
        m.lidarrNew = out
        mergeNew()
        out = m.relData["new"]
    else
        m.missAll = sortMissing(out)
        applyHide()
        out = m.relData["missing"]
    end if
    if t.tag = m.mode
        if out.Count() = 0
            if t.tag = "new" then m.relEmpty.text = "Nothing new from your artists in the last six weeks or the next four months." else m.relEmpty.text = "You have every album Lidarr knows about."
        else
            m.relEmpty.text = ""
        end if
        paint()
    end if
end sub

' New releases = Lidarr's calendar plus what MusicBrainz says your Last.fm artists (top 300 + top 40 recommended)
' put out lately or have coming. Lidarr's copy wins when both have the same album, since OK can request it directly.
sub mergeNew()
    now = CreateObject("roDateTime").AsSeconds()
    all = []
    seen = {}
    if m.lidarrNew <> invalid
        for each x in m.lidarrNew
            seen[LCase(x.artist) + "|" + LCase(x.title)] = true
            all.push(x)
        end for
    end if
    if m.data <> invalid and m.data.fresh <> invalid
        for each f in m.data.fresh
            k = LCase(pxStr(f.artist)) + "|" + LCase(pxStr(f.title))
            if seen[k] = invalid
                seen[k] = true
                when = dateSecs(pxStr(f.date))
                cover = ""
                if pxStr(f.rgid) <> "" then cover = "https://coverartarchive.org/release-group/" + pxStr(f.rgid) + "/front-250"
                all.push({ id: 0, key: "mb" + pxStr(f.rgid), title: pxStr(f.title), artist: pxStr(f.artist), kind: LCase(pxStr(f.kind)), when: when, state: "ext", cover: cover, future: (when > now), rating: 0, why: pxStr(f.why) })
            end if
        end for
    end if
    if m.lidarrNew = invalid and all.Count() = 0 then return
    ' coming soon first (soonest on top), then what came out recently (newest on top)
    soon = []
    past = []
    for each x in all
        if x.future then soon.push(x) else past.push(x)
    end for
    soon.SortBy("when")
    past.SortBy("when", "r")
    out = []
    out.Append(soon)
    out.Append(past)
    hid = relHidden()
    keep = []
    for each x in out
        if hid[LCase(x.artist)] = invalid then keep.push(x)
    end for
    m.relData["new"] = keep
end sub

' Artists hidden from New releases and Missing with the * button. Kept on the TV.
function relHidden() as object
    if m.relHid = invalid
        m.relHid = {}
        j = ParseJson(CreateObject("roRegistrySection", "hearth").Read("discRelHide"))
        if j <> invalid
            for each n in j
                m.relHid[LCase(n)] = n
            end for
        end if
    end if
    return m.relHid
end function

sub saveRelHidden()
    hidList = []
    for each k in m.relHid
        hidList.push(m.relHid[k])
    end for
    reg = CreateObject("roRegistrySection", "hearth")
    reg.Write("discRelHide", FormatJson(hidList))
    reg.Flush()
end sub

sub applyHide()
    if m.missAll <> invalid
        hid = relHidden()
        keep = []
        for each x in m.missAll
            if hid[LCase(x.artist)] = invalid then keep.push(x)
        end for
        m.relData["missing"] = keep
    end if
    mergeNew()
end sub

' * on a row: hide that artist from both lists; * again while the note is up brings them back
sub toggleRelHide()
    if m.lastHid <> "" and m.lastHid <> invalid and m.toast.text <> ""
        relHidden().Delete(LCase(m.lastHid))
        saveRelHidden()
        say(m.lastHid + " is back.")
        m.lastHid = ""
        applyHide()
        return
    end if
    items = relItems()
    if items.Count() = 0 then return
    a = items[m.relSel].artist
    if a = "" then return
    relHidden()[LCase(a)] = a
    saveRelHidden()
    m.lastHid = a
    applyHide()
    say(a + " hidden from New releases and Missing. Press * again to undo.")
    if relItems().Count() = 0 then m.zone = "chips"
end sub

' Missing: artists you play most on Last.fm first, then Lidarr's album rating, then newest
function sortMissing(items as object) as object
    plays = {}
    if m.data <> invalid and m.data.plays <> invalid then plays = m.data.plays
    for each x in items
        p = plays[LCase(x.artist)]
        if p = invalid then p = 0
        x.plays = p
        x.rank = p * 1000.0 + x.rating * 10.0 + x.when / 1000000000.0
    end for
    items.SortBy("rank", "r")
    return items
end function

function dateSecs(iso as string) as integer
    if Len(iso) < 10 then return 0
    dt = CreateObject("roDateTime")
    dt.FromISO8601String(Left(iso, 10) + "T00:00:00")
    return dt.AsSeconds()
end function

function coverUrl(al as object) as string
    if al.images = invalid then return ""
    for each im in al.images
        if LCase(pxStr(im.coverType)) = "cover" and pxStr(im.remoteUrl) <> "" then return pxStr(im.remoteUrl)
    end for
    return ""
end function

function dayText(secs as integer) as string
    if secs = 0 then return ""
    dt = CreateObject("roDateTime")
    dt.FromSeconds(secs)
    now = CreateObject("roDateTime").AsSeconds()
    diff = Int((secs - now) / 86400)
    if diff = 0 or (secs <= now and now - secs < 86400) then return "Today"
    mon = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    t = mon[dt.GetMonth() - 1] + " " + dt.GetDayOfMonth().toStr()
    if secs > now and diff < 7 then t = Left(dt.GetWeekday(), 3) + ", " + t
    if Abs(secs - now) > 300 * 86400 then t = t + ", " + dt.GetYear().toStr()
    return t
end function

sub drawRel()
    m.rel.removeChildrenIndex(m.rel.getChildCount(), 0)
    items = relItems()
    m.relHints.visible = (m.top.active and m.zone = "rows" and m.toast.text = "" and items.Count() > 0)
    if items.Count() = 0 then return
    if m.relSel >= items.Count() then m.relSel = items.Count() - 1
    visible = 7
    if m.relSel < m.relTop then m.relTop = m.relSel
    if m.relSel >= m.relTop + visible then m.relTop = m.relSel - visible + 1
    for i = 0 to visible - 1
        idx = m.relTop + i
        if idx >= items.Count() then exit for
        x = items[idx]
        foc = (idx = m.relSel and m.top.active and m.zone = "rows")
        g = m.rel.createChild("Group")
        g.translation = [0, i * 100]
        bg = g.createChild("Poster")
        bg.translation = [-12, -12]
        bg.width = 1174
        bg.height = 100
        bg.uri = "pkg:/images/w/panel-v3.9.png"
        bg.blendColor = "0x141A11FF"
        if foc
            rg = g.createChild("Poster")
            rg.translation = [-12, -12]
            rg.width = 1174
            rg.height = 100
            rg.uri = "pkg:/images/w/button-outline" + hVar(idx) + ".9.png"
            rg.blendColor = "0xD9A066FF"
        end if
        art = g.createChild("Rectangle")
        art.translation = [14, 10]
        art.width = 64
        art.height = 64
        art.color = avatarColor(x.title)
        if x.cover <> ""
            cp = g.createChild("Poster")
            cp.translation = [14, 10]
            cp.width = 64
            cp.height = 64
            cp.loadDisplayMode = "scaleToZoom"
            cp.uri = x.cover
        end if
        tl = g.createChild("Label")
        tl.font = hFont("bold", 28)
        tl.translation = [96, 6]
        tl.width = 660
        tl.maxLines = 1
        tl.color = "0xEDE6CAFF"
        tl.text = x.title
        sl = g.createChild("Label")
        sl.font = hFont("regular", 22)
        sl.translation = [96, 44]
        sl.width = 660
        sl.maxLines = 1
        sl.color = "0xB5AF8CFF"
        k = x.kind
        if k = "ep" then k = "EP"
        sl.text = x.artist + " · " + k
        if x.why = "recommended" then sl.text = sl.text + " · recommended"
        if m.mode = "missing" and x.plays > 0 then sl.text = sl.text + " · " + x.plays.toStr() + " plays"
        dl = g.createChild("Label")
        dl.font = hFont("regular", 23)
        dl.translation = [740, 20]
        dl.width = 200
        dl.horizAlign = "right"
        dl.color = "0xB5AF8CFF"
        dl.text = dayText(x.when)
        al = g.createChild("Label")
        al.font = hFont("bold", 22)
        al.translation = [960, 20]
        al.width = 190
        al.horizAlign = "right"
        st = x.state
        if m.requested[x.key] = true then st = "pend"
        if st = "have"
            al.color = "0xA3A35AFF"
            al.text = "IN LIBRARY"
        else if st = "pend"
            al.color = "0xE0B34AFF"
            al.text = "REQUESTED"
        else
            if foc then al.color = "0xE0B34AFF" else al.color = "0xEDE6CAFF"
            if st = "pre" then al.text = "GET WHEN OUT" else al.text = "REQUEST"
        end if
    end for
end sub

sub requestRel()
    items = relItems()
    if items.Count() = 0 then return
    x = items[m.relSel]
    st = x.state
    if m.requested[x.key] = true then st = "pend"
    if st = "ext"
        ' Lidarr doesn't follow this artist yet: open the request screen on them
        m.top.request = { action: "musicView", mode: "request", term: x.artist }
        return
    end if
    if st = "have" or st = "pend"
        say(x.title + " is already " + iif(st = "have", "in your library.", "requested."))
        return
    end if
    if m.relBusy = true then return
    m.lastHid = ""
    m.relBusy = true
    m.reqItem = x
    say("Asking Lidarr for " + x.title + Chr(8230))
    dApi("PUT", "/album/monitor", {}, { albumIds: [x.id], monitored: true }, "onRelMonitored", x.key)
end sub

sub onRelMonitored(event as object)
    t = hTaskFrom(event)
    m.relBusy = false
    if not t.ok
        say("Lidarr said no (error " + t.status.toStr() + ").")
        return
    end if
    m.requested[t.tag] = true
    x = m.reqItem
    if x <> invalid and not x.future
        dApi("POST", "/command", {}, { name: "AlbumSearch", albumIds: [x.id] }, "onRelSearched")
        say(x.title + " requested. Lidarr is searching.")
    else if x <> invalid
        say(x.title + " will be fetched when it comes out.")
    end if
    paint()
end sub

sub onRelSearched(event as object)
    hTaskFrom(event)
end sub

function iif(c as boolean, a as string, b as string) as string
    if c then return a
    return b
end function

sub doButton()
    items = names()
    if items.Count() = 0 then return
    e = items[m.sel]
    if m.btn = 0
        m.top.request = { action: "musicView", mode: "request", term: e.name }
    else
        ' Not for me: the NAS never recommends them again
        m.hidden[LCase(e.name)] = true
        nasCall("POST", "/api/discover/hide", FormatJson({ name: e.name }), "onHidden", e.name)
        say(e.name + " won't be recommended again.")
        m.zone = "list"
        redraw()
    end if
end sub

sub onHidden(event as object)
end sub

sub say(text as string)
    m.toast.text = text
    m.relHints.visible = false
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub hideToast()
    m.toast.text = ""
    m.lastHid = ""
    paint()
end sub
