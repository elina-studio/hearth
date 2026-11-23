' Requests room (layout B: rail and grid, Search first; P1 poster-card popup).
' Zones: "rail", "grid", "kb" (search keyboard), "results" (search results), "popup", "setup", "save".

sub init()
    m.reg = CreateObject("roRegistrySection", "hearth")
    m.rail = m.top.findNode("rail")
    m.grid = m.top.findNode("grid")
    m.empty = m.top.findNode("empty")
    m.empty.font = hFont("regular", 28)
    m.eyebrow = m.top.findNode("eyebrow")
    m.eyebrow.font = hFont("caps", 28)
    m.rating = m.top.findNode("rating")
    m.rating.font = hFont("caps", 28)
    m.star = m.top.findNode("star")
    m.title = m.top.findNode("title")
    m.title.font = hFont("caps", 60)
    m.top.findNode("musicTitle").font = hFont("caps", 44)
    m.top.findNode("musicSub").font = hFont("regular", 26)
    m.searchPanel = m.top.findNode("searchPanel")
    m.musicPanel = m.top.findNode("musicPanel")
    m.kb = m.top.findNode("kb")
    m.kb.observeField("text", "onKbText")
    m.results = m.top.findNode("results")
    m.resultsHead = m.top.findNode("resultsHead")
    m.resultsHead.font = hFont("regular", 28)
    m.setup = m.top.findNode("setup")
    m.setupText = m.top.findNode("setupText")
    m.setupText.font = hFont("regular", 28)
    m.keyKb = m.top.findNode("keyKb")
    m.saveKey = m.top.findNode("saveKey")
    m.toast = m.top.findNode("toast")
    m.toastText = m.top.findNode("toastText")
    m.toastText.font = hFont("bold", 30)
    m.toastHint = m.top.findNode("toastHint")
    m.toastHint.font = hFont("regular", 26)
    m.popupHolder = m.top.findNode("popupHolder")
    m.top.findNode("toastTimer").observeField("fire", "onToastDone")
    m.top.findNode("undoTimer").observeField("fire", "onUndoTick")
    m.top.findNode("detailTimer").observeField("fire", "onDetailTimer")
    m.top.findNode("searchTimer").observeField("fire", "runSearch")

    m.lists = [
        { key: "search", icon: "search", name: "Search", about: "TYPE A TITLE" },
        { key: "trending", icon: "spark", name: "Trending", about: "TRENDING THIS WEEK", path: "/api/v1/discover/trending" },
        { key: "movies", icon: "film", name: "Popular movies", about: "POPULAR MOVIES", path: "/api/v1/discover/movies" },
        { key: "tv", icon: "tv", name: "Popular shows", about: "POPULAR SHOWS", path: "/api/v1/discover/tv" },
        { key: "upcoming", icon: "cal", name: "Coming soon", about: "MOVIES COMING SOON", path: "/api/v1/discover/movies/upcoming" },
        { key: "mine", icon: "clock", name: "Your requests", about: "WHAT YOU'VE ASKED FOR" },
        { key: "music", icon: "note", name: "Music", about: "LIDARR" }
    ]
    m.cards = {}
    m.details = {}
    m.tasks = {}
    m.railIndex = 1
    m.gridIndex = 0
    m.resIndex = 0
    m.zone = "rail"
    m.focused = false
    m.loaded = false
    m.pending = invalid
    m.problem = ""
    m.cols = 6
    m.pitchX = 212
    m.pitchY = 370
    m.query = ""
    m.wantPopup = ""
    m.ver = 0
    m.builtFor = ""

    if not m.global.hasField("overseerrKey") then m.global.addFields({ overseerrKey: "" })
    m.global.observeField("overseerrKey", "onKeyArrived")
    buildRail()
    refresh(invalid)
end sub

' ================================================================ loading

sub refresh(unused as dynamic)
    if apiKey() = ""
        showSetup("")
        return
    end if
    if m.setup.visible
        m.setup.visible = false
        m.top.findNode("main").visible = true
        m.zone = "rail"
    end if
    if not m.loaded
        m.loaded = true
        m.problem = ""
        for each l in m.lists
            if l.path <> invalid then oApi("GET", l.path, { page: "1" }, invalid, "onList", l.key)
        end for
    end if
    loadMine()
