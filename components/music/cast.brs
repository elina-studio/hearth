' Playing music in other rooms. Included by MusicPlayer.
'
' The speakers are Music Assistant players, reached through Home Assistant's REST API (the same
' haUrl / haToken Hearth already uses for the weather). Music Assistant keeps the speakers in sync
' (it joins them into one group under a leader). It can't sync a Roku, so the TV plays the same song
' itself, started castDelay seconds after the speakers are told to play; "TV timing" nudges that.
'
' rooms: [{ id, name, sub, kind: "tv" | "speaker", on, vol (0-100, -1 = unknown) }], the TV first.
' Commands (music.command): castRefresh, castToggle {id}, castVolume {id, delta}, castAll, castNudge {delta} (moves the TV at once), castResync (lines the TV up now).

sub castInit()
    m.castTimer = m.top.findNode("castTimer")
    m.castTimer.observeField("fire", "onCastTimer")
    m.castAlignTimer = m.top.findNode("castAlign")
    m.castAlignTimer.observeField("fire", "castAlign")
    m.castClock = m.top.findNode("castClock")
    m.castClock.observeField("fire", "onCastClock")
    m.castPollT = m.top.findNode("castPoll")
    m.castPollT.observeField("fire", "onCastPoll")
    ' castDelay = how far the speakers trail the "play" answer (castLag, measured again every song)
    ' plus castTrim (what the TV needs on top, from the phone's microphone or the TV timing row, kept per set of rooms)
    m.castLag = 1.5
    m.castTrim = 0
    d = CreateObject("roRegistrySection", "hearth").Read("castDelay")
    if d = "" then m.top.castDelay = 1.5 else m.top.castDelay = Val(d)
    m.castTrim = m.top.castDelay - m.castLag
    m.castLeader = ""
    m.top.rooms = [{ id: "tv", name: "This TV", sub: "Hearth", kind: "tv", on: true, vol: -1 }]
end sub

' true when at least one speaker is playing along
function castActive() as boolean
    return m.top.castCount > 0
end function

' the TV is ticked and hasn't handed its screen to a video (tvYield)
function castTvOn() as boolean
    rooms = m.top.rooms
    return rooms[0].on = true and m.tvYielded <> true
end function

function castOnIds() as object
    ids = []
    for each r in m.top.rooms
        if r.kind <> "tv" and r.on = true then ids.push(r.id)
    end for
    return ids
end function

' Handles the cast* commands. Returns true when it did.
function castCommand(c as object) as boolean
    cmd = c.cmd
    if cmd = "castRefresh"
        haCall("GET", "/api/states", "", "onCastStates")
    else if cmd = "castToggle"
        castToggle(pxStr(c.id))
    else if cmd = "castAll"
        castAll()
    else if cmd = "castVolume"
        castVolume(pxStr(c.id), c.delta)
    else if cmd = "castNudge"
        m.castTrim = m.castTrim + c.delta
        castSetDelay()
        castSaveTrim()
        ' line the TV up right away (after a short pause, so a run of presses seeks once)
        m.castAlignTimer.control = "stop"
        m.castAlignTimer.control = "start"
    else if cmd = "castResync"
        castAlign()
    else if cmd = "tvYield"
        tvYield()
    else if cmd = "tvRejoin"
        tvRejoin()
    else
        return false
    end if
    return true
end function

' ---------- Home Assistant ----------
function haCall(method as string, path as string, body as string, cb as string, tag = "" as string) as object
    t = CreateObject("roSGNode", "HaTask")
    t.method = method
    t.path = path
    t.bodyText = body
    t.tag = tag
    t.observeField("done", cb)
    if m.hTasks = invalid then m.hTasks = {}
    key = "h" + Rnd(1000000).toStr()
    m.hTasks[key] = t
    t.key = key
    t.control = "RUN"
    return t
end function

sub haService(domain as string, service as string, data as object, tag = "" as string)
    haCall("POST", "/api/services/" + domain + "/" + service, FormatJson(data), "onCastService", tag)
end sub

