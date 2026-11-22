sub init()
    m.moods = ["hearth", "rain", "fireflies", "lightsout"]
    m.titles = { hearth: "Hearth", rain: "Rain on the roof", fireflies: "Fireflies", lightsout: "Lights out" }
    m.scene = m.top.findNode("scene")
    m.sound = m.top.findNode("sound")
    m.hud = m.top.findNode("hud")
    m.top.findNode("name").font = hFont("caps", 64)
    m.state = m.top.findNode("state")
    m.state.font = hFont("bold", 28)
    m.hint = m.top.findNode("hint")
    m.hint.font = hFont("regular", 24)
    m.hint.text = "OK sound   ·   Left/Right mood   ·   * timer   ·   Back leaves"
    m.clock = m.top.findNode("clock")
    m.clock.font = hFont("bold", 40)
    m.hudIn = m.top.findNode("hudIn")
    m.hudOut = m.top.findNode("hudOut")
    m.hudTimer = m.top.findNode("hudTimer")
    m.hudTimer.observeField("fire", "hideHud")
    m.sleepTimer = m.top.findNode("sleepTimer")
    m.sleepTimer.observeField("fire", "onSleep")
    m.sleepFade = m.top.findNode("sleepFade")
    m.sleepFade.observeField("state", "onSleepFaded")
    m.night = m.top.findNode("night")
    m.reg = CreateObject("roRegistrySection", "hearth")
    m.sleepMin = 0
    m.sleepAt = invalid
    m.asleep = false
end sub

sub onMood()
    md = m.top.mood
    m.scene.mood = md
    m.sound.mood = md
    m.sound.on = soundPref(md)
    m.sound.active = true
    ' lights out means "stop in 30 min" unless a timer is already set
    if md = "lightsout" and m.sleepMin = 0 then setSleep(30)
    m.top.findNode("name").text = UCase(m.titles[md])
    paintState()
    showHud()
end sub

sub onShown(unused as dynamic)
    m.top.setFocus(true)
end sub

function soundPref(md as string) as boolean
    v = m.reg.Read("ambSound_" + md)
    return (v <> "0")
end function

sub paintState()
    if m.sound.on then s = "Sound on" else s = "Sound off"
    if m.sleepMin > 0 and m.sleepAt <> invalid then s = s + "   ·   Stops at " + clockText(m.sleepAt)
    m.state.text = s
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    m.clock.text = clockText(now)
end sub

function clockText(dt as object) as string
    h = dt.GetHours() mod 12
    if h = 0 then h = 12
    mi = dt.GetMinutes()
    mm = mi.toStr()
    if mi < 10 then mm = "0" + mm
    return h.toStr() + ":" + mm
end function

sub showHud()
    paintState()
    m.hudOut.control = "stop"
    if m.hud.opacity < 1 then m.hudIn.control = "start"
    m.hudTimer.control = "stop"
    m.hudTimer.control = "start"
end sub

sub hideHud()
    m.hudOut.control = "start"
end sub

sub toggleSound()
    md = m.top.mood
    m.sound.on = not m.sound.on
    if m.sound.on then v = "1" else v = "0"
    m.reg.Write("ambSound_" + md, v)
    m.reg.Flush()
end sub

sub nextMood(d as integer)
    n = m.moods.count()
    i = 0
    for k = 0 to n - 1
        if m.moods[k] = m.top.mood then i = k
    end for
    m.top.mood = m.moods[(i + d + n) mod n]
end sub

' ---------- sleep timer ----------
sub setSleep(minutes as integer)
    m.sleepMin = minutes
    m.sleepTimer.control = "stop"
    if minutes <= 0
        m.sleepAt = invalid
        return
    end if
    m.sleepTimer.duration = minutes * 60
    m.sleepTimer.control = "start"
    at = CreateObject("roDateTime")
    at.FromSeconds(at.AsSeconds() + minutes * 60)
    at.ToLocalTime()
    m.sleepAt = at
end sub

sub sleepMenu()
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = m.titles[m.top.mood]
    d.message = ["Sound and sleep timer"]
    if m.sound.on then snd = "Turn sound off" else snd = "Turn sound on"
    m.menuMins = [-1, 0, 30, 60, 90]
    labels = [snd]
    for each mins in [0, 30, 60, 90]
        if mins = 0 then t = "No timer" else t = "Stop in " + mins.toStr() + " min"
        if mins = m.sleepMin then t = t + "  (now)"
        labels.push(t)
    end for
    d.buttons = labels
    d.observeField("buttonSelected", "onMenu")
    d.observeField("wasClosed", "onMenuClosed")
    m.dialog = d
    m.top.getScene().dialog = d
end sub

sub onMenu()
    i = m.dialog.buttonSelected
    m.dialog.close = true
    if i = 0
        toggleSound()
    else
        setSleep(m.menuMins[i])
    end if
    showHud()
end sub

sub onMenuClosed()
    m.top.setFocus(true)
end sub

sub onSleep()
    ' fade everything to black, then stop the sound and the motion
    m.hudOut.control = "start"
    m.sleepFade.control = "start"
end sub

sub onSleepFaded()
    if m.sleepFade.state <> "stopped" or m.night.opacity < 0.99 then return
    m.asleep = true
    m.sound.active = false
    m.scene.running = false
    m.sleepMin = 0
    m.sleepAt = invalid
end sub

sub wake()
    m.asleep = false
    m.sleepFade.control = "stop"
    m.night.opacity = 0
    m.scene.running = true
    m.sound.active = true
    showHud()
end sub

sub leave()
    m.sleepTimer.control = "stop"
    m.sound.active = false
    m.scene.running = false
    m.top.request = { action: "back" }
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back"
        leave()
        return true
    end if
    if m.asleep or m.night.opacity > 0
        wake()
        return true
    end if
    if key = "OK"
        toggleSound()
        showHud()
    else if key = "left"
        nextMood(-1)
    else if key = "right"
        nextMood(1)
    else if key = "options"
        sleepMenu()
    else
        showHud()
        return false
    end if
    return true
end function
