sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    base = CreateObject("roRegistrySection", "hearth").Read("nasUrl")
    if base = "" then base = "http://192.168.254.41:8765"
    status = 0
    resp = {}
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.setMessagePort(port)
    xfer.setUrl(base + m.top.path)
    xfer.addHeader("Accept", "application/json")
    if m.top.method = "POST"
        xfer.addHeader("Content-Type", "application/json")
        started = xfer.AsyncPostFromString(m.top.bodyText)
    else
        started = xfer.AsyncGetToString()
    end if
    if started
        ' lyrics may need the NAS to ask LRCLIB first
        msg = wait(20000, port)
        if type(msg) = "roUrlEvent"
            status = msg.GetResponseCode()
            body = msg.GetString()
            if body <> ""
                parsed = ParseJson(hFixText(body))
                if type(parsed) = "roAssociativeArray" then resp = parsed
            end if
        else
            xfer.AsyncCancel()
            status = -1
        end if
    end if
    m.top.status = status
    m.top.ok = (status >= 200 and status < 300)
    m.top.response = resp
    m.top.done = true
end sub
