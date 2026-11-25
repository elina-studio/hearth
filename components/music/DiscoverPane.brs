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
    m.pvTimer = m.top.findNode("pvTimer")
    m.pvTimer.observeField("fire", "loadAlbums")
    m.chipNodes = []
    for each t in [["Artists you love", "star"], ["Recommended", "wave"]]
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
    if m.loaded then return
    m.loaded = true
    m.note.text = "Asking the NAS" + Chr(8230)
    nasCall("GET", "/api/discover", "", "onData", "discover")
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

sub redraw()
    m.recsF = invalid
    m.list.removeChildrenIndex(m.list.getChildCount(), 0)
    items = invalid
    if m.data <> invalid then items = names()
    if items = invalid or items.Count() = 0
        m.detail.visible = false
        if m.data = invalid then return
        if m.data.building = true or (m.data.built = 0 and m.data.user = "")
            m.note.text = "The NAS is still working out your lists from Last.fm. Come back in a few minutes."
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
    for i = 0 to 1
        c = m.chipNodes[i]
        c.on = ((i = 0 and m.mode = "loved") or (i = 1 and m.mode = "recs"))
        c.focused = (m.top.active and m.zone = "chips" and ((i = 0 and m.mode = "loved") or (i = 1 and m.mode = "recs")))
    end for
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
    if m.data = invalid
        if key = "up" then return "up"
        if key = "left" then return "left"
        return ""
    end if
    if m.zone = "chips"
        if key = "up" then return "up"
        if key = "left"
            if m.mode = "recs" then switchMode("loved") else return "left"
        else if key = "right"
            switchMode("recs")
        else if key = "down" or key = "OK"
            if names().Count() > 0 then m.zone = "list"
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

sub switchMode(mode as string)
    if mode = m.mode then return
    m.mode = mode
    m.sel = 0
    m.top0 = 0
    redraw()
end sub

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
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub hideToast()
    m.toast.text = ""
end sub
