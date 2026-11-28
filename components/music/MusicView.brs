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
    m.lookTimer = m.top.findNode("lookTimer")
    m.lookTimer.observeField("fire", "applyLook")
    m.lookWant = ""
    m.vizVideo = m.top.findNode("vizVideo")
    m.vizVideo.visible = false
    m.vizBack = m.top.findNode("vizBack")
    m.vizNote = m.top.findNode("vizNote")
    m.vizNote.font = hFont("regular", 32)
    m.picker = m.top.findNode("picker")
    m.picker.observeField("chosen", "onLookChosen")
    m.noFire = m.top.findNode("noFire")
    m.noFire.font = hFont("regular", 32)
    m.fireNote = m.top.findNode("fireNote")
    m.top.findNode("fireNoteText").font = hFont("regular", 24)
    m.stripIn = m.top.findNode("stripIn")
    m.stripOut = m.top.findNode("stripOut")
    m.stripTimer = m.top.findNode("stripTimer")
    m.stripTimer.observeField("fire", "hideStrip")
    m.lyrics = m.top.findNode("lyrics")
    m.ctl = m.top.findNode("ctl")
    m.panel = m.top.findNode("panel")
    m.panel.observeField("request", "onPanelRequest")
    m.ctlTag = m.top.findNode("ctlTag")
    m.ctlTag.font = hFont("caps", 26)
    m.ctlToast = m.top.findNode("ctlToast")
    m.ctlToast.font = hFont("regular", 26)
    m.top.findNode("ctlNextTitle").font = hFont("fell", 40)
    m.ctlNext = m.top.findNode("ctlNext")
    m.ctlIn = m.top.findNode("ctlIn")
    m.ctlOut = m.top.findNode("ctlOut")
    m.ctlOut.observeField("state", "onCtlOut")
    m.ctlTimer = m.top.findNode("ctlTimer")
    m.ctlTimer.observeField("fire", "onCtlTimer")
    m.ctlOn = false
    m.noteOn = false
    m.noteText = ""
    m.ctlMsg = ""
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
    p.observeFieldScoped("castCount", "onCastCount")
    p.observeFieldScoped("rooms", "onRooms")
    m.castWas = p.castCount
end sub

' music moved to (or back from) other rooms while a picture is up: speakers carry the song and the TV
' shows the picture without sound, or the TV takes the song back with the picture
sub onCastCount()
    p = muPlayer()
    now = (p.castCount > 0)
    was = (m.castWas > 0)
    m.castWas = p.castCount
    if now = was then return
    if m.top.mode = "milk" and m.vizOn
        stopViz()
        startViz()
    else if m.top.mode = "hearth" and m.fireClip <> invalid
        fireMixStop()
        stopFire()
        fireStart()
    end if
end sub

' ---------- Play in other rooms, as a popup (the player's room list isn't on this screen) ----------
sub roomsMenu()
    p = muPlayer()
    m.roomIds = []
    ic = "pkg:/images/music/icons/"
    rb = rbNew()
    for each r in p.rooms
        if r.kind = "speaker"
            if m.roomIds.Count() = 0 then rbHead(rb, "Speakers")
            if r.on = true then w = r.name + ": On" else w = r.name + ": Off"
            rbAdd(rb, w, "", ic + "speaker.png", "")
            m.roomIds.push(r.id)
        end if
    end for
    if m.roomIds.Count() > 1
        rbAdd(rb, "Every room", "Turn every speaker on", ic + "house.png", "") : m.roomIds.push("all")
    end if
    rbAdd(rb, "Done", "", "", "main") : m.roomIds.push("done")
    labels = rb.labels
    d = CreateObject("roSGNode", "HearthDialog")
    d.title = "Play in other rooms"
    d.icon = ic + "cast.png"
    rbSet(d, rb)
    if m.roomIds.Count() = 1
        d.message = ["Looking for speakers..."]
    else if p.castCount > 0
        d.message = ["The speakers play the song; the picture stays on this TV."]
    else
        d.message = ["Pick the rooms to play in. The picture stays on this TV."]
    end if
    m.roomsSigWas = roomsSig()
    if m.roomFocus <> invalid and m.roomFocus < labels.Count() then d.buttonFocused = m.roomFocus
    d.observeField("buttonSelected", "onRoomsMenu")
    d.observeField("wasClosed", "onRoomsClosed")
    m.roomsDialog = d
    m.roomsOpen = true
    hShowDialog(d)
