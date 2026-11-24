' Requests room data helpers: turn Overseerr JSON into card data. No nodes here, so any layout can use them.
' Card: { kind: "media"|"search"|"music", title, image, chip: { text, icon, tone }, progress (0-100 or -1), data }
' tone: "out" (not requested), "gold" (on its way), "olive" (here), "ember" (problem)

function rqNum(v as dynamic) as integer
    if v = invalid then return -1
    return v
end function

function rqYear(r as object) as string
    d = r.releaseDate
    if d = invalid or d = "" then d = r.firstAirDate
    if d = invalid or Len(d) < 4 then return ""
    return Left(d, 4)
end function

' TMDB image; w185 posters suit 200 x 300 cards on a 720p UI
function rqImage(path as dynamic, size as string) as string
    if path = invalid or path = "" then return ""
    return "https://image.tmdb.org/t/p/" + size + path
end function

function rqChip(text as string, icon as string, tone as string) as object
    return { text: text, icon: icon, tone: tone }
end function

' Overseerr media status: 1 unknown, 2 pending, 3 processing, 4 partly available, 5 available
function rqMediaChip(status as integer) as object
    if status = 2 then return rqChip("Requested", "clock", "gold")
    if status = 3 then return rqChip("Approved", "stamp", "gold")
    if status = 4 then return rqChip("Partly here", "check", "olive")
    if status = 5 then return rqChip("In library", "check", "olive")
    return rqChip("Request", "plus", "out")
end function

' Percent downloaded from Overseerr's downloadStatus list (Sonarr/Radarr queue), or -1
function rqProgress(media as dynamic) as integer
    if media = invalid or media.downloadStatus = invalid or media.downloadStatus.count() = 0 then return -1
    size = 0.0
    left = 0.0
    for each d in media.downloadStatus
        if d.size <> invalid then size = size + d.size
        if d.sizeLeft <> invalid then left = left + d.sizeLeft
    end for
    if size <= 0 then return 0
    return Int((size - left) * 100 / size)
end function

