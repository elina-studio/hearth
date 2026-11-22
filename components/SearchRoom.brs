' Search room. Left: the Hearth keyboard (suggests titles, dims dead keys). Right: matches from
' Plex /hubs/search (movies, shows, episodes, artists, albums, songs),
' updating as you type. Right from the grid's last column jumps to the results.

sub init()
    m.top.findNode("eyebrow").font = hFont("caps", 28)
    m.kb = m.top.findNode("kb")
    m.kb.observeField("text", "onKbText")
    m.resultsLabel = m.top.findNode("resultsLabel")
    m.resultsLabel.font = hFont("caps", 28)
    m.hint = m.top.findNode("hint")
    m.hint.font = hFont("regular", 30)
    m.viewport = m.top.findNode("viewport")
    m.viewport.clippingRect = [-14, -14, 1092, 804]
    m.list = m.top.findNode("list")
    m.debounce = m.top.findNode("debounce")
    m.debounce.observeField("fire", "runSearch")

    m.rowPitch = 142
    m.visibleRows = 5
    m.idleHint = "Type a few letters. Movies, shows and music show up here as you go, and the keyboard suggests titles from your library."

    m.query = ""
    m.results = []
    m.sel = 0
    m.first = 0
    m.zone = "kb"
    m.active = false
    m.seq = 0
    m.pending = 0

    m.hint.text = m.idleHint
    loadVocabulary()
    paint()
end sub

' Every movie, show and artist name from Plex, so the keyboard can suggest titles and dim keys.
' Needs the library ids, so it runs (once) when the hub has loaded them and calls refresh.
sub loadVocabulary()
    if m.vocabStarted = true then return
    libs = m.global.libraries
    if libs = invalid then return
    sections = []
    for each kind in ["movies", "tvshows", "music"]
        if libs[kind] <> invalid then sections.push(libs[kind])
    end for
    if sections.count() = 0 then return
    m.vocabStarted = true
    m.vocabParts = []
    m.vocabPending = sections.count()
    for each id in sections
        hPlex("list", { section: id, limit: 5000 }, "onVocabulary")
    end for
end sub

sub onVocabulary(event as object)
    t = hTaskFrom(event)
    m.vocabPending = m.vocabPending - 1
    if t.ok and t.response <> invalid and t.response.Items <> invalid
        for each it in t.response.Items
            if it.Name <> invalid then m.vocabParts.push(it.Name)
        end for
    end if
    if m.vocabPending = 0
        m.kb.words = m.vocabParts
        m.vocabParts = invalid
    end if
end sub

sub onKbText()
    m.query = m.kb.text
    m.debounce.control = "stop"
    m.debounce.control = "start"
end sub

' ---------- searching ----------

sub runSearch()
    term = m.query.Trim()
    m.seq = m.seq + 1
    if term = ""
        m.pending = 0
        setResults([])
        m.resultsLabel.text = ""
        m.hint.text = m.idleHint
        return
    end if
    m.term = term
    if m.results.count() = 0 then m.hint.text = "Looking..."
    hPlex("search", { query: term, limit: 20 }, "onFound", m.seq.toStr())
end sub

sub onFound(event as object)
    t = hTaskFrom(event)
    if t.tag <> m.seq.toStr() then return ' an older search finished late
    m.found = []
    failed = not t.ok
    if t.response <> invalid and t.response.Items <> invalid then m.found = t.response.Items

    ' titles that start with what you typed come first, then movies and shows, music, songs, episodes
    q = LCase(m.term)
    ranks = { Movie: 0, Series: 0, artist: 1, album: 1, track: 2, Episode: 3 }
    keyed = []
    i = 0
    for each it in m.found
        name = ""
        if it.Name <> invalid then name = LCase(it.Name)
        if Left(name, 4) = "the " and Left(q, 4) <> "the " then name = Mid(name, 5)
        prefix = 1
        if Left(name, Len(q)) = q then prefix = 0
        rank = ranks[it.Type]
        if rank = invalid then rank = 4
        keyed.push({ item: it, key: (prefix * 10 + rank) * 1000 + i })
        i = i + 1
    end for
    keyed.SortBy("key")
    list = []
    for each k in keyed
        if list.count() < 40 then list.push(k.item)
    end for
    matches = list.count()
    ' last row: hand the term to the Requests room (Overseerr)
    if not failed then list.push({ Type: "HearthRequest", Name: "Ask for " + Chr(34) + m.term + Chr(34) })
    setResults(list)

    m.hint.text = ""
    if matches > 0
        if matches = 1 then m.resultsLabel.text = "1 MATCH" else m.resultsLabel.text = matches.toStr() + " MATCHES"
    else if failed
        m.resultsLabel.text = ""
        m.hint.text = "Couldn't reach Plex. Check that the server is on, then type again."
    else
        m.resultsLabel.text = "NOTHING IN YOUR LIBRARY YET"
    end if
