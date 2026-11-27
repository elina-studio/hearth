' Music with pictures, as one stream (part of MusicPlayer).
' The TV plays one stream at a time, so a music view that shows a video (the Visualizer, the Hearth fire)
' can't run it beside the Audio node. Instead the NAS helper joins the pictures and the song into one
' HLS stream (tools/remote/mix.py), and the song plays through the view's Video node:
'   mixOn  { video: <Video node>, kind: "viz" | "fire", clip: <Plex part key of the fire clip> }
'   mixOff                       back to the Audio node, at the same spot
'   mixLook { look: "57" }       another look for this song (the Visualizer's Left/Right and picker)
' The video's position 0 is the song at m.mixBase. If the helper can't make the stream, the song plays
' on the Audio node as before and mixState says "failed" (mixNote says why), so the view can show
' something else.

sub mixInit()
    m.mix = invalid
    m.mixSeq = 0
    m.mixBase = 0
    m.mixReq = invalid
    m.mixSkip = ""
    m.mixPrefetched = ""
    m.mixPending = invalid
    m.mixShownLook = ""
    m.mixAskLook = ""
    m.mixNoLive = ""
    m.vizFor = {}
end sub

function mixCommand(c as object) as boolean
    cmd = c.cmd
    if cmd = "mixOn"
        mixOn(c)
    else if cmd = "mixOff"
        mixOff()
    else if cmd = "mixLook"
        mixLook(pxStr(c.look))
    else
        return false
    end if
    return true
end function

function mixWanted(tr as dynamic) as boolean
    if m.mix = invalid or tr = invalid then return false
    if castActive() then return false
    if tr.file = invalid or tr.file = "" then return false
    ' this song's joined stream already failed on the TV: plain audio for the rest of it
    if m.mixSkip = tr.id then return false
    return true
end function

sub mixOn(c as object)
    if c.video = invalid then return
    v = c.video
    if m.mix <> invalid and m.mix.video.isSameNode(v) and m.mix.kind = pxStr(c.kind)
        ' asked again (the fire clip is ready now): try this song again where it is
        m.mixSkip = ""
        if m.out.isSameNode(m.audio) and m.top.state = "playing" and not castActive()
            mixSwitch()
        end if
        return
    end if
    if m.mix <> invalid then mixOff()
    m.mix = { video: v, kind: pxStr(c.kind), clip: pxStr(c.clip) }
    m.mixSkip = ""
    v.observeField("state", "onMixVideoState")
    v.observeField("position", "onMixVideoPos")
    ' fresh positions keep the lyrics on time
    v.notificationInterval = 0.25
    m.top.mixState = "off"
    ' a song already playing keeps playing, and moves over to the joined stream a few seconds on
    if m.top.queue <> invalid and m.top.queue.count() > 0 and not castActive()
        if m.top.state = "playing"
            mixSwitch()
        else if m.top.state = "buffering"
            playIndex(m.top.index, m.top.position)
        end if
    end if
end sub

sub mixOff()
    if m.mix = invalid then return
    v = m.mix.video
    wasMixing = (not m.out.isSameNode(m.audio))
    live = (m.top.state = "playing" or m.top.state = "buffering")
    at = m.top.position
    v.unobserveField("state")
    v.unobserveField("position")
    m.out = m.audio
    v.control = "stop"
    m.mix = invalid
    m.mixReq = invalid
    mixClearPending()
    m.mixSeq = m.mixSeq + 1
    m.top.mixState = "off"
    if wasMixing or m.top.state = "buffering"
        if live
            playIndex(m.top.index, at)
        else
            ' paused: resume() finds the Audio node idle and starts the song here
            m.top.position = at
        end if
    end if
end sub

sub mixLook(look as string)
    tr = m.top.track
    if tr = invalid or look = "" then return
    m.vizFor[tr.id] = look
    m.top.vizLook = look
    ' a new pick always gets a fresh try, even if this song's stream failed before
    m.mixSkip = ""
    m.mixNoLive = ""
    if m.mix <> invalid and m.mix.kind = "viz" and not castActive()
        if m.top.state = "playing"
            mixSwitch()
        else if m.top.state = "buffering"
            playIndex(m.top.index, m.top.position)
        end if
    end if
end sub

function vizLookFor(tr as object) as string
    l = m.vizFor[tr.id]
    if l = invalid
        l = vizPick()
        m.vizFor[tr.id] = l
    end if
    return l
end function

' called at the top of playIndex: the old stream stops, and its events stop counting
sub mixStopVideo()
    m.mixSeq = m.mixSeq + 1
    m.mixReq = invalid
    mixClearPending()
    if m.mix <> invalid and not m.out.isSameNode(m.audio)
        m.out = m.audio
        m.mix.video.control = "stop"
    end if