end sub

sub loadMine()
    t = CreateObject("roSGNode", "OverseerrTask")
    t.mode = "requests"
    t.tag = "mine"
    keep(t, "onMine")
end sub

sub oApi(method as string, path as string, query as dynamic, body as dynamic, cb as string, tag as string)
    t = CreateObject("roSGNode", "OverseerrTask")
    t.method = method
    t.path = path
    if query <> invalid then t.query = query
    if body <> invalid
        if type(body) = "roString" or type(body) = "String" then t.bodyText = body else t.body = body
    end if
    t.tag = tag
    keep(t, cb)
end sub

sub keep(t as object, cb as string)
    key = "o" + Rnd(1000000).toStr()
    t.key = key
    m.tasks[key] = t
    t.observeField("done", cb)
    t.control = "RUN"
end sub

function taskFrom(event as object) as object
    t = event.getRoSGNode()
    if t.key <> invalid then m.tasks.delete(t.key)
    return t
end function

function apiKey() as string
    k = m.reg.Read("overseerrKey")
    if k = invalid then return ""
    return k
end function

function baseUrl() as string
    u = m.reg.Read("overseerrUrl")
    if u = invalid or u = "" then u = "http://192.168.254.41:5055"
    return u
end function

sub onKeyArrived()
    m.loaded = false
    m.cards = {}
    m.ver = m.ver + 1
    refresh(invalid)
    if m.focused then focusIn(invalid)
    flash("check", "Overseerr key saved", "")
end sub

' Bad key or Overseerr down: say so in plain words
function checkProblem(t as object) as boolean
    if t.status = 401 or t.status = 403
        showSetup("Overseerr didn't accept the saved key (error " + t.status.toStr() + "). Send it again, or type it here.")
        return true
    end if
    if t.status <= 0
        m.problem = "Overseerr isn't answering at " + baseUrl() + ". Is its container running?"
        showList()
        return true
    end if
    return false
end function

sub onList(event as object)
    t = taskFrom(event)
    if checkProblem(t) then return
    m.cards[t.tag] = discoverCards(t)
    m.ver = m.ver + 1
    m.problem = ""
    paintRail()
    if currentList().key = t.tag then showList()
end sub

function discoverCards(t as object) as object
    cards = []
    if t.ok and t.response.results <> invalid
        for each r in t.response.results
            if r.mediaType = "movie" or r.mediaType = "tv" then cards.push(rqMediaCard(r))
            ' upcoming movies come without mediaType
            if r.mediaType = invalid and r.title <> invalid
                r.mediaType = "movie"
                cards.push(rqMediaCard(r))
            end if
        end for
    end if
    return cards
end function

sub onMine(event as object)
    t = taskFrom(event)
    if checkProblem(t) then return
    cards = []
    if t.ok and t.response.results <> invalid
        for each r in t.response.results
            cards.push(rqRequestCard(r.request, r.info))
        end for
    end if
    m.cards["mine"] = cards
    m.ver = m.ver + 1
    paintRail()
    if currentList().key = "mine" then showList()
end sub

' ================================================================ rail

function currentList() as object
    return m.lists[m.railIndex]
end function

sub buildRail()
    m.rail.removeChildrenIndex(m.rail.getChildCount(), 0)
    y = 0
    for each l in m.lists
        g = m.rail.createChild("Group")
        g.translation = [0, y]
        bg = g.createChild("Poster")
        bg.width = 400
        bg.height = 66
        ic = g.createChild("Poster")
        ic.uri = "pkg:/images/requests/" + l.icon + ".png"
        ic.width = 28
        ic.height = 28
        ic.translation = [24, 19]
        lab = g.createChild("Label")
        lab.font = hFont("bold", 28)
        lab.text = l.name
        lab.width = 270
        lab.height = 66
        lab.vertAlign = "center"
        lab.translation = [70, 0]
        cnt = g.createChild("Label")
        cnt.font = hFont("regular", 24)
        cnt.width = 360
        cnt.height = 66
        cnt.horizAlign = "right"
        cnt.vertAlign = "center"
        y = y + 76
    end for
    paintRail()
end sub

