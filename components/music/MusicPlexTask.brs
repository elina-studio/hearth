sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.setMessagePort(port)
    url = m.top.url
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
    xfer.addHeader("Accept", "application/json")
    xfer.addHeader("X-Plex-Product", "Hearth")
    xfer.addHeader("X-Plex-Version", "0.1")
    xfer.addHeader("X-Plex-Platform", "Roku")
    xfer.addHeader("X-Plex-Device-Name", "Hearth (Roku TV)")
    xfer.addHeader("X-Plex-Client-Identifier", m.global.deviceId)
    if m.global.hasField("plexServerToken") and m.global.plexServerToken <> invalid and m.global.plexServerToken <> ""
        xfer.addHeader("X-Plex-Token", m.global.plexServerToken)
    end if
    xfer.RetainBodyOnError(true)
    if Left(url, 8) = "https://"
        xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        xfer.InitClientCertificates()
    end if
    method = UCase(m.top.method)
    if method = "GET"
        started = xfer.AsyncGetToString()
    else
        xfer.setRequest(method)
        started = xfer.AsyncPostFromString("")
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
        if parsed <> invalid and type(parsed) = "roAssociativeArray" then resp = parsed
    end if
    m.top.status = status
    m.top.ok = (status >= 200 and status < 300)
    m.top.response = resp
    m.top.done = true
end sub
