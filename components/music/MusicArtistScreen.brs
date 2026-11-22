sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.art = m.top.findNode("art")
    m.top.findNode("eyebrow").font = hFont("caps", 28)
    m.name = m.top.findNode("name")
    m.name.font = hFont("caps", 84)
    m.sub = m.top.findNode("sub")
    m.sub.font = hFont("regular", 30)
    m.list = m.top.findNode("list")
    m.toast = m.top.findNode("toast")
    m.toast.font = hFont("bold", 26)
    m.toastTimer = m.top.findNode("toastTimer")
    m.toastTimer.observeField("fire", "hideToast")
    m.buttons = m.top.findNode("buttons")
    m.btnDefs = [["Play all", "play"], ["Shuffle", "shuffle"], ["Show all songs", "toggleAll"]]
    for each b in m.btnDefs
        p = m.buttons.createChild("HearthPill")
        p.button = true
        p.width = Len(b[0]) * 14 + 56
        p.text = b[0]
    end for
    m.zone = "list"
    m.btn = 0
    m.sel = 0
    m.albums = []
    m.rows = []
    muPlayer().observeFieldScoped("track", "drawList")
end sub

sub onShown(unused as dynamic)
    m.top.setFocus(true)
end sub

' ---------- loading ----------
sub load(unused = invalid as dynamic)
    id = m.top.artistId
    if id = "" then return
    m.name.text = "Loading" + Chr(8230)
    pxApi("/library/metadata/" + id, {}, "onArtist")
    pxApi("/library/metadata/" + id + "/children", {}, "onAlbums")
end sub

sub onArtist(event as object)
    t = hTaskFrom(event)
    items = pxItems(t)
    if items.Count() = 0 then return
    a = items[0]
    m.artist = a
    m.name.text = UCase(pxStr(a.title))
    m.art.uri = pxImage(a.thumb, 240, 240)
    if a.art <> invalid then m.backdrop.uri = pxImage(a.art, 640, 360, 30)
end sub

sub onAlbums(event as object)
    t = hTaskFrom(event)
    m.albums = []
    for each md in pxItems(t)
        if md.type = "album"
            open = (pxStr(md.ratingKey) = m.top.openAlbumId)
            m.albums.push({ md: md, tracks: invalid, open: open, loading: false })
        end if
    end for
    n = m.albums.Count()
    if n = 1 then m.sub.text = "1 album" else m.sub.text = n.toStr() + " albums"
    if n = 0
        if t.status <= 0 then say("Can't reach Plex.") else say("No albums for this artist.")
    end if
    ' open the album we came in from, and put focus on it
    for i = 0 to n - 1
        if m.albums[i].open
            fetchTracks(i)
            m.focusAlbum = i
        end if
    end for
    drawList()
    if m.focusAlbum <> invalid
        for r = 0 to m.rows.Count() - 1
            if m.rows[r].kind = "album" and m.rows[r].a = m.focusAlbum then m.sel = r
        end for
        paint()
    end if
end sub

sub fetchTracks(i as integer)
    al = m.albums[i]
    if al.tracks <> invalid or al.loading then return
    al.loading = true
    pxApi("/library/metadata/" + pxStr(al.md.ratingKey) + "/children", {}, "onTracks", i.toStr())
end sub

sub onTracks(event as object)
    t = hTaskFrom(event)
    i = t.tag.toInt()
    if i >= m.albums.Count() then return
    al = m.albums[i]
    al.loading = false
    al.tracks = pxItems(t)
    if al.open then drawList()
end sub

