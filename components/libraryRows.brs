' Shows and Movies as rows (UX review Nov 27, picked by the owner): one Plex fetch of the whole library plus
' "continue" and "recently added", sorted on the TV into rows. Every row ends with an "All A to Z" tile that opens
' the poster grid (the older tabs + grid view in LibraryRoom.brs). Back from the grid comes back here.
'   Shows:  Continue watching, New episodes (shows you watch), Recently added, Not started yet, your top 3 genres,
'           Finished
'   Movies: Continue watching, Short enough for tonight (under 1 h 40), Recently added, Unwatched, your top 3 genres

sub rowsInit()
    m.view = "rows"
    m.rowsClip = m.top.findNode("rowsClip")
    m.rowsBox = m.top.findNode("rowsBox")
    m.rowNodes = []
    m.rowKeys = []
    m.rowI = 0
    m.rowData = {}
    m.rowsSig = ""
end sub

sub applyView()
    rows = (m.view = "rows")
    m.rowsClip.visible = rows
    m.top.findNode("tabs").visible = not rows
    m.gridClip.visible = not rows
    m.countLabel.visible = not rows
    m.top.findNode("buttons").visible = not rows
    if rows
        m.chipsG.visible = false
        m.lettersG.visible = false
    else
        layoutAZ()
    end if
end sub

sub loadRows()
    applyView()
    sec = m.section
    if m.rowData.all = invalid then m.empty.text = "Loading…"
    hPlex("resume", { section: sec, limit: 20 }, "onRowData", "continue")
    hPlex("latest", { section: sec, limit: 40 }, "onRowData", "latest")
    hPlex("list", { section: sec, sort: "titleSort", limit: 2000 }, "onRowData", "all")
end sub

sub onRowData(event as object)
    t = hTaskFrom(event)
    m.top.ready = true
    if not t.ok
        if t.tag = "all" and m.rowData.all = invalid then m.empty.text = "Couldn't reach Plex. Hearth tries again when you come back to this room."
        return
    end if
    items = []
    if t.response.Items <> invalid then items = t.response.Items
    m.rowData[t.tag] = items
    ' the whole library doubles as the A to Z grid's first page, so "All A to Z" opens instantly
    if t.tag = "all" then m.data["A to Z|0|false|"] = items
    buildRowsList()
end sub

' The same order all day (a title you noticed in a row is still there when you come back), a new one tomorrow.
' Each title gets a number from its id and today's date; the row is sorted by it.
function rowsShuffle(list as object) as object
    if m.rowsDay = invalid
        dt = CreateObject("roDateTime")
        dt.ToLocalTime()
        m.rowsDay = dt.GetDayOfMonth() * 37 + dt.GetMonth() * 101
    end if
    a = []
    for each x in list
        k = ""
        if x.Id <> invalid then k = x.Id.toStr()
        h = m.rowsDay
        for i = 1 to Len(k)
            h = (h * 31 + Asc(Mid(k, i, 1))) mod 1000003
        end for
        x._ord = h
        a.push(x)
    end for
    a.SortBy("_ord")
    return a
end function

' Titles already shown in an earlier row are passed over, so Comedy and Drama don't open with the same posters.
' If that would leave a thin row (under 6), the row keeps its own picks.
function rowsFresh(list as object, used as object, n as integer) as object
    out = []
    for each x in list
        k = ""
        if x.Id <> invalid then k = x.Id.toStr()
        if out.count() < n and not used.DoesExist(k) then out.push(x)
    end for
    if out.count() < 6 then out = rowsTake(list, n)
    for each x in out
        if x.Id <> invalid then used[x.Id.toStr()] = true
    end for
    return out
end function

function rowsTake(list as object, n as integer) as object
    out = []
    for each x in list
        if out.count() < n then out.push(x)
    end for
    return out
end function

' shows: watched some of it; movies: watched it
function rowsSeen(it as object) as boolean
    if it.Type = "Series" then return it.ViewedLeafCount <> invalid and it.ViewedLeafCount > 0
    return it.UserData <> invalid and it.UserData.Played = true
end function

function rowsTopGenres(all as object) as object
    counts = {}
    for pass = 0 to 1
        for each it in all
            if it.Genres <> invalid and (pass = 1 or rowsSeen(it))
                for each g in it.Genres
                    if counts[g] = invalid then counts[g] = 0
                    counts[g] = counts[g] + 1
                end for
            end if
        end for
        ' nothing watched yet: rank genres over the whole library instead
        if counts.count() > 0 then exit for
    end for
    list = []
    for each g in counts
        list.push({ n: g, c: counts[g] })
    end for
    list.SortBy("c", "r")
    out = []
    for each x in list
        if out.count() < 3 then out.push(x.n)
    end for
    return out
end function

