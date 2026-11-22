' Search room. Left: a letter grid you drive with the arrows. Right: matches from
' Jellyfin (movies, shows, music, and episodes once you've typed 3 letters),
' updating as you type. Right from the grid's last column jumps to the results.

sub init()
    m.top.findNode("eyebrow").font = hFont("caps", 28)
    m.queryLabel = m.top.findNode("query")
    m.queryLabel.font = hFont("bold", 48)
    m.resultsLabel = m.top.findNode("resultsLabel")
    m.resultsLabel.font = hFont("caps", 28)
    m.hint = m.top.findNode("hint")
    m.hint.font = hFont("regular", 30)
    m.viewport = m.top.findNode("viewport")
    m.viewport.clippingRect = [-14, -14, 1092, 804]
    m.list = m.top.findNode("list")
    m.debounce = m.top.findNode("debounce")
    m.debounce.observeField("fire", "runSearch")

    m.keyW = 84
    m.keyH = 70
    m.keyGap = 10
    m.rowPitch = 142
    m.visibleRows = 5
    m.idleHint = "Type a few letters. Movies, shows and music show up here as you go."

    m.query = ""
    m.results = []
    m.sel = 0
    m.first = 0
    m.zone = "kb"
    m.active = false
    m.r = 0
    m.c = 0
    m.seq = 0
    m.pending = 0

    buildKeys()
    showQuery()
    m.hint.text = m.idleHint
    paint()
end sub

' ---------- the letter grid ----------

sub buildKeys()
    letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"
    keys = m.top.findNode("keys")
    m.keyNodes = []
    for r = 0 to 5
        row = []
        for c = 0 to 5
            ch = Mid(letters, r * 6 + c + 1, 1)
            row.push(makeKey(keys, c * (m.keyW + m.keyGap), r * (m.keyH + m.keyGap), m.keyW, m.keyH, ch, 34))
        end for
        m.keyNodes.push(row)
    end for
    ' bottom row: three wide keys, each two columns wide
    m.wideLabels = ["Space", "Delete", "Clear"]
    m.wideNodes = []
    wideW = m.keyW * 2 + m.keyGap
    for k = 0 to 2
        m.wideNodes.push(makeKey(keys, k * (wideW + m.keyGap), 6 * (m.keyH + m.keyGap), wideW, m.keyH, m.wideLabels[k], 28))
    end for
end sub

function makeKey(parent as object, x as integer, y as integer, w as integer, h as integer, text as string, size as integer) as object
    g = parent.createChild("Group")
    g.translation = [x, y]
    base = g.createChild("Poster")
    base.uri = "pkg:/images/tile.9.png"
    base.width = w
    base.height = h
    lab = g.createChild("Label")
    lab.width = w
    lab.height = h
    lab.horizAlign = "center"
    lab.vertAlign = "center"
    lab.font = hFont("bold", size)
    lab.text = text
    return g
end function

sub paintKey(g as object, focused as boolean)
    base = g.getChild(0)
    lab = g.getChild(1)
    if focused
        base.blendColor = "0xE0B34AFF"
        lab.color = "0x1F1606FF"
    else
        base.blendColor = "0x1D2418FF"
        lab.color = "0xEDE6CAFF"
    end if
end sub

sub pressKey()
    if m.r < 6
        typeText(LCase(Mid("ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890", m.r * 6 + m.c + 1, 1)))
        return
    end if
    k = m.c \ 2
    if k = 0
        if m.query <> "" and Right(m.query, 1) <> " " then typeText(" ")
    else if k = 1
        deleteLetter()
    else
        m.query = ""
        queryChanged()
    end if
end sub

sub typeText(s as string)
    if Len(m.query) >= 40 then return
    m.query = m.query + s
    queryChanged()
end sub

sub deleteLetter()
    if m.query = "" then return
    m.query = Left(m.query, Len(m.query) - 1)
    queryChanged()
end sub

sub queryChanged()
    showQuery()
    m.debounce.control = "stop"
    m.debounce.control = "start"
end sub

sub showQuery()
    if m.query = ""
        m.queryLabel.text = "_"
        m.queryLabel.color = "0xE0B34AFF"
        return
    end if
    shown = m.query
    if Len(shown) > 18 then shown = "..." + Right(shown, 17)
    m.queryLabel.text = shown + "_"
    m.queryLabel.color = "0xE0B34AFF"
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
    m.found = []
    m.failures = 0
    m.pending = 2
    if m.results.count() = 0 then m.hint.text = "Looking..."
    tag = m.seq.toStr()
    types = "Movie,Series,MusicAlbum,Audio"
    if Len(term) >= 3 then types = types + ",Episode"
    hApi("GET", "/Items", { userId: hUser(), searchTerm: term, Recursive: "true", IncludeItemTypes: types, Limit: 40, Fields: hFields(), EnableImageTypes: "Primary,Backdrop,Thumb", ImageTypeLimit: 1 }, invalid, "onFound", tag)
    hApi("GET", "/Artists", { userId: hUser(), searchTerm: term, Limit: 10, Fields: hFields(), EnableImageTypes: "Primary", ImageTypeLimit: 1 }, invalid, "onFound", tag)
