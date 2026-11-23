sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    reg = CreateObject("roRegistrySection", "hearth")
    movie = (m.top.mediaType = "movie")
    if movie
        base = reg.Read("radarrUrl")
        if base = "" then base = "http://192.168.254.41:7878"
        key = reg.Read("radarrKey")
        who = "Radarr"
    else
        base = reg.Read("sonarrUrl")
        if base = "" then base = "http://192.168.254.41:8989"
        key = reg.Read("sonarrKey")
        who = "Sonarr"
    end if
    if Right(base, 1) = "/" then base = Left(base, Len(base) - 1)
    if key = ""
        print "[hearth-arr] no "; who; " key on the TV, so the download waits for "; who; "'s own search"
        finish(false, "no key")
        return
    end if
    ' Overseerr hands the request to Radarr/Sonarr within a few seconds; look for it for up to ~40 s
    id = invalid
    for attempt = 1 to 10
        if movie
            r = call(base, key, "GET", "/api/v3/movie?tmdbId=" + m.top.tmdbId.toStr(), "")
            if r.ok and type(r.body) = "roArray" and r.body.count() > 0 then id = r.body[0].id
        else
            r = call(base, key, "GET", "/api/v3/series", "")
            if r.ok and type(r.body) = "roArray"
                for each s in r.body
                    if (m.top.tvdbId > 0 and s.tvdbId = m.top.tvdbId) or (m.top.tmdbId > 0 and s.tmdbId = m.top.tmdbId)
                        id = s.id
                        exit for
                    end if
                end for
            end if
        end if
        if id <> invalid then exit for
        sleep(4000)
    end for
    if id = invalid
        print "[hearth-arr] "; who; " doesn't have it yet; leaving the search to "; who
        finish(false, "not found")
        return
    end if
    q = Chr(34)
    bodies = []
    if movie
        bodies.push("{" + q + "name" + q + ":" + q + "MoviesSearch" + q + "," + q + "movieIds" + q + ":[" + id.toStr() + "]}")
    else if m.top.seasons = "" or m.top.seasons = "all"
        bodies.push("{" + q + "name" + q + ":" + q + "SeriesSearch" + q + "," + q + "seriesId" + q + ":" + id.toStr() + "}")
    else
        for each n in m.top.seasons.Split(",")
            bodies.push("{" + q + "name" + q + ":" + q + "SeasonSearch" + q + "," + q + "seriesId" + q + ":" + id.toStr() + "," + q + "seasonNumber" + q + ":" + n.Trim() + "}")
        end for
    end if
    allOk = true
    for each b in bodies
        r = call(base, key, "POST", "/api/v3/command", b)
        print "[hearth-arr] "; who; " search "; b; " -> "; r.status
        if not r.ok then allOk = false
    end for
    finish(allOk, who)
end sub

sub finish(ok as boolean, note as string)
    m.top.ok = ok
    m.top.note = note
    m.top.done = true
end sub

function call(base as string, key as string, method as string, path as string, body as string) as object
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.setMessagePort(port)
    xfer.setUrl(base + path)
    xfer.addHeader("X-Api-Key", key)
    xfer.addHeader("Accept", "application/json")
    xfer.RetainBodyOnError(true)
    if method = "GET"
        started = xfer.AsyncGetToString()
    else
        xfer.setRequest(method)
        xfer.addHeader("Content-Type", "application/json")
        started = xfer.AsyncPostFromString(body)
    end if
    status = -1
    text = ""
    if started
        msg = wait(30000, port)
        if type(msg) = "roUrlEvent"
            status = msg.GetResponseCode()
            text = msg.GetString()
        else
            xfer.AsyncCancel()
        end if
    end if
    parsed = invalid
    if text <> "" then parsed = ParseJson(text)
    return { ok: (status >= 200 and status < 300), status: status, body: parsed }
end function