sub buildRowsList()
    all = m.rowData.all
    if all = invalid then all = []
    cont = m.rowData.continue
    if cont = invalid then cont = []
    latest = m.rowData.latest
    if latest = invalid then latest = []
    shows = (m.top.kind = "tvshows")
    byId = {}
    for each it in all
        if it.Id <> invalid then byId[it.Id.toStr()] = it
    end for
    defs = []
    m.rowsUsed = {}
    defs.push({ key: "continue", title: "Continue watching", icon: "home-play", wide: true, items: cont })
    if shows
        newEps = []
        added = []
        for each it in latest
            sid = it.Id
            if it.SeriesId <> invalid then sid = it.SeriesId
            show = invalid
            if sid <> invalid then show = byId[sid.toStr()]
            if show <> invalid and rowsSeen(show) and not (show.UserData <> invalid and show.UserData.Played = true)
                newEps.push(show)
            else
                added.push(it)
            end if
        end for
        defs.push({ key: "new", title: "New episodes", icon: "d-heart", wide: false, items: rowsDedupe(newEps) })
        defs.push({ key: "added", title: "Recently added", icon: "d-layers", wide: false, items: rowsDedupe(added) })
        fresh = []
        done = []
        for each it in all
            if it.ViewedLeafCount <> invalid and it.ViewedLeafCount = 0 then fresh.push(it)
            if it.UserData <> invalid and it.UserData.Played = true then done.push(it)
        end for
        defs.push({ key: "fresh", title: "Not started yet", icon: "d-film", wide: false, items: rowsFresh(rowsShuffle(fresh), m.rowsUsed, 20) })
        rowsGenreDefs(defs, all)
        defs.push({ key: "done", title: "Finished", icon: "d-film", wide: false, items: rowsFresh(rowsShuffle(done), m.rowsUsed, 20) })
    else
        short = []
        unw = []
        for each it in all
            played = (it.UserData <> invalid and it.UserData.Played = true)
            if not played
                unw.push(it)
                if it.RunTimeTicks <> invalid and it.RunTimeTicks > 0 and it.RunTimeTicks / 600000000 <= 100 then short.push(it)
            end if
        end for
        defs.push({ key: "short", title: "Short enough for tonight", icon: "d-film", wide: false, items: rowsFresh(rowsShuffle(short), m.rowsUsed, 20) })
        defs.push({ key: "added", title: "Recently added", icon: "d-layers", wide: false, items: rowsDedupe(latest) })
        defs.push({ key: "unw", title: "Unwatched", icon: "d-film", wide: false, items: rowsFresh(rowsShuffle(unw), m.rowsUsed, 20) })
        rowsGenreDefs(defs, all)
    end if
    ' rows with nothing in them are left out; the rest are rebuilt only when what they hold changed
    keep = []
    for each d in defs
        if d.items.count() > 0 then keep.push(d)
    end for
    sig = ""
    for each d in keep
        sig = sig + d.key + ":" + d.items.count().toStr() + ";"
        ' Continue changes as you watch: its progress is part of the signature
        if d.key = "continue"
            for each it in d.items
                sig = sig + Int(hPercent(it)).toStr() + ","
            end for
        end if
    end for
    if keep.count() = 0
        if m.rowData.all <> invalid then m.empty.text = "Nothing here yet."
    else
        m.empty.text = ""
    end if
    if sig = m.rowsSig then return
    m.rowsSig = sig
    oldKey = ""
    if m.rowI < m.rowKeys.count() then oldKey = m.rowKeys[m.rowI]
    oldIdx = {}
    for i = 0 to m.rowNodes.count() - 1
        oldIdx[m.rowKeys[i]] = m.rowNodes[i].index
    end for
    m.rowsBox.removeChildrenIndex(m.rowsBox.getChildCount(), 0)
    m.rowNodes = []
    m.rowKeys = []
    m.rowI = 0
    noun = "shows"
    if not shows then noun = "movies"
    for i = 0 to keep.count() - 1
        d = keep[i]
        r = m.rowsBox.createChild("CardRow")
        if d.wide
            r.cardWidth = 300
            r.cardHeight = 168
        else
            r.cardWidth = 160
            r.cardHeight = 240
        end if
        r.title = d.title
        r.icon = "pkg:/images/icons/" + d.icon + ".png"
        r.seed = i mod 4
        r.viewWidth = 1728
        cards = []
        for each it in d.items
            if d.wide then cards.push(hCard(it, "wide")) else cards.push(hCard(it, "tall"))
        end for
        ' the way out to everything: last tile of every row
        cards.push({ az: true, title: "All " + noun, sub: all.count().toStr() + " titles", image: "", progress: 0 })
        r.cards = cards
        if oldIdx[d.key] <> invalid and oldIdx[d.key] < cards.count() then r.index = oldIdx[d.key]
        if d.key = oldKey then m.rowI = i
        m.rowNodes.push(r)
        m.rowKeys.push(d.key)
    end for
    layoutRowsView()
    paintRows()
