' state: none (nothing queued) | buffering | playing | paused | stopped | ended
sub init()
    m.audio = m.top.findNode("audio")
    m.audio.observeField("state", "onAudioState")
    m.audio.observeField("position", "onPosition")
    ' m.out is whatever plays the song right now: the Audio node, or a Video node while a music view
    ' shows pictures with the song in one stream (mixplay.brs)
    m.out = m.audio
    mixInit()
    m.report = m.top.findNode("report")
    ' rapid Next/Previous presses are folded into one change of song (see skip)
    m.skipTimer = m.top.findNode("skipTimer")
    m.skipTimer.observeField("fire", "onSkipSettled")
    m.skipDelta = 0
    m.skipClock = CreateObject("roTimespan")
    m.skipLast = -10000
    m.report.observeField("fire", "onReport")
    m.original = invalid
    m.errors = 0
    m.pending = invalid
    m.lastId = ""
    castInit()
    lfmInit()
    radioInit()
    ' While music plays, keep the TV's screensaver (the lantern) away, just like a video does:
    ' when it took over, the next song didn't start and the album view froze.
    m.awake = CreateObject("roSGNode", "Timer")
    m.awake.repeat = true
    m.awake.duration = 45
    m.awake.observeField("fire", "onStayAwake")
    m.top.observeField("state", "onPlayState")
end sub

sub onPlayState()
    s = m.top.state
    if s = "playing" or s = "buffering"
        if m.awake.control <> "start"
            onStayAwake()
            m.awake.control = "start"
        end if
    else
        m.awake.control = "stop"
    end if
end sub

' counts as a remote press, so the TV's screensaver timer starts over (no network call)
sub onStayAwake()
    pHa("", "", true)
end sub

sub say(text as string)
    m.top.message = text
end sub

' ---------- commands ----------
sub onCommand()
    c = m.top.command
    if c = invalid then return
    if c.cmd = invalid then return
    cmd = c.cmd
    if castCommand(c) then return
    if mixCommand(c) then return
    if queueCommand(c) then return
    ' the TV's screen is lent to a video and no speaker plays: play/pause only decides what happens on tvRejoin
    if m.tvYielded = true and not castActive() and (cmd = "toggle" or cmd = "play" or cmd = "resume" or cmd = "pause")
        m.tvYieldResume = (cmd <> "pause" and not (cmd = "toggle" and m.tvYieldResume = true))
        return
    end if
    ' while speakers play along, pause / resume reach them too
    hasQueue = (m.top.queue <> invalid and m.top.queue.count() > 0)
    if castActive() and hasQueue and (cmd = "toggle" or cmd = "pause" or cmd = "play" or cmd = "resume")
        live = (m.top.state = "playing" or m.top.state = "buffering")
        if live and (cmd = "toggle" or cmd = "pause")
            castPause(true)
            if castTvOn() then m.audio.control = "pause"
            return
        else if m.top.state = "paused" and cmd <> "pause" and m.castFresh = true
            playIndex(m.top.index)
            return
        else if m.top.state = "paused" and cmd <> "pause"
            castPause(false)
            if castTvOn() then resume()
            return
        end if
    end if
    if cmd = "toggle"
        if m.top.queue = invalid or m.top.queue.count() = 0
            shuffleAll()
        else if m.top.state = "playing" or m.top.state = "buffering"
            m.out.control = "pause"
        else if m.top.state = "paused"
            resume()
        else
            playIndex(m.top.index)
        end if
    else if cmd = "play" or cmd = "resume"
        if m.top.queue = invalid or m.top.queue.count() = 0
            shuffleAll()
        else if m.top.state = "paused"
            resume()
        else if m.top.state <> "playing" and m.top.state <> "buffering"
            playIndex(m.top.index)
        end if
    else if cmd = "pause"
        if m.top.state = "playing" or m.top.state = "buffering" then m.out.control = "pause"
    else if cmd = "stop"
        m.out.control = "stop"
    else if cmd = "next"
        skip(1)
    else if cmd = "prev"
        ' like a CD player: back to the top first, then the song before
        if m.top.position > 4 and m.skipDelta = 0 and m.skipClock.TotalMilliseconds() - m.skipLast > 700 then restart() else skip(-1)
    else if cmd = "restart"
        restart()
    else if cmd = "queueTracks"
        enqueue(c.tracks, c.next = true, c.label)
    else if cmd = "queueContainer"
        if c.next = true then tag = "queueNext" else tag = "queueEnd"
        path = containerPath(c.kind, c.id)
        if path <> "" then withSection({ path: path, query: {}, label: c.label, tag: tag })
    else if cmd = "nextLibrary"
        nextLibrary()
    else if cmd = "findLibrary"
        withSection({ tag: "none" })
    else if cmd = "shuffleAll"
        shuffleAll()
    else if cmd = "load"
        m.loadKind = pxStr(c.kind)
        load(c.tracks, c.start, c.shuffle = true, c.label)
    else if cmd = "playContainer"
        playContainer(c.kind, c.id, c.shuffle = true, c.label)
    else if cmd = "moreLikeThis"
        moreLikeThis()
    else if cmd = "search"
        searchAndPlay(c)
    else if cmd = "rate"
        rateTrack(c.value)
    else if cmd = "love"
        lfmLove()
    else if cmd = "lfmReload"
        lfmReload()
    else if cmd = "radioStart"
        radioStart(c)
    else if cmd = "radioStop"
        radioStop()
    else if cmd = "radioNope"
        radioNope()
    else if cmd = "radioVariety"
        radioVariety(c.delta)
    else if cmd = "setShuffle"
        setShuffle(c.value = true)
    else if cmd = "cycleRepeat"
        if m.top.repeat = "off"
            m.top.repeat = "all"
            say("Repeat all")
        else if m.top.repeat = "all"
            m.top.repeat = "one"
            say("Repeat this song")
        else
            m.top.repeat = "off"
            say("Repeat off")
        end if
    end if
