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
    m.video.observeField("availableSubtitleTracks", "applyEmbeddedSub")
    m.retried5 = false
    m.finished = false
    m.hlsLight = false
    m.subApplied = false
    m.leaving = false
    m.started = false
    m.ready = false
    m.offset = 0
    m.finder = m.top.findNode("finder")
    m.finder.observeField("closed", "onFinderClosed")
    m.finder.observeField("result", "onFinderResult")
    m.reloadSubs = false
    m.upnext = m.top.findNode("upnext")
    m.upnext.observeField("action", "onUpNextAction")
    m.video.observeField("position", "onPosition")
    resetUpNext()
    uiInit()
end sub

sub onShown(unused as dynamic)
    m.top.setFocus(true)
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
    ' coming back from the subtitle finder after a download: carry on from the same spot
    if m.resumeAt <> invalid
        m.startSec = m.resumeAt
        m.resumeAt = invalid
    end if
    m.durationMs = 0
    if media.duration <> invalid then m.durationMs = media.duration

    m.media = media
    m.part = part
    setupUpNext(it)
    m.streams = hPlayStreams(part)
    m.decision = invalid
    uiOnItem(it)
    m.session = m.global.deviceId + "-" + Rnd(100000).toStr()
    hPlayLogCaps()
    chk = hPlayDirectCheck(media, m.streams)
    if m.forceQuality <> invalid then chk = { ok: false, why: "picked quality " + m.forceQuality + "p" }
    m.planWhy = chk.why
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
    m.decision = d
    if t.ok and d <> invalid
        print "[hearth-play] Plex says: video "; d.video; " ("; d.videoCodec; "), audio "; d.audio; " ("; d.audioCodec; "), captions "; d.subtitle; " ("; d.subtitleCodec; ") | "; d.general
        ' never let a caption cost a full video convert: drop the embedded caption and ask again
        if m.hlsSubs <> "none" and (d.video = "transcode" or d.subtitle = "burn")
            print "[hearth-play] that caption would force a video convert; retrying without it (sidecar files still work)"
            m.hlsSubs = "none"
            askDecision()
            return
        end if
        if d.video = "transcode" and not m.hlsLight and m.forceQuality = invalid
            ' a full convert at 1080p is more than the NAS CPU can do in real time (stuck loading); ask for 720p instead
            print "[hearth-play] Plex must convert the video; asking for 720p at 3 Mbps so the NAS keeps up"
            m.hlsLight = true
            askDecision()
            return
        end if
        if d.video = "transcode" then print "[hearth-play] converting video to 720p on the NAS CPU"
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
    m.top.setFocus(true)
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
            uiStartSubs()
        end if
        uiOnState(s)
        report("playing")
    else if s = "paused" and m.started
        uiOnState(s)
        report("paused")
    else if s = "finished"
        m.finished = true
        if m.next <> invalid and autoplayOn() and m.sleepMode <> "ep"
            playNext()
        else
            m.finished = true
            leave()
        end if
    else if s = "error"
        if m.video.errorCode = -5 and not m.retried5
            ' "only one playing instance": the music (or a mood's sound) still held the player; stop it and try again
            print "[hearth-play] another player was still active; stopping music and retrying"
            m.retried5 = true
            mp = m.global.music
            if mp <> invalid then mp.command = { cmd: "stop" }
            t = CreateObject("roSGNode", "Timer")
            t.duration = 1
            t.observeField("fire", "retryPlay")
            m.retryTimer = t
            t.control = "start"
            return
        end if
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

sub retryPlay()
    m.video.control = "play"
end sub

' The caption Plex has picked for this title is inside the file (or arrives in the remux): once the TV
' lists the tracks it found, turn on the one in that language. With nothing picked in Plex but the CC
' preference on, English (or the first track) is used, like the Plex app's "auto".
sub applyEmbeddedSub()
    if m.subApplied or not m.started or m.capsPref = "off" or m.subMode = "hearth" then return
    tracks = m.video.availableSubtitleTracks
    if tracks = invalid or tracks.count() = 0 then return
    want = ""
    if m.streams <> invalid and m.streams.sub <> invalid
        if m.streams.sub.languageCode <> invalid then want = LCase(m.streams.sub.languageCode)
    else if m.capsPref <> "on"
        return
    end if
    if want = "" then want = "en"
    pick = invalid
    for each tr in tracks
        lang = ""
        if tr.Language <> invalid then lang = LCase(tr.Language)
        if pick = invalid and Left(lang, 2) = Left(want, 2) then pick = tr
    end for
    if pick = invalid then pick = tracks[0]
    print "[hearth-play] captions on: "; pick.TrackName; " ("; pick.Language; ")"
    m.video.globalCaptionMode = "On"
    m.video.subtitleTrack = pick.TrackName
    m.subApplied = true