end sub

sub onRoomsMenu()
    b = m.roomsDialog.buttonSelected
    id = m.roomIds[b]
    m.roomFocus = b
    if id = "done"
        m.roomsDialog.close = true
        return
    end if
    if id = "all" then muSend("castAll") else muSend("castToggle", { id: id })
end sub

sub onRoomsClosed()
    m.roomsOpen = false
    m.roomFocus = invalid
    muRestoreFocus()
end sub

' the room list changed (found, or a room turned on or off): show it again where the focus was
sub onRooms()
    if m.roomsOpen <> true then return
    ' volume polls rewrite the list too: only redraw when a name or an on/off changed
    sig = roomsSig()
    if sig = m.roomsSigWas then return
    m.roomsDialog.unobserveField("wasClosed")
    m.roomsDialog.close = true
    roomsMenu()
end sub

function roomsSig() as string
    sig = ""
    for each r in muPlayer().rooms
        sig = sig + r.id + ":" + r.name + ":" + (r.on = true).toStr() + "|"
    end for
    return sig
end function

function roomsLabel() as string
    n = muPlayer().castCount
    if n = 1 then return "Other rooms: 1 playing"
    if n > 1 then return "Other rooms: " + n.toStr() + " playing"
    return "Play in other rooms"
end function

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
    if mode = "milk" then showControls() else showStrip()
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
        keys = keys + Chr(10) + "OK mutes the fire or the music"
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
        ctlTagPaint()
        muNextTiles(m.ctlNext)
        keys = keys + Chr(10) + "Left and Right change the look  ·  OK all looks and options"
    else
        keys = keys + Chr(10) + "OK music options"
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
    msg = muPlayer().message
    if m.top.mode = "milk"
        ' with the controls up the words sit under the buttons; without them, in the small tag at the top
        m.ctlMsg = msg
        if m.ctlOn then ctlWords() else tagSay(msg)
        return
    end if
    m.sToast.text = msg
    showStrip()
end sub

sub showStrip()
    ' the Visualizer has the whole player over the picture instead (showControls)
    if m.top.mode = "milk" then return
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
    vizSay("Starting the visualizer...")
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
        vizSay("")
    else if v.state = "error"
        print "[music] visualizer loop error: "; v.errorMsg
        v.visible = false
        vizSay("No ready-made loop for this look on the NAS yet. The music carries on in the other rooms." + Chr(10) + "Run the visualizer setup on the NucBox to make the loops.")
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
            vizSay("")
        else if st = "failed"
            vizSay("No visualizer for this song: " + p.mixNote + "." + Chr(10) + "The music carries on, and the next song tries again.")
        else if st = "starting"
            vizSay("Starting the visualizer...")
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
        else if st = "failed"
            ' the still stays up; say so, once, in plain words
            why = p.mixNote
            if why = invalid or why = "" then why = "the NAS could not join it to the song"
            t = m.top.findNode("fireNoteText")
            t.text = "A still fire for this song: " + why + ". The next song tries the moving fire again."
            m.top.findNode("fireNoteBg").width = Int(t.boundingRect().width) + 48
            m.fireNote.visible = true
        else if st = "on"
            m.noFire.visible = false
        end if
        if st <> "failed" then m.fireNote.visible = false
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
    ctlTagPaint()
    ' with the controls up, the look is named in their top line
    if m.ctlOn then return
    tagSay(name)
end sub

' a few words in the small tag at the top left, for three seconds
sub tagSay(words as dynamic)
    if words = invalid or words = "" then return
    m.presetName.text = UCase(words)
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
    ' hearted looks or all of them, per the Play setting in the Visualizer menu
    pool = vizPool()
    cur = muPlayer().vizLook
    if m.vizLoop = true then cur = m.vizLoopLook
    ' presses made while an earlier one is still waiting step on from that one
    if m.lookWant <> "" then cur = m.lookWant
    at = -1
    for i = 0 to pool.Count() - 1
        if pool[i] = cur then at = i
    end for
    at = (at + d + pool.Count()) mod pool.Count()
    useLook(pool[at])
end sub

