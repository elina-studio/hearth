' Plex helpers for the Music room. Sign-in lives in the app shell, which fills
' m.global.plexServer and m.global.plexServerToken (client id is m.global.deviceId).

function pxReady() as boolean
    g = m.global
    if not g.hasField("plexServer") or not g.hasField("plexServerToken") then return false
    return g.plexServer <> invalid and g.plexServer <> "" and g.plexServerToken <> invalid and g.plexServerToken <> ""
end function

function pxServer() as string
    s = m.global.plexServer
    if Right(s, 1) = "/" then s = Left(s, Len(s) - 1)
    return s
end function

function pxToken() as string
    return m.global.plexServerToken
end function

function pxEscape(s as string) as string
    return hEscape(s)
end function

' Start a Plex call. path is a server path such as /library/sections. cb takes the event.
function pxApi(path as string, query as object, cb as string, tag = "" as string, method = "GET" as string) as object
    t = CreateObject("roSGNode", "MusicPlexTask")
    t.method = method
    ' the query is built here, not passed as an assocarray: keys lose their capitals crossing into a Task
    ' (X-Plex-Container-Size would arrive as x-plex-container-size and Plex would ignore it)
    url = pxServer() + path
    qs = pxQuery(query)
    if qs <> ""
        if Instr(1, url, "?") > 0 then url = url + "&" + qs else url = url + "?" + qs
    end if
    t.url = url
    t.tag = tag
    t.observeField("done", cb)
    if m.hTasks = invalid then m.hTasks = {}
    key = "p" + Rnd(1000000).toStr()
    m.hTasks[key] = t
    t.key = key
    t.control = "RUN"
    return t
end function

function pxQuery(q as object) as string
    if q = invalid or q.Keys().Count() = 0 then return ""
    parts = []
    for each k in q
        v = q[k]
        if type(v) <> "roString" and type(v) <> "String" then v = v.toStr()
        parts.push(k + "=" + hEscape(v))
    end for
    return parts.join("&")
end function

' Metadata (or Directory) array from a finished task, or []
function pxItems(t as object) as object
    if t = invalid or not t.ok or t.response = invalid then return []
    mc = t.response.MediaContainer
    if mc = invalid then return []
    src = mc.Metadata
    if src = invalid then src = mc.Directory
    if src = invalid then return []
    keep = []
    for each md in src
        if not isHiddenItem(md) then keep.push(md)
    end for
    return keep
end function

' Plex resizes (and can blur) any library image
function pxImage(path as dynamic, w as integer, h as integer, blur = 0 as integer) as string
    if path = invalid or path = "" or not pxReady() then return ""
    u = pxServer() + "/photo/:/transcode?width=" + w.toStr() + "&height=" + h.toStr() + "&minSize=1&upscale=1&url=" + pxEscape(path) + "&X-Plex-Token=" + pxToken()
    if blur > 0 then u = u + "&blur=" + blur.toStr()
    return u
end function

function pxStr(v as dynamic) as string
    if v = invalid then return ""
    if type(v) = "roString" or type(v) = "String" then return v
    return v.toStr()
end function

' Generic track from Plex track metadata: what the player, the rooms and the views use
function pxTrack(md as object) as object
    tr = { id: pxStr(md.ratingKey), title: pxStr(md.title), album: pxStr(md.parentTitle), albumId: pxStr(md.parentRatingKey), artistId: pxStr(md.grandparentRatingKey), url: "", format: "mp3", duration: 0, file: "", rating: 0 }
    artist = md.originalTitle
    if artist = invalid or artist = "" then artist = md.grandparentTitle
    tr.artist = pxStr(artist)
    thumb = md.parentThumb
    if thumb = invalid then thumb = md.thumb
    if thumb = invalid then thumb = md.grandparentThumb
    tr.thumb = pxStr(thumb)
    if md.duration <> invalid then tr.duration = md.duration / 1000
    if md.userRating <> invalid then tr.rating = md.userRating
    if md.Media = invalid or md.Media.count() = 0 or md.Media[0].Part = invalid or md.Media[0].Part.count() = 0 then return tr
    media = md.Media[0]
    part = media.Part[0]
    tr.file = pxStr(part.file)
    c = LCase(pxStr(media.container))
    if c = "" then c = LCase(pxStr(part.container))
    codec = LCase(pxStr(media.audioCodec))
    direct = { mp3: "mp3", flac: "flac", mp4: "mp4", m4a: "mp4", aac: "mp4", wav: "wav" }
    if direct[c] <> invalid and codec <> "alac" and codec <> "opus" and codec <> "vorbis"
        tr.url = pxServer() + part.key + "?X-Plex-Token=" + pxToken()
        tr.format = direct[c]
    else
        ' Plex turns anything else into mp3 for us
        tr.url = pxServer() + "/music/:/transcode/universal/start.mp3?path=" + pxEscape("/library/metadata/" + tr.id) + "&mediaIndex=0&partIndex=0&protocol=http&directPlay=0&directStream=0&X-Plex-Product=Hearth&X-Plex-Platform=Roku&X-Plex-Client-Identifier=" + m.global.deviceId + "&session=" + pxEscape(m.global.deviceId + "-" + tr.id) + "&X-Plex-Token=" + pxToken()
        tr.format = "mp3"
    end if
    return tr
