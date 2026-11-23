sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    if m.top.keepAwake then CreateObject("roAppManager").UpdateLastKeyPressTime()
    c = pCfg()
    status = 0
    resp = {}
    if m.top.path <> "" and c.haToken <> ""
        xfer = CreateObject("roUrlTransfer")
        port = CreateObject("roMessagePort")
        xfer.setMessagePort(port)
        url = c.haUrl + m.top.path
        xfer.setUrl(url)
        xfer.addHeader("Authorization", "Bearer " + c.haToken)
        xfer.addHeader("Accept", "application/json")
        if Left(LCase(url), 8) = "https://"
            xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
            xfer.InitClientCertificates()
        end if
        if m.top.method = "POST"
            xfer.addHeader("Content-Type", "application/json")
            started = xfer.AsyncPostFromString(m.top.bodyText)
        else
            started = xfer.AsyncGetToString()
        end if
        if started
            ' a service call returns when it's done; Music Assistant looking up a song can take a while
            limit = 15000
            if m.top.method = "POST" then limit = 60000
            msg = wait(limit, port)
            if type(msg) = "roUrlEvent"
                status = msg.GetResponseCode()
                body = msg.GetString()
                parsed = invalid
                if body <> "" then parsed = ParseJson(hFixText(body))
                if type(parsed) = "roAssociativeArray" then resp = parsed
                if type(parsed) = "roArray" then resp = { items: parsed }
            else
                xfer.AsyncCancel()
                status = -1
            end if
        end if
    end if
    m.top.status = status
    m.top.ok = (status >= 200 and status < 300)
    m.top.response = resp
    m.top.done = true
end sub