sub paintRail()
    for i = 0 to m.lists.count() - 1
        g = m.rail.getChild(i)
        if g = invalid then return
        bg = g.getChild(0)
        ic = g.getChild(1)
        lab = g.getChild(2)
        cnt = g.getChild(3)
        sel = (i = m.railIndex)
        if sel and m.focused and m.zone = "rail"
            bg.uri = "pkg:/images/pill.9.png"
            bg.blendColor = "0xE0B34AFF"
            bg.visible = true
            ink = "0x1F1606FF"
        else if sel
            bg.uri = "pkg:/images/pill-ring.9.png"
            bg.blendColor = "0xE0B34AFF"
            bg.visible = true
            ink = "0xEDE6CAFF"
        else
            bg.visible = false
            ink = "0xB5AF8CFF"
        end if
        ic.blendColor = ink
        lab.color = ink
        cnt.color = ink
        k = m.lists[i].key
        c = m.cards[k]
        if c <> invalid and k <> "search" and k <> "music" then cnt.text = c.count().toStr() else cnt.text = ""
    end for
end sub

' Show what the rail points at (also while just passing over it)
sub showList()
    l = currentList()
    m.searchPanel.visible = (l.key = "search")
    m.musicPanel.visible = (l.key = "music")
    m.top.findNode("gridClip").visible = (l.key <> "search" and l.key <> "music")
    m.empty.text = ""
    if l.key = "search"
        setHeader("SEARCH OVERSEERR", "", "")
        m.title.text = ""
        paintResults()
        return
    end if
    if l.key = "music"
        setHeader("MUSIC · LIDARR", "", "Request music")
        return
    end if
    buildGrid()
    if m.zone <> "grid" then setHeader(l.about, "", l.name)
    if m.problem <> "" and m.cards[l.key] = invalid
        m.empty.text = m.problem
    else if m.cards[l.key] = invalid
        m.empty.text = "Asking Overseerr…"
    else if m.cards[l.key].count() = 0
        if l.key = "mine" then m.empty.text = "No requests yet. Pick something in Trending or Search and press OK." else m.empty.text = "Nothing here right now."
    end if
end sub

sub setHeader(eyebrow as string, rating as string, title as string)
    m.eyebrow.text = eyebrow
    m.title.text = UCase(title)
    has = (rating <> "")
    m.star.visible = has
    m.rating.visible = has
    if has
        x = m.eyebrow.boundingRect().width + 14
        m.star.translation = [x, 4]
        m.rating.translation = [x + 30, 0]
        m.rating.text = rating
    end if
end sub

' ================================================================ grid

sub buildGrid()
    key = currentList().key
    cards = m.cards[key]
    stamp = key + "|" + m.ver.toStr()
    if stamp = m.builtFor and cards <> invalid
        paintGrid()
        return
    end if
    m.builtFor = stamp
    m.grid.removeChildrenIndex(m.grid.getChildCount(), 0)
    if cards = invalid then return
    if m.gridIndex >= cards.count() then m.gridIndex = 0
    for i = 0 to cards.count() - 1
        n = m.grid.createChild("ReqCard")
        n.translation = [(i mod m.cols) * m.pitchX, Int(i / m.cols) * m.pitchY]
        n.card = cards[i]
    end for
    paintGrid()
end sub

sub paintGrid()
    n = m.grid.getChildCount()
    row = Int(m.gridIndex / m.cols)
    ' keep the focused row as the first or second row on screen
    top = row - 1
    if top < 0 then top = 0
    m.grid.translation = [0, -top * m.pitchY]
    for i = 0 to n - 1
        c = m.grid.getChild(i)
        r = Int(i / m.cols)
        c.focused = (m.focused and m.zone = "grid" and i = m.gridIndex)
        if r >= top - 1 and r <= top + 3 then c.load = true
    end for
    if m.zone = "grid" then showCardInfo()
end sub

function currentCard() as object
    cards = m.cards[currentList().key]
    if cards = invalid or m.gridIndex >= cards.count() then return invalid
    return cards[m.gridIndex]
end function

sub showCardInfo()
    c = currentCard()
    if c = invalid then return
    d = withDetails(c.data)
    setHeader(rqEyebrow(d), rqRating(d.rating), d.title)
    m.top.findNode("detailTimer").control = "stop"
    m.top.findNode("detailTimer").control = "start"
end sub

