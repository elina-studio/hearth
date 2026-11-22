sub init()
    ' every mood with a picture of its own (built-in and Plex clips), not The Window
    m.moods = []
    m.titles = {}
    for each it in ambItems()
        if it.mood <> "window"
            m.moods.push(it.mood)
            m.titles[it.mood] = it.title
        end if
    end for
    m.video = m.top.findNode("video")
    m.video.observeField("state", "onVideoState")
    m.credit = m.top.findNode("credit")
    m.credit.font = hFont("regular", 20)
    m.useVideo = false
    m.still = m.top.findNode("still")
    m.dim = m.top.findNode("dim")
    m.dimLevels = [0, 0.25, 0.5, 0.7]
    m.dimIndex = 0
    v = CreateObject("roRegistrySection", "hearth").Read("ambDim")
    if v <> "" then m.dimIndex = Val(v)
    if m.dimIndex < 0 or m.dimIndex > 3 then m.dimIndex = 0
    m.dim.opacity = m.dimLevels[m.dimIndex]
    m.cornerClock = m.top.findNode("cornerClock")
    m.cornerClock.font = hFont("bold", 36)
    m.cornerClock.visible = (CreateObject("roRegistrySection", "hearth").Read("ambClock") = "1")
    ct = m.top.findNode("clockTick")
    ct.observeField("fire", "paintClock")
    ct.control = "start"
    m.scene = m.top.findNode("scene")
    m.sound = m.top.findNode("sound")
    m.hud = m.top.findNode("hud")
    m.top.findNode("name").font = hFont("caps", 64)
    m.state = m.top.findNode("state")
    m.state.font = hFont("bold", 28)
    m.hint = m.top.findNode("hint")
    m.hint.font = hFont("regular", 24)
    m.hint.text = "OK sound   ·   Left/Right mood   ·   Up/Down dim   ·   * options   ·   Back leaves"
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
    it = ambMood(md)
    m.useVideo = ambHasVideo(it)
    if m.useVideo
        ' real footage: the video carries its own sound, muted on request
        m.scene.running = false
        m.scene.visible = false
        m.sound.active = false
        m.clip = it.clip
        m.clipRetried = false
        if m.clip <> invalid
            ' the person's own footage, streamed from their Plex "Ambiance" library
            m.video.content = clipContent(m.clip, false)
            pic = m.clip.art
            if pic = invalid then pic = m.clip.thumb
            m.still.uri = ""
            if pic <> invalid then m.still.uri = fullStill(pic)
        else
            c = CreateObject("roSGNode", "ContentNode")
            c.url = it.video
            c.streamFormat = "mp4"
            m.video.content = c
            ' the still covers the screen until the first frame is up
            m.still.uri = "pkg:/images/amb/full-" + md + ".jpg"
        end if
        m.still.visible = true
        m.video.visible = true
        m.video.mute = not soundPref(md)
        m.video.control = "play"
        m.credit.text = it.credit
    else
        ' no footage in this build: the drawn scene and its generated sound
        m.video.control = "stop"
        m.video.visible = false
        m.still.visible = false
        m.scene.visible = true
        m.scene.mood = md
        m.scene.running = true
        m.sound.mood = md
        m.sound.on = soundPref(md)
        m.sound.active = true
        m.credit.text = ""
    end if
    ' lights out means "stop in 30 min" unless a timer is already set
    if md = "lightsout" and m.sleepMin = 0 then setSleep(30)
    m.reg.Write("ambLast", md)
    m.reg.Flush()
    paintClock()
    m.top.findNode("name").text = UCase(titleOf(md))
    paintState()
    showHud()
end sub

' A Plex clip as video content: the file as it is, or (transcode=true) converted by Plex to HLS
' for files the TV can't play directly. Either way it loops.
function clipContent(clip as object, transcode as boolean) as object
    server = m.global.plexServer
    token = m.global.plexServerToken
    c = CreateObject("roSGNode", "ContentNode")
    if not transcode
        c.url = server + clip.key + "?X-Plex-Token=" + token
        if LCase(clip.container) = "mkv" then c.streamFormat = "mkv" else c.streamFormat = "mp4"
    else
        q = "path=" + hEscape("/library/metadata/" + clip.Id.toStr()) + "&mediaIndex=0&partIndex=0&protocol=hls&fastSeek=1"
        q = q + "&directPlay=0&directStream=1&directStreamAudio=1&videoResolution=1920x1080&maxVideoBitrate=12000"
        q = q + "&subtitles=none&session=" + m.global.deviceId + "-amb" + Rnd(100000).toStr()
        q = q + "&X-Plex-Client-Identifier=" + hEscape(m.global.deviceId) + "&X-Plex-Product=Hearth&X-Plex-Platform=Roku&X-Plex-Token=" + token
        q = q + "&X-Plex-Client-Profile-Extra=" + hEscape("add-transcode-target(type=videoProfile&context=streaming&protocol=hls&container=mpegts&videoCodec=h264&audioCodec=aac,ac3)")
        c.url = server + "/video/:/transcode/universal/start.m3u8?" + q
        c.streamFormat = "hls"
    end if
    return c
