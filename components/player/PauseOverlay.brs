' Pause screen A. Two focus zones: the timeline (Left/Right skip 10 s back / 30 s ahead, Rewind/Fast-forward
' scrub faster each press, holding Left/Right seeks faster the longer it is held, OK plays or jumps to the scrub point) and the button row (Down from the timeline).
' While playing it hides itself after 5 s; while paused it stays.

sub init()
    m.top.visible = false
    m.c = hColors()
    m.barX = 300
    m.barW = 1320
    m.barY = 832
    m.top.findNode("kicker").font = hFont("caps", 24)
    m.top.findNode("title").font = hFont("bold", 44)
    m.top.findNode("clock").font = hFont("bold", 44)
    m.top.findNode("ampm").font = hFont("regular", 21)
    m.top.findNode("elapsed").font = hFont("bold", 64)
    m.top.findNode("remaining").font = hFont("bold", 64)
    m.top.findNode("ends").font = hFont("regular", 21)
    m.top.findNode("thumbTime").font = hFont("bold", 26)
    m.bar = hBraid(m.top.findNode("barHolder"), m.barW, 0)
    m.head = m.top.findNode("head")
    m.preview = m.top.findNode("preview")
    m.thumb = m.top.findNode("thumb")
    m.hints = m.top.findNode("hints")
    m.hideTimer = m.top.findNode("hideTimer")
    m.hideTimer.observeField("fire", "onHideTimer")
    m.scrubTimer = m.top.findNode("scrubTimer")
    m.scrubTimer.observeField("fire", "onScrubTick")
    m.clockTimer = m.top.findNode("clockTimer")
    m.clockTimer.observeField("fire", "paintClock")
    m.zone = "bar"
    m.btn = 1
    m.target = invalid
    m.scrubDir = 0
    m.scrubSpeed = 0
    m.holdKey = ""
    m.holdScrub = false
    m.holdWasPlaying = false
    m.holdClock = CreateObject("roTimespan")
    m.holdLast = CreateObject("roTimespan")
    m.seekTag = m.top.findNode("seekTag")
    m.seekTag.font = hFont("bold", 26)
    m.seekDist = m.top.findNode("seekDist")
    m.seekDistText = m.top.findNode("seekDistText")
    m.seekDistText.font = hFont("bold", 24)
    m.bif = invalid
    buildButtons()
end sub

' ---------- open / close ----------
' mode "pause" (opened by pausing) or "peek" (playing on; hides itself after 5 s)
sub open(mode as dynamic)
    m.zone = "bar"
    m.target = invalid
    m.top.visible = true
    m.top.setFocus(true)
    paintClock()
    paint()
    armHide()
    m.clockTimer.control = "start"
end sub

sub close(unused = invalid as dynamic)
    if not m.top.visible then return
    stopScrub()
    m.target = invalid
    m.preview.visible = false
    m.hideTimer.control = "stop"
    m.clockTimer.control = "stop"
    m.top.visible = false
    m.top.action = { cmd: "hidden" }
end sub

sub armHide()
    m.hideTimer.control = "stop"
    if m.top.playing and m.target = invalid then m.hideTimer.control = "start"
end sub

sub onHideTimer()
    if m.top.playing and m.target = invalid then close()
end sub

' ---------- info ----------
sub onInfo()
    i = m.top.info
    if i = invalid then return
    k = i.kicker
    if k = invalid then k = ""
    t = i.title
    if t = invalid then t = ""
    m.top.findNode("kicker").text = UCase(k)
    m.top.findNode("title").text = t
    buildButtons()
end sub

sub onBifUrl()
    if m.bif <> invalid then m.bif.quit = true
    m.bif = invalid
    if m.top.bifUrl = "" then return
    m.bif = CreateObject("roSGNode", "BifTask")
    m.bif.url = m.top.bifUrl
    m.bif.observeField("frameUri", "onFrame")
    m.bif.control = "RUN"
