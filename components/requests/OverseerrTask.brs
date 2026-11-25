' Talks to Overseerr with the API key saved on the TV (registry section "hearth").
sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    reg = CreateObject("roRegistrySection", "hearth")
    m.base = reg.Read("overseerrUrl")
    if m.base = "" then m.base = "http://192.168.254.41:5055"
    if Right(m.base, 1) = "/" then m.base = Left(m.base, Len(m.base) - 1)
    m.apiKey = reg.Read("overseerrKey")

    if m.top.mode = "requests"
        loadRequests()
    else
        b = m.top.body
        if m.top.bodyText <> "" then b = m.top.bodyText
        r = fetch(m.top.method, m.top.path, m.top.query, b)
        finish(r.status, r.data)
    end if
end sub

sub finish(status as integer, data as object)
    if data = invalid then data = {}
    m.top.status = status
    m.top.ok = (status >= 200 and status < 300)
    m.top.response = data
    m.top.done = true
end sub

' Your requests, newest first, each with its title and poster filled in.
sub loadRequests()
    take = "20"
    if m.top.query <> invalid and m.top.query.take <> invalid then take = m.top.query.take.toStr()
    r = fetch("GET", "/api/v1/request", { take: take, skip: "0", sort: "added", filter: "all" }, invalid)
    if r.status < 200 or r.status >= 300 or r.data = invalid or r.data.results = invalid
        finish(r.status, r.data)
        return
    end if
    out = []
    for each q in r.data.results
        media = q.media
        if media <> invalid and media.tmdbId <> invalid
            kind = media.mediaType
            if kind = invalid then kind = q.type
            d = fetch("GET", "/api/v1/" + kind + "/" + media.tmdbId.toStr(), invalid, invalid)
            info = { id: media.tmdbId, mediaType: kind, title: "", detailStatus: d.status }
            if d.data <> invalid
                t = d.data.title
                if t = invalid then t = d.data.name
                if t <> invalid then info.title = t
                info.posterPath = d.data.posterPath
                info.overview = d.data.overview
                info.releaseDate = d.data.releaseDate
                info.firstAirDate = d.data.firstAirDate
                info.backdropPath = d.data.backdropPath
                info.voteAverage = d.data.voteAverage
                info.runtime = d.data.runtime
                info.numberOfSeasons = d.data.numberOfSeasons
            end if
            out.push({ request: q, info: info })
        end if
    end for
    finish(200, { results: out })
end sub

' Asks Overseerr; if the saved key is missing or refused, pulls the current one from the NAS helper
' (tools/remote hearth-keys.json) once and tries again, so a wiped or stale key heals itself.
function fetch(method as string, path as string, query as dynamic, body as dynamic) as object
    if m.apiKey = invalid or m.apiKey = "" then healKey()
    r = fetchOnce(method, path, query, body)
    if r.status = 401 or r.status = 403
        if healKey() then r = fetchOnce(method, path, query, body)
    end if
    return r
end function

function healKey() as boolean
    if m.healed = true then return false
    m.healed = true
    reg = CreateObject("roRegistrySection", "hearth")
    nas = reg.Read("nasUrl")
    if nas = "" then nas = "http://192.168.254.41:8765"
    port = CreateObject("roMessagePort")
    x = CreateObject("roUrlTransfer")
    x.setMessagePort(port)
    x.setUrl(nas + "/api/keys")
    if not x.asyncGetToString() then return false
    msg = wait(5000, port)
    if type(msg) <> "roUrlEvent" or msg.getResponseCode() <> 200 then return false
    d = ParseJson(msg.getString())
    if d = invalid or type(d) <> "roAssociativeArray" then return false
    k = d.overseerrKey
    if k = invalid or k = "" or k = m.apiKey then return false
    reg.Write("overseerrKey", k)
    if d.overseerrUrl <> invalid and d.overseerrUrl <> "" and reg.Read("overseerrUrl") = "" then reg.Write("overseerrUrl", d.overseerrUrl)
    reg.Flush()
    m.apiKey = k
    print "[hearth] Overseerr key refreshed from the NAS helper"
    return true
end function

function fetchOnce(method as string, path as string, query as dynamic, body as dynamic) as object
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.setMessagePort(port)
    url = m.base + path
    if query <> invalid and query.count() > 0
        parts = []
        for each k in query
            v = query[k]
            if type(v) <> "roString" and type(v) <> "String" then v = v.toStr()
            parts.push(k + "=" + xfer.Escape(v))
        end for
        url = url + "?" + parts.join("&")
    end if
    xfer.setUrl(url)
    xfer.addHeader("X-Api-Key", m.apiKey)
    xfer.addHeader("Accept", "application/json")
    xfer.RetainBodyOnError(true)
    if Left(url, 8) = "https://"
        xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        xfer.InitClientCertificates()
    end if
    started = false
    if UCase(method) = "GET"
        started = xfer.AsyncGetToString()
    else
        xfer.setRequest(UCase(method))
        xfer.addHeader("Content-Type", "application/json")
        text = "{}"
        if type(body) = "roString" or type(body) = "String"
            text = body
        else if body <> invalid and body.count() > 0
            text = FormatJson(body)
        end if
        started = xfer.AsyncPostFromString(text)
    end if
    status = 0
    resp = ""
    if started
        msg = wait(15000, port)
        if type(msg) = "roUrlEvent"
            status = msg.GetResponseCode()
            resp = msg.GetString()
        else
            xfer.AsyncCancel()
            status = -1
        end if
    end if
    data = invalid
    if resp <> invalid and resp <> ""
        data = ParseJson(hFixText(resp))
        if type(data) = "roArray" then data = { results: data }
    end if
    return { status: status, data: data }
end function
