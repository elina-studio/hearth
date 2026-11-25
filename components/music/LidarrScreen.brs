' Lidarr requests, layout C. The key lives only on the TV: registry "hearth" / "lidarrKey" (optional "lidarrUrl",
' default http://192.168.254.41:8686). It arrives from the Mac over ECP (/input?lidarrKey=...) via main.brs.
' Zones: "kb" (keyboard), "matches" (artists under the keyboard), "actions" (panel buttons), "albums" (panel covers).
sub init()
    m.top.findNode("eyebrow").font = hFont("caps", 30)
    m.kb = m.top.findNode("kb")
    m.kb.observeField("text", "onKbText")
    m.matches = m.top.findNode("matches")
    m.panel = m.top.findNode("panel")
    m.pv = m.top.findNode("pv")
    m.pvArt = m.top.findNode("pvArt")
    m.pvName = m.top.findNode("pvName")
    m.pvName.font = hFont("caps", 64)
    m.pvSub = m.top.findNode("pvSub")
    m.pvSub.font = hFont("regular", 26)
    m.pvButtons = m.top.findNode("pvButtons")
    m.top.findNode("pvAlbumsTitle").font = hFont("regular", 28)
    m.pvAlbums = m.top.findNode("pvAlbums")
    m.pvNote = m.top.findNode("pvNote")
    m.pvNote.font = hFont("regular", 22)
    m.empty = m.top.findNode("empty")
    m.empty.font = hFont("regular", 30)
    m.setup = m.top.findNode("setup")
    m.setupText = m.top.findNode("setupText")
    m.setupText.font = hFont("regular", 30)
    m.toast = m.top.findNode("toast")
    m.toast.font = hFont("bold", 26)
    m.toastTimer = m.top.findNode("toastTimer")
    m.toastTimer.observeField("fire", "hideToast")
    m.debounce = m.top.findNode("debounce")
    m.debounce.observeField("fire", "lookup")
    m.pvTimer = m.top.findNode("pvTimer")
    m.pvTimer.observeField("fire", "loadPreview")
    m.results = []
    m.sel = 0
    m.zone = "kb"
    m.btn = 0
    m.alb = 0
    m.btnActions = []
    m.pvData = invalid
    m.pvToken = 0
    m.defaults = invalid
    m.adding = false
    showPreview(false)
    if not m.global.hasField("lidarrKey") then m.global.addFields({ lidarrKey: "" })
    m.global.observeFieldScoped("lidarrKey", "onKeyArrived")
    start()
end sub

sub onShown(unused as dynamic)
    m.top.setFocus(true)
end sub

sub start()
    if not hasKey()
        showSetup("")
        return
    end if
    m.setup.visible = false
    m.kb.visible = true
    m.panel.visible = true
    m.empty.text = "Type an artist. Pick a match to see their albums and which ones you already have."
    paint()
    ' the profiles and folder new artists go into: the first of each
    m.defaults = {}
    lApi("GET", "/qualityprofile", {}, invalid, "onDefaults", "quality")
    lApi("GET", "/metadataprofile", {}, invalid, "onDefaults", "metadata")
    lApi("GET", "/rootfolder", {}, invalid, "onDefaults", "root")
end sub

sub onKeyArrived()
    if m.setup.visible and hasKey() then start()
end sub

sub showSetup(problem as string)
    m.kb.visible = false
    m.kb.active = false
    m.panel.visible = false
    showPreview(false)
    m.matches.removeChildrenIndex(m.matches.getChildCount(), 0)
    m.empty.text = ""
    q = Chr(34)
    nl = Chr(10)
    lines = []
    lines.push("ONE-TIME SETUP: CONNECT LIDARR")
    lines.push("")
    if problem <> "" then lines.push(problem) : lines.push("")
    lines.push("Requests go through Lidarr, which needs its key. You only do this once; after that this screen never comes back.")
    lines.push("")
    lines.push("1.  Leave this screen open on the TV.")
    lines.push("2.  On your Mac, open Terminal and paste the command from the Music thread in Hearth's project (it's also below).")
    lines.push("3.  Type your NAS password when it asks. This screen switches to Request by itself.")
    lines.push("")
    lines.push("KEY=$(ssh -t Elina@192.168.254.41 " + q + "sudo /usr/local/bin/docker exec lidarr cat /config/config.xml" + q + " | sed -n 's/.*<ApiKey>\(.*\)<\/ApiKey>.*/\1/p' | tr -d '\r'); curl -X POST -G --data-urlencode " + q + "lidarrKey=$KEY" + q + " http://192.168.254.9:8060/input")
    lines.push("")
    lines.push("The key stays on the TV. Press Back to leave.")
    m.setupText.text = lines.join(nl)
    m.setup.visible = true