' Download state from Overseerr's downloadStatus (it relays Radarr/Sonarr's queue).
' { pct, stage: "downloading"|"importing", left: "9 min left", n: records } or invalid when nothing is queued
function rqDownload(media as dynamic) as dynamic
    if media = invalid or media.downloadStatus = invalid or media.downloadStatus.count() = 0 then return invalid
    pct = rqProgress(media)
    stage = "downloading"
    secs = 0
    allDone = true
    for each d in media.downloadStatus
        st = d.status
        if st = invalid then st = ""
        if LCase(st) <> "completed" and LCase(st) <> "importpending" and LCase(st) <> "importing" then allDone = false
        tl = d.timeLeft
        if tl <> invalid and (Type(tl) = "roString" or Type(tl) = "String")
            parts = tl.Split(":")
            if parts.count() = 3
                v = parts[0].toInt() * 3600 + parts[1].toInt() * 60 + parts[2].toInt()
                if v > secs then secs = v
            end if
        end if
    end for
    if allDone or pct >= 100 then stage = "importing"
    left = ""
    if stage = "downloading" and secs > 0
        if secs >= 3600
            left = Int(secs / 3600).toStr() + " h " + Int((secs mod 3600) / 60).toStr() + " min left"
        else if secs >= 60
            left = Int(secs / 60).toStr() + " min left"
        else
            left = "under a minute left"
        end if
    end if
    return { pct: pct, stage: stage, left: left, n: media.downloadStatus.count() }
end function

function rqTitle(r as object) as string
    t = r.title
    if t = invalid then t = r.name
    if t = invalid then t = ""
    return t
end function

' A discover or search result
function rqMediaCard(r as object) as object
    status = -1
    if r.mediaInfo <> invalid then status = rqNum(r.mediaInfo.status)
    title = rqTitle(r)
    data = { id: r.id, mediaType: r.mediaType, title: title, year: rqYear(r), overview: r.overview, backdrop: r.backdropPath, poster: r.posterPath, rating: r.voteAverage, mediaStatus: status }
    ' score = the TMDB audience score on the poster; genreIds and date feed the Trending filters
    date = r.releaseDate
    if date = invalid then date = r.firstAirDate
    if date = invalid then date = ""
    return { kind: "media", title: title, image: rqImage(r.posterPath, "w185"), chip: rqMediaChip(status), progress: -1, data: data, score: rqRating(r.voteAverage), vote: r.voteAverage, genreIds: r.genreIds, date: date }
end function

' One of your requests (q) with its title details (info) from OverseerrTask mode "requests".
' Request status: 1 waiting for approval, 2 approved, 3 declined, 4 failed
function rqRequestCard(q as object, info as object) as object
    media = q.media
    ms = -1
    if media <> invalid then ms = rqNum(media.status)
    rs = rqNum(q.status)
    dl = rqDownload(media)
    pct = -1
    if dl <> invalid then pct = dl.pct
    caption = ""
    if rs = 1
        caption = "Waiting for approval"
        chip = rqChip("Waiting approval", "clock", "out")
        note = "Waiting for approval in Overseerr."
    else if rs = 3
        chip = rqChip("Declined", "warn", "ember")
        note = "This request was declined in Overseerr."
    else if rs = 4
        chip = rqChip("Failed", "warn", "ember")
        note = "Overseerr couldn't send this to Radarr or Sonarr. Check Overseerr's Requests page."
    else if ms = 5
        chip = rqChip("Ready · Play", "play", "olive")
        caption = "Ready to watch"
        note = "Ready to watch. Press OK to open it."
    else if ms = 4
        chip = rqChip("Partly ready", "play", "olive")
        caption = "The rest is on the way"
        note = "Some of it is ready to watch; the rest is on the way."
    else if dl <> invalid and dl.stage = "importing"
        chip = rqChip("Importing", "layers", "dim")
        note = "Downloaded. Adding it to Plex now."
        caption = "Adding to Plex"
    else if dl <> invalid
        chip = rqChip("Downloading " + pct.toStr() + "%", "down", "dim")
        note = "Downloading now."
        caption = dl.left
        if dl.n > 1 then caption = dl.n.toStr() + " parts coming. " + dl.left
    else
        chip = rqChip("Searching", "search", "dim")
        note = "Approved. Waiting for a download to start."
        caption = "Looking for a release"
        pct = 0
    end if
    when = rqWhen(q.createdAt)
    if when <> "" then note = "Requested " + when + ". " + note
    title = info.title
    if title = invalid or title = "" then title = "Untitled"
    if info.title = "" and info.detailStatus <> invalid
        note = note + " (Overseerr couldn't load this title: error " + info.detailStatus.toStr() + ".)"
    end if
    data = { id: info.id, mediaType: info.mediaType, title: title, year: rqYear(info), overview: info.overview, backdrop: info.backdropPath, poster: info.posterPath, rating: info.voteAverage, mediaStatus: ms, requestId: q.id, requestStatus: rs, note: note, runtime: info.runtime, seasons: info.numberOfSeasons }
    return { kind: "media", title: title, image: rqImage(info.posterPath, "w185"), chip: chip, progress: pct, caption: caption, active: (dl <> invalid or (rs = 2 and ms <> 5)), data: data }
end function

' "today at 3:52 PM", "Nov 20"
function rqWhen(iso as dynamic) as string
    if iso = invalid or iso = "" then return ""
    dt = CreateObject("roDateTime")
    dt.FromISO8601String(iso)
    dt.ToLocalTime()
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    if dt.GetYear() = now.GetYear() and dt.GetMonth() = now.GetMonth() and dt.GetDayOfMonth() = now.GetDayOfMonth()
        h = dt.GetHours()
        mi = dt.GetMinutes()
        ap = "AM"
        if h >= 12 then ap = "PM"
        h = h mod 12
        if h = 0 then h = 12
        mm = mi.toStr()
        if mi < 10 then mm = "0" + mm
        return "today at " + h.toStr() + ":" + mm + " " + ap
    end if
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return months[dt.GetMonth() - 1] + " " + dt.GetDayOfMonth().toStr()
end function

' Eyebrow: "MOVIE · 2024 · 2H 46M" (+ rating shown with a star icon by the room)
function rqEyebrow(d as object) as string
    if d.mediaType = "tv" then e = "SHOW" else e = "MOVIE"
    if d.year <> invalid and d.year <> "" then e = e + " · " + d.year
    if d.runtime <> invalid and d.runtime > 0
        h = Int(d.runtime / 60)
        mi = d.runtime mod 60
        if h > 0 then e = e + " · " + h.toStr() + "H " + mi.toStr() + "M" else e = e + " · " + mi.toStr() + "M"
    end if
    if d.seasons <> invalid and d.seasons > 0
        s = d.seasons.toStr() + " SEASON"
        if d.seasons > 1 then s = s + "S"
        e = e + " · " + s
    end if
    return e
end function

' "8.2", or "" when TMDB has no votes
function rqRating(v as dynamic) as string
    if v = invalid or v <= 0 then return ""
    x = Int(v * 10 + 0.5)
    return Int(x / 10).toStr() + "." + (x mod 10).toStr()
end function

' Seasons of a show for the picker: [{ number, label, sub, have }] from /api/v1/tv/{id}
function rqSeasons(tv as object) as object
    have = {}
    if tv.mediaInfo <> invalid and tv.mediaInfo.seasons <> invalid
        for each s in tv.mediaInfo.seasons
            st = rqNum(s.status)
            if s.seasonNumber <> invalid and (st = 5 or st = 2 or st = 3) then have[s.seasonNumber.toStr()] = st
        end for
    end if
    out = []
    if tv.seasons = invalid then return out
    for each s in tv.seasons
        n = rqNum(s.seasonNumber)
        if n > 0
            info = ""
            if s.episodeCount <> invalid then info = s.episodeCount.toStr() + " episodes"
            if s.airDate <> invalid and Len(s.airDate) >= 4
                info = info + " · " + Left(s.airDate, 4)
            else
                info = "announced"
            end if
            st = have[n.toStr()]
            tag = ""
            if st <> invalid
                if st = 5 then tag = "In library" else tag = "Requested"
            end if
            out.push({ number: n, label: "Season " + n.toStr(), sub: info, tag: tag, aired: (s.airDate <> invalid and s.airDate <> "") })
        end if
    end for
    return out
end function

' Latest aired season not already here or requested, or -1
function rqLatestSeason(list as object) as integer
    best = -1
    for each s in list
        if s.aired and s.tag = "" and s.number > best then best = s.number
    end for
    return best
end function

' The POST /api/v1/request body as JSON text, written by hand so the key names keep their capitals
' (Overseerr needs "mediaType" and "mediaId" exactly). b: { mediaType, mediaId, seasons: invalid | "all" | [numbers] }
function rqRequestJson(b as object) as string
    q = Chr(34)
    j = "{" + q + "mediaType" + q + ":" + q + b.mediaType + q + "," + q + "mediaId" + q + ":" + b.mediaId.toStr()
    s = b.seasons
    if s <> invalid
        if type(s) = "roString" or type(s) = "String"
            j = j + "," + q + "seasons" + q + ":" + q + s + q
        else
            parts = []
            for each n in s
                parts.push(n.toStr())
            end for
            j = j + "," + q + "seasons" + q + ":[" + parts.join(",") + "]"
        end if
    end if
    return j + "}"
end function

' ---------------------------------------------------------------- New (newly downloaded, from Plex)

' Plex item (PlexTask op "arrived") to a grid card. Episodes stand in for their show. Returns invalid for anything else.
' imgUrl is the poster URL the room built (it knows the Plex server).
function rqArrivedCard(it as object, imgUrl as string) as object
    t = it.Type
    kind = ""
    if t = "Movie" then kind = "movie"
    if t = "Series" or t = "Episode" then kind = "tv"
    if t = "album" then kind = "music"
    if kind = "" then return invalid
    name = it.Name
    if t = "Episode" and it.SeriesName <> invalid then name = it.SeriesName
    if name = invalid then name = ""
    when = rqArrivedWhen(it.AddedAt)
    tone = "out"
    if when.today then tone = "olive"
    data = { item: it, kind: kind, title: name, when: when, year: it.ProductionYear }
    return { kind: "plex", title: name, image: imgUrl, square: (kind = "music"), chip: rqChip(when.band, "down", tone), progress: -1, data: data }
end function

' { band: "TODAY" | "YESTERDAY" | "THU" | "NOV 20", text: "today 3:12 PM" | "yesterday" | "Thursday" | "Nov 20", today }
function rqArrivedWhen(secs as dynamic) as object
    out = { band: "", text: "", today: false }
    if secs = invalid then return out
    dt = CreateObject("roDateTime")
    dt.FromSeconds(secs)
    dt.ToLocalTime()
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    ' whole days between the two local dates
    a = CreateObject("roDateTime")
    a.FromISO8601String(Left(dt.ToISOString(), 10) + "T00:00:00Z")
    b = CreateObject("roDateTime")
    b.FromISO8601String(Left(now.ToISOString(), 10) + "T00:00:00Z")
    days = Int((b.AsSeconds() - a.AsSeconds()) / 86400)
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    if days <= 0
        h = dt.GetHours()
        mi = dt.GetMinutes()
        ap = "AM"
        if h >= 12 then ap = "PM"
        h = h mod 12
        if h = 0 then h = 12
        mm = mi.toStr()
        if mi < 10 then mm = "0" + mm
        return { band: "TODAY", text: "today " + h.toStr() + ":" + mm + " " + ap, today: true }
    end if
    if days = 1 then return { band: "YESTERDAY", text: "yesterday", today: false }
    if days < 7
        wd = dt.GetWeekday()
        return { band: UCase(Left(wd, 3)), text: wd, today: false }
    end if
    md = months[dt.GetMonth() - 1] + " " + dt.GetDayOfMonth().toStr()
    return { band: UCase(md), text: md, today: false }
end function

' "MOVIE · 2024 · ARRIVED TODAY 3:12 PM", "SHOW · ARRIVED YESTERDAY", "ALBUM · BIG THIEF · ARRIVED NOV 20"
function rqArrivedEyebrow(d as object) as string
    e = "ALBUM"
    if d.kind = "movie" then e = "MOVIE"
    if d.kind = "tv" then e = "SHOW"
    it = d.item
    if d.kind = "music" and it.ArtistName <> invalid then e = e + " · " + UCase(it.ArtistName)
    if d.kind = "tv" and it.Type = "Episode" and it.ParentIndexNumber <> invalid and it.IndexNumber <> invalid
        e = e + " · S" + it.ParentIndexNumber.toStr() + " E" + it.IndexNumber.toStr()
    else if d.kind = "tv" and it.SeasonIndex <> invalid
        e = e + " · SEASON " + it.SeasonIndex.toStr()
    end if
    if d.year <> invalid and d.kind <> "music" then e = e + " · " + d.year.toStr()
    if d.when.text <> "" then e = e + " · ARRIVED " + UCase(d.when.text)
    return e
end function
