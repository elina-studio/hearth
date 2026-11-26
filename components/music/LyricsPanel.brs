sub init()
    m.rows = m.top.findNode("rows")
    m.timing = m.top.findNode("timing")
    m.timing.font = hFont("regular", 22)
    m.timingTimer = m.top.findNode("timingTimer")
    m.timingTimer.observeField("fire", "hideTiming")
    ys = [26, 84, 142, 262, 320]
    m.rowNodes = []
    for i = 0 to 4
        l = m.rows.createChild("Label")
        l.translation = [36, ys[i]]
        l.width = 688
        if i = 2
            l.height = 112
            l.vertAlign = "center"
            l.wrap = true
            l.maxLines = 2
            l.font = hFont("bold", 40)
            l.color = "0xFFE7A0FF"
        else
            l.height = 50
            l.vertAlign = "center"
            l.maxLines = 1
            l.font = hFont("bold", 28)
            l.color = "0xB5AF8CFF"
            if i = 1 or i = 3 then l.opacity = 0.7 else l.opacity = 0.4
        end if
        m.rowNodes.push(l)
    end for
    reg = CreateObject("roRegistrySection", "hearth")
    m.on = (reg.Read("lyricsOn") <> "0")
    m.offset = 0.0
    o = reg.Read("lyricsOffset")
    if o <> "" then m.offset = Val(o)
    m.mode = "none"
    m.times = []
    m.lines = []
    m.idx = -1
    m.trackId = ""
    m.top.visible = false
end sub

function isOn() as boolean
    return m.on
end function

sub start(unused as dynamic)
    p = m.global.music
    if p = invalid then return
    p.observeFieldScoped("track", "onTrack")
    p.observeFieldScoped("position", "onTick")
    p.observeFieldScoped("command", "onCmd")
    p.observeFieldScoped("state", "onState")
    p.lyricsActive = true
    onTrack()
end sub

sub lyricsStop(unused as dynamic)
    p = m.global.music
    if p = invalid then return
    p.unobserveFieldScoped("track")
    p.unobserveFieldScoped("position")
    p.unobserveFieldScoped("command")
    p.unobserveFieldScoped("state")
    p.lyricsActive = false
    p.lyricsFound = false
end sub

' the * options sheet sends lyricsToggle / lyricsNudge through the player's command field
sub onCmd()
    c = m.global.music.command
    if c = invalid or c.cmd = invalid then return
    if c.cmd = "lyricsToggle" then toggle(invalid)
    if c.cmd = "lyricsNudge" then nudge(c.delta)
end sub

function toggle(unused as dynamic) as boolean
    m.on = not m.on
    reg = CreateObject("roRegistrySection", "hearth")
    if m.on then reg.Write("lyricsOn", "1") else reg.Write("lyricsOn", "0")
    reg.Flush()
    m.idx = -1
    if m.on and m.mode = "none" then onTrack()
    redraw()
    return m.on
end function

sub nudge(delta as dynamic)
    m.offset = m.offset + delta
    if m.offset > 10 then m.offset = 10.0
    if m.offset < -10 then m.offset = -10.0
    m.offset = Int(m.offset * 10 + 0.5 * Sgn(m.offset)) / 10.0
    reg = CreateObject("roRegistrySection", "hearth")
    reg.Write("lyricsOffset", Str(m.offset).Trim())
    reg.Flush()
    t = Str(m.offset).Trim()
    if m.offset > 0 then t = "+" + t
    m.timing.text = "Lyrics timing " + t + " s"
    m.timingTimer.control = "stop"
    m.timingTimer.control = "start"
    m.idx = -1
    onTick()
end sub

sub muRestoreFocus()
end sub

sub hideTiming()
    m.timing.text = ""
end sub

sub onTrack()
    tr = m.global.music.track
    m.mode = "none"
    m.times = []
    m.lines = []
    m.idx = -1
    m.top.found = false
    if tr = invalid or tr.id = invalid
        m.trackId = ""
        redraw()
        return
    end if
    m.trackId = tr.id
    redraw()
    if not m.on then return
    path = "/api/lyrics?artist=" + pxEscape(tr.artist) + "&title=" + pxEscape(tr.title) + "&album=" + pxEscape(tr.album) + "&duration=" + Int(tr.duration).toStr() + "&file=" + pxEscape(pxStr(tr.file))
    nasCall("GET", path, "", "onLyrics", tr.id)
end sub

sub onLyrics(event as object)
    t = hTaskFrom(event)
    if t.tag <> m.trackId then return
    r = t.response
    m.mode = "none"
    if t.ok and r <> invalid
        if r.times <> invalid and r.lines <> invalid and r.times.Count() > 2
            m.times = r.times
            m.lines = r.lines
            m.mode = "synced"
        else if r.plain <> invalid and r.plain <> ""
            m.lines = []
            for each ln in r.plain.Split(Chr(10))
                s = ln.Trim()
                if s <> "" then m.lines.push(s)
            end for
            if m.lines.Count() > 2 then m.mode = "plain"
        end if
    end if
    m.top.found = (m.mode <> "none")
    m.idx = -1
    redraw()
    onTick()
end sub

sub onTick()
    if m.mode = "none" or not m.on then return
    p = m.global.music
    idx = 0
    if m.mode = "synced"
        at = p.position + m.offset
        i = m.idx
        if i < 0 then i = 0
        if i >= m.times.Count() then i = m.times.Count() - 1
        while i > 0 and m.times[i] > at
            i = i - 1
        end while
        while i + 1 < m.times.Count() and m.times[i + 1] <= at
            i = i + 1
        end while
        idx = i
        if m.times[0] > at then idx = -1
    else
        if p.duration > 0 then idx = Int((p.position / p.duration) * m.lines.Count())
        if idx >= m.lines.Count() then idx = m.lines.Count() - 1
    end if
    if idx = m.idx then return
    m.idx = idx
    paintRows()
end sub

sub onState()
    redraw()
end sub

sub redraw()
    st = m.global.music.state
    live = (st = "playing" or st = "paused" or st = "buffering")
    show = (m.on and m.mode <> "none" and live)
    m.top.visible = show
    m.global.music.lyricsFound = (m.mode <> "none")
    if show then paintRows()
end sub

sub paintRows()
    for k = 0 to 4
        i = m.idx + k - 2
        txt = ""
        if i >= 0 and i < m.lines.Count()
            txt = m.lines[i]
            if txt = "" then txt = "..."
        end if
        m.rowNodes[k].text = txt
    end for
end sub
