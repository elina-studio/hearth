' Details, layout A "Ledger". For a show the page is the show: season tabs and the full episode list, with
' the next-up episode as the target of Play / CC / Audio. An episode opened from elsewhere opens its show,
' on its season, with that episode focused. Actions and the side sheets live in details/actions.brs.

sub init()
    m.content = m.top.findNode("content")
    m.poster = m.top.findNode("poster")
    m.kicker = m.top.findNode("kicker")
    m.kicker.font = hFont("caps", 24)
    m.title = m.top.findNode("title")
    m.title.font = hFont("caps", 64)
    m.meta = m.top.findNode("meta")
    m.meta.font = hFont("regular", 22)
    m.tags = m.top.findNode("tags")
    m.overview = m.top.findNode("overview")
    m.overview.font = hFont("regular", 22)
    m.actionsBox = m.top.findNode("actions")
    m.tabsBox = m.top.findNode("tabsBox")
    m.tabsClip = m.top.findNode("tabsClip")
    m.tabs = m.top.findNode("tabs")
    m.chipsBox = m.top.findNode("chips")
    m.rowsBox = m.top.findNode("rows")
    m.belowBox = m.top.findNode("below")
    m.empty = m.top.findNode("empty")
    m.empty.font = hFont("regular", 24)
    m.scroll = m.top.findNode("scroll")
    m.scrollTo = m.top.findNode("scrollTo")
    m.seasonWait = m.top.findNode("seasonWait")
    m.seasonWait.observeField("fire", "onSeasonWait")
    m.later = m.top.findNode("later")
    m.later.observeField("fire", "onLater")
    m.sheet = m.top.findNode("sheet")
    m.sheet.observeField("result", "onSheetResult")
    m.sheet.observeField("closed", "onSheetClosed")
    m.finder = m.top.findNode("finder")
    m.finder.observeField("closed", "onFinderClosed")
    m.finder.observeField("result", "onFinderResult")
    m.finderChanged = false

    m.LIST_TOP = 538
    m.ROW = 124
    ' the page sits 80px lower to make room for the rooms bar (RoomBar, 0-120)
    m.offset = 80
    m.roomBar = m.top.findNode("roomBar")
    m.hints = m.top.findNode("hints")
    m.hintSig = ""
    m.zone = "act"
    m.isShow = false
    m.btn = 0
    m.tabSel = 0
    m.epSel = 0
    m.belowSel = 0
    m.actions = []
    m.chips = []
    m.seasons = []
    m.sIdx = -1
    m.eps = []
    m.missing = {}
    m.bz = invalid
    m.full = invalid
    m.target = invalid
    m.targetFull = invalid
    m.wantEp = invalid
    m.belowRows = []
    m.pool = []
    for i = 0 to 10
        r = m.rowsBox.createChild("EpisodeRow")
        r.visible = false
        r.addFields({ at: -1 })
        m.pool.push(r)
    end for
end sub

sub onShown(unused as dynamic)
    ' back from the player or a pushed page: progress and watched marks may have changed
    if m.full <> invalid then reload()
    m.top.setFocus(true)
end sub

' ---------------------------------------------------------------- loading

sub load()
    it = m.top.item
    if it = invalid or it.Id = invalid then return
    m.showId = it.Id
    if it.Type = "Episode" and it.SeriesId <> invalid
        ' the page for an episode is its show, opened on that episode
        m.showId = it.SeriesId
        m.wantEp = { season: it.ParentIndexNumber, id: it.Id }
        m.zone = "eps"
    end if
    if it.Type <> "Episode" then fillHeaderBasic(it)
    if it.Type = "Movie" then m.roomBar.current = "Movies" else m.roomBar.current = "Shows"
    hPlex("item", { id: m.showId, full: true }, "onFull")
end sub

' Keep the season, episode and focus; fetch everything again.
sub reload()
    if m.sIdx >= 0 and m.sIdx < m.seasons.count() and m.eps.count() > 0 and m.epSel < m.eps.count()
        m.wantEp = { season: m.seasons[m.sIdx].index, id: m.eps[m.epSel].Id }
    end if
    hPlex("item", { id: m.showId, full: true }, "onFull")
end sub

sub onFull(event as object)
    t = hTaskFrom(event)
    if not t.ok or t.response.Id = invalid
        if m.full = invalid
            ' first load failed: say so instead of leaving a blank page
            m.empty.translation = [340, 334]
            m.empty.text = "Couldn't load this title from Plex. Press Back to return."
            m.empty.visible = true
        end if
        return
    end if
    m.full = t.response
    m.isShow = (m.full.Type = "Series")
    if m.isShow then m.roomBar.current = "Shows" else m.roomBar.current = "Movies"
    if m.isShow
        m.target = m.full.OnDeck
        hPlex("seasons", { id: m.full.Id }, "onSeasons")
        loadBazarrShow()
    else
        m.target = m.full
        m.targetFull = m.full
        autoSubs()
        loadBazarrMovie()
    end if
    fillHeader()
    buildActions()
    buildBelow()
    if m.target <> invalid and m.isShow then hPlex("item", { id: m.target.Id }, "onTargetFull")
