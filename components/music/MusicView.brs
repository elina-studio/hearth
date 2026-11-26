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
    m.noFire = m.top.findNode("noFire")
    m.noFire.font = hFont("regular", 32)
    m.stripIn = m.top.findNode("stripIn")
    m.stripOut = m.top.findNode("stripOut")
    m.stripTimer = m.top.findNode("stripTimer")
    m.stripTimer.observeField("fire", "hideStrip")
    m.lyrics = m.top.findNode("lyrics")
    m.mix = "both"
    m.preset = 0
    m.sound = invalid

    ' scoped, so leaving this view drops only its own observers
    p = muPlayer()
    for each f in ["track", "queue"]
        p.observeFieldScoped(f, "showNow")
    end for
    p.observeFieldScoped("state", "onPlayerState")
    p.observeFieldScoped("position", "showTime")
    p.observeFieldScoped("message", "onMessage")
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
        applyPreset()
        for each id in ["vSpin", "vTint", "vBreath"]
            m.top.findNode(id).control = "start"
        end for
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
    keys = "Play pauses  ·  Rewind and Fast forward change song  ·  Back closes"
    if m.top.mode <> "cover" then keys = keys + "  ·  Up shows or hides lyrics"
    if mode = "hearth"
        names = { both: "FIRE + MUSIC", fire: "FIRE ONLY", music: "MUSIC ONLY" }
        m.sEyebrow.text = "HEARTH  ·  " + names[m.mix] + "  ·  " + n.eyebrow
        keys = keys + Chr(10) + "* mutes the fire or the music"
    else if mode = "milk"
        keys = keys + Chr(10) + "Left and Right change the look  ·  * music options"
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

' ---------- visualizer (a stand-in for MilkDrop: no beat detection on the TV) ----------
sub applyPreset()
    ' name, spin seconds, four tints for each layer group
    presets = [
        { name: "Embers", spin: 60, c: [&hE0B34AFF, &hF0907CFF, &hD9A066FF, &hE0B34AFF] },
        { name: "Moss", spin: 80, c: [&hA3A35AFF, &h6E8B4AFF, &hE0B34AFF, &hA3A35AFF] },
        { name: "Night sky", spin: 110, c: [&h8FA7C9FF, &hE0B34AFF, &hB59ACFFF, &h8FA7C9FF] },
        { name: "Bonfire", spin: 36, c: [&hF0907CFF, &hE0B34AFF, &hFF6A3DFF, &hF0907CFF] }
    ]
    p = presets[m.preset mod presets.count()]
    spin = m.top.findNode("vSpin")
    spin.control = "stop"
    spin.duration = p.spin
    c = p.c
    ' each layer starts at a different point of the palette so they never match
    m.top.findNode("c1").keyValue = [c[0], c[1], c[2], c[0]]
    m.top.findNode("c2").keyValue = [c[1], c[2], c[0], c[1]]
    m.top.findNode("c3").keyValue = [c[2], c[0], c[1], c[2]]
    m.top.findNode("c4").keyValue = [c[3], c[1], c[0], c[3]]
    m.top.findNode("cg").keyValue = [c[0], c[2], c[1], c[0]]
    m.presetName.text = UCase(p.name)
    if m.top.mode = "milk" then spin.control = "start"
end sub

' ---------- hearth: the Ambiance room's fire picture and crackle, with music on top ----------
sub startHearth()
    holder = m.top.findNode("moodHolder")
    scene = CreateObject("roSGNode", "MoodScene")
    if scene <> invalid
        scene.mood = "hearth"
        holder.appendChild(scene)
    else
        m.noFire.text = "The fire arrives with the Ambiance build. Music still plays here."
        m.noFire.visible = true
    end if
    m.sound = CreateObject("roSGNode", "AmbientSound")
    if m.sound <> invalid
        m.sound.mood = "hearth"
        holder.appendChild(m.sound)
        m.sound.active = true
    end if
    setMix("both")
end sub

sub setMix(mix as string)
    m.mix = mix
    if m.sound <> invalid then m.sound.on = (mix <> "music")
    p = muPlayer()
    if mix = "fire"
        muSend("pause")
    else if p.state <> "playing" and p.state <> "buffering"
        muSend("play")
    end if
    showNow()
end sub

sub onPlayerState()
    showNow()
    ' pressing Play during "fire only" means they want music too
    if m.top.mode = "hearth" and m.mix = "fire" and muPlayer().state = "playing"
        m.mix = "both"
        showNow()
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
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = "Hearth"
    d.message = ["Mute the fire or the music on their own."]
    d.buttons = labels
    d.observeField("buttonSelected", "onMix")
    d.observeField("wasClosed", "onMuClosed")
    m.mixDialog = d
    m.top.getScene().dialog = d
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
    if m.sound <> invalid
        m.sound.on = false
        m.sound.active = false
    end if
    for each id in ["vSpin", "vTint", "vBreath"]
        m.top.findNode(id).control = "stop"
    end for
    p = muPlayer()
    for each f in ["track", "queue", "state", "position", "message"]
        p.unobserveFieldScoped(f)
    end for
    m.top.request = { action: "back" }
end sub

function hKeyInner(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back"
        leave()
        return true
    end if
    if muMediaKey(key)
        showStrip()
        return true
    end if
    if key = "options"
        if m.top.mode = "hearth" then mixMenu() else muOptions(false)
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
        if key = "left" then m.preset = m.preset + 3 else m.preset = m.preset + 1
        applyPreset()
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
