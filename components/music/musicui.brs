' Shared bits for MusicRoom and MusicView. The including component defines muRestoreFocus().

function muPlayer() as object
    return m.global.music
end function

sub muSend(cmd as string, extra = invalid as dynamic)
    c = { cmd: cmd }
    if extra <> invalid then c.append(extra)
    muPlayer().command = c
end sub

' Play/Rewind/FastForward/Replay go to the music. Returns true when handled.
function muMediaKey(key as string) as boolean
    if key = "play"
        muSend("toggle")
    else if key = "fastforward"
        muSend("next")
    else if key = "rewind"
        muSend("prev")
    else if key = "replay"
        muSend("restart")
    else
        return false
    end if
    return true
end function

' { eyebrow, title, sub } for whatever is playing
function muNow() as object
    p = muPlayer()
    tr = p.track
    s = p.state
    if tr = invalid or p.queue = invalid or p.queue.count() = 0
        return { eyebrow: "NOTHING QUEUED", title: "Shuffle my music", sub: "Press Play to start a random mix", track: invalid }
    end if
    if s = "playing" then e = "NOW PLAYING" else if s = "buffering" then e = "LOADING" else e = "PAUSED"
    sub2 = tr.artist
    if tr.album <> "" then sub2 = sub2 + "  ·  " + tr.album
    e = e + "  ·  " + (p.index + 1).toStr() + " OF " + p.queue.count().toStr()
    return { eyebrow: e, title: tr.title, sub: sub2, track: tr }
end function

function muRepeatLabel() as string
    r = muPlayer().repeat
    if r = "all" then return "Repeat all"
    if r = "one" then return "Repeat one"
    return "Repeat off"
end function

' The music options sheet (the * key). views: show the Cover/Visualizer/Fire entries too.
sub muOptions(views as boolean)
    p = muPlayer()
    m.muActions = []
    labels = []
    if p.shuffle then labels.push("Shuffle: on") else labels.push("Shuffle: off")
    m.muActions.push("shuffle")
    labels.push(muRepeatLabel()) : m.muActions.push("repeat")
    labels.push("More like this song") : m.muActions.push("more")
    if p.radioOn
        labels.push("Radio...") : m.muActions.push("radioMenu")
    else
        labels.push("Start a radio...") : m.muActions.push("radio")
    end if
    if p.lyricsActive
        labels.push("Lyrics...") : m.muActions.push("lyricsMenu")
    end if
    labels.push("Love on Last.fm") : m.muActions.push("love")
    labels.push("Last.fm...") : m.muActions.push("lastfm")
    labels.push("Music schedules...") : m.muActions.push("schedules")
    libs = p.libraries
    if libs <> invalid and libs.Count() > 1
        labels.push("Library: " + p.sectionName + " (switch)") : m.muActions.push("library")
    end if
    if views
        labels.push("Cover") : m.muActions.push("cover")
        labels.push("Visualizer") : m.muActions.push("milk")
        labels.push("Hearth fire") : m.muActions.push("hearth")
    end if
    labels.push("Close") : m.muActions.push("close")
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = "Music"
    n = muNow()
    d.message = [n.title + "  ·  " + n.sub]
    d.buttons = labels
    d.observeField("buttonSelected", "onMuOption")
    d.observeField("wasClosed", "onMuClosed")
    m.muDialog = d
    m.top.getScene().dialog = d
end sub

sub onMuOption()
    a = m.muActions[m.muDialog.buttonSelected]
    m.muDialog.close = true
    if a = "radioMenu"
        muSubMenu("Radio: " + muPlayer().radioName, ["Not this song (skip it for a month)", "Closer to what I started with", "More adventurous", "Stop the radio", "Back"], ["radioNope", "radioCloser", "radioWander", "radioStop", "close"])
    else if a = "lyricsMenu"
        if muPlayer().lyricsFound
            muSubMenu("Lyrics", ["Hide the lyrics", "Show earlier (-0.5 s)", "Show later (+0.5 s)", "Back"], ["lyricsToggle", "lyricsEarlier", "lyricsLater", "close"])
        else
            muSubMenu("Lyrics", ["Show the lyrics", "Back"], ["lyricsToggle", "close"])
        end if
    else
        muDo(a)
    end if
end sub

sub muSubMenu(title as string, labels as object, actions as object)
    m.muActions = actions
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = title
    d.message = [""]
    d.buttons = labels
    d.observeField("buttonSelected", "onMuOption")
    d.observeField("wasClosed", "onMuClosed")
    m.muDialog = d
    m.top.getScene().dialog = d
end sub

sub onMuClosed()
    muRestoreFocus()
end sub

sub muDo(a as string)
    p = muPlayer()
    if a = "toggle"
        muSend("toggle")
    else if a = "shuffle"
        muSend("setShuffle", { value: not p.shuffle })
    else if a = "repeat"
        muSend("cycleRepeat")
    else if a = "prev" or a = "next"
        muSend(a)
    else if a = "more"
        muSend("moreLikeThis")
    else if a = "library"
        muSend("nextLibrary")
    else if a = "love" or a = "radioNope" or a = "radioStop" or a = "lyricsToggle"
        muSend(a)
    else if a = "radioCloser"
        muSend("radioVariety", { delta: -1 })
    else if a = "radioWander"
        muSend("radioVariety", { delta: 1 })
    else if a = "lyricsEarlier"
        muSend("lyricsNudge", { delta: -0.5 })
    else if a = "lyricsLater"
        muSend("lyricsNudge", { delta: 0.5 })
    else if a = "hearth"
        ' the Ambiance hearth (their own fire clip); the music keeps playing over it
        m.top.request = { action: "mood", mood: "hearth" }
    else if a = "cover" or a = "milk" or a = "request" or a = "radio" or a = "lastfm" or a = "schedules"
        m.top.request = { action: "musicView", mode: a }
    end if
end sub