end sub

sub onTargetFull(event as object)
    t = hTaskFrom(event)
    if not t.ok or t.response.Id = invalid then return
    m.targetFull = t.response
    autoSubs()
    fillHeader()
    buildActions()
end sub

' Fetch an English subtitle ahead of Play when the title has none (components/subs/SubsAuto)
sub autoSubs()
    if m.auto = invalid
        m.auto = m.top.findNode("auto")
        m.auto.observeField("result", "onAutoSub")
    end if
    m.auto.item = m.targetFull
    m.auto.callFunc("go", invalid)
end sub

sub onAutoSub()
    r = m.auto.result
    if r = invalid or r.ok <> true or r.item = invalid or m.targetFull = invalid or r.item.Id <> m.targetFull.Id then return
    m.targetFull = r.item
    if not m.isShow then m.full = r.item
    fillHeader()
    buildActions()
end sub

sub onSeasons(event as object)
    t = hTaskFrom(event)
    if not t.ok
        hMessage("Seasons", "Couldn't load the seasons from Plex (status " + t.status.toStr() + "). Press Back and open the show again.")
        return
    end if
    ' specials (season 0) go last
    list = []
    specials = invalid
    for each s in t.response.Items
        if s.index = 0 then specials = s else list.push(s)
    end for
    if specials <> invalid then list.push(specials)
    m.seasons = list
    m.tabsBox.visible = list.count() > 0
    pick = -1
    want = invalid
    if m.wantEp <> invalid then want = m.wantEp.season
    if want = invalid and m.target <> invalid then want = m.target.ParentIndexNumber
    for i = 0 to list.count() - 1
        if want <> invalid and list[i].index = want then pick = i
    end for
    if pick = -1
        ' first season with something unwatched
        for i = 0 to list.count() - 1
            if pick = -1 and list[i].index > 0 and list[i].watched <> invalid and list[i].total <> invalid and list[i].watched < list[i].total then pick = i
        end for
    end if
    if pick = -1 then pick = 0
    m.sIdx = pick
    m.tabSel = pick
    drawTabs()
    if list.count() > 0 then loadSeason()
end sub

sub loadSeason()
    s = m.seasons[m.sIdx]
    m.loadingSeason = s.Id
    hPlex("seasonEpisodes", { id: s.Id }, "onSeasonEpisodes")
end sub

sub onSeasonEpisodes(event as object)
    t = hTaskFrom(event)
    if m.sIdx < 0 or m.seasons[m.sIdx].Id <> m.loadingSeason then return
    if not t.ok
        ' don't leave the previous season's episodes under this season's tab
        m.eps = []
        for each r in m.pool
            r.at = -1
        end for
        m.empty.visible = true
        m.empty.translation = [100, m.LIST_TOP]
        m.empty.text = "Couldn't load this season. Pick it again to retry."
        if m.zone = "eps" then m.zone = "tabs"
        drawChips()
        layoutBelow()
        paint()
        return
    end if
    m.eps = t.response.Items
    sel = -1
    if m.wantEp <> invalid
        for i = 0 to m.eps.count() - 1
            if m.eps[i].Id = m.wantEp.id then sel = i
        end for
        m.wantEp = invalid
    end if
    if sel = -1 and m.target <> invalid
        for i = 0 to m.eps.count() - 1
            if m.eps[i].Id = m.target.Id then sel = i
        end for
    end if
    if sel = -1
        for i = 0 to m.eps.count() - 1
            if sel = -1 and not isPlayed(m.eps[i]) then sel = i
        end for
    end if
    if sel = -1 then sel = 0
    m.epSel = sel
    if m.target = invalid and m.eps.count() > 0
        ' nothing on deck (all watched, or not started): Play starts the focused episode
        m.target = m.eps[sel]
        hPlex("item", { id: m.target.Id }, "onTargetFull")
    end if
    for each r in m.pool
        r.at = -1
    end for
    m.empty.visible = (m.eps.count() = 0)
    m.empty.translation = [100, m.LIST_TOP]
    m.empty.text = "No episodes in this season yet."
    if m.zone = "eps" and m.eps.count() = 0 then m.zone = "tabs"
    drawChips()
    layoutBelow()
    paint()
end sub

' ---------------------------------------------------------------- header

sub fillHeaderBasic(it as object)
    ' title: 64, then 52, then 40 on one line; longer takes two lines at 40 and the rest of the header moves down
    fit = hFitTitle2(m.title, UCase(hTitle(it)), "caps", [64, 52, 40], 1480)
    m.title.translation = [0, 88 + fit.drop]
    d = 0
    if fit.lines = 2 then d = fit.height - 78
    if d < 0 then d = 0
    if d > 36 then d = 36
    ' the badge row is centred on its y: it sat on top of the line above it (walk 2). Each line now clears the last.
    m.meta.translation = [0, 174 + d]
    m.tags.translation = [0, 230 + d]
    m.overview.translation = [0, 262 + d]
    m.actionsBox.translation = [0, 342 + d]
    m.poster.uri = hImageAny(it, ["Primary"], 300)
    ov = it.Overview
    if ov = invalid then ov = ""
    m.overview.text = ov
