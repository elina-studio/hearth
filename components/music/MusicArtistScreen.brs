' Artist page, layout B2: slim header, album list on the left, songs in two columns on the right.
' Zones: "top" (Play all / Shuffle / Get missing), "albums", "abtn" (album Play / Shuffle), "songs".

sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.art = m.top.findNode("art")
    m.name = m.top.findNode("name")
    m.name.font = hFont("caps", 64)
    m.top.findNode("albHead").font = hFont("fell", 40)
    m.sub = m.top.findNode("sub")
    m.sub.font = hFont("regular", 24)
    m.albumList = m.top.findNode("albums")
    m.cover = m.top.findNode("cover")
    m.aTitle = m.top.findNode("aTitle")
    m.aTitle.font = hFont("bold", 48)
    m.aSub = m.top.findNode("aSub")
    m.aSub.font = hFont("regular", 24)
    m.songs = m.top.findNode("songs")
    m.divider = m.top.findNode("divider")
    m.pageL = m.top.findNode("page")
    m.pageL.font = hFont("regular", 22)
    m.toast = m.top.findNode("toast")
    m.toast.font = hFont("bold", 26)
    m.toastTimer = m.top.findNode("toastTimer")
    m.toastTimer.observeField("fire", "hideToast")

    m.topBtns = makeChips(m.top.findNode("buttons"), [["play", "Play all", "play"], ["shuffle", "Shuffle", "shuffle"], ["request", "Get missing albums", "lidarr"]], 1824)
    m.albBtns = makeChips(m.top.findNode("aButtons"), [["play", "Play", "playAlbum"], ["shuffle", "", "shuffleAlbum"]], 1144)

    m.bar = m.top.findNode("bar")
    m.bar.observeField("request", "onBarRequest")
    m.zone = "albums"
    m.aboveBar = "albums"
    m.topSel = 0
    m.abtnSel = 0
    m.sel = 0
    m.song = 0
    m.page = 0
    m.albums = []
    m.albumRows = []
    m.songNodes = []
    muPlayer().observeFieldScoped("track", "drawSongs")
end sub

' Lays chips out right-aligned so the row ends at rightEdge. Returns { nodes, actions }.
function makeChips(parent as object, defs as object, rightEdge as integer) as object
    out = { nodes: [], actions: [] }
    x = 0
    for each d in defs
        c = parent.createChild("MusicChip")
        c.icon = d[0]
        c.text = d[1]
        c.name = d[1]
        out.nodes.push(c)
        out.actions.push(d[2])
    end for
    total = 0
    for each c in out.nodes
        total = total + c.width + 12
    end for
    x = rightEdge - total + 12
    for each c in out.nodes
        c.translation = [x, 0]
        x = x + c.width + 12
    end for
    return out
end function

sub onShown(unused as dynamic)
    m.top.setFocus(true)
end sub

' ---------- loading ----------
sub load(unused = invalid as dynamic)
    id = m.top.artistId
    ' this artist's own twig under "Albums" (the same one every visit)
    th = 0
    for ci = 1 to Len(id)
        th = (th * 31 + Asc(Mid(id, ci, 1))) mod 1009
    end for
    m.top.findNode("albTwig").uri = "pkg:/images/w/twig-420-s" + ((th mod 4) + 4).toStr() + ".png"
    if id = "" then return
    m.name.text = "Loading" + Chr(8230)
    pxApi("/library/metadata/" + id, {}, "onArtist")
    pxApi("/library/metadata/" + id + "/children", {}, "onAlbums")
end sub

sub onArtist(event as object)
    t = hTaskFrom(event)
    items = pxItems(t)
    if items.Count() = 0
        m.name.text = ""
        if t.status <= 0 then say("Can't reach Plex.") else say("Couldn't open this artist.")
        return
    end if
    a = items[0]
    m.artist = a
    m.name.text = UCase(pxStr(a.title))
    m.art.uri = pxImage(a.thumb, 120, 120)
    if a.art <> invalid then m.backdrop.uri = pxImage(a.art, 640, 360, 30)
    sec = muPlayer().section
    if sec <> "" then pxApi("/library/sections/" + sec + "/all", { type: "8", title: pxStr(a.title) }, "onArtistTwins")
