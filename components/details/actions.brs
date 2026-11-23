' Details page actions: play, watched marks, the side sheets (More, episode options, audio, file info,
' fix match, a person's titles, season requests), Bazarr missing subtitles and the subtitle finder.

sub runAction(a as string, ep = invalid as dynamic)
    tgt = m.target
    if ep <> invalid then tgt = ep
    if a = "resume" and tgt <> invalid
        m.top.request = { action: "play", item: tgt, resume: true }
    else if a = "restart" and tgt <> invalid
        m.top.request = { action: "play", item: tgt, resume: false }
    else if a = "trailer"
        t = trailer()
        if t <> invalid then m.top.request = { action: "play", item: t, resume: false }
    else if a = "subs" and tgt <> invalid
        openFinder(tgt)
    else if a = "audio" and tgt <> invalid
        withFull(tgt, "audio")
    else if a = "fileinfo" and tgt <> invalid
        withFull(tgt, "fileinfo")
    else if a = "watchAll"
        hPlex("played", { id: m.full.Id }, "onChanged")
    else if a = "unwatchAll"
        hPlex("unplayed", { id: m.full.Id }, "onChanged")
    else if a = "more"
        openMore()
    else if a = "shuffle"
        hPlex("episodes", { id: m.full.Id }, "onShuffleList")
    else if a = "playSeason"
        if m.eps.count() > 0 then playQueue(m.eps)
    else if a = "fetchMissing"
        fetchMissing()
    end if
end sub

sub onChanged(event as object)
    hTaskFrom(event)
    reload()
end sub

' ---------------------------------------------------------------- queues (shuffle, season from the start)

sub onShuffleList(event as object)
    t = hTaskFrom(event)
    if not t.ok or t.response.Items.count() = 0 then return
    list = t.response.Items
    ' Fisher-Yates, then keep 60 so the queue stays small
    for i = list.count() - 1 to 1 step -1
        j = Rnd(i + 1) - 1
        x = list[i]
        list[i] = list[j]
        list[j] = x
    end for
    q = []
    for i = 0 to list.count() - 1
        if i < 60 then q.push(list[i])
    end for
    playQueue(q)
end sub

sub playQueue(list as object)
    rest = []
    for i = 1 to list.count() - 1
        rest.push(list[i])
    end for
    m.top.request = { action: "play", item: list[0], resume: false, queue: rest }
end sub

' ---------------------------------------------------------------- More (side sheet A)

sub openMore()
    rows = []
    s = invalid
    if m.isShow and m.sIdx >= 0 and m.sIdx < m.seasons.count() then s = m.seasons[m.sIdx]
    sName = ""
    if s <> invalid
        if s.index = 0 then sName = "specials" else sName = "season " + s.index.toStr()
    end if
    if m.isShow
        rows.push({ header: "Play" })
        rows.push({ icon: "shuffle", label: "Shuffle the show", action: "shuffle" })
        if s <> invalid then rows.push({ icon: "restart", label: "Play " + sName + " from the start", sub: countText(s.total, "episode"), action: "playSeason" })
    end if
    rows.push({ header: "Watched" })
    if m.isShow
        if s <> invalid
            if s.total <> invalid and s.watched <> invalid and s.watched >= s.total and s.total > 0
                rows.push({ icon: "restart", label: "Mark " + sName + " unwatched", action: "seasonUnwatched", data: s })
            else
                rows.push({ icon: "eye", label: "Mark " + sName + " watched", action: "seasonWatched", data: s })
            end if
        end if
        if m.eps.count() > 0 and m.epSel < m.eps.count()
            ep = m.eps[m.epSel]
            rows.push({ icon: "upto", label: "Watched up to S" + hNum(ep.ParentIndexNumber) + " E" + hNum(ep.IndexNumber), action: "upTo", data: ep })
        end if
        if isPlayed(m.full)
            rows.push({ icon: "restart", label: "Mark whole show unwatched", action: "unwatchAll" })
        else
            rows.push({ icon: "checkc", label: "Mark whole show watched", sub: countText(m.full.SeasonCount, "season"), action: "watchAll" })
        end if
    else
        if isPlayed(m.full)
            rows.push({ icon: "restart", label: "Mark unwatched", action: "unwatchAll" })
        else
            rows.push({ icon: "checkc", label: "Mark watched", action: "watchAll" })
        end if
    end if
    rows.push({ header: "Library" })
    if m.isShow then rows.push({ icon: "plus", label: "Request more seasons", sub: "Overseerr", action: "requestSeasons" })
    miss = missingInSeason()
    if miss.count() > 0 then rows.push({ icon: "ccx", label: "Find missing subtitles", sub: countText(miss.count(), "missing"), action: "fetchMissing" })
    stars = 0
    if m.full.UserRating <> invalid then stars = Int(m.full.UserRating / 2 + 0.5)
    rows.push({ icon: "star", label: "Your rating", stars: stars, action: "rate" })
    if m.target <> invalid then rows.push({ icon: "file", label: "File info", sub: fileSub(m.targetFull), action: "fileinfo" })
    rows.push({ icon: "refresh", label: "Refresh metadata", action: "refresh" })
    rows.push({ icon: "wand", label: "Fix match", action: "fixMatch" })
    showSheet("More for " + hTitle(m.full), "more", "", rows)
