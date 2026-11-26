' Music, layout B. Focus zones: "panel" (now playing, left), "tabs", "letters" (A to Z), "content" (shelves or grid).
sub init()
    m.panel = m.top.findNode("panel")
    m.panel.observeField("request", "onPanelRequest")
    m.queue = m.top.findNode("queue")
    m.tabsG = m.top.findNode("tabs")
    m.lettersG = m.top.findNode("letters")
    m.heading = m.top.findNode("heading")
    m.heading.font = hFont("caps", 26)
    m.shelves = m.top.findNode("shelves")
    m.grid = m.top.findNode("grid")
    m.empty = m.top.findNode("empty")
    m.empty.font = hFont("regular", 30)
    m.toast = m.top.findNode("toast")
    m.toast.font = hFont("bold", 26)
    m.toastTimer = m.top.findNode("toastTimer")
    m.toastTimer.observeField("fire", "hideToast")
    m.scroll = m.top.findNode("scroll")
    m.scrollTo = m.top.findNode("scrollTo")
    m.buildTimer = m.top.findNode("buildTimer")
    m.buildTimer.observeField("fire", "onBuildTimer")
    m.clip = m.top.findNode("clip")
    m.spotG = m.top.findNode("spot")
    m.banner = m.top.findNode("banner")
    m.bannerText = m.top.findNode("bannerText")
    m.bannerText.font = hFont("bold", 24)
    m.retryFill = m.top.findNode("retryFill")
    m.retryIcon = m.top.findNode("retryIcon")
    m.retryLabel = m.top.findNode("retryLabel")
    m.retryLabel.font = hFont("bold", 22)
    m.offline = {}
    m.retrying = {}
    m.bo = 0

    ' tabs are plain words with a gold underline (like Movies and Shows); Request sits apart after a divider
    m.tabDefs = [["For you", "foryou"], ["Artists", "artists"], ["Albums", "albums"], ["Playlists", "playlists"], ["New", "new"], ["Discover", "discover"], ["Radio", "radio"], ["Request", "request"]]
    m.tabNodes = []
    x = 0
    for each t in m.tabDefs
        g = m.tabsG.createChild("Group")
        if t[1] = "request"
            dv = m.tabsG.createChild("Rectangle")
            dv.translation = [x - 10, 14]
            dv.width = 2
            dv.height = 30
            dv.color = "0xD9A06655"
            x = x + 24
        end if
        g.translation = [x, 6]
        lx = 0
        ic = invalid
        if t[1] = "request"
            ic = g.createChild("Poster")
            ic.uri = "pkg:/images/music/icons/request.png"
            ic.width = 28
            ic.height = 28
            ic.translation = [0, 6]
            lx = 38
        end if
        l = g.createChild("Label")
        l.font = hFont("regular", 28)
        l.text = t[0]
        l.translation = [lx, 0]
        w = Int(l.localBoundingRect().width)
        u = g.createChild("Rectangle")
        u.translation = [lx, 42]
        u.width = w
        u.height = 3
        u.color = "0xE0B34AFF"
        u.visible = false
        g.addFields({ label: l, under: u, icon: ic })
        m.tabNodes.push(g)
        x = x + lx + w + 44
    end for

    m.spot = m.top.findNode("spot")
    m.spotArt = m.top.findNode("spotArt")
    m.spotEyebrow = m.top.findNode("spotEyebrow")
    m.spotEyebrow.font = hFont("caps", 26)
    m.spotTitle = m.top.findNode("spotTitle")
    m.spotTitle.font = hFont("bold", 50)
    m.spotSub = m.top.findNode("spotSub")
    m.spotSub.font = hFont("regular", 26)
    sc = m.top.findNode("spotChips")
    m.spotBtns = []
    bx = 0
    for each b in [["play", "Play"], ["shuffle", "Shuffle"]]
        c = sc.createChild("MusicChip")
        c.icon = b[0]
        c.text = b[1]
        c.translation = [bx, 0]
        bx = bx + c.width + 12
        m.spotBtns.push(c)
    end for
    m.newSpot = false
    m.spotBtn = 0

    m.LET = "#ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    for i = 0 to Len(m.LET) - 1
        g = m.lettersG.createChild("Group")
        g.translation = [8 + i * 42, 6]
        hl = g.createChild("Rectangle")
        hl.width = 40
        hl.height = 46
        hl.color = "0xE0B34A00"
        l = g.createChild("Label")
        l.width = 40
        l.height = 46
        l.horizAlign = "center"
        l.vertAlign = "center"
        l.font = hFont("bold", 22)
        l.text = Mid(m.LET, i + 1, 1)
    end for

    m.disc = m.top.findNode("disc")
    m.disc.observeField("request", "onDiscRequest")
    m.zone = "content"
    m.lastRight = "content"
    m.focused = false
    m.tab = 0
    m.tabSel = 0
    m.letter = 1
    m.row = 0
    m.rows = []
    m.results = {}
    m.loadedFor = ""
    m.lib = {}

    p = muPlayer()
    p.observeField("message", "onMessage")
    p.observeField("section", "refresh")
    paint()
    refresh()