end sub

' ---------- loading ----------
' Every Plex fetch first makes sure we know the music library
sub withSection(p as object)
    if m.top.section <> ""
        runPending(p)
        return
    end if
    if not pxReady()
        say("Sign in to Plex first (Settings on the Home pill).")
        return
    end if
    ' a lookup is already on its way: keep the real request it will run
    if m.pending <> invalid and p.tag = "none" then return
    if m.pending = invalid
        m.pending = p
    else if m.pending.tag = "none"
        m.pending = p
    end if
    if m.looking = true then return
    m.looking = true
    pxApi("/library/sections", {}, "onSections")
end sub

sub onSections(event as object)
    t = hTaskFrom(event)
    m.looking = false
    ' Plex uses the music type for audiobooks and podcasts too: prefer the one that's really music,
    ' unless the person picked one (the * menu in the Music room)
    libs = []
    best = invalid
    bestScore = -99
    saved = CreateObject("roRegistrySection", "hearth").Read("musicSection")
    for each d in pxItems(t)
        if d.type = "artist"
            lib = { key: pxStr(d.key), title: pxStr(d.title) }
            libs.push(lib)
            name = LCase(lib.title)
            score = 0
            if Instr(1, name, "music") > 0 then score = score + 2
            for each word in ["book", "podcast", "spoken", "lesson", "course", "language"]
                if Instr(1, name, word) > 0 then score = score - 5
            end for
            if lib.key = saved then score = score + 100
            if score > bestScore
                best = lib
                bestScore = score
            end if
        end if
    end for
    m.top.libraries = libs
    if best <> invalid and m.top.section = ""
        m.top.sectionName = best.title
        m.top.section = best.key
    end if
    print "[hearth music] sections status "; t.status; ", music section: "; m.top.section
    if m.top.section = ""
        if t.status <= 0 then say("Can't reach Plex.") else say("Plex has no music library.")
        m.top.busy = false
        return
    end if
    if m.pending <> invalid then runPending(m.pending)
    m.pending = invalid
end sub

' Switch to the next music-type library and remember the choice
sub nextLibrary()
    libs = m.top.libraries
    if libs = invalid or libs.Count() < 2 then return
    i = 0
    for k = 0 to libs.Count() - 1
        if libs[k].key = m.top.section then i = k
    end for
    lib = libs[(i + 1) mod libs.Count()]
    reg = CreateObject("roRegistrySection", "hearth")
    reg.Write("musicSection", lib.key)
    reg.Flush()
    m.top.sectionName = lib.title
    m.top.section = lib.key
    say("Library: " + lib.title)
end sub

