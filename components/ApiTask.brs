sub init()
    m.top.functionName = "runTask"
end sub

function authHeader() as string
    q = Chr(34)
    a = "MediaBrowser Client=" + q + "Hearth" + q + ", Device=" + q + "Roku TV" + q
    a = a + ", DeviceId=" + q + m.global.deviceId + q + ", Version=" + q + "0.1.1" + q
    if m.global.token <> invalid and m.global.token <> ""
        a = a + ", Token=" + q + m.global.token + q
    end if
    return a
end function

sub runTask()
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.setMessagePort(port)
    url = m.global.server + m.top.path
    q = m.top.query
    if q <> invalid and q.count() > 0
        parts = []
        for each k in q
            v = q[k]
            if type(v) <> "roString" and type(v) <> "String" then v = v.toStr()
            parts.push(k + "=" + xfer.Escape(v))
        end for
        sep = "?"
        if Instr(1, url, "?") > 0 then sep = "&"
        url = url + sep + parts.join("&")
    end if
    xfer.setUrl(url)
    xfer.addHeader("Authorization", authHeader())
    xfer.addHeader("X-Emby-Authorization", authHeader())
    xfer.addHeader("Accept", "application/json")
    xfer.RetainBodyOnError(true)
    if Left(url, 8) = "https://"
        xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        xfer.InitClientCertificates()
    end if

    method = UCase(m.top.method)
    started = false
    if method = "GET"
        started = xfer.AsyncGetToString()
    else
        xfer.setRequest(method)
        xfer.addHeader("Content-Type", "application/json")
        body = ""
        if m.top.body <> invalid and m.top.body.count() > 0 then body = FormatJson(m.top.body)
        started = xfer.AsyncPostFromString(body)
    end if

    status = 0
    text = ""
    if started
        msg = wait(15000, port)
        if type(msg) = "roUrlEvent"
            status = msg.GetResponseCode()
            text = msg.GetString()
        else
            xfer.AsyncCancel()
            status = -1
        end if
    end if

    resp = {}
    if text <> invalid and text <> ""
        parsed = ParseJson(text)
        if parsed <> invalid
            if type(parsed) = "roArray"
                resp = { Items: parsed }
            else
                resp = parsed
            end if
        end if
    end if
    m.top.status = status
    m.top.ok = (status >= 200 and status < 300)
    m.top.response = resp
    m.top.done = true
end sub