end sub

sub onTick()
    if m.leaving then return
    checkSleep()
    if m.leaving then return
    if m.video.state = "paused" then report("paused") else report("playing")
end sub

sub onReported(event as object)
    hTaskFrom(event)
end sub

sub leave()
    if m.leaving then return
    m.upnext.callFunc("halt", invalid)
    m.leaving = true
    m.tick.control = "stop"
    m.ov.callFunc("close", invalid)
    if m.markWatched = true
        ' Mark watched and leave: save it as finished, not as a spot to resume
        hPlex("timeline", { id: m.item.Id, state: "stopped", time: m.durationMs.toStr(), duration: m.durationMs.toStr() }, "onReported")
        hPlex("played", { id: m.item.Id }, "onStopped")
    else if m.started
        ' wait for Plex to save the spot so the next screen shows it
        ms = Int(position() * 1000)
        hPlex("timeline", { id: m.item.Id, state: "stopped", time: ms.toStr(), duration: m.durationMs.toStr() }, "onStopped")
    else
        goOn()
    end if
    m.video.control = "stop"
end sub

sub onStopped(event as object)
    hTaskFrom(event)
    goOn()
end sub

' Back to the page, or on to the next queued episode when this one played to the end.
sub goOn()
    q = m.top.queue
    if m.finished = true and q <> invalid and q.count() > 0
        rest = []
        for i = 1 to q.count() - 1
            rest.push(q[i])
        end for
        m.top.request = { action: "play", item: q[0], resume: false, queue: rest, replace: true }
    else
        m.top.request = { action: "back" }
    end if
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
    m.top.setFocus(true)
end sub

' ---------- subtitle finder (the * key) ----------
sub openFinder()
    m.wasPlaying = (m.video.state = "playing")
    if m.wasPlaying then m.video.control = "pause"
    m.reloadSubs = false
    m.finder.item = m.item
    m.finder.callFunc("open", invalid)
end sub

sub onFinderResult()
    r = m.finder.result
    if r = invalid then return
    if r.action = "off"
        subsOff()
        m.capsPref = "off"
    else if r.action = "select"
        s = r.stream
        m.capsPref = "on"
        if isTextSub(s)
            useHearthSub(s)
        else if s.key <> invalid
            ' a subtitle file: it is one of the tracks handed to the video at the start
            url = m.global.plexServer + s.key + "?X-Plex-Token=" + m.global.plexServerToken
            m.video.globalCaptionMode = "On"
            m.video.subtitleTrack = url
        else
            ' inside the file: find the TV's track in that language
            m.streams.sub = s
            m.subApplied = false
            applyEmbeddedSub()
        end if
    else if r.action = "downloaded"
        ' the new file isn't among the video's tracks yet; restart from here once the finder closes
        m.reloadSubs = true
    end if
end sub

sub onFinderClosed()
    if m.reloadSubs
        m.reloadSubs = false
        print "[hearth-play] new subtitle downloaded; restarting to load it"
        ' Plex now has the new file picked; take its choice instead of the old one
        m.subStream = invalid
        reloadAt(position())
        return
    else if m.wasPlaying
        m.video.control = "resume"
    end if
    focusBack()
end sub

sub afterOptions()
end sub

sub onOptions()
end sub

' called when the error message closes
sub restoreFocus()
    if m.failed = true then leave() else focusBack()
end sub

' ---------- Up next and autoplay ----------
' Episodes only. The card appears at Plex's credits marker (Plex Pass credits detection), otherwise 40 s
' before the end. It counts down 15 s and plays the next episode; autoplay off (registry hearth/autoplay)
' shows the card without the countdown. Watch credits (or Back) hides it; the next episode still follows
' when the video ends unless autoplay is off.
sub resetUpNext()
    m.next = invalid
    m.creditsAt = invalid
    m.upShown = false
    m.upDismissed = false
    m.playingNext = false
    m.nextFromQueue = false
end sub

function autoplayOn() as boolean
    return CreateObject("roRegistrySection", "hearth").Read("autoplay") <> "off"
end function