end sub

sub onFound(event as object)
    t = hTaskFrom(event)
    if t.tag <> m.seq.toStr() then return ' an older search finished late
    m.pending = m.pending - 1
    if t.ok and t.response <> invalid and t.response.Items <> invalid
        for each it in t.response.Items
            m.found.push(it)
        end for
    else
        m.failures = m.failures + 1
    end if
    if m.pending > 0 then return

    ' titles that start with what you typed come first, then movies and shows, music, songs, episodes
    q = LCase(m.term)
    ranks = { Movie: 0, Series: 0, MusicArtist: 1, MusicAlbum: 1, Audio: 2, Episode: 3 }
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
    setResults(list)

    if list.count() > 0
        if list.count() = 1 then m.resultsLabel.text = "1 MATCH" else m.resultsLabel.text = list.count().toStr() + " MATCHES"
        m.hint.text = ""
    else if m.failures >= 2
        m.resultsLabel.text = ""
        m.hint.text = "Couldn't reach Jellyfin. Check that the NAS is on, then type again."
    else
        m.resultsLabel.text = ""
        m.hint.text = "Nothing in your library matches " + Chr(34) + m.term + Chr(34) + "."
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
    else if t = "MusicAlbum"
        parts.push("Album")
        if it.AlbumArtist <> invalid and it.AlbumArtist <> "" then parts.push(it.AlbumArtist)
        if it.ProductionYear <> invalid then parts.push(it.ProductionYear.toStr())
    else if t = "MusicArtist"
        parts.push("Artist")
    else if t = "Audio"
        parts.push("Song")
        artist = it.AlbumArtist
        if it.Artists <> invalid and it.Artists.count() > 0 then artist = it.Artists[0]
        if artist <> invalid and artist <> "" then parts.push(artist)
        if it.Album <> invalid and it.Album <> "" then parts.push(it.Album)
    else
        parts.push(t)
    end if
    return parts.join("  ·  ")
end function

function artFor(it as object) as object
    t = it.Type
    if t = "Movie" or t = "Series"
        return { uri: hImageAny(it, ["Thumb", "Backdrop", "Primary"], 400), square: false }
    else if t = "Episode"
        return { uri: hImageAny(it, ["Primary", "Thumb", "Backdrop"], 400), square: false }
    end if
    uri = hImage(it, "Primary", 240)
    if uri = "" and it.AlbumId <> invalid and it.AlbumPrimaryImageTag <> invalid
        uri = m.global.server + "/Items/" + it.AlbumId + "/Images/Primary?maxWidth=240&quality=90&tag=" + it.AlbumPrimaryImageTag
    end if
    return { uri: uri, square: true }
end function

function isMusic(it as object) as boolean
    return it.Type = "MusicAlbum" or it.Type = "MusicArtist" or it.Type = "Audio"
end function

sub openResult()
    if m.sel >= m.results.count() then return
    it = m.results[m.sel]
    if isMusic(it)
        hMessage("Music is on its way", "Search can find songs, albums and artists, but they'll open once the Music room is built.")
    else
        m.top.request = { action: "details", item: it }
    end if
end sub

' ---------- focus and painting ----------

sub paint()
    for r = 0 to 5
        for c = 0 to 5
            paintKey(m.keyNodes[r][c], m.active and m.zone = "kb" and m.r = r and m.c = c)
        end for
    end for
    for k = 0 to 2
        paintKey(m.wideNodes[k], m.active and m.zone = "kb" and m.r = 6 and (m.c \ 2) = k)
    end for

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

    ' typing from the Roku phone app's keyboard
    if Left(key, 4) = "Lit_"
        typeText(LCase(Mid(key, 5)))
        return true
    else if key = "backspace"
        deleteLetter()
        return true
    end if

    if m.zone = "kb"
        if key = "up"
            if m.r = 0
                toPills()
                return true
            end if
            m.r = m.r - 1
        else if key = "down"
            if m.r < 6 then m.r = m.r + 1
        else if key = "left"
            if m.r = 6
                if m.c \ 2 > 0 then m.c = (m.c \ 2 - 1) * 2
            else if m.c > 0
                m.c = m.c - 1
            end if
        else if key = "right"
            atEdge = (m.c = 5)
            if m.r = 6 then atEdge = (m.c \ 2 = 2)
            if atEdge
                if m.results.count() > 0 then m.zone = "results"
            else if m.r = 6
                m.c = (m.c \ 2 + 1) * 2
            else
                m.c = m.c + 1
            end if
        else if key = "OK"
            pressKey()
        else if key = "back"
            toPills()
            return true
        end if
        paint()
        return true
    end if

    ' results
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
        if not isMusic(it) then hOptions(it)
    end if
    paint()
    return true
end function
