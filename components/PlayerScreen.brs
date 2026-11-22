sub init()
    m.video = m.top.findNode("video")
    m.status = m.top.findNode("status")
    m.status.font = hFont("regular", 28)
    m.tick = m.top.findNode("tick")
    m.tick.observeField("fire", "onTick")
    m.video.observeField("state", "onState")
    m.session = invalid
    m.leaving = false
    m.started = false
end sub

sub onShown(unused as dynamic)
    m.video.setFocus(true)
end sub

function ticksFromSeconds(sec as dynamic) as longinteger
    t& = Int(sec)
    return t& * 10000000
end function

function deviceProfile() as object
    di = CreateObject("roDeviceInfo")
    video = "h264"
    if di.CanDecodeVideo({ Codec: "hevc" }).result = true then video = video + ",hevc"
    if di.CanDecodeVideo({ Codec: "vp9" }).result = true then video = video + ",vp9"
    audio = "aac,mp3,ac3,eac3,flac,opus"
    return {
        MaxStreamingBitrate: 40000000,
        MaxStaticBitrate: 100000000,
        MusicStreamingTranscodingBitrate: 192000,
        DirectPlayProfiles: [
            { Container: "mp4,m4v,mov", Type: "Video", VideoCodec: video, AudioCodec: audio },
            { Container: "mkv,webm", Type: "Video", VideoCodec: video, AudioCodec: audio }
        ],
        TranscodingProfiles: [
            { Container: "ts", Type: "Video", VideoCodec: "h264", AudioCodec: "aac,ac3", Context: "Streaming", Protocol: "hls", MaxAudioChannels: "6", MinSegments: 1, BreakOnNonKeyFrames: true }
        ],
        ContainerProfiles: [],
        CodecProfiles: [],
        SubtitleProfiles: [
            { Format: "srt", Method: "External" },
            { Format: "vtt", Method: "External" },
            { Format: "subrip", Method: "External" }
        ]
    }
end function

sub start()
    it = m.top.item
    if it = invalid or it.Id = invalid then return
    m.startSec = 0
    if m.top.resume and it.UserData <> invalid and it.UserData.PlaybackPositionTicks <> invalid
        m.startSec = it.UserData.PlaybackPositionTicks / 10000000
    end if
    body = { UserId: hUser(), StartTimeTicks: ticksFromSeconds(m.startSec), AutoOpenLiveStream: true, EnableDirectPlay: true, EnableDirectStream: true, EnableTranscoding: true, AllowVideoStreamCopy: true, AllowAudioStreamCopy: true, DeviceProfile: deviceProfile() }
    hApi("POST", "/Items/" + it.Id + "/PlaybackInfo", { userId: hUser() }, body, "onPlaybackInfo")
end sub

sub onPlaybackInfo(event as object)
    t = hTaskFrom(event)
    r = t.response
    if not t.ok or r = invalid or r.MediaSources = invalid or r.MediaSources.count() = 0
        reason = "The server didn't send a playable version."
        if r <> invalid and r.ErrorCode <> invalid then reason = "Jellyfin said: " + r.ErrorCode
        if t.status <= 0 then reason = "Couldn't reach Jellyfin."
        fail(reason)
        return
    end if
    src = r.MediaSources[0]
    it = m.top.item
    server = m.global.server
    token = m.global.token
    content = CreateObject("roSGNode", "ContentNode")
    content.title = hTitle(it)
    if it.Type = "Episode" then content.secondaryTitle = hSubtitle(it)

    if src.SupportsDirectPlay = true or (src.SupportsDirectStream = true and src.TranscodingUrl = invalid)
        m.playMethod = "DirectPlay"
        if src.SupportsDirectPlay <> true then m.playMethod = "DirectStream"
        content.url = server + "/Videos/" + it.Id + "/stream?static=true&MediaSourceId=" + src.Id + "&PlaySessionId=" + r.PlaySessionId + "&api_key=" + token
        c = LCase(src.Container)
        if c = "mkv" or c = "webm" or Instr(1, c, "mkv") > 0
            content.streamFormat = "mkv"
        else
            content.streamFormat = "mp4"
        end if
    else if src.TranscodingUrl <> invalid
        m.playMethod = "Transcode"
        url = server + src.TranscodingUrl
        if Instr(1, LCase(url), "api_key=") = 0 then url = url + "&api_key=" + token
        content.url = url
        content.streamFormat = "hls"
    else
        fail("This file needs a format the TV can't play.")
        return
    end if

    ' outside subtitle files
    subs = []
    if src.MediaStreams <> invalid
        for each s in src.MediaStreams
            if s.Type = "Subtitle" and s.DeliveryMethod = "External" and s.DeliveryUrl <> invalid
                u = s.DeliveryUrl
                if Left(u, 4) <> "http" then u = server + u
                if Instr(1, LCase(u), "api_key=") = 0
                    sep = "?"
                    if Instr(1, u, "?") > 0 then sep = "&"
                    u = u + sep + "api_key=" + token
                end if
                lang = "und"
                if s.Language <> invalid then lang = s.Language
                name = lang
                if s.DisplayTitle <> invalid then name = s.DisplayTitle
                subs.push({ Language: lang, TrackName: u, Description: name })
            end if
        end for
    end if
    if subs.count() > 0 then content.subtitleTracks = subs

    ' transcodes already start at the resume point on the server
    if m.playMethod = "Transcode"
        content.playStart = 0
        m.offset = m.startSec
    else
        content.playStart = m.startSec
        m.offset = 0
    end if

    m.session = { ItemId: it.Id, MediaSourceId: src.Id, PlaySessionId: r.PlaySessionId, PlayMethod: m.playMethod }
    m.video.content = content
    m.video.control = "play"
    m.video.setFocus(true)
end sub

function position() as dynamic
    p = m.video.position
    if p = invalid then p = 0
    return p + m.offset
end function

function report(extra as object) as object
    b = {}
    b.append(m.session)
    b.PositionTicks = ticksFromSeconds(position())
    b.CanSeek = true
    b.append(extra)
    return b
end function

sub onState()
    s = m.video.state
    if s = "playing"
        m.status.visible = false
        if not m.started
            m.started = true
            hApi("POST", "/Sessions/Playing", {}, report({ IsPaused: false }), "onReported")
            m.tick.control = "start"
        else
            hApi("POST", "/Sessions/Playing/Progress", {}, report({ IsPaused: false, EventName: "unpause" }), "onReported")
        end if
    else if s = "paused" and m.started
        hApi("POST", "/Sessions/Playing/Progress", {}, report({ IsPaused: true, EventName: "pause" }), "onReported")
    else if s = "finished"
        leave()
    else if s = "error"
        msg = m.video.errorMsg
        if msg = invalid or msg = "" then msg = "The video stopped with an error."
        fail(msg + " (" + m.video.errorCode.toStr() + ")")
    end if
end sub

sub onTick()
    if m.session = invalid or m.leaving then return
    hApi("POST", "/Sessions/Playing/Progress", {}, report({ IsPaused: (m.video.state = "paused"), EventName: "timeupdate" }), "onReported")
end sub

sub onReported(event as object)
    hTaskFrom(event)
end sub

sub leave()
    if m.leaving then return
    m.leaving = true
    m.tick.control = "stop"
    if m.session <> invalid and m.started
        ' wait for the server to save the position so the next screen shows it
        hApi("POST", "/Sessions/Playing/Stopped", {}, report({}), "onStopped")
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

sub afterOptions()
end sub

sub onOptions()
end sub

' called when the message closes
sub restoreFocus()
    if m.failed = true then leave()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back"
        leave()
        return true
    end if
    return false
end function
