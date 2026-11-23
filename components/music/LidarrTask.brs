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
        msg = wait(20000, port)
        if type(msg) = "roUrlEvent"
            status = msg.GetResponseCode()
            text = msg.GetString()
        else
            xfer.AsyncCancel()
            status = -1
        end if
    end if
    print "[hearth lidarr] "; method; " "; m.top.path; " -> "; status
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