' Merge cached details (runtime, seasons) into card data
function withDetails(d as object) as object
    x = m.details[d.mediaType + d.id.toStr()]
    if x = invalid then return d
    out = {}
    out.Append(d)
    if x.runtime <> invalid then out.runtime = x.runtime
    if x.numberOfSeasons <> invalid then out.seasons = x.numberOfSeasons
    return out
end function

' Fetch details for the focused title after a short pause
sub onDetailTimer()
    c = focusedMedia()
    if c = invalid then return
    d = c.data
    if m.details[d.mediaType + d.id.toStr()] <> invalid then return
    oApi("GET", "/api/v1/" + d.mediaType + "/" + d.id.toStr(), invalid, invalid, "onDetails", d.mediaType + d.id.toStr())
end sub

sub onDetails(event as object)
    t = taskFrom(event)
    if not t.ok then return
    m.details[t.tag] = t.response
    if m.zone = "grid" then showCardInfo()
    if m.wantPopup = t.tag then openPopupFor(m.wantCard)
end sub

function focusedMedia() as object
    c = invalid
    if m.zone = "grid" then c = currentCard()
    if m.zone = "results" then c = currentResult()
    if c = invalid or c.kind <> "media" then return invalid
    return c
end function

' ================================================================ search

sub onSearchTerm()
    term = m.top.searchTerm.Trim()
    if term = "" then return
    m.railIndex = 0
    m.zone = "kb"
    paintRail()
    showList()
    m.kb.text = term
    runSearch()
    refreshFocus()
end sub

sub onKbText()
    m.top.findNode("searchTimer").control = "stop"
    m.top.findNode("searchTimer").control = "start"
end sub

sub runSearch()
    q = m.kb.text
    if q = invalid then q = ""
    q = q.Trim()
    if q = m.query and m.cards["search"] <> invalid then return
    m.query = q
    if q = ""
        m.cards["search"] = []
        paintResults()
        return
    end if
    m.resultsHead.text = "Searching…"
    oApi("GET", "/api/v1/search", { query: q, page: "1" }, invalid, "onSearch", q)
end sub

sub onSearch(event as object)
    t = taskFrom(event)
    if t.tag <> m.query then return
    if checkProblem(t) then return
    m.cards["search"] = discoverCards(t)
    m.resIndex = 0
    paintResults()
end sub

function currentResult() as object
    r = m.cards["search"]
    if r = invalid or m.resIndex >= r.count() then return invalid
    return r[m.resIndex]
end function

sub paintResults()
    m.results.removeChildrenIndex(m.results.getChildCount(), 0)
    r = m.cards["search"]
    if r = invalid then r = []
    if m.query = ""
        m.resultsHead.text = "Type a few letters"
    else if r.count() = 0
        m.resultsHead.text = "Nothing found for " + Chr(8220) + m.query + Chr(8221)
    else
        m.resultsHead.text = "Results · " + r.count().toStr()
    end if
    first = m.resIndex - 4
    if first < 0 then first = 0
    y = 0
    for i = first to r.count() - 1
        if y > 700 then exit for
        c = r[i]
        g = m.results.createChild("Group")
        g.translation = [0, y]
        on = (m.focused and m.zone = "results" and i = m.resIndex)
        if on
            ring = g.createChild("Poster")
            ring.uri = "pkg:/images/ring.9.png"
            ring.blendColor = "0xE0B34AFF"
            ring.translation = [-10, -6]
            ring.width = 710
            ring.height = 136
        end if
        pb = g.createChild("Rectangle")
        pb.width = 72
        pb.height = 108
        pb.translation = [8, 8]
        pb.color = "0x1D2418FF"
        p = g.createChild("Poster")
        p.width = 72
        p.height = 108
        p.translation = [8, 8]
        p.loadDisplayMode = "scaleToZoom"
        p.uri = c.image
        t = g.createChild("Label")
        t.font = hFont("bold", 30)
        t.text = c.title
        t.width = 380
        t.translation = [104, 24]
        s = g.createChild("Label")
        s.font = hFont("regular", 22)
        s.color = "0xB5AF8CFF"
        if c.data.mediaType = "tv" then kind = "Show" else kind = "Movie"
        if c.data.year <> "" then kind = kind + " · " + c.data.year
        s.text = kind
        s.translation = [104, 66]
        ch = g.createChild("ReqCard")
        ch.card = { kind: "chiponly", chip: c.chip }
        ch.translation = [500, 52 - 282]
        y = y + 132
    end for