end sub

function countText(n as dynamic, noun as string) as string
    if n = invalid then return ""
    if noun = "missing" then return n.toStr() + " missing"
    if n = 1 then return "1 " + noun
    return n.toStr() + " " + noun + "s"
end function

function fileSub(it as dynamic) as string
    if it = invalid or it._media = invalid or it._media.count() = 0 then return ""
    md = it._media[0]
    parts = []
    r = resText(md.videoResolution)
    if r <> "" then parts.push(r)
    if md.videoCodec <> invalid then parts.push(codecText(md.videoCodec))
    if md.Part <> invalid and md.Part.count() > 0 and md.Part[0].size <> invalid then parts.push(sizeText(md.Part[0].size))
    return parts.join(" · ")
end function

function sizeText(b as dynamic) as string
    gb = b / 1073741824.0
    if gb >= 1
        n = Int(gb * 10 + 0.5)
        return (n \ 10).toStr() + "." + (n mod 10).toStr() + " GB"
    end if
    return Int(b / 1048576).toStr() + " MB"
end function

' ---------------------------------------------------------------- episode options (* or Right on a row)

sub openEpisodeSheet(ep as object)
    rows = []
    rows.push({ header: "S" + hNum(ep.ParentIndexNumber) + " E" + hNum(ep.IndexNumber) })
    if hPercent(ep) > 0 and not isPlayed(ep)
        rows.push({ icon: "play", label: "Resume", sub: hMinutesLeft(ep), action: "epResume", data: ep })
        rows.push({ icon: "restart", label: "Play from the start", action: "epRestart", data: ep })
    else
        rows.push({ icon: "play", label: "Play", action: "epRestart", data: ep })
    end if
    rows.push({ icon: "cc", label: "Subtitles", sub: "Pick or find more", action: "epSubs", data: ep })
    rows.push({ icon: "audio", label: "Audio track", action: "epAudio", data: ep })
    if isPlayed(ep)
        rows.push({ icon: "restart", label: "Mark unwatched", action: "epUnwatched", data: ep })
    else
        rows.push({ icon: "check", label: "Mark watched", action: "epWatched", data: ep })
    end if
    rows.push({ icon: "upto", label: "Watched up to here", action: "upTo", data: ep })
    rows.push({ icon: "file", label: "File info", action: "epFile", data: ep })
    t = ep.Name
    if t = invalid then t = "Episode"
    showSheet(t, "tv", "", rows)
end sub

' ---------------------------------------------------------------- the sheet

sub showSheet(heading as string, icon as string, note as string, rows as object)
    m.sheet.heading = heading
    m.sheet.icon = icon
    m.sheet.note = note
    m.sheet.rows = rows
    m.sheet.callFunc("open", invalid)
end sub

sub onSheetClosed()
    ' a pick may have opened the next sheet (or the finder) already
    if not m.sheet.visible and not m.finder.visible then m.top.setFocus(true)
