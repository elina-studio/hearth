' Reads the Plex photo library. Every result is { Items: [...] } where an item is
' a photo { Id, Name, Type: "Photo", path, date } or an album { Id, Name, Type: "Album", count, path }.
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
    m.top.response = { Items: items }
    m.top.done = true
end sub

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
    isPhoto = (md.Media <> invalid and md.Media.count() > 0)
    if isPhoto
        it.Type = "Photo"
        it.path = md.thumb
        part = md.Media[0].Part
        if part <> invalid and part.count() > 0 and part[0].key <> invalid then it.path = part[0].key
        it.date = md.originallyAvailableAt
        if it.date = invalid and md.year <> invalid then it.date = md.year.toStr()
    else if md.type = "photo" or md.type = "photoalbum" or md.key <> invalid and Instr(1, md.key, "/children") > 0
        it.Type = "Album"
        it.path = md.thumb
        n = md.leafCount
        if n = invalid then n = md.childCount
        it.count = n
    else
        it.Type = "Other"
    end if
    return it
end function

function get(url as string, query as object, token as string) as object
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
    if xfer.AsyncGetToString()
        msg = wait(20000, port)
        if type(msg) = "roUrlEvent"
            status = msg.GetResponseCode()
            text = msg.GetString()
            if text <> invalid and text <> "" then body = ParseJson(text)
        else
            xfer.AsyncCancel()
            status = -1
        end if
    end if
    return { status: status, body: body }
end function