end sub

sub onAlbums(event as object)
    t = hTaskFrom(event)
    m.albumKeys = {}
    m.rawAlbums = []
    addAlbums(pxItems(t))
    if m.rawAlbums.Count() = 0
        if t.status <= 0 then say("Can't reach Plex.") else say("No albums for this artist.")
        m.zone = "top"
    end if
    arrange(m.top.openAlbumId)
end sub

' Plex sometimes files one artist twice (two spellings or IDs), which splits their albums.
' Look for other artists with the same name and fold their albums in.
sub onArtistTwins(event as object)
    t = hTaskFrom(event)
    want = normName(m.name.text)
    for each md in pxItems(t)
        if pxStr(md.ratingKey) <> m.top.artistId and normName(pxStr(md.title)) = want
            pxApi("/library/metadata/" + pxStr(md.ratingKey) + "/children", {}, "onMoreAlbums")
        end if
    end for
end sub

sub onMoreAlbums(event as object)
    t = hTaskFrom(event)
    before = m.rawAlbums.Count()
    addAlbums(pxItems(t))
    if m.rawAlbums.Count() = before then return
    keep = ""
    if m.sel < m.albums.Count() then keep = pxStr(m.albums[m.sel].md.ratingKey)
    arrange(keep)
end sub

function normName(s as string) as string
    s = LCase(s)
    if Left(s, 4) = "the " then s = Mid(s, 5)
    out = ""
    for i = 1 to Len(s)
        c = Mid(s, i, 1)
        if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") then out = out + c
    end for
    return out
end function

sub addAlbums(items as object)
    if m.albumKeys = invalid then m.albumKeys = {}
    if m.rawAlbums = invalid then m.rawAlbums = []
    for each md in items
        k = pxStr(md.ratingKey)
        if md.type = "album" and m.albumKeys[k] = invalid
            m.albumKeys[k] = true
            m.rawAlbums.push({ md: md, tracks: invalid, loading: false, group: albumGroup(md) })
        end if
    end for
end sub

' albums first, then EPs and singles, each newest first; focus stays on keepId when given
sub arrange(keepId as string)
    full = []
    small = []
    for each al in m.rawAlbums
        if al.group = "Albums" then full.push(al) else small.push(al)
    end for
    m.albums = newestFirst(full)
    m.albums.append(newestFirst(small))
    n = m.albums.Count()
    bits = []
    if full.Count() = 1 then bits.push("1 album") else if full.Count() > 1 then bits.push(full.Count().toStr() + " albums")
    if small.Count() = 1 then bits.push("1 EP or single") else if small.Count() > 1 then bits.push(small.Count().toStr() + " EPs and singles")
    m.sub.text = bits.join("  ·  ")
    sel = 0
    for i = 0 to n - 1
        if pxStr(m.albums[i].md.ratingKey) = keepId then sel = i
    end for
    drawAlbums()
    if n > 0
        if m.zone = "songs" and sel = m.sel and m.albums.Count() > 0
            paint()
        else
            pickAlbum(sel)
        end if
    end if
    paint()
end sub

sub fetchTracks(i as integer)
    al = m.albums[i]
    if al.tracks <> invalid or al.loading then return
    al.loading = true
    pxApi("/library/metadata/" + pxStr(al.md.ratingKey) + "/children", {}, "onTracks", pxStr(al.md.ratingKey))
end sub

sub onTracks(event as object)
    t = hTaskFrom(event)
    for i = 0 to m.albums.Count() - 1
        al = m.albums[i]
        if pxStr(al.md.ratingKey) = t.tag
            al.loading = false
            al.tracks = pxItems(t)
            if i = m.sel then drawSongs()
            return
        end if
    end for