end sub

sub onSheetResult()
    r = m.sheet.result
    if r = invalid or r.action = invalid then return
    a = r.action
    d = r.data
    if a = "seasonWatched"
        hPlex("played", { id: d.Id }, "onChanged")
    else if a = "seasonUnwatched"
        hPlex("unplayed", { id: d.Id }, "onChanged")
    else if a = "upTo"
        upTo(d)
    else if a = "rate"
        v = r.stars * 2
        if r.stars = 0 then v = -1
        hPlex("rate", { id: m.full.Id, rating: v }, "onChanged")
    else if a = "refresh"
        hPlex("refresh", { id: m.full.Id }, "onRefreshing")
    else if a = "fixMatch"
        y = m.full.ProductionYear
        hPlex("matches", { id: m.full.Id, title: m.full.Name, year: y }, "onMatches")
        showSheet("Fix match", "wand", "Asking Plex for matches…", [])
    else if a = "match"
        hPlex("match", { id: m.full.Id, guid: d.guid, name: d.name, year: d.year }, "onChanged")
    else if a = "requestSeasons"
        requestSeasons()
    else if a = "requestPick"
        sendRequest(d)
    else if a = "epResume"
        runAction("resume", d)
    else if a = "epRestart"
        runAction("restart", d)
    else if a = "epSubs"
        openFinder(d)
    else if a = "epAudio"
        withFull(d, "audio")
    else if a = "epFile"
        withFull(d, "fileinfo")
    else if a = "epWatched"
        hPlex("played", { id: d.Id }, "onChanged")
    else if a = "epUnwatched"
        hPlex("unplayed", { id: d.Id }, "onChanged")
    else if a = "pickAudio"
        hPlex("setAudio", { part: d.part, stream: d.stream }, "onChanged")
    else if a = "openTitle"
        m.top.request = { action: "details", item: d }
    else
        runAction(a)
    end if
end sub

' Everything before this episode (earlier seasons, then this season up to it) marked watched.
sub upTo(ep as object)
    ids = []
    for each s in m.seasons
        if s.index > 0 and ep.ParentIndexNumber <> invalid and s.index < ep.ParentIndexNumber then ids.push(s.Id)
    end for
    for each e in m.eps
        if e.ParentIndexNumber = ep.ParentIndexNumber and e.IndexNumber <> invalid and ep.IndexNumber <> invalid and e.IndexNumber <= ep.IndexNumber then ids.push(e.Id)
    end for
    if ids.count() = 0 then ids.push(ep.Id)
    hPlex("playedMany", { ids: ids }, "onChanged")
end sub

sub onRefreshing(event as object)
    hTaskFrom(event)
    hMessage("Refreshing", "Plex is fetching fresh details and artwork. The page reloads in a few seconds.")
    m.later.control = "start"
end sub

sub onLater()
    reload()
end sub

sub onMatches(event as object)
    t = hTaskFrom(event)
    rows = []
    if t.ok
        for each x in t.response.Items
            lab = x.name
            if x.year <> invalid then lab = lab + " (" + x.year.toStr() + ")"
            sc = ""
            if x.score <> invalid then sc = x.score.toStr() + "% match"
            rows.push({ icon: "wand", label: lab, sub: sc, action: "match", data: x })
        end for
    end if
    note = "Pick the right title. Plex re-downloads its details."
    if rows.count() = 0 then note = "Plex found no other matches."
    showSheet("Fix match", "wand", note, rows)
end sub

' ---------------------------------------------------------------- the full item (streams) for audio / file info

sub withFull(it as object, purpose as string)
    if it._media <> invalid
        fullReady(it, purpose)
        return
    end if
    m.fullPurpose = purpose
    hPlex("item", { id: it.Id }, "onWithFull")
end sub

sub onWithFull(event as object)
    t = hTaskFrom(event)
    if t.ok and t.response.Id <> invalid then fullReady(t.response, m.fullPurpose)
end sub

