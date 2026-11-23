sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    x = CreateObject("roUrlTransfer")
    x.SetUrl(m.top.url)
    x.SetCertificatesFile("common:/certs/ca-bundle.crt")
    x.RetainBodyOnError(true)
    port = CreateObject("roMessagePort")
    x.SetMessagePort(port)
    text = ""
    code = 0
    if x.AsyncGetToString()
        msg = wait(20000, port)
        if type(msg) = "roUrlEvent"
            code = msg.GetResponseCode()
            text = msg.GetString()
        else
            x.AsyncCancel()
        end if
    end if
    cues = []
    if code = 200 and text <> "" then cues = parse(text)
    print "[hearth-subs] Hearth draws the subtitles: "; cues.count(); " lines (HTTP "; code; ")"
    m.top.cues = cues
    m.top.ok = cues.count() > 0
    m.top.done = true
end sub

' SRT and WebVTT: "00:01:02,345 --> 00:01:04,000" (VTT may leave out the hours and uses a dot)
function parse(text as string) as object
    text = text.Replace(Chr(13), "")
    lines = text.Split(Chr(10))
    tre = CreateObject("roRegex", "(?:(\d+):)?(\d+):(\d+)[,.](\d+)\s*-->\s*(?:(\d+):)?(\d+):(\d+)[,.](\d+)", "")
    tags = CreateObject("roRegex", "<[^>]*>|\{[^}]*\}", "")
    cues = []
    i = 0
    n = lines.count()
    while i < n
        mt = tre.Match(lines[i])
        if mt.count() > 8
            s = secs(mt[1], mt[2], mt[3], mt[4])
            e = secs(mt[5], mt[6], mt[7], mt[8])
            body = ""
            i = i + 1
            while i < n and lines[i].Trim() <> ""
                ln = tags.ReplaceAll(lines[i], "")
                if body = "" then body = ln else body = body + Chr(10) + ln
                i = i + 1
            end while
            if body.Trim() <> "" then cues.push({ s: s, e: e, t: body })
        end if
        i = i + 1
    end while
    return cues
end function

function secs(h as string, mi as string, s as string, ms as string) as float
    hh = 0
    if h <> "" then hh = h.ToInt()
    frac = ms.ToInt()
    if Len(ms) = 2 then frac = frac * 10
    if Len(ms) = 1 then frac = frac * 100
    return hh * 3600 + mi.ToInt() * 60 + s.ToInt() + frac / 1000.0
end function
