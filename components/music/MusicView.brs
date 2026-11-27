sub init()
    m.groups = { cover: m.top.findNode("cover"), milk: m.top.findNode("milk"), hearth: m.top.findNode("hearth") }
    m.coverBlur = m.top.findNode("coverBlur")
    m.coverArt = m.top.findNode("coverArt")
    m.coverTitle = m.top.findNode("coverTitle")
    m.coverTitle.font = hFont("bold", 56)
    m.coverSub = m.top.findNode("coverSub")
    m.coverSub.font = hFont("regular", 32)
    m.coverClip = m.top.findNode("coverClip")
    m.coverTip = m.top.findNode("coverTip")
    m.strip = m.top.findNode("strip")
    m.sArt = m.top.findNode("sArt")
    m.sEyebrow = m.top.findNode("sEyebrow")
    m.sEyebrow.font = hFont("caps", 26)
    m.sTitle = m.top.findNode("sTitle")
    m.sTitle.font = hFont("bold", 40)
    m.sSub = m.top.findNode("sSub")
    m.sSub.font = hFont("regular", 26)
    m.sHint = m.top.findNode("sHint")
    m.sHint.font = hFont("regular", 22)
    m.sToast = m.top.findNode("sToast")
    m.sToast.font = hFont("bold", 24)
    m.presetName = m.top.findNode("presetName")
    m.presetName.font = hFont("caps", 30)
    m.lookTag = m.top.findNode("lookTag")
    m.lookTagBg = m.top.findNode("lookTagBg")
    m.tagIn = m.top.findNode("tagIn")
    m.tagOut = m.top.findNode("tagOut")
    m.tagTimer = m.top.findNode("tagTimer")
    m.tagTimer.observeField("fire", "hideLookTag")
    m.vizVideo = m.top.findNode("vizVideo")
    m.vizVideo.visible = false
    m.vizBack = m.top.findNode("vizBack")
    m.vizNote = m.top.findNode("vizNote")
    m.vizNote.font = hFont("regular", 32)
    m.picker = m.top.findNode("picker")
    m.picker.observeField("chosen", "onLookChosen")
    m.noFire = m.top.findNode("noFire")
    m.noFire.font = hFont("regular", 32)
    m.stripIn = m.top.findNode("stripIn")
    m.stripOut = m.top.findNode("stripOut")
    m.stripTimer = m.top.findNode("stripTimer")
    m.stripTimer.observeField("fire", "hideStrip")
    m.lyrics = m.top.findNode("lyrics")
    m.mix = "both"
    m.sound = invalid
    m.vizOn = false

    ' scoped, so leaving this view drops only its own observers
    p = muPlayer()
    for each f in ["track", "queue"]
        p.observeFieldScoped(f, "showNow")
    end for
    p.observeFieldScoped("state", "onPlayerState")
    p.observeFieldScoped("position", "showTime")
    p.observeFieldScoped("message", "onMessage")
    p.observeFieldScoped("mixState", "onMixState")
    p.observeFieldScoped("vizLook", "onVizLook")
end sub

sub onShown(unused as dynamic)
    m.top.setFocus(true)
end sub

sub onMode()
    mode = m.top.mode
    for each k in m.groups
        m.groups[k].visible = (k = mode)
    end for
    if mode = "milk"
        startViz()
    else if mode = "hearth"
        startHearth()
    end if
    ' lyrics sit over the visualizer and the fire, not over the big cover
    if mode = "cover"
        m.lyrics.callFunc("lyricsStop", invalid)
        m.lyrics.visible = false
    else
        m.lyrics.callFunc("start", invalid)
    end if
    showNow()
    ' music is the point of these views: start it if nothing is on
    p = muPlayer()
    if mode <> "hearth" and p.state <> "playing" and p.state <> "buffering" then muSend("play")
    showStrip()
end sub