end function

function fullStill(path as string) as string
    return m.global.plexServer + "/photo/:/transcode?width=1280&height=720&minSize=1&upscale=1&url=" + hEscape(path) + "&X-Plex-Token=" + m.global.plexServerToken
end function

sub onVideoState()
    print "[ambiance] video state "; m.video.state
    if m.video.state = "error"
        print "[ambiance] video error: "; m.video.errorMsg
        ' a phone clip in a format the TV can't open directly: ask Plex to convert it, once
        if m.clip <> invalid and not m.clipRetried
            m.clipRetried = true
            m.video.content = clipContent(m.clip, true)
            m.video.control = "play"
        end if
    end if
    if m.video.state = "playing" then m.still.visible = false
end sub

function soundOn() as boolean
    if m.useVideo then return not m.video.mute
    return m.sound.on
end function

function titleOf(md as string) as string
    t = m.titles[md]
    if t = invalid then return md
    return t
end function

sub onShown(unused as dynamic)
    m.top.setFocus(true)
end sub

function soundPref(md as string) as boolean
    v = m.reg.Read("ambSound_" + md)
    return (v <> "0")
end function

sub paintState()
    if soundOn() then s = "Sound on" else s = "Sound off"
    if m.dimIndex > 0 then s = s + "   ·   Dimmed " + Int(m.dimLevels[m.dimIndex] * 100).toStr() + "%"
    if m.sleepMin > 0 and m.sleepAt <> invalid then s = s + "   ·   Stops at " + clockText(m.sleepAt)
    m.state.text = s
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    m.clock.text = clockText(now)
end sub

sub paintClock()
    now = CreateObject("roDateTime")
    now.ToLocalTime()
    m.cornerClock.text = clockText(now)
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
    on = not soundOn()
    if m.useVideo then m.video.mute = not on else m.sound.on = on
    if on then v = "1" else v = "0"
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
    d.title = titleOf(m.top.mood)
    d.message = ["Sound and sleep timer"]
    if soundOn() then snd = "Turn sound off" else snd = "Turn sound on"
    m.menuMins = [-1, 0, 30, 60, 90, -2]
    labels = [snd]
    for each mins in [0, 30, 60, 90]
        if mins = 0 then t = "No timer" else t = "Stop in " + mins.toStr() + " min"
        if mins = m.sleepMin then t = t + "  (now)"
        labels.push(t)
    end for
    if m.cornerClock.visible then labels.push("Hide the clock") else labels.push("Show the clock")
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
    else if m.menuMins[i] = -2
        m.cornerClock.visible = not m.cornerClock.visible
        if m.cornerClock.visible then v = "1" else v = "0"
        m.reg.Write("ambClock", v)
        m.reg.Flush()
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
    if m.useVideo then m.video.control = "pause"
    m.sleepMin = 0
    m.sleepAt = invalid
end sub

sub wake()
    m.asleep = false
    m.sleepFade.control = "stop"
    m.night.opacity = 0
    if m.useVideo
        m.video.control = "resume"
    else
        m.scene.running = true
        m.sound.active = true
    end if
    showHud()
end sub

sub leave()
    m.sleepTimer.control = "stop"
    m.sound.active = false
    m.scene.running = false
    m.video.control = "stop"
    m.top.request = { action: "back" }
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
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
    else if key = "up" or key = "down"
        if key = "down" then m.dimIndex = m.dimIndex + 1 else m.dimIndex = m.dimIndex - 1
        if m.dimIndex < 0 then m.dimIndex = 0
        if m.dimIndex > 3 then m.dimIndex = 3
        m.dim.opacity = m.dimLevels[m.dimIndex]
        m.reg.Write("ambDim", m.dimIndex.toStr())
        m.reg.Flush()
        showHud()
    else if key = "options"
        sleepMenu()
    else
        showHud()
        return false
    end if
    return true
end function
