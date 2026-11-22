' Search room. Left: the Hearth keyboard (suggests titles, dims dead keys). Right: matches from
' Plex /hubs/search grouped by kind, updating as you type. With an empty box the right side lists
' recent searches. Right from the keyboard's last column jumps to the list.
' Mockups: /mnt/project-files/hearth/mockups/search/

sub init()
    m.top.findNode("eyebrow").font = hFont("caps", 28)
    m.kb = m.top.findNode("kb")
    m.kb.observeField("text", "onKbText")
    m.resultsLabel = m.top.findNode("resultsLabel")
    m.resultsLabel.font = hFont("caps", 28)
    m.hint = m.top.findNode("hint")
    m.hint.font = hFont("regular", 28)
    m.viewport = m.top.findNode("viewport")
    m.viewHeight = 806
    m.viewport.clippingRect = [-14, -14, 1092, m.viewHeight + 14]
    m.list = m.top.findNode("list")
    m.debounce = m.top.findNode("debounce")
    m.debounce.observeField("fire", "runSearch")

    m.groups = [
        { type: "Movie", head: "MOVIES", icon: "film" },
        { type: "Series", head: "SHOWS", icon: "tv" },
        { type: "Episode", head: "EPISODES", icon: "episode" },
        { type: "artist", head: "ARTISTS", icon: "artist" },
        { type: "album", head: "ALBUMS", icon: "album" },
        { type: "track", head: "SONGS", icon: "song" }
    ]
    m.kindIcons = { Movie: "film", Series: "tv", Episode: "episode", artist: "artist", album: "album", track: "song" }
    m.perGroup = 8
    m.idleHint = "Type a title. Matches appear as you go."

    m.reg = CreateObject("roRegistrySection", "hearth")
    m.recent = loadRecent()
    m.query = ""
    m.term = ""
    m.rows = []
    m.focusable = []
    m.sel = 0
    m.offset = 0
    m.zone = "kb"
    m.active = false
    m.seq = 0

    loadVocabulary()
    showIdle()
end sub

' ---------- keyboard vocabulary ----------

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
        hPlex("titles", { section: id, limit: 5000 }, "onVocabulary")
    end for
end sub

sub onVocabulary(event as object)
    t = hTaskFrom(event)
    m.vocabPending = m.vocabPending - 1
    if t.ok and t.response <> invalid and t.response.Names <> invalid then m.vocabParts.append(t.response.Names)
    if m.vocabPending = 0
        m.kb.words = m.vocabParts
        m.vocabParts = invalid
    end if
end sub

' ---------- recent searches (registry "hearth" / "recentSearches", newest first) ----------

function loadRecent() as object
    raw = m.reg.Read("recentSearches")
    if raw = invalid or raw = "" then return []
    list = ParseJson(raw)
    if type(list) <> "roArray" then return []
    return list
end function

sub rememberSearch(term as string)
    term = term.Trim()
    if term = "" then return
    out = [term]
    for each r in m.recent
        if LCase(r) <> LCase(term) and out.count() < 5 then out.push(r)
    end for
    m.recent = out
    m.reg.Write("recentSearches", FormatJson(out))
    m.reg.Flush()
end sub

' ---------- searching ----------

sub onKbText()
    m.query = m.kb.text
    m.debounce.control = "stop"
    m.debounce.control = "start"
end sub

sub runSearch()
    term = m.query.Trim()
    m.seq = m.seq + 1
    if term = ""
        showIdle()
        return
    end if
    m.term = term
    m.tried = term
    if m.rows.count() = 0 or (m.showingRecent = true and m.zone <> "results")
        clearRows()
        m.resultsLabel.text = ""
        m.hint.text = "Looking" + Chr(8230)
    end if
    hPlex("search", { query: term, limit: 20 }, "onFound", m.seq.toStr())
end sub