' ---------- the accordion ----------
' Flattened rows: { kind: "album" | "track" | "note", a: album index, t: track index }
sub drawList()
    m.list.removeChildrenIndex(m.list.getChildCount(), 0)
    m.rows = []
    cur = muPlayer().track
    curId = ""
    if cur <> invalid and cur.id <> invalid then curId = cur.id
    y = 0
    for i = 0 to m.albums.Count() - 1
        al = m.albums[i]
        md = al.md
        g = m.list.createChild("Group")
        g.translation = [0, y]
        hl = g.createChild("Rectangle")
        hl.width = 1728
        hl.height = 128
        hl.color = "0xE0B34A00"
        bg = g.createChild("Rectangle")
        bg.translation = [8, 8]
        bg.width = 112
        bg.height = 112
        bg.color = "0x1D2418FF"
        p = g.createChild("Poster")
        p.translation = [8, 8]
        p.width = 112
        p.height = 112
        p.loadDisplayMode = "scaleToZoom"
        p.uri = pxImage(md.thumb, 112, 112)
        title = g.createChild("Label")
        title.translation = [144, 22]
        title.width = 1200
        title.maxLines = 1
        title.font = hFont("bold", 36)
        title.color = "0xEDE6CAFF"
        title.text = pxStr(md.title)
        sub2 = g.createChild("Label")
        sub2.translation = [144, 72]
        sub2.width = 1200
        sub2.font = hFont("regular", 26)
        sub2.color = "0xB5AF8CFF"
        bits = []
        if md.year <> invalid then bits.push(md.year.toStr())
        if md.leafCount <> invalid then bits.push(md.leafCount.toStr() + " songs")
        sub2.text = bits.join("  ·  ")
        state = g.createChild("Label")
        state.translation = [1380, 44]
        state.width = 330
        state.horizAlign = "right"
        state.font = hFont("bold", 26)
        state.color = "0xD9A066FF"
        if al.open then state.text = "Hide songs" else state.text = "Show songs"
        m.rows.push({ kind: "album", a: i, node: g, h: 128 })
        y = y + 136
        if al.open
            if al.tracks = invalid
                y = y + addNote(y, i, "Loading songs" + Chr(8230))
            else if al.tracks.Count() = 0
                y = y + addNote(y, i, "No songs found.")
            else
                ' disc headings when the album has more than one disc
                discs = 0
                for each tr in al.tracks
                    if tr.parentIndex <> invalid and tr.parentIndex > discs then discs = tr.parentIndex
                end for
                disc = -1
                for k = 0 to al.tracks.Count() - 1
                    tr = al.tracks[k]
                    if discs > 1 and tr.parentIndex <> invalid and tr.parentIndex <> disc
                        disc = tr.parentIndex
                        y = y + addNote(y, i, "Disc " + disc.toStr())
                    end if
                    y = y + addTrack(y, i, k, tr, curId)
                end for
                y = y + 12
            end if
        end if
    end for
    m.listHeight = y
    if m.sel >= m.rows.Count() then m.sel = m.rows.Count() - 1
    if m.sel < 0 then m.sel = 0
    paint()
end sub

function addNote(y as integer, i as integer, text as string) as integer
    g = m.list.createChild("Group")
    g.translation = [0, y]
    hl = g.createChild("Rectangle")
    hl.width = 1728
    hl.height = 56
    hl.color = "0xE0B34A00"
    l = g.createChild("Label")
    l.translation = [144, 12]
    l.font = hFont("regular", 28)
    l.color = "0xB5AF8CFF"
    l.text = text
    m.rows.push({ kind: "note", a: i, node: g, h: 56 })
    return 60
end function

function addTrack(y as integer, i as integer, k as integer, md as object, curId as string) as integer
    g = m.list.createChild("Group")
    g.translation = [0, y]
    hl = g.createChild("Rectangle")
    hl.width = 1728
    hl.height = 56
    hl.color = "0xE0B34A00"
    playing = (pxStr(md.ratingKey) = curId)
    num = g.createChild("Label")
    num.translation = [144, 12]
    num.width = 60
    num.font = hFont("regular", 28)
    num.color = "0xB5AF8CFF"
    if md.index <> invalid then num.text = md.index.toStr() else num.text = (k + 1).toStr()
    title = g.createChild("Label")
    title.translation = [214, 12]
    title.width = 1260
    title.maxLines = 1
    title.font = hFont("regular", 30)
    if playing then title.color = "0xE0B34AFF" else title.color = "0xEDE6CAFF"
    title.text = pxStr(md.title)
    if playing then title.text = title.text + "   (playing)"
    dur = g.createChild("Label")
    dur.translation = [1500, 12]
    dur.width = 210
    dur.horizAlign = "right"
    dur.font = hFont("regular", 28)
    dur.color = "0xB5AF8CFF"
    if md.duration <> invalid then dur.text = pxClock(md.duration / 1000)
    m.rows.push({ kind: "track", a: i, t: k, node: g, h: 56 })
    return 60
end function