sub fullReady(it as object, purpose as string)
    if it._media = invalid or it._media.count() = 0 then return
    md = it._media[0]
    part = invalid
    if md.Part <> invalid and md.Part.count() > 0 then part = md.Part[0]
    if purpose = "audio"
        rows = []
        if part <> invalid and part.Stream <> invalid
            st = hPlayStreams(part)
            for each s in part.Stream
                if s.streamType = 2
                    lab = s.displayTitle
                    if lab = invalid then lab = pStr(s.language) + " " + channelsText(s.channels)
                    sub2 = ""
                    if s.title <> invalid and s.title <> lab then sub2 = s.title
                    sel = (st.audio <> invalid and st.audio.id = s.id)
                    c = LCase(pStr(s.codec))
                    if c = "truehd" or c = "dca" or Left(c, 3) = "dts" or c = "flac"
                        if sub2 <> "" then sub2 = sub2 + " · "
                        sub2 = sub2 + "converts"
                    end if
                    rows.push({ icon: "audio", label: lab, sub: sub2, checked: sel, action: "pickAudio", data: { part: part.id, stream: s.id } })
                end if
            end for
        end if
        showSheet("Audio", "audio", hTitle(it) + "  ·  " + hSubtitle(it), rows)
    else
        showSheet("File info", "file", hTitle(it) + "  ·  " + hSubtitle(it), fileRows(it, md, part))
    end if
end sub

function fileRows(it as object, md as object, part as dynamic) as object
    rows = []
    rows.push({ header: "File" })
    if part <> invalid
        f = pStr(part.file)
        bits = f.split("/")
        if bits.count() > 0 then f = bits[bits.count() - 1]
        rows.push({ icon: "file", label: f })
        if part.size <> invalid then rows.push({ icon: "info", label: "Size", sub: sizeText(part.size) })
    end if
    rows.push({ icon: "info", label: "Container", sub: UCase(pStr(md.container)) })
    if md.bitrate <> invalid then rows.push({ icon: "info", label: "Bitrate", sub: (md.bitrate / 1000).toStr() + " Mbps" })
    st = hPlayStreams(part)
    d = hPlayDirectCheck(md, st)
    how = "Plays directly"
    if not d.ok then how = "Converts: " + d.why
    rows.push({ icon: "leaf", label: "On this TV", sub: how })
    if part <> invalid and part.Stream <> invalid
        rows.push({ header: "Video" })
        for each s in part.Stream
            if s.streamType = 1 then rows.push({ icon: "film", label: pStr(s.displayTitle), sub: pStr(s.profile) })
        end for
        rows.push({ header: "Audio" })
        for each s in part.Stream
            if s.streamType = 2 then rows.push({ icon: "audio", label: pStr(s.displayTitle), checked: s.selected = true })
        end for
        subs = []
        for each s in part.Stream
            if s.streamType = 3 then subs.push(s)
        end for
        if subs.count() > 0
            rows.push({ header: "Subtitles" })
            for each s in subs
                where = "in the file"
                if s.key <> invalid then where = "separate file"
                rows.push({ icon: "cc", label: pStr(s.displayTitle), sub: where, checked: s.selected = true })
            end for
        end if
    end if
    return rows
end function

' ---------------------------------------------------------------- people

sub openPerson(p as object)
    m.personName = p.Name
    hPlex("person", { id: p.Id }, "onPerson")
    showSheet(p.Name, "person", "Looking in your libraries…", [])
end sub

sub onPerson(event as object)
    t = hTaskFrom(event)
    rows = []
    if t.ok
        for each x in t.response.Items
            ic = "film"
            if x.Type = "Series" then ic = "tv"
            sub2 = ""
            if x.ProductionYear <> invalid then sub2 = x.ProductionYear.toStr()
            if x.Id <> m.full.Id then rows.push({ icon: ic, label: x.Name, sub: sub2, action: "openTitle", data: x })
        end for
    end if
    note = "Also in your libraries"
    if rows.count() = 0 then note = "Nothing else of theirs in your libraries."
    showSheet(m.personName, "person", note, rows)
end sub

' ---------------------------------------------------------------- Overseerr: request more seasons

