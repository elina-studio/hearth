' Photos room ("The Window"). Left: the big "Start the slideshow" card (every photo).
' Right: albums, one per subfolder of the photos folder.
sub init()
    m.heroArt = m.top.findNode("heroArt")
    m.heroRing = m.top.findNode("heroRing")
    m.heroEyebrow = m.top.findNode("heroEyebrow")
    m.heroEyebrow.font = hFont("caps", 28)
    m.heroTitle = m.top.findNode("heroTitle")
    m.heroTitle.font = hFont("caps", 84)
    m.heroSub = m.top.findNode("heroSub")
    m.heroSub.font = hFont("regular", 28)
    m.top.findNode("albumsLabel").font = hFont("caps", 28)
    m.albumGroup = m.top.findNode("albums")
    m.note = m.top.findNode("note")
    m.note.font = hFont("regular", 28)
    m.scroll = m.top.findNode("scroll")
    m.scrollTo = m.top.findNode("scrollTo")

    m.albums = []
    m.col = 0
    m.sel = 0
    m.focused = false
    m.loadedFor = ""
    m.loadedAt = 0
    m.clock = CreateObject("roTimespan")
    refresh(invalid)
end sub

' Called when the room is shown and when the library list arrives. Reloads every 10 minutes.
sub refresh(unused as dynamic)
    lib = pLibrary()
    if lib = ""
        m.loadedFor = ""
        showSetup()
        return
    end if
    if lib = m.loadedFor and m.clock.TotalSeconds() - m.loadedAt < 600 then return
    m.loadedFor = lib
    m.loadedAt = m.clock.TotalSeconds()
    m.heroEyebrow.text = "THE WINDOW · ALL YOUR PHOTOS"
    m.heroTitle.text = "START THE SLIDESHOW"
    m.heroSub.text = "Shuffles every photo in the folder, with the time and weather"
    m.note.text = "Looking for your albums…"
    pPhotos("albums", { section: lib }, "onAlbums")
    pPhotos("random", { section: lib, limit: 1 }, "onHeroPhoto")
end sub

sub showSetup()
    m.heroArt.uri = ""
    m.heroEyebrow.text = "THE WINDOW"
    m.heroTitle.text = "NO PHOTOS YET"
    m.heroSub.text = "Add your photos folder to Plex as a Photos library"
    m.albums = []
    m.albumGroup.removeChildrenIndex(m.albumGroup.getChildCount(), 0)
    m.note.text = "Once Plex has scanned it, come back to this room."
    m.col = 0
    paint()
end sub

sub onAlbums(event as object)
    t = pTaskFrom(event)
    if not t.ok
        m.note.text = "Can't reach Plex (" + t.status.toStr() + "). Press OK to try again."
        m.loadedFor = ""
        return
    end if
    list = t.response.Items
    if list = invalid then list = []
    m.albums = []
    m.albumGroup.removeChildrenIndex(m.albumGroup.getChildCount(), 0)
    for each a in list
        i = m.albums.count()
        m.albums.push(a)
        tile = m.albumGroup.createChild("PhotoTile")
        tile.translation = [0, i * 146]
        tile.title = a.Name
        n = a.count
        if n = invalid then tile.sub = "Album" else if n = 1 then tile.sub = "1 photo" else tile.sub = n.toStr() + " photos"
        tile.image = pPhotoUrl(a, 260, 260)
    end for
    if m.albums.count() = 0 then m.note.text = "No albums yet. Subfolders of your photos folder show up here." else m.note.text = ""
    if m.sel >= m.albums.count() then m.sel = 0
    if m.col = 1 and m.albums.count() = 0 then m.col = 0
    paint()
end sub

sub onHeroPhoto(event as object)
    t = pTaskFrom(event)
    if not t.ok
        m.note.text = "Can't reach Plex (" + t.status.toStr() + "). Press OK to try again."
        m.loadedFor = ""
        return
    end if
    items = t.response.Items
    if items = invalid or items.count() = 0
        m.heroSub.text = "The photos library is empty so far. Plex may still be scanning."
        return
    end if
    m.heroArt.uri = pPhotoUrl(items[0], 1180, 620)
end sub

' ---------- focus ----------
sub focusIn(unused as dynamic)
    m.focused = true
    m.top.setFocus(true)
    paint()
end sub

sub paint()
    m.heroRing.visible = (m.focused and m.col = 0)
    for i = 0 to m.albumGroup.getChildCount() - 1
        m.albumGroup.getChild(i).focused = (m.focused and m.col = 1 and i = m.sel)
    end for
    ' keep the focused album inside the four visible slots
    y = 10
    if m.sel > 3 then y = 10 - (m.sel - 3) * 146
    m.scroll.control = "stop"
    m.scrollTo.keyValue = [m.albumGroup.translation, [10, y]]
    m.scroll.control = "start"
end sub

sub toPills()
    m.focused = false
    paint()
    m.top.request = { action: "pills" }
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    n = m.albums.count()
    if key = "back"
        toPills()
    else if key = "up"
        if m.col = 1 and m.sel > 0
            m.sel = m.sel - 1
            paint()
        else
            toPills()
        end if
    else if key = "down"
        if m.col = 1 and m.sel < n - 1
            m.sel = m.sel + 1
            paint()
        end if
    else if key = "right"
        if m.col = 0 and n > 0
            m.col = 1
            paint()
        end if
    else if key = "left"
        if m.col = 1
            m.col = 0
            paint()
        end if
    else if key = "OK"
        if pLibrary() = "" or m.loadedFor = ""
            m.loadedFor = ""
            refresh(invalid)
        else if m.col = 0
            m.top.request = { action: "slideshow", albumId: "", albumName: "" }
        else if m.sel < n
            a = m.albums[m.sel]
            m.top.request = { action: "slideshow", albumId: a.Id, albumName: a.Name }
        end if
    else
        return false
    end if
    return true
end function