end sub

' ================================================================ opening a card

sub openCard(c as object)
    if c = invalid then return
    if c.kind = "search"
        m.railIndex = 0
        m.zone = "kb"
        refreshFocus()
        return
    end if
    if c.kind = "music"
        m.top.request = { action: "musicView", mode: "request" }
        return
    end if
    d = c.data
    rs = rqNum(d.requestStatus)
    if d.mediaStatus = 5 or (rs > 0 and d.mediaStatus = 4 and d.mediaType = "movie")
        openInPlex(d)
        return
    end if
    key = d.mediaType + d.id.toStr()
    if m.details[key] = invalid and d.mediaType = "tv"
        ' the season list needs the show's details first
        m.wantPopup = key
        m.wantCard = c
        oApi("GET", "/api/v1/tv/" + d.id.toStr(), invalid, invalid, "onDetails", key)
        flash("clock", "Opening " + d.title + "…", "")
        return
    end if
    openPopupFor(c)
end sub

sub openPopupFor(c as object)
    m.wantPopup = ""
    d = withDetails(c.data)
    m.popCard = c
    items = []
    overview = d.overview
    if d.note <> invalid then overview = d.note
    rs = rqNum(d.requestStatus)
    if rs = 1
        items.push({ label: "Cancel request", icon: "cancel", tag: "cancel" })
    else if d.mediaStatus = 2 or d.mediaStatus = 3
        if rs < 0 then overview = "Already requested and on its way. " + nz(d.overview)
    else if rs = 3 or rs = 4 or rs < 0
        ' not asked yet, or declined or failed: offer to ask (again)
        addRequestItems(items, d)
    end if
    if d.mediaStatus = 5 or d.mediaStatus = 4 then items.push({ label: "Open in Plex", icon: "play", tag: "plex" })
    items.push({ label: "More like this", icon: "spark", tag: "like" })
    items.push({ label: "Close", icon: "close", tag: "back" })
    showPopup({ eyebrow: rqEyebrow(d), rating: rqRating(d.rating), title: d.title, overview: overview, poster: rqImage(d.poster, "w342"), items: items, hints: [{ icon: "back", text: "Back to close" }] })
end sub

function nz(s as dynamic) as string
    if s = invalid then return ""
    return s
end function

sub addRequestItems(items as object, d as object)
    if d.mediaType = "tv"
        x = m.details["tv" + d.id.toStr()]
        latest = -1
        if x <> invalid then latest = rqLatestSeason(rqSeasons(x))
        if d.mediaStatus = 4
            items.push({ label: "Request the rest", icon: "layers", tag: "all" })
        else
            items.push({ label: "Request all seasons", icon: "layers", tag: "all" })
        end if
        if latest > 0 then items.push({ label: "Latest season", sub: "Season " + latest.toStr(), icon: "latest", tag: "s" + latest.toStr() })
        items.push({ label: "Choose seasons…", icon: "list", tag: "choose" })
    else
        items.push({ label: "Request", icon: "plus", tag: "movie" })
    end if
end sub

sub showPopup(model as object)
    closePopup()
    p = m.popupHolder.createChild("ReqPopup")
    p.model = model
    p.observeField("picked", "onPicked")
    m.popup = p
    m.zoneBeforePopup = m.zone
    m.zone = "popup"
end sub

sub closePopup()
    if m.popup <> invalid
        m.popupHolder.removeChild(m.popup)
        m.popup = invalid
        m.zone = m.zoneBeforePopup
        refreshFocus()
    end if
end sub