' ---------- now playing ----------
sub showNow()
    n = muNow()
    m.sEyebrow.text = n.eyebrow
    m.sTitle.text = n.title
    m.sSub.text = n.sub
    m.coverTitle.text = n.title
    m.coverSub.text = n.sub
    if n.track <> invalid
        m.sArt.uri = pxImage(n.track.thumb, 150, 150)
        if m.top.mode = "cover"
            m.coverArt.uri = pxImage(n.track.thumb, 600, 600)
            m.coverBlur.uri = pxImage(n.track.thumb, 480, 270, 40)
        end if
    else
        m.sArt.uri = ""
        m.coverArt.uri = ""
        m.coverBlur.uri = ""
    end if
    mode = m.top.mode
    ' one idea per line, so the right-aligned hint never breaks mid-phrase
    keys = "Play pauses  ·  Rewind and Fast forward change song" + Chr(10)
    if m.top.mode <> "cover" then keys = keys + "Up shows or hides lyrics  ·  Back closes" else keys = keys + "Back closes"
    if mode = "hearth"
        names = { both: "FIRE + MUSIC", fire: "FIRE ONLY", music: "MUSIC ONLY" }
        m.sEyebrow.text = "HEARTH  ·  " + names[m.mix] + "  ·  " + n.eyebrow
        keys = keys + Chr(10) + "* mutes the fire or the music"
    else if mode = "milk"
        p = muPlayer()
        how = ""
        if m.vizLoop = true
            how = "  ·  LOOP"
        else if p.mixState = "on" and p.mixKind = "loop"
            how = "  ·  LOOP (NUCBOX OFF)"
        else if p.mixState = "on"
            how = "  ·  LIVE"
        end if
        m.sEyebrow.text = "VISUALIZER" + how + "  ·  " + n.eyebrow
        if n.track <> invalid then m.vizBack.uri = pxImage(n.track.thumb, 480, 270, 40)
        keys = keys + Chr(10) + "Left and Right change the look  ·  * looks and options"
    else
        keys = keys + Chr(10) + "* music options"
    end if
    m.sHint.text = keys
    showTime()
end sub

sub showTime()
    p = muPlayer()
    fw = 0
    if p.duration > 0 then fw = Int(598 * p.position / p.duration)
    if fw < 15 then fw = 15
    m.coverClip.clippingRect = [0, 0, fw - 12, 10]
    m.coverTip.translation = [1 + fw - 12, 1]
    m.coverTip.visible = true
end sub

sub onMessage()
    m.sToast.text = muPlayer().message
    showStrip()
end sub

sub showStrip()
    if m.strip.opacity < 1
        m.stripOut.control = "stop"
        m.top.findNode("stripInI").keyValue = [m.strip.opacity, 1.0]
        m.stripIn.control = "start"
    end if
    m.stripTimer.control = "stop"
    m.stripTimer.control = "start"
end sub

sub hideStrip()
    m.sToast.text = ""
    ' cover mode keeps the title under the art, so the strip can go; the others fade it too
    m.stripOut.control = "start"
end sub

' ---------- visualizer: MilkDrop for each song (rendered on the NucBox, or a ready-made loop on the NAS) ----------
' The song and the picture come as one stream (MusicPlayer mixplay.brs), so the Video here plays the music too.
' While the song plays on speakers (cast), the TV shows the look's loop with no sound instead.
sub startViz()
    p = muPlayer()
    m.vizOn = true
    m.vizLoop = false
    m.vizNote.text = "Starting the visualizer..."
    m.vizNote.visible = true
    if p.castCount > 0
        startVizLoop()
    else
        p.command = { cmd: "mixOn", kind: "viz", video: m.vizVideo }
        onMixState()
    end if
end sub