sub requestSeasons()
    ids = m.full.Ids
    if ids = invalid or ids.tmdb = invalid
        hMessage("Request more seasons", "Plex doesn't have a TMDB id for this show, so Overseerr can't look it up. Try Fix match first.")
        return
    end if
    m.tmdbId = ids.tmdb
    overseerr("GET", "/api/v1/tv/" + ids.tmdb, "", "onOverseerrShow")
    showSheet("Request more seasons", "plus", "Asking Overseerr…", [])
end sub

sub overseerr(method as string, path as string, body as string, cb as string)
    t = CreateObject("roSGNode", "OverseerrTask")
    t.mode = "call"
    t.method = method
    t.path = path
    if body <> "" then t.bodyText = body
    t.observeField("done", cb)
    m.oTask = t
    t.control = "RUN"
end sub

sub onOverseerrShow(event as object)
    t = event.getRoSGNode()
    m.oTask = invalid
    if not t.ok
        m.sheet.callFunc("close", invalid)
        if t.status = 401 or t.status = 403
            hMessage("Request more seasons", "Overseerr refused the key. Set it again from the Requests room.")
        else
            hMessage("Request more seasons", "Couldn't reach Overseerr (" + t.status.toStr() + ").")
        end if
        return
    end if
    d = t.response
    have = {}
    if d.mediaInfo <> invalid and d.mediaInfo.seasons <> invalid
        for each s in d.mediaInfo.seasons
            ' 2 pending, 3 processing, 4 partly available, 5 available
            if s.status <> invalid and s.status >= 2 then have[s.seasonNumber.toStr()] = s.status
        end for
    end if
    if d.mediaInfo <> invalid and d.mediaInfo.requests <> invalid
        for each q in d.mediaInfo.requests
            if q.seasons <> invalid
                for each s in q.seasons
                    if have[s.seasonNumber.toStr()] = invalid then have[s.seasonNumber.toStr()] = 2
                end for
            end if
        end for
    end if
    ' what Plex already has counts too
    for each s in m.seasons
        if have[s.index.toStr()] = invalid then have[s.index.toStr()] = 5
    end for
    missing = []
    if d.seasons <> invalid
        for each s in d.seasons
            if s.seasonNumber <> invalid and s.seasonNumber > 0 and have[s.seasonNumber.toStr()] = invalid then missing.push(s)
        end for
    end if
    rows = []
    if missing.count() > 1
        nums = []
        for each s in missing
            nums.push(s.seasonNumber)
        end for
        rows.push({ icon: "plus", label: "All " + missing.count().toStr() + " missing seasons", action: "requestPick", data: { seasons: nums } })
    end if
    for each s in missing
        sub2 = ""
        if s.episodeCount <> invalid then sub2 = countText(s.episodeCount, "episode")
        if s.airDate <> invalid and Len(s.airDate) >= 4 then sub2 = sub2 + " · " + Left(s.airDate, 4)
        rows.push({ icon: "plus", label: "Season " + s.seasonNumber.toStr(), sub: sub2, action: "requestPick", data: { seasons: [s.seasonNumber] } })
    end for
    note = "Seasons you don't have yet"
    if rows.count() = 0 then note = "Every season is already here or requested."
    showSheet("Request more seasons", "plus", note, rows)
end sub

sub sendRequest(d as object)
    body = FormatJson({ mediaType: "tv", mediaId: m.tmdbId.toInt(), seasons: d.seasons })
    overseerr("POST", "/api/v1/request", body, "onRequested")
end sub

sub onRequested(event as object)
    t = event.getRoSGNode()
    m.oTask = invalid
    if t.ok
        hMessage("Requested", "Overseerr has the request. It shows in the Requests room.")
    else
        hMessage("Request more seasons", "Overseerr said no (" + t.status.toStr() + ").")
    end if
end sub

' ---------------------------------------------------------------- Bazarr: missing subtitles

function bazarrOn() as boolean
    return CreateObject("roRegistrySection", "hearth").Read("bazarrKey") <> ""
end function

sub bazarr(op as string, args as object, cb as string)
    t = CreateObject("roSGNode", "BazarrTask")
    t.op = op
    t.args = args
    t.observeField("done", cb)
    if m.bzTasks = invalid then m.bzTasks = []
    m.bzTasks.push(t)
    t.control = "RUN"
