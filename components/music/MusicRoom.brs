sub init()
    m.content = m.top.findNode("content")
    m.art = m.top.findNode("art")
    m.eyebrow = m.top.findNode("eyebrow")
    m.eyebrow.font = hFont("caps", 30)
    m.title = m.top.findNode("title")
    m.title.font = hFont("bold", 64)
    m.sub = m.top.findNode("sub")
    m.sub.font = hFont("regular", 32)
    m.fill = m.top.findNode("fill")
    m.time = m.top.findNode("time")
    m.time.font = hFont("regular", 24)
    m.chips = m.top.findNode("chips")
    m.shelves = m.top.findNode("shelves")
    m.empty = m.top.findNode("empty")
    m.empty.font = hFont("regular", 30)
    m.toast = m.top.findNode("toast")
    m.toast.font = hFont("bold", 28)
    m.toastTimer = m.top.findNode("toastTimer")
    m.toastTimer.observeField("fire", "hideToast")
    m.scroll = m.top.findNode("scroll")
    m.buildTimer = m.top.findNode("buildTimer")
    m.buildTimer.observeField("fire", "onBuildTimer")
    m.scrollTo = m.top.findNode("scrollTo")

    ' chips: [icon, word, action]. Transport is icon-only (its name shows under the row when focused),
    ' then a divider, then the views with a word each. Shuffle and Repeat light up gold when on.
    m.chipDefs = [["prev", "", "prev"], ["play", "", "toggle"], ["next", "", "next"], ["shuffle", "", "shuffle"], ["repeat", "", "repeat"], ["", "", "sep"], ["cover", "Cover", "cover"], ["viz", "Visualizer", "milk"], ["fire", "Fire", "hearth"], ["request", "Request", "request"]]
    m.chipNames = { prev: "Previous", toggle: "Play", next: "Next", shuffle: "Shuffle", repeat: "Repeat" }
    m.chipName = m.top.findNode("chipName")
    m.chipName.font = hFont("regular", 22)
    for each c in m.chipDefs
        if c[2] = "sep"
            g = m.chips.createChild("Group")
            spacer = g.createChild("Rectangle")
            spacer.width = 26
            spacer.height = 64
            spacer.color = "0x00000000"
            line = g.createChild("Rectangle")
            line.translation = [12, 12]
            line.width = 2
            line.height = 40
            line.color = "0xD9A06655"
        else
            p = m.chips.createChild("MusicChip")
            p.icon = c[0]
            p.text = c[1]
            p.big = (c[2] = "toggle")
        end if
    end for

    m.row = 0
    m.chip = 1
    m.focused = false
    m.rows = []
    m.results = {}
    m.loadedFor = ""

    p = muPlayer()
    for each f in ["track", "state", "shuffle", "repeat", "queue"]
        p.observeField(f, "showNow")
    end for
    p.observeField("position", "showTime")
    p.observeField("message", "onMessage")
    p.observeField("section", "refresh")
    showNow()
    paint()
    ' load the shelves as soon as the room exists (the hub only refreshes rooms it already had)
    refresh()
end sub

sub focusIn(unused as dynamic)
    if m.rows.count() = 0 then refresh()
    m.focused = true
    m.top.setFocus(true)
    paint()
end sub

' ---------- now playing ----------
sub showNow()
    n = muNow()
    p = muPlayer()
    m.eyebrow.text = n.eyebrow
    m.title.text = n.title
    m.sub.text = n.sub
    ' with nothing queued, the lantern keeps the square from sitting empty
    if n.track <> invalid
        m.art.uri = pxImage(n.track.thumb, 300, 300)
    else
        m.art.uri = "pkg:/images/lantern.png"
    end if
    if not pxReady()
        m.eyebrow.text = "PLEX ISN'T LINKED"
        m.title.text = "Sign in to Plex"
        m.sub.text = "Hearth's setup links Plex with a short code at plex.tv/link."
    end if
    ' chip icons and names follow the player
    playing = (p.state = "playing" or p.state = "buffering")
    if playing then m.chipNames.toggle = "Pause" else m.chipNames.toggle = "Play"
    if p.repeat = "one" then m.chipNames.repeat = "Repeat one" else if p.repeat = "all" then m.chipNames.repeat = "Repeat all" else m.chipNames.repeat = "Repeat"
    if p.shuffle then m.chipNames.shuffle = "Shuffle on" else m.chipNames.shuffle = "Shuffle"
    for i = 0 to m.chipDefs.count() - 1
        a = m.chipDefs[i][2]
        c = m.chips.getChild(i)
        if a = "toggle"
            if playing then c.icon = "pause" else c.icon = "play"
        else if a = "shuffle"
            c.on = p.shuffle
        else if a = "repeat"
            c.on = (p.repeat <> "off")
            if p.repeat = "one" then c.badge = "1" else c.badge = ""
        end if
    end for
    showTime()
