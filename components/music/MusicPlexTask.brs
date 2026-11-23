sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.setMessagePort(port)
    url = m.top.url
    q = m.top.query
    ' Keys(): a query key named "count" would hide the AA's count() method
    if q <> invalid and q.Keys().Count() > 0
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
    if text <> invalid and (Left(text, 1) = "{" or Left(text, 1) = "[")
        parsed = ParseJson(hFixText(text))
        if parsed <> invalid and type(parsed) = "roAssociativeArray" then resp = parsed
    end if
    ' shows in the TV's debug log (nc <TV IP> 8085); the token stays out of it
    shown = url
    cut = Instr(1, shown, "X-Plex-Token=")
    if cut > 0 then shown = Left(shown, cut - 1)
    print "[hearth music] "; method; " "; shown; " -> "; status; " ("; Len(text); " bytes)"
    m.top.status = status
    m.top.ok = (status >= 200 and status < 300)
    m.top.response = resp
    m.top.done = true
end sub