' cast: the speakers carry the song, the TV loops the look's ready-made video without sound
sub startVizLoop()
    p = muPlayer()
    look = p.vizLook
    if look = invalid or look = "" or vizLabel(look) = "" then look = vizPick()
    m.vizLoop = true
    m.vizLoopLook = look
    c = CreateObject("roSGNode", "ContentNode")
    c.url = nasBase() + "/api/viz/loopfile?n=" + look
    c.streamFormat = "mp4"
    v = m.vizVideo
    v.loop = true
    v.mute = true
    v.content = c
    v.observeField("state", "onVizLoopState")
    if m.vizYielded <> true
        p.command = { cmd: "tvYield" }
        m.vizYielded = true
    end if
    v.control = "play"
    showLookTag(look)
end sub

sub onVizLoopState()
    v = m.vizVideo
    if v.state = "playing"
        v.visible = true
        m.vizNote.visible = false
    else if v.state = "error"
        print "[music] visualizer loop error: "; v.errorMsg
        v.visible = false
        m.vizNote.text = "No ready-made loop for this look on the NAS yet. The music carries on in the other rooms." + Chr(10) + "Run the visualizer setup on the NucBox to make the loops."
        m.vizNote.visible = true
    end if
end sub

sub stopViz()
    if not m.vizOn then return
    m.vizOn = false
    v = m.vizVideo
    if m.vizLoop = true
        v.unobserveField("state")
        v.control = "stop"
        m.vizLoop = false
    else
        muPlayer().command = { cmd: "mixOff" }
    end if
    v.visible = false
    if m.vizYielded = true
        m.vizYielded = false
        muPlayer().command = { cmd: "tvRejoin" }
    end if
end sub

' the player's joined stream: show the video when it runs, the soft cover and a note when it can't
sub onMixState()
    p = muPlayer()
    st = p.mixState
    if m.top.mode = "milk" and m.vizOn and m.vizLoop <> true
        m.vizVideo.visible = (st = "on")
        if st = "on"
            m.vizNote.visible = false
        else if st = "failed"
            m.vizNote.text = "No visualizer for this song: " + p.mixNote + "." + Chr(10) + "The music carries on, and the next song tries again."
            m.vizNote.visible = true
        else if st = "starting"
            m.vizNote.text = "Starting the visualizer..."
            m.vizNote.visible = true
        end if
    else if m.top.mode = "hearth" and m.fireMix <> invalid
        m.fireMix.visible = (st = "on")
        if st = "failed" and p.mixNote = "preparing"
            m.noFire.text = "Getting your fire clip ready on the NAS. The moving fire joins the music in a moment."
            m.noFire.visible = true
            ' the NAS is copying the clip from Plex: try again shortly
            if m.fireRetry = invalid
                m.fireRetry = CreateObject("roSGNode", "Timer")
                m.fireRetry.duration = 15
                m.fireRetry.observeField("fire", "onFireRetry")
            end if
            m.fireRetry.control = "start"
        else if st = "on"
            m.noFire.visible = false
        end if
        if m.sound <> invalid then m.sound.active = (st <> "on" or m.mix <> "music")
    end if
    showNow()
end sub

sub onVizLook()
    if m.top.mode = "milk" then showLookTag(muPlayer().vizLook)
end sub

sub showLookTag(look as dynamic)
    if look = invalid or look = "" then return
    name = vizLabel(look)
    if name = "" then return
    m.presetName.text = UCase(name)
    w = m.presetName.boundingRect().width
    if w < 100 then w = 100
    m.lookTagBg.width = w + 48
    m.tagOut.control = "stop"
    m.tagIn.control = "start"
    m.tagTimer.control = "stop"
    m.tagTimer.control = "start"
end sub

sub hideLookTag()
    m.tagOut.control = "start"
end sub

' Left/Right: the next or previous look (among the starred ones when there are any) for this song
sub stepLook(d as integer)
    pool = []
    stars = vizStars()
    for each l in vizLooks()
        if stars.Count() = 0 or stars[l.n] = true then pool.push(l.n)
    end for
    if pool.Count() < 2
        pool = []
        for each l in vizLooks()
            pool.push(l.n)
        end for
    end if
    cur = muPlayer().vizLook
    if m.vizLoop = true then cur = m.vizLoopLook
    at = -1
    for i = 0 to pool.Count() - 1
        if pool[i] = cur then at = i
    end for
    at = (at + d + pool.Count()) mod pool.Count()
    useLook(pool[at])