sub onCastService(event as object)
    t = hTaskFrom(event)
    if t.ok
        if t.tag = "playjoin" or t.tag = "playjoin2" then castCatchUp(t.bodyText)
        return
    end if
    print "[hearth cast] "; t.path; " failed: "; t.status; " "; t.bodyText
    if t.tag = "queueadd"
        m.castQueuedId = ""
        return
    end if
    ' Music Assistant finds the song by name; an artist or album spelled differently in its library
    ' (e.g. alt-J tagged with an odd hyphen) makes it fail, so try once more with the title alone
    if (t.tag = "play" or t.tag = "playjoin") and t.status >= 400
        req = ParseJson(t.bodyText)
        if req <> invalid and (req.artist <> invalid or req.album <> invalid)
            req.delete("artist")
            req.delete("album")
            haService("music_assistant", "play_media", req, t.tag + "2")
            return
        end if
    end if
    if t.tag = "playjoin" or t.tag = "play2" or t.tag = "playjoin2" then tag = "play" else tag = t.tag
    if tag = "join"
        ' different kinds of speakers can't always be grouped: play on each one instead (not in sync)
        m.castNoJoin = true
        say("These speakers can't be grouped, so they'll play side by side, maybe not quite in step.")
        m.castSeekFrom = m.top.position
        m.castSeekClock = CreateObject("roTimespan")
        castPlayTrack("playjoin")
    else if tag = "play"
        if t.status = -1
            say("The speakers are slow to answer. The song may still start there.")
        else if t.status = 0
            say("Can't reach Home Assistant.")
        else
            say("Music Assistant couldn't play this song on the speakers.")
        end if
    end if
end sub

sub onCastStates(event as object)
    t = hTaskFrom(event)
    if not t.ok
        if pCfg().haToken = ""
            say("Home Assistant isn't set up on this TV yet.")
        else
            say("Can't reach Home Assistant.")
        end if
        return
    end if
    old = {}
    for each r in m.top.rooms
        old[r.id] = r
    end for
    rooms = [m.top.rooms[0]]
    items = t.response.items
    if items = invalid then items = []
    for each s in items
        id = pxStr(s.entity_id)
        a = s.attributes
        if Left(id, 13) = "media_player." and a <> invalid and a.mass_player_type <> invalid and s.state <> "unavailable"
            name = pxStr(a.friendly_name)
            if name = "" then name = Mid(id, 14)
            sub2 = ""
            if a.mass_player_type = "group" then sub2 = "Speaker group"
            vol = -1
            if a.volume_level <> invalid then vol = Int(a.volume_level * 100 + 0.5)
            on = false
            if old[id] <> invalid then on = (old[id].on = true)
            rooms.push({ id: id, name: name, sub: sub2, kind: "speaker", on: on, vol: vol })
        end if
    end for
    m.top.rooms = rooms
    if rooms.count() = 1 then say("Music Assistant has no speakers in Home Assistant yet.")
end sub

' ---------- choosing rooms ----------
sub castToggle(id as string)
    rooms = m.top.rooms
    before = castOnIds()
    for each r in rooms
        if r.id = id then r.on = not (r.on = true)
    end for
    ' something has to play: the TV comes back when the last speaker goes
    anySpeaker = false
    for each r in rooms
        if r.kind <> "tv" and r.on = true then anySpeaker = true
    end for
    if not anySpeaker and rooms[0].on <> true
        if id = "tv" then say("Pick a speaker first, then the TV can go quiet.")
        rooms[0].on = true
    end if
    m.top.rooms = rooms
    castApply(before, id)
end sub

sub castAll()
    rooms = m.top.rooms
    before = castOnIds()
    for each r in rooms
        r.on = true
    end for
    m.top.rooms = rooms
    castApply(before, "")
end sub

' castDelay from the measured lag and the trim, kept between 0 and 6 seconds
sub castSetDelay()
    d = m.castLag + m.castTrim
    if d < 0 then d = 0
    if d > 6 then d = 6
    m.castTrim = d - m.castLag
    m.top.castDelay = Int(d * 100 + 0.5) / 100
end sub

function castRoomKey() as string
    ids = castOnIds()
    ids.sort()
    k = ""
    for each id in ids
        k = k + id + "|"
    end for
    return k
