' Photos room, layout C ("The window"). A live photo fills the room and changes every
' 12 seconds. Three buttons: Start the slideshow, On this day, Favourites. Albums on a rail.
' Focus: buttons row, then Down to the albums rail. Up from the buttons goes to the pills.
sub init()
    m.win = [m.top.findNode("winA"), m.top.findNode("winB")]
    m.winFront = 1
    m.winFade = m.top.findNode("winFade")
    m.winIn = m.top.findNode("winIn")
    m.winOut = m.top.findNode("winOut")
    m.winTimer = m.top.findNode("winTimer")
    m.winTimer.observeField("fire", "nextWindow")
    for each p in m.win
        p.observeField("loadStatus", "onWindowLoaded")
    end for
    m.eyebrow = m.top.findNode("eyebrow")
    m.eyebrow.font = hFont("caps", 30)
    m.eyeIcon = m.top.findNode("eyeIcon")
    m.title = m.top.findNode("title")
    m.title.font = hFont("caps", 96)
    m.buttonsGroup = m.top.findNode("buttons")
    m.albumsLabel = m.top.findNode("albumsLabel")
    m.albumsLabel.font = hFont("caps", 28)
    m.albumGroup = m.top.findNode("albums")
    m.note = m.top.findNode("note")
    m.note.font = hFont("regular", 28)
    m.scroll = m.top.findNode("scroll")
    m.scrollTo = m.top.findNode("scrollTo")

    m.buttons = []
    m.albums = []
    m.windowPhotos = []
    m.winPos = -1
    m.zone = "buttons"
    m.btn = 0
    m.sel = 0
    m.focused = false
    m.loadedFor = ""
    m.loadedAt = 0
    m.clock = CreateObject("roTimespan")
    m.summary = { total: 0, favourites: 0, onThisDay: 0 }
    buildButtons()
    refresh(invalid)
end sub

' Called when the room is shown and when the library list arrives. Reloads every 10 minutes.
sub refresh(unused as dynamic)
    lib = pLibrary()
    if lib = ""
        m.loadedFor = ""
        showEmpty()
        return
    end if
    m.winTimer.control = "start"
    if lib = m.loadedFor and m.clock.TotalSeconds() - m.loadedAt < 600 then return
    m.loadedFor = lib
    ' the screensaver runs outside the app and needs to know which library holds the photos
    if pPref("photoSection", "") <> lib then pSetPref("photoSection", lib)
    m.loadedAt = m.clock.TotalSeconds()
    m.note.text = ""
    m.eyebrow.text = "THE WINDOW"
    if m.title.text = "" then m.title.text = "YOUR PHOTOS"
    pPhotos("albums", { section: lib }, "onAlbums")
    pPhotos("summary", { section: lib }, "onSummary")
    pPhotos("random", { section: lib, limit: 30 }, "onWindowPhotos")
end sub

' Nothing to show yet: say exactly what to do
sub showEmpty()
    m.winTimer.control = "stop"
    m.eyebrow.text = "THE WINDOW"
    m.title.text = "NO PHOTOS YET"
    m.albums = []
    m.albumGroup.removeChildrenIndex(m.albumGroup.getChildCount(), 0)
    m.albumsLabel.visible = false
    m.note.text = "Add your photos folder to Plex as a Photos library. Each folder inside it becomes an album here. Then press OK to check again."
    m.buttons = []
    m.buttonsGroup.removeChildrenIndex(m.buttonsGroup.getChildCount(), 0)
    m.zone = "buttons"
    paint()
end sub

' ---------- buttons ----------
sub buildButtons()
    m.buttonsGroup.removeChildrenIndex(m.buttonsGroup.getChildCount(), 0)
    m.buttons = []
    specs = [{ id: "", icon: "play", text: "Start the slideshow" }]
    if m.summary.onThisDay > 0 then specs.push({ id: "@onthisday", icon: "calendar", text: "On this day" })
    if m.summary.favourites > 0 then specs.push({ id: "@favourites", icon: "star", text: "Favourites · " + m.summary.favourites.toStr() })
    x = 0
    for each sp in specs
        b = m.buttonsGroup.createChild("PhotoButton")
        b.iconName = sp.icon
        b.text = sp.text
        b.translation = [x, 0]
        x = x + b.buttonWidth + 18
        m.buttons.push(sp)
    end for
    if m.btn >= m.buttons.count() then m.btn = 0
    paint()
end sub

sub onSummary(event as object)
    t = pTaskFrom(event)
    if not t.ok then return
    r = t.response
    m.summary = { total: r.total, favourites: r.favourites, onThisDay: r.onThisDay }
    if r.total <> invalid and r.total > 0 then m.eyebrow.text = "THE WINDOW · " + hThousands(r.total) + " PHOTOS"
    buildButtons()
end sub

function hThousands(n as integer) as string
    s = n.toStr()
    out = ""
    while Len(s) > 3
        out = "," + Right(s, 3) + out
        s = Left(s, Len(s) - 3)
    end while
    return s + out
end function