sub setupUpNext(it as object)
    resetUpNext()
    q = m.top.queue
    queued = (q <> invalid and q.count() > 0)
    if not queued and (it.Type <> "Episode" or it.SeriesId = invalid) then return
    durSec = m.durationMs / 1000
    if it._markers <> invalid
        ' the last credits marker is the one at the end (some shows have a mid-episode credits roll too)
        for each mk in it._markers
            if mk.type = "credits" and mk.startTimeOffset <> invalid
                at = mk.startTimeOffset / 1000
                if at > durSec * 0.5 and (m.creditsAt = invalid or at > m.creditsAt) then m.creditsAt = at
            end if
        end for
    end if
    if m.creditsAt = invalid and durSec > 120
        lead = 40
        if durSec < 900 then lead = 20
        m.creditsAt = durSec - lead
        print "[hearth-play] no credits marker; Up next at "; Int(m.creditsAt); " s (end minus "; lead; ")"
    else if m.creditsAt <> invalid
        print "[hearth-play] credits marker at "; Int(m.creditsAt); " s"
    end if
    if queued
        ' Shuffle / play season from the details page: the queue decides what comes next
        m.next = q[0]
        m.nextFromQueue = true
        m.ov.canNext = true
    else
        hPlex("nextEp", { show: it.SeriesId, id: it.Id }, "onNextEp")
    end if
end sub

sub onNextEp(event as object)
    t = hTaskFrom(event)
    n = t.response
    if not t.ok or n = invalid or n.Id = invalid
        print "[hearth-play] no next episode (last one, or Plex didn't say)"
        return
    end if
    m.next = n
    m.ov.canNext = true
    print "[hearth-play] next up: "; hSubtitle(n)
end sub

sub onPosition()
    uiOnPosition()
    if m.next = invalid or m.creditsAt = invalid or m.upShown or m.upDismissed or not m.started then return
    if m.finder.visible = true or m.sheet.visible or m.chapters.visible or m.sleepMode = "ep" then return
    if position() >= m.creditsAt then showUpNext()
end sub

sub showUpNext()
    m.upShown = true
    m.ov.callFunc("close", invalid)
    m.upnext.autoplay = autoplayOn()
    m.upnext.item = m.next
    m.upnext.callFunc("begin", invalid)
    m.upnext.setFocus(true)
end sub

sub onUpNextAction()
    a = m.upnext.action
    if a = "play"
        playNext()
    else if a = "dismiss"
        m.upDismissed = true
        m.upnext.callFunc("halt", invalid)
        focusBack()
    end if
end sub

' Saves this episode as watched, then plays the next one in the same player.
sub playNext()
    if m.playingNext or m.next = invalid then return
    m.playingNext = true
    nxt = m.next
    m.upnext.callFunc("halt", invalid)
    m.tick.control = "stop"
    if m.started and m.noMarkOnNext = true
        ms = Int(position() * 1000)
        hPlex("timeline", { id: m.item.Id, state: "stopped", time: ms.toStr(), duration: m.durationMs.toStr() }, "onReported")
    else if m.started
        hPlex("timeline", { id: m.item.Id, state: "stopped", time: m.durationMs.toStr(), duration: m.durationMs.toStr() }, "onReported")
        hPlex("played", { id: m.item.Id }, "onReported")
    end if
    m.noMarkOnNext = false
    uiReset(false)
    m.subStream = invalid
    m.epSeasons = invalid
    m.epList = invalid
    m.forceQuality = invalid
    m.reloading = false
    m.video.control = "stop"
    m.ready = false
    m.started = false
    m.subApplied = false
    m.retried5 = false
    m.hlsLight = false
    m.offset = 0
    m.status.text = "Lighting the lantern..."
    m.status.visible = true
    m.top.setFocus(true)
    print "[hearth-play] autoplay: "; hSubtitle(nxt)
    if m.nextFromQueue
        q = m.top.queue
        rest = []
        for i = 1 to q.count() - 1
            rest.push(q[i])
        end for
        m.top.queue = rest
        m.top.resume = false
    else
        ' carry on where the next episode was left, if it was started before
        m.top.resume = true
    end if
    m.finished = false
    m.top.item = nxt
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    print "[hearth-ui] key "; key; " | ready "; m.ready; " | video "; m.video.state; " | up next "; m.upnext.visible
    if key = "play" and m.upnext.visible
        ' the Up next card has focus; play/pause still controls the video
        if m.video.state = "paused" then m.video.control = "resume" else m.video.control = "pause"
        return true
    end if
    if key = "back"
        leave()
        return true
    end if
    return uiKey(key)
end function