end sub

' ---------- Lidarr calls ----------
function lApi(method as string, path as string, query as object, body as dynamic, cb as string, tag = "" as string) as object
    t = CreateObject("roSGNode", "LidarrTask")
    t.method = method
    ' searches go out to Lidarr's online music database, which can be slow: give them a minute
    if Instr(1, path, "/lookup") > 0 or method <> "GET" then t.timeout = 60000
    ' query and body go across as text: assocarray keys lose their capitals crossing into a Task,
    ' and Lidarr wants foreignArtistId, addOptions, albumsToMonitor... exactly as written
    qs = pxQuery(query)
    if qs <> "" then path = path + "?" + qs
    t.path = path
    if body <> invalid then t.bodyText = FormatJson(body)
    t.tag = tag
    t.observeField("done", cb)
    if m.hTasks = invalid then m.hTasks = {}
    key = "l" + Rnd(1000000).toStr()
    m.hTasks[key] = t
    t.key = key
    t.control = "RUN"
    return t
end function

function bad(t as object) as boolean
    if t.status = 401
        showSetup("Lidarr didn't accept the saved key.")
        return true
    end if
    if t.status = -1
        say("Lidarr didn't answer in time.")
        return true
    end if
    if t.status <= 0
        say("Can't reach Lidarr at the NAS.")
        return true
    end if
    if not t.ok
        say("Lidarr said no (error " + t.status.toStr() + ").")
        return true
    end if
    return false
end function

sub onDefaults(event as object)
    t = hTaskFrom(event)
    if bad(t) then return
    items = t.response.Items
    if items = invalid or items.Count() = 0 then return
    first = items[0]
    if t.tag = "root" then m.defaults.root = first.path else m.defaults[t.tag] = first.id
end sub

sub onKbText()
    m.debounce.control = "stop"
    if Len(m.kb.text) >= 2 then m.debounce.control = "start"
end sub

sub lookup()
    m.term = m.kb.text
    if m.results.Count() = 0 then m.empty.text = "Asking Lidarr" + Chr(8230)
    lApi("GET", "/artist/lookup", { term: m.term }, invalid, "onLookup", m.term)
end sub

sub onLookup(event as object)
    t = hTaskFrom(event)
    if t.tag <> m.kb.text then return
    if t.status = -1 or (t.status >= 500)
        ' Lidarr is up (the profiles loaded) but its online music database didn't answer:
        ' fall back to the artists Lidarr already has, and say so on screen
        m.empty.text = "Lidarr's online music database isn't answering, so new artists can't be found right now. Showing artists already in Lidarr."
        m.lookupFailed = true
        lApi("GET", "/artist", invalid, invalid, "onLocalArtists", t.tag)
        return
    end if
    if bad(t)
        if not m.setup.visible then m.empty.text = "Lidarr search failed. Try again in a moment."
        return
    end if
    m.lookupFailed = false
    m.results = []
    items = t.response.Items
    if items <> invalid
        for each a in items
            if m.results.Count() < 4 then m.results.push(a)
        end for
    end if
    m.sel = 0
    drawMatches()
    if m.results.Count() = 0
        showPreview(false)
        m.empty.text = "Lidarr found nobody called " + m.kb.text + "."
    else
        focusArtist(0, true)
    end if
    paint()
end sub

' Search the artists Lidarr already has, by name (used when the online lookup fails)
sub onLocalArtists(event as object)
    t = hTaskFrom(event)
    if t.tag <> m.kb.text then return
    if not t.ok then return
    want = LCase(t.tag)
    m.results = []
    items = t.response.Items
    if items <> invalid
        for each a in items
            if m.results.Count() < 4 and Instr(1, LCase(pxStr(a.artistName)), want) > 0 then m.results.push(a)
        end for
    end if
    m.sel = 0
    drawMatches()
    if m.results.Count() = 0
        showPreview(false)
    else
        focusArtist(0, true)
        say("Lidarr's online music database isn't answering. These are artists Lidarr already has.")
    end if
    paint()
