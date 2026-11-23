' Last.fm scrobbling. Included by MusicPlayer. The NAS helper (tools/remote) holds the Last.fm session and does the real
' sending, so a failed send here only means the NAS wasn't reachable. Rules (Last.fm's): the song is longer than 30 s and
' was heard for half its length or 4 minutes, whichever comes first; the time stamp is when it started.
' lfmState: off | idle (playing, not counted yet) | now (now-playing sent) | counted | queued (NAS unreachable, will retry)
' Works the same when speakers play along: the clock that drives position is the same either way.
' Registry hearth/: lastfmOn "1" once connected, lastfmCast "0" to skip speaker plays, lastfmNow "0" to skip now-playing,
' lastfmLove "0" to hide the Love entry.

sub lfmInit()
    m.lfmPending = []
    m.lfmListen = 0.0
    m.lfmLastPos = -1.0
    m.lfmCounted = false
    m.lfmStart = 0
    lfmReload()
    m.top.observeField("position", "lfmTick")
end sub

sub lfmReload()
    reg = CreateObject("roRegistrySection", "hearth")
    m.lfmOn = (reg.Read("lastfmOn") = "1")
    m.lfmCast = (reg.Read("lastfmCast") <> "0")
    m.lfmNowOn = (reg.Read("lastfmNow") <> "0")
    if m.lfmOn then m.top.lfmState = "idle" else m.top.lfmState = "off"
end sub

function lfmAllowed() as boolean
    if not m.lfmOn then return false
    if castActive() and not m.lfmCast then return false
    return true
end function

function lfmBody(kind as string, tr as object, ts as integer) as string
    return FormatJson({ type: kind, artist: tr.artist, title: tr.title, album: tr.album, duration: Int(tr.duration), ts: ts })
end function

' a new song begins (playIndex from the top, not a resume)
sub lfmTrackStart()
    m.lfmListen = 0.0
    m.lfmLastPos = -1.0
    m.lfmCounted = false
    m.lfmStart = CreateObject("roDateTime").AsSeconds()
    if not m.lfmOn then return
    m.top.lfmState = "idle"
    ' resend anything the NAS missed earlier
    old = m.lfmPending
    m.lfmPending = []
    for each body in old
        nasCall("POST", "/api/lastfm/event", body, "onLfmDone", "retry:" + body)
    end for
    tr = m.top.track
    if tr = invalid or not lfmAllowed() or not m.lfmNowOn then return
    nasCall("POST", "/api/lastfm/event", lfmBody("now", tr, m.lfmStart), "onLfmDone", "now")
end sub

sub lfmTick()
    cur = m.top.position
    if m.top.state = "playing" and m.lfmLastPos >= 0
        d = cur - m.lfmLastPos
        if d > 0 and d < 3 then m.lfmListen = m.lfmListen + d
    end if
    m.lfmLastPos = cur
    if m.lfmCounted or not m.lfmOn then return
    dur = m.top.duration
    if dur <= 30 then return
    need = dur / 2
    if need > 240 then need = 240
    if m.lfmListen < need then return
    tr = m.top.track
    if tr = invalid or not lfmAllowed() then return
    m.lfmCounted = true
    body = lfmBody("scrobble", tr, m.lfmStart)
    nasCall("POST", "/api/lastfm/event", body, "onLfmDone", "scrobble:" + body)
end sub

sub lfmLove()
    tr = m.top.track
    if tr = invalid or tr.title = invalid then return
    if not m.lfmOn
        say("Connect Last.fm first (the * options sheet).")
        return
    end if
    nasCall("POST", "/api/lastfm/event", lfmBody("love", tr, 0), "onLfmDone", "love")
end sub

sub onLfmDone(event as object)
    t = hTaskFrom(event)
    tag = t.tag
    ok = (t.ok and t.response.ok = true)
    if Left(tag, 9) = "scrobble:" or Left(tag, 6) = "retry:"
        body = Mid(tag, Instr(1, tag, ":") + 1)
        if ok
            m.top.lfmState = "counted"
            say("Scrobbled to Last.fm")
        else if t.response.error = "not connected"
            m.top.lfmState = "off"
            say("Last.fm isn't connected any more. Connect it again in the * options.")
        else
            if m.lfmPending.Count() < 20 then m.lfmPending.push(body)
            m.top.lfmState = "queued"
        end if
    else if tag = "now"
        if ok and not m.lfmCounted then m.top.lfmState = "now"
    else if tag = "love"
        if ok then say("Loved on Last.fm") else say("Couldn't reach Last.fm.")
    end if
end sub