' ---------- the window ----------
sub onWindowPhotos(event as object)
    t = pTaskFrom(event)
    if not t.ok
        m.note.text = "Can't reach Plex (" + t.status.toStr() + "). Press OK to try again."
        m.loadedFor = ""
        return
    end if
    all = t.response.Items
    if all = invalid then all = []
    ' the window is wide: landscape photos fill it without cutting off heads
    m.windowPhotos = []
    for each it in all
        if it.w = invalid or it.h = invalid or it.w >= it.h then m.windowPhotos.push(it)
    end for
    if m.windowPhotos.count() = 0 then m.windowPhotos = all
    if m.windowPhotos.count() = 0
        showEmpty()
        return
    end if
    m.winPos = -1
    nextWindow()
end sub

sub nextWindow()
    if m.windowPhotos.count() = 0 then return
    ' only while the room is on screen
    if m.top.getParent() = invalid then return
    m.winPos = (m.winPos + 1) mod m.windowPhotos.count()
    m.winPending = m.windowPhotos[m.winPos]
    m.win[1 - m.winFront].uri = pPhotoUrl(m.winPending, 1280, 720, true)
end sub

sub onWindowLoaded(event as object)
    if event.getData() <> "ready" then return
    incoming = m.win[1 - m.winFront]
    if not event.getRoSGNode().isSameNode(incoming) then return
    outgoing = m.win[m.winFront]
    m.winFade.control = "stop"
    m.winIn.fieldToInterp = incoming.id + ".opacity"
    m.winOut.fieldToInterp = outgoing.id + ".opacity"
    m.winOut.keyValue = [outgoing.opacity, 0.0]
    m.winFade.control = "start"
    m.winFront = 1 - m.winFront
    cap = pPhotoCaption(m.winPending)
    if cap <> "" then m.title.text = UCase(cap) else m.title.text = "YOUR PHOTOS"
end sub

' ---------- albums ----------
sub onAlbums(event as object)
    t = pTaskFrom(event)
    if not t.ok then return
    list = t.response.Items
    if list = invalid then list = []
    m.albums = []
    m.albumGroup.removeChildrenIndex(m.albumGroup.getChildCount(), 0)
    for each a in list
        i = m.albums.count()
        m.albums.push(a)
        tile = m.albumGroup.createChild("PhotoTile")
        tile.translation = [i * 296, 0]
        tile.title = a.Name
        n = a.count
        if n = invalid then tile.sub = "Album" else if n = 1 then tile.sub = "1 photo" else tile.sub = hThousands(n) + " photos"
        ' covers load only for the first screenful; the rest as you scroll to them
        if i < 8 then tile.image = pPhotoUrl(a, 272, 172, true)
    end for
    m.albumsLabel.visible = m.albums.count() > 0
    if m.sel >= m.albums.count() then m.sel = 0
    if m.zone = "albums" and m.albums.count() = 0 then m.zone = "buttons"
    paint()
end sub

' ---------- focus ----------
sub focusIn(unused as dynamic)
    m.focused = true
    m.top.setFocus(true)
    paint()
end sub

sub paint()
    for i = 0 to m.buttonsGroup.getChildCount() - 1
        m.buttonsGroup.getChild(i).focused = (m.focused and m.zone = "buttons" and i = m.btn)
    end for
    n = m.albumGroup.getChildCount()
    for i = 0 to n - 1
        m.albumGroup.getChild(i).focused = (m.focused and m.zone = "albums" and i = m.sel)
    end for
    ' six tiles show at once; scroll so the focused one stays in view, and load covers ahead
    first = 0
    if m.sel > 4 then first = m.sel - 4
    for i = first to first + 7
        if i < n and i < m.albums.count()
            tile = m.albumGroup.getChild(i)
            if tile.image = "" then tile.image = pPhotoUrl(m.albums[i], 272, 172, true)
        end if
    end for
    m.scroll.control = "stop"
    m.scrollTo.keyValue = [m.albumGroup.translation, [10 - first * 296, 10]]
    m.scroll.control = "start"
end sub

sub toPills()
    m.focused = false
    paint()
    m.top.request = { action: "pills" }
end sub

sub openSelected()
    if m.zone = "buttons"
        if m.buttons.count() = 0 then return
        b = m.buttons[m.btn]
        name = ""
        if b.id = "@onthisday" then name = "On this day"
        if b.id = "@favourites" then name = "Favourites"
        m.top.request = { action: "slideshow", albumId: b.id, albumName: name }
    else if m.sel < m.albums.count()
        a = m.albums[m.sel]
        m.top.request = { action: "slideshow", albumId: a.Id, albumName: a.Name }
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
    if key = "back"
        toPills()
    else if key = "up"
        if m.zone = "albums"
            m.zone = "buttons"
            paint()
        else
            toPills()
        end if
    else if key = "down"
        if m.zone = "buttons" and m.albums.count() > 0
            m.zone = "albums"
            paint()
        end if
    else if key = "left"
        if m.zone = "buttons" and m.btn > 0 then m.btn = m.btn - 1
        if m.zone = "albums" and m.sel > 0 then m.sel = m.sel - 1
        paint()
    else if key = "right"
        if m.zone = "buttons" and m.btn < m.buttons.count() - 1 then m.btn = m.btn + 1
        if m.zone = "albums" and m.sel < m.albums.count() - 1 then m.sel = m.sel + 1
        paint()
    else if key = "OK"
        if pLibrary() = "" or m.loadedFor = ""
            m.loadedFor = ""
            refresh(invalid)
        else
            openSelected()
        end if
    else
        return false
    end if
    return true
end function