end sub

sub fillHeader()
    it = m.full
    fillHeaderBasic(it)
    tgt = m.target
    ' the kicker is the path back (Back climbs one step): SHOWS › SUPERNATURAL › NEXT UP S4 E3
    if m.isShow
        k = backTo("SHOWS")
        if tgt <> invalid and tgt.Type = "Episode"
            k = k + "    "
            if hPercent(tgt) > 0 then k = k + "CONTINUE " else k = k + "NEXT UP "
            k = k + "S" + hNum(tgt.ParentIndexNumber) + " E" + hNum(tgt.IndexNumber)
        end if
    else
        k = backTo("MOVIES")
        if it.Studio <> invalid then k = k + "    " + UCase(it.Studio)
    end if
    m.kicker.text = k

    parts = []
    if it.ProductionYear <> invalid then parts.push(it.ProductionYear.toStr())
    if it.OfficialRating <> invalid then parts.push(it.OfficialRating)
    if it.Genres <> invalid and it.Genres.count() > 0
        g = [it.Genres[0]]
        if it.Genres.count() > 1 then g.push(it.Genres[1])
        parts.push(g.join(", "))
    end if
    if m.isShow and it.SeasonCount <> invalid
        if it.SeasonCount = 1 then parts.push("1 season") else parts.push(it.SeasonCount.toStr() + " seasons")
    end if
    rt = invalid
    if tgt <> invalid then rt = tgt.RunTimeTicks
    if rt <> invalid then parts.push(runtimeText(rt))
    if rt <> invalid
        leftMs = (rt - posTicks(tgt)) / 10000
        if isPlayed(tgt) then leftMs = rt / 10000
        parts.push("ends " + clockAfter(leftMs))
    end if
    m.meta.text = parts.join("  ·  ")
    fillTags()
end sub

' "MOVIES" after the back arrow icon: where Back takes you. The title is already big below, so it isn't repeated here.
function backTo(dflt as string) as string
    f = m.top.from
    if f = "" or f = "Back" then f = dflt
    return UCase(f)
end function

sub fillTags()
    m.tags.removeChildrenIndex(m.tags.getChildCount(), 0)
    it = m.full
    ' two ratings at most: critics and IMDb first, then whatever else Plex has (UX review item 26)
    if it.Ratings <> invalid
        pick2 = []
        for each want in ["Critics", "IMDb", "Audience", "TMDB", "TVDB"]
            for each r in it.Ratings
                if r.label = want and pick2.count() < 2 then pick2.push(r)
            end for
        end for
        for each r in pick2
            hRating(m.tags, r.label, r.text)
        end for
    end if
    if it.UserRating <> invalid and it.UserRating > 0
        hRating(m.tags, "Yours", (Int(it.UserRating / 2 + 0.5)).toStr() + "/5")
    end if
    row = m.tags.createChild("LayoutGroup")
    row.layoutDirection = "horiz"
    row.vertAlignment = "center"
    row.itemSpacings = [10]
    tf = m.targetFull
    if tf <> invalid and tf._media <> invalid and tf._media.count() > 0
        media = tf._media[0]
        part = invalid
        if media.Part <> invalid and media.Part.count() > 0 then part = media.Part[0]
        st = hPlayStreams(part)
        res = resText(media.videoResolution)
        if res <> "" then hTag(row, res, "", "gold")
        cc = ccText(tf)
        if cc <> "" then hTag(row, cc, "", "plain")
        miss = missingFor(tf)
        if miss <> "" then hTag(row, miss, "ccx", "warn")
        d = hPlayDirectCheck(media, st)
        ' tech badges cut to resolution and captions (UX review item 10); a note only when the file has to convert
        if d.ok
            ' plays as is: nothing to say
        else if LCase(pStr(media.videoCodec)) = "hevc" or LCase(pStr(media.videoCodec)) = "h265"
            hTag(row, "Will convert to 720p", "wand", "plain")
        else if Left(d.why, 5) = "audio"
            hTag(row, "Audio converts", "wand", "plain")
        else if Left(d.why, 9) = "container"
            hTag(row, "Repackaged to play", "wand", "plain")
        else
            hTag(row, "Converts to play", "wand", "plain")
        end if
    end if
end sub

' ---------------------------------------------------------------- action row

