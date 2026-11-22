' state: none (nothing queued) | buffering | playing | paused | stopped | ended
sub init()
    m.audio = m.top.findNode("audio")
    m.audio.observeField("state", "onAudioState")
    m.audio.observeField("position", "onPosition")
    m.report = m.top.findNode("report")
    m.report.observeField("fire", "onReport")
    m.original = invalid
    m.errors = 0
    m.pending = invalid
    m.lastId = ""
end sub

sub say(text as string)
    m.top.message = text
end sub

' ---------- commands ----------
sub onCommand()
    c = m.top.command
    if c = invalid or c.cmd = invalid then return
    cmd = c.cmd
    if cmd = "toggle"
        if m.top.queue = invalid or m.top.queue.count() = 0
            shuffleAll()
        else if m.top.state = "playing" or m.top.state = "buffering"
            m.audio.control = "pause"
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
        if m.top.state = "playing" or m.top.state = "buffering" then m.audio.control = "pause"
    else if cmd = "stop"
        m.audio.control = "stop"
    else if cmd = "next"
        skip(1)
    else if cmd = "prev"
        ' like a CD player: back to the top first, then the song before
        if m.top.position > 4 then restart() else skip(-1)
    else if cmd = "restart"
        restart()
    else if cmd = "findLibrary"
        withSection({ tag: "none" })
    else if cmd = "shuffleAll"
        shuffleAll()
    else if cmd = "load"
        load(c.tracks, c.start, c.shuffle = true, c.label)
    else if cmd = "playContainer"
        playContainer(c.kind, c.id, c.shuffle = true, c.label)
    else if cmd = "moreLikeThis"
        moreLikeThis()
    else if cmd = "search"
        searchAndPlay(c)
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
    if m.pending = invalid or m.pending.tag = "none" then m.pending = p
    if m.looking = true then return
    m.looking = true
    pxApi("/library/sections", {}, "onSections")
end sub

sub onSections(event as object)
    t = hTaskFrom(event)
    m.looking = false
    for each d in pxItems(t)
        if d.type = "artist" and m.top.section = "" then m.top.section = pxStr(d.key)
    end for
    if m.top.section = ""
        if t.status <= 0 then say("Can't reach Plex.") else say("Plex has no music library.")
        m.top.busy = false
        return
    end if
    if m.pending <> invalid then runPending(m.pending)
    m.pending = invalid
end sub

sub runPending(p as object)
    if p.tag = "none" then return
    if p.tag = "all" then p.path = "/library/sections/" + m.top.section + "/all"
    m.top.busy = true
    m.label = p.label
    m.shuffleOnLoad = (p.shuffle = true)
    pxApi(p.path, p.query, "onTracks", p.tag)
end sub

sub shuffleAll()
    say("Shuffling your music")
    withSection({ path: "", query: { type: "10", sort: "random", "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "150" }, label: "", tag: "all" })
end sub

sub playContainer(kind as string, id as string, shuffle as boolean, label as dynamic)
    if kind = "album"
        path = "/library/metadata/" + id + "/children"
    else if kind = "artist"
        path = "/library/metadata/" + id + "/allLeaves"
    else if kind = "playlist"
        path = "/playlists/" + id + "/items"
    else
        return
    end if
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
    if t.tag = "search"
        playSearchHit(t)
        return
    end if
    tracks = pxTracks(pxItems(t))
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
    if start = invalid then start = 0
    m.original = invalid
    if shuffle
        tracks = shuffled(tracks)
        start = 0
        m.top.shuffle = true
    else
        m.top.shuffle = false
    end if
    m.top.queue = tracks
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
    timeline("stopped")
    m.top.index = i
    m.top.track = tr
    m.top.position = startAt
    m.top.duration = tr.duration
    c = CreateObject("roSGNode", "ContentNode")
    if startAt > 0 then c.playStart = startAt
    c.url = tr.url
    c.streamFormat = tr.format
    c.title = tr.title
    c.addFields({ artist: tr.artist, album: tr.album })
    m.audio.control = "stop"
    m.audio.content = c
    m.audio.control = "play"
    m.scrobbled = false
end sub

' The TV plays one Audio node at a time; if another one took over while we were paused, start again where we were
sub resume()
    if m.audio.state = "paused"
        m.audio.control = "resume"
    else
        playIndex(m.top.index, m.top.position)
    end if
end sub

sub skip(d as integer)
    q = m.top.queue
    if q = invalid or q.count() = 0
        if d > 0 then shuffleAll()
        return
    end if
    i = m.top.index + d
    if i >= q.count()
        if m.top.repeat = "all" then i = 0 else i = q.count() - 1
    end if
    if i < 0 then i = 0
    playIndex(i)
end sub

sub restart()
    if m.top.queue = invalid or m.top.queue.count() = 0 then return
    if m.top.state = "playing" or m.top.state = "paused"
        m.audio.seek = 0
        if m.top.state = "paused" then m.audio.control = "resume"
    else
        playIndex(m.top.index)
    end if
end sub

sub onAudioState()
    s = m.audio.state
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
        scrobble()
        timeline("stopped")
        q = m.top.queue
        if m.top.repeat = "one"
            playIndex(m.top.index)
        else if m.top.index + 1 < q.count()
            playIndex(m.top.index + 1)
        else if m.top.repeat = "all"
            playIndex(0)
        else
            m.top.state = "ended"
            m.report.control = "stop"
        end if
    else if s = "error"
        m.errors = m.errors + 1
        tr = m.top.track
        name = ""
        if tr <> invalid then name = tr.title
        if m.errors >= 3
            say("The TV can't play these songs (" + m.audio.errorMsg + ").")
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

sub onPosition()
    m.top.position = m.audio.position
    if m.audio.duration > 0 then m.top.duration = m.audio.duration
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
    q = { ratingKey: tr.id, key: "/library/metadata/" + tr.id, state: state, time: Int(m.top.position * 1000).toStr(), duration: Int(m.top.duration * 1000).toStr() }
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