end sub

sub mixPlay(i as integer, startAt as float)
    tr = m.top.queue[i]
    ss = Int(startAt)
    m.mixSeq = m.mixSeq + 1
    ' the stream starts on a whole second; the part of a second left over is skipped inside it
    m.mixReq = { seq: m.mixSeq, index: i, ss: ss, id: tr.id, at: startAt, live: false }
    m.top.state = "buffering"
    m.top.mixState = "starting"
    m.mixAskLook = ""
    q = mixQuery(tr, ss)
    m.mixReq.look = m.mixAskLook
    nasCall("GET", "/api/mix/start?" + q, "", "onMixStart", m.mixSeq.toStr())
end sub

function mixQuery(tr as object, ss as integer, ahead = false as boolean) as string
    q = "kind=" + m.mix.kind + "&file=" + pxEscape(tr.file) + "&ss=" + ss.toStr()
    if ahead then q = q + "&prefetch=1"
    if m.mixNoLive = tr.id then q = q + "&noLive=1"
    if m.mix.kind = "viz"
        look = vizLookFor(tr)
        if not ahead
            m.top.vizLook = look
            m.mixAskLook = look
        end if
        q = q + "&look=" + look
        ' looks the helper may show instead when this one isn't ready (no NucBox and no backup loop yet)
        q = q + "&alt=" + vizPool().Join(",")
    else
        q = q + "&clip=" + pxEscape(m.mix.clip)
    end if
    return q
end function

' Mid-song (the view opened, the fire clip got ready, a new look): the song keeps playing where it is,
' and the joined stream is asked to start a few seconds further on. When it is ready and the song gets
' there, the TV changes over at that exact spot, so nothing repeats and the lyrics stay on time.
sub mixSwitch()
    tr = m.top.track
    if m.mix = invalid or tr = invalid or not mixWanted(tr) then return
    ss = Int(m.top.position) + 4
    ' too close to the end: the next song starts on the joined stream anyway
    if m.top.duration > 0 and ss > m.top.duration - 3 then return
    m.mixSeq = m.mixSeq + 1
    mixClearPending()
    m.mixReq = { seq: m.mixSeq, index: m.top.index, ss: ss, id: tr.id, at: ss, live: true }
    ' a new look: the old one stays on screen until the change-over
    if m.out.isSameNode(m.audio) then m.top.mixState = "starting"
    m.mixAskLook = ""
    q = mixQuery(tr, ss)
    m.mixReq.look = m.mixAskLook
    print "[music] new look "; m.mixAskLook; " from "; ss; " s (song at "; m.top.position; ")"
    nasCall("GET", "/api/mix/start?" + q, "", "onMixStart", m.mixSeq.toStr())
end sub

' the joined stream is ready ahead of the song: wait for the song to get there, watching closely
sub mixWait(p as object)
    m.mixPending = p
    m.out.notificationInterval = 0.1
    mixCheckPending()
end sub

sub mixClearPending()
    if m.mixPending = invalid then return
    m.mixPending = invalid
    m.audio.notificationInterval = 1
    if m.mix <> invalid then m.mix.video.notificationInterval = 0.25
end sub

' called on every position tick while a change-over is waiting
sub mixCheckPending()
    p = m.mixPending
    if p = invalid then return
    tr = m.top.track
    if tr = invalid or tr.id <> p.id or m.top.index <> p.index
        mixClearPending()
        return
    end if
    if m.top.position < p.ss - 0.12 then return
    mixClearPending()
    mixJoin(p.url, p.kind, p.ss, m.top.position, p.look)
end sub

' start the joined stream (which begins at song second ss) at song second at
sub mixJoin(url as string, kind as string, ss as integer, at as float, look = "" as dynamic)
    m.mixShownLook = pxStr(look)
    c = CreateObject("roSGNode", "ContentNode")
    c.url = url
    c.streamFormat = "hls"
    tr = m.top.track
    if tr <> invalid then c.title = tr.title
    off = at - ss
    if off > 0.05 then c.playStart = off
    m.mixBase = ss
    m.top.mixKind = kind
    wasAudio = m.out.isSameNode(m.audio)
    ' the old stream's "stopped" must not read as the song stopping
    m.top.state = "buffering"
    m.out = m.mix.video
    if wasAudio then m.audio.control = "stop"
    m.mix.video.content = c
    m.mix.video.control = "play"
    m.top.mixState = "on"
    print "[music] joined stream ("; kind; ") from "; ss; " s, in at "; at
end sub