' A fast run of Left/Right only changes the look once, 0.45 s after the last press: every change asks the
' NAS and the NucBox for a new stream and swaps the TV's video over.
sub useLook(look as string)
    m.lookWant = look
    showLookTag(look)
    m.lookTimer.control = "stop"
    m.lookTimer.control = "start"
end sub

sub applyLook()
    look = m.lookWant
    m.lookWant = ""
    if look <> "" then useLookNow(look)
end sub

sub useLookNow(look as string)
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
        ' the song (or the fire + song stream) owns the TV's one player: the crackle is always the SoundEffect loop
        m.sound.preferSfx = true
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
        m.global.ambItems = ambMerge(t.response.Clips, t.response.Preparing)
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
    icn = ["fire.png", "fire.png", "disc.png"]
    ic = "pkg:/images/music/icons/"
    rb = rbNew()
    rbHead(rb, "What you hear")
    for i = 0 to 2
        sub2 = ""
        if keys[i] = m.mix then sub2 = "Playing"
        rbAdd(rb, names[i], sub2, ic + icn[i], "tile")
    end for
    rbHead(rb, "More")
    rbAdd(rb, roomsLabel(), "The speakers play the song; the fire stays here", ic + "cast.png", "")
    rbAdd(rb, "Music options...", "Shuffle, repeat, radio, Last.fm", ic + "more.png", "")
    m.mixKeys = keys
    d = CreateObject("roSGNode", "HearthDialog")
    d.title = "Hearth"
    d.icon = ic + "fire.png"
    muNowBox(d)
    rbSet(d, rb)
    d.observeField("buttonSelected", "onMix")
    d.observeField("wasClosed", "onMuClosed")
    m.mixDialog = d
    hShowDialog(d)
end sub

' OK (or *) in the Visualizer: heart the look on screen, what Next/Shuffle play, the picker, rooms, music options
sub vizMenu()
    p = muPlayer()
    look = p.vizLook
    if m.vizLoop = true then look = m.vizLoopLook
    if look = invalid or vizLabel(look) = "" then look = ""
    hearts = vizHearts()
    md = vizPlayMode()
    m.vizActs = []
    ic = "pkg:/images/music/icons/"
    rb = rbNew()
    rbHead(rb, "This look")
    if look <> ""
        if hearts[look] = true
            rbAdd(rb, "Unheart " + vizLabel(look), "Take it out of your hearted looks", ic + "heart.png", "")
        else
            rbAdd(rb, "Heart " + vizLabel(look), "Add it to the looks Next and Shuffle play", ic + "heart.png", "")
        end if
        m.vizActs.push("heart")
    end if
    if md = "hearted" and hearts.Count() > 0
        rbAdd(rb, "Play: Hearted (" + hearts.Count().toStr() + ")", "What Next, Shuffle and Left/Right go through", ic + "shuffle.png", "")
    else
        rbAdd(rb, "Play: All (" + vizLooks().Count().toStr() + ")", "What Next, Shuffle and Left/Right go through", ic + "shuffle.png", "")
    end if
    m.vizActs.push("play")
    rbAdd(rb, "Choose a look...", "Every look, with pictures", ic + "viz.png", "") : m.vizActs.push("choose")
    rbHead(rb, "More")
    rbAdd(rb, roomsLabel(), "The speakers play the song; the picture stays here", ic + "cast.png", "") : m.vizActs.push("rooms")
    rbAdd(rb, "Music options...", "Shuffle, repeat, radio, Last.fm", ic + "more.png", "") : m.vizActs.push("options")
    labels = rb.labels
    d = CreateObject("roSGNode", "HearthDialog")
    d.title = "Visualizer"
    d.icon = ic + "viz.png"
    if vizChoice() <> "shuffle" then how = "Kept for every song" else how = "A new look each song"
    if look <> ""
        d.now = { art: "pkg:/images/music/viz/" + look + ".jpg", kicker: "On screen", title: vizLabel(look), sub: how }
    else
        d.now = { art: "pkg:/images/music/viz/201.jpg", kicker: "Starting", title: "The visualizer", sub: how }
    end if
    if m.vizMsg <> invalid
        d.message = [m.vizMsg]
        m.vizMsg = invalid
    end if
    rbSet(d, rb)
    if m.vizFocus <> invalid and m.vizFocus < labels.Count() then d.buttonFocused = m.vizFocus
    m.vizFocus = invalid
    d.observeField("buttonSelected", "onVizMenu")
    d.observeField("wasClosed", "onMuClosed")
    m.vizDialog = d
    hShowDialog(d)
