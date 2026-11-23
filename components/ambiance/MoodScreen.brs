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
    m.hint.text = "OK switch sound   ·   Left/Right mood   ·   Up/Down dim   ·   * options   ·   Back leaves"
    m.mixGroup = m.top.findNode("mix")
    m.drift = m.top.findNode("drift")
    m.still.scaleRotateCenter = [960, 540]
    if m.global.hasField("music") and m.global.music <> invalid then m.global.music.observeField("track", "paintState")
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
    ' Opened straight from Home before the Ambiance room ever loaded: fetch the Plex clips first,
    ' so a mood with your own footage plays it instead of the drawn scene.
    if needClips()
        m.clipsAsked = true
        sec = ""
        if m.global.libraries.ambiance <> invalid then sec = m.global.libraries.ambiance
        hPlex("clips", { section: sec }, "onMoodClips")
        return
    end if
    it = ambMood(md)
    m.item = it
    m.clip = invalid
    if it <> invalid then m.clip = it.clip
    m.clipRetried = false
    m.retried5 = false
    m.video.control = "stop"
    if m.clip <> invalid
        ' the person's own footage, streamed from their Plex "Ambiance" library
        m.video.content = clipContent(m.clip, false)
        pic = m.clip.art
        if pic = invalid then pic = m.clip.thumb
        m.still.uri = ""
        if pic <> invalid then m.still.uri = fullStill(pic)
        m.credit.text = ""
    end if
    fillScreen(m.clip)
    applyMix()
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

' Size the video so it covers the whole screen whatever its shape (crop, never black bars):
' the picture is scaled to the screen's longer side and centred, the overflow falls off-screen.
sub fillScreen(clip as dynamic)
    w = 1920.0
    h = 1080.0
    ar = 0.0
    if clip <> invalid
        if clip.width <> invalid and clip.height <> invalid and clip.height > 0 then ar = clip.width / clip.height
        if ar = 0 and clip.aspect <> invalid then ar = Val(clip.aspect.toStr())
    end if
    if ar > 0
        if ar > w / h
            w = 1080.0 * ar
        else
            h = 1920.0 / ar
        end if
    end if
    m.video.width = Int(w)
    m.video.height = Int(h)
    m.video.translation = [Int((1920 - w) / 2), Int((1080 - h) / 2)]
    print "[ambiance] video rect "; Int(w); "x"; Int(h); " (clip aspect "; ar; ")"
end sub

' ---------- the sound switch: Fire (or Rain...) / Music / Both ----------
' The TV plays one stream at a time, so:
'   fire  = the clip moving, with its own sound; music is stopped (drawn moods: scene + generated sound)
'   music = your music keeps playing; the clip's still drifts slowly (no video)
'   both  = music + the generated crackle/rain loop (a SoundEffect, which can play alongside music)
function mixMode() as string
    v = m.reg.Read("ambMix")
    if v <> "music" and v <> "both" then v = "fire"
    return v
end function

function musicNode() as dynamic
    if not m.global.hasField("music") then return invalid
    return m.global.music
end function

sub applyMix()
    mode = mixMode()
    md = m.top.mood
    mp = musicNode()
    hasClip = (m.clip <> invalid)
    m.useVideo = hasClip and mode = "fire"
    m.drift.control = "stop"
    m.still.scale = [1.0, 1.0]
    m.still.translation = [0, 0]
    if mode = "fire"
        m.sound.preferSfx = false
        if hasClip
            m.scene.running = false
            m.scene.visible = false
            m.sound.active = false
            m.still.visible = true
            m.video.visible = true
            m.video.mute = not soundPref(md)
            ' music (even paused) holds the player, so stop it first
            if mp <> invalid and mp.state <> invalid and mp.state <> "none" and mp.state <> "stopped"
                print "[ambiance] stopping music ("; mp.state; ") so the video can play"
                mp.command = { cmd: "stop" }
                startVideoSoon(0.6)
            else
                m.video.control = "play"
            end if
        else
            if mp <> invalid and (mp.state = "playing" or mp.state = "buffering") then mp.command = { cmd: "pause" }
            showScene(md)
            m.sound.mood = md
            m.sound.on = soundPref(md)
            m.sound.active = true
        end if
    else
        m.video.control = "stop"
        m.video.visible = false
        if hasClip
            m.scene.running = false
            m.scene.visible = false
            m.still.visible = true
            m.drift.control = "start"
        else
            showScene(md)
        end if
        if mp <> invalid and mp.state <> "playing" and mp.state <> "buffering" then mp.command = { cmd: "play" }
        if mode = "both"
            ' never the Audio node here: it would fight the music for the player
            m.sound.preferSfx = true
            m.sound.mood = ambSoundMood(m.item)
            m.sound.on = true
            m.sound.active = true
        else
            m.sound.active = false
        end if
    end if
    paintMix()