end sub

' ---------- left: the album list ----------
sub drawAlbums()
    m.albumList.removeChildrenIndex(m.albumList.getChildCount(), 0)
    m.albumRows = []
    for i = 0 to m.albums.Count() - 1
        md = m.albums[i].md
        g = m.albumList.createChild("Group")
        g.translation = [0, i * 120]
        hl = g.createChild("Poster")
        hl.uri = "pkg:/images/w/focus-ring" + hVar(i) + ".9.png"
        hl.translation = [-27, -27]
        hl.width = 574
        hl.height = 166
        hl.opacity = 0
        bg = g.createChild("Rectangle")
        bg.translation = [10, 10]
        bg.width = 92
        bg.height = 92
        bg.color = "0x1D2418FF"
        p = g.createChild("Poster")
        p.translation = [10, 10]
        p.width = 92
        p.height = 92
        p.loadDisplayMode = "scaleToZoom"
        p.uri = pxImage(md.thumb, 92, 92)
        title = g.createChild("Label")
        title.translation = [124, 22]
        title.width = 380
        title.maxLines = 1
        title.font = hFont("bold", 28)
        title.text = pxStr(md.title)
        s = g.createChild("Label")
        s.translation = [124, 62]
        s.width = 380
        s.font = hFont("regular", 22)
        s.text = albumKind(m.albums[i])
        m.albumRows.push(g)
    end for
end sub

function albumKind(al as object) as string
    md = al.md
    bits = []
    if md.year <> invalid then bits.push(md.year.toStr())
    if al.group = "Albums"
        bits.push("Album")
    else if md.leafCount <> invalid and md.leafCount <= 3
        bits.push("Single")
    else
        bits.push("EP")
    end if
    return bits.join("  ·  ")
end function

sub pickAlbum(i as integer)
    if i < 0 or i >= m.albums.Count() then return
    m.sel = i
    m.song = 0
    m.page = 0
    al = m.albums[i]
    md = al.md
    m.cover.uri = pxImage(md.thumb, 150, 150)
    m.aTitle.text = pxStr(md.title)
    bits = []
    if md.year <> invalid then bits.push(md.year.toStr())
    if md.leafCount <> invalid then bits.push(md.leafCount.toStr() + " songs")
    if md.duration <> invalid then bits.push(Int(md.duration / 60000 + 0.5).toStr() + " min")
    m.aSub.text = bits.join("  ·  ")
    fetchTracks(i)
    drawSongs()
end sub

' ---------- right: songs in two columns ----------
' Up to 14 songs per page: two columns that split the album evenly (12 songs = 6 + 6).
' Longer albums page on by 14, shown as "Songs 15 to 20 of 20".
function pageSize() as integer
    return 7 * 2
end function

function colRows(count as integer) as integer
    onPage = count - m.page * pageSize()
    if onPage > pageSize() then onPage = pageSize()
    r = Int((onPage + 1) / 2)
    if r < 1 then r = 1
    return r
end function

sub drawSongs(unused = invalid as dynamic)
    m.songs.removeChildrenIndex(m.songs.getChildCount(), 0)
    m.songNodes = []
    m.pageL.text = ""
    if m.albums.Count() = 0 then return
    al = m.albums[m.sel]
    if al.tracks = invalid
        addSongNote("Loading songs" + Chr(8230))
        m.divider.visible = false
        return
    end if
    n = al.tracks.Count()
    if n = 0
        addSongNote("No songs found.")
        m.divider.visible = false
        return
    end if
    cur = muPlayer().track
    curId = ""
    if cur <> invalid and cur.id <> invalid then curId = cur.id
    discs = 0
    for each tr in al.tracks
        if tr.parentIndex <> invalid and tr.parentIndex > discs then discs = tr.parentIndex
    end for
    first = m.page * pageSize()
    last = first + pageSize() - 1
    if last > n - 1 then last = n - 1
    rows = colRows(n)
    m.divider.visible = (last - first + 1) > rows
    m.divider.height = rows * 64
    for k = first to last
        j = k - first
        col = Int(j / rows)
        row = j - col * rows
        m.songNodes.push(addSong(col * 572, row * 64, k, al.tracks[k], curId, discs > 1))
    end for
    if n > pageSize()
        m.pageL.text = "Songs " + (first + 1).toStr() + " to " + (last + 1).toStr() + " of " + n.toStr()
    end if
    paint()