sub buildActions()
    list = []
    it = m.full
    tgt = m.target
    if tgt <> invalid
        lab = "Play"
        pct = hPercent(tgt)
        if pct > 0 and not isPlayed(tgt) then lab = "Resume"
        if m.isShow and tgt.Type = "Episode" then lab = lab + " S" + hNum(tgt.ParentIndexNumber) + " E" + hNum(tgt.IndexNumber)
        if pct > 0 and not isPlayed(tgt)
            list.push({ icon: "play", text: lab, action: "resume" })
            list.push({ icon: "restart", text: "From start", action: "restart" })
        else
            list.push({ icon: "play", text: lab, action: "restart" })
        end if
    end if
    if trailer() <> invalid then list.push({ icon: "film", text: "Trailer", action: "trailer" })
    if tgt <> invalid
        list.push({ icon: "cc", text: ccShort(m.targetFull), action: "subs" })
        au = audioShort(m.targetFull)
        if au <> "" then list.push({ icon: "audio", text: au, action: "audio" })
    end if
    ' Mark watched lives in More: as a main button it sat one press from Resume (UX review item 28)
    if isPlayed(it) then list.push({ icon: "checkc", text: "Watched", action: "more" })
    list.push({ icon: "more", text: "More", action: "more" })
    m.actions = list
    m.actionsBox.removeChildrenIndex(m.actionsBox.getChildCount(), 0)
    x = 0
    vi = 0
    for each a in list
        b = m.actionsBox.createChild("IconButton")
        b.variant = (vi mod 6) + 1
        vi = vi + 1
        b.icon = a.icon
        b.text = a.text
        b.translation = [x, 0]
        x = x + b.width + 14
    end for
    if m.btn >= list.count() then m.btn = 0
    paint()
end sub

' ---------------------------------------------------------------- season tabs and chips

sub drawTabs()
    m.tabs.removeChildrenIndex(m.tabs.getChildCount(), 0)
    x = 0
    m.tabX = []
    for i = 0 to m.seasons.count() - 1
        s = m.seasons[i]
        g = m.tabs.createChild("Group")
        g.translation = [x, 0]
        cur = (i = m.sIdx)
        foc = (m.zone = "tabs" and i = m.tabSel)
        lab = g.createChild("Label")
        if cur or s.index = 0
            lab.font = hFont("pica", 28)
            if s.index = 0 then lab.text = "SPECIALS" else lab.text = "SEASON " + s.index.toStr()
        else
            lab.font = hFont("bold", 28)
            lab.text = s.index.toStr()
        end if
        done = (s.total <> invalid and s.watched <> invalid and s.total > 0 and s.watched >= s.total)
        if foc
            lab.color = "0x1F1606FF"
        else if cur
            lab.color = "0xFFE7A0FF"
        else if done
            lab.color = "0x7E8A62FF"
        else
            lab.color = "0xB5AF8CFF"
        end if
        lab.translation = [0, 4]
        w = lab.boundingRect().width
        ' progress in words under the name: "all watched" + tick, "6 left", "8 new"
        prog = seasonProgress(s)
        if prog <> ""
            sub1 = g.createChild("Label")
            sub1.font = hFont("regular", 20)
            sub1.text = prog
            sub1.translation = [0, 40]
            if foc
                sub1.color = "0x1F1606CC"
            else if cur
                sub1.color = "0xEDE6CACC"
            else
                sub1.color = "0xB5AF8CCC"
            end if
            sw = sub1.boundingRect().width
            if done
                tick = g.createChild("Poster")
                tick.uri = "pkg:/images/icons/d-check.png"
                tick.width = 20
                tick.height = 20
                tick.translation = [sw + 6, 43]
                if foc then tick.blendColor = "0x1F1606FF" else tick.blendColor = "0x7E8A62FF"
                sw = sw + 26
            end if
            if sw > w then w = sw
        end if
        if foc
            pill = g.createChild("Poster")
            pill.uri = "pkg:/images/w/button-fill.9.png"
            pill.blendColor = "0xE0B34AFF"
            pill.translation = [-14 - 12, -4 - 12]
            pill.width = w + 28 + 24
            pill.height = 72 + 24
            g.insertChild(pill, 0)
        end if
        if cur
            u = g.createChild("Rectangle")
            u.color = "0xE0B34AFF"
            u.width = w
            u.height = 3
            u.translation = [0, 68]
        end if
        m.tabX.push([x, w])
        x = x + w + 40
    end for
    ' keep the focused tab inside the clip
    if m.tabX.count() > 0
        i = m.tabSel
        if i >= m.tabX.count() then i = m.sIdx
        sx = m.tabs.translation[0]
        l = m.tabX[i][0] + sx
        r = l + m.tabX[i][1]
        if r > 1280 then sx = sx - (r - 1280)
        if l < 0 then sx = sx - l
        m.tabs.translation = [sx, 0]
    end if
end sub

' A season's progress in words, from the seasons answer (total / watched): "all watched", "6 left", "8 new"
function seasonProgress(s as object) as string
    if s.total = invalid or s.watched = invalid or s.total <= 0 then return ""
    if s.watched >= s.total then return "all watched"
    if s.watched <= 0 then return s.total.toStr() + " new"
    return (s.total - s.watched).toStr() + " left"
end function

sub drawChips()
    list = []
    if m.eps.count() > 0 then list.push({ icon: "shuffle", text: "Shuffle", action: "shuffle" })
    n = missingInSeason().count()
    if n > 0 then list.push({ icon: "ccx", text: "Find " + n.toStr() + " missing", action: "fetchMissing" })
    m.chips = list
    ' a chip may have just disappeared (e.g. "Find missing" after Bazarr): keep the cursor on something real
    if m.zone = "tabs" and m.tabSel >= m.seasons.count() + list.count() then m.tabSel = m.sIdx
    m.chipsBox.removeChildrenIndex(m.chipsBox.getChildCount(), 0)
    vi = 2
    for each c in list
        b = m.chipsBox.createChild("IconButton")
        b.variant = (vi mod 6) + 1
        vi = vi + 1
        b.icon = c.icon
        b.text = c.text
    end for
