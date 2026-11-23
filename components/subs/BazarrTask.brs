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
    else if m.top.op = "sync"
        ' Bazarr's subsync (PATCH /api/subtitles action=sync): re-times the saved file against the audio
        r = syncSub(a)
        status = r.status
        err = r.error
    else if m.top.op = "missing"
        ' which episodes (or the movie) lack a wanted subtitle language, as Bazarr sees it
        r = missing(a)
        status = r.status
        err = r.error
        out = r.out
    else if m.top.op = "fetchMissing"
        ' Bazarr's automatic search + download for each missing language (best match wins)
        n = 0
        for each x in a.list
            form = { language: x.code2, forced: x.forced, hi: x.hi }
            if a.kind = "movie"
                form.radarrid = a.movie.toStr()
                res = req("PATCH", "/api/movies/subtitles", form, formBody(form), 120000)
            else
                form.seriesid = a.series.toStr()
                form.episodeid = x.episode.toStr()
                res = req("PATCH", "/api/episodes/subtitles", form, formBody(form), 120000)
            end if
            status = res.status
            if status >= 200 and status < 300 then n = n + 1 else print "[hearth-subs] Bazarr fetch said ("; status; "): "; Left(res.text, 200)
        end for
        out = { fetched: n }
        if n = 0 and a.list.count() > 0 then err = "download"
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

function missing(a as object) as object
    if a.movie = true
        ids = findIds(a)
        if ids.error <> invalid then return { status: ids.status, error: ids.error, out: {} }
        res = req("GET", "/api/movies", { "radarrid[]": ids.movie.toStr() }, "", 30000)
        langs = []
        if res.body <> invalid and res.body.data <> invalid and res.body.data.count() > 0
            for each l in listOf(res.body.data[0].missing_subtitles)
                langs.push(lang(l))
            end for
        end if
        return { status: res.status, error: "", out: { kind: "movie", movie: ids.movie, missing: { movie: langs } } }
    end if
    res = req("GET", "/api/series", { start: "0", length: "-1" }, "", 30000)
    if res.status = 401 then return { status: 401, error: "badkey", out: {} }
    if res.body = invalid or res.body.data = invalid then return { status: res.status, error: "unreachable", out: {} }
    folder = LCase(baseName(a.folder))
    sid = invalid
    for each s in res.body.data
        if s.path <> invalid and folder <> "" and LCase(baseName(s.path)) = folder then sid = s.sonarrSeriesId
        if sid <> invalid then exit for
    end for
    if sid = invalid
        for each s in res.body.data
            if s.title <> invalid and a.series <> invalid and LCase(s.title) = LCase(a.series) then sid = s.sonarrSeriesId
            if sid <> invalid then exit for
        end for
    end if
    if sid = invalid then return { status: 404, error: "notfound", out: {} }
    res = req("GET", "/api/episodes", { "seriesid[]": sid.toStr() }, "", 30000)
    miss = {}
    if res.body <> invalid and res.body.data <> invalid
        for each ep in res.body.data
            langs = []
            for each l in listOf(ep.missing_subtitles)
                x = lang(l)
                x.episode = ep.sonarrEpisodeId
                langs.push(x)
            end for
            if langs.count() > 0 then miss[ep.season.toStr() + "-" + ep.episode.toStr()] = langs
        end for
    end if
    return { status: res.status, error: "", out: { kind: "episode", series: sid, missing: miss } }
end function

function listOf(v as dynamic) as object
    if type(v) = "roArray" then return v
    return []
end function

function lang(l as object) as object
    hi = "False"
    forced = "False"
    if l.hi = true then hi = "True"
    if l.forced = true then forced = "True"
    name = l.name
    if name = invalid then name = l.code2
    return { code2: l.code2, name: name, hi: hi, forced: forced }
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

function syncSub(a as object) as object
    ids = findIds(a)
    if ids.error <> invalid then return { status: ids.status, error: ids.error }
    if ids.kind = "movie"
        res = req("GET", "/api/movies", { "radarrid[]": ids.movie.toStr() }, "", 30000)
        kind = "movie"
        id = ids.movie
    else
        res = req("GET", "/api/episodes", { "episodeid[]": ids.episode.toStr() }, "", 30000)
        kind = "episode"
        id = ids.episode
    end if
    if res.body = invalid or res.body.data = invalid or res.body.data.count() = 0 then return { status: res.status, error: "notfound" }
    want = LCase(toStr(a.language))
    pick = invalid
    for each sb in listOf(res.body.data[0].subtitles)
        if sb.path <> invalid and sb.path <> ""
            c2 = LCase(toStr(sb.code2))
            c3 = LCase(toStr(sb.code3))
            if pick = invalid and (want = "" or c3 = want or c2 = want or c2 = Left(want, 2)) then pick = sb
        end if
    end for
    if pick = invalid then return { status: 404, error: "nofile" }
    form = { action: "sync", language: toStr(pick.code2), path: pick.path, type: kind, id: id.toStr(), forced: tf(pick.forced), hi: tf(pick.hi) }
    print "[hearth-subs] Bazarr sync "; pick.path
    r2 = req("PATCH", "/api/subtitles", form, formBody(form), 300000)
    if r2.status < 200 or r2.status >= 300
        print "[hearth-subs] Bazarr sync said ("; r2.status; "): "; Left(r2.text, 200)
        return { status: r2.status, error: "sync" }
    end if
    return { status: r2.status, error: "" }
end function

function tf(v as dynamic) as string
    if v = true then return "True"
    return "False"
end function

function toStr(v as dynamic) as string
    if v = invalid then return ""
    return v.toStr()
end function
