' Music, layout B. Focus zones: "panel" (now playing, left), "tabs", "letters" (A to Z), "content" (shelves or grid).
sub init()
    m.panel = m.top.findNode("panel")
    m.panel.observeField("request", "onPanelRequest")
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

    m.tabDefs = [["For you", "foryou"], ["Artists", "artists"], ["Albums", "albums"], ["Playlists", "playlists"], ["Request", "request"]]
    x = 0
    for each t in m.tabDefs
        if t[1] = "request"
            c = m.tabsG.createChild("MusicChip")
            c.icon = "request"
            c.text = t[0]
            c.translation = [x, -3]
            x = x + c.width + 10
        else
            c = m.tabsG.createChild("HearthPill")
            c.button = true
            c.text = t[0]
            c.width = Len(t[0]) * 16 + 56
            c.translation = [x, 0]
            x = x + c.width + 10
        end if
    end for

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
    if m.zone = "content" and not hasContent() then m.zone = "tabs"
    m.top.setFocus(true)
    paint()
end sub

sub onPanelRequest()
    r = m.panel.request
    if r = invalid then return
    if r.action = "refocus"
        m.top.setFocus(true)
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
        return
    end if
    s = muPlayer().section
    if s = ""
        if m.rows.count() = 0 then m.empty.text = "Looking for your music library in Plex" + Chr(8230)
        muSend("findLibrary")
        return
    end if
    if m.loadedFor = s and m.rows.count() > 0 then return
    if m.loadedFor <> s
        m.lib = {}
        m.asked = {}
    end if
    m.loadedFor = s
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
    order.push("Playlists")
    keepTitle = invalid
    keepIndex = 0
    if m.row < m.rows.count()
        keepTitle = m.rows[m.row].title
        keepIndex = m.rows[m.row].index
    end if
    m.shelves.removeChildrenIndex(m.shelves.getChildCount(), 0)
    m.rows = []
    y = 0
    for each name in order
        items = m.results[name]
        if items <> invalid and items.count() > 0
            r = m.shelves.createChild("CardRow")
            r.translation = [0, y]
            r.viewWidth = 1150
            r.title = name
            r.cardWidth = 200
            r.cardHeight = 200
            if items[0].type = "artist" then r.maskUri = "pkg:/images/music/round-mask.png"
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
        else if m.failed <> invalid
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
    if forYou
        if m.rows.count() = 0 then m.empty.text = "Loading your music" + Chr(8230)
        paint()
        return
    end if
    if m.lettersG.visible then m.grid.translation = [690, 240] else m.grid.translation = [690, 132]
    if m.lettersG.visible then m.grid.viewHeight = 690 else m.grid.viewHeight = 798
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