end sub

sub onVizMenu()
    b = m.vizDialog.buttonSelected
    a = m.vizActs[b]
    m.vizDialog.unobserveField("wasClosed")
    m.vizDialog.close = true
    if a = "heart"
        p = muPlayer()
        look = p.vizLook
        if m.vizLoop = true then look = m.vizLoopLook
        vizSetHeart(look, vizHearts()[look] <> true)
        ' the first heart switches Play to hearted looks, unless the setting was chosen before
        if CreateObject("roRegistrySection", "hearth").Read("vizPlay") = "" and vizHearts().Count() = 1 then vizSetPlayMode("hearted")
        m.vizFocus = b
        vizMenu()
    else if a = "play"
        if vizPlayMode() = "hearted" and vizHearts().Count() > 0
            vizSetPlayMode("all")
        else if vizHearts().Count() = 0
            m.vizMsg = "Heart a look first. Then Play can stick to your hearted looks."
        else
            vizSetPlayMode("hearted")
        end if
        m.vizFocus = b
        vizMenu()
    else if a = "choose"
        openLooks()
    else if a = "rooms"
        openRooms()
    else if a = "options"
        muOptions(false)
    else
        muRestoreFocus()
    end if
end sub

sub onMix()
    b = m.mixDialog.buttonSelected
    m.mixDialog.close = true
    if b < 3
        setMix(m.mixKeys[b])
    else if b = 3
        openRooms()
    else
        muOptions(false)
    end if
end sub

sub openRooms()
    muSend("castRefresh")
    m.roomFocus = invalid
    roomsMenu()
end sub

sub muRestoreFocus()
    m.top.setFocus(true)
    if m.ctlOn then ctlKeep()
end sub

sub leave()
    m.ctlTimer.control = "stop"
    m.lookTimer.control = "stop"
    m.lookWant = ""
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
    if hKeyTooFast(120, key) then return true
    ' the look picker takes every key while it is open
    if m.picker.visible
        m.picker.callFunc("handleKey", key)
        return true
    end if
    if m.top.mode = "milk" then return vizKey(key)
    if key = "back"
        leave()
        return true
    end if
    if muMediaKey(key)
        showStrip()
        return true
    end if
    ' OK as well as *: while a video plays the TV keeps * for its own picture menu
    if key = "options" or key = "OK"
        if m.top.mode = "hearth"
            mixMenu()
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
    showStrip()
    return true
end function

' ---------- the Visualizer's controls: the Big view's player over the picture ----------
' Controls up: every key goes to the panel, as in the Big view (Left/Right along the buttons, OK presses one,
' * opens Music options); Back puts them away. Controls away: Left/Right change the look, Up shows or hides
' the lyrics, Back leaves, and OK (or anything else) brings the controls up.
function vizKey(key as string) as boolean
    if muMediaKey(key)
        showControls()
        return true
    end if
    if m.ctlOn
        if key = "back"
            hideControls()
        else
            m.panel.callFunc("handleKey", key)
            ctlKeep()
        end if
        return true
    end if
    if key = "back"
        leave()
    else if key = "left"
        stepLook(-1)
    else if key = "right"
        stepLook(1)
    else if key = "up"
        muSend("lyricsToggle")
    else
        showControls()
    end if
    return true
end function

sub showControls()
    m.ctlOn = true
    m.ctlOut.control = "stop"
    m.ctl.visible = true
    m.panel.active = true
    ' the lyrics plaque and the small look tag would sit on top of the player
    m.lyrics.opacity = 0
    m.tagTimer.control = "stop"
    m.tagIn.control = "stop"
    m.tagOut.control = "stop"
    m.lookTag.opacity = 0
    ctlTagPaint()
    ctlWords()
    if m.ctl.opacity < 1
        m.top.findNode("ctlInI").keyValue = [m.ctl.opacity, 1.0]
        m.ctlIn.control = "start"
    end if
    ctlKeep()
end sub

' another eight seconds before the controls go
sub ctlKeep()
    m.ctlTimer.control = "stop"
    m.ctlTimer.control = "start"
end sub

