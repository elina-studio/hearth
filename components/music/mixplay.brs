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
        if m.out.isSameNode(m.audio) and (m.top.state = "playing" or m.top.state = "buffering") and not castActive()
            playIndex(m.top.index, m.top.position)
        end if
        return
    end if
    if m.mix <> invalid then mixOff()
    m.mix = { video: v, kind: pxStr(c.kind), clip: pxStr(c.clip) }
    m.mixSkip = ""
    v.observeField("state", "onMixVideoState")
    v.observeField("position", "onMixVideoPos")
    m.top.mixState = "off"
    ' a song already playing moves over to the joined stream where it is
    live = (m.top.state = "playing" or m.top.state = "buffering")
    if live and m.top.queue <> invalid and m.top.queue.count() > 0 and not castActive()
        playIndex(m.top.index, m.top.position)
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
    if m.mix <> invalid and m.mix.kind = "viz" and (m.top.state = "playing" or m.top.state = "buffering")
        playIndex(m.top.index, m.top.position)
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
    if m.mix <> invalid and not m.out.isSameNode(m.audio)
        m.out = m.audio
        m.mix.video.control = "stop"
    end if
end sub

sub mixPlay(i as integer, startAt as float)
    tr = m.top.queue[i]
    ss = Int(startAt)
    m.mixSeq = m.mixSeq + 1
    m.mixReq = { seq: m.mixSeq, index: i, ss: ss, id: tr.id }
    m.top.state = "buffering"
    m.top.mixState = "starting"
    q = "kind=" + m.mix.kind + "&file=" + pxEscape(tr.file) + "&ss=" + ss.toStr()
    if m.mix.kind = "viz"
        look = vizLookFor(tr)
        m.top.vizLook = look
        q = q + "&look=" + look
    else
        q = q + "&clip=" + pxEscape(m.mix.clip)
    end if
    nasCall("GET", "/api/mix/start?" + q, "", "onMixStart", m.mixSeq.toStr())
end sub

sub onMixStart(event as object)
    t = hTaskFrom(event)
    r = m.mixReq
    if m.mix = invalid or r = invalid or t.tag <> r.seq.toStr() then return
    m.mixReq = invalid
    resp = t.response
    if t.ok and resp.url <> invalid and resp.url <> ""
        c = CreateObject("roSGNode", "ContentNode")
        c.url = resp.url
        c.streamFormat = "hls"
        tr = m.top.track
        if tr <> invalid then c.title = tr.title
        m.mixBase = r.ss
        m.top.mixKind = pxStr(resp.kind)
        m.out = m.mix.video
        m.mix.video.content = c
        m.mix.video.control = "play"
        m.top.mixState = "on"
        print "[music] joined stream ("; m.top.mixKind; ") from "; r.ss; " s"
        return
    end if
    why = ""
    if resp.why <> invalid then why = pxStr(resp.why)
    if why = "" and t.status <= 0 then why = "the NAS helper didn't answer"
    if why = "" then why = "the NAS helper said " + t.status.toStr()
    print "[music] no joined stream: "; why
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
    if v.state = "error"
        print "[music] joined stream error: "; v.errorMsg
        tr = m.top.track
        if tr <> invalid then m.mixSkip = tr.id
        m.top.mixNote = "the TV couldn't play the joined stream (" + v.errorMsg + ")"
        m.top.mixState = "failed"
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
    mixPrefetch()
end sub

' near the end of a song, ask the NucBox to start on the next one so it is ready in time
sub mixPrefetch()
    if m.mix.kind <> "viz" or m.top.duration <= 0 then return
    if m.top.duration - m.top.position > 30 then return
    q = m.top.queue
    nxt = m.top.index + 1
    if m.top.repeat = "one" then nxt = m.top.index
    if q = invalid or nxt >= q.count() then return
    tr = q[nxt]
    if m.mixPrefetched = tr.id or tr.file = invalid or tr.file = "" then return
    m.mixPrefetched = tr.id
    nasCall("GET", "/api/mix/start?kind=viz&prefetch=1&ss=0&file=" + pxEscape(tr.file) + "&look=" + vizLookFor(tr), "", "onMixPrefetch")
end sub

sub onMixPrefetch(event as object)
    hTaskFrom(event)
end sub