end function

sub castSaveTrim()
    reg = CreateObject("roRegistrySection", "hearth")
    reg.Write("castTrim_" + castRoomKey(), m.castTrim.toStr())
    reg.Write("castDelay", m.top.castDelay.toStr())
    reg.Flush()
end sub

' a new set of rooms starts from the trim last used with them
sub castLoadTrim()
    saved = CreateObject("roRegistrySection", "hearth").Read("castTrim_" + castRoomKey())
    if saved <> "" then m.castTrim = Val(saved)
    castSetDelay()
end sub

' Make the speakers match the ticks after a change
sub castApply(before as object, changed as string)
    now = castOnIds()
    if changed <> "tv" and now.count() > 0 then castLoadTrim()
    m.top.castCount = now.count()
    playing = (m.top.queue <> invalid and m.top.queue.count() > 0 and (m.top.state = "playing" or m.top.state = "buffering"))
    ' speakers that were unticked stop
    for each id in before
        if not castHas(now, id)
            ' only a speaker that was grouped with others can be unjoined (a lone one answers 500)
            if before.count() > 1 and m.castNoJoin <> true then haService("media_player", "unjoin", { entity_id: id })
            haService("media_player", "media_stop", { entity_id: id })
        end if
    end for
    if now.count() = 0
        m.castLeader = ""
        m.castClock.control = "stop"
        ' back to the TV alone, from where the speakers were
        if playing and m.audio.state <> "playing" then playIndex(m.top.index, m.top.position)
        return
    end if
    if changed = "tv"
        if castTvOn()
            ' the TV catches up with the speakers
            m.castClock.control = "stop"
            if playing then castStartTv(m.top.position)
        else
            m.audio.control = "stop"
            if playing then castStartClock()
        end if
        return
    end if
    if m.castLeader <> "" and castHas(now, m.castLeader) and before.count() > 0
        ' the group keeps going: new speakers join the leader and pick up mid-song
        joins = []
        for each id in now
            if id <> m.castLeader and not castHas(before, id) then joins.push(id)
        end for
        if joins.count() > 0 and m.castNoJoin <> true then haService("media_player", "join", { entity_id: m.castLeader, group_members: joins }, "join")
        if joins.count() > 0 and m.castNoJoin = true and playing then playIndex(m.top.index)
        return
    end if
    ' a new group (or the leader left): start this song over in every room, in step
    m.castLeader = now[0]
    m.castNoJoin = false
    if now.count() > 1 then castJoin()
    if playing
        ' keep the song going on the TV; the speakers start it and then skip to where the TV is
        m.castFresh = false
        m.castSeekFrom = m.top.position
        m.castSeekClock = CreateObject("roTimespan")
        castPlayTrack("playjoin")
    else
        ' nothing is playing yet: the next Play starts the song in every room
        m.castFresh = true
    end if
end sub

function castHas(list as object, id as string) as boolean
    for each x in list
        if x = id then return true
    end for
    return false
end function

sub castJoin()
    members = []
    for each id in castOnIds()
        if id <> m.castLeader then members.push(id)
    end for
    if members.count() > 0 and m.castNoJoin <> true then haService("media_player", "join", { entity_id: m.castLeader, group_members: members }, "join")
end sub

sub castVolume(id as string, delta as dynamic)
    rooms = m.top.rooms
    for each r in rooms
        if r.id = id and r.kind <> "tv"
            v = r.vol
            if v < 0 then v = 50
            v = v + delta
            if v < 0 then v = 0
            if v > 100 then v = 100
            r.vol = v
            haService("media_player", "volume_set", { entity_id: id, volume_level: v / 100 })
        end if
    end for
    m.top.rooms = rooms
end sub

