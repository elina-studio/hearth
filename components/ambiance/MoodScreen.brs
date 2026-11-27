sub init()
    ' every mood with a picture of its own (built-in and Plex clips), not The Window
    loadMoodList()
    m.video = m.top.findNode("video")
    m.video.observeField("state", "onVideoState")
    m.credit = m.top.findNode("credit")
    m.credit.font = hFont("regular", 22)
    m.useVideo = false
    m.note = m.top.findNode("note")
    m.note.font = hFont("regular", 24)
    m.videoWatch = m.top.findNode("videoWatch")
    m.videoWatch.observeField("fire", "onVideoWatch")
    ' the Video node can take key focus for itself and then Back never reaches this screen: reclaim it twice a second
    m.focusTick = m.top.findNode("focusTick")
    m.focusTick.observeField("fire", "refocus")
    m.focusTick.control = "start"
    m.still = m.top.findNode("still")
    m.black = m.top.findNode("black")
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
    m.hint.text = "Down or OK  controls   ·   Left/Right  mood   ·   Back  leaves"
    m.controls = m.top.findNode("controls")
    m.controls.observeField("request", "onControls")
    m.yielded = false
    m.drift = m.top.findNode("drift")
    m.still.scaleRotateCenter = [960, 540]
    if m.global.hasField("music") and m.global.music <> invalid then m.global.music.observeFieldScoped("track", "paintState")
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

' every mood with a picture of its own (built-in and Plex clips), not The Window.
' Rebuilt on each mood change: the Plex clips may have arrived since the screen was made.
sub loadMoodList()
    m.moods = []
    m.titles = {}
    for each it in ambItems()
        if it.mood <> "window"
            m.moods.push(it.mood)
            m.titles[it.mood] = it.title
        end if
    end for
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
    loadMoodList()
    ' a "Video unavailable" note from the last mood must not follow us to the next one
    m.note.visible = false
    it = ambMood(md)
    m.item = it
    m.clip = invalid
    if it <> invalid then m.clip = it.clip
    m.clipRetried = false
    m.retried5 = false
    m.why = ""
    m.video.control = "stop"
    if m.clip <> invalid
        ' the person's own footage, streamed from their Plex "Ambiance" library
        m.note.visible = false
        if m.video.getParent() = invalid then m.top.insertChild(m.video, 3)
        m.video.content = clipContent(m.clip, needsConvert(m.clip))
        pic = m.clip.art
        if pic = invalid then pic = m.clip.thumb
        m.still.uri = ""
        if pic <> invalid then m.still.uri = fullStill(pic) else m.still.uri = it.still
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

