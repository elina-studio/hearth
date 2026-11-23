' Plays a Plex movie or episode. Plays the file as-is when the TV can decode it; otherwise Plex remuxes it
' to HLS and converts only what the TV can't take (usually just the audio). See playback.brs.
' Captions: Plex sidecar files (including Bazarr's) plus anything embedded; * opens the captions picker.
sub init()
    m.capsPref = ""
    m.video = m.top.findNode("video")
    m.status = m.top.findNode("status")
    m.status.font = hFont("regular", 28)
    m.tick = m.top.findNode("tick")
    m.tick.observeField("fire", "onTick")
    m.video.observeField("state", "onState")
    m.leaving = false
    m.started = false
    m.ready = false
    m.offset = 0
end sub

sub onShown(unused as dynamic)
    m.video.setFocus(true)
end sub

sub start()
    it = m.top.item
    if it = invalid or it.Id = invalid then return
    hPlex("item", { id: it.Id }, "onItem")
end sub

function toStr(v as dynamic) as string
    if v = invalid then return ""
    return v.toStr()
end function

sub onItem(event as object)
    t = hTaskFrom(event)
    it = t.response
    if not t.ok or it = invalid or it._media = invalid or it._media.count() = 0
        if t.status <= 0 then fail("Couldn't reach Plex.") else fail("Plex didn't send a playable version.")
        return
    end if
    m.item = it
    media = it._media[0]
    part = media.Part[0]
    server = m.global.plexServer
    token = m.global.plexServerToken
    m.startSec = 0
    if m.top.resume and it.UserData.PlaybackPositionTicks <> invalid then m.startSec = it.UserData.PlaybackPositionTicks / 10000000
    m.durationMs = 0
    if media.duration <> invalid then m.durationMs = media.duration

    m.media = media
    m.part = part
    m.streams = hPlayStreams(part)
    m.session = m.global.deviceId + "-" + Rnd(100000).toStr()
    hPlayLogCaps()
    chk = hPlayDirectCheck(media, m.streams)
    print "[hearth-play] "; hTitle(it); " | "; toStr(media.container); " "; toStr(media.videoCodec); " "; toStr(media.height); "p "; toStr(media.audioCodec); " | sub "; subDesc()
    if chk.ok
        print "[hearth-play] plan: direct play (no Plex conversion)"
        m.mode = "direct"
        buildContent()
    else
        print "[hearth-play] needs Plex because of "; chk.why; "; asking Plex for a remux"
        m.mode = "hls"
        m.hlsSubs = "none"
        ' an embedded text caption Plex picked can ride along in the remux; image captions (PGS/VobSub) would force a burn-in
        if m.streams.embeddedTextSub and hCaptions() <> "off" then m.hlsSubs = "auto"
        askDecision()
    end if
end sub

function subDesc() as string
    if m.streams.sub = invalid then return "none picked"
    d = toStr(m.streams.sub.codec)
    if m.streams.sub.key <> invalid then d = d + " (file)" else d = d + " (embedded)"
    return d
end function

sub askDecision()
    hPlex("decision", { query: hPlayHlsQuery(m.item.Id, m.startSec, m.hlsSubs, m.session, m.global.plexServerToken) }, "onDecision")
end sub

sub onDecision(event as object)
    t = hTaskFrom(event)
    d = t.response
    if t.ok and d <> invalid
        print "[hearth-play] Plex says: video "; d.video; " ("; d.videoCodec; "), audio "; d.audio; " ("; d.audioCodec; "), captions "; d.subtitle; " ("; d.subtitleCodec; ") | "; d.general
        ' never let a caption cost a full video convert: drop the embedded caption and ask again
        if m.hlsSubs <> "none" and (d.video = "transcode" or d.subtitle = "burn")
            print "[hearth-play] that caption would force a video convert; retrying without it (sidecar files still work)"
            m.hlsSubs = "none"
            askDecision()
            return
        end if
        if d.video = "transcode" then print "[hearth-play] WARNING: Plex will convert the video on the NAS CPU; this file may stutter"
    else
        print "[hearth-play] Plex decision check failed (status "; t.status; "); starting the remux anyway"
    end if
    buildContent()
end sub

