sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    reg = CreateObject("roRegistrySection", "hearth")
    base = reg.Read("lidarrUrl")
    if base = "" then base = "http://192.168.254.41:8686"
    if Right(base, 1) = "/" then base = Left(base, Len(base) - 1)
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.setMessagePort(port)
    url = base + "/api/v1" + m.top.path
    q = m.top.query
    if q <> invalid and q.Keys().Count() > 0
        parts = []
        for each k in q
            v = q[k]
            if type(v) <> "roString" and type(v) <> "String" then v = v.toStr()
            parts.push(k + "=" + xfer.Escape(v))
        end for
        url = url + "?" + parts.join("&")
    end if
    xfer.setUrl(url)
    xfer.addHeader("X-Api-Key", reg.Read("lidarrKey"))
    xfer.addHeader("Accept", "application/json")
    xfer.RetainBodyOnError(true)
    method = UCase(m.top.method)
    status = 0
    text = ""
    clock = CreateObject("roTimespan")
    ' Lidarr answers 503 when its online music database hiccups; that clears in a moment,
    ' so searches (GETs) try up to 3 times before giving up
    tries = 1
    if method = "GET" then tries = 3
    for attempt = 1 to tries
        if method = "GET"
            started = xfer.AsyncGetToString()
        else
            xfer.setRequest(method)
            xfer.addHeader("Content-Type", "application/json")
            body = ""
            if m.top.bodyText <> invalid then body = m.top.bodyText
            started = xfer.AsyncPostFromString(body)
        end if
        status = 0
        text = ""
        if started
            msg = wait(m.top.timeout, port)
            if type(msg) = "roUrlEvent"
                status = msg.GetResponseCode()
                text = msg.GetString()
            else
                xfer.AsyncCancel()
                status = -1
            end if
        end if
        if status <> 503 or attempt = tries then exit for
        print "[hearth lidarr] "; m.top.path; " -> 503, trying again"
        sleep(1500)
    end for
    print "[hearth lidarr] "; method; " "; m.top.path; " -> "; status; " in "; clock.TotalMilliseconds(); " ms, "; Len(text); " bytes"
    if status <> 200 and status <> 201 and status <> 202 and text <> "" then print "[hearth lidarr] reply: "; Left(text, 300)
    resp = {}
    if text <> invalid and text <> ""
        parsed = ParseJson(hFixText(text))
        if parsed <> invalid
            if type(parsed) = "roArray" then resp = { Items: parsed } else resp = parsed
        end if
    end if
    m.top.status = status
    m.top.ok = (status >= 200 and status < 300)
    m.top.response = resp
    m.top.done = true
end sub