' ---------- playing ----------
' Called by playIndex while casting: the speakers get the song now, the TV castDelay seconds later.
' Returns true when the speakers were already on this song (queued ahead, so they never wander off
' to a song of Music Assistant's own choosing when the last one ends) and nothing was sent.
function castPlayTrack(tag = "play" as string) as boolean
    tr = m.top.track
    if tr = invalid then return false
    if tag = "play" and m.castAdvanced = true and m.castQueuedId = tr.id and m.castQueuedId <> ""
        m.castQueuedId = ""
        ' the speakers started it about castDelay seconds ago
        castMark(m.top.castDelay * 2)
        return true
    end if
    m.castQueuedId = ""
    if m.castNoJoin = true then targets = castOnIds() else targets = [m.castLeader]
    for each id in targets
        data = { entity_id: id, media_id: tr.title, media_type: "track", enqueue: "replace" }
        if tr.artist <> invalid and tr.artist <> "" then data.artist = tr.artist
        if tr.album <> invalid and tr.album <> "" then data.album = tr.album
        haService("music_assistant", "play_media", data, tag)
    end for
    if tag = "play" then castMark(0)
    return false
end function

' Queue the next song behind this one in Music Assistant, so its own "keep the music going" never
' picks a song when this one ends (the TV, which trails the speakers, would then be sent to the right one a few seconds late)
sub castQueueNext()
    q = m.top.queue
    i = m.top.index + 1
    if q = invalid or i >= q.count() or m.top.repeat <> "off" or m.castLeader = "" then return
    tr = q[i]
    if m.castQueuedId = tr.id then return
    if m.castNoJoin = true then targets = castOnIds() else targets = [m.castLeader]
    for each id in targets
        data = { entity_id: id, media_id: tr.title, media_type: "track", enqueue: "add" }
        if tr.artist <> invalid and tr.artist <> "" then data.artist = tr.artist
        if tr.album <> invalid and tr.album <> "" then data.album = tr.album
        haService("music_assistant", "play_media", data, "queueadd")
    end for
    m.castQueuedId = tr.id
end sub

' The speaker answered play_media: skip it to where the TV is now (plus its start-up delay)
sub castCatchUp(body as string)
    if m.castSeekClock = invalid then return
    req = ParseJson(body)
    if req = invalid or req.entity_id = invalid then return
    at = m.castSeekFrom + m.castSeekClock.TotalMilliseconds() / 1000 + m.top.castDelay
    if m.top.duration > 0 and at > m.top.duration - 2 then return
    haService("media_player", "media_seek", { entity_id: req.entity_id, seek_position: Int(at * 10) / 10 })
    castMark(at)
end sub

' Where the speakers are: we told them to be at pos just now, and they get there castDelay later.
' So at any moment they're at refPos + (time since) - castDelay, and that's where the TV belongs.
sub castMark(atPos as float)
    m.castRefPos = atPos
    m.castRefClock = CreateObject("roTimespan")
    ' a few seconds on, ask Music Assistant where the speakers really are (the delay differs every song)
    m.castPollN = 0
    m.castPollT.duration = 5
    m.castPollT.control = "stop"
    m.castPollT.control = "start"
end sub

sub onCastPoll()
    if m.castLeader = "" or not castActive() then return
    haCall("GET", "/api/states/" + m.castLeader, "", "onCastPos")
end sub

' seconds since 1970 from Home Assistant's "2026-11-23T16:00:00.123456+00:00" (always UTC)
function castIsoSeconds(s as string) as double
    if Len(s) < 19 then return -1
    dt = CreateObject("roDateTime")
    dt.FromISO8601String(Left(s, 19) + "Z")
    sec# = dt.AsSeconds()
    if Mid(s, 20, 1) = "." then sec# = sec# + Val("0" + Mid(s, 20, 7))
    return sec#
end function

