' Requests room: a native front end to Overseerr.
' The API key lives only on the TV (registry "hearth" / "overseerrKey"). It arrives from
' the Mac over ECP (/input?overseerrKey=...) via main.brs, or is typed on the setup card.

sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.eyebrow = m.top.findNode("eyebrow")
    m.eyebrow.font = hFont("caps", 28)
    m.title = m.top.findNode("title")
    m.title.font = hFont("caps", 72)
    m.overview = m.top.findNode("overview")
    m.overview.font = hFont("regular", 28)
    m.empty = m.top.findNode("empty")
    m.empty.font = hFont("regular", 30)
    m.setup = m.top.findNode("setup")
    m.setupText = m.top.findNode("setupText")
    m.setupText.font = hFont("regular", 30)
    m.toast = m.top.findNode("toast")
    m.toast.font = hFont("bold", 30)
    m.toastTimer = m.top.findNode("toastTimer")
    m.toastTimer.observeField("fire", "onToastDone")
    m.content = m.top.findNode("content")
    m.scroll = m.top.findNode("scroll")
    m.scrollTo = m.top.findNode("scrollTo")
    m.reg = CreateObject("roRegistrySection", "hearth")

    m.rows = []
    m.row = 0
    m.focused = false
    m.results = {}
    m.loaded = false
    m.query = ""
    m.focusTag = ""
    m.tasks = {}
    m.problem = ""

    if not m.global.hasField("overseerrKey") then m.global.addFields({ overseerrKey: "" })
    m.global.observeField("overseerrKey", "onKeyArrived")
    defaultHero()
    refresh(invalid)
end sub

' ---------------------------------------------------------------- loading

sub refresh(unused as dynamic)
    if apiKey() = ""
        showSetup("")
        return
    end if
    m.setup.visible = false
    if not m.loaded
        m.loaded = true
        m.problem = ""
        m.empty.text = "Asking Overseerr…"
        oApi("GET", "/api/v1/discover/trending", { page: "1" }, invalid, "onList", "Trending")
        oApi("GET", "/api/v1/discover/movies", { page: "1" }, invalid, "onList", "Popular movies")
        oApi("GET", "/api/v1/discover/tv", { page: "1" }, invalid, "onList", "Popular shows")
    end if
    loadRequests()
end sub

sub loadRequests()
    t = CreateObject("roSGNode", "OverseerrTask")
    t.mode = "requests"
    t.tag = "Your requests"
    keep(t, "onRequests")
end sub

sub oApi(method as string, path as string, query as dynamic, body as dynamic, cb as string, tag as string)
    t = CreateObject("roSGNode", "OverseerrTask")
    t.method = method
    t.path = path
    if query <> invalid then t.query = query
    if body <> invalid then t.body = body
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

' Overseerr numbers may be missing; -1 stands for "none"
function num(v as dynamic) as integer
    if v = invalid then return -1
    return v
end function

function apiKey() as string
    k = m.reg.Read("overseerrKey")
    if k = invalid then return ""
    return k
end function

sub onKeyArrived()
    m.loaded = false
    m.results = {}
    refresh(invalid)
    if m.focused then focusIn(invalid)
    flash("Overseerr key saved")
end sub

' Problems that stop the whole room (bad key, Overseerr down) show on the setup card.
function checkProblem(t as object) as boolean
    if t.status = 401 or t.status = 403
        showSetup("Overseerr didn't accept the saved key (error " + t.status.toStr() + "). Send it again with the command below.")
        return true
    end if
    if t.status <= 0 and m.problem = ""
        m.problem = "down"
        m.empty.text = "Can't reach Overseerr at " + baseUrl() + ". Is the container running?"
    end if
    return false
end function

function baseUrl() as string
    u = m.reg.Read("overseerrUrl")
    if u = invalid or u = "" then u = "http://192.168.254.41:5055"
    return u
end function

sub onList(event as object)
    t = taskFrom(event)
    if checkProblem(t) then return
    cards = []
    if t.ok and t.response.results <> invalid
        for each r in t.response.results
            if r.mediaType = "movie" or r.mediaType = "tv" then cards.push(mediaCard(r))
        end for
    end if
    m.results[t.tag] = cards
    build()
end sub

