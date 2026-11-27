' Up next countdown. Left/Right pick a button, OK presses it, Back = Watch credits, * turns autoplay on/off.
sub init()
    m.top.visible = false
    m.top.findNode("head").font = hFont("fell", 36)
    m.top.findNode("rolling").font = hFont("caps", 22)
    m.top.findNode("kicker").font = hFont("caps", 22)
    m.top.findNode("title").font = hFont("bold", 30)
    m.top.findNode("meta").font = hFont("regular", 22)
    m.top.findNode("playLabel").font = hFont("bold", 24)
    m.top.findNode("stayLabel").font = hFont("bold", 24)
    m.top.findNode("count").font = hFont("bold", 30)
    m.bar = hBraid(m.top.findNode("bar"), 630, 0)
    m.tick = m.top.findNode("tick")
    m.tick.observeField("fire", "onTick")
    m.focus = 0
    m.left = 0.0
end sub

sub begin(unused = invalid as dynamic)
    it = m.top.item
    if it = invalid then return
    k = "S" + hNum(it.ParentIndexNumber) + " E" + hNum(it.IndexNumber)
    m.top.findNode("kicker").text = k
    name = it.Name
    if name = invalid then name = ""
    m.top.findNode("title").text = name
    m.top.findNode("meta").text = metaLine(it)
    m.top.findNode("thumb").uri = hImage(it, "Thumb", 256)
    m.focus = 0
    m.left = m.top.seconds
    m.base = m.left
    m.clock = CreateObject("roTimespan")
    m.top.visible = true
    paint()
    if m.top.autoplay then m.tick.control = "start"
end sub

sub halt(unused = invalid as dynamic)
    m.tick.control = "stop"
    m.top.visible = false
end sub

' "43 min · ends 11:27 PM"
function metaLine(it as object) as string
    if it.RunTimeTicks = invalid then return ""
    mins = Int(it.RunTimeTicks / 600000000)
    if mins < 1 then mins = 1
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    secs = dt.AsSeconds() + mins * 60 + m.top.seconds
    dt.FromSeconds(secs)
    h = dt.GetHours()
    ap = "AM"
    if h >= 12 then ap = "PM"
    h = h mod 12
    if h = 0 then h = 12
    mm = dt.GetMinutes().toStr()
    if Len(mm) < 2 then mm = "0" + mm
    return mins.toStr() + " min · ends " + h.toStr() + ":" + mm + " " + ap
end function

' The video was paused or resumed: the countdown waits with it, so a paused episode never jumps to the next one
sub onHold()
    if m.clock = invalid then return
    if not m.top.hold
        m.base = m.left
        m.clock.Mark()
    end if
end sub

sub onTick()
    if m.top.hold then return
    left = m.base - m.clock.TotalMilliseconds() / 1000.0
    if left <= 0
        m.tick.control = "stop"
        m.left = 0
        paint()
        m.top.action = "play"
        return
    end if
    m.left = left
    paint()
end sub

sub paint()
    if m.bar = invalid then return
    c = hColors()
    playBg = m.top.findNode("playBg")
    stayBg = m.top.findNode("stayBg")
    focusOn = [m.focus = 0, m.focus = 1]
    bgs = [playBg, stayBg]
    labels = [m.top.findNode("playLabel"), m.top.findNode("stayLabel")]
    icons = [m.top.findNode("playIcon"), m.top.findNode("stayIcon")]
    for i = 0 to 1
        if focusOn[i]
            bgs[i].uri = "pkg:/images/w/button-fill" + hVar(i) + ".9.png"
            bgs[i].blendColor = c.gold
            labels[i].color = c.goldInk
            icons[i].blendColor = c.goldInk
        else
            bgs[i].uri = "pkg:/images/w/button-outline" + hVar(i) + ".9.png"
            bgs[i].blendColor = "0x404B2DFF"
            labels[i].color = c.ink
            icons[i].blendColor = c.ink
        end if
    end for
    count = m.top.findNode("count")
    count.color = labels[0].color
    if m.top.autoplay
        count.text = Int(m.left + 0.999).toStr()
        m.top.findNode("rolling").text = "CREDITS ROLLING"
        hBraidSet(m.bar, 100.0 * (m.top.seconds - m.left) / m.top.seconds)
        m.bar.visible = true
    else
        count.text = ""
        m.top.findNode("rolling").text = "AUTOPLAY OFF"
        m.bar.visible = false
    end if
end sub

function hKeyInner(key as string, press as boolean) as boolean
    if not press or not m.top.visible then return false
    if key = "left" or key = "right"
        if key = "left" then m.focus = 0 else m.focus = 1
        paint()
        return true
    else if key = "OK"
        m.tick.control = "stop"
        if m.focus = 0 then m.top.action = "play" else m.top.action = "dismiss"
        return true
    else if key = "back"
        m.tick.control = "stop"
        m.top.action = "dismiss"
        return true
    else if key = "options"
        ' * turns autoplay on/off for every show (remembered on the TV)
        on = not m.top.autoplay
        reg = CreateObject("roRegistrySection", "hearth")
        if on then reg.Write("autoplay", "on") else reg.Write("autoplay", "off")
        reg.Flush()
        m.top.autoplay = on
        if on
            m.clock = CreateObject("roTimespan")
            m.left = m.top.seconds
            m.base = m.left
            m.tick.control = "start"
        else
            m.tick.control = "stop"
        end if
        paint()
        return true
    end if
    ' play/pause etc. still reach the video
    return false
end function

' menu sound for whatever the handler above took (source/util.brs hKeySfx)
function onKeyEvent(key as string, press as boolean) as boolean
    return hKeySfx(key, press, hKeyInner(key, press))
end function