end sub

sub loadBazarrShow()
    if not bazarrOn() then return
    folder = m.full.Folder
    if folder = invalid then folder = ""
    bazarr("missing", { folder: folder, series: m.full.Name }, "onMissing")
end sub

sub loadBazarrMovie()
    if not bazarrOn() then return
    f = ""
    if m.full._media <> invalid and m.full._media.count() > 0 and m.full._media[0].Part <> invalid then f = pStr(m.full._media[0].Part[0].file)
    bazarr("missing", { movie: true, file: f, title: m.full.Name, year: m.full.ProductionYear }, "onMissing")
end sub

sub onMissing(event as object)
    t = event.getRoSGNode()
    if not t.ok
        print "[hearth-details] Bazarr missing: "; t.error
        return
    end if
    r = t.response
    m.bz = r
    m.missing = {}
    if r.missing <> invalid then m.missing = r.missing
    refreshRows()
    drawChips()
    if m.targetFull <> invalid then fillTags()
    paint()
end sub

' "No English" for the item (movie, or an episode), from Bazarr
function missingFor(it as object) as string
    langs = invalid
    if it.Type = "Episode" and it.ParentIndexNumber <> invalid and it.IndexNumber <> invalid
        langs = m.missing[it.ParentIndexNumber.toStr() + "-" + it.IndexNumber.toStr()]
    else if it.Type = "Movie"
        langs = m.missing["movie"]
    end if
    if langs = invalid or langs.count() = 0 then return ""
    return "No " + langs[0].name
end function

' The missing languages in the open season (or the movie): [{ episode, code2, hi, forced, name }]
function missingInSeason() as object
    out = []
    if m.bz = invalid then return out
    if m.isShow <> true
        langs = m.missing["movie"]
        if langs <> invalid then out = langs
        return out
    end if
    for each ep in m.eps
        if ep.ParentIndexNumber <> invalid and ep.IndexNumber <> invalid
            langs = m.missing[ep.ParentIndexNumber.toStr() + "-" + ep.IndexNumber.toStr()]
            if langs <> invalid
                for each l in langs
                    out.push(l)
                end for
            end if
        end if
    end for
    return out
end function

sub fetchMissing()
    list = missingInSeason()
    if list.count() = 0 or m.bz = invalid then return
    args = { kind: m.bz.kind, list: list }
    if m.bz.kind = "movie" then args.movie = m.bz.movie else args.series = m.bz.series
    bazarr("fetchMissing", args, "onFetchedMissing")
    hMessage("Finding subtitles", "Bazarr is searching for " + countText(list.count(), "subtitle") + ". This can take a minute; the page updates when it's done.")
end sub

sub onFetchedMissing(event as object)
    t = event.getRoSGNode()
    n = 0
    if t.response <> invalid and t.response.fetched <> invalid then n = t.response.fetched
    ' Plex has to look at the folder again to list the new files
    id = m.full.Id
    if m.isShow and m.sIdx >= 0 then id = m.seasons[m.sIdx].Id
    hPlex("refresh", { id: id }, "onRefreshAfterSubs")
    print "[hearth-details] Bazarr fetched "; n
end sub

sub onRefreshAfterSubs(event as object)
    hTaskFrom(event)
    if m.isShow then loadBazarrShow() else loadBazarrMovie()
    m.later.control = "start"
end sub

' ---------------------------------------------------------------- subtitle finder (components/subs/SubsFinder)

sub openFinder(it as object)
    if it._media = invalid
        hPlex("item", { id: it.Id }, "onFinderItem")
        return
    end if
    m.finderChanged = false
    m.finder.item = it
    m.finder.callFunc("open", invalid)
end sub

sub onFinderItem(event as object)
    t = hTaskFrom(event)
    if t.ok and t.response <> invalid and t.response.Id <> invalid then openFinder(t.response)
end sub

sub onFinderResult()
    m.finderChanged = true
end sub

sub onFinderClosed()
    m.top.setFocus(true)
    if m.finderChanged then reload()
end sub
