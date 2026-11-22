' Plays a Plex movie or episode. Direct play when the TV can handle the file, otherwise a Plex HLS transcode.
' Captions: Plex sidecar files (including Bazarr's) plus anything embedded; * opens the captions picker.
sub init()
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

function canPlay(media as object) as boolean
    di = CreateObject("roDeviceInfo")
    c = LCase(toStr(media.container))
    v = LCase(toStr(media.videoCodec))
    a = LCase(toStr(media.audioCodec))
    okC = (c = "mp4" or c = "m4v" or c = "mov" or c = "mkv")
    okV = (v = "h264")
    if v = "hevc" or v = "h265" then okV = (di.CanDecodeVideo({ Codec: "hevc" }).result = true)
    if v = "vp9" then okV = (di.CanDecodeVideo({ Codec: "vp9" }).result = true)
    okA = (a = "aac" or a = "mp3" or a = "ac3" or a = "eac3" or a = "flac" or a = "opus" or a = "")
    return okC and okV and okA
end function

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

    content = CreateObject("roSGNode", "ContentNode")
    content.title = hTitle(it)
    if it.Type = "Episode" then content.secondaryTitle = hSubtitle(it)
    if canPlay(media)
        content.url = server + part.key + "?X-Plex-Token=" + token
        if LCase(toStr(media.container)) = "mkv" then content.streamFormat = "mkv" else content.streamFormat = "mp4"
        content.playStart = m.startSec
        m.offset = 0
    else
        q = "path=" + hEscape("/library/metadata/" + it.Id) + "&mediaIndex=0&partIndex=0&protocol=hls&fastSeek=1"
        q = q + "&directPlay=0&directStream=1&directStreamAudio=1&videoResolution=1920x1080&maxVideoBitrate=20000"
        q = q + "&offset=" + Int(m.startSec).toStr() + "&subtitles=none&session=" + m.global.deviceId + "-" + Rnd(100000).toStr()
        q = q + "&X-Plex-Client-Identifier=" + hEscape(m.global.deviceId) + "&X-Plex-Product=Hearth&X-Plex-Platform=Roku&X-Plex-Token=" + token
        q = q + "&X-Plex-Client-Profile-Extra=" + hEscape("add-transcode-target(type=videoProfile&context=streaming&protocol=hls&container=mpegts&videoCodec=h264&audioCodec=aac,ac3)")
        content.url = server + "/video/:/transcode/universal/start.m3u8?" + q
        content.streamFormat = "hls"
        content.playStart = 0
        m.offset = m.startSec
    end if

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
            end if
        end if
        report("playing")
    else if s = "paused" and m.started
        report("paused")
    else if s = "finished"
        leave()
    else if s = "error"
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