end sub

sub showScene(md as string)
    m.video.control = "stop"
    m.video.visible = false
    m.still.visible = false
    m.scene.visible = true
    m.scene.mood = md
    m.scene.running = true
end sub

sub cycleMix()
    mode = mixMode()
    if mode = "fire"
        mode = "music"
    else if mode = "music"
        mode = "both"
    else
        mode = "fire"
    end if
    m.reg.Write("ambMix", mode)
    m.reg.Flush()
    applyMix()
end sub

' the switch: three segments, the chosen one filled gold
sub paintMix()
    lab = ambSoundLabel(m.item)
    names = [lab.word, "Music", "Both"]
    icons = [[lab.icon], ["note"], [lab.icon, "note"]]
    modes = ["fire", "music", "both"]
    cur = mixMode()
    m.mixGroup.removeChildrenIndex(m.mixGroup.getChildCount(), 0)
    pill = m.mixGroup.createChild("Poster")
    pill.uri = "pkg:/images/amb/mix-pill.png"
    pill.width = 528
    pill.height = 80
    for i = 0 to 2
        on = (modes[i] = cur)
        x = 8 + i * 172
        if on
            seg = m.mixGroup.createChild("Poster")
            seg.uri = "pkg:/images/amb/mix-seg.png"
            seg.width = 168
            seg.height = 64
            seg.translation = [x, 8]
        end if
        if on then col = "0x1A1408FF" else col = "0xEDE6CAFF"
        ix = x + 18
        for each ic in icons[i]
            p = m.mixGroup.createChild("Poster")
            p.uri = "pkg:/images/amb/mix-" + ic + ".png"
            p.width = 32
            p.height = 32
            p.translation = [ix, 24]
            p.blendColor = col
            ix = ix + 34
        end for
        l = m.mixGroup.createChild("Label")
        l.font = hFont("regular", 28)
        l.color = col
        l.text = names[i]
        l.translation = [ix + 6, 20]
    end for
end sub

sub startVideoSoon(sec as float)
    t = CreateObject("roSGNode", "Timer")
    t.duration = sec
    t.repeat = false
    t.observeField("fire", "startVideoNow")
    m.startTimer = t
    t.control = "start"
end sub

sub startVideoNow()
    if m.useVideo and not m.asleep then m.video.control = "play"
end sub

sub onVideoState()
    print "[ambiance] video state "; m.video.state
    if m.video.state = "error"
        print "[ambiance] video error: "; m.video.errorCode; " "; m.video.errorMsg
        ' -5 "only one playing instance": something (music) still holds the player; stop it and retry once
        if m.video.errorCode = -5 and m.retried5 <> true
            m.retried5 = true
            mp = m.global.music
            if mp <> invalid then mp.command = { cmd: "stop" }
            m.sound.active = false
            startVideoSoon(1.0)
            return
        end if
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
    mode = mixMode()
    if mode = "fire"
        if soundOn() then s = "Sound on" else s = "Sound off"
    else
        s = "Your music"
        mp = musicNode()
        if mp <> invalid and mp.track <> invalid and mp.track.title <> invalid
            s = mp.track.title
            if mp.track.artist <> invalid and mp.track.artist <> "" then s = s + "  ·  " + mp.track.artist
        end if
        if mode = "both" then s = s + "   +   " + LCase(ambSoundLabel(m.item).word)
    end if
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
    m.drift.control = "stop"
    mp = musicNode()
    if mixMode() <> "fire" and mp <> invalid then mp.command = { cmd: "pause" }
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
        applyMix()
    end if
    showHud()
end sub

sub leave()
    m.sleepTimer.control = "stop"
    m.sound.active = false
    m.scene.running = false
    m.video.control = "stop"
    m.drift.control = "stop"
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
        cycleMix()
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

function needClips() as boolean
    if m.clipsAsked = true then return false
    if m.global.hasField("ambItems") and m.global.ambItems <> invalid and m.global.ambItems.count() > 0 then return false
    libs = m.global.libraries
    return libs <> invalid and libs.Count() > 0
end function

sub onMoodClips(event as object)
    t = hTaskFrom(event)
    if t.ok and t.response.Clips <> invalid and t.response.Clips.count() > 0
        if not m.global.hasField("ambItems") then m.global.addFields({ ambItems: [] })
        m.global.ambItems = ambMerge(t.response.Clips)
    end if
    onMood()
end sub