end sub

function tabCount() as integer
    return m.seasons.count() + m.chips.count()
end function

sub onSeasonWait()
    if m.tabSel < m.seasons.count() and m.tabSel <> m.sIdx
        m.sIdx = m.tabSel
        m.epSel = 0
        loadSeason()
        drawTabs()
    end if
end sub

' ---------------------------------------------------------------- episode rows

function epData(ep as object) as object
    meta = []
    if ep.RunTimeTicks <> invalid then meta.push(runtimeText(ep.RunTimeTicks))
    if ep.aired <> invalid and ep.aired <> "" then meta.push(dateText(ep.aired))
    if hPercent(ep) > 0 and not isPlayed(ep) then meta.push(hMinutesLeft(ep))
    syn = ep.Overview
    if syn = invalid then syn = ""
    name = ep.Name
    if name = invalid then name = ""
    miss = ""
    if ep.ParentIndexNumber <> invalid and ep.IndexNumber <> invalid
        langs = m.missing[ep.ParentIndexNumber.toStr() + "-" + ep.IndexNumber.toStr()]
        if langs <> invalid and langs.count() > 0 then miss = "No " + langs[0].name
    end if
    hevc = false
    if ep.flags <> invalid then hevc = ep.flags.hevc
    return { number: hNum(ep.IndexNumber), title: name, synopsis: syn, meta: meta.join("  ·  "), pct: hPercent(ep), watched: isPlayed(ep), missing: miss, hevc: hevc, image: hImageAny(ep, ["Thumb"], 320), key: ep.Id.toStr() }
end function

sub placeRows()
    n = m.eps.count()
    first = Int((-m.offset - m.LIST_TOP) / m.ROW) - 1
    if first < 0 then first = 0
    want = {}
    for i = first to first + m.pool.count() - 1
        if i < n then want[i.toStr()] = true
    end for
    ' free rows that scrolled away, then fill the gaps
    free = []
    for each r in m.pool
        if r.at < 0 or want[r.at.toStr()] = invalid
            r.at = -1
            r.visible = false
            free.push(r)
        else
            want.delete(r.at.toStr())
        end if
    end for
    for each k in want
        if free.count() > 0
            r = free.pop()
            i = k.toInt()
            r.at = i
            r.data = epData(m.eps[i])
            r.translation = [0, m.LIST_TOP + i * m.ROW]
            r.visible = true
        end if
    end for
    for each r in m.pool
        r.focused = (m.zone = "eps" and r.at = m.epSel)
    end for
end sub

' Redraw one episode's row after its data changed (watched mark, missing subs).
sub refreshRows()
    for each r in m.pool
        if r.at >= 0 and r.at < m.eps.count() then r.data = epData(m.eps[r.at])
    end for
end sub

' ---------------------------------------------------------------- rows below

sub buildBelow()
    for each r in m.belowRows
        m.belowBox.removeChild(r)
    end for
    m.belowRows = []
    it = m.full
    if it.Collections <> invalid
        for each col in it.Collections
            r = addBelow("Part of " + col.name, "layers", "titles", [], 200, 300)
            r.addFields({ collectionId: col.id })
            hPlex("collection", { id: col.id.toStr() }, "onCollection", col.id.toStr())
        end for
    end if
    sim = addBelow("More like this", "heart", "", [], 200, 300)
    sim.addFields({ similar: true })
    hPlex("similar", { id: it.Id }, "onSimilar")
    ' what to watch next comes before who is in it (UX review item 29)
    if it.People <> invalid and it.People.count() > 0
        cards = []
        for each p in it.People
            img = ""
            if p.thumb <> invalid and p.thumb <> "" then img = hPlexImage(p.thumb, 200, "Primary")
            cards.push({ item: { Type: "Person", Id: p.id, Name: p.name }, title: p.name, sub: p.role, image: img, progress: 0 })
        end for
        addBelow("Cast & crew", "people", "people", cards, 160, 240)
    end if
    if it.Extras <> invalid and it.Extras.count() > 0
        cards = []
        for each x in it.Extras
            c = hCard(x, "wide")
            c.sub = extraKind(x.subtype)
            cards.push(c)
        end for
        addBelow("Extras", "film", "", cards, 320, 180)
    end if
    layoutBelow()
end sub

function addBelow(title as string, icon as string, noun as string, cards as object, w as integer, h as integer) as object
    r = m.belowBox.createChild("CardRow")
    r.cardWidth = w
    r.cardHeight = h
    r.title = title
    r.icon = "pkg:/images/icons/d-" + icon + ".png"
    r.countNoun = noun
    r.seed = m.belowRows.count()
    r.cards = cards
    r.visible = cards.count() > 0
    m.belowRows.push(r)
    return r