end sub

' ---------- results list ----------

sub setResults(items as object)
    m.list.removeChildrenIndex(m.list.getChildCount(), 0)
    m.results = items
    m.sel = 0
    m.first = 0
    y = 0
    for each it in items
        makeRow(it, y)
        y = y + m.rowPitch
    end for
    if items.count() = 0 and m.zone = "results" then m.zone = "kb"
    paint()
end sub

sub makeRow(it as object, y as integer)
    g = m.list.createChild("Group")
    g.translation = [0, y]
    bg = g.createChild("Poster")
    bg.uri = "pkg:/images/tile.9.png"
    bg.blendColor = "0x141A11FF"
    bg.width = 1064
    bg.height = 128

    art = artFor(it)
    boxW = 192
    imgW = boxW
    if art.square then imgW = 108
    frame = g.createChild("Rectangle")
    frame.color = "0x1D2418FF"
    frame.width = imgW
    frame.height = 108
    frame.translation = [12 + (boxW - imgW) / 2, 10]
    if art.uri <> ""
        p = g.createChild("Poster")
        p.width = imgW
        p.height = 108
        p.translation = frame.translation
        p.loadDisplayMode = "scaleToZoom"
        p.uri = art.uri
    else
        letter = g.createChild("Label")
        letter.width = imgW
        letter.height = 108
        letter.translation = frame.translation
        letter.horizAlign = "center"
        letter.vertAlign = "center"
        letter.font = hFont("caps", 48)
        letter.color = "0xB5AF8CFF"
        letter.text = UCase(Left(rowTitle(it), 1))
        if it.Type = "HearthRequest"
            letter.text = "+"
            letter.color = "0xE0B34AFF"
        end if
    end if

    title = g.createChild("Label")
    title.translation = [228, 20]
    title.width = 812
    title.font = hFont("bold", 32)
    title.color = "0xEDE6CAFF"
    title.text = rowTitle(it)
    sub2 = g.createChild("Label")
    sub2.translation = [228, 68]
    sub2.width = 812
    sub2.font = hFont("regular", 24)
    sub2.color = "0xB5AF8CFF"
    sub2.text = rowSubtitle(it)

    ring = g.createChild("Poster")
    ring.uri = "pkg:/images/ring.9.png"
    ring.blendColor = "0xE0B34AFF"
    ring.translation = [-10, -10]
    ring.width = 1084
    ring.height = 148
    ring.visible = false
end sub

function rowTitle(it as object) as string
    if it.Name = invalid then return ""
    return it.Name
end function

function rowSubtitle(it as object) as string
    parts = []
    t = it.Type
    if t = "Movie"
        parts.push("Movie")
        if it.ProductionYear <> invalid then parts.push(it.ProductionYear.toStr())
    else if t = "Series"
        parts.push("Show")
        if it.ProductionYear <> invalid then parts.push(it.ProductionYear.toStr())
    else if t = "Episode"
        parts.push("Episode")
        if it.SeriesName <> invalid then parts.push(it.SeriesName)
        parts.push("S" + hNum(it.ParentIndexNumber) + " E" + hNum(it.IndexNumber))
    else if t = "album"
        parts.push("Album")
        if it.ArtistName <> invalid and it.ArtistName <> "" then parts.push(it.ArtistName)
        if it.ProductionYear <> invalid then parts.push(it.ProductionYear.toStr())
    else if t = "artist"
        parts.push("Artist")
    else if t = "track"
        parts.push("Song")
        if it.ArtistName <> invalid and it.ArtistName <> "" then parts.push(it.ArtistName)
    else if t = "HearthRequest"
        parts.push("Search Overseerr and request it")
    else
        parts.push(t)
    end if
    return parts.join("  ·  ")