sub loadLib(kind as string)
    s = muPlayer().section
    if not pxReady() or s = ""
        m.empty.text = "Sign in to Plex first."
        return
    end if
    c = cacheRead(kind)
    if c <> invalid and c.items <> invalid
        lib = { cards: [], index: 0, note: "", starts: c.starts }
        for each md in c.items
            lib.cards.push(pxCard(md, 180))
        end for
        m.lib[kind] = lib
        if m.tabDefs[m.tab][1] = kind then showTab(m.tab)
    else
        m.empty.text = "Loading" + Chr(8230)
    end if
    if kind = "playlists"
        pxApi("/playlists", { playlistType: "audio" }, "onLib", kind)
        return
    end if
    if kind = "artists" then ty = "8" else ty = "9"
    pxApi("/library/sections/" + s + "/all", { type: ty, sort: "titleSort", "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "5000" }, "onLib", kind)
    pxApi("/library/sections/" + s + "/firstCharacter", { type: ty }, "onLetters", kind)
end sub

sub onLib(event as object)
    t = hTaskFrom(event)
    kind = t.tag
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
    if not t.ok then note = "Couldn't load from Plex (error " + t.status.toStr() + ")." else if cards.Count() = 0 then note = "Nothing here yet."
    lib = m.lib[kind]
    if lib = invalid then lib = { starts: invalid }
    keepIndex = 0
    if lib.index <> invalid and lib.index < cards.Count() then keepIndex = lib.index
    lib.cards = cards
    lib.index = keepIndex
    lib.note = note
    m.lib[kind] = lib
    if m.tabDefs[m.tab][1] = kind then showTab(m.tab)
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
    if m.tab = 0 then return m.rows.count() > 0
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
    for i = 0 to m.tabsG.getChildCount() - 1
        c = m.tabsG.getChild(i)
        c.focused = (m.focused and m.zone = "tabs" and i = m.tabSel)
        if m.tabDefs[i][1] <> "request" then c.current = (i = m.tab)
    end for
    for i = 0 to m.rows.count() - 1
        m.rows[i].active = (m.focused and m.zone = "content" and m.tab = 0 and m.row = i)
    end for
    m.grid.active = (m.focused and m.zone = "content" and m.tab > 0)
    if m.tab = 0 and m.rows.count() > 0
        y = 0
        if m.row >= 1 then y = -(m.rows[m.row].translation[1])
        target = [690, 132 + y]
        cur = m.shelves.translation
        if cur[1] <> target[1]
            m.scroll.control = "stop"
            m.scrollTo.keyValue = [cur, target]
            m.scroll.control = "start"
        end if
    end if
    if m.lettersG.visible then paintLetters()
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

sub toPills()
    m.focused = false
    paint()
    m.top.request = { action: "pills" }
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if muMediaKey(key) then return true
    if key = "back"
        toPills()
        return true
    end if
    if m.zone = "panel"
        edge = m.panel.callFunc("handleKey", key)
        if edge = "up"
            toPills()
            return true
        else if edge = "right"
            if m.lastRight = "content" and not hasContent() then m.lastRight = "tabs"
            m.zone = m.lastRight
        end if
    else if m.zone = "tabs"
        tabKey(key)
    else if m.zone = "letters"
        letterKey(key)
    else
        contentKey(key)
    end if
    if m.zone <> "panel" then m.lastRight = m.zone
    paint()
    return true
end function

sub tabKey(key as string)
    n = m.tabDefs.Count()
    if key = "up"
        toPills()
    else if key = "left"
        if m.tabSel > 0 then m.tabSel = m.tabSel - 1 else m.zone = "panel"
        if m.zone = "tabs" and m.tabDefs[m.tabSel][1] <> "request" then showTab(m.tabSel)
    else if key = "right"
        if m.tabSel < n - 1 then m.tabSel = m.tabSel + 1
        if m.tabDefs[m.tabSel][1] <> "request" then showTab(m.tabSel)
    else if key = "OK" and m.tabDefs[m.tabSel][1] = "request"
        m.top.request = { action: "musicView", mode: "request" }
    else if key = "down" or key = "OK"
        if m.lettersG.visible and hasContent()
            m.zone = "letters"
            here = letterAt(m.grid.index)
            if here >= 0 then m.letter = here
        else if hasContent()
            m.zone = "content"
        end if
    else if key = "options"
        muOptions(true)
    end if
end sub

sub letterKey(key as string)
    if key = "up"
        m.zone = "tabs"
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
    if key = "OK"
        openCard()
        return
    end if
    if key = "options"
        cardOptions()
        return
    end if
    if m.tab = 0
        if key = "up"
            if m.row = 0 then m.zone = "tabs" else m.row = m.row - 1
        else if key = "down"
            if m.row < m.rows.count() - 1 then m.row = m.row + 1
        else if key = "left"
            if not m.rows[m.row].callFunc("move", -1) then m.zone = "panel"
        else if key = "right"
            m.rows[m.row].callFunc("move", 1)
        end if
        return
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
            m.zone = "tabs"
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
        for each k in ["type", "title", "ratingKey", "parentRatingKey", "parentTitle", "thumb", "composite", "leafCount"]
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
    return ParseJson(text)
end function