end sub

' ---------- matches under the keyboard ----------
sub drawMatches()
    m.matches.removeChildrenIndex(m.matches.getChildCount(), 0)
    for i = 0 to m.results.Count() - 1
        a = m.results[i]
        g = m.matches.createChild("Group")
        g.translation = [0, i * 52]
        hl = g.createChild("Rectangle")
        hl.width = 620
        hl.height = 48
        hl.color = "0xE0B34A00"
        l = g.createChild("Label")
        l.translation = [16, 0]
        l.width = 590
        l.height = 48
        l.vertAlign = "center"
        l.maxLines = 1
        l.font = hFont("regular", 28)
        t = a.artistName
        if owned(a) then t = t + "  ·  in Lidarr"
        l.text = t
    end for
end sub

' ---------- the preview panel ----------
sub showPreview(on as boolean)
    m.pv.visible = on
    if on then m.empty.text = ""
end sub

' Show the artist straight away; their albums follow (debounced while you scroll the matches).
sub focusArtist(i as integer, now as boolean)
    if i < 0 or i >= m.results.Count() then return
    m.sel = i
    a = m.results[i]
    m.pvToken = m.pvToken + 1
    m.pvData = { a: a, token: m.pvToken.toStr(), lidarr: invalid, plex: invalid, albums: [] }
    m.alb = 0
    m.btn = 0
    showPreview(true)
    m.pvArt.uri = poster(a)
    m.pvName.text = UCase(a.artistName)
    m.pvSub.text = artistLine(a, "")
    m.pvAlbums.removeChildrenIndex(m.pvAlbums.getChildCount(), 0)
    m.pvNote.text = "Looking up albums" + Chr(8230)
    setButtons([])
    m.pvTimer.control = "stop"
    if now then loadPreview() else m.pvTimer.control = "start"
end sub

function artistLine(a as object, extra as string) as string
    bits = []
    if a.genres <> invalid and a.genres.Count() > 0 then bits.push(a.genres[0])
    if a.disambiguation <> invalid and a.disambiguation <> "" then bits.push(a.disambiguation)
    if extra <> "" then bits.push(extra)
    return bits.join("  ·  ")
end function

sub loadPreview()
    d = m.pvData
    if d = invalid then return
    a = d.a
    ' albums: Lidarr's own list when it already has the artist, otherwise an album search filtered to them
    if owned(a)
        lApi("GET", "/album", { artistId: a.id.toStr() }, invalid, "onPvAlbums", d.token)
    else
        lApi("GET", "/album/lookup", { term: a.artistName }, invalid, "onPvAlbums", d.token)
    end if
    ' what Plex already has: the artist with the same name, then their albums
    sec = muPlayer().section
    if pxReady() and sec <> ""
        pxApi("/library/sections/" + sec + "/all", { type: "8", title: a.artistName }, "onPlexArtist", d.token)
    else
        d.plex = {}
    end if
end sub

sub onPvAlbums(event as object)
    t = hTaskFrom(event)
    d = m.pvData
    if d = invalid or t.tag <> d.token then return
    if not t.ok
        d.lidarr = []
        if t.status = 401 then showSetup("Lidarr didn't accept the saved key.")
    else
        list = []
        items = t.response.Items
        if items <> invalid
            for each al in items
                if keepAlbum(al, d.a) then list.push(al)
            end for
        end if
        d.lidarr = newestFirst(list)
    end if
    merge()
end sub

' Albums and EPs by this artist (the lookup search also returns other artists' albums with similar names).
function keepAlbum(al as object, a as object) as boolean
    if al.artist <> invalid and al.artist.foreignArtistId <> invalid and a.foreignArtistId <> invalid
        if al.artist.foreignArtistId <> a.foreignArtistId then return false
    end if
    ty = ""
    if al.albumType <> invalid then ty = LCase(al.albumType)
    return ty = "" or ty = "album" or ty = "ep"
end function