sub onFound(event as object)
    t = hTaskFrom(event)
    if t.tag <> m.seq.toStr() then return ' an older search finished late
    found = []
    if t.response <> invalid and t.response.Items <> invalid then found = t.response.Items
    if not t.ok
        clearRows()
        m.resultsLabel.text = ""
        m.hint.text = "Couldn't reach Plex. Check the server is on, then type again."
        return
    end if

    ' nothing? quietly try again without the last letter (a typo is usually the last key pressed)
    if found.count() = 0 and Len(m.tried) >= 3 and m.tried = m.term
        m.tried = Left(m.tried, Len(m.tried) - 1).Trim()
        m.seq = m.seq + 1
        hPlex("search", { query: m.tried, limit: 20 }, "onFound", m.seq.toStr())
        return
    end if

    q = LCase(m.tried)
    rows = []
    count = 0
    if m.tried <> m.term
        ' typo fallback: one flat list under a "showing" heading, with the kind in each subtitle
        m.resultsLabel.text = "NOTHING FOR " + Chr(34) + UCase(m.term) + Chr(34)
        if found.count() > 0
            rows.push({ kind: "head", text: "SHOWING " + Chr(34) + UCase(m.tried) + Chr(34), icon: "search" })
            for each it in ranked(found, q)
                if count < 12
                    rows.push({ kind: "item", item: it, subText: subtitle(it, true) })
                    count = count + 1
                end if
            end for
        end if
    else
        for each g in m.groups
            inGroup = []
            for each it in found
                if it.Type = g.type then inGroup.push(it)
            end for
            if inGroup.count() > 0
                rows.push({ kind: "head", text: g.head, icon: g.icon })
                n = 0
                for each it in ranked(inGroup, q)
                    if n < m.perGroup
                        rows.push({ kind: "item", item: it, subText: subtitle(it, false) })
                        n = n + 1
                    end if
                end for
                count = count + n
            end if
        end for
        if count = 1 then m.resultsLabel.text = "1 MATCH" else m.resultsLabel.text = count.toStr() + " MATCHES"
        if count = 0 then m.resultsLabel.text = "NOTHING FOR " + Chr(34) + UCase(m.term) + Chr(34)
    end if

    ' always end with a way to ask for it
    rows.push({ kind: "head", text: "NOT IN YOUR LIBRARY?", icon: "plus" })
    rows.push({ kind: "request", target: "overseerr", title: "Ask Overseerr for " + Chr(34) + m.term + Chr(34), subText: "Movies and shows" })
    rows.push({ kind: "request", target: "lidarr", title: "Ask Lidarr for " + Chr(34) + m.term + Chr(34), subText: "Music" })
    m.hint.text = ""
    m.showingRecent = false
    setRows(rows)
end sub

' Titles that start with what you typed first (ignoring a leading "The"), otherwise Plex's order.
function ranked(items as object, q as string) as object
    keyed = []
    i = 0
    for each it in items
        name = ""
        if it.Name <> invalid then name = LCase(it.Name)
        if Left(name, 4) = "the " and Left(q, 4) <> "the " then name = Mid(name, 5)
        prefix = 1
        if Left(name, Len(q)) = q then prefix = 0
        keyed.push({ item: it, key: prefix * 1000 + i })
        i = i + 1
    end for
    keyed.SortBy("key")
    out = []
    for each k in keyed
        out.push(k.item)
    end for
    return out
end function

sub showIdle()
    m.seq = m.seq + 1
    m.term = ""
    rows = []
    if m.recent.count() > 0
        m.resultsLabel.text = "RECENT SEARCHES"
        m.hint.text = ""
        for each r in m.recent
            rows.push({ kind: "recent", text: r })
        end for
    else
        m.resultsLabel.text = ""
        m.hint.text = m.idleHint
    end if
    m.showingRecent = true
    setRows(rows)
end sub

' ---------- the list ----------

sub clearRows()
    setRows([])
end sub

sub setRows(rows as object)
    m.list.removeChildrenIndex(m.list.getChildCount(), 0)
    m.rows = rows
    m.focusable = []
    m.sel = 0
    m.offset = 0
    y = 0
    for i = 0 to rows.count() - 1
        r = rows[i]
        if r.kind = "head"
            if i > 0 then y = y + 8
            r.y = y
            r.h = 44
            makeHead(r)
            y = y + 52
        else
            r.y = y
            if r.kind = "recent" then r.h = 64 else r.h = 92
            r.node = makeRow(r)
            m.focusable.push(i)
            y = y + r.h + 10
        end if
    end for
    if m.focusable.count() = 0 and m.zone = "results" then m.zone = "kb"
    paint()
end sub