end sub

sub showTime()
    p = muPlayer()
    if p.track = invalid
        m.fill.width = 0
        m.time.text = ""
        return
    end if
    d = p.duration
    if d > 0 then m.fill.width = 900 * p.position / d else m.fill.width = 0
    m.time.text = pxClock(p.position) + "  /  " + pxClock(d)
end sub

sub onMessage()
    ' while the shelves are empty, keep the latest word from the player in their place
    if m.rows.count() = 0 then m.empty.text = muPlayer().message
    m.toast.text = muPlayer().message
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub hideToast()
    m.toast.text = ""
end sub

' ---------- shelves ----------
sub refresh(unused = invalid as dynamic)
    if not pxReady()
        showNow()
        return
    end if
    s = muPlayer().section
    if s = ""
        if m.rows.count() = 0 then m.empty.text = "Looking for your music library in Plex" + Chr(8230)
        muSend("findLibrary")
        return
    end if
    if m.rows.count() = 0 then m.empty.text = "Loading your music" + Chr(8230)
    if m.loadedFor = s and m.rows.count() > 0 then return
    m.loadedFor = s
    m.results = {}
    m.hubOrder = []
    ' build the shelves once, when every answer is in (or after a few seconds), so they don't jump about
    m.waiting = 4
    m.builtOnce = false
    m.buildTimer.control = "stop"
    m.buildTimer.control = "start"
    pxApi("/hubs/sections/" + s + "?count=12", {}, "onHubs", "hubs")
    pxApi("/playlists", { playlistType: "audio" }, "onShelf", "Playlists")
    pxApi("/library/sections/" + s + "/all", { type: "8", sort: "titleSort", "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "40" }, "onShelf", "Artists")
    pxApi("/library/sections/" + s + "/all", { type: "9", sort: "titleSort", "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "40" }, "onShelf", "Albums A to Z")
end sub

sub arrived()
    m.waiting = m.waiting - 1
    if m.waiting <= 0 or m.builtOnce then build()
end sub

sub onBuildTimer()
    if not m.builtOnce then build()
end sub

sub onHubs(event as object)
    t = hTaskFrom(event)
    if not t.ok or t.response.MediaContainer = invalid or t.response.MediaContainer.Hub = invalid
        arrived()
        return
    end if
    for each hub in t.response.MediaContainer.Hub
        ok = (hub.type = "album" or hub.type = "artist" or hub.type = "playlist")
        if ok and hub.Metadata <> invalid and hub.Metadata.count() > 0 and m.hubOrder.count() < 3
            name = pxStr(hub.title)
            m.hubOrder.push(name)
            m.results[name] = hub.Metadata
        end if
    end for
    arrived()
end sub

sub onShelf(event as object)
    t = hTaskFrom(event)
    m.results[t.tag] = pxItems(t)
    if not t.ok
        m.failed = "Couldn't load " + t.tag + " from Plex (error " + t.status.toStr() + ")."
        onMessageText(m.failed)
    end if
    arrived()
end sub

sub build()
    m.builtOnce = true
    m.buildTimer.control = "stop"
    order = []
    if m.hubOrder <> invalid then order.append(m.hubOrder)
    order.push("Artists")
    order.push("Albums A to Z")
    order.push("Playlists")
    keepTitle = invalid
    keepIndex = 0
    if m.row > 0 and m.row - 1 < m.rows.count()
        keepTitle = m.rows[m.row - 1].title
        keepIndex = m.rows[m.row - 1].index
    end if
    m.shelves.removeChildrenIndex(m.shelves.getChildCount(), 0)
    m.rows = []
    y = 0
    for each name in order
        items = m.results[name]
        if items <> invalid and items.count() > 0
            r = m.shelves.createChild("CardRow")
            r.translation = [96, y]
            r.title = name
            r.cardWidth = 220
            r.cardHeight = 220
            ' artists are round, albums square
            if items[0].type = "artist" then r.maskUri = "pkg:/images/music/round-mask.png"
            cards = []
            for each md in items
                c = pxCard(md, 220)
                ' artists without a picture borrow their first album's cover
                if c.image = "" and md.type = "artist" then c.image = albumCoverFor(pxStr(md.ratingKey))
                cards.push(c)
            end for
            r.cards = cards
            if name = keepTitle then r.index = keepIndex
            m.rows.push(r)
            y = y + r.rowHeight + 20
        end if
    end for
    if m.rows.count() > 0
        m.empty.text = ""
    else if m.failed <> invalid
        m.empty.text = m.failed
    end if
    if keepTitle <> invalid
        m.row = 0
        for i = 0 to m.rows.count() - 1
            if m.rows[i].title = keepTitle then m.row = i + 1
        end for
    end if
    paint()
end sub

' ---------- focus ----------
sub paint()
    for i = 0 to m.chips.getChildCount() - 1
        if m.chipDefs[i][2] <> "sep" then m.chips.getChild(i).focused = (m.focused and m.row = 0 and i = m.chip)
    end for
    ' name the focused icon-only button, so nothing is a mystery
    name = ""
    if m.focused and m.row = 0
        n = m.chipNames[m.chipDefs[m.chip][2]]
        if n <> invalid then name = n
    end if
    m.chipName.text = name
    for i = 0 to m.rows.count() - 1
        m.rows[i].active = (m.focused and m.row = i + 1)
    end for
    ' keep the focused shelf in view: rows after the first push the page up
    y = 0
    if m.row >= 2 then y = -(m.rows[m.row - 1].translation[1])
    target = [0, y]
    cur = m.content.translation
    if cur[1] <> y
        m.scroll.control = "stop"
        m.scrollTo.keyValue = [cur, target]
        m.scroll.control = "start"
    end if
end sub

sub muRestoreFocus()
    m.top.setFocus(true)
end sub

sub activate()
    if m.row = 0
        a = m.chipDefs[m.chip][2]
        if not pxReady() and a <> "cover" and a <> "milk" and a <> "hearth" and a <> "request"
            onMessageText("Sign in to Plex first.")
            return
        end if
        muDo(a)
        return
    end if
    card = m.rows[m.row - 1].callFunc("current", invalid)
    if card = invalid then return
    md = card.item
    kind = pxStr(md.type)
    ' artists open their page; albums open their artist's page with that album unfolded
    if kind = "artist"
        m.top.request = { action: "musicView", mode: "artist", artistId: pxStr(md.ratingKey) }
    else if kind = "album" and md.parentRatingKey <> invalid
        m.top.request = { action: "musicView", mode: "artist", artistId: pxStr(md.parentRatingKey), albumId: pxStr(md.ratingKey) }
    else
        muSend("playContainer", { kind: kind, id: pxStr(md.ratingKey), shuffle: false, label: pxStr(md.title) })
    end if
end sub

sub onMessageText(t as string)
    m.toast.text = t
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

' * on a shelf card: play, shuffle
sub cardOptions()
    card = m.rows[m.row - 1].callFunc("current", invalid)
    if card = invalid then return
    m.optCard = card.item
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = pxStr(card.item.title)
    d.message = [card.sub]
    d.buttons = ["Play", "Shuffle", "Close"]
    d.observeField("buttonSelected", "onCardOption")
    d.observeField("wasClosed", "onMuClosed")
    m.cardDialog = d
    m.top.getScene().dialog = d
end sub

sub onCardOption()
    b = m.cardDialog.buttonSelected
    m.cardDialog.close = true
    md = m.optCard
    if b = 0 or b = 1
        muSend("playContainer", { kind: pxStr(md.type), id: pxStr(md.ratingKey), shuffle: (b = 1), label: pxStr(md.title) })
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if muMediaKey(key) then return true
    if key = "back" or (key = "up" and m.row = 0)
        m.focused = false
        paint()
        m.top.request = { action: "pills" }
        return true
    end if
    if key = "OK"
        activate()
        return true
    end if
    if key = "options"
        if m.row = 0 then muOptions(true) else cardOptions()
        return true
    end if
    if key = "left" or key = "right"
        if key = "left" then d = -1 else d = 1
        if m.row = 0
            i = m.chip + d
            if i >= 0 and i < m.chipDefs.count() and m.chipDefs[i][2] = "sep" then i = i + d
            if i >= 0 and i < m.chipDefs.count() then m.chip = i
        else
            m.rows[m.row - 1].callFunc("move", d)
        end if
        paint()
        return true
    end if
    if key = "up"
        m.row = m.row - 1
        paint()
        return true
    end if
    if key = "down"
        if m.row < m.rows.count() then m.row = m.row + 1
        paint()
        return true
    end if
    return true
end function


function albumCoverFor(artistId as string) as string
    albums = m.results["Albums A to Z"]
    if albums = invalid then return ""
    for each al in albums
        if pxStr(al.parentRatingKey) = artistId and al.thumb <> invalid then return pxImage(al.thumb, 220, 220)
    end for
    return ""
end function
