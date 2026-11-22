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
    muDo(a)
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
    else if a = "cover" or a = "milk" or a = "hearth" or a = "request"
        m.top.request = { action: "musicView", mode: a }
    end if
end sub