end function

sub onCollection(event as object)
    t = hTaskFrom(event)
    if not t.ok then return
    for each r in m.belowRows
        if r.collectionId <> invalid and r.collectionId.toStr() = t.tag
            cards = []
            for each x in t.response.Items
                if x.Id <> m.full.Id then cards.push(hCard(x, "tall"))
            end for
            r.cards = cards
            r.visible = cards.count() > 0
        end if
    end for
    layoutBelow()
end sub

sub onSimilar(event as object)
    t = hTaskFrom(event)
    if not t.ok then return
    cards = []
    for each x in t.response.Items
        cards.push(hCard(x, "tall"))
    end for
    for each r in m.belowRows
        if r.similar = true
            r.cards = cards
            r.visible = cards.count() > 0
        end if
    end for
    layoutBelow()
end sub

function belowTop() as integer
    if m.isShow = true
        n = m.eps.count()
        if n = 0 then n = 1
        return m.LIST_TOP + n * m.ROW + 50
    end if
    return 450
end function

sub layoutBelow()
    y = belowTop()
    for each r in m.belowRows
        if r.visible
            r.translation = [0, y]
            y = y + r.rowHeight + 40
        end if
    end for
end sub

function visibleBelow() as object
    out = []
    for each r in m.belowRows
        if r.visible and r.callFunc("count", invalid) > 0 then out.push(r)
    end for
    return out
end function

' ---------------------------------------------------------------- focus, scroll, paint

sub paint()
    for i = 0 to m.actionsBox.getChildCount() - 1
        m.actionsBox.getChild(i).focused = (m.zone = "act" and i = m.btn)
    end for
    for i = 0 to m.chipsBox.getChildCount() - 1
        m.chipsBox.getChild(i).focused = (m.zone = "tabs" and m.tabSel = m.seasons.count() + i)
    end for
    vb = visibleBelow()
    for i = 0 to vb.count() - 1
        vb[i].active = (m.zone = "below" and i = m.belowSel)
    end for
    ' where the focused thing sits on the page
    top = 0
    h = 400
    if m.zone = "tabs"
        top = 424
        h = 82 + 2 * m.ROW
    else if m.zone = "eps"
        top = m.LIST_TOP + m.epSel * m.ROW - 30
        h = m.ROW + 40
    else if m.zone = "below" and m.belowSel < vb.count()
        top = vb[m.belowSel].translation[1] - 40
        h = vb[m.belowSel].rowHeight + 40
    end if
    off = m.offset
    ' room for the pinned show header while the episode list or rows below are in view
    minTop = 130
    if m.isShow = true and (m.zone = "eps" or m.zone = "tabs" or m.zone = "below") then minTop = 230
    if m.zone = "act" or m.zone = "bar"
        off = 80
    else
        if top + off < minTop then off = minTop - top
        if top + h + off > 995 then off = 995 - top - h
        if off > 80 then off = 80
    end if
    if off <> m.offset
        m.scroll.control = "stop"
        m.scrollTo.keyValue = [m.content.translation, [0, off]]
        m.scroll.control = "start"
        m.offset = off
    end if
    placeRows()
    paintSticky()
    paintHints()
end sub

' The show's name, the season and the focused episode, pinned under the rooms bar once the page has scrolled
' past the title (UX review item 3).
sub paintSticky()
    if m.sticky = invalid
        m.sticky = m.top.findNode("sticky")
        m.stTitle = m.top.findNode("stTitle")
        m.stTitle.font = hFont("bold", 36)
        m.stSub = m.top.findNode("stSub")
        m.stSub.font = hFont("caps", 24)
    end if
    show = (m.isShow = true and m.full <> invalid and m.offset < -60)
    m.sticky.visible = show
    if not show then return
    name = m.full.Name
    if name = invalid then name = ""
    m.stTitle.text = name
    parts = []
    if m.sIdx >= 0 and m.sIdx < m.seasons.count()
        sn = m.seasons[m.sIdx]
        if sn.index = 0 then parts.push("SPECIALS") else parts.push("SEASON " + sn.index.toStr())
    end if
    if m.zone = "eps" and m.epSel >= 0 and m.epSel < m.eps.count()
        ep = m.eps[m.epSel]
        lbl = ""
        if ep.IndexNumber <> invalid then lbl = "E" + ep.IndexNumber.toStr()
        if ep.Name <> invalid and ep.Name <> "" then lbl = (lbl + "  " + UCase(ep.Name)).Trim()
        if lbl <> "" then parts.push(lbl)
    end if
    m.stSub.text = parts.join("  ·  ")
end sub

sub paintHints()
    opt = "More"
    if m.zone = "eps" then opt = "Episode options"
    if m.zone = "below" then opt = "Options"
    keys = [{ icon: "back", label: m.roomBar.current }]
    if m.zone = "act" then keys.push({ icon: "up", label: "Rooms" })
    ' * does nothing on the season tabs, so don't advertise it there
    if m.zone <> "bar" and m.zone <> "tabs" then keys.push({ icon: "asterisk", label: opt })
    sig = FormatJson(keys)
    if sig <> m.hintSig
        m.hintSig = sig
        m.hints.keys = keys
    end if