end sub

sub onFrame()
    if m.target <> invalid then m.thumb.uri = m.bif.frameUri
end sub

sub onPlaying()
    buildButtons()
    if m.top.visible
        armHide()
        paintHints()
    end if
end sub

sub onPosition()
    if m.top.visible and m.target = invalid then paint()
end sub

' ---------- painting ----------
function clockText(secs as dynamic) as string
    if secs = invalid or secs < 0 then secs = 0
    s = Int(secs)
    h = Int(s / 3600)
    mi = Int((s mod 3600) / 60)
    se = s mod 60
    ss = se.toStr()
    if se < 10 then ss = "0" + ss
    if h > 0
        ms = mi.toStr()
        if mi < 10 then ms = "0" + ms
        return h.toStr() + ":" + ms + ":" + ss
    end if
    return mi.toStr() + ":" + ss
end function

' local wall time n seconds from now: ["10:42", "PM"]
function wallTime(ahead as dynamic) as object
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    if ahead <> invalid and ahead > 0 then dt.FromSeconds(dt.AsSeconds() + Int(ahead))
    h = dt.GetHours()
    ap = "AM"
    if h >= 12 then ap = "PM"
    h = h mod 12
    if h = 0 then h = 12
    mm = dt.GetMinutes().toStr()
    if Len(mm) < 2 then mm = "0" + mm
    return [h.toStr() + ":" + mm, ap]
end function

sub paintClock()
    w = wallTime(0)
    m.top.findNode("clock").text = w[0]
    m.top.findNode("ampm").text = w[1]
end sub

sub paint()
    dur = m.top.duration
    cur = m.top.position
    if m.target <> invalid then cur = m.target
    if cur < 0 then cur = 0
    if dur > 0 and cur > dur then cur = dur
    ' films over an hour show h:mm:ss, which is too wide for the 64 px labels beside the bar: step down to 44 px
    size = 64
    if dur >= 3600 then size = 44
    if m.timeSize <> size
        m.timeSize = size
        m.top.findNode("elapsed").font = hFont("bold", size)
        m.top.findNode("remaining").font = hFont("bold", size)
        m.top.findNode("elapsed").translation = [100, 800 + (64 - size) / 2]
        m.top.findNode("remaining").translation = [1600, 800 + (64 - size) / 2]
    end if
    m.top.findNode("elapsed").text = clockText(cur)
    left = dur - cur
    if dur <= 0 then left = 0
    m.top.findNode("remaining").text = "−" + clockText(left)
    w = wallTime(left)
    ends = m.top.findNode("ends")
    ends.text = "Ends at " + w[0] + " " + w[1]
    ends.width = 0
    tw = ends.boundingRect().width
    ends.translation = [1820 - tw, 882]
    m.top.findNode("moon").translation = [1820 - tw - 34, 884]
    pct = 0.0
    if dur > 0 then pct = 100.0 * cur / dur
    if pct < 0.6 then pct = 0.6
    hBraidSet(m.bar, pct)
    fillW = Int((m.barW - 2) * pct / 100)
    if fillW < 15 then fillW = 15
    hx = m.barX + 1 + fillW
    m.head.translation = [hx - 24, m.barY + 6 - 24]
    if m.target <> invalid
        px = hx - 160
        if px < 100 then px = 100
        if px > 1500 then px = 1500
        m.preview.translation = [px, 560]
        m.top.findNode("thumbTime").text = clockText(m.target)
        hasBif = (m.bif <> invalid and m.bif.ready = true)
        m.top.findNode("thumbBg").visible = hasBif
        m.thumb.visible = hasBif
        m.top.findNode("thumbRing").visible = hasBif
        if hasBif then m.bif.want = m.target
        m.preview.visible = true
    else
        m.preview.visible = false
    end if
    if m.scrubDir <> 0 and m.scrubSpeed > 0
        mult = [10, 30, 80, 180, 360]
        word = "Fast-forward"
        if m.scrubDir < 0 then word = "Rewind"
        m.seekTag.text = word + "  " + mult[m.scrubSpeed - 1].toStr() + "x"
        m.seekTag.visible = true
        paintSeekDist()
    else
        m.seekTag.visible = false
        m.seekDist.visible = false
    end if
    paintHints()