sub onPicked()
    a = m.popup.picked
    c = m.popCard
    d = c.data
    if a = "toggle"
        n = m.popup.callFunc("checked", invalid).count()
        label = "Request " + n.toStr() + " season"
        if n <> 1 then label = label + "s"
        m.popup.callFunc("setLabel", { tag: "send", label: label })
        return
    end if
    if a = "send"
        nums = []
        for each t in m.popup.callFunc("checked", invalid)
            nums.push(Mid(t, 2).toInt())
        end for
        if nums.count() = 0 then return
        closePopup()
        startRequest(c, nums)
        return
    end if
    closePopup()
    if a = "movie"
        startRequest(c, invalid)
    else if a = "all"
        startRequest(c, "all")
    else if Left(a, 1) = "s"
        startRequest(c, [Mid(a, 2).toInt()])
    else if a = "choose"
        chooseSeasons(c)
    else if a = "cancel"
        oApi("DELETE", "/api/v1/request/" + d.requestId.toStr(), invalid, invalid, "onCancelled", d.title)
    else if a = "like"
        moreLike(d)
    else if a = "plex"
        openInPlex(d)
    end if
end sub

sub chooseSeasons(c as object)
    d = c.data
    x = m.details["tv" + d.id.toStr()]
    if x = invalid then return
    items = []
    for each s in rqSeasons(x)
        locked = (s.tag <> "")
        items.push({ label: s.label, sub: s.sub, check: locked, locked: locked, right: s.tag, tag: "s" + s.number.toStr() })
    end for
    items.push({ label: "Request 0 seasons", icon: "plus", tag: "send" })
    items.push({ label: "Cancel", icon: "close", tag: "back" })
    m.popCard = c
    showPopup({ eyebrow: "CHOOSE SEASONS", rating: "", title: d.title, overview: "", poster: rqImage(d.poster, "w342"), items: items, hints: [{ icon: "back", text: "Back to close" }] })
end sub

' ================================================================ request with undo

' seasons: invalid for a movie, "all", or an array of season numbers
sub startRequest(c as object, seasons as dynamic)
    if m.pending <> invalid then sendPending()
    d = c.data
    body = { mediaType: d.mediaType, mediaId: d.id }
    if seasons <> invalid then body.seasons = seasons
    m.pending = { body: body, card: c, list: currentList().key, index: m.gridIndex, left: 3 }
    setChip(c, rqChip("Requested", "clock", "gold"))
    showUndo()
    m.top.findNode("undoTimer").control = "start"
end sub

sub showUndo()
    p = m.pending
    m.top.findNode("toastIcon").uri = "pkg:/images/requests/back.png"
    m.toastText.text = "Requesting " + p.card.data.title + " · " + p.left.toStr()
    m.toastHint.text = "Back to undo"
    layoutToast()
    m.top.findNode("toastTimer").control = "stop"
end sub

sub onUndoTick()
    if m.pending = invalid then return
    m.pending.left = m.pending.left - 1
    if m.pending.left <= 0 then sendPending() else showUndo()
end sub

sub sendPending()
    p = m.pending
    m.pending = invalid
    m.top.findNode("undoTimer").control = "stop"
    oApi("POST", "/api/v1/request", invalid, rqRequestJson(p.body), "onRequested", p.card.data.title)
    m.toast.visible = false
end sub

sub undoPending()
    p = m.pending
    m.pending = invalid
    m.top.findNode("undoTimer").control = "stop"
    setChip(p.card, p.card.chip)
    flash("close", "Not requested: " + p.card.data.title, "")
end sub

sub onRequested(event as object)
    t = taskFrom(event)
    if t.ok
        flash("check", "Requested " + t.tag, "")
        loadMine()
        return
    end if
    why = ""
    if t.response <> invalid and t.response.message <> invalid then why = t.response.message
    if why = "" then why = "Overseerr said error " + t.status.toStr()
    flash("warn", "Couldn't request " + t.tag, why)
end sub

sub onCancelled(event as object)
    t = taskFrom(event)
    if t.ok then flash("check", "Cancelled " + t.tag, "") else flash("warn", "Couldn't cancel " + t.tag, "error " + t.status.toStr())
    loadMine()
end sub

' Redraw one card's chip wherever it is on screen (the card data itself keeps its old chip for undo)
sub setChip(c as object, chip as object)
    for i = 0 to m.grid.getChildCount() - 1
        n = m.grid.getChild(i)
        cc = n.card
        if cc <> invalid and cc.data <> invalid and cc.data.id = c.data.id and cc.data.mediaType = c.data.mediaType
            cc.chip = chip
            n.card = cc
        end if
    end for
end sub

' ================================================================ more like this, Plex