end sub

sub useLook(look as string)
    ' a fixed pick follows the change; shuffle keeps shuffling from the next song
    if vizChoice() <> "shuffle" then vizSetChoice(look)
    if m.vizLoop = true
        m.vizVideo.unobserveField("state")
        m.vizVideo.control = "stop"
        muPlayer().vizLook = look
        startVizLoop()
    else
        muSend("mixLook", { look: look })
    end if
end sub

sub openLooks()
    cur = muPlayer().vizLook
    if m.vizLoop = true then cur = m.vizLoopLook
    m.picker.callFunc("open", { current: cur })
    m.picker.visible = true
end sub

sub onLookChosen()
    c = m.picker.chosen
    m.picker.visible = false
    m.top.setFocus(true)
    if c = invalid or c = "" or c = "close" then return
    if c = "shuffle"
        vizSetChoice("shuffle")
        useLook(vizPick())
    else
        vizSetChoice(c)
        useLook(c)
    end if
end sub

' ---------- hearth: your own fire clip from the Ambiance library, with the music on top ----------
' Never the drawn fire (owner, Nov 27). The TV plays one stream at a time, so:
'   music playing on the TV  -> a still of the fire clip, with the crackle sound effect
'   music on speakers (cast) -> the TV lends its screen (tvYield) and the real fire video loops
' A merged fire + song stream made on the NAS is the later fix for the TV-only case.
sub startHearth()
    m.noFire.visible = false
    m.sound = CreateObject("roSGNode", "AmbientSound")
    if m.sound <> invalid
        m.sound.mood = "hearth"
        m.top.findNode("moodHolder").appendChild(m.sound)
    end if
    clip = hearthClip()
    if clip <> invalid
        showFire(clip)
    else if m.global.hasField("ambItems")
        noFireClip()
    else
        ' the Ambiance room hasn't asked Plex yet: ask here
        sec = ""
        libs = m.global.libraries
        if libs <> invalid and libs.ambiance <> invalid then sec = libs.ambiance
        m.noFire.text = "Finding your fire clip..."
        m.noFire.visible = true
        hPlex("clips", { section: sec }, "onFireClips")
    end if
    setMix("both")
end sub

function hearthClip() as dynamic
    if not m.global.hasField("ambItems") then return invalid
    for each it in m.global.ambItems
        if it.mood = "hearth" and it.clip <> invalid then return it.clip
    end for
    return invalid
end function

sub onFireClips(event as object)
    t = hTaskFrom(event)
    if m.top.mode <> "hearth" then return
    if t.ok and t.response.Clips <> invalid and t.response.Clips.count() > 0
        if not m.global.hasField("ambItems") then m.global.addFields({ ambItems: [] })
        m.global.ambItems = ambMerge(t.response.Clips)
    end if
    clip = hearthClip()
    if clip <> invalid then showFire(clip) else noFireClip()
end sub

sub noFireClip()
    m.noFire.text = "No fire clip in your Plex Ambiance library yet. Add a video whose file name starts with " + Chr(8220) + "fire" + Chr(8221) + " and it shows here, with the music over it."
    m.noFire.visible = true
end sub

sub showFire(clip as object)
    m.noFire.visible = false
    holder = m.top.findNode("moodHolder")
    st = holder.createChild("Poster")
    st.width = 1920
    st.height = 1080
    st.loadDisplayMode = "scaleToZoom"
    pic = clip.art
    if pic = invalid then pic = clip.thumb
    if pic <> invalid then st.uri = fullStill(pic)
    m.fireStill = st
    m.fireClip = clip
    fireStart()