end sub

function rowsDedupe(list as object) as object
    out = []
    seen = {}
    for each it in list
        if it.Id <> invalid and seen[it.Id.toStr()] = invalid and out.count() < 20
            seen[it.Id.toStr()] = true
            out.push(it)
        end if
    end for
    return out
end function

sub rowsGenreDefs(defs as object, all as object)
    for each g in rowsTopGenres(all)
        fresh = []
        seen = []
        for each it in all
            if it.Genres <> invalid
                hit = false
                for each x in it.Genres
                    if x = g then hit = true
                end for
                if hit
                    ' unwatched first: these rows are for finding something
                    if it.UserData <> invalid and it.UserData.Played = true then seen.push(it) else fresh.push(it)
                end if
            end if
        end for
        list = rowsShuffle(fresh)
        list.append(rowsShuffle(seen))
        defs.push({ key: "g:" + g, title: g, icon: "d-heart", wide: false, items: rowsFresh(list, m.rowsUsed, 20) })
    end for
end sub

sub layoutRowsView()
    y = 0
    m.rowY = []
    for each r in m.rowNodes
        r.translation = [0, y]
        m.rowY.push(y)
        h = r.rowHeight
        if h = 0 then h = 400
        y = y + h + 24
    end for
end sub

' the focused row sits at the top of the rows area; rows above it slide out of view
sub paintRows()
    if m.rowNodes.count() = 0 then return
    if m.rowI >= m.rowNodes.count() then m.rowI = m.rowNodes.count() - 1
    m.rowsBox.translation = [96, -m.rowY[m.rowI]]
    for i = 0 to m.rowNodes.count() - 1
        r = m.rowNodes[i]
        r.active = (m.focused and m.zone = "rows" and i = m.rowI)
        if i < m.rowI then r.opacity = 0 else r.opacity = 1
    end for
    c = rowsCurrent()
    if c <> invalid and not rowsIsAz(c) and c.item <> invalid
        m.item = c.item
    else if c <> invalid
        m.item = invalid
        m.eyebrow.text = "EVERYTHING"
        if m.top.kind = "tvshows" then setStripTitle("ALL SHOWS A TO Z") else setStripTitle("ALL MOVIES A TO Z")
        m.overview.text = "OK opens every title as posters, with sort, filters and a letter row."
        m.art.uri = ""
    end if
    if m.item <> invalid then showInfo()
    paintRowHints()
end sub

function rowsCurrent() as dynamic
    if m.rowI >= m.rowNodes.count() then return invalid
    return m.rowNodes[m.rowI].callFunc("current", invalid)
end function

' the rows run to the bottom of the screen (the picked layout has no key strip), so the hints stay hidden here;
' OK opens, Play plays and * gives options as everywhere else
sub paintRowHints()
    m.hints.visible = false
    m.hintSig = ""
end sub

' the poster grid, opened at A to Z
sub enterGrid()
    m.view = "grid"
    m.zone = "grid"
    m.keepAt = invalid
    m.hintSig = ""
    applyView()
    loadTab(3)
    paint()
end sub

sub leaveGrid()
    m.view = "rows"
    m.zone = "rows"
    m.hintSig = ""
    m.genre = invalid
    applyView()
    m.empty.text = ""
    paintRows()
end sub

function rowsKey(key as string) as boolean
    n = m.rowNodes.count()
    c = rowsCurrent()
    if key = "back"
        leaveToPills()
        return true
    end if
    if key = "play"
        if c <> invalid and not rowsIsAz(c) and playable(c.item)
            m.top.request = { action: "play", item: c.item, resume: hPercent(c.item) > 0 }
            return true
        end if
        return false
    end if
    if hMediaKey(key) then return false
    if key = "options"
        if c <> invalid and not rowsIsAz(c) and c.item <> invalid then hOptions(c.item)
        return true
    end if
    if key = "up"
        if m.rowI > 0
            m.rowI = m.rowI - 1
        else
            leaveToPills()
            return true
        end if
    else if key = "down"
        if m.rowI < n - 1 then m.rowI = m.rowI + 1
    else if key = "left" and n > 0
        m.rowNodes[m.rowI].callFunc("move", -1)
    else if key = "right" and n > 0
        m.rowNodes[m.rowI].callFunc("move", 1)
    else if key = "OK" and c <> invalid
        if rowsIsAz(c)
            enterGrid()
        else
            m.top.request = { action: "details", item: c.item }
        end if
        return true
    end if
    paintRows()
    return true
end function

' the "All A to Z" tile (plain cards have no az field; comparing a missing field to true is not safe)
function rowsIsAz(c as dynamic) as boolean
    if c = invalid then return false
    return c.DoesExist("az")
end function
