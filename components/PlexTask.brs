' Plex Media Server + plex.tv requests, normalised to the item shape the screens use:
' { Id, Type (Movie/Series/Episode), Name, SeriesName, SeriesId, IndexNumber, ParentIndexNumber, ProductionYear,
'   Overview, OfficialRating, Genres, RunTimeTicks, UserData: { PlaybackPositionTicks, PlayedPercentage, Played },
'   _img: { Primary, Thumb, Backdrop } (server paths), _media (Plex Media array), LibraryId }

sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    op = m.top.op
    a = m.top.args
    if a = invalid then a = {}
    m.server = m.global.plexServer
    m.token = m.global.plexServerToken
    res = { status: 0, body: invalid }
    out = {}
    if op = "pin.create"
        res = req("POST", "https://plex.tv/api/v2/pins", { strong: "false" }, m.global.plexToken)
        out = res.body
    else if op = "pin.check"
        res = req("GET", "https://plex.tv/api/v2/pins/" + a.id.toStr(), {}, "")
        out = res.body
    else if op = "servers"
        res = req("GET", "https://plex.tv/api/v2/resources", { includeHttps: "1", includeRelay: "0" }, a.token)
        out = {}
        found = false
        list = pickServers(res.body, a.token)
        ' owned servers first, then shared ones; first address that answers wins
        for pass = 0 to 1
            for each sv in list
                if not found and (sv.owned = (pass = 0))
                    for each u in sv.urls
                        if not found
                            r = req("GET", u + "/identity", {}, sv.token, 4000)
                            if r.status = 200
                                found = true
                                out = { name: sv.name, url: u, token: sv.token }
                            end if
                        end if
                    end for
                end if
            end for
        end for
        if res.status = 200 and not found then res.status = 404
    else if op = "check"
        res = req("GET", m.server + "/library/sections", {}, m.token)
    else if op = "libraries"
        res = req("GET", m.server + "/library/sections", {}, m.token)
        libs = []
        for each d in dirs(res.body)
            ct = invalid
            if d.type = "movie" then ct = "movies"
            ' the person's own footage for the Ambiance room; never a Movies shelf
            ' (found by name, either spelling, or by its folder: .../hearth or .../ambiance)
            if isAmbiance(d) then ct = "ambiance"
            if d.type = "show" then ct = "tvshows"
            if d.type = "artist" then ct = "music"
            if d.type = "photo" then ct = "photos"
            print "[plex] library "; d.key; " "; d.title; " type "; d.type; " -> "; ct
            libs.push({ Id: d.key, CollectionType: ct, Name: d.title })
        end for
        out = { Items: libs }
    else if op = "resume" or op = "nextup"
        q = { "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "40" }
        res = req("GET", m.server + "/library/onDeck", q, m.token)
        if res.status <> 200
            res = req("GET", m.server + "/hubs/home/continueWatching", q, m.token)
        end if
        items = []
        for each md in metas(res.body)
            it = norm(md)
            inProgress = (md.viewOffset <> invalid and md.viewOffset > 0)
            want = (op = "resume" and inProgress) or (op = "nextup" and not inProgress and it.Type = "Episode")
            if a.section <> invalid and md.librarySectionID <> invalid and md.librarySectionID.toStr() <> a.section.toStr() then want = false
            if want then items.push(it)
        end for
        out = { Items: limit(items, a.limit) }
    else if op = "latest"
        q = { "X-Plex-Container-Start": "0", "X-Plex-Container-Size": toS(a.limit, "16") }
        path = "/library/recentlyAdded"
        if a.section <> invalid then path = "/library/sections/" + a.section + "/recentlyAdded"
        res = req("GET", m.server + path, q, m.token)
        out = { Items: dedupe(metas(res.body)) }
    else if op = "list"
        q = { "X-Plex-Container-Start": "0", "X-Plex-Container-Size": toS(a.limit, "300") }
        if a.sort <> invalid then q.sort = a.sort
        if a.unwatched = true then q.unwatched = "1"
        if a.genre <> invalid and a.genre <> "" then q.genre = a.genre.toStr()
        if a.decade <> invalid and a.decade <> "" then q.decade = a.decade.toStr()
        res = req("GET", m.server + "/library/sections/" + a.section + "/all", q, m.token)
        out = { Items: normAll(metas(res.body)), Total: total(res.body) }
    else if op = "genres"
        res = req("GET", m.server + "/library/sections/" + a.section + "/genre", {}, m.token)
        gs = []
        for each d in dirs(res.body)
            if d.title <> invalid and d.key <> invalid then gs.push({ name: d.title, key: d.key.toStr() })
        end for
        out = { Genres: gs }
    else if op = "clips"
        ' the Ambiance library: each clip with what the mood screen needs to stream it
        ' With no Ambiance library, look for a folder called hearth/ambiance inside any movie-type library.
        section = toS(a.section, "")
        found = []
        if section <> ""
            res = req("GET", m.server + "/library/sections/" + section + "/all", { "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "60" }, m.token)
            found = metas(res.body)
        else
            res = req("GET", m.server + "/library/sections", {}, m.token)
            found = clipFolders(res.body)
        end if
        print "[ambiance] clips: section '"; section; "' status "; res.status; " items "; found.count()
        clips = []
        for each md in found
            if md.Media <> invalid and md.Media.count() > 0 and md.Media[0].Part <> invalid and md.Media[0].Part.count() > 0
                med = md.Media[0]
                part = med.Part[0]
                f = toS(part.file, "")
                bits = f.split("/")
                if bits.count() > 0 then f = bits[bits.count() - 1]
                clips.push({ Id: md.ratingKey, Name: toS(md.title, f), file: f, key: part.key, container: toS(med.container, ""), videoCodec: toS(med.videoCodec, ""), thumb: md.thumb, art: md.art, duration: md.duration })
            end if
        end for
        out = { Clips: clips }
    else if op = "titles"
        ' just the names in a library, for the search keyboard's predictions
        res = req("GET", m.server + "/library/sections/" + a.section + "/all", { "X-Plex-Container-Start": "0", "X-Plex-Container-Size": toS(a.limit, "5000") }, m.token)
        names = []
        for each md in metas(res.body)
            if md.title <> invalid then names.push(md.title)
        end for
        out = { Names: names }
    else if op = "item"
        q = {}
        ' the details page wants extras (trailers), outside ids (Overseerr), and the show's next episode
        if a.full = true then q = { includeExtras: "1", includeGuids: "1", includeOnDeck: "1", includeConcerts: "0" }
        res = req("GET", m.server + "/library/metadata/" + a.id, q, m.token)
        list = metas(res.body)
        if list.count() > 0
            out = norm(list[0])
            if a.full = true then addDetails(out, list[0])
        end if
    else if op = "seasons"
        res = req("GET", m.server + "/library/metadata/" + a.id + "/children", {}, m.token)
        ss = []
        for each md in metas(res.body)
            if md.type = "season"
                idx = md.index
                if idx = invalid then idx = 0
                ss.push({ Id: md.ratingKey, index: idx, title: toS(md.title, "Season " + idx.toStr()), total: md.leafCount, watched: md.viewedLeafCount, thumb: md.thumb })
            end if
        end for
        out = { Items: ss }
    else if op = "seasonEpisodes"
        ' a season's episodes with what the list shows: date, file flags (hevc = converts on this TV)
        res = req("GET", m.server + "/library/metadata/" + a.id + "/children", {}, m.token)
        eps = []
        for each md in metas(res.body)
            it = norm(md)
            it.aired = toS(md.originallyAvailableAt, "")
            it.flags = mediaFlags(md)
            it.delete("_media")
            eps.push(it)
        end for
        out = { Items: eps }
    else if op = "collection"
        res = req("GET", m.server + "/library/collections/" + a.id + "/children", {}, m.token)
        out = { Items: normAll(metas(res.body)) }
    else if op = "person"
        ' titles in your libraries with this actor (movie and show libraries)
        res = req("GET", m.server + "/library/sections", {}, m.token)
        items = []
        for each d in dirs(res.body)
            if (d.type = "movie" or d.type = "show") and not isAmbiance(d)
                r2 = req("GET", m.server + "/library/sections/" + d.key + "/all", { actor: a.id.toStr(), "X-Plex-Container-Size": "40" }, m.token)
                for each it in normAll(metas(r2.body))
                    items.push(it)
                end for
            end if
        end for
        out = { Items: items }
    else if op = "rate"
        ' 0-10 (stars x2); -1 clears
        res = req("PUT", m.server + "/:/rate", { key: a.id, identifier: "com.plexapp.plugins.library", rating: a.rating.toStr() }, m.token)
    else if op = "playedMany" or op = "unplayedMany"
        verb = "/:/scrobble"
        if op = "unplayedMany" then verb = "/:/unscrobble"
        for each id in a.ids
            res = req("GET", m.server + verb, { key: id, identifier: "com.plexapp.plugins.library" }, m.token)
        end for
    else if op = "setAudio"
        res = req("PUT", m.server + "/library/parts/" + a.part.toStr(), { audioStreamID: a.stream.toStr(), allParts: "1" }, m.token)
    else if op = "matches"
        q = { manual: "1" }
        if a.title <> invalid then q.title = a.title
        if a.year <> invalid then q.year = a.year.toStr()
        res = req("GET", m.server + "/library/metadata/" + a.id + "/matches", q, m.token, 45000)
        found = []
        if res.body <> invalid and res.body.MediaContainer <> invalid and res.body.MediaContainer.SearchResult <> invalid
            for each r in res.body.MediaContainer.SearchResult
                found.push({ guid: r.guid, name: toS(r.name, ""), year: r.year, score: r.score })
            end for
        end if
        out = { Items: found }
    else if op = "match"
        q = { guid: a.guid, name: a.name }
        if a.year <> invalid then q.year = a.year.toStr()
        res = req("PUT", m.server + "/library/metadata/" + a.id + "/match", q, m.token, 45000)
    else if op = "episodes"
        res = req("GET", m.server + "/library/metadata/" + a.id + "/allLeaves", {}, m.token)
        out = { Items: normAll(metas(res.body)) }
    else if op = "similar"
        res = req("GET", m.server + "/library/metadata/" + a.id + "/similar", { "X-Plex-Container-Size": "12" }, m.token)
        list = metas(res.body)
        if list.count() = 0
            r2 = req("GET", m.server + "/library/metadata/" + a.id + "/related", {}, m.token)
            if r2.body <> invalid and r2.body.MediaContainer <> invalid and r2.body.MediaContainer.Hub <> invalid
                for each h in r2.body.MediaContainer.Hub
                    if h.Metadata <> invalid and list.count() = 0 then list = h.Metadata
                end for
            end if
        end if
        out = { Items: limit(normAll(list), 12) }
        if res.status <> 200 then res.status = 200 ' "more like this" is optional
    else if op = "search"
        ' every hub (movies, shows, episodes, artists, albums, tracks), flattened; Type is Movie/Series/Episode or Plex's own type
        res = req("GET", m.server + "/hubs/search", { query: a.query, limit: toS(a.limit, "20") }, m.token)
        items = []
        if res.body <> invalid and res.body.MediaContainer <> invalid and res.body.MediaContainer.Hub <> invalid
            for each h in res.body.MediaContainer.Hub
                if h.Metadata <> invalid
                    for each md in h.Metadata
                        items.push(norm(md))
                    end for
                end if
            end for
        end if
        out = { Items: items }
    else if op = "played" or op = "unplayed"
        ' works for an episode, a whole season or a whole show
        verb = "/:/scrobble"
        if op = "unplayed" then verb = "/:/unscrobble"
        res = req("GET", m.server + verb, { key: a.id, identifier: "com.plexapp.plugins.library" }, m.token)
    else if op = "decision"
        ' ask Plex what it would do with a playback request (copy or convert each stream), without starting it
        res = req("GET", m.server + "/video/:/transcode/universal/decision?" + a.query, {}, m.token)
        out = decisionSummary(res.body)
    else if op = "setSubtitle"
        ' what Plex apps do: remember the chosen subtitle on the server (0 = none), so every player honors it
        res = req("PUT", m.server + "/library/parts/" + a.part.toStr(), { subtitleStreamID: a.stream.toStr(), allParts: "1" }, m.token)
    else if op = "subSearch"
        ' Plex's own subtitle search (OpenSubtitles, https://support.plex.tv/articles/subtitle-search/)
        q = { language: toS(a.language, "en"), hearingImpaired: toS(a.hi, "0"), forced: "0" }
        res = req("GET", m.server + "/library/metadata/" + a.id + "/subtitles", q, m.token, 45000)
        items = []
        if res.body <> invalid and res.body.MediaContainer <> invalid
            mc = res.body.MediaContainer
            if mc.Stream <> invalid then items = mc.Stream
            if items.count() = 0 and mc.Metadata <> invalid then items = mc.Metadata
        end if
        if items.count() > 0 then print "[hearth-subs] Plex result fields: "; FormatJson(items[0])
        out = { Items: items }
    else if op = "subDownload"
        ' Plex downloads in the background; the new stream shows up on the item a few seconds later
        res = req("PUT", m.server + "/library/metadata/" + a.id + "/subtitles", { key: a.key }, m.token)
    else if op = "refresh"
        ' rescans the item so Plex lists a subtitle file Bazarr just saved next to the video
        res = req("PUT", m.server + "/library/metadata/" + a.id + "/refresh", {}, m.token)
    else if op = "timeline"
        q = { ratingKey: a.id, key: "/library/metadata/" + a.id, state: a.state, time: a.time, duration: a.duration, identifier: "com.plexapp.plugins.library" }
        res = req("GET", m.server + "/:/timeline", q, m.token)
    end if
    ' lists don't need the file details; keeping them out saves copying big arrays to the screens
    if out <> invalid and op <> "item" and out.Items <> invalid and type(out.Items) = "roArray"
        for each it in out.Items
            if type(it) = "roAssociativeArray" then it.delete("_media")
        end for
    end if
    m.top.status = res.status
    m.top.ok = (res.status >= 200 and res.status < 300)
    if out = invalid then out = {}
    m.top.response = out
    m.top.done = true
end sub

' Files in a folder named hearth / ambiance / ambience at the top of any movie-type library (Plex's
' "By folder" browse), for when the person hasn't made a separate Ambiance library.
function clipFolders(body as dynamic) as object
    out = []
    for each d in dirs(body)
        if d.type = "movie" and d.key <> invalid
            base = "/library/sections/" + d.key.toStr() + "/folder"
            r = req("GET", m.server + base, {}, m.token)
            for each fd in entries(r.body)
                t = LCase(toS(fd.title, ""))
                if (t = "hearth" or t = "ambiance" or t = "ambience") and fd.key <> invalid
                    k = fd.key.toStr()
                    if Left(k, 1) <> "/" then k = base + "/" + k
                    print "[ambiance] found folder "; t; " in library "; d.title
                    r2 = req("GET", m.server + k, {}, m.token)
                    for each md in entries(r2.body)
                        if md.Media <> invalid then out.push(md)
                    end for
                end if
            end for
        end if
    end for
    return out
end function

' Directory and Metadata entries of a response, together.
function entries(body as dynamic) as object
    out = []
    if body = invalid or body.MediaContainer = invalid then return out
    mc = body.MediaContainer
    if mc.Directory <> invalid then out.append(mc.Directory)
    if mc.Metadata <> invalid then out.append(mc.Metadata)
    return out
end function

function isAmbiance(d as object) as boolean
    t = LCase(toS(d.title, ""))
    if Instr(1, t, "ambiance") > 0 or Instr(1, t, "ambience") > 0 then return true
    if d.Location <> invalid
        for each loc in d.Location
            p = LCase(toS(loc.path, ""))
            if Right(p, 1) = "/" then p = Left(p, Len(p) - 1)
            if Right(p, 7) = "/hearth" or Right(p, 9) = "/ambiance" or Right(p, 9) = "/ambience" then return true
        end for
    end if
    return false
end function

function toS(v as dynamic, fallback as string) as string
    if v = invalid then return fallback
    return v.toStr()
end function

function limit(list as object, n as dynamic) as object
    if n = invalid or list.count() <= n then return list
    out = []
    for i = 0 to n - 1
        out.push(list[i])
    end for
    return out
end function

function req(method as string, url as string, query as object, token as string, timeout = 15000 as integer) as object
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.setMessagePort(port)
    parts = []
    for each k in query
        v = query[k]
        if type(v) <> "roString" and type(v) <> "String" then v = v.toStr()
        parts.push(k + "=" + xfer.Escape(v))
    end for
    if parts.count() > 0
        sep = "?"
        if Instr(1, url, "?") > 0 then sep = "&"
        url = url + sep + parts.join("&")
    end if
    xfer.setUrl(url)
    xfer.addHeader("Accept", "application/json")
    xfer.addHeader("X-Plex-Product", "Hearth")
    xfer.addHeader("X-Plex-Version", "0.2")
    xfer.addHeader("X-Plex-Client-Identifier", m.global.deviceId)
    xfer.addHeader("X-Plex-Platform", "Roku")
    xfer.addHeader("X-Plex-Device", "Roku TV")
    xfer.addHeader("X-Plex-Device-Name", "Hearth")
    if token <> invalid and token <> "" then xfer.addHeader("X-Plex-Token", token)
    xfer.RetainBodyOnError(true)
    if Left(url, 8) = "https://"
        xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        xfer.InitClientCertificates()
    end if
    started = false
    if method = "GET"
        started = xfer.AsyncGetToString()
    else
        xfer.setRequest(method)
        started = xfer.AsyncPostFromString("")
    end if
    status = 0
    text = ""
    if started
        msg = wait(timeout, port)
        if type(msg) = "roUrlEvent"
            status = msg.GetResponseCode()
            text = msg.GetString()
        else
            xfer.AsyncCancel()
            status = -1
        end if
    end if
    body = invalid
    if text <> invalid and text <> "" then body = ParseJson(text)
    return { status: status, body: body }
end function

function metas(body as dynamic) as object
    if body = invalid or body.MediaContainer = invalid then return []
    mc = body.MediaContainer
    if mc.Metadata <> invalid then return mc.Metadata
    if mc.Hub <> invalid and mc.Hub.count() > 0 and mc.Hub[0].Metadata <> invalid then return mc.Hub[0].Metadata
    return []
end function

function total(body as dynamic) as integer
    if body = invalid or body.MediaContainer = invalid then return 0
    mc = body.MediaContainer
    if mc.totalSize <> invalid then return mc.totalSize
    if mc.size <> invalid then return mc.size
    return 0
end function

function dirs(body as dynamic) as object
    if body = invalid or body.MediaContainer = invalid or body.MediaContainer.Directory = invalid then return []
    return body.MediaContainer.Directory
end function

function normAll(list as object) as object
    out = []
    for each md in list
        out.push(norm(md))
    end for
    return out
end function

' recently added gives seasons for new episodes: show them as their series, once
function dedupe(list as object) as object
    out = []
    seen = {}
    for each md in list
        it = norm(md)
        if seen[it.Id] = invalid
            seen[it.Id] = true
            out.push(it)
        end if
    end for
    return out
end function

function ticks(ms as dynamic) as dynamic
    if ms = invalid then return invalid
    t& = ms
    return t& * 10000
end function

function norm(md as object) as object
    t = md.type
    it = { Id: md.ratingKey, Name: md.title, Overview: md.summary, ProductionYear: md.year, OfficialRating: md.contentRating, LibraryId: md.librarySectionID }
    img = { Primary: md.thumb, Thumb: invalid, Backdrop: md.art }
    ' cast and director for the details page (only present on a full item fetch)
    if md.Role <> invalid
        cast = []
        for each role in md.Role
            if cast.count() < 3 and role.tag <> invalid then cast.push(role.tag)
        end for
        it.Cast = cast
    end if
    if md.Director <> invalid
        dirNames = []
        for each dr in md.Director
            if dr.tag <> invalid then dirNames.push(dr.tag)
        end for
        it.Directors = dirNames
    end if
    if t = "movie"
        it.Type = "Movie"
    else if t = "show"
        it.Type = "Series"
        it.SeasonCount = md.childCount
    else if t = "season"
        ' a season stands in for its show
        it.Type = "Series"
        it.Id = md.parentRatingKey
        it.Name = md.parentTitle
        if md.parentThumb <> invalid then img.Primary = md.parentThumb
    else if t = "episode"
        it.Type = "Episode"
        it.SeriesName = md.grandparentTitle
        it.SeriesId = md.grandparentRatingKey
        it.IndexNumber = md.index
        it.ParentIndexNumber = md.parentIndex
        img.Thumb = md.thumb
        img.Primary = md.grandparentThumb
        if md.grandparentArt <> invalid then img.Backdrop = md.grandparentArt
        if img.Backdrop = invalid then img.Backdrop = md.art
    else
        it.Type = t
        it.ArtistName = md.grandparentTitle
        it.ArtistId = md.grandparentRatingKey
        if t = "album"
            it.ArtistName = md.parentTitle
            it.ArtistId = md.parentRatingKey
        end if
        if t = "track" then it.AlbumId = md.parentRatingKey
    end if
    if md.Genre <> invalid
        g = []
        for each x in md.Genre
            g.push(x.tag)
        end for
        it.Genres = g
    end if
    it.RunTimeTicks = ticks(md.duration)
    if md.titleSort <> invalid then it.SortName = md.titleSort else it.SortName = md.title
    ud = { Played: false, PlayedPercentage: 0 }
    if md.viewOffset <> invalid and md.viewOffset > 0
        ud.PlaybackPositionTicks = ticks(md.viewOffset)
        if md.duration <> invalid and md.duration > 0 then ud.PlayedPercentage = 100.0 * md.viewOffset / md.duration
    end if
    if md.viewCount <> invalid and md.viewCount > 0 then ud.Played = true
    if t = "show" and md.leafCount <> invalid and md.viewedLeafCount <> invalid and md.leafCount > 0 and md.leafCount = md.viewedLeafCount then ud.Played = true
    it.UserData = ud
    it._img = img
    if md.Media <> invalid then it._media = md.Media
    return it
end function

' Extra fields for the details page, from a full item fetch (includeExtras/includeGuids/includeOnDeck).
sub addDetails(it as object, md as object)
    it.Ratings = ratings(md)
    it.UserRating = md.userRating
    it.Studio = md.studio
    it.Aired = toS(md.originallyAvailableAt, "")
    it.LeafCount = md.leafCount
    it.ViewedLeafCount = md.viewedLeafCount
    people = []
    if md.Role <> invalid
        for each r in md.Role
            people.push({ id: r.id, name: toS(r.tag, ""), role: toS(r.role, ""), thumb: r.thumb })
        end for
    end if
    if md.Director <> invalid
        for each r in md.Director
            people.push({ id: r.id, name: toS(r.tag, ""), role: "Director", thumb: r.thumb, crew: true })
        end for
    end if
    if md.Writer <> invalid
        for each r in md.Writer
            if people.count() < 60 then people.push({ id: r.id, name: toS(r.tag, ""), role: "Writer", thumb: r.thumb, crew: true })
        end for
    end if
    it.People = people
    cols = []
    if md.Collection <> invalid
        for each c in md.Collection
            cols.push({ id: c.id, name: toS(c.tag, "") })
        end for
    end if
    it.Collections = cols
    ids = {}
    if type(md.Guid) = "roArray"
        for each g in md.Guid
            if type(g) = "roAssociativeArray"
                bits = toS(g.id, "").split("://")
                if bits.count() = 2 then ids[bits[0]] = bits[1]
            end if
        end for
    end if
    it.Ids = ids
    extras = []
    if md.Extras <> invalid and md.Extras.Metadata <> invalid
        for each x in md.Extras.Metadata
            e = norm(x)
            e.Type = "Extra"
            e.subtype = toS(x.subtype, "")
            e._img = { Primary: x.thumb, Thumb: x.thumb, Backdrop: x.art }
            e.delete("_media")
            extras.push(e)
        end for
    end if
    it.Extras = extras
    if md.OnDeck <> invalid and md.OnDeck.Metadata <> invalid and md.OnDeck.Metadata.count() > 0
        od = norm(md.OnDeck.Metadata[0])
        od.delete("_media")
        it.OnDeck = od
    end if
    if md.Location <> invalid and md.Location.count() > 0 then it.Folder = toS(md.Location[0].path, "")
end sub

' IMDb / TMDB / Rotten Tomatoes scores, whichever Plex has: [{ label, text }]
function ratings(md as object) as object
    out = []
    seen = {}
    list = []
    ' ParseJson keys can be read case-blind on some firmware, so "Rating" (list) and "rating" (number) are told apart by type
    if type(md.Rating) = "roArray" then list = md.Rating
    if list.count() = 0
        if md.rating <> invalid and type(md.rating) <> "roArray" then list.push({ image: toS(md.ratingImage, ""), value: md.rating, type: "critic" })
        if md.audienceRating <> invalid then list.push({ image: toS(md.audienceRatingImage, ""), value: md.audienceRating, type: "audience" })
    end if
    for each r in list
        img = LCase(toS(r.image, ""))
        v = r.value
        if v <> invalid
            label = ""
            text = ""
            if Instr(1, img, "imdb") > 0
                label = "IMDb" : text = fmt1(v)
            else if Instr(1, img, "rottentomatoes") > 0
                if r.type = "audience" then label = "Audience" else label = "Critics"
                text = Int(v * 10 + 0.5).toStr() + "%"
            else if Instr(1, img, "themoviedb") > 0
                label = "TMDB" : text = fmt1(v)
            else if Instr(1, img, "thetvdb") > 0
                label = "TVDB" : text = fmt1(v)
            end if
            if label <> "" and seen[label] = invalid
                seen[label] = true
                out.push({ label: label, text: text })
            end if
        end if
    end for
    return out
end function

function fmt1(v as dynamic) as string
    n = Int(v * 10 + 0.5)
    return (n \ 10).toStr() + "." + (n mod 10).toStr()
end function

' Small per-file flags for list rows: { hevc, res, audio }
function mediaFlags(md as object) as object
    f = { hevc: false, res: "", audio: "" }
    if md.Media <> invalid and md.Media.count() > 0
        med = md.Media[0]
        vc = LCase(toS(med.videoCodec, ""))
        f.hevc = (vc = "hevc" or vc = "h265")
        f.res = toS(med.videoResolution, "")
        f.audio = toS(med.audioCodec, "")
    end if
    return f
end function

' Servers this account can use, best connection first: local plain http, then the rest.
function pickServers(body as dynamic, token as string) as object
    out = []
    if body = invalid or type(body) <> "roArray" then return out
    for each r in body
        if r.provides <> invalid and Instr(1, r.provides, "server") > 0 and r.connections <> invalid
            urls = []
            for each c in r.connections
                if c.local = true and c.address <> invalid then urls.push("http://" + c.address + ":" + c.port.toStr())
            end for
            for each c in r.connections
                if c.uri <> invalid then urls.push(c.uri)
            end for
            tok = r.accessToken
            if tok = invalid then tok = token
            out.push({ name: r.name, owned: (r.owned = true), token: tok, urls: urls })
        end if
    end for
    return out
end function

' Plex's playback decision, flattened: { general, video, audio, subtitle } where each stream says copy, transcode or burn
function decisionSummary(body as dynamic) as object
    out = { general: "", video: "", audio: "", subtitle: "", videoCodec: "", audioCodec: "", subtitleCodec: "" }
    if body = invalid or body.MediaContainer = invalid then return out
    mc = body.MediaContainer
    if mc.generalDecisionText <> invalid then out.general = mc.generalDecisionText
    if mc.transcodeDecisionText <> invalid then out.general = out.general + " / " + mc.transcodeDecisionText
    if mc.Metadata = invalid or mc.Metadata.count() = 0 then return out
    md = mc.Metadata[0]
    if md.Media = invalid or md.Media.count() = 0 or md.Media[0].Part = invalid or md.Media[0].Part.count() = 0 then return out
    pt = md.Media[0].Part[0]
    if pt.Stream = invalid then return out
    for each s in pt.Stream
        d = toS(s.decision, "copy")
        cd = toS(s.codec, "")
        if s.streamType = 1 then out.video = d : out.videoCodec = cd
        if s.streamType = 2 then out.audio = d : out.audioCodec = cd
        if s.streamType = 3 then out.subtitle = d : out.subtitleCodec = cd
    end for
    return out
end function