sub buildContent()
    it = m.item
    server = m.global.plexServer
    token = m.global.plexServerToken
    content = CreateObject("roSGNode", "ContentNode")
    content.title = hTitle(it)
    if it.Type = "Episode" then content.secondaryTitle = hSubtitle(it)
    if m.mode = "direct"
        content.url = server + m.part.key + "?X-Plex-Token=" + token
        if LCase(toStr(m.media.container)) = "mkv" then content.streamFormat = "mkv" else content.streamFormat = "mp4"
        content.playStart = m.startSec
        m.offset = 0
    else
        content.url = server + "/video/:/transcode/universal/start.m3u8?" + hPlayHlsQuery(it.Id, m.startSec, m.hlsSubs, m.session, token)
        content.streamFormat = "hls"
        content.playStart = 0
        m.offset = m.startSec
    end if
    part = m.part

    ' sidecar caption files Plex knows about (Bazarr's downloads show up here)
    subs = []
    m.wantSub = invalid
    if part.Stream <> invalid
        for each s in part.Stream
            if s.streamType = 3 and s.key <> invalid
                codec = LCase(toStr(s.codec))
                if codec = "srt" or codec = "subrip" or codec = "vtt" or codec = "webvtt"
                    lang = "und"
                    if s.languageCode <> invalid then lang = s.languageCode
                    name = lang
                    if s.displayTitle <> invalid then name = s.displayTitle
                    url = server + s.key + "?X-Plex-Token=" + token
                    subs.push({ Language: lang, TrackName: url, Description: name })
                    if s.selected = true then m.wantSub = url
                end if
            end if
        end for
    end if
    if subs.count() > 0 then content.subtitleTracks = subs
    ' the CC button's choice wins over Plex's pick: off hides captions, on shows English (or the first) when Plex chose none
    m.capsPref = hCaptions()
    if m.capsPref = "off"
        m.wantSub = invalid
    else if m.capsPref = "on" and m.wantSub = invalid and subs.count() > 0
        m.wantSub = subs[0].TrackName
        for each sb in subs
            if Left(LCase(sb.Language), 2) = "en"
                m.wantSub = sb.TrackName
                exit for
            end if
        end for
    end if

    m.video.content = content
    m.video.control = "play"
    m.video.setFocus(true)
    m.ready = true
end sub

function position() as dynamic
    p = m.video.position
    if p = invalid then p = 0
    return p + m.offset
end function

sub report(state as string)
    if not m.ready then return
    ms = Int(position() * 1000)
    hPlex("timeline", { id: m.item.Id, state: state, time: ms.toStr(), duration: m.durationMs.toStr() }, "onReported")
end sub

sub onState()
    s = m.video.state
    if s = "playing"
        m.status.visible = false
        if not m.started
            m.started = true
            m.tick.control = "start"
            if m.wantSub <> invalid
                m.video.globalCaptionMode = "On"
                m.video.subtitleTrack = m.wantSub
            else if m.capsPref = "on"
                m.video.globalCaptionMode = "On"
            else if m.capsPref = "off"
                m.video.globalCaptionMode = "Off"
            end if
        end if
        report("playing")
    else if s = "paused" and m.started
        report("paused")
    else if s = "finished"
        leave()
    else if s = "error"
        if m.mode = "direct" and not m.started
            ' the TV refused the file after all: let Plex repackage it instead
            print "[hearth-play] direct play failed ("; m.video.errorCode; " "; m.video.errorMsg; "); falling back to a Plex remux"
            m.video.control = "stop"
            m.mode = "hls"
            m.hlsSubs = "none"
            m.ready = false
            askDecision()
            return
        end if
        msg = m.video.errorMsg
        if msg = invalid or msg = "" then msg = "The video stopped with an error."
        fail(msg + " (" + m.video.errorCode.toStr() + ")")
    end if
end sub

sub onTick()
    if m.leaving then return
    if m.video.state = "paused" then report("paused") else report("playing")
end sub

sub onReported(event as object)
    hTaskFrom(event)
end sub

sub leave()
    if m.leaving then return
    m.leaving = true
    m.tick.control = "stop"
    if m.started
        ' wait for Plex to save the spot so the next screen shows it
        ms = Int(position() * 1000)
        hPlex("timeline", { id: m.item.Id, state: "stopped", time: ms.toStr(), duration: m.durationMs.toStr() }, "onStopped")
    else
        m.top.request = { action: "back" }
    end if
    m.video.control = "stop"
end sub

sub onStopped(event as object)
    hTaskFrom(event)
    m.top.request = { action: "back" }
end sub

sub fail(reason as string)
    m.tick.control = "stop"
    m.video.control = "stop"
    m.status.visible = false
    m.failed = true
    hMessage("Can't play this", reason)
end sub

' ---------- captions picker (the * key) ----------
sub showCaptions()
    tracks = m.video.availableSubtitleTracks
    labels = ["Captions off"]
    m.capTracks = [""]
    if tracks <> invalid
        for each tr in tracks
            name = tr.Description
            if name = invalid or name = "" then name = tr.Language
            if name = invalid or name = "" then name = "Track " + (m.capTracks.count()).toStr()
            labels.push(name)
            m.capTracks.push(tr.TrackName)
        end for
    end if
    if labels.count() = 1 then labels = ["No captions for this one"] : m.capTracks = [""]
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = "Captions"
    d.buttons = labels
    d.observeField("buttonSelected", "onCaptionPicked")
    m.capDialog = d
    m.top.getScene().dialog = d
end sub

sub onCaptionPicked()
    i = m.capDialog.buttonSelected
    m.capDialog.close = true
    track = m.capTracks[i]
    ' remember the choice for the CC buttons and the next video
    reg = CreateObject("roRegistrySection", "hearth")
    if track = "" then reg.Write("captions", "off") else reg.Write("captions", "on")
    reg.Flush()
    if track = ""
        m.video.globalCaptionMode = "Off"
    else
        m.video.globalCaptionMode = "On"
        m.video.subtitleTrack = track
    end if
    m.video.setFocus(true)
end sub

sub afterOptions()
end sub

sub onOptions()
end sub

' called when the error message closes
sub restoreFocus()
    if m.failed = true then leave() else m.video.setFocus(true)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back"
        leave()
        return true
    end if
    if key = "options" and m.ready
        showCaptions()
        return true
    end if
    return false
end function