end sub

' Which fire: while the song plays on the TV, the NAS joins the fire clip and the song into one stream
' (m.fireMix, MusicPlayer mixplay.brs). With speakers (cast) or "Fire only", the clip loops on its own.
sub fireStart()
    p = muPlayer()
    if p.castCount > 0 or m.mix = "fire"
        fireLoop(m.fireClip)
    else
        holder = m.top.findNode("moodHolder")
        if m.fireMix = invalid
            v = holder.createChild("Video")
            v.width = 1920
            v.height = 1080
            v.enableUI = false
            v.disableScreenSaver = true
            v.visible = false
            m.fireMix = v
        end if
        if m.sound <> invalid then m.sound.active = true
        p.command = { cmd: "mixOn", kind: "fire", video: m.fireMix, clip: m.fireClip.key }
    end if
end sub

sub onFireRetry()
    if m.top.mode = "hearth" and m.fireMix <> invalid and m.mix <> "fire" and muPlayer().castCount = 0 then fireStart()
end sub

sub fireMixStop()
    if m.fireRetry <> invalid then m.fireRetry.control = "stop"
    if m.fireMix = invalid then return
    muPlayer().command = { cmd: "mixOff" }
    m.fireMix.visible = false
end sub

sub fireLoop(clip as object)
    ' speakers carry the song (or "Fire only" paused it), so the screen is free for the clip on its own
    p = muPlayer()
    v = m.top.findNode("moodHolder").createChild("Video")
    v.width = 1920
    v.height = 1080
    v.enableUI = false
    v.loop = true
    v.disableScreenSaver = true
    v.mute = (m.mix = "music")
    m.fireConverted = needsConvert(clip)
    v.content = clipContent(clip, m.fireConverted)
    v.observeField("state", "onFireVideo")
    m.fireVideo = v
    m.fireClip = clip
    p.command = { cmd: "tvYield" }
    m.fireYielded = true
    v.control = "play"
    m.top.setFocus(true)
end sub

sub onFireVideo()
    v = m.fireVideo
    if v = invalid then return
    stt = v.state
    if stt = "playing"
        m.fireStill.visible = false
        if m.sound <> invalid then m.sound.active = false
        m.top.setFocus(true)
    else if stt = "error"
        print "[music] fire video error: "; v.errorMsg
        if not m.fireConverted
            ' this file won't play as it is: ask Plex for a converted copy once
            m.fireConverted = true
            v.content = clipContent(m.fireClip, true)
            v.control = "play"
        else
            ' keep the still, give the TV back to the music
            stopFire()
            if m.sound <> invalid then m.sound.active = true
        end if
    end if
end sub

sub stopFire()
    if m.fireVideo <> invalid
        m.fireVideo.unobserveField("state")
        m.fireVideo.control = "stop"
        m.top.findNode("moodHolder").removeChild(m.fireVideo)
        m.fireVideo = invalid
    end if
    if m.fireStill <> invalid then m.fireStill.visible = true
    if m.fireYielded = true
        m.fireYielded = false
        muPlayer().command = { cmd: "tvRejoin" }
    end if
end sub

sub setMix(mix as string)
    old = m.mix
    m.mix = mix
    if m.sound <> invalid then m.sound.on = (mix <> "music")
    if m.fireVideo <> invalid then m.fireVideo.mute = (mix = "music")
    p = muPlayer()
    ' "Fire only" swaps the joined stream for the clip on its own, and back again
    if m.fireClip <> invalid and p.castCount = 0 and (old = "fire") <> (mix = "fire")
        if mix = "fire"
            fireMixStop()
        else
            stopFire()
        end if
    end if
    if mix = "fire"
        muSend("pause")
    else if p.state <> "playing" and p.state <> "buffering"
        muSend("play")
    end if
    if m.fireClip <> invalid and p.castCount = 0 and (old = "fire") <> (mix = "fire") then fireStart()
    showNow()