sub moreLike(d as object)
    oApi("GET", "/api/v1/" + d.mediaType + "/" + d.id.toStr() + "/recommendations", { page: "1" }, invalid, "onLike", d.title)
end sub

sub onLike(event as object)
    t = taskFrom(event)
    if checkProblem(t) then return
    cards = []
    if t.ok and t.response.results <> invalid
        for each r in t.response.results
            if r.mediaType = invalid then r.mediaType = "movie"
            cards.push(rqMediaCard(r))
        end for
    end if
    if cards.count() = 0
        flash("warn", "Overseerr has nothing like " + t.tag, "")
        return
    end if
    entry = { key: "like", icon: "spark", name: "Like " + t.tag, about: "MORE LIKE " + UCase(t.tag) }
    if m.lists[1].key = "like" then m.lists[1] = entry else m.lists = insertAt(m.lists, 1, entry)
    m.cards["like"] = cards
    m.ver = m.ver + 1
    buildRail()
    m.railIndex = 1
    m.gridIndex = 0
    m.zone = "grid"
    refreshFocus()
end sub

function insertAt(list as object, at as integer, item as object) as object
    out = []
    for i = 0 to list.count() - 1
        if i = at then out.push(item)
        out.push(list[i])
    end for
    return out
end function

sub openInPlex(d as object)
    m.plexWant = d
    hPlex("search", { query: d.title, limit: 20 }, "onPlexFound", d.title)
end sub

sub onPlexFound(event as object)
    t = hTaskFrom(event)
    d = m.plexWant
    if d = invalid then return
    want = "Movie"
    if d.mediaType = "tv" then want = "Series"
    best = invalid
    if t.ok and t.response.Items <> invalid
        for each it in t.response.Items
            if it.Type = want
                y = ""
                if it.ProductionYear <> invalid then y = it.ProductionYear.toStr()
                if best = invalid or y = d.year then best = it
                if y = d.year then exit for
            end if
        end for
    end if
    if best = invalid
        flash("warn", "Couldn't find " + d.title + " in Plex yet", "Plex may still be scanning it")
        return
    end if
    m.top.request = { action: "details", item: best }
end sub

' ================================================================ toast

sub flash(icon as string, text as string, hint as string)
    if m.pending <> invalid then return
    m.top.findNode("toastIcon").uri = "pkg:/images/requests/" + icon + ".png"
    m.toastText.text = text
    m.toastHint.text = hint
    layoutToast()
    m.top.findNode("toastTimer").control = "stop"
    m.top.findNode("toastTimer").control = "start"
end sub

sub layoutToast()
    w = m.toastText.boundingRect().width
    m.toastHint.translation = [72 + w + 20, 0]
    hw = 0
    if m.toastHint.text <> "" then hw = m.toastHint.boundingRect().width + 20
    m.top.findNode("toastBg").width = 72 + w + hw + 30
    m.toast.visible = true
end sub

sub onToastDone()
    if m.pending = invalid then m.toast.visible = false
end sub

' ================================================================ setup (no key yet)

sub showSetup(problem as string)
    m.loaded = false
    m.cards = {}
    m.top.findNode("main").visible = false
    ip = "<TV IP>"
    addrs = CreateObject("roDeviceInfo").GetIPAddrs()
    for each k in addrs
        ip = addrs[k]
    end for
    q = Chr(34)
    lines = []
    if problem <> "" then lines.push(problem) else lines.push("Hearth needs your Overseerr API key, once. It stays on this TV.")
    lines.push("")
    lines.push("Find it in Overseerr under Settings, General, API Key. With this screen open, run this in Terminal on your Mac:")
    lines.push("")
    lines.push("curl -X POST -G --data-urlencode " + q + "overseerrKey=YOUR-KEY" + q + " http://" + ip + ":8060/input")
    lines.push("")
    lines.push("Or type it on the keyboard here (the phone remote can paste it), then choose Save key.")
    m.setupText.text = lines.join(Chr(10))
    m.setup.visible = true
    if m.zone <> "save" then m.zone = "setup"
end sub

sub saveTypedKey()
    k = m.keyKb.text
    if k = invalid then return
    k = k.Trim()
    if k = "" then return
    m.reg.Write("overseerrKey", k)
    m.reg.Flush()
    m.zone = "rail"
    m.global.overseerrKey = k
end sub

' ================================================================ focus and keys