end sub

' The chip after the speed tag: distance from the playing point and the landing time, "+1:20 → 42:15"
sub paintSeekDist()
    if m.target = invalid
        m.seekDist.visible = false
        return
    end if
    d = Int(m.target) - Int(m.top.position)
    sign = "+"
    if d < 0
        sign = "−"
        d = -d
    end if
    m.seekDistText.text = sign + clockText(d) + " → " + clockText(m.target)
    w = Int(m.seekDistText.boundingRect().width) + 36
    m.top.findNode("seekDistFill").width = w
    m.top.findNode("seekDistRing").width = w
    tagW = Int(m.seekTag.boundingRect().width)
    m.seekDist.translation = [300 + tagW + 18, 878]
    m.seekDist.visible = true
end sub

sub paintHints()
    if m.target <> invalid
        keys = [{ icon: "lr", label: "Move" }, { text: "OK", label: "Jump here" }, { icon: "back", label: "Cancel" }]
    else if m.zone = "bar"
        okLabel = "Pause"
        if not m.top.playing then okLabel = "Play"
        keys = [{ icon: "lr", label: "10 s back · 30 s ahead" }, { icon: "down", label: "Buttons" }, { text: "OK", label: okLabel }, { icon: "back", label: "Hide" }]
    else
        keys = [{ icon: "lr", label: "Choose" }, { icon: "up", label: "Timeline" }, { icon: "back", label: "Hide" }]
    end if
    m.hints.keys = keys
end sub

' ---------- buttons ----------
function buttonDefs() as object
    playIcon = "pause"
    playLabel = "Pause"
    if not m.top.playing
        playIcon = "play"
        playLabel = "Play"
    end if
    i = m.top.info
    if i = invalid then i = {}
    d = [{ id: "back10", icon: "back10", label: "Back 10" }, { id: "toggle", icon: playIcon, label: playLabel }, { id: "fwd30", icon: "fwd30", label: "Ahead 30" }, { id: "sep" }]
    d.push({ id: "cc", icon: "cc", label: "Subtitles" })
    d.push({ id: "audio", icon: "audio", label: "Audio" })
    if i.hasChapters = true then d.push({ id: "chapters", icon: "chap", label: "Chapters" })
    if i.isEpisode = true then d.push({ id: "episodes", icon: "eps", label: "Episodes" })
    if m.top.canNext then d.push({ id: "next", icon: "next", label: "Next ep" })
    d.push({ id: "quality", icon: "qual", label: "Quality" })
    d.push({ id: "info", icon: "info", label: "Info" })
    d.push({ id: "sleep", icon: "moon", label: "Sleep" })
    d.push({ id: "watched", icon: "check", label: "Watched" })
    return d
end function