end sub

sub onPlayerState()
    showNow()
    ' pressing Play during "fire only" means they want music too
    if m.top.mode = "hearth" and m.mix = "fire" and muPlayer().state = "playing"
        setMix("both")
    end if
end sub

sub mixMenu()
    names = ["Fire + music", "Fire only", "Music only"]
    keys = ["both", "fire", "music"]
    labels = []
    for i = 0 to 2
        if keys[i] = m.mix then labels.push(names[i] + "  (on)") else labels.push(names[i])
    end for
    labels.push("Music options")
    m.mixKeys = keys
    d = CreateObject("roSGNode", "HearthDialog")
    d.title = "Hearth"
    d.message = ["Mute the fire or the music on their own."]
    d.buttons = labels
    d.observeField("buttonSelected", "onMix")
    d.observeField("wasClosed", "onMuClosed")
    m.mixDialog = d
    hShowDialog(d)
end sub

' * in the Visualizer: the look picker first, then the usual music options
sub vizMenu()
    d = CreateObject("roSGNode", "HearthDialog")
    d.title = "Visualizer"
    c = vizChoice()
    if c = "shuffle" then now = "Shuffling your starred looks" else now = "Always " + vizLabel(c)
    if c = "shuffle" and vizStars().Count() = 0 then now = "Shuffling all looks (star some to narrow it)"
    d.message = [now]
    d.buttons = ["Choose a look...", "Music options", "Close"]
    d.observeField("buttonSelected", "onVizMenu")
    d.observeField("wasClosed", "onMuClosed")
    m.vizDialog = d
    hShowDialog(d)
end sub

sub onVizMenu()
    b = m.vizDialog.buttonSelected
    m.vizDialog.close = true
    if b = 0
        openLooks()
    else if b = 1
        muOptions(false)
    end if
end sub

sub onMix()
    b = m.mixDialog.buttonSelected
    m.mixDialog.close = true
    if b < 3
        setMix(m.mixKeys[b])
    else
        muOptions(false)
    end if
end sub

sub muRestoreFocus()
    m.top.setFocus(true)
end sub

sub leave()
    m.lyrics.callFunc("lyricsStop", invalid)
    stopViz()
    fireMixStop()
    stopFire()
    if m.sound <> invalid
        m.sound.on = false
        m.sound.active = false
    end if
    p = muPlayer()
    for each f in ["track", "queue", "state", "position", "message", "mixState", "vizLook"]
        p.unobserveFieldScoped(f)
    end for
    m.top.request = { action: "back" }
end sub

function hKeyInner(key as string, press as boolean) as boolean
    if not press then return false
    ' the look picker takes every key while it is open
    if m.picker.visible
        m.picker.callFunc("handleKey", key)
        return true
    end if
    if key = "back"
        leave()
        return true
    end if
    if muMediaKey(key)
        showStrip()
        return true
    end if
    if key = "options"
        if m.top.mode = "hearth"
            mixMenu()
        else if m.top.mode = "milk"
            vizMenu()
        else
            muOptions(false)
        end if
        return true
    end if
    if key = "up" and m.top.mode <> "cover"
        muSend("lyricsToggle")
        showStrip()
        return true
    end if
    if m.top.mode = "hearth" and (key = "left" or key = "right") and muPlayer().lyricsFound
        if key = "left" then muSend("lyricsNudge", { delta: -0.5 }) else muSend("lyricsNudge", { delta: 0.5 })
        showStrip()
        return true
    end if
    if m.top.mode = "milk" and (key = "left" or key = "right")
        if key = "left" then stepLook(-1) else stepLook(1)
        showStrip()
        return true
    end if
    showStrip()
    return true
end function

' menu sound for whatever the handler above took (source/util.brs hKeySfx)
function onKeyEvent(key as string, press as boolean) as boolean
    return hKeySfx(key, press, hKeyInner(key, press))
end function