function newestFirst(list as object) as object
    out = []
    for each al in list
        d = ""
        if al.releaseDate <> invalid then d = al.releaseDate
        k = 0
        while k < out.Count() and out[k].sortDate >= d
            k = k + 1
        end while
        al.sortDate = d
        tail = []
        for j = k to out.Count() - 1
            tail.push(out[j])
        end for
        while out.Count() > k
            out.pop()
        end while
        out.push(al)
        out.append(tail)
    end for
    if out.Count() > 12 then out = sliceTo(out, 12)
    return out
end function

function sliceTo(list as object, n as integer) as object
    out = []
    for i = 0 to n - 1
        out.push(list[i])
    end for
    return out
end function

sub onPlexArtist(event as object)
    t = hTaskFrom(event)
    d = m.pvData
    if d = invalid or t.tag <> d.token then return
    want = norm(d.a.artistName)
    for each md in pxItems(t)
        if norm(pxStr(md.title)) = want
            pxApi("/library/metadata/" + pxStr(md.ratingKey) + "/children", {}, "onPlexAlbums", d.token)
            return
        end if
    end for
    d.plex = {}
    merge()
end sub

sub onPlexAlbums(event as object)
    t = hTaskFrom(event)
    d = m.pvData
    if d = invalid or t.tag <> d.token then return
    d.plex = {}
    for each md in pxItems(t)
        d.plex[norm(pxStr(md.title))] = true
    end for
    merge()
end sub

' Lowercase letters and digits only, with "(Deluxe Edition)" / "[Remastered]" style endings dropped,
' so "Willow Lane (Deluxe)" in Plex matches "Willow Lane" in Lidarr.
function norm(s as string) as string
    s = LCase(s)
    for each cutAt in [" (", " [", " - "]
        p = Instr(1, s, cutAt)
        if p > 1 then s = Left(s, p - 1)
    end for
    if Left(s, 4) = "the " then s = Mid(s, 5)
    out = ""
    for i = 1 to Len(s)
        c = Mid(s, i, 1)
        if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") then out = out + c
    end for
    ' a title with no Latin letters or digits (Cyrillic...) must not collapse to "" or every such title matches every other
    if out = "" then out = s
    return out
end function

' Once both Lidarr's albums and Plex's titles are in, mark each album and draw the panel.
sub merge()
    d = m.pvData
    if d.lidarr = invalid or d.plex = invalid then return
    d.albums = []
    have = 0
    for each al in d.lidarr
        st = ""
        if d.plex[norm(pxStr(al.title))] = true
            st = "lib"
        else if al.statistics <> invalid and al.statistics.percentOfTracks <> invalid and al.statistics.percentOfTracks >= 100
            st = "lib"
        else if owned(d.a) and al.monitored = true
            st = "want"
        end if
        if st = "lib" then have = have + 1
        d.albums.push({ al: al, state: st })
    end for
    drawPanel()
end sub

sub drawPanel()
    d = m.pvData
    n = d.albums.Count()
    missing = missingAlbums()
    if n = 0
        m.pvSub.text = artistLine(d.a, "")
        m.pvNote.text = "Lidarr doesn't list any albums for this artist."
        if owned(d.a) then setButtons([]) else setButtons([["request", "Request artist", "all"]])
    else
        have = 0
        for each x in d.albums
            if x.state = "lib" then have = have + 1
        end for
        m.pvSub.text = artistLine(d.a, have.toStr() + " of " + n.toStr() + " albums in your library")
        if missing.Count() = 0
            m.pvNote.text = "You have or have asked for all of these."
            setButtons([])
        else
            m.pvNote.text = "OK on one album requests just that one. Albums you already have are dimmed and skipped."
            label = "Get the " + missing.Count().toStr() + " missing"
            if missing.Count() = n then label = "Get all " + n.toStr()
            btns = [["request", label, "missing"]]
            if missing.Count() > 1 then btns.push(["", "Latest only", "latest"])
            setButtons(btns)
        end if
    end if
    m.pvAlbums.removeChildrenIndex(m.pvAlbums.getChildCount(), 0)
    for i = 0 to n - 1
        drawAlbum(i * 188, d.albums[i])
    end for
    if m.alb >= n then m.alb = n - 1
    if m.alb < 0 then m.alb = 0
    if m.zone = "actions" and m.btnActions.Count() = 0 then m.zone = "matches"
    if m.zone = "albums" and n = 0 then m.zone = "matches"
    paint()