end sub

sub addSongNote(text as string)
    l = m.songs.createChild("Label")
    l.translation = [8, 12]
    l.font = hFont("regular", 28)
    l.color = "0xB5AF8CFF"
    l.text = text
end sub

function addSong(x as integer, y as integer, k as integer, md as object, curId as string, multiDisc as boolean) as object
    if x > 0 then x = x + 26
    g = m.songs.createChild("Group")
    g.translation = [x, y]
    hl = g.createChild("Rectangle")
    hl.width = 546
    hl.height = 64 - 6
    hl.color = "0xE0B34A00"
    playing = (pxStr(md.ratingKey) = curId)
    dot = g.createChild("Rectangle")
    dot.translation = [10, 23]
    dot.width = 12
    dot.height = 12
    dot.color = "0xE0B34AFF"
    dot.visible = playing
    num = g.createChild("Label")
    num.translation = [30, 0]
    num.width = 64
    num.height = 64 - 6
    num.vertAlign = "center"
    num.font = hFont("regular", 28)
    num.color = "0xB5AF8CFF"
    if md.index <> invalid then n = md.index.toStr() else n = (k + 1).toStr()
    if multiDisc and md.parentIndex <> invalid then n = md.parentIndex.toStr() + "." + n
    num.text = n
    title = g.createChild("Label")
    title.translation = [96, 0]
    title.width = 340
    title.height = 64 - 6
    title.vertAlign = "center"
    title.maxLines = 1
    title.font = hFont("regular", 30)
    if playing then title.color = "0xE0B34AFF" else title.color = "0xEDE6CAFF"
    title.text = pxStr(md.title)
    dur = g.createChild("Label")
    dur.translation = [436, 0]
    dur.width = 96
    dur.height = 64 - 6
    dur.vertAlign = "center"
    dur.horizAlign = "right"
    dur.font = hFont("regular", 28)
    dur.color = "0xB5AF8CFF"
    if md.duration <> invalid then dur.text = pxClock(md.duration / 1000)
    return g
end function

' ---------- focus ----------
sub paint()
    m.bar.active = (m.zone = "bar")
    for i = 0 to m.topBtns.nodes.Count() - 1
        m.topBtns.nodes[i].focused = (m.zone = "top" and i = m.topSel)
    end for
    for i = 0 to m.albBtns.nodes.Count() - 1
        m.albBtns.nodes[i].focused = (m.zone = "abtn" and i = m.abtnSel)
    end for
    for i = 0 to m.albumRows.Count() - 1
        g = m.albumRows[i]
        if i = m.sel and m.zone = "albums"
            g.getChild(0).opacity = 1
            fg = "0xEDE6CAFF"
            sub2 = "0xB5AF8CFF"
        else if i = m.sel
            g.getChild(0).opacity = 0.35
            fg = "0xEDE6CAFF"
            sub2 = "0xB5AF8CFF"
        else
            g.getChild(0).opacity = 0
            fg = "0xEDE6CAFF"
            sub2 = "0xB5AF8CFF"
        end if
        g.getChild(3).color = fg
        g.getChild(4).color = sub2
    end for
    ' keep the chosen album in view (5 rows fit above the player bar)
    scrollY = (m.sel - 2) * 120
    maxY = (m.albums.Count() - 5) * 120
    if scrollY > maxY then scrollY = maxY
    if scrollY < 0 then scrollY = 0
    m.albumList.translation = [96, 270 - scrollY]
    for j = 0 to m.songNodes.Count() - 1
        if m.zone = "songs" and j = m.song then c = "0xE0B34A2E" else c = "0xE0B34A00"
        m.songNodes[j].getChild(0).color = c
    end for