end function

function pxTracks(items as object) as object
    out = []
    for each md in items
        if md.type = "track" then out.push(pxTrack(md))
    end for
    return out
end function

' An image cut to a circle by the NAS helper (real transparency, so no box behind it)
function pxRound(url as string, size as integer) as string
    b = CreateObject("roRegistrySection", "hearth").Read("nasUrl")
    if b = "" then b = "http://192.168.254.41:8765"
    return b + "/api/round?s=" + size.toStr() + "&u=" + pxEscape(url)
end function

' Card for CardRow from an album, artist or playlist
function pxCard(md as object, size as integer) as object
    sub2 = ""
    if md.type = "album"
        sub2 = pxStr(md.parentTitle)
    else if md.type = "playlist"
        if md.leafCount <> invalid then sub2 = md.leafCount.toStr() + " songs"
    else if md.type = "artist"
        sub2 = "Artist"
    end if
    thumb = md.thumb
    if thumb = invalid then thumb = md.composite
    img = pxImage(thumb, size, size)
    if md.type = "artist" and img <> "" then img = pxRound(img, size)
    return { item: md, title: pxStr(md.title), sub: sub2, image: img, progress: 0 }
end function

function pxClock(sec as dynamic) as string
    if sec = invalid or sec < 0 then sec = 0
    s = Int(sec)
    mm = Int(s / 60)
    ss = s mod 60
    t = ss.toStr()
    if ss < 10 then t = "0" + t
    return mm.toStr() + ":" + t
end function

' ---------- albums Hearth asked Lidarr for (registry "hearth" / "musicRequested") ----------
function muReqKey(artist as string, album as string) as string
    out = ""
    s = LCase(artist + "|" + album)
    for i = 1 to Len(s)
        c = Mid(s, i, 1)
        if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c = "|" or c = "*" then out = out + c
    end for
    return out
end function

function muRequested() as object
    raw = CreateObject("roRegistrySection", "hearth").Read("musicRequested")
    if raw = "" then return {}
    list = ParseJson(raw)
    out = {}
    if type(list) = "roArray"
        for each k in list
            out[k] = true
        end for
    end if
    return out
end function

' album "" means the whole artist
sub muMarkRequested(artist as string, albums as object)
    raw = CreateObject("roRegistrySection", "hearth").Read("musicRequested")
    list = []
    if raw <> "" then list = ParseJson(raw)
    if type(list) <> "roArray" then list = []
    if albums.Count() = 0 then albums = ["*"]
    for each al in albums
        list.push(muReqKey(artist, al))
    end for
    while list.Count() > 300
        list.shift()
    end while
    reg = CreateObject("roRegistrySection", "hearth")
    reg.Write("musicRequested", FormatJson(list))
    reg.Flush()
end sub

function muIsRequested(req as object, artist as string, album as string) as boolean
    return req[muReqKey(artist, album)] = true or req[muReqKey(artist, "*")] = true
end function

' "2 hours ago", "Yesterday", "Tuesday", "Nov 14" from a Plex addedAt (seconds)
function muWhen(added as dynamic) as string
    if added = invalid then return ""
    now = CreateObject("roDateTime")
    secs = now.AsSeconds() - added
    if secs < 3600 then return "Just now"
    if secs < 86400
        h = Int(secs / 3600)
        if h = 1 then return "1 hour ago"
        return h.toStr() + " hours ago"
    end if
    d = CreateObject("roDateTime")
    d.FromSeconds(added)
    d.ToLocalTime()
    if secs < 2 * 86400 then return "Yesterday"
    if secs < 7 * 86400 then return d.GetWeekday()
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return months[d.GetMonth() - 1] + " " + d.GetDayOfMonth().toStr()
end function