sub onRequests(event as object)
    t = taskFrom(event)
    if checkProblem(t) then return
    cards = [{ kind: "search", title: "Search", chip: "" }]
    if t.ok and t.response.results <> invalid
        for each r in t.response.results
            cards.push(requestCard(r.request, r.info))
        end for
    end if
    m.results["Your requests"] = cards
    build()
end sub

sub onSearch(event as object)
    t = taskFrom(event)
    if checkProblem(t) then return
    cards = []
    if t.ok and t.response.results <> invalid
        for each r in t.response.results
            if r.mediaType = "movie" or r.mediaType = "tv" then cards.push(mediaCard(r))
        end for
    end if
    if cards.count() = 0
        flash("Nothing found for " + Chr(8220) + m.query + Chr(8221))
        return
    end if
    m.results["Results"] = cards
    m.focusTag = "Results"
    build()
end sub

' ---------------------------------------------------------------- cards

function yearOf(r as object) as string
    d = r.releaseDate
    if d = invalid or d = "" then d = r.firstAirDate
    if d = invalid or Len(d) < 4 then return ""
    return Left(d, 4)
end function

function posterUrl(path as dynamic, size as string) as string
    if path = invalid or path = "" then return ""
    return "https://image.tmdb.org/t/p/" + size + path
end function

function mediaCard(r as object) as object
    title = r.title
    if title = invalid then title = r.name
    if title = invalid then title = ""
    status = -1
    if r.mediaInfo <> invalid then status = num(r.mediaInfo.status)
    c = chipFor(status)
    data = { id: r.id, mediaType: r.mediaType, title: title, year: yearOf(r), overview: r.overview, backdrop: r.backdropPath, mediaStatus: status }
    return { kind: "media", title: title, image: posterUrl(r.posterPath, "w300"), chip: c.text, lit: c.lit, data: data }
end function

' Overseerr media status: 1 unknown, 2 pending, 3 processing, 4 partly available, 5 available
function chipFor(status as integer) as object
    if status = 2 then return { text: "Requested", lit: true }
    if status = 3 then return { text: "On the way", lit: true }
    if status = 4 then return { text: "Partly here", lit: true }
    if status = 5 then return { text: "Available", lit: true }
    return { text: "Request", lit: false }
end function

' Request status: 1 waiting for approval, 2 approved, 3 declined
function requestCard(q as object, info as object) as object
    mediaStatus = -1
    if q.media <> invalid then mediaStatus = num(q.media.status)
    rs = num(q.status)
    if rs = 1
        chip = "Waiting"
        note = "Waiting for approval in Overseerr."
    else if rs = 3
        chip = "Declined"
        note = "This request was declined in Overseerr."
    else if mediaStatus = 5
        chip = "Ready"
        note = "Ready to watch. Find it under Movies or Shows."
    else if mediaStatus = 4
        chip = "Partly ready"
        note = "Some of it is ready to watch; the rest is on the way."
    else
        chip = "On the way"
        note = "Approved and downloading."
    end if
    title = info.title
    if title = invalid then title = ""
    data = { id: info.id, mediaType: info.mediaType, title: title, year: yearOf(info), overview: info.overview, backdrop: invalid, mediaStatus: mediaStatus, note: note }
    return { kind: "media", title: title, image: posterUrl(info.posterPath, "w300"), chip: chip, lit: (rs <> 3), data: data }
end function

' ---------------------------------------------------------------- layout

sub build()
    order = ["Results", "Trending", "Your requests", "Popular movies", "Popular shows"]
    keepTag = m.focusTag
    keepIndex = 0
    if keepTag = "" and m.row < m.rows.count()
        keepTag = m.rows[m.row].tag
        keepIndex = m.rows[m.row].index
    end if
    m.content.removeChildrenIndex(m.content.getChildCount(), 0)
    m.rows = []
    y = 0
    for each tag in order
        cards = m.results[tag]
        if cards <> invalid and cards.count() > 0
            r = m.content.createChild("ReqRow")
            r.addFields({ tag: tag })
            r.translation = [96, y]
            if tag = "Results"
                r.title = "Results for " + Chr(8220) + m.query + Chr(8221)
            else
                r.title = tag
            end if
            r.cards = cards
            if tag = keepTag and m.focusTag = "" then r.index = keepIndex
            m.rows.push(r)
            y = y + r.rowHeight + 24
        end if
    end for
    m.row = 0
    for i = 0 to m.rows.count() - 1
        if m.rows[i].tag = keepTag then m.row = i
    end for
    if m.focusTag <> ""
        m.focusTag = ""
        if not m.focused then focusIn(invalid)
    end if
    if m.rows.count() > 0 then m.empty.text = ""
    paint()