end sub

' ---------- actions ----------
sub playTrack(k as integer)
    al = m.albums[m.sel]
    muSend("load", { tracks: pxTracks(al.tracks), start: k, label: pxStr(al.md.title) })
end sub

sub playAlbum(i as integer, shuffle as boolean)
    md = m.albums[i].md
    muSend("playContainer", { kind: "album", id: pxStr(md.ratingKey), shuffle: shuffle, label: pxStr(md.title) })
end sub

sub doTop(a as string)
    if a = "lidarr"
        name = ""
        if m.artist <> invalid then name = pxStr(m.artist.title)
        m.top.request = { action: "musicView", mode: "request", term: name }
    else if m.artist <> invalid
        muSend("playContainer", { kind: "artist", id: m.top.artistId, shuffle: (a = "shuffle"), label: pxStr(m.artist.title) })
    end if
end sub

sub albumOptions(i as integer)
    m.optAlbum = i
    m.optTrack = -1
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = pxStr(m.albums[i].md.title)
    d.message = [pxStr(m.albums[i].md.parentTitle)]
    d.buttons = ["Play album", "Shuffle album", "Play next", "Add to queue", "Close"]
    d.observeField("buttonSelected", "onAlbumOption")
    d.observeField("wasClosed", "onShown")
    m.dialog = d
    m.top.getScene().dialog = d
end sub

sub trackOptions(i as integer, k as integer)
    m.optAlbum = i
    m.optTrack = k
    md = m.albums[i].tracks[k]
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = pxStr(md.title)
    d.message = [pxStr(m.albums[i].md.title)]
    d.buttons = ["Play from here", "Play next", "Add to queue", "More like this", "Close"]
    d.observeField("buttonSelected", "onAlbumOption")
    d.observeField("wasClosed", "onShown")
    m.dialog = d
    m.top.getScene().dialog = d
end sub

sub onAlbumOption()
    b = m.dialog.buttonSelected
    m.dialog.close = true
    al = m.albums[m.optAlbum]
    name = pxStr(al.md.title)
    if m.optTrack < 0
        if b < 2 then playAlbum(m.optAlbum, b = 1)
        if b = 2 or b = 3 then muSend("queueContainer", { kind: "album", id: pxStr(al.md.ratingKey), next: (b = 2), label: name })
    else
        md = al.tracks[m.optTrack]
        if b = 0 then playTrack(m.optTrack)
        if b = 1 or b = 2 then muSend("queueTracks", { tracks: [pxTrack(md)], next: (b = 1), label: pxStr(md.title) })
        if b = 3
            ' start this song, then ask Plex for songs that sound like it
            muSend("load", { tracks: [pxTrack(md)], start: 0, label: pxStr(md.title) })
            muSend("moreLikeThis")
        end if
    end if
end sub

sub muRestoreFocus()
    m.top.setFocus(true)
end sub

sub say(text as string)
    m.toast.text = text
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub hideToast()
    m.toast.text = ""
end sub

sub onBarRequest()
    r = m.bar.request
    if r = invalid then return
    if r.action = "refocus" then m.top.setFocus(true) else m.top.request = r
end sub