sub buildButtons()
    row = m.top.findNode("buttons")
    if row = invalid then return
    keepId = invalid
    if m.defs <> invalid and m.btn < m.defs.count() then keepId = m.defs[m.btn].id
    row.removeChildrenIndex(row.getChildCount(), 0)
    m.defs = []
    for each d in buttonDefs()
        if d.id <> "sep" then m.defs.push(d)
    end for
    seps = 1
    total = m.defs.count() * 96 + (m.defs.count() - 1) * 6 + seps * 38
    x = Int(960 - total / 2)
    m.btnNodes = []
    for each d in buttonDefs()
        if d.id = "sep"
            r = row.createChild("Rectangle")
            r.width = 2
            r.height = 64
            r.color = "0x404B2DFF"
            r.translation = [x + 12, 0]
            x = x + 38
        else
            g = row.createChild("Group")
            g.translation = [x, 0]
            bg = g.createChild("Poster")
            bg.translation = [0, -12]
            bg.width = 96
            bg.height = 88
            icon = g.createChild("Poster")
            icon.uri = "pkg:/images/player/" + d.icon + ".png"
            icon.width = 36
            icon.height = 36
            icon.translation = [30, 14]
            lab = g.createChild("Label")
            lab.font = hFont("bold", 19)
            lab.text = d.label
            lab.width = 110
            lab.horizAlign = "center"
            lab.translation = [-7, 74]
            m.btnNodes.push({ bg: bg, icon: icon, label: lab, id: d.id })
            x = x + 102
        end if
    end for
    m.btn = 1
    if keepId <> invalid
        for k = 0 to m.defs.count() - 1
            if m.defs[k].id = keepId then m.btn = k
        end for
    end if
    paintButtons()
end sub

sub paintButtons()
    if m.btnNodes = invalid then return
    for k = 0 to m.btnNodes.count() - 1
        b = m.btnNodes[k]
        focused = (m.zone = "buttons" and k = m.btn)
        filled = focused or b.id = "toggle"
        if filled
            b.bg.uri = "pkg:/images/w/button-fill" + hVar(k) + ".9.png"
            b.bg.blendColor = m.c.gold
            b.icon.blendColor = m.c.goldInk
        else
            b.bg.uri = "pkg:/images/w/button-outline" + hVar(k) + ".9.png"
            b.bg.blendColor = "0x404B2DFF"
            b.icon.blendColor = m.c.ink
        end if
        if focused then b.label.color = "0xFFE7A0FF" else b.label.color = m.c.muted
    end for
end sub

sub pressButton(id as string)
    if id = "back10"
        jump(-10)
    else if id = "fwd30"
        jump(30)
    else if id = "toggle"
        m.top.action = { cmd: "toggle" }
    else
        m.top.action = { cmd: "button", id: id }
    end if
end sub

' ---------- seeking ----------
function clampTime(t as float) as float
    if t < 0 then t = 0
    if m.top.duration > 0 and t > m.top.duration - 1 then t = m.top.duration - 1
    return t
end function

sub jump(delta as integer)
    if m.target <> invalid or not m.top.playing
        ' paused: move a scrub point with a preview; OK jumps there
        base = m.top.position
        if m.target <> invalid then base = m.target
        m.target = clampTime(base + delta)
    else
        dest = clampTime(m.top.position + delta)
        m.top.position = dest
        m.top.action = { cmd: "seek", to: dest }
    end if
    paint()
end sub

sub startScrub(dir as integer)
    if m.target = invalid then m.target = m.top.position
    if dir = m.scrubDir
        if m.scrubSpeed < 4 then m.scrubSpeed = m.scrubSpeed + 1
    else
        m.scrubDir = dir
        m.scrubSpeed = 1
    end if
    m.hideTimer.control = "stop"
    m.scrubTimer.control = "start"
    paint()
end sub

sub stopScrub()
    m.scrubTimer.control = "stop"
    m.scrubDir = 0
    m.scrubSpeed = 0
    m.holdScrub = false
end sub

' ---------- hold Left/Right to seek ----------
' Roku repeats the key press while a button is held and sends press=false on release. A tap keeps its 10 s / 30 s
' skip; once held past 0.5 s the scrub starts and speeds up with the hold time (10x, 30x, 80x, 180x, 360x real time).
sub holdRepeat(key as string)
    secs = m.holdClock.TotalMilliseconds() / 1000
    if secs < 0.5 then return
    dir = 1
    if key = "left" then dir = -1
    wasHolding = m.holdScrub
    if not m.holdScrub
        m.holdScrub = true
        m.holdWasPlaying = m.top.playing
        if m.target = invalid then m.target = m.top.position
        m.scrubDir = dir
        m.hideTimer.control = "stop"
        m.scrubTimer.control = "start"
    end if
    sp = 1
    if secs >= 8 then
        sp = 5
    else if secs >= 5 then
        sp = 4
    else if secs >= 3 then
        sp = 3
    else if secs >= 1.5 then
        sp = 2
    end if
    ' the 0.25 s scrub tick repaints; only repaint here when the speed (or the start) changed
    changed = (sp <> m.scrubSpeed or not wasHolding)
    m.scrubSpeed = sp
    if changed then paint()