end sub

sub paint()
    for i = 0 to m.rows.count() - 1
        m.rows[i].active = (m.focused and i = m.row)
    end for
    y = 0
    if m.row > 0 and m.row < m.rows.count() then y = -m.rows[m.row].translation[1]
    m.scroll.control = "stop"
    m.scrollTo.keyValue = [m.content.translation, [0, y]]
    m.scroll.control = "start"
    showInfo()
end sub

sub defaultHero()
    m.eyebrow.text = "REQUESTS · OVERSEERR"
    m.title.text = "ASK FOR SOMETHING NEW"
    m.overview.text = "Sent to Overseerr. It shows up under Recently added when it's ready."
    m.backdrop.uri = ""
end sub

sub showInfo()
    c = currentCard()
    if c = invalid or not m.focused
        defaultHero()
        return
    end if
    if c.kind = "search"
        m.eyebrow.text = "SEARCH"
        m.title.text = "SEARCH TO REQUEST"
        m.overview.text = "Type a title. Hearth searches Overseerr and you can request it from the results."
        m.backdrop.uri = ""
        return
    end if
    d = c.data
    if d.mediaType = "tv" then e = "SHOW" else e = "MOVIE"
    if d.year <> "" then e = e + " · " + d.year
    m.eyebrow.text = e
    m.title.text = UCase(d.title)
    ov = d.overview
    if ov = invalid then ov = ""
    m.overview.text = ov
    m.backdrop.uri = posterUrl(d.backdrop, "w780")
end sub

function currentCard() as object
    if m.row >= m.rows.count() then return invalid
    return m.rows[m.row].callFunc("current", invalid)
end function

sub focusIn(unused as dynamic)
    m.focused = true
    m.top.setFocus(true)
    if m.setup.visible then return
    paint()
end sub

sub flash(text as string)
    m.toast.text = text
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub onToastDone()
    m.toast.text = ""
end sub

' ---------------------------------------------------------------- setup (no key yet)

sub showSetup(problem as string)
    m.loaded = false
    m.results = {}
    m.content.removeChildrenIndex(m.content.getChildCount(), 0)
    m.rows = []
    m.empty.text = ""
    defaultHero()
    ip = "<TV IP>"
    addrs = CreateObject("roDeviceInfo").GetIPAddrs()
    for each k in addrs
        ip = addrs[k]
    end for
    q = Chr(34)
    lines = []
    if problem <> "" then lines.push(problem) else lines.push("Hearth needs your Overseerr API key, once. It stays on this TV.")
    lines.push("")
    lines.push("Find it in Overseerr under Settings, General, API Key. Then, with this screen open, run this in Terminal on your Mac:")
    lines.push("")
    lines.push("curl -X POST -G --data-urlencode " + q + "overseerrKey=YOUR-KEY" + q + " http://" + ip + ":8060/input")
    lines.push("")
    lines.push("Or press OK to type it with the remote (the Roku phone app's keyboard can paste it).")
    m.setupText.text = lines.join(Chr(10))
    m.setup.visible = true
end sub

sub askKey()
    d = CreateObject("roSGNode", "StandardKeyboardDialog")
    d.title = "Overseerr API key"
    d.message = ["Settings, General, API Key in Overseerr"]
    d.buttons = ["Save", "Cancel"]
    d.observeField("buttonSelected", "onKeyTyped")
    d.observeField("wasClosed", "onDialogClosed")
    m.keyDialog = d
    m.top.getScene().dialog = d
end sub

sub onKeyTyped()
    d = m.keyDialog
    text = d.text
    d.close = true
    if d.buttonSelected <> 0 or text = invalid then return
    text = text.Trim()
    if text = "" then return
    m.reg.Write("overseerrKey", text)
    m.reg.Flush()
    m.global.overseerrKey = text
end sub

' ---------------------------------------------------------------- search and request

sub askSearch()
    d = CreateObject("roSGNode", "StandardKeyboardDialog")
    d.title = "Search Overseerr"
    d.buttons = ["Search", "Cancel"]
    d.text = m.query
    d.observeField("buttonSelected", "onSearchTyped")
    d.observeField("wasClosed", "onDialogClosed")
    m.searchDialog = d
    m.top.getScene().dialog = d