end sub

function missingAlbums() as object
    out = []
    if m.pvData = invalid then return out
    for each x in m.pvData.albums
        if x.state = "" then out.push(x)
    end for
    return out
end function

sub setButtons(defs as object)
    m.pvButtons.removeChildrenIndex(m.pvButtons.getChildCount(), 0)
    m.btnActions = []
    x = 0
    for each b in defs
        c = m.pvButtons.createChild("MusicChip")
        c.icon = b[0]
        c.text = b[1]
        c.translation = [x, 0]
        x = x + c.width + 12
        m.btnActions.push(b[2])
    end for
    if m.btn >= m.btnActions.Count() then m.btn = 0
end sub

sub drawAlbum(x as integer, item as object)
    al = item.al
    g = m.pvAlbums.createChild("Group")
    g.translation = [x, 0]
    ring = g.createChild("Rectangle")
    ring.translation = [-8, -8]
    ring.width = 182
    ring.height = 182
    ring.color = "0xE0B34A00"
    bg = g.createChild("Rectangle")
    bg.width = 166
    bg.height = 166
    bg.color = "0x1D2418FF"
    p = g.createChild("Poster")
    p.width = 166
    p.height = 166
    p.loadWidth = 166
    p.loadHeight = 166
    p.loadDisplayMode = "scaleToZoom"
    p.uri = cover(al)
    if item.state = "lib" then p.opacity = 0.55
    if item.state <> "" then badge(g, item.state)
    t = g.createChild("Label")
    t.translation = [0, 178]
    t.width = 166
    t.maxLines = 1
    t.font = hFont("bold", 22)
    t.color = "0xEDE6CAFF"
    t.text = pxStr(al.title)
    y = g.createChild("Label")
    y.translation = [0, 208]
    y.width = 166
    y.font = hFont("regular", 20)
    y.color = "0xB5AF8CFF"
    if al.releaseDate <> invalid then y.text = Left(al.releaseDate, 4)
end sub

sub badge(g as object, state as string)
    if state = "lib"
        text = "In library"
        icon = "check"
        c = "0xA9C46AFF"
    else
        text = "Requested"
        icon = "clock"
        c = "0xE0B34AFF"
    end if
    w = 40 + Len(text) * 11
    b = g.createChild("Rectangle")
    b.translation = [8, 8]
    b.width = w
    b.height = 32
    b.color = "0x0B0E09E6"
    i = g.createChild("Poster")
    i.translation = [14, 13]
    i.width = 22
    i.height = 22
    i.uri = "pkg:/images/music/icons/" + icon + ".png"
    i.blendColor = c
    l = g.createChild("Label")
    l.translation = [40, 8]
    l.height = 32
    l.vertAlign = "center"
    l.font = hFont("bold", 18)
    l.color = c
    l.text = text
end sub

function cover(al as object) as string
    if al.images = invalid then return ""
    for each im in al.images
        if im.coverType = "cover" and im.remoteUrl <> invalid then return im.remoteUrl
    end for
    for each im in al.images
        if im.remoteUrl <> invalid then return im.remoteUrl
    end for
    return ""
end function

function poster(a as object) as string
    if a.images = invalid then return ""
    for each im in a.images
        if im.coverType = "poster" and im.remoteUrl <> invalid then return im.remoteUrl
    end for
    for each im in a.images
        if im.remoteUrl <> invalid then return im.remoteUrl
    end for
    return ""
end function

function owned(a as object) as boolean
    return a.id <> invalid and a.id > 0
end function