sub toBar()
    m.aboveBar = m.zone
    m.zone = "bar"
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
    if m.zone = "bar" and key <> "back"
        if m.bar.callFunc("handleKey", key) = "up" then m.zone = m.aboveBar
        paint()
        return true
    end if
    if key = "back"
        if m.zone = "songs" or m.zone = "abtn" or m.zone = "bar"
            m.zone = "albums"
            paint()
            return true
        end if
        muPlayer().unobserveFieldScoped("track")
        m.top.request = { action: "back" }
        return true
    end if
    n = m.albums.Count()
    if m.zone = "top"
        if key = "left" and m.topSel > 0 then m.topSel = m.topSel - 1
        if key = "right" and m.topSel < m.topBtns.nodes.Count() - 1 then m.topSel = m.topSel + 1
        if key = "down"
            if n > 0 then m.zone = "albums" else toBar()
        end if
        if key = "OK" then doTop(m.topBtns.actions[m.topSel])
    else if m.zone = "albums"
        if key = "up"
            if m.sel = 0 then m.zone = "top" else pickAlbum(m.sel - 1)
        else if key = "down"
            if m.sel < n - 1 then pickAlbum(m.sel + 1) else toBar()
        else if key = "right" or key = "OK"
            if m.songNodes.Count() > 0
                m.zone = "songs"
                m.song = 0
            else
                m.zone = "abtn"
            end if
        else if key = "options"
            albumOptions(m.sel)
        end if
    else if m.zone = "abtn"
        if key = "left"
            if m.abtnSel > 0 then m.abtnSel = m.abtnSel - 1 else m.zone = "albums"
        else if key = "right"
            if m.abtnSel < m.albBtns.nodes.Count() - 1 then m.abtnSel = m.abtnSel + 1
        else if key = "up"
            m.zone = "top"
        else if key = "down"
            if m.songNodes.Count() > 0 then m.zone = "songs" else toBar()
        else if key = "OK"
            playAlbum(m.sel, m.albBtns.actions[m.abtnSel] = "shuffleAlbum")
        end if
    else if m.zone = "songs"
        songKey(key)
    end if
    paint()
    return true
end function

' Songs: Up/Down within a column (Down at the bottom of the left column carries on at the top of the right one),
' Left/Right across columns, Left from the left column goes back to the albums.
sub songKey(key as string)
    al = m.albums[m.sel]
    total = al.tracks.Count()
    count = m.songNodes.Count()
    rows = colRows(total)
    col = Int(m.song / rows)
    row = m.song - col * rows
    if key = "up"
        if row > 0
            m.song = m.song - 1
        else if col = 1
            m.song = rows - 1
        else if m.page > 0
            m.page = m.page - 1
            drawSongs()
            m.song = m.songNodes.Count() - 1
        else
            m.zone = "abtn"
        end if
    else if key = "down"
        if m.song < count - 1
            m.song = m.song + 1
        else if (m.page + 1) * pageSize() < total
            m.page = m.page + 1
            m.song = 0
            drawSongs()
        else
            toBar()
        end if
    else if key = "left"
        if col = 1 then m.song = row else m.zone = "albums"
    else if key = "right"
        if col = 0 and m.song + rows < count
            m.song = m.song + rows
        else if col = 0 and rows < count
            m.song = count - 1
        end if
    else if key = "OK"
        playTrack(m.page * pageSize() + m.song)
    else if key = "options"
        trackOptions(m.sel, m.page * pageSize() + m.song)
    end if
end sub

' Plex tags some albums with a format (EP, Single...). Without one, six songs or fewer counts as an EP or single.
function albumGroup(md as object) as string
    for each field in ["Format", "Subformat"]
        tags = md[field]
        if tags <> invalid
            for each tg in tags
                t = LCase(pxStr(tg.tag))
                if Instr(1, t, "single") > 0 or Instr(1, t, "ep") = 1 then return "EPs and singles"
                if Instr(1, t, "album") > 0 then return "Albums"
            end for
        end if
    end for
    if md.leafCount <> invalid and md.leafCount <= 6 then return "EPs and singles"
    return "Albums"
end function

function newestFirst(list as object) as object
    out = []
    for each al in list
        y = 0
        if al.md.year <> invalid then y = al.md.year
        ' insertion sort: lists are short
        k = 0
        while k < out.Count() and out[k].y >= y
            k = k + 1
        end while
        al.y = y
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
    return out
end function