end sub

function hKeyInner(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
    if key = "back"
        m.top.request = { action: "back" }
        return true
    end if
    if m.zone = "bar"
        if key = "left" or key = "right"
            d = 1
            if key = "left" then d = -1
            m.roomBar.callFunc("move", d)
        else if key = "down"
            m.zone = "act"
            m.roomBar.focused = false
        else if key = "OK"
            ' climb back to the hub and open that room
            m.top.request = { action: "room", name: m.roomBar.callFunc("chosen", invalid) }
        end if
        paint()
        return true
    end if
    if m.full = invalid then return true
    if m.zone = "act" and key = "up"
        m.zone = "bar"
        m.roomBar.focused = true
        paint()
        return true
    end if
    if m.zone = "act"
        n = m.actions.count()
        if key = "left" and m.btn > 0
            m.btn = m.btn - 1
        else if key = "right" and m.btn < n - 1
            m.btn = m.btn + 1
        else if key = "down"
            if m.isShow and m.seasons.count() > 0
                m.zone = "tabs"
                m.tabSel = m.sIdx
                drawTabs()
            else
                downToBelow()
            end if
        else if key = "OK" and n > 0
            runAction(m.actions[m.btn].action)
        else if key = "options"
            openMore()
        end if
    else if m.zone = "tabs"
        n = tabCount()
        if key = "left" and m.tabSel > 0
            m.tabSel = m.tabSel - 1
            seasonMoved()
        else if key = "right" and m.tabSel < n - 1
            m.tabSel = m.tabSel + 1
            seasonMoved()
        else if key = "up"
            m.zone = "act"
            drawTabs()
        else if key = "down"
            if m.eps.count() > 0
                m.zone = "eps"
                if m.epSel >= m.eps.count() then m.epSel = 0
            else
                downToBelow()
            end if
            drawTabs()
        else if key = "OK"
            if m.tabSel >= m.seasons.count()
                if m.tabSel - m.seasons.count() < m.chips.count() then runAction(m.chips[m.tabSel - m.seasons.count()].action)
            else
                m.seasonWait.control = "stop"
                onSeasonWait()
                if m.eps.count() > 0 then m.zone = "eps"
                drawTabs()
            end if
        end if
    else if m.zone = "eps" and m.eps.count() = 0
        m.zone = "act"
    else if m.zone = "eps"
        if key = "up"
            if m.epSel > 0
                m.epSel = m.epSel - 1
            else
                m.zone = "tabs"
                m.tabSel = m.sIdx
                drawTabs()
            end if
        else if key = "down"
            if m.epSel < m.eps.count() - 1 then m.epSel = m.epSel + 1 else downToBelow()
        else if key = "OK"
            ep = m.eps[m.epSel]
            m.top.request = { action: "play", item: ep, resume: (hPercent(ep) > 0 and not isPlayed(ep)) }
        else if key = "options" or key = "right"
            openEpisodeSheet(m.eps[m.epSel])
        end if
    else if m.zone = "below"
        vb = visibleBelow()
        if m.belowSel >= vb.count() then m.belowSel = 0
        row = invalid
        if vb.count() > 0 then row = vb[m.belowSel]
        if row = invalid
            m.zone = "act"
        else if key = "left" or key = "right"
            d = 1
            if key = "left" then d = -1
            row.callFunc("move", d)
        else if key = "up"
            if m.belowSel > 0
                m.belowSel = m.belowSel - 1
            else if m.isShow and m.eps.count() > 0
                m.zone = "eps"
                m.epSel = m.eps.count() - 1
            else if m.isShow and m.seasons.count() > 0
                m.zone = "tabs"
                drawTabs()
            else
                m.zone = "act"
            end if
        else if key = "down" and m.belowSel < vb.count() - 1
            m.belowSel = m.belowSel + 1
        else if key = "OK"
            c = row.callFunc("current", invalid)
            if c <> invalid then openCard(c.item)
        else if key = "options"
            c = row.callFunc("current", invalid)
            if c <> invalid and c.item.Type <> "Person" and c.item.Type <> "Extra" then hOptions(c.item)
        end if
    end if
    paint()
    return true
end function

sub downToBelow()
    if visibleBelow().count() > 0
        m.zone = "below"
        m.belowSel = 0
    end if
end sub

sub seasonMoved()
    drawTabs()
    if m.tabSel < m.seasons.count()
        m.seasonWait.control = "stop"
        m.seasonWait.control = "start"
    end if
end sub

sub openCard(it as object)
    if it.Type = "Person"
        openPerson(it)
    else if it.Type = "Extra"
        m.top.request = { action: "play", item: it, resume: false }
    else if it.Type = "Episode"
        m.top.request = { action: "play", item: it, resume: true }
    else
        m.top.request = { action: "details", item: it }
    end if
end sub

' ---------------------------------------------------------------- small helpers

function isPlayed(it as dynamic) as boolean
    return it <> invalid and it.UserData <> invalid and it.UserData.Played = true
end function

function posTicks(it as object) as dynamic
    if it.UserData = invalid or it.UserData.PlaybackPositionTicks = invalid then return 0
    return it.UserData.PlaybackPositionTicks
end function

function runtimeText(t as dynamic) as string
    mins = Int(t / 600000000)
    if mins >= 60 then return (mins \ 60).toStr() + " h " + (mins mod 60).toStr() + " min"
    return mins.toStr() + " min"
end function

' "10:42 PM", ms from now, in the TV's time zone
function clockAfter(ms as dynamic) as string
    d = CreateObject("roDateTime")
    d.FromSeconds(d.AsSeconds() + Int(ms / 1000))
    d.ToLocalTime()
    h = d.GetHours()
    ap = "AM"
    if h >= 12 then ap = "PM"
    h = h mod 12
    if h = 0 then h = 12
    mi = d.GetMinutes()
    mm = mi.toStr()
    if mi < 10 then mm = "0" + mm
    return h.toStr() + ":" + mm + " " + ap
end function

function dateText(s as string) as string
    b = s.split("-")
    if b.count() < 3 then return s
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    mo = b[1].toInt()
    if mo < 1 or mo > 12 then return s
    return months[mo - 1] + " " + b[2].toInt().toStr() + ", " + b[0]
end function

function resText(r as dynamic) as string
    if r = invalid then return ""
    r = LCase(r.toStr())
    if r = "4k" then return "4K"
    if r = "sd" then return "SD"
    if r = "" then return ""
    return r + "p"
end function

function codecText(c as dynamic) as string
    c = LCase(pStr(c))
    if c = "h264" then return "H.264"
    if c = "hevc" or c = "h265" then return "HEVC"
    return UCase(c)
end function

function channelsText(n as dynamic) as string
    if n = invalid then return ""
    if n = 1 then return "Mono"
    if n = 2 then return "Stereo"
    if n = 6 then return "5.1"
    if n = 8 then return "7.1"
    return n.toStr() + " ch"
end function

function audioText(a as dynamic, media as object) as string
    codec = pStr(media.audioCodec)
    ch = media.audioChannels
    if a <> invalid
        if a.codec <> invalid then codec = pStr(a.codec)
        if a.channels <> invalid then ch = a.channels
    end if
    c = UCase(codec)
    if c = "DCA" then c = "DTS"
    if c = "EAC3" then c = "DD+"
    if c = "AC3" then c = "DD"
    return (c + " " + channelsText(ch)).Trim()
end function

' "English 5.1" for the Audio button (the selected track)
function audioShort(it as dynamic) as string
    if it = invalid or it._media = invalid or it._media.count() = 0 then return "Audio"
    part = it._media[0].Part
    if part = invalid or part.count() = 0 then return "Audio"
    st = hPlayStreams(part[0])
    if st.audio = invalid then return "Audio"
    lang = st.audio.language
    if lang = invalid then lang = "Audio"
    return (lang + " " + channelsText(st.audio.channels)).Trim()
end function

' "English" / "Off" / "None" for the CC button
function ccShort(it as dynamic) as string
    if it = invalid or it._media = invalid then return "Subtitles"
    st = hSubsStreams(it)
    for each s in st
        ' the language only: a subtitle's own title is often its file name (UX review item 17)
        if s.selected = true
            if s.language <> invalid and s.language <> "" then return s.language
            return "On"
        end if
    end for
    if st.count() = 0 then return "None"
    return "Off"
end function

' "CC English" when the file has English subtitles, else the first language it has
function ccText(it as object) as string
    st = hSubsStreams(it)
    if st.count() = 0 then return ""
    for each s in st
        lc = LCase(pStr(s.languageCode))
        if lc = "eng" or lc = "en" then return "CC English"
    end for
    if st[0].language <> invalid then return "CC " + st[0].language
    return "CC"
end function

function extraKind(s as dynamic) as string
    s = LCase(pStr(s))
    if s = "trailer" then return "Trailer"
    if s = "behindthescenes" then return "Behind the scenes"
    if s = "deletedscene" then return "Deleted scene"
    if s = "interview" then return "Interview"
    if s = "featurette" then return "Featurette"
    if s = "short" then return "Short"
    if s = "scene" then return "Scene"
    return "Extra"
end function

function trailer() as dynamic
    if m.full = invalid or m.full.Extras = invalid then return invalid
    for each x in m.full.Extras
        if LCase(pStr(x.subtype)) = "trailer" then return x
    end for
    return invalid
end function

' dialogs.brs needs these
sub restoreFocus()
    m.top.setFocus(true)
end sub

sub afterOptions()
    reload()
end sub

sub onOptions()
    hOptionsChosen()
end sub

' the old subtitle picker (subs.brs) calls this after a pick
sub hSubsChanged(label as string)
    reload()
end sub

' menu sound for whatever the handler above took (source/util.brs hKeySfx)
function onKeyEvent(key as string, press as boolean) as boolean
    return hKeySfx(key, press, hKeyInner(key, press))
end function