sub paint()
    m.kb.active = (m.zone = "kb" and m.kb.visible)
    for i = 0 to m.matches.getChildCount() - 1
        g = m.matches.getChild(i)
        l = g.getChild(1)
        if i = m.sel and m.zone = "matches"
            g.getChild(0).color = "0xE0B34AFF"
            l.color = "0x1F1606FF"
        else if i = m.sel
            g.getChild(0).color = "0xE0B34A2E"
            l.color = "0xEDE6CAFF"
        else
            g.getChild(0).color = "0xE0B34A00"
            l.color = "0xB5AF8CFF"
        end if
    end for
    for i = 0 to m.pvButtons.getChildCount() - 1
        m.pvButtons.getChild(i).focused = (m.zone = "actions" and i = m.btn)
    end for
    for i = 0 to m.pvAlbums.getChildCount() - 1
        if m.zone = "albums" and i = m.alb then c = "0xE0B34AFF" else c = "0xE0B34A00"
        m.pvAlbums.getChild(i).getChild(0).color = c
    end for
    ' five covers fit; keep the focused one in view
    scrollX = (m.alb - 2) * 188
    maxX = (m.pvAlbums.getChildCount() - 5) * 188
    if scrollX > maxX then scrollX = maxX
    if scrollX < 0 then scrollX = 0
    m.pvAlbums.translation = [-scrollX, 302]
end sub

' ---------- requesting ----------
sub doAction(a as string)
    d = m.pvData
    if d = invalid then return
    if a = "all"
        requestAlbums([])
    else if a = "missing"
        requestAlbums(missingAlbums())
    else if a = "latest"
        mi = missingAlbums()
        if mi.Count() > 0 then requestAlbums([mi[0]])
    end if
end sub

' New artist: add them with only these albums monitored, and search. Known artist: monitor these albums and search.
sub requestAlbums(items as object)
    d = m.pvData
    a = d.a
    if m.adding then return
    m.adding = true
    foreign = []
    ids = []
    for each x in items
        if x.al.foreignAlbumId <> invalid then foreign.push(x.al.foreignAlbumId)
        if x.al.id <> invalid and x.al.id > 0 then ids.push(x.al.id)
    end for
    m.pending = items
    if items.Count() = 1 then what = pxStr(items[0].al.title) else what = items.Count().toStr() + " albums"
    if items.Count() = 0 then what = a.artistName
    m.pendingWhat = what
    names = []
    for each x in items
        names.push(pxStr(x.al.title))
    end for
    m.pendingArtist = pxStr(a.artistName)
    m.pendingNames = names
    if not owned(a)
        df = m.defaults
        if df = invalid or df.root = invalid or df.quality = invalid or df.metadata = invalid
            m.adding = false
            say("Lidarr hasn't told Hearth its folders yet. Try again in a moment.")
            return
        end if
        opts = { monitor: "none", albumsToMonitor: foreign, searchForMissingAlbums: true }
        if items.Count() = 0 then opts = { monitor: "all", searchForMissingAlbums: true }
        body = { foreignArtistId: a.foreignArtistId, artistName: a.artistName, qualityProfileId: df.quality, metadataProfileId: df.metadata, rootFolderPath: df.root, monitored: true, monitorNewItems: "none", addOptions: opts }
        say("Asking Lidarr for " + what + Chr(8230))
        lApi("POST", "/artist", {}, body, "onAdded", d.token)
    else
        say("Asking Lidarr for " + what + Chr(8230))
        m.searchIds = ids
        lApi("PUT", "/album/monitor", {}, { albumIds: ids, monitored: true }, "onMonitored", d.token)
    end if
end sub

sub onAdded(event as object)
    t = hTaskFrom(event)
    m.adding = false
    if bad(t) then return
    r = t.response
    d = m.pvData
    if d <> invalid and t.tag = d.token and r <> invalid and r.id <> invalid then d.a.id = r.id
    ' Lidarr searches a new artist only after it has fetched their albums; nudge it once that's likely done
    if r <> invalid and r.id <> invalid
        m.nudgeArtist = r.id
        nt = m.top.findNode("nudgeTimer")
        if nt = invalid
            nt = m.top.createChild("Timer")
            nt.id = "nudgeTimer"
            nt.duration = 20
            nt.observeField("fire", "onNudge")
        end if
        nt.control = "stop"
        nt.control = "start"
    end if
    done()
end sub

sub onNudge()
    if m.nudgeArtist = invalid then return
    lApi("GET", "/album", { artistId: m.nudgeArtist.toStr() }, invalid, "onNudgeAlbums")
end sub