sub makeHead(r as object)
    g = m.list.createChild("Group")
    g.translation = [0, r.y]
    x = 0
    if r.icon <> invalid
        ic = g.createChild("Poster")
        ic.uri = "pkg:/images/icons/" + r.icon + ".png"
        ic.width = 26
        ic.height = 26
        ic.translation = [0, 9]
        ic.blendColor = "0xB5AF8CFF"
        x = 38
    end if
    lab = g.createChild("Label")
    lab.font = hFont("caps", 24)
    lab.color = "0xB5AF8CFF"
    lab.height = 44
    lab.vertAlign = "center"
    lab.translation = [x, 0]
    lab.text = r.text
    w = x + lab.boundingRect().width
    rule = g.createChild("Rectangle")
    rule.color = "0xD9A06644"
    rule.height = 2
    rule.translation = [w + 16, 21]
    rule.width = 1064 - w - 16
end sub

function makeRow(r as object) as object
    g = m.list.createChild("Group")
    g.translation = [0, r.y]
    bg = g.createChild("Poster")
    bg.uri = "pkg:/images/tile.9.png"
    bg.blendColor = "0x141A11FF"
    bg.width = 1064
    bg.height = r.h

    if r.kind = "recent"
        ic = g.createChild("Poster")
        ic.uri = "pkg:/images/icons/history.png"
        ic.width = 32
        ic.height = 32
        ic.translation = [24, 16]
        ic.blendColor = "0xB5AF8CFF"
        t = g.createChild("Label")
        t.translation = [74, 0]
        t.width = 970
        t.height = r.h
        t.vertAlign = "center"
        t.font = hFont("bold", 30)
        t.color = "0xEDE6CAFF"
        t.text = r.text
    else
        textX = 156
        if r.kind = "request"
            plus = g.createChild("Rectangle")
            plus.color = "0x1D2418FF"
            plus.width = 128
            plus.height = 72
            plus.translation = [10, 10]
            sign = g.createChild("Poster")
            sign.uri = "pkg:/images/icons/plus.png"
            sign.width = 40
            sign.height = 40
            sign.translation = [54, 26]
            sign.blendColor = "0xE0B34AFF"
            title = r.title
        else
            it = r.item
            title = rowTitle(it)
            art = artFor(it)
            w = 128
            if art.square then w = 72
            x = 10 + (128 - w) / 2
            frame = g.createChild("Rectangle")
            frame.color = "0x1D2418FF"
            frame.width = w
            frame.height = 72
            frame.translation = [x, 10]
            if art.uri <> ""
                p = g.createChild("Poster")
                p.width = w
                p.height = 72
                p.translation = [x, 10]
                p.loadDisplayMode = "scaleToZoom"
                p.uri = art.uri
            else
                ' no artwork: the kind's icon instead
                ic = g.createChild("Poster")
                name = m.kindIcons[it.Type]
                if name = invalid then name = "search"
                ic.uri = "pkg:/images/icons/" + name + ".png"
                ic.width = 36
                ic.height = 36
                ic.translation = [x + (w - 36) / 2, 28]
                ic.blendColor = "0xB5AF8CFF"
            end if
        end if
        top = 12
        if r.subText = "" then top = 26
        tl = g.createChild("Label")
        tl.translation = [textX, top]
        tl.width = 1064 - textX - 20
        tl.font = hFont("bold", 30)
        tl.color = "0xEDE6CAFF"
        tl.text = title
        if r.subText <> ""
            sl = g.createChild("Label")
            sl.translation = [textX, top + 42]
            sl.width = 1064 - textX - 20
            sl.font = hFont("regular", 22)
            sl.color = "0xB5AF8CFF"
            sl.text = r.subText
        end if
    end if

    ring = g.createChild("Poster")
    ring.uri = "pkg:/images/ring.9.png"
    ring.blendColor = "0xE0B34AFF"
    ring.translation = [-10, -10]
    ring.width = 1084
    ring.height = r.h + 20
    ring.visible = false
    return ring
end function

function rowTitle(it as object) as string
    if it.Name = invalid then return ""
    return it.Name
end function