sub paint()
    for i = 0 to m.buttons.getChildCount() - 1
        m.buttons.getChild(i).focused = (m.zone = "buttons" and i = m.btn)
    end for
    anyOpen = false
    for each al in m.albums
        if al.open then anyOpen = true
    end for
    if anyOpen then label = "Hide all songs" else label = "Show all songs"
    b = m.buttons.getChild(2)
    b.width = Len(label) * 14 + 56
    b.text = label
    for r = 0 to m.rows.Count() - 1
        row = m.rows[r]
        if m.zone = "list" and r = m.sel then c = "0xE0B34A2E" else c = "0xE0B34A00"
        row.node.getChild(0).color = c
    end for
    ' keep the focused row about a third of the way down the list area
    if m.rows.Count() > 0 and m.sel < m.rows.Count()
        fy = m.rows[m.sel].node.translation[1]
        top = fy - 220
        maxTop = m.listHeight - 700
        if top > maxTop then top = maxTop
        if top < 0 then top = 0
        m.list.translation = [96, 350 - top]
    end if
end sub

' ---------- actions ----------
sub toggle(i as integer)
    al = m.albums[i]
    al.open = not al.open
    if al.open then fetchTracks(i)
    drawList()
    ' stay on the album header
    for r = 0 to m.rows.Count() - 1
        if m.rows[r].kind = "album" and m.rows[r].a = i then m.sel = r
    end for
    paint()
end sub

sub toggleAll()
    anyOpen = false
    for each al in m.albums
        if al.open then anyOpen = true
    end for
    for i = 0 to m.albums.Count() - 1
        m.albums[i].open = not anyOpen
        if not anyOpen then fetchTracks(i)
    end for
    m.sel = 0
    drawList()
end sub

sub playTrack(i as integer, k as integer)
    al = m.albums[i]
    muSend("load", { tracks: pxTracks(al.tracks), start: k, label: pxStr(al.md.title) })
end sub

sub playAlbum(i as integer, shuffle as boolean)
    md = m.albums[i].md
    muSend("playContainer", { kind: "album", id: pxStr(md.ratingKey), shuffle: shuffle, label: pxStr(md.title) })
end sub

sub button(a as string)
    if a = "toggleAll"
        toggleAll()
    else if m.artist <> invalid
        muSend("playContainer", { kind: "artist", id: m.top.artistId, shuffle: (a = "shuffle"), label: pxStr(m.artist.title) })
    end if
end sub

sub albumOptions(i as integer)
    m.optAlbum = i
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = pxStr(m.albums[i].md.title)
    d.message = [pxStr(m.albums[i].md.parentTitle)]
    d.buttons = ["Play album", "Shuffle album", "Close"]
    d.observeField("buttonSelected", "onAlbumOption")
    d.observeField("wasClosed", "onShown")
    m.dialog = d
    m.top.getScene().dialog = d
end sub

sub onAlbumOption()
    b = m.dialog.buttonSelected
    m.dialog.close = true
    if b < 2 then playAlbum(m.optAlbum, b = 1)
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

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
    if key = "back"
        muPlayer().unobserveFieldScoped("track")
        m.top.request = { action: "back" }
        return true
    end if
    if m.zone = "buttons"
        if key = "left" and m.btn > 0 then m.btn = m.btn - 1
        if key = "right" and m.btn < m.btnDefs.Count() - 1 then m.btn = m.btn + 1
        if key = "down" and m.rows.Count() > 0 then m.zone = "list"
        if key = "OK" then button(m.btnDefs[m.btn][1])
        paint()
        return true
    end if
    if m.rows.Count() = 0
        if key = "up" then m.zone = "buttons"
        paint()
        return true
    end if
    row = m.rows[m.sel]
    if key = "up"
        if m.sel = 0 then m.zone = "buttons" else m.sel = m.sel - 1
    else if key = "down"
        if m.sel < m.rows.Count() - 1 then m.sel = m.sel + 1
    else if key = "left" or key = "right"
        ' jump between album headers
        if key = "left" then d = -1 else d = 1
        r = m.sel + d
        while r >= 0 and r < m.rows.Count() and m.rows[r].kind <> "album"
            r = r + d
        end while
        if r >= 0 and r < m.rows.Count() then m.sel = r
    else if key = "OK"
        if row.kind = "album" then toggle(row.a)
        if row.kind = "track" then playTrack(row.a, row.t)
    else if key = "options"
        albumOptions(row.a)
    end if
    paint()
    return true
end function