end function

function artFor(it as object) as object
    t = it.Type
    if t = "HearthRequest" then return { uri: "", square: false }
    if t = "Movie" or t = "Series"
        return { uri: hImageAny(it, ["Thumb", "Backdrop", "Primary"], 400), square: false }
    else if t = "Episode"
        return { uri: hImageAny(it, ["Thumb", "Backdrop", "Primary"], 400), square: false }
    end if
    uri = ""
    if it._img <> invalid and it._img.Primary <> invalid and it._img.Primary <> "" then uri = hPlexImage(it._img.Primary, 240, "Thumb")
    return { uri: uri, square: true }
end function

function isMusic(it as object) as boolean
    return it.Type = "album" or it.Type = "artist" or it.Type = "track"
end function

sub openResult()
    if m.sel >= m.results.count() then return
    it = m.results[m.sel]
    if it.Type = "HearthRequest"
        m.top.request = { action: "room", name: "Requests", search: m.term }
    else if isMusic(it)
        ' the Music room plays from Plex, by kind, title and artist
        r = { action: "playMusic", kind: it.Type, title: rowTitle(it), artist: "" }
        if it.ArtistName <> invalid then r.artist = it.ArtistName
        if it.Type = "artist" then r.artist = rowTitle(it)
        m.top.request = r
    else
        m.top.request = { action: "details", item: it }
    end if
end sub

' ---------- focus and painting ----------

sub paint()
    m.kb.active = (m.active and m.zone = "kb")
    n = m.list.getChildCount()
    for i = 0 to n - 1
        g = m.list.getChild(i)
        g.getChild(g.getChildCount() - 1).visible = (m.active and m.zone = "results" and i = m.sel)
    end for
    ' keep the focused result on screen
    if m.sel < m.first then m.first = m.sel
    if m.sel > m.first + m.visibleRows - 1 then m.first = m.sel - m.visibleRows + 1
    m.list.translation = [0, -m.first * m.rowPitch]
end sub

sub focusIn(unused as dynamic)
    m.active = true
    if m.zone = "results" and m.results.count() = 0 then m.zone = "kb"
    m.top.setFocus(true)
    paint()
end sub

sub refresh(unused as dynamic)
    loadVocabulary()
end sub

sub toPills()
    m.active = false
    paint()
    m.top.request = { action: "pills" }
end sub

sub restoreFocus()
    m.top.setFocus(true)
end sub

sub afterOptions()
    runSearch()
end sub

sub onOptions()
    hOptionsChosen()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false

    if m.zone = "kb"
        edge = m.kb.callFunc("handleKey", key)
        if edge = "up" or edge = "back"
            toPills()
        else if edge = "right"
            if m.results.count() > 0
                m.zone = "results"
                paint()
            end if
        end if
        return true
    end if

    ' results; typing from the phone app still goes to the keyboard
    if Left(key, 4) = "Lit_" or key = "backspace"
        m.kb.callFunc("handleKey", key)
        return true
    end if
    if key = "up"
        if m.sel > 0 then m.sel = m.sel - 1 else m.zone = "kb"
    else if key = "down"
        if m.sel < m.results.count() - 1 then m.sel = m.sel + 1
    else if key = "left" or key = "back"
        m.zone = "kb"
    else if key = "OK"
        openResult()
    else if key = "options"
        it = m.results[m.sel]
        if not isMusic(it) and it.Type <> "HearthRequest" then hOptions(it)
    end if
    paint()
    return true
end function