' Under a group heading the kind is already said, so `withKind` is only for the flat typo list.
function subtitle(it as object, withKind as boolean) as string
    parts = []
    t = it.Type
    kinds = { Movie: "Movie", Series: "Show", Episode: "Episode", artist: "Artist", album: "Album", track: "Song" }
    if withKind and kinds[t] <> invalid then parts.push(kinds[t])
    if t = "Episode"
        if it.SeriesName <> invalid then parts.push(it.SeriesName)
        parts.push("S" + hNum(it.ParentIndexNumber) + " E" + hNum(it.IndexNumber))
    else if t = "album" or t = "track"
        if it.ArtistName <> invalid and it.ArtistName <> "" then parts.push(it.ArtistName)
        if t = "album" and it.ProductionYear <> invalid then parts.push(it.ProductionYear.toStr())
    else if t = "Movie" or t = "Series"
        if it.ProductionYear <> invalid then parts.push(it.ProductionYear.toStr())
    end if
    return parts.join("  ·  ")
end function

function artFor(it as object) as object
    t = it.Type
    if t = "Movie" or t = "Series" or t = "Episode"
        return { uri: hImageAny(it, ["Thumb", "Backdrop", "Primary"], 256), square: false }
    end if
    uri = ""
    if it._img <> invalid and it._img.Primary <> invalid and it._img.Primary <> "" then uri = hPlexImage(it._img.Primary, 144, "Thumb")
    return { uri: uri, square: true }
end function

sub openRow()
    if m.focusable.count() = 0 then return
    r = m.rows[m.focusable[m.sel]]
    if r.kind = "recent"
        m.kb.text = r.text ' the keyboard's text change runs the search
        return
    end if
    rememberSearch(m.term)
    if r.kind = "request"
        if r.target = "lidarr"
            m.top.request = { action: "musicView", mode: "request", term: m.term }
        else
            m.top.request = { action: "room", name: "Requests", search: m.term }
        end if
        return
    end if
    it = r.item
    if it.Type = "artist"
        m.top.request = { action: "musicView", mode: "artist", artistId: it.Id }
    else if it.Type = "album" and it.ArtistId <> invalid
        m.top.request = { action: "musicView", mode: "artist", artistId: it.ArtistId, albumId: it.Id }
    else if it.Type = "album" or it.Type = "track"
        r2 = { action: "playMusic", kind: it.Type, title: rowTitle(it), artist: "" }
        if it.ArtistName <> invalid then r2.artist = it.ArtistName
        m.top.request = r2
    else
        m.top.request = { action: "details", item: it }
    end if
end sub

' ---------- focus and painting ----------

sub paint()
    m.kb.active = (m.active and m.zone = "kb")
    for i = 0 to m.focusable.count() - 1
        m.rows[m.focusable[i]].node.visible = (m.active and m.zone = "results" and i = m.sel)
    end for
    ' keep the focused row, and its group heading, inside the viewport
    if m.focusable.count() > 0
        idx = m.focusable[m.sel]
        r = m.rows[idx]
        top = r.y
        if idx > 0 and m.rows[idx - 1].kind = "head" then top = m.rows[idx - 1].y
        if m.sel = 0 then top = 0
        if top < m.offset then m.offset = top
        if r.y + r.h > m.offset + m.viewHeight then m.offset = r.y + r.h - m.viewHeight
    end if
    m.list.translation = [0, -m.offset]
end sub

sub focusIn(unused as dynamic)
    m.active = true
    if m.zone = "results" and m.focusable.count() = 0 then m.zone = "kb"
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
            if m.focusable.count() > 0
                m.zone = "results"
                paint()
            end if
        end if
        return true
    end if

    ' list; typing from the phone app still goes to the keyboard
    if Left(key, 4) = "Lit_" or key = "backspace"
        m.kb.callFunc("handleKey", key)
        return true
    end if
    if key = "up"
        if m.sel > 0 then m.sel = m.sel - 1 else m.zone = "kb"
    else if key = "down"
        if m.sel < m.focusable.count() - 1 then m.sel = m.sel + 1
    else if key = "left" or key = "back"
        m.zone = "kb"
    else if key = "OK"
        openRow()
    else if key = "options"
        r = m.rows[m.focusable[m.sel]]
        if r.kind = "item" and (r.item.Type = "Movie" or r.item.Type = "Series" or r.item.Type = "Episode") then hOptions(r.item)
    end if
    paint()
    return true
end function