end sub

sub endHold()
    wasScrub = m.holdScrub
    m.holdKey = ""
    m.holdScrub = false
    if not wasScrub then return
    if m.holdWasPlaying and m.target <> invalid
        commit()
    else
        ' paused: leave the scrub point (OK jumps there, Back cancels)
        stopScrub()
        paint()
    end if
    armHide()
end sub

sub onScrubTick()
    if m.target = invalid then
        stopScrub()
        return
    end if
    if m.holdScrub and m.holdLast.TotalMilliseconds() > 900
        ' the release was missed: stop rather than run away
        endHold()
        return
    end if
    steps = [2.5, 7.5, 20, 45, 90]
    m.target = clampTime(m.target + m.scrubDir * steps[m.scrubSpeed - 1])
    ' at either end: stop a scrub, but keep a held scrub alive so the release still commits it
    if not m.holdScrub and (m.target <= 0 or (m.top.duration > 0 and m.target >= m.top.duration - 1)) then stopScrub()
    paint()
end sub

sub commit()
    dest = m.target
    stopScrub()
    m.target = invalid
    m.top.position = dest
    m.top.action = { cmd: "seek", to: dest, play: true }
    paint()
end sub

' ---------- keys ----------
function onKeyEvent(key as string, press as boolean) as boolean
    if not m.top.visible then return false
    if not press
        if (key = "left" or key = "right") and m.holdKey = key
            endHold()
            return true
        end if
        return false
    end if
    armHide()
    if key = "back"
        if m.target <> invalid
            stopScrub()
            m.target = invalid
            paint()
        else
            close()
        end if
        return true
    else if key = "rewind"
        startScrub(-1)
        return true
    else if key = "fastforward"
        startScrub(1)
        return true
    else if key = "replay"
        m.target = invalid
        stopScrub()
        dest = clampTime(m.top.position - 10)
        m.top.position = dest
        m.top.action = { cmd: "seek", to: dest }
        paint()
        return true
    else if key = "play"
        if m.target <> invalid then commit() else m.top.action = { cmd: "toggle" }
        return true
    end if
    if m.zone = "bar"
        if key = "left" or key = "right"
            fresh = (m.holdKey <> key or m.holdLast.TotalMilliseconds() > 900)
            m.holdLast.Mark()
            if not fresh
                holdRepeat(key)
                return true
            end if
            m.holdKey = key
            m.holdClock.Mark()
            stopScrub()
            if key = "left" then jump(-10) else jump(30)
        else if key = "OK"
            if m.target <> invalid then commit() else m.top.action = { cmd: "toggle" }
        else if key = "down"
            if m.target <> invalid then return true
            m.zone = "buttons"
            m.hideTimer.control = "stop"
            paintButtons()
            paintHints()
        else
            return key <> "options"
        end if
        return true
    end if
    ' button row
    if key = "left"
        if m.btn > 0 then m.btn = m.btn - 1
        paintButtons()
    else if key = "right"
        if m.btn < m.defs.count() - 1 then m.btn = m.btn + 1
        paintButtons()
    else if key = "up"
        m.zone = "bar"
        paintButtons()
        paintHints()
        armHide()
    else if key = "OK"
        pressButton(m.defs[m.btn].id)
    else
        return key <> "options"
    end if
    return true
end function

' Called by the player for a key pressed while the overlay was hidden.
sub nudge(key as dynamic)
    onKeyEvent(key, true)
end sub
