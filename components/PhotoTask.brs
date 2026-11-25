' Reads the Plex photo library. Every result is { Items: [...] } where an item is
' a photo { Id, Name, Type: "Photo", path, date, place } or an album { Id, Name, Type: "Album", count, path, years }.
' path is a server image path for /photo/:/transcode (see pPhotoUrl).
sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    a = m.top.args
    if a = invalid then a = {}
    server = m.global.plexServer
    token = m.global.plexServerToken
    op = m.top.op
    status = 0
    items = []
    out = {}
    if op = "albums"
        r = get(server + "/library/sections/" + a.section + "/all", {}, token)
        status = r.status
        for each md in entries(r.body)
            it = norm(md)
            if it.Type = "Album" then items.push(it)
        end for
    else if op = "random"
        ' type 13 = photo: every photo in the library, subfolders included
        r = get(server + "/library/sections/" + a.section + "/all", { type: "13", sort: "random", "X-Plex-Container-Start": "0", "X-Plex-Container-Size": toS(a.limit, "60") }, token)
        status = r.status
        for each md in entries(r.body)
            it = norm(md)
            if it.Type = "Photo" then items.push(it)
        end for
    else if op = "summary"
        ' counts for the room: every photo, favourites, and photos taken on this day in past years
        r = get(server + "/library/sections/" + a.section + "/all", { type: "13", "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "0" }, token)
        status = r.status
        out.total = total(r.body)
        r2 = get(server + "/library/sections/" + a.section + "/all", { type: "13", "userRating%3E%3E": "9", "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "0" }, token)
        out.favourites = total(r2.body)
        out.onThisDay = onThisDay(server, token, a.section, 1).count()
    else if op = "favourites"
        r = get(server + "/library/sections/" + a.section + "/all", { type: "13", "userRating%3E%3E": "9", sort: "originallyAvailableAt:asc", "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "500" }, token)
        status = r.status
        for each md in entries(r.body)
            it = norm(md)
            if it.Type = "Photo" then items.push(it)
        end for
    else if op = "onthisday"
        status = 200
        items = onThisDay(server, token, a.section, 200)
    else if op = "ordered"
        ' every photo, oldest first, one page at a time
        r = get(server + "/library/sections/" + a.section + "/all", { type: "13", sort: "originallyAvailableAt:asc", "X-Plex-Container-Start": toS(a.start, "0"), "X-Plex-Container-Size": toS(a.limit, "60") }, token)
        status = r.status
        for each md in entries(r.body)
            it = norm(md)
            if it.Type = "Photo" then items.push(it)
        end for
    else if op = "rate"
        ' Favourites are Plex ratings: 10 = favourite, -1 = cleared
        r = put(server + "/:/rate", { key: a.id, identifier: "com.plexapp.plugins.library", rating: toS(a.rating, "10") }, token)
        status = r.status
    else if op = "album"
        ' photos in this album and one level of albums inside it
        r = get(server + "/library/metadata/" + a.id + "/children", {}, token)
        status = r.status
        for each md in entries(r.body)
            it = norm(md)
            if it.Type = "Photo"
                items.push(it)
            else if it.Type = "Album" and items.count() < 500
                r2 = get(server + "/library/metadata/" + it.Id + "/children", {}, token)
                for each md2 in entries(r2.body)
                    it2 = norm(md2)
                    if it2.Type = "Photo" then items.push(it2)
                end for
            end if
        end for
    end if
    m.top.status = status
    m.top.ok = (status >= 200 and status < 300)
    out.Items = items
    m.top.response = out
    m.top.done = true
end sub

function total(body as dynamic) as integer
    if body = invalid or body.MediaContainer = invalid then return 0
    mc = body.MediaContainer
    if mc.totalSize <> invalid then return mc.totalSize
    if mc.size <> invalid then return mc.size
    return 0
end function

' Photos taken on today's month and day in each of the last 25 years, oldest first.
' Stops early once it has enough (the room only needs to know there are some).
function onThisDay(server as string, token as string, section as string, enough as integer) as object
    found = []
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    mo = dt.GetMonth().toStr()
    if Len(mo) = 1 then mo = "0" + mo
    dd = dt.GetDayOfMonth().toStr()
    if Len(dd) = 1 then dd = "0" + dd
    thisYear = dt.GetYear()
    for y = thisYear - 25 to thisYear - 1
        day = y.toStr() + "-" + mo + "-" + dd
        ' Plex's >> and << are strict, so ask for the day before to the day after
        r = get(server + "/library/sections/" + section + "/all", { type: "13", "originallyAvailableAt%3E%3E": shiftDay(day, -1), "originallyAvailableAt%3C%3C": shiftDay(day, 1), "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "50" }, token)
        for each md in entries(r.body)
            it = norm(md)
            if it.Type = "Photo" and it.date <> invalid and Left(it.date, 10) = day then found.push(it)
        end for
        if found.count() >= enough then return found
    end for
    return found
end function

function shiftDay(day as string, d as integer) as string
    t = CreateObject("roDateTime")
    t.FromISO8601String(day + "T12:00:00Z")
    t.FromSeconds(t.AsSeconds() + d * 86400)
    return Left(t.ToISOString(), 10)
end function

function toS(v as dynamic, fallback as string) as string
    if v = invalid then return fallback
    return v.toStr()
end function

' Plex lists albums as Directory or as Metadata depending on version; take both
function entries(body as dynamic) as object
    out = []
    if body = invalid or body.MediaContainer = invalid then return out
    mc = body.MediaContainer
    if mc.Directory <> invalid then out.append(mc.Directory)
    if mc.Metadata <> invalid then out.append(mc.Metadata)
    return out
end function

function norm(md as object) as object
    it = { Id: md.ratingKey, Name: md.title }
    if it.Id <> invalid then it.Id = it.Id.toStr()
    ' videos in the folder are type "clip"; only photos go in the slideshow
    isPhoto = (md.type = "photo" and md.Media <> invalid and md.Media.count() > 0)
    if isPhoto
        it.Type = "Photo"
        it.path = md.thumb
        part = md.Media[0].Part
        if part <> invalid and part.count() > 0 and part[0].key <> invalid then it.path = part[0].key
        ' size, so the slideshow can pair up portrait photos
        it.w = md.Media[0].width
        it.h = md.Media[0].height
        it.fav = (md.userRating <> invalid and md.userRating >= 10)
        ' screenshots aren't memories: leave them out
        if md.title <> invalid and Instr(1, LCase(md.title), "screenshot") > 0 then it.Type = "Other"
        if it.path <> invalid and Instr(1, LCase(it.path), "screenshot") > 0 then it.Type = "Other"
        it.date = md.originallyAvailableAt
        if it.date = invalid and md.year <> invalid then it.date = md.year.toStr()
        ' the album (folder) the photo sits in, shown as its place under the window title
        if md.parentTitle <> invalid and md.parentTitle <> "" and md.parentTitle <> md.librarySectionTitle then it.place = md.parentTitle
    else if md.type = "photo" or md.type = "photoalbum" or md.key <> invalid and Instr(1, md.key, "/children") > 0
        it.Type = "Album"
        it.path = md.thumb
        n = md.leafCount
        if n = invalid then n = md.childCount
        it.count = n
        ' years only when Plex gives the album a date itself (no extra calls per album)
        y = invalid
        if md.originallyAvailableAt <> invalid and Len(md.originallyAvailableAt) >= 4 then y = Left(md.originallyAvailableAt, 4)
        if y = invalid and md.year <> invalid then y = md.year.toStr()
        if y <> invalid then it.years = y
    else
        it.Type = "Other"
    end if
    return it
end function

function get(url as string, query as object, token as string) as object
    return send("GET", url, query, token)
end function

function put(url as string, query as object, token as string) as object
    return send("PUT", url, query, token)
end function

function send(method as string, url as string, query as object, token as string) as object
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.setMessagePort(port)
    parts = []
    for each k in query
        parts.push(k + "=" + xfer.Escape(query[k]))
    end for
    if parts.count() > 0
        sep = "?"
        if Instr(1, url, "?") > 0 then sep = "&"
        url = url + sep + parts.join("&")
    end if
    xfer.setUrl(url)
    xfer.addHeader("Accept", "application/json")
    xfer.addHeader("X-Plex-Product", "Hearth")
    xfer.addHeader("X-Plex-Client-Identifier", m.global.deviceId)
    if token <> invalid and token <> "" then xfer.addHeader("X-Plex-Token", token)
    if Left(url, 8) = "https://"
        xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        xfer.InitClientCertificates()
    end if
    status = 0
    body = invalid
    started = false
    if method = "GET"
        started = xfer.AsyncGetToString()
    else
        xfer.setRequest(method)
        started = xfer.AsyncPostFromString("")
    end if
    if started
        msg = wait(20000, port)
        if type(msg) = "roUrlEvent"
            status = msg.GetResponseCode()
            text = msg.GetString()
            if text <> invalid and text <> "" then body = ParseJson(hFixText(text))
        else
            xfer.AsyncCancel()
            status = -1
        end if
    end if
    return { status: status, body: body }
end function