sub onCastPos(event as object)
    t = hTaskFrom(event)
    if not t.ok or m.castRefClock = invalid then return
    st = t.response
    if st = invalid or st.state <> "playing" or st.attributes = invalid then return
    castQueueNext()
    a = st.attributes
    if a.media_position = invalid or a.media_position_updated_at = invalid then return
    upd# = castIsoSeconds(pxStr(a.media_position_updated_at))
    if upd# < 0 then return
    dt = CreateObject("roDateTime")
    now# = dt.AsSeconds() + dt.GetMilliseconds() / 1000
    real = a.media_position + (now# - upd#)
    modelled = m.castRefPos + m.castRefClock.TotalMilliseconds() / 1000
    lag = modelled - real
    print "[hearth cast] speakers trail by "; lag
    if lag < 0 or lag > 6 then return
    m.castLag = lag
    castSetDelay()
    castAlign()
    castQueueNext()
    ' once more later, to catch any drift
    m.castPollN = m.castPollN + 1
    if m.castPollN < 2
        m.castPollT.duration = 25
        m.castPollT.control = "start"
    end if
end sub

function castSpeakerPos() as float
    if m.castRefClock = invalid then return -1
    return m.castRefPos + m.castRefClock.TotalMilliseconds() / 1000 - m.top.castDelay
end function

' Seek the TV to where the speakers are now. TV timing presses land here, so the TV moves while you listen.
sub castAlign()
    if not castActive() or not castTvOn() or m.audio.state <> "playing" then return
    at = castSpeakerPos()
    if at < 0.5 then return
    if m.top.duration > 0 and at > m.top.duration - 1 then return
    m.audio.seek = at
end sub

' at = 0: the song is starting everywhere, so the TV waits castDelay seconds for the speakers.
' at > 0: the TV joins mid-song, where the speakers are.

sub castStartTv(at as float)
    c = m.audio.content
    if c = invalid then return
    m.castTimer.control = "stop"
    if at > 0
        spk = castSpeakerPos()
        if spk > 0 then at = spk else at = at - m.top.castDelay + 0.5
        if at < 0.1 then at = 0.1
        m.audio.control = "stop"
        c.playStart = at
        m.audio.control = "play"
    else
        m.top.state = "buffering"
        m.castTimer.duration = m.top.castDelay + 0.01
        m.castTimer.control = "start"
    end if
end sub

sub onCastTimer()
    if castTvOn() then m.audio.control = "play"
end sub

' The TV is quiet: keep time ourselves so the queue moves on when the song ends
sub castStartClock()
    m.top.state = "playing"
    m.castClock.control = "start"
end sub

sub onCastClock()
    if m.top.state <> "playing" then return
    m.top.position = m.top.position + 1
    if m.top.duration > 0 and m.top.position >= m.top.duration
        m.castClock.control = "stop"
        trackFinished()
    end if
end sub

' pause / resume for the speakers (the TV's own audio is handled by the player)
sub castPause(paused as boolean)
    if not castActive() then return
    if m.castNoJoin = true then targets = castOnIds() else targets = [m.castLeader]
    for each id in targets
        if paused then haService("media_player", "media_pause", { entity_id: id }) else haService("media_player", "media_play", { entity_id: id })
    end for
    if not paused then castMark(m.top.position)
    if not castTvOn()
        if paused
            m.castClock.control = "stop"
            m.top.state = "paused"
        else
            castStartClock()
        end if
    end if
end sub

' ---------- lending the TV to a video (the Ambiance hearth) ----------
' tvYield: only the TV's own Audio stops, so a Video node can play. Speakers keep going and the
' player stays "playing" (our clock keeps the position). With no speakers it's a pause.
sub tvYield()
    if m.tvYielded = true then return
    hasQueue = (m.top.queue <> invalid and m.top.queue.count() > 0)
    if not hasQueue then return
    live = (m.top.state = "playing" or m.top.state = "buffering")
    m.tvYielded = true
    m.castTimer.control = "stop"
    if castActive()
        m.audio.control = "stop"
        if live then castStartClock()
    else
        if live then m.audio.control = "pause"
        m.top.state = "paused"
        m.tvYieldResume = live
    end if
end sub

' tvRejoin: the TV picks the song up again where the speakers are (or where it paused)
sub tvRejoin()
    if m.tvYielded <> true then return
    m.tvYielded = false
    if castActive()
        m.castClock.control = "stop"
        if castTvOn() and m.top.state = "playing"
            spk = castSpeakerPos()
            if spk < 0 then spk = m.top.position
            castStartTv(spk + m.top.castDelay)
        end if
    else if m.tvYieldResume = true
        m.tvYieldResume = false
        resume()
    end if
end sub