sub onMixStart(event as object)
    t = hTaskFrom(event)
    r = m.mixReq
    if m.mix = invalid or r = invalid or t.tag <> r.seq.toStr() then return
    m.mixReq = invalid
    resp = t.response
    if t.ok and resp.url <> invalid and resp.url <> ""
        tr = m.top.track
        if tr = invalid or tr.id <> r.id then return
        ' the look asked for isn't ready, so the helper sent another one: name the one really on screen
        shown = pxStr(resp.look)
        if shown <> "" and r.look <> invalid and r.look <> "" and shown <> r.look and vizLabel(shown) <> ""
            say(vizLabel(r.look) + " isn't ready yet, showing " + vizLabel(shown))
            r.look = shown
            m.vizFor[tr.id] = shown
            m.top.vizLook = shown
        end if
        if r.live = true
            ' the song is still playing: change over when it reaches the stream's start
            if m.top.state <> "playing"
                ' paused meanwhile: resume() starts the joined stream where the song is
                if m.out.isSameNode(m.audio) then m.top.mixState = "off"
                return
            end if
            if m.top.position < r.ss - 0.12
                mixWait({ url: resp.url, kind: pxStr(resp.kind), ss: r.ss, id: r.id, index: r.index, look: r.look })
            else
                mixJoin(resp.url, pxStr(resp.kind), r.ss, m.top.position, r.look)
            end if
            return
        end if
        mixJoin(resp.url, pxStr(resp.kind), r.ss, r.at, r.look)
        return
    end if
    why = ""
    if resp.why <> invalid then why = pxStr(resp.why)
    if why = "" and t.status <= 0 then why = "the NAS helper didn't answer"
    if why = "" then why = "the NAS helper said " + t.status.toStr()
    print "[music] no joined stream: "; why
    if r.live = true
        ' the song never stopped: it just carries on as it is (with the old look, if one is on)
        if not m.out.isSameNode(m.audio)
            ' say so, and put the name back to the look that is really on screen
            tr = m.top.track
            if tr <> invalid and m.mixShownLook <> invalid and m.mixShownLook <> ""
                m.vizFor[tr.id] = m.mixShownLook
                m.top.vizLook = m.mixShownLook
            end if
            say("Look not ready: " + why)
            return
        end if
        m.top.mixNote = why
        m.top.mixState = "failed"
        return
    end if
    mixFallBack(why)
end sub

' the song carries on as plain audio from where it is; the view shows its stand-in
sub mixFallBack(why as string)
    m.top.mixNote = why
    m.top.mixState = "failed"
    m.out = m.audio
    m.audio.control = "play"
end sub

sub onMixVideoState()
    if m.mix = invalid or not m.out.isSameNode(m.mix.video) then return
    v = m.mix.video
    if v.state = "error" and m.top.mixKind = "live" and m.top.track <> invalid and m.mixNoLive <> m.top.track.id
        ' the NucBox couldn't keep up with this look: carry on with the NAS's ready-made loop of it
        print "[music] live stream error ("; v.errorMsg; "), trying the backup loop"
        m.mixNoLive = m.top.track.id
        playIndex(m.top.index, m.top.position)
        return
    end if
    if v.state = "error"
        print "[music] joined stream error: "; v.errorMsg
        tr = m.top.track
        if tr <> invalid then m.mixSkip = tr.id
        m.top.mixNote = "the TV couldn't play the joined stream (" + v.errorMsg + ")"
        m.top.mixState = "failed"
        playIndex(m.top.index, m.top.position)
        return
    end if
    if v.state = "finished" and m.top.duration > 0 and m.top.position < m.top.duration - 3
        ' the stream ran out before the song did: carry on from here, never skip ahead to the next song
        print "[music] joined stream ended early at "; m.top.position; " of "; m.top.duration
        playIndex(m.top.index, m.top.position)
        return
    end if
    outState(v.state, v.errorMsg)
end sub

sub onMixVideoPos()
    if m.mix = invalid or not m.out.isSameNode(m.mix.video) then return
    v = m.mix.video
    m.top.position = m.mixBase + v.position
    tr = m.top.track
    if tr <> invalid and tr.duration > 0 then m.top.duration = tr.duration
    afterPosition()
    mixCheckPending()
    mixPrefetch()
end sub

' near the end of a song, have the next one's stream made now, so it is whole and ready the moment it's needed
sub mixPrefetch()
    if m.top.duration <= 0 then return
    if m.top.duration - m.top.position > 40 then return
    q = m.top.queue
    nxt = m.top.index + 1
    if m.top.repeat = "one" then nxt = m.top.index
    if q = invalid or nxt >= q.count() then return
    tr = q[nxt]
    if m.mixPrefetched = tr.id or tr.file = invalid or tr.file = "" then return
    m.mixPrefetched = tr.id
    nasCall("GET", "/api/mix/start?" + mixQuery(tr, 0, true), "", "onMixPrefetch")
end sub

sub onMixPrefetch(event as object)
    hTaskFrom(event)
end sub