end sub

sub focusIn(unused as dynamic)
    if m.rows.count() = 0 then refresh()
    m.focused = true
    if m.zone = "content" and not hasContent() then m.zone = upZone()
    if m.zone = "banner" and not bannerOn() then m.zone = "tabs"
    m.top.setFocus(true)
    paint()
end sub

sub onPanelRequest()
    r = m.panel.request
    if r = invalid then return
    if r.action = "refocus"
        m.top.setFocus(true)
    else if r.action = "queue"
        m.queue.visible = true
        m.queue.callFunc("open")
        m.zone = "queue"
    else
        m.top.request = r
    end if
end sub

sub muRestoreFocus()
    m.top.setFocus(true)
end sub

sub onMessage()
    t = muPlayer().message
    if m.rows.count() = 0 and m.tab = 0 then m.empty.text = t
    onMessageText(t)
end sub

sub onMessageText(t as string)
    m.toast.text = t
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub hideToast()
    m.toast.text = ""
end sub

' ---------- For you: shelves ----------
sub refresh(unused = invalid as dynamic)
    if not pxReady()
        m.empty.text = "Sign in to Plex first. Hearth's setup links it with a short code at plex.tv/link."
        m.top.ready = true
        return
    end if
    s = muPlayer().section
    if s = ""
        if m.rows.count() = 0 then m.empty.text = "Looking for your music library in Plex" + Chr(8230)
        muSend("findLibrary")
        return
    end if
    again = (m.retrying["foryou"] = true)
    if m.loadedFor = s and m.rows.count() > 0 and not again then return
    if m.loadedFor <> s
        m.lib = {}
        m.asked = {}
    end if
    m.loadedFor = s
    m.failed = invalid
    if m.rows.count() = 0 and m.tab = 0 then m.empty.text = "Loading your music" + Chr(8230)
    m.results = {}
    m.hubOrder = []
    if m.rows.count() = 0
        c = cacheRead("foryou")
        if c <> invalid and c.results <> invalid and c.hubOrder <> invalid
            m.results = c.results
            m.hubOrder = c.hubOrder
            build()
            m.results = {}
            m.hubOrder = []
        end if
    end if
    m.builtOnce = false
    m.waiting = 3
    m.builtOnce = false
    m.buildTimer.control = "stop"
    m.buildTimer.control = "start"
    pxApi("/hubs/sections/" + s + "?count=12", {}, "onHubs", "hubs")
    pxApi("/playlists", { playlistType: "audio" }, "onShelf", "Playlists")
    pxApi("/library/sections/" + s + "/all", { type: "8", sort: "titleSort", "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "40" }, "onShelf", "Artists")
end sub

sub arrived()
    m.waiting = m.waiting - 1
    if m.waiting = 0
        got = false
        for each k in m.results
            if m.results[k] <> invalid and m.results[k].count() > 0 then got = true
        end for
        m.retrying.Delete("foryou")
        if m.failed <> invalid and not got
            m.offline["foryou"] = true
        else
            m.offline.Delete("foryou")
            ' some shelves came, some didn't: a short note is enough
            if m.failed <> invalid then onMessageText(m.failed)
        end if
        if m.tabDefs[m.tab][1] = "foryou"
            applyBanner()
            if m.offline["foryou"] = true and m.rows.count() = 0 then m.empty.text = ""
        end if
    end if
    if m.waiting <= 0 or m.builtOnce then build()
    if m.waiting = 0 and m.failed = invalid
        slim = {}
        for each k in m.results
            slim[k] = slimItems(m.results[k])
        end for
        cacheWrite("foryou", { hubOrder: m.hubOrder, results: slim })
    end if
end sub

sub onBuildTimer()
    if not m.builtOnce then build()
end sub

sub onHubs(event as object)
    t = hTaskFrom(event)
    if t.ok and t.response.MediaContainer <> invalid and t.response.MediaContainer.Hub <> invalid
        for each hub in t.response.MediaContainer.Hub
            ok = (hub.type = "album" or hub.type = "artist" or hub.type = "playlist")
            if ok and hub.Metadata <> invalid and hub.Metadata.count() > 0 and m.hubOrder.count() < 3
                name = pxStr(hub.title)
                m.hubOrder.push(name)
                m.results[name] = hub.Metadata
            end if
        end for
    end if
    arrived()
end sub

sub onShelf(event as object)
    t = hTaskFrom(event)
    m.results[t.tag] = pxItems(t)
    if not t.ok then m.failed = "Couldn't load " + t.tag + " from Plex."
    arrived()
end sub

sub build()
    m.builtOnce = true
    m.top.ready = true
    m.buildTimer.control = "stop"
    order = []
    if m.hubOrder <> invalid then order.append(m.hubOrder)
    order.push("Artists")
    order.push("Playlists")
    ' every call failed: keep the shelves the cache drew rather than blanking them
    if m.failed <> invalid and m.rows.count() > 0
        got = false
        for each name in order
            if m.results[name] <> invalid and m.results[name].count() > 0 then got = true
        end for
        if not got then return
    end if
    keepTitle = invalid
    keepIndex = 0
    if m.row < m.rows.count()
        keepTitle = m.rows[m.row].title
        keepIndex = m.rows[m.row].index
    end if
    m.shelves.removeChildrenIndex(m.shelves.getChildCount(), 0)
    m.rows = []
    y = 0
    prevSeed = 0
    for each name in order
        items = m.results[name]
        if items <> invalid and items.count() > 0
            r = m.shelves.createChild("CardRow")
            r.translation = [0, y]
            ' each shelf gets its own twig: a pick that depends on the shelf's name but is never the same as the shelf above
            nh = 0
            for ci = 1 to Len(name)
                nh = (nh * 31 + Asc(Mid(name, ci, 1))) mod 1009
            end for
            prevSeed = (prevSeed + 1 + (nh mod 3)) mod 4
            r.seed = prevSeed
            r.viewWidth = 1150
            r.noMoss = true
            r.title = name
            r.cardWidth = 200
            r.cardHeight = 200
            if items[0].type = "artist" then r.roundCards = true
            cards = []
            for each md in items
                cards.push(pxCard(md, 200))
            end for
            r.cards = cards
            if name = keepTitle then r.index = keepIndex
            m.rows.push(r)
            y = y + r.rowHeight + 20
        end if
    end for
    m.row = 0
    for i = 0 to m.rows.count() - 1
        if m.rows[i].title = keepTitle then m.row = i
    end for
    if m.tab = 0
        if m.rows.count() > 0
            m.empty.text = ""
        else if m.failed <> invalid and m.offline["foryou"] <> true
            m.empty.text = m.failed
        end if
    end if
    paint()
end sub

' ---------- Artists / Albums / Playlists: grids ----------
sub showTab(i as integer)
    m.tab = i
    kind = m.tabDefs[i][1]
    m.empty.text = ""
    m.heading.text = ""
    forYou = (kind = "foryou")
    m.shelves.visible = forYou
    m.grid.visible = not forYou
    m.lettersG.visible = (kind = "artists" or kind = "albums")
    m.spot.visible = false
    m.disc.visible = (kind = "discover")
    applyBanner()
    if kind = "discover"
        m.shelves.visible = false
        m.grid.visible = false
        m.lettersG.visible = false
        ' Recommended leaves out artists already in Plex, so make sure the artist list is on its way
        al = m.lib["artists"]
        if al = invalid or al.cards = invalid
            if m.asked = invalid then m.asked = {}
            if m.asked["artists"] <> true or m.loadedFor <> m.askedFor
                m.asked["artists"] = true
                m.askedFor = m.loadedFor
                loadLib("artists")
            end if
        end if
        sendKnown()
        m.disc.callFunc("load", invalid)
        paint()
        return
    end if
    if kind = "new"
        showNew()
        paint()
        return
    end if
    if forYou
        if m.rows.count() = 0 and not bannerOn() then m.empty.text = "Loading your music" + Chr(8230)
        paint()
        return
    end if
    if m.lettersG.visible then m.grid.translation = [690, 240 + m.bo] else m.grid.translation = [690, 132 + m.bo]
    if m.lettersG.visible then m.grid.viewHeight = 690 - m.bo else m.grid.viewHeight = 798 - m.bo
    m.grid.round = (kind = "artists")
    lib = m.lib[kind]
    if lib = invalid or lib.cards = invalid
        m.grid.cards = []
        if m.asked = invalid then m.asked = {}
        if m.asked[kind] <> true or m.loadedFor <> m.askedFor
            m.asked[kind] = true
            m.askedFor = m.loadedFor
            loadLib(kind)
        else
            m.empty.text = "Loading" + Chr(8230)
        end if
    else
        m.grid.index = lib.index
        m.grid.cards = lib.cards
        if lib.cards.Count() = 0 then m.empty.text = lib.note
    end if
    paint()
end sub

sub loadLib(kind as string, useCache = true as boolean)
    s = muPlayer().section
    here = (m.tabDefs[m.tab][1] = kind)
    if not pxReady() or s = ""
        m.retrying.Delete(kind)
        if here then m.empty.text = "Sign in to Plex first."
        return
    end if
    c = invalid
    if useCache then c = cacheRead(kind)
    if not useCache
        ' Try again: keep what is on screen until Plex answers
    else if c <> invalid and c.items <> invalid
        lib = { cards: [], index: 0, note: "", starts: c.starts }
        for each md in c.items
            lib.cards.push(pxCard(md, 180))
        end for
        m.lib[kind] = lib
        if here then showTab(m.tab)
        if kind = "artists" and m.tabDefs[m.tab][1] = "discover" then sendKnown()
    else if here
        m.empty.text = "Loading" + Chr(8230)
    end if
    if kind = "playlists"
        pxApi("/playlists", { playlistType: "audio" }, "onLib", kind)
        return
    end if
    if kind = "new"
        pxApi("/library/sections/" + s + "/all", { type: "9", sort: "addedAt:desc", "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "60" }, "onLib", kind)
        return
    end if
    if kind = "artists" then ty = "8" else ty = "9"
    pxApi("/library/sections/" + s + "/all", { type: ty, sort: "titleSort", "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "5000" }, "onLib", kind)
    pxApi("/library/sections/" + s + "/firstCharacter", { type: ty }, "onLetters", kind)
end sub

sub onLib(event as object)
    t = hTaskFrom(event)
    kind = t.tag
    ' a failed refresh keeps what the cache already drew instead of blanking it
    m.retrying.Delete(kind)
    if t.ok then m.offline.Delete(kind) else m.offline[kind] = true
    old = m.lib[kind]
    if not t.ok and old <> invalid and old.cards <> invalid and old.cards.Count() > 0
        if m.tabDefs[m.tab][1] = kind then showTab(m.tab)
        return
    end if
    cards = []
    items = pxItems(t)
    for each md in items
        cards.push(pxCard(md, 180))
    end for
    if t.ok and items.Count() > 0
        if m.pendingCache = invalid then m.pendingCache = {}
        m.pendingCache[kind] = slimItems(items)
        saveLib(kind)
    end if
    note = ""
    ' a failure says so in the banner above the empty area
    if t.ok and cards.Count() = 0 then note = "Nothing here yet."
    lib = m.lib[kind]
    if lib = invalid then lib = { starts: invalid }
    keepIndex = 0
    if lib.index <> invalid and lib.index < cards.Count() then keepIndex = lib.index
    lib.cards = cards
    lib.index = keepIndex
    lib.note = note
    m.lib[kind] = lib
    if m.tabDefs[m.tab][1] = kind then showTab(m.tab)
    if kind = "artists" and m.tabDefs[m.tab][1] = "discover" then sendKnown()
end sub

' Plex counts titles per first letter, in the same order as titleSort, so each letter's first card is a running total.
sub onLetters(event as object)
    t = hTaskFrom(event)
    kind = t.tag
    starts = {}
    total = 0
    mc = invalid
    if t.ok and t.response <> invalid then mc = t.response.MediaContainer
    if mc <> invalid and mc.Directory <> invalid
        for each d in mc.Directory
            ch = UCase(pxStr(d.title))
            if Len(ch) <> 1 or ch < "A" or ch > "Z" then ch = "#"
            if starts[ch] = invalid then starts[ch] = total
            if d.size <> invalid then total = total + d.size
        end for
    end if
    lib = m.lib[kind]
    if lib = invalid then lib = { cards: invalid, index: 0, note: "" }
    lib.starts = starts
    m.lib[kind] = lib
    if m.startsCache = invalid then m.startsCache = {}
    m.startsCache[kind] = starts
    saveLib(kind)
    paint()
end sub

' once both the list and its letters are in, keep them for next time
sub saveLib(kind as string)
    if m.pendingCache = invalid or m.pendingCache[kind] = invalid then return
    starts = invalid
    if m.startsCache <> invalid then starts = m.startsCache[kind]
    if kind <> "playlists" and starts = invalid then return
    cacheWrite(kind, { items: m.pendingCache[kind], starts: starts })
    m.pendingCache.Delete(kind)
end sub

function curLib() as object
    return m.lib[m.tabDefs[m.tab][1]]
end function

function hasContent() as boolean
    if m.tabDefs[m.tab][1] = "discover" then return true
    if m.tab = 0 then return m.rows.count() > 0
    if m.tabDefs[m.tab][1] = "new" and m.newItem <> invalid then return true
    lib = curLib()
    return lib <> invalid and lib.cards <> invalid and lib.cards.Count() > 0
end function

' the letter the focused card sits under
function letterAt(index as integer) as integer
    lib = curLib()
    if lib = invalid or lib.starts = invalid then return -1
    best = -1
    bestStart = -1
    for i = 0 to Len(m.LET) - 1
        s = lib.starts[Mid(m.LET, i + 1, 1)]
        if s <> invalid and s <= index and s >= bestStart
            best = i
            bestStart = s
        end if
    end for
    return best
end function

function letterCount(i as integer) as integer
    lib = curLib()
    s = lib.starts[Mid(m.LET, i + 1, 1)]
    if s = invalid then return 0
    nxt = lib.cards.Count()
    for each k in lib.starts
        v = lib.starts[k]
        if v > s and v < nxt then nxt = v
    end for
    return nxt - s
end function

function hasLetter(i as integer) as boolean
    lib = curLib()
    return lib <> invalid and lib.starts <> invalid and lib.starts[Mid(m.LET, i + 1, 1)] <> invalid
end function

' ---------- focus ----------
sub paint()
    m.panel.active = (m.focused and m.zone = "panel")
    for i = 0 to m.tabNodes.Count() - 1
        g = m.tabNodes[i]
        cur = (i = m.tab and m.tabDefs[i][1] <> "request" and m.tabDefs[i][1] <> "radio")
        foc = (m.focused and m.zone = "tabs" and i = m.tabSel)
        g.under.visible = cur or foc
        if foc
            col = "0xE0B34AFF"
        else if cur
            col = "0xEDE6CAFF"
        else
            col = "0xB5AF8CFF"
        end if
        g.label.color = col
        if g.icon <> invalid then g.icon.blendColor = col
    end for
    onNew = (m.tabDefs[m.tab][1] = "new")
    for i = 0 to m.spotBtns.Count() - 1
        m.spotBtns[i].focused = (onNew and m.focused and m.zone = "content" and m.newSpot and i = m.spotBtn)
    end for
    for i = 0 to m.rows.count() - 1
        m.rows[i].active = (m.focused and m.zone = "content" and m.tab = 0 and m.row = i)
    end for
    onDisc = (m.tabDefs[m.tab][1] = "discover")
    m.disc.active = (m.focused and m.zone = "content" and onDisc)
    m.grid.active = (m.focused and m.zone = "content" and m.tab > 0 and not onDisc and not (onNew and m.newSpot))
    if m.tab = 0 and m.rows.count() > 0
        y = 0
        if m.row >= 1 then y = -(m.rows[m.row].translation[1])
        target = [690, 132 + m.bo + y]
        cur = m.shelves.translation
        if cur[1] <> target[1]
            m.scroll.control = "stop"
            m.scrollTo.keyValue = [cur, target]
            m.scroll.control = "start"
        end if
    end if
    if m.lettersG.visible then paintLetters()
    f = (m.focused and m.zone = "banner")
    if f
        m.retryFill.blendColor = "0xE0B34AFF"
        m.retryIcon.blendColor = "0x1F1606FF"
        m.retryLabel.color = "0x1F1606FF"
    else
        m.retryFill.blendColor = "0xFFFFFF14"
        m.retryIcon.blendColor = "0xEDE6CAFF"
        m.retryLabel.color = "0xEDE6CAFF"
    end if
end sub

sub paintLetters()
    here = -1
    lib = curLib()
    if lib <> invalid and lib.cards <> invalid and lib.cards.Count() > 0 then here = letterAt(m.grid.index)
    for i = 0 to Len(m.LET) - 1
        g = m.lettersG.getChild(i + 1)
        l = g.getChild(1)
        if m.focused and m.zone = "letters" and i = m.letter
            g.getChild(0).color = "0xE0B34AFF"
            l.color = "0x1F1606FF"
        else if i = here
            g.getChild(0).color = "0xE0B34A2E"
            l.color = "0xE0B34AFF"
        else
            g.getChild(0).color = "0xE0B34A00"
            if hasLetter(i) then l.color = "0xB5AF8CFF" else l.color = "0x5E5A44FF"
        end if
    end for
    if here >= 0
        n = letterCount(here)
        if m.tabDefs[m.tab][1] = "artists" then what = " artists" else what = " albums"
        if n = 1 then what = Left(what, Len(what) - 1)
        m.heading.text = Mid(m.LET, here + 1, 1) + "  ·  " + n.toStr() + what
    else
        m.heading.text = ""
    end if
end sub

' ---------- actions ----------
function focusedCard() as object
    ' the New tab's spotlight album is focused while newSpot is set
    if m.tabDefs[m.tab][1] = "new" and m.newSpot and m.newItem <> invalid
        return { item: m.newItem, sub: pxStr(m.newItem.parentTitle) }
    end if
    if m.tab = 0
        if m.row >= m.rows.count() then return invalid
        return m.rows[m.row].callFunc("current", invalid)
    end if
    return m.grid.callFunc("current", invalid)
end function

sub openCard()
    card = focusedCard()
    if card = invalid then return
    md = card.item
    kind = pxStr(md.type)
    ' artists open their page; albums open their artist's page on that album
    if kind = "artist"
        m.top.request = { action: "musicView", mode: "artist", artistId: pxStr(md.ratingKey) }
    else if kind = "album" and md.parentRatingKey <> invalid
        m.top.request = { action: "musicView", mode: "artist", artistId: pxStr(md.parentRatingKey), albumId: pxStr(md.ratingKey) }
    else
        muSend("playContainer", { kind: kind, id: pxStr(md.ratingKey), shuffle: false, label: pxStr(md.title) })
    end if
end sub

' * on a card: play, shuffle
sub cardOptions()
    card = focusedCard()
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

sub onDiscRequest()
    r = m.disc.request
    if r <> invalid then m.top.request = r
end sub

sub toPills()
    m.focused = false
    paint()
    m.top.request = { action: "pills" }
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if muMediaKey(key) then return true
    if m.zone = "queue"
        if m.queue.callFunc("handleKey", key) = "close"
            m.queue.visible = false
            m.zone = "panel"
            paint()
        end if
        return true
    end if
    if key = "back"
        if m.zone = "panel" and m.panel.castOpen
            m.panel.callFunc("handleKey", key)
        else
            toPills()
        end if
        return true
    end if
    if m.zone = "panel"
        edge = m.panel.callFunc("handleKey", key)
        if edge = "up"
            toPills()
            return true
        else if edge = "right"
            if m.lastRight = "content" and not hasContent() then m.lastRight = upZone()
            if m.lastRight = "banner" and not bannerOn() then m.lastRight = "tabs"
            m.zone = m.lastRight
        end if
    else if m.zone = "tabs"
        tabKey(key)
    else if m.zone = "letters"
        letterKey(key)
    else if m.zone = "banner"
        bannerKey(key)
    else
        contentKey(key)
    end if
    if m.zone <> "panel" then m.lastRight = m.zone
    paint()
    return true
end function

' Request and Radio open their own screens instead of showing shelves
function isActionTab(i as integer) as boolean
    k = m.tabDefs[i][1]
    return (k = "request" or k = "radio")
end function

sub tabKey(key as string)
    n = m.tabDefs.Count()
    if key = "up"
        toPills()
    else if key = "left"
        if m.tabSel > 0 then m.tabSel = m.tabSel - 1 else m.zone = "panel"
        if m.zone = "tabs" and not isActionTab(m.tabSel) then showTab(m.tabSel)
    else if key = "right"
        if m.tabSel < n - 1 then m.tabSel = m.tabSel + 1
        if not isActionTab(m.tabSel) then showTab(m.tabSel)
    else if key = "OK" and isActionTab(m.tabSel)
        m.top.request = { action: "musicView", mode: m.tabDefs[m.tabSel][1] }
    else if (key = "down" or key = "OK") and bannerOn()
        m.zone = "banner"
    else if key = "down" or key = "OK"
        if m.lettersG.visible and hasContent()
            m.zone = "letters"
            here = letterAt(m.grid.index)
            if here >= 0 then m.letter = here
        else if hasContent()
            m.zone = "content"
            if m.tabDefs[m.tab][1] = "new" and m.newItem <> invalid then m.newSpot = true
        end if
    else if key = "options"
        muOptions(true)
    end if
end sub

sub letterKey(key as string)
    if key = "up"
        m.zone = upZone()
    else if key = "down"
        m.zone = "content"
    else if key = "left" or key = "right"
        if key = "left" then d = -1 else d = 1
        i = m.letter + d
        while i >= 0 and i < Len(m.LET) and not hasLetter(i)
            i = i + d
        end while
        if i >= 0 and i < Len(m.LET)
            m.letter = i
        else if d < 0
            m.zone = "panel"
        end if
    else if key = "OK"
        lib = curLib()
        if lib = invalid or lib.starts = invalid or lib.cards = invalid then return
        s = lib.starts[Mid(m.LET, m.letter + 1, 1)]
        if s <> invalid
            m.grid.callFunc("jumpTo", s)
            lib.index = s
            m.zone = "content"
        end if
    end if
end sub

sub contentKey(key as string)
    if m.tabDefs[m.tab][1] = "discover"
        edge = m.disc.callFunc("handleKey", key)
        if edge = "left" then m.zone = "panel"
        if edge = "up" then m.zone = "tabs"
        return
    end if
    if key = "OK" and m.tabDefs[m.tab][1] = "new" and m.newSpot
        newKey(key)
        return
    end if
    if key = "OK"
        openCard()
        return
    end if
    if key = "options"
        cardOptions()
        return
    end if
    if m.tab = 0
        if m.rows.count() = 0 or m.row >= m.rows.count()
            m.row = 0
            m.zone = upZone()
            return
        end if
        if key = "up"
            if m.row = 0 then m.zone = upZone() else m.row = m.row - 1
        else if key = "down"
            if m.row < m.rows.count() - 1 then m.row = m.row + 1
        else if key = "left"
            if not m.rows[m.row].callFunc("move", -1) then m.zone = "panel"
        else if key = "right"
            m.rows[m.row].callFunc("move", 1)
        end if
        return
    end if
    if m.tabDefs[m.tab][1] = "new"
        if newKey(key) then return
    end if
    moved = true
    if key = "up" then moved = m.grid.callFunc("move", 0, -1)
    if key = "down" then m.grid.callFunc("move", 0, 1)
    if key = "right" then m.grid.callFunc("move", 1, 0)
    if key = "left" and not m.grid.callFunc("move", -1, 0) then m.zone = "panel"
    if key = "up" and not moved
        if m.lettersG.visible
            m.zone = "letters"
            here = letterAt(m.grid.index)
            if here >= 0 then m.letter = here
        else
            m.zone = upZone()
        end if
    end if
    lib = curLib()
    if lib <> invalid then lib.index = m.grid.index
end sub

' ---------- cache: the room draws what it showed last time at once, then refreshes from Plex ----------
' Kept in cachefs: (survives restarts when the TV has room), falling back to tmp: (this session only).
function cachePath(name as string) as string
    return "cachefs:/hearth-music-" + muPlayer().section + "-" + name + ".json"
end function

function slimItems(items as object) as object
    out = []
    for each md in items
        o = {}
        for each k in ["type", "title", "ratingKey", "parentRatingKey", "parentTitle", "thumb", "composite", "leafCount", "addedAt"]
            if md[k] <> invalid then o[k] = md[k]
        end for
        out.push(o)
    end for
    return out
end function

sub cacheWrite(name as string, data as object)
    text = FormatJson(data)
    if text = "" then return
    if not WriteAsciiFile(cachePath(name), text) then WriteAsciiFile("tmp:/" + Mid(cachePath(name), 10), text)
end sub

function cacheRead(name as string) as object
    text = ReadAsciiFile(cachePath(name))
    if text = "" then text = ReadAsciiFile("tmp:/" + Mid(cachePath(name), 10))
    if text = "" then return invalid
    return ParseJson(hFixText(text))
end function

' ---------- New: newly downloaded albums, newest first ----------
' The newest album gets the spotlight card (Play, Shuffle); the rest are tiles that say when they arrived.
' Albums Hearth asked Lidarr for get a REQUESTED tag.
sub showNew()
    lib = m.lib["new"]
    if lib = invalid or lib.cards = invalid
        m.grid.cards = []
        m.newItem = invalid
        if m.asked = invalid then m.asked = {}
        if m.asked["new"] <> true or m.loadedFor <> m.askedFor
            m.asked["new"] = true
            m.askedFor = m.loadedFor
            loadLib("new")
        else
            m.empty.text = "Loading" + Chr(8230)
        end if
        return
    end if
    req = muRequested()
    cards = []
    for each c in lib.cards
        md = c.item
        artist = pxStr(md.parentTitle)
        c.sub = muWhen(md.addedAt)
        if artist <> "" then c.sub = artist + "  ·  " + c.sub
        c.tag = ""
        if muIsRequested(req, artist, pxStr(md.title)) then c.tag = "REQUESTED"
        cards.push(c)
    end for
    if cards.Count() = 0
        m.newItem = invalid
        m.grid.cards = []
        m.empty.text = lib.note
        return
    end if
    top = cards[0]
    m.newItem = top.item
    m.spot.visible = true
    m.spotArt.uri = top.image
    when = LCase(muWhen(top.item.addedAt))
    m.spotEyebrow.text = "JUST ARRIVED  ·  " + UCase(when)
    drop = hFitTitle(m.spotTitle, pxStr(top.title), "bold", [50, 42, 36], 860)
    m.spotTitle.translation = [256, 60 + drop]
    line = pxStr(top.item.parentTitle)
    if top.item.leafCount <> invalid then line = line + "  ·  " + top.item.leafCount.toStr() + " songs"
    if top.tag <> "" then line = line + "  ·  Requested"
    m.spotSub.text = line
    rest = []
    for i = 1 to cards.Count() - 1
        rest.push(cards[i])
    end for
    m.grid.translation = [690, 412 + m.bo]
    m.grid.viewHeight = 518 - m.bo
    m.grid.round = false
    if lib.index >= rest.Count() then lib.index = 0
    m.grid.index = lib.index
    m.grid.cards = rest
end sub

' Keys on the New tab. Returns true when handled here.
function newKey(key as string) as boolean
    if m.newSpot
        if key = "left"
            if m.spotBtn > 0 then m.spotBtn = m.spotBtn - 1 else m.zone = "panel"
        else if key = "right"
            if m.spotBtn < m.spotBtns.Count() - 1 then m.spotBtn = m.spotBtn + 1
        else if key = "up"
            m.zone = upZone()
        else if key = "down"
            gc = m.grid.cards
            if gc <> invalid and gc.Count() > 0 then m.newSpot = false
        else if key = "OK" and m.newItem <> invalid
            muSend("playContainer", { kind: "album", id: pxStr(m.newItem.ratingKey), shuffle: (m.spotBtn = 1), label: pxStr(m.newItem.title) })
        end if
        return true
    end if
    if key = "up" and not m.grid.callFunc("move", 0, -1)
        m.newSpot = true
        return true
    end if
    if key = "up" then return true
    return false
end function

' ---------- Plex not answering: banner with Try again ----------
function bannerOn() as boolean
    kind = m.tabDefs[m.tab][1]
    return m.offline[kind] = true
end function

' where Up goes from the top of the content (or the letters): the banner when it shows, else the tabs
function upZone() as string
    if bannerOn() then return "banner"
    return "tabs"
end function

' shows or hides the banner and pushes the tab's content down under it, dimmed
sub applyBanner()
    show = bannerOn()
    kind = m.tabDefs[m.tab][1]
    if show then m.bo = 72 else m.bo = 0
    m.banner.visible = show
    if show
        if m.retrying[kind] = true
            m.bannerText.text = "Trying Plex again" + Chr(8230)
        else if hasContent()
            m.bannerText.text = "Showing your saved list  ·  Plex isn't answering"
        else
            m.bannerText.text = "Plex isn't answering  ·  nothing saved on this TV yet"
        end if
    end if
    if show then op = 0.45 else op = 1.0
    m.grid.opacity = op
    m.shelves.opacity = op
    m.spotG.opacity = op
    m.lettersG.translation = [690, 112 + m.bo]
    m.heading.translation = [690, 190 + m.bo]
    m.spotG.translation = [690, 132 + m.bo]
    m.empty.translation = [690, 160 + m.bo]
    m.clip.clippingRect = [660, 112 + m.bo, 1260, 818 - m.bo]
    if not show and m.zone = "banner"
        if hasContent() then m.zone = "content" else m.zone = "tabs"
    end if
end sub

sub bannerKey(key as string)
    if key = "up"
        m.zone = "tabs"
    else if key = "left"
        m.zone = "panel"
    else if key = "down"
        if m.lettersG.visible and hasContent()
            m.zone = "letters"
            here = letterAt(m.grid.index)
            if here >= 0 then m.letter = here
        else if hasContent()
            m.zone = "content"
            if m.tabDefs[m.tab][1] = "new" and m.newItem <> invalid then m.newSpot = true
        end if
    else if key = "OK"
        retryLoad()
    end if
end sub

sub retryLoad()
    kind = m.tabDefs[m.tab][1]
    if m.retrying[kind] = true then return
    m.retrying[kind] = true
    applyBanner()
    if kind = "foryou"
        refresh()
        if not pxReady() or muPlayer().section = ""
            m.retrying.Delete("foryou")
            applyBanner()
        end if
    else
        if m.asked = invalid then m.asked = {}
        m.asked[kind] = true
        m.askedFor = m.loadedFor
        loadLib(kind, false)
    end if
end sub

' Discover drops recommended artists already in Plex, and shows the round Plex photo for loved ones you own
sub sendKnown()
    known = []
    owned = {}
    al = m.lib["artists"]
    if al <> invalid and al.cards <> invalid
        for each c in al.cards
            known.push(c.title)
            owned[LCase(c.title)] = c.image
        end for
    end if
    m.disc.owned = owned
    m.disc.known = known
end sub
