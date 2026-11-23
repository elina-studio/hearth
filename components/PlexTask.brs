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
        res = req("GET", m.server + "/library/sections/" + a.section + "/all", { "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "60" }, m.token)
        clips = []
        for each md in metas(res.body)
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
        res = req("GET", m.server + "/library/metadata/" + a.id, {}, m.token)
        list = metas(res.body)
        if list.count() > 0 then out = norm(list[0])
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
        verb = "/:/scrobble"
        if op = "unplayed" then verb = "/:/unscrobble"
        res = req("GET", m.server + verb, { key: a.id, identifier: "com.plexapp.plugins.library" }, m.token)
    else if op = "decision"
        ' ask Plex what it would do with a playback request (copy or convert each stream), without starting it
        res = req("GET", m.server + "/video/:/transcode/universal/decision?" + a.query, {}, m.token)
        out = decisionSummary(res.body)
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