sub onCtlTimer()
    ' a menu or the look picker is open over the controls: they wait for it
    if m.picker.visible or not m.top.hasFocus()
        ctlKeep()
        return
    end if
    hideControls()
end sub

sub hideControls()
    if not m.ctlOn then return
    m.ctlOn = false
    m.ctlMsg = ""
    m.ctlTimer.control = "stop"
    m.panel.active = false
    m.ctlIn.control = "stop"
    m.ctlOut.control = "start"
    m.lyrics.opacity = 1
    ctlWords()
end sub

sub onCtlOut()
    if m.ctlOut.state = "stopped" and not m.ctlOn
        m.ctl.opacity = 0
        m.ctl.visible = false
    end if
end sub

' the controls' top line: which look is on, and whether it is drawn live
sub ctlTagPaint()
    p = muPlayer()
    look = p.vizLook
    if m.vizLoop = true then look = m.vizLoopLook
    if m.lookWant <> "" then look = m.lookWant
    t = "VISUALIZER"
    if look <> invalid and look <> ""
        if vizLabel(look) <> "" then t = t + "  ·  " + UCase(vizLabel(look))
    end if
    if m.vizLoop = true
        t = t + "  ·  LOOP"
    else if p.mixState = "on" and p.mixKind = "loop"
        t = t + "  ·  LOOP (NUCBOX OFF)"
    else if p.mixState = "on"
        t = t + "  ·  LIVE"
    end if
    m.ctlTag.text = t
end sub

' why there is no picture ("Starting the visualizer...", "No visualizer for this song..."): in the middle of the
' screen, or under the buttons while the controls are up
sub vizSay(words as string)
    m.noteText = words
    m.noteOn = (words <> "")
    ctlWords()
end sub

sub ctlWords()
    m.vizNote.text = m.noteText
    m.vizNote.visible = (m.noteOn and not m.ctlOn)
    if m.ctlMsg <> "" then m.ctlToast.text = m.ctlMsg else if m.noteOn then m.ctlToast.text = m.noteText else m.ctlToast.text = ""
end sub

sub onPanelRequest()
    r = m.panel.request
    if r = invalid then return
    a = r.action
    if a = "refocus"
        muRestoreFocus()
    else if a = "look"
        vizMenu()
    else if a = "back"
        leave()
    else if a = "musicView" and r.mode = "milk"
        hideControls()
    else if a = "musicView" and (r.mode = "cover" or r.mode = "hearth")
        ' the other two pictures open here, in place of the Visualizer
        m.ctlOn = false
        m.ctlTimer.control = "stop"
        m.ctlIn.control = "stop"
        m.panel.active = false
        m.ctl.opacity = 0
        m.ctl.visible = false
        m.lyrics.opacity = 1
        m.lookTimer.control = "stop"
        m.lookWant = ""
        vizSay("")
        stopViz()
        m.top.mode = r.mode
    else
        m.top.request = r
    end if
end sub

' menu sound for whatever the handler above took (source/util.brs hKeySfx)
function onKeyEvent(key as string, press as boolean) as boolean
    return hKeySfx(key, press, hKeyInner(key, press))
end function

' ---- building a rich HearthDialog (icons, second lines, tiles), as muOptions does ----
function rbNew() as object
    return { labels: [], subs: [], icons: [], kinds: [], pics: [], heads: {} }
end function

sub rbHead(rb as object, words as string)
    rb.heads[rb.labels.count().toStr()] = words
end sub

sub rbAdd(rb as object, caption as string, line as string, iconUri as string, kind as string)
    rb.labels.push(caption)
    rb.subs.push(line)
    rb.icons.push(iconUri)
    rb.kinds.push(kind)
    rb.pics.push("")
end sub

sub rbSet(d as object, rb as object)
    d.buttons = rb.labels
    d.subs = rb.subs
    d.icons = rb.icons
    d.kinds = rb.kinds
    d.pics = rb.pics
    d.heads = rb.heads
end sub

' the song that is playing, in the dialog's "playing now" box
sub muNowBox(d as object)
    n = muNow()
    if n.track = invalid then return
    k = "Playing now"
    p = muPlayer()
    if p.state <> "playing" and p.state <> "buffering" then k = "Paused"
    d.now = { art: pxImage(n.track.thumb, 208, 208), kicker: k, title: n.title, sub: n.sub }
end sub