sub focusIn(unused as dynamic)
    m.focused = true
    m.top.setFocus(true)
    refreshFocus()
end sub

sub refreshFocus()
    if m.setup.visible
        m.keyKb.active = (m.focused and m.zone = "setup")
        m.saveKey.focused = (m.focused and m.zone = "save")
        return
    end if
    m.kb.active = (m.focused and m.zone = "kb")
    paintRail()
    showList()
    if m.zone = "grid" then paintGrid()
    if m.zone = "rail" then paintGrid()
end sub

sub toPills()
    m.focused = false
    m.zone = "rail"
    refreshFocus()
    m.top.request = { action: "pills" }
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
    if m.pending <> invalid and key = "back"
        undoPending()
        return true
    end if
    z = m.zone
    if z = "popup"
        m.popup.callFunc("handleKey", key)
        return true
    end if
    if z = "setup"
        edge = m.keyKb.callFunc("handleKey", key)
        if edge = "up" or edge = "back"
            toPills()
        else if edge = "down"
            m.zone = "save"
            refreshFocus()
        end if
        return true
    end if
    if z = "save"
        if key = "OK"
            saveTypedKey()
        else if key = "up"
            m.zone = "setup"
            refreshFocus()
        else if key = "back"
            toPills()
        end if
        return true
    end if
    if z = "rail" then return railKey(key)
    if z = "grid" then return gridKey(key)
    if z = "kb"
        edge = m.kb.callFunc("handleKey", key)
        if edge = "left" or edge = "back"
            m.zone = "rail"
            refreshFocus()
        else if edge = "up"
            toPills()
        else if edge = "right"
            r = m.cards["search"]
            if r <> invalid and r.count() > 0
                m.zone = "results"
                paintResults()
                m.kb.active = false
            end if
        end if
        return true
    end if
    if z = "results"
        r = m.cards["search"]
        if Left(key, 4) = "Lit_" or key = "backspace"
            m.kb.callFunc("handleKey", key)
            return true
        end if
        if key = "up" and m.resIndex > 0
            m.resIndex = m.resIndex - 1
        else if key = "down" and r <> invalid and m.resIndex < r.count() - 1
            m.resIndex = m.resIndex + 1
        else if key = "left" or key = "back" or key = "up"
            m.zone = "kb"
            m.kb.active = true
        else if key = "OK" or key = "options"
            openCard(currentResult())
        end if
        paintResults()
        return true
    end if
    return true
end function

function railKey(key as string) as boolean
    n = m.lists.count()
    if key = "up"
        if m.railIndex = 0
            toPills()
            return true
        end if
        m.railIndex = m.railIndex - 1
        m.gridIndex = 0
    else if key = "down"
        if m.railIndex < n - 1
            m.railIndex = m.railIndex + 1
            m.gridIndex = 0
        end if
    else if key = "back"
        toPills()
        return true
    else if key = "right" or key = "OK"
        k = currentList().key
        if k = "search"
            m.zone = "kb"
        else if k = "music"
            if key = "OK" then m.top.request = { action: "musicView", mode: "request" }
            return true
        else if m.cards[k] <> invalid and m.cards[k].count() > 0
            m.zone = "grid"
        end if
    else
        return true
    end if
    refreshFocus()
    return true
end function

function gridKey(key as string) as boolean
    cards = m.cards[currentList().key]
    n = 0
    if cards <> invalid then n = cards.count()
    i = m.gridIndex
    col = i mod m.cols
    if key = "left"
        if col = 0
            m.zone = "rail"
            refreshFocus()
            return true
        end if
        m.gridIndex = i - 1
    else if key = "right"
        if col < m.cols - 1 and i + 1 < n then m.gridIndex = i + 1
    else if key = "up"
        if i < m.cols
            toPills()
            return true
        end if
        m.gridIndex = i - m.cols
    else if key = "down"
        if i + m.cols < n
            m.gridIndex = i + m.cols
        else if Int(i / m.cols) < Int((n - 1) / m.cols)
            m.gridIndex = n - 1
        end if
    else if key = "back"
        m.zone = "rail"
        refreshFocus()
        return true
    else if key = "OK" or key = "options"
        openCard(currentCard())
        return true
    end if
    paintGrid()
    return true
end function