' Search now for the monitored albums that have no files yet
sub onNudgeAlbums(event as object)
    t = hTaskFrom(event)
    if not t.ok or t.response = invalid or t.response.Items = invalid then return
    ids = []
    for each al in t.response.Items
        have = 0
        if al.statistics <> invalid and al.statistics.trackFileCount <> invalid then have = al.statistics.trackFileCount
        if al.monitored = true and have = 0 then ids.push(al.id)
    end for
    print "[hearth lidarr] new artist: searching "; ids.count(); " albums now"
    if ids.count() > 0 then lApi("POST", "/command", {}, { name: "AlbumSearch", albumIds: ids }, "onNudged")
end sub

sub onNudged(event as object)
    hTaskFrom(event)
end sub

sub onMonitored(event as object)
    t = hTaskFrom(event)
    if bad(t)
        m.adding = false
        return
    end if
    lApi("POST", "/command", {}, { name: "AlbumSearch", albumIds: m.searchIds }, "onSearched", t.tag)
end sub

sub onSearched(event as object)
    t = hTaskFrom(event)
    m.adding = false
    if bad(t) then return
    done()
end sub

' Mark what we just asked for as Requested and say so.
sub done()
    ' only now that Lidarr said yes does the New tab show "Requested"
    if m.pendingArtist <> invalid then muMarkRequested(m.pendingArtist, m.pendingNames)
    for each x in m.pending
        x.state = "want"
    end for
    if m.pvData <> invalid
        drawMatches()
        drawPanel()
    end if
    say(m.pendingWhat + " is on the way. It shows up in Music once Lidarr has it and Plex scans it.")
end sub

sub say(text as string)
    m.toast.text = text
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub hideToast()
    m.toast.text = ""
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
    if key = "back"
        if m.zone <> "kb" and not m.setup.visible
            m.zone = "kb"
            paint()
        else
            m.top.request = { action: "back" }
        end if
        return true
    end if
    if m.setup.visible then return true
    n = m.results.Count()
    if m.zone = "kb"
        edge = m.kb.callFunc("handleKey", key)
        if edge = "down" and n > 0 then m.zone = "matches"
        if edge = "right" and n > 0
            if m.btnActions.Count() > 0 then m.zone = "actions" else m.zone = "matches"
        end if
    else if m.zone = "matches"
        if key = "up"
            if m.sel = 0 then m.zone = "kb" else focusArtist(m.sel - 1, false)
        else if key = "down"
            if m.sel < n - 1 then focusArtist(m.sel + 1, false)
        else if key = "right" or key = "OK"
            if m.btnActions.Count() > 0
                m.zone = "actions"
            else if m.pvAlbums.getChildCount() > 0
                m.zone = "albums"
            end if
        end if
    else if m.zone = "actions"
        if key = "left"
            if m.btn > 0 then m.btn = m.btn - 1 else m.zone = "matches"
        else if key = "right"
            if m.btn < m.btnActions.Count() - 1 then m.btn = m.btn + 1
        else if key = "down"
            if m.pvAlbums.getChildCount() > 0 then m.zone = "albums"
        else if key = "OK"
            doAction(m.btnActions[m.btn])
        end if
    else if m.zone = "albums"
        count = m.pvAlbums.getChildCount()
        if key = "left"
            if m.alb > 0 then m.alb = m.alb - 1 else m.zone = "matches"
        else if key = "right"
            if m.alb < count - 1 then m.alb = m.alb + 1
        else if key = "up"
            if m.btnActions.Count() > 0 then m.zone = "actions"
        else if key = "OK"
            x = invalid
            if m.pvData <> invalid and m.alb >= 0 and m.alb < m.pvData.albums.Count() then x = m.pvData.albums[m.alb]
            if x = invalid
                ' the panel is being rebuilt (a late search answer): nothing to pick yet
            else if x.state = "lib"
                say(pxStr(x.al.title) + " is already in your library.")
            else if x.state = "want"
                say(pxStr(x.al.title) + " is already requested.")
            else
                requestAlbums([x])
            end if
        end if
    end if
    paint()
    return true
end function

' opened from an artist page: search for them straight away
sub onTerm()
    if m.top.term = "" or not hasKey() then return
    m.kb.text = m.top.term
    m.debounce.control = "stop"
    lookup()
end sub
function hasKey() as boolean
    return CreateObject("roRegistrySection", "hearth").Read("lidarrKey") <> ""
end function

sub muRestoreFocus()
    m.top.setFocus(true)
end sub