sub runPending(p as object)
    if p.tag = "none" then return
    if p.tag = "all" then p.path = "/library/sections/" + m.top.section + "/all"
    m.top.busy = true
    m.label = p.label
    m.loadKind = p.tag
    m.shuffleOnLoad = (p.shuffle = true)
    t = pxApi(p.path, p.query, "onTracks", p.tag)
    ' two albums picked quickly: only the newest pick may start playing (its label and shuffle flag are the ones kept above)
    if p.tag <> "queueNext" and p.tag <> "queueEnd"
        if m.playLoads = invalid then m.playLoads = {}
        m.playLoads[t.key] = true
        m.playLoadKey = t.key
    end if
end sub

sub saveLastPlay(mode as string, kind as string, id as string, label as string)
    reg = CreateObject("roRegistrySection", "hearth")
    clean = label.Replace("|", " ")
    reg.Write("lastPlay", mode + "|" + kind + "|" + id + "|" + clean)
    reg.Flush()
end sub

sub shuffleAll()
    saveLastPlay("s", "all", "", "Shuffle my music")
    say("Shuffling your music")
    withSection({ path: "", query: { type: "10", sort: "random", "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "150" }, label: "", tag: "all" })
end sub

function containerPath(kind as string, id as string) as string
    if kind = "album" then return "/library/metadata/" + id + "/children"
    if kind = "artist" then return "/library/metadata/" + id + "/allLeaves"
    if kind = "playlist" then return "/playlists/" + id + "/items"
    return ""
end function

' Play next (right after this song) or add to the end of the queue
sub enqueue(tracks as object, nextUp as boolean, label as dynamic)
    if tracks = invalid or tracks.Count() = 0 then return
    q = m.top.queue
    if q = invalid or q.Count() = 0
        load(tracks, 0, false, label)
        return
    end if
    out = []
    for i = 0 to q.Count() - 1
        out.push(q[i])
        if nextUp and i = m.top.index then out.append(tracks)
    end for
    if not nextUp then out.append(tracks)
    m.top.queue = out
    if m.original <> invalid then m.original.append(tracks)
    name = ""
    if label <> invalid then name = label
    if nextUp then say(name + " plays next") else say(name + " added to the queue")
end sub

sub playContainer(kind as string, id as string, shuffle as boolean, label as dynamic)
    path = containerPath(kind, id)
    if path = "" then return
    if label <> invalid and label <> "" then saveLastPlay("c", kind, id, label)
    withSection({ path: path, query: {}, label: label, shuffle: shuffle, tag: kind })
end sub

' Plexamp-style "more like this": songs that sound close to the current one (needs Plex Pass sonic analysis)
sub moreLikeThis()
    tr = m.top.track
    if tr = invalid or tr.id = invalid or tr.id = ""
        say("Play a song first, then ask for more like it.")
        return
    end if
    say("Finding songs like " + tr.title)
    m.seed = tr
    withSection({ path: "/library/metadata/" + tr.id + "/nearest", query: { limit: "60", maxDistance: "0.3" }, label: "Like " + tr.title, tag: "nearest" })
end sub

sub searchAndPlay(c as object)
    q = pxStr(c.title)
    if q = "" then return
    m.want = c
    withSection({ path: "/hubs/search", query: { query: q, limit: "10" }, label: q, tag: "search" })
end sub

sub onTracks(event as object)
    t = hTaskFrom(event)
    m.top.busy = false
    if t.tag = "radioGo"
        radioRefill()
        return
    end if
    if t.tag = "search"
        playSearchHit(t)
        return
    end if
    if m.playLoads <> invalid and m.playLoads[t.key] <> invalid
        m.playLoads.delete(t.key)
        ' an older pick answering late: the newer one wins
        if t.key <> m.playLoadKey then return
    end if
    tracks = pxTracks(pxItems(t))
    if t.tag = "queueNext" or t.tag = "queueEnd"
        enqueue(tracks, t.tag = "queueNext", m.label)
        return
    end if
    if t.tag = "nearest"
        if tracks.count() = 0
            say("Plex has no sonic matches for this song. That needs Plex Pass and sonic analysis.")
            return
        end if
        seed = m.seed
        tracks.unshift(seed)
        load(tracks, 0, false, m.label)
        ' the seed is already playing: keep it going rather than restarting
        return
    end if
    if tracks.count() = 0
        if t.status <= 0 then say("Can't reach Plex.") else say("Nothing to play there.")
        return
    end if
    load(tracks, 0, m.shuffleOnLoad = true, m.label)
end sub

sub playSearchHit(t as object)
    want = m.want
    kind = pxStr(want.kind)
    if kind = "" then kind = "album"
    artist = LCase(pxStr(want.artist))
    hit = invalid
    if t.ok and t.response.MediaContainer <> invalid and t.response.MediaContainer.Hub <> invalid
        for each hub in t.response.MediaContainer.Hub
            if hub.type = kind and hub.Metadata <> invalid
                for each md in hub.Metadata
                    who = LCase(pxStr(md.parentTitle) + " " + pxStr(md.grandparentTitle) + " " + pxStr(md.title))
                    if hit = invalid and (artist = "" or Instr(1, who, artist) > 0) then hit = md
                end for
                if hit = invalid and hub.Metadata.count() > 0 then hit = hub.Metadata[0]
            end if
        end for
    end if
    if hit = invalid
        say("Couldn't find " + pxStr(want.title) + " in Plex.")
        return
    end if
    if kind = "track"
        load([pxTrack(hit)], 0, false, pxStr(hit.title))
    else
        playContainer(kind, pxStr(hit.ratingKey), (kind = "artist"), pxStr(hit.title))
    end if
end sub

sub load(tracks as object, start as dynamic, shuffle as boolean, label as dynamic)
    if tracks = invalid or tracks.count() = 0 then return
    radioDetach()
    if start = invalid then start = 0
    if start < 0 or start >= tracks.count() then start = 0
    m.original = invalid
    if shuffle
        tracks = shuffled(tracks)
        start = 0
        m.top.shuffle = true
    else
        m.top.shuffle = false
    end if
    m.top.queue = tracks
    kind = ""
    if m.loadKind <> invalid then kind = m.loadKind
    name = ""
    if label <> invalid then name = label
    m.top.source = { label: name, kind: kind }
    m.loadKind = ""
    m.errors = 0
    keep = (m.top.track <> invalid and tracks[start].id = m.top.track.id and (m.top.state = "playing" or m.top.state = "paused"))
    if keep
        m.top.index = start
    else
        playIndex(start)
    end if
    if label <> invalid and label <> "" then say("Playing " + label)
end sub

function shuffled(a as object) as object
    out = []
    for each x in a
        out.push(x)
    end for
    for i = out.count() - 1 to 1 step -1
        j = Rnd(i + 1) - 1
        tmp = out[i] : out[i] = out[j] : out[j] = tmp
    end for
    return out
end function

sub setShuffle(on as boolean)
    q = m.top.queue
    if q = invalid or q.count() < 2
        m.top.shuffle = on
        return
    end if
    cur = q[m.top.index]
    if on
        m.original = q
        rest = []
        for i = 0 to q.count() - 1
            if i <> m.top.index then rest.push(q[i])
        end for
        rest = shuffled(rest)
        rest.unshift(cur)
        m.top.queue = rest
        m.top.index = 0
        say("Shuffle on")
    else
        if m.original <> invalid
            m.top.queue = m.original
            for i = 0 to m.original.count() - 1
                if m.original[i].id = cur.id then m.top.index = i
            end for
        end if
        m.original = invalid
        say("Shuffle off")
    end if
    m.top.shuffle = on
end sub

' ---------- playback ----------
sub playIndex(i as integer, startAt = 0 as float)
    q = m.top.queue
    if q = invalid or q.count() = 0 then return
    if i < 0 then i = 0
    if i >= q.count() then i = q.count() - 1
    tr = q[i]
    radioLeaving(tr)
    timeline("stopped")
    m.top.index = i
    m.top.track = tr
    m.top.position = startAt
    m.top.duration = tr.duration
    mixStopVideo()
    c = CreateObject("roSGNode", "ContentNode")
    if startAt > 0 then c.playStart = startAt
    c.url = tr.url
    c.streamFormat = tr.format
    c.title = tr.title
    c.addFields({ artist: tr.artist, album: tr.album })
    m.audio.control = "stop"
    m.audio.content = c
    m.scrobbled = false
    likedFrom(tr)
    if startAt = 0 then lfmTrackStart()
    if castActive()
        ' the speakers start this song now; the TV follows castDelay later, or keeps quiet
        m.castFresh = false
        m.castClock.control = "stop"
        already = castPlayTrack()
        if castTvOn() and already
            ' the speakers are already part-way into this song: the TV jumps in where they are
            castStartTv(m.top.castDelay + 0.5)
        else if castTvOn()
            castStartTv(0)
        else
            castStartClock()
        end if
        return
    end if
    if m.tvYielded = true
        ' a video has the screen: the song waits for tvRejoin
        m.top.state = "paused"
        m.tvYieldResume = true
        return
    end if
    ' a music view wants pictures with the song: ask the NAS for the joined stream (mixplay.brs)
    if mixWanted(tr)
        mixPlay(i, startAt)
        return
    end if
    m.out = m.audio
    m.audio.control = "play"
end sub

' The TV plays one Audio node at a time; if another one took over while we were paused, start again where we were
sub resume()
    if m.mix <> invalid and m.out.isSameNode(m.audio) and mixWanted(m.top.track)
        ' a music view wants the joined stream: start it here instead of the paused Audio
        playIndex(m.top.index, m.top.position)
    else if m.mix <> invalid and m.mix.kind = "viz" and not m.out.isSameNode(m.audio) and m.top.track <> invalid and m.vizFor[m.top.track.id] <> invalid and m.vizFor[m.top.track.id] <> m.mixShownLook
        ' a new look was picked while paused: start the stream with it where the song is
        playIndex(m.top.index, m.top.position)
    else if m.out.state = "paused"
        m.out.control = "resume"
    else
        playIndex(m.top.index, m.top.position)
    end if
end sub

' Next / Previous. The first press acts at once; presses that follow quickly are added up and acted on
' once, 0.4 s after the last one. Starting a song means stopping and reloading the Audio node, a Plex
' report, a Last.fm report, a helper request and several redraws, and doing that on every press of a
' fast run froze the TV until the watchdog switched it off.
sub skip(d as integer)
    now = m.skipClock.TotalMilliseconds()
    if m.skipDelta = 0 and now - m.skipLast > 700
        m.skipLast = now
        skipNow(d)
        return
    end if
    m.skipDelta = m.skipDelta + d
    m.skipLast = now
    m.skipTimer.control = "stop"
    m.skipTimer.control = "start"
end sub

sub onSkipSettled()
    d = m.skipDelta
    m.skipDelta = 0
    m.skipLast = m.skipClock.TotalMilliseconds()
    if d <> 0 then skipNow(d)
end sub

sub skipNow(d as integer)
    q = m.top.queue
    if q = invalid or q.count() = 0
        if d > 0 then shuffleAll()
        return
    end if
    i = m.top.index + d
    if i >= q.count()
        if m.top.repeat = "all"
            i = i mod q.count()
        else if d > 1 and m.top.index + 1 < q.count()
            ' a run of presses past the end: stop on the last song; the next press asks for more
            i = q.count() - 1
        else
            ' Next on the last song: play the first of the "more like this" songs as soon as they arrive
            m.wantNext = true
            m.keepTried = ""
            keepPlaying()
            if m.radio = invalid then m.wantNext = false
            if m.radio <> invalid and not m.radio.busy then radioRefill()
            return
        end if
    end if
    if i < 0 then i = 0
    playIndex(i)
end sub

sub restart()
    if m.top.queue = invalid or m.top.queue.count() = 0 then return
    if castActive()
        playIndex(m.top.index)
    else if not m.out.isSameNode(m.audio)
        ' the joined stream starts where the song started: ask for it again from the top
        playIndex(m.top.index)
    else if m.top.state = "playing" or m.top.state = "paused"
        m.audio.seek = 0
        if m.top.state = "paused" then m.audio.control = "resume"
    else
        playIndex(m.top.index)
    end if
end sub

sub onAudioState()
    if not m.out.isSameNode(m.audio) then return
    outState(m.audio.state, m.audio.errorMsg)
end sub

' what the song's player (Audio, or the Video of a joined stream) is doing
sub outState(s as string, errorMsg as string)
    ' the TV is quiet while speakers play: its audio events don't count
    if castActive() and not castTvOn() then return
    if s = "playing"
        m.errors = 0
        m.top.state = "playing"
        timeline("playing")
        m.report.control = "start"
    else if s = "paused"
        m.top.state = "paused"
        timeline("paused")
    else if s = "buffering"
        m.top.state = "buffering"
    else if s = "finished"
        trackFinished()
    else if s = "error"
        m.errors = m.errors + 1
        tr = m.top.track
        name = ""
        if tr <> invalid then name = tr.title
        if m.errors >= 3
            say("The TV can't play these songs (" + errorMsg + ").")
            m.top.state = "stopped"
            m.report.control = "stop"
        else
            say("Skipped " + name + ": the TV couldn't play it.")
            if m.top.index + 1 < m.top.queue.count() then playIndex(m.top.index + 1) else m.top.state = "stopped"
        end if
    else if s = "stopped"
        if m.top.state <> "buffering" and m.top.state <> "paused" then m.top.state = "stopped"
    end if
end sub

sub trackFinished()
    scrobble()
    timeline("stopped")
    q = m.top.queue
    if m.top.repeat = "one"
        playIndex(m.top.index)
    else if m.top.index + 1 < q.count()
        ' the speakers may already be on the next song (castQueueNext)
        m.castAdvanced = true
        playIndex(m.top.index + 1)
        m.castAdvanced = false
    else if m.top.repeat = "all"
        playIndex(0)
    else
        m.top.state = "ended"
        m.report.control = "stop"
        m.castClock.control = "stop"
        ' the "more like this" songs may still be on their way: start the first when they land
        keepPlaying()
        if m.radio <> invalid then m.wantNext = true
    end if
end sub

sub onPosition()
    if not m.out.isSameNode(m.audio) then return
    m.top.position = m.audio.position
    if m.audio.duration > 0 then m.top.duration = m.audio.duration
    afterPosition()
    mixCheckPending()
end sub

sub afterPosition()
    if not m.scrobbled and m.top.duration > 30 and m.top.position > m.top.duration * 0.9 then scrobble()
end sub

' ---------- tell Plex what we're playing, so Recently played and play counts stay right ----------
sub onReport()
    if m.top.state = "playing" then timeline("playing")
end sub

sub timeline(state as string)
    tr = m.top.track
    if tr = invalid or tr.id = invalid or not pxReady() then return
    if state = "stopped" and m.lastId <> tr.id then return
    m.lastId = tr.id
    ' Plex answers 400 when the time is past the end of the song
    at = m.top.position
    if m.top.duration > 0 and at > m.top.duration then at = m.top.duration
    q = { ratingKey: tr.id, key: "/library/metadata/" + tr.id, state: state, time: Int(at * 1000).toStr(), duration: Int(m.top.duration * 1000).toStr() }
    pxApi("/:/timeline", q, "onReported")
    if state = "stopped" then m.lastId = ""
end sub

sub scrobble()
    if m.scrobbled = true then return
    m.scrobbled = true
    tr = m.top.track
    if tr = invalid or not pxReady() then return
    pxApi("/:/scrobble", { key: tr.id, identifier: "com.plexapp.plugins.library" }, "onReported")
end sub

sub onReported(event as object)
    hTaskFrom(event)
end sub

' ---------- like / dislike: saved as the song's Plex rating (Plexamp-style: like = 10, dislike = 2; pressing again clears) ----------
sub likedFrom(tr as object)
    r = tr.rating
    v = ""
    if r <> invalid and r >= 8 then v = "like"
    if r <> invalid and r > 0 and r <= 2 then v = "dislike"
    m.top.liked = v
end sub

sub rateTrack(which as dynamic)
    tr = m.top.track
    if tr = invalid or tr.id = invalid or tr.id = "" then return
    if not pxReady()
        say("Sign in to Plex first.")
        return
    end if
    cur = m.top.liked
    if which = cur
        newRating = -1
        newState = ""
    else if which = "like"
        newRating = 10
        newState = "like"
    else
        newRating = 2
        newState = "dislike"
    end if
    pxApi("/:/rate", { key: tr.id, identifier: "com.plexapp.plugins.library", rating: newRating.toStr() }, "onRated", "", "PUT")
    q = m.top.queue
    if q <> invalid and m.top.index < q.Count()
        if newRating < 0 then q[m.top.index].rating = 0 else q[m.top.index].rating = newRating
    end if
    m.top.liked = newState
    if newState = "like"
        say("Liked " + tr.title)
    else if newState = "dislike"
        ' a dislike is also "not this one": skip it and keep it out for a month (as in the radio)
        radioNope()
    else
        say("Rating cleared")
    end if
end sub

sub onRated(event as object)
    hTaskFrom(event)
end sub