end sub

sub onSearchTerm()
    text = m.top.searchTerm.Trim()
    if text = "" or apiKey() = "" then return
    runSearch(text)
end sub

sub runSearch(text as string)
    m.query = text
    flash("Searching for " + Chr(8220) + text + Chr(8221) + "…")
    oApi("GET", "/api/v1/search", { query: text, page: "1" }, invalid, "onSearch", "Results")
end sub

sub onSearchTyped()
    d = m.searchDialog
    text = d.text
    d.close = true
    if d.buttonSelected <> 0 or text = invalid then return
    text = text.Trim()
    if text = "" then return
    runSearch(text)
end sub

sub openCard(c as object)
    if c.kind = "search"
        askSearch()
        return
    end if
    d = c.data
    m.pick = c
    sub1 = d.title
    if d.year <> "" then sub1 = sub1 + " (" + d.year + ")"
    if d.note <> invalid
        ask(d.title, [d.note], ["OK"], [""])
    else if d.mediaStatus = 5
        ask(d.title, ["Already in your library. Find it under Movies or Shows."], ["OK"], [""])
    else if d.mediaStatus = 2 or d.mediaStatus = 3
        ask(d.title, ["Already requested. It's on the way."], ["OK"], [""])
    else if d.mediaType = "tv"
        msg = "Ask Overseerr for this show."
        if d.mediaStatus = 4 then msg = "Part of this show is already here. Ask for the rest."
        ask(sub1, [msg], ["Request all seasons", "First season only", "Cancel"], ["all", "first", ""])
    else
        ask(sub1, ["Ask Overseerr for this movie."], ["Request", "Cancel"], ["movie", ""])
    end if
end sub

sub ask(title as string, message as object, buttons as object, actions as object)
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = title
    d.message = message
    d.buttons = buttons
    d.observeField("buttonSelected", "onDialogButton")
    d.observeField("wasClosed", "onDialogClosed")
    m.dlg = d
    m.dlgActions = actions
    m.top.getScene().dialog = d
end sub

sub onDialogButton()
    a = m.dlgActions[m.dlg.buttonSelected]
    m.dlg.close = true
    if a = invalid or a = "" then return
    d = m.pick.data
    body = { mediaType: d.mediaType, mediaId: d.id }
    if a = "all" then body.seasons = "all"
    if a = "first" then body.seasons = [1]
    m.requestRow = m.row
    m.requestTitle = d.title
    oApi("POST", "/api/v1/request", invalid, body, "onRequested", "request")
end sub

sub onDialogClosed()
    m.top.setFocus(true)
end sub

sub onRequested(event as object)
    t = taskFrom(event)
    if t.ok
        if m.requestRow < m.rows.count() then m.rows[m.requestRow].callFunc("setChip", { chip: "Requested", lit: true })
        flash("Requested " + m.requestTitle)
        loadRequests()
        return
    end if
    why = ""
    if t.response <> invalid and t.response.message <> invalid then why = t.response.message
    if why = "" then why = "Overseerr answered with error " + t.status.toStr() + "."
    ask("Couldn't request " + m.requestTitle, [why], ["OK"], [""])
end sub

' ---------------------------------------------------------------- keys

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
    if m.setup.visible
        if key = "back" or key = "up"
            m.focused = false
            m.top.request = { action: "pills" }
        else if key = "OK"
            askKey()
        end if
        return true
    end if
    if key = "back" or (key = "up" and m.row = 0)
        m.focused = false
        paint()
        m.top.request = { action: "pills" }
        return true
    end if
    if m.rows.count() = 0 then return true
    current = m.rows[m.row]
    if key = "left" or key = "right"
        if key = "left" then d = -1 else d = 1
        current.callFunc("move", d)
        showInfo()
    else if key = "up"
        m.row = m.row - 1
        paint()
    else if key = "down"
        if m.row < m.rows.count() - 1
            m.row = m.row + 1
            paint()
        end if
    else if key = "OK"
        c = current.callFunc("current", invalid)
        if c <> invalid then openCard(c)
    else if key = "replay"
        m.loaded = false
        refresh(invalid)
        flash("Refreshing…")
    end if
    return true
end function
