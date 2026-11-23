' Bazarr API (https://github.com/morpheus65535/bazarr, bazarr/api/providers/*.py):
'   GET  /api/movies, /api/series, /api/episodes?seriesid[]=N   find Bazarr's ids for the file Plex is playing
'   GET  /api/providers/movies?radarrid=N, /api/providers/episodes?episodeid=N   manual search (slow: asks every provider)
'   POST /api/providers/movies (radarrid, hi, forced, original_format, provider, subtitle)
'   POST /api/providers/episodes (seriesid, episodeid, + the same)   downloads and saves the file next to the video
' Auth: X-API-KEY header.

sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    reg = CreateObject("roRegistrySection", "hearth")
    m.apiKey = reg.Read("bazarrKey")
    m.base = reg.Read("bazarrUrl")
    if m.base = "" then m.base = "http://192.168.254.41:6767"
    if Right(m.base, 1) = "/" then m.base = Left(m.base, Len(m.base) - 1)
    a = m.top.args
    if a = invalid then a = {}
    out = {}
    status = 0
    err = ""
    if m.apiKey = ""
        err = "nokey"
    else if m.top.op = "search"
        ids = findIds(a)
        if ids.error <> invalid
            err = ids.error
            status = ids.status
        else
            if ids.kind = "movie"
                res = req("GET", "/api/providers/movies", { radarrid: ids.movie.toStr() }, "", 120000)
            else
                res = req("GET", "/api/providers/episodes", { episodeid: ids.episode.toStr() }, "", 120000)
            end if
            status = res.status
            items = []
            if res.body <> invalid and res.body.data <> invalid then items = res.body.data
            if status < 200 or status >= 300
                err = "search"
                if type(res.text) = "roString" or type(res.text) = "String" then print "[hearth-subs] Bazarr search said: "; Left(res.text, 200)
            end if
            out = { Items: items, ids: ids }
        end if
    else if m.top.op = "download"
        ids = a.ids
        form = { hi: a.hi, forced: a.forced, original_format: "False", provider: a.provider, subtitle: a.subtitle }
        if ids.kind = "movie"
            form.radarrid = ids.movie.toStr()
            res = req("POST", "/api/providers/movies", {}, formBody(form), 120000)
        else
            form.seriesid = ids.series.toStr()
            form.episodeid = ids.episode.toStr()
            res = req("POST", "/api/providers/episodes", {}, formBody(form), 120000)
        end if
        status = res.status
        if status < 200 or status >= 300
            err = "download"
            print "[hearth-subs] Bazarr download said ("; status; "): "; Left(res.text, 200)
        end if
    end if
    m.top.status = status
    m.top.error = err
    m.top.ok = (err = "")
    m.top.response = out
    m.top.done = true
end sub

' Match the Plex file to Bazarr by file name (Bazarr sees the same files under its own mount, so
' only the end of the path is the same). Shows: the show folder name, then the episode file name,
' then season and episode numbers.
function findIds(a as object) as object
    file = baseName(a.file)
    if a.movie = true
        res = req("GET", "/api/movies", { start: "0", length: "-1" }, "", 30000)
        if res.status = 401 then return { error: "badkey", status: 401 }
        if res.body = invalid or res.body.data = invalid then return { error: "unreachable", status: res.status }
        for each mv in res.body.data
            if mv.path <> invalid and LCase(baseName(mv.path)) = LCase(file) then return { kind: "movie", movie: mv.radarrId }
        end for
        ' fall back to the title and year
        for each mv in res.body.data
            if mv.title <> invalid and LCase(mv.title) = LCase(a.title) and (a.year = invalid or mv.year = invalid or mv.year = a.year.toStr()) then return { kind: "movie", movie: mv.radarrId }
        end for
        return { error: "notfound", status: 404 }
    end if
    res = req("GET", "/api/series", { start: "0", length: "-1" }, "", 30000)
    if res.status = 401 then return { error: "badkey", status: 401 }
    if res.body = invalid or res.body.data = invalid then return { error: "unreachable", status: res.status }
    plexPath = LCase(a.file)
    seriesId = invalid
    for each s in res.body.data
        if s.path <> invalid
            folder = LCase(baseName(s.path))
            if folder <> "" and Instr(1, plexPath, "/" + folder + "/") > 0 then seriesId = s.sonarrSeriesId
        end if
        if seriesId <> invalid then exit for
    end for
    if seriesId = invalid
        for each s in res.body.data
            if s.title <> invalid and a.series <> invalid and LCase(s.title) = LCase(a.series) then seriesId = s.sonarrSeriesId
            if seriesId <> invalid then exit for
        end for
    end if
    if seriesId = invalid then return { error: "notfound", status: 404 }
    res = req("GET", "/api/episodes", { "seriesid[]": seriesId.toStr() }, "", 30000)
    if res.body = invalid or res.body.data = invalid then return { error: "unreachable", status: res.status }
    for each ep in res.body.data
        if ep.path <> invalid and LCase(baseName(ep.path)) = LCase(file) then return { kind: "episode", series: seriesId, episode: ep.sonarrEpisodeId }
    end for
    for each ep in res.body.data
        if ep.season = a.season and ep.episode = a.episode then return { kind: "episode", series: seriesId, episode: ep.sonarrEpisodeId }
    end for
    return { error: "notfound", status: 404 }
end function

function baseName(p as dynamic) as string
    if p = invalid then return ""
    p = p.Replace("\", "/")
    if Right(p, 1) = "/" then p = Left(p, Len(p) - 1)
    parts = p.split("/")
    return parts[parts.count() - 1]
end function

function formBody(form as object) as string
    x = CreateObject("roUrlTransfer")
    parts = []
    for each k in form
        v = form[k]
        if v = invalid then v = ""
        parts.push(k + "=" + x.Escape(v.toStr()))
    end for
    return parts.join("&")
end function

function req(method as string, path as string, query as object, body as string, timeout as integer) as object
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.setMessagePort(port)
    url = m.base + path
    parts = []
    for each k in query
        parts.push(xfer.Escape(k) + "=" + xfer.Escape(query[k]))
    end for
    if parts.count() > 0 then url = url + "?" + parts.join("&")
    xfer.setUrl(url)
    xfer.addHeader("X-API-KEY", m.apiKey)
    xfer.addHeader("Accept", "application/json")
    xfer.RetainBodyOnError(true)
    if Left(url, 8) = "https://"
        xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        xfer.InitClientCertificates()
    end if
    if method = "GET"
        started = xfer.AsyncGetToString()
    else
        xfer.setRequest(method)
        xfer.addHeader("Content-Type", "application/x-www-form-urlencoded")
        started = xfer.AsyncPostFromString(body)
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
    parsed = invalid
    if text <> invalid and text <> "" then parsed = ParseJson(text)
    return { status: status, body: parsed, text: text }
end function