'' Size the video so the whole frame shows (fit, with black bars when its shape isn't 16:9), never cropped:
' the owner's footage is framed on purpose (rain on the glass with the window edge in shot).
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
            h = 1920.0 / ar
        else
            w = 1080.0 * ar
        end if
    end if
    m.black.visible = (clip <> invalid)
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
            ' the TV's own music player would block the video: lend it the screen (speakers keep playing)
            wasYielded = m.yielded
            yieldMusic()
            if m.yielded and not wasYielded then startVideoSoon(0.6) else m.video.control = "play"
            armWatch(10)
        else
            yieldMusic()
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
        rejoinMusic()
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

' keep the control bar's labels in step
sub paintMix()
    m.controls.item = m.item
    m.controls.mode = mixMode()
    if m.dimIndex = 0 then m.controls.dimText = "Bright" else m.controls.dimText = Int(m.dimLevels[m.dimIndex] * 100).toStr() + "%"
    if m.sleepMin = 0 then m.controls.timerText = "Off" else m.controls.timerText = m.sleepMin.toStr() + " min"
    if m.controls.visible then m.controls.callFunc("paint", invalid)
end sub

sub openControls()
    paintMix()
    m.controls.visible = true
    m.controls.callFunc("open", invalid)
    ' the bar carries the mood's name and its own key hints, so the big title and hint line step aside (UX review item 38)
    m.hudIn.control = "stop"
    m.hudOut.control = "stop"
    m.hudTimer.control = "stop"
    m.hud.opacity = 0
    paintState()
end sub

sub closeControls()
    m.controls.visible = false
    ' Roku leaves focus on the child when its parent asks for it back: release it first
    ' (live walk Nov 27: Back closed the bar, but the hidden bar kept every key and Back could never leave)
    m.controls.setFocus(false)
    m.top.setFocus(true)
    showHud()
end sub

sub onControls()
    r = m.controls.request
    if r = invalid then return
    if r.act = "close"
        closeControls()
    else if r.act = "mix"
        m.reg.Write("ambMix", r.mode)
        m.reg.Flush()
        applyMix()
    else if r.act = "dim"
        m.dimIndex = (m.dimIndex + 1) mod 4
        m.dim.opacity = m.dimLevels[m.dimIndex]
        m.reg.Write("ambDim", m.dimIndex.toStr())
        m.reg.Flush()
        paintMix()
    else if r.act = "timer"
        mins = [0, 30, 60, 90]
        i = 0
        for k = 0 to 3
            if mins[k] = m.sleepMin then i = k
        end for
        setSleep(mins[(i + 1) mod 4])
        paintMix()
    end if
    paintState()
end sub

' the TV lends its screen to the video: speakers keep the song (or, with none, it pauses in place)
sub yieldMusic()
    mp = musicNode()
    if mp = invalid then return
    if m.yielded then return
    if mp.state = "playing" or mp.state = "buffering" or mp.state = "paused"
        print "[ambiance] tvYield (music "; mp.state; ")"
        mp.command = { cmd: "tvYield" }
        m.yielded = true
    end if
end sub

' give the TV back to the music (same spot, in step with the speakers)
sub rejoinMusic()
    mp = musicNode()
    if mp = invalid then return
    if m.yielded
        print "[ambiance] tvRejoin"
        mp.command = { cmd: "tvRejoin" }
        m.yielded = false
    else if mp.state <> "playing" and mp.state <> "buffering"
        mp.command = { cmd: "play" }
    end if
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
    if m.useVideo and not m.asleep
        m.video.control = "play"
        armWatch(10)
    end if
end sub

sub armWatch(sec as float)
    m.videoWatch.control = "stop"
    m.videoWatch.duration = sec
    m.videoWatch.control = "start"
end sub

' the video never started (or errored twice): show the still, calm, with a small note; Back always works
sub videoFailed(why as string)
    print "[ambiance] video gave up: "; why
    code = why
    if m.why <> "" then code = m.why + " / " + why
    info = ""
    if m.clip <> invalid then info = "  " + toStr0(m.clip.videoCodec) + " " + toStr0(m.clip.width) + "x" + toStr0(m.clip.height) + " " + toStr0(m.clip.container)
    m.videoWatch.control = "stop"
    m.video.control = "stop"
    m.video.visible = false
    ' take the player out of the screen altogether so it can't hold the remote's focus
    if m.video.getParent() <> invalid then m.top.removeChild(m.video)
    m.useVideo = false
    m.drift.control = "stop"
    m.still.scale = [1.0, 1.0]
    m.still.translation = [0, 0]
    m.still.visible = true
    m.note.text = "Video unavailable. Back to leave.   [" + code + "]" + info
    m.note.visible = true
    if m.yielded then rejoinMusic()
    refocus()
    showHud()
end sub

sub onVideoWatch()
    if not m.useVideo or m.asleep then return
    if m.video.state = "playing" then return
    print "[ambiance] video start timeout, state "; m.video.state
    if m.clip <> invalid and not m.clipRetried
        m.why = "first try timed out (" + m.video.state + ")"
        m.clipRetried = true
        m.video.control = "stop"
        m.video.content = clipContent(m.clip, true)
        m.video.control = "play"
        armWatch(40)
    else
        videoFailed("convert timed out (" + m.video.state + ")")
    end if
end sub

' focus must stay on this screen or Back goes nowhere
sub refocus()
    if m.controls.visible then return
    if hDialogUp() then return
    if not m.top.hasFocus() then m.top.setFocus(true)
end sub

sub onVideoState()
    print "[ambiance] video state "; m.video.state
    refocus()
    if m.video.state = "error"
        print "[ambiance] video error: "; m.video.errorCode; " "; m.video.errorMsg
        ' -5 "only one playing instance": something (music) still holds the player; stop it and retry once
        if m.video.errorCode = -5 and m.retried5 <> true
            m.retried5 = true
            m.yielded = false
            yieldMusic()
            m.sound.active = false
            startVideoSoon(1.0)
            return
        end if
        ' a phone clip in a format the TV can't open directly: ask Plex to convert it, once
        if m.clip <> invalid and not m.clipRetried
            m.why = "first try error " + m.video.errorCode.toStr()
            m.clipRetried = true
            m.video.content = clipContent(m.clip, true)
            m.video.control = "play"
            armWatch(40)
        else
            videoFailed("error " + m.video.errorCode.toStr() + " " + m.video.errorMsg)
        end if
    end if
    if m.video.state = "playing"
        m.videoWatch.control = "stop"
        m.note.visible = false
        m.still.visible = false
    end if
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
            s = hClean(mp.track.title)
            ar = hArtist(mp.track.artist)
            if ar <> "" then s = s + "  ·  " + ar
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
    if m.controls.visible then return
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
    d = CreateObject("roSGNode", "HearthDialog")
    d.title = titleOf(m.top.mood)
    d.icon = "pkg:/images/music/icons/moon.png"
    if soundOn() then snd = "Sound: On" else snd = "Sound: Off"
    m.menuMins = [-1, 0, 30, 60, 90, -2]
    labels = [snd]
    lines = ["The fire, the rain, the night"]
    icons = ["pkg:/images/music/icons/speaker.png"]
    for each mins in [0, 30, 60, 90]
        if mins = 0 then t = "No timer" else t = "Stop in " + mins.toStr() + " min"
        labels.push(t)
        if mins = 0 then lines.push("Stays on until you leave") else lines.push("Fades to black, then quiet")
        if mins = m.sleepMin then icons.push("pkg:/images/music/icons/check.png") else icons.push("pkg:/images/music/icons/clock.png")
    end for
    if m.cornerClock.visible then labels.push("Corner clock: On") else labels.push("Corner clock: Off")
    lines.push("A small clock in the corner")
    icons.push("pkg:/images/music/icons/clock.png")
    d.buttons = labels
    d.subs = lines
    d.icons = icons
    d.heads = { "0": "Sound", "1": "Sleep timer", "5": "On screen" }
    d.observeField("buttonSelected", "onMenu")
    d.observeField("wasClosed", "onMenuClosed")
    m.dialog = d
    hShowDialog(d)
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
    if m.controls.visible then m.controls.setFocus(true) else m.top.setFocus(true)
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
    m.focusTick.control = "stop"
    m.sleepTimer.control = "stop"
    m.videoWatch.control = "stop"
    ' a pending start timer must not begin the video after we've gone, and the music observer goes with us
    m.useVideo = false
    mp = musicNode()
    if mp <> invalid then mp.unobserveFieldScoped("track")
    m.sound.active = false
    m.scene.running = false
    m.video.control = "stop"
    m.drift.control = "stop"
    if m.yielded then rejoinMusic()
    m.top.request = { action: "back" }
end sub

function hKeyInner(key as string, press as boolean) as boolean
    if not press then return false
    print "[ambiance] key "; key
    if key = "back"
        leave()
        return true
    end if
    if hMediaKey(key) then return false
    if key = "back"
        leave()
        return true
    end if
    if m.asleep or m.night.opacity > 0
        wake()
        return true
    end if
    if key = "OK" or key = "down"
        openControls()
    else if key = "left"
        nextMood(-1)
    else if key = "right"
        nextMood(1)
    else if key = "up"
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
        m.global.ambItems = ambMerge(t.response.Clips, t.response.Preparing)
    end if
    onMood()
end sub

' menu sound for whatever the handler above took (source/util.brs hKeySfx)
function onKeyEvent(key as string, press as boolean) as boolean
    return hKeySfx(key, press, hKeyInner(key, press))
end function
