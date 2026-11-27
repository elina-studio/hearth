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
    ' "[unknown]" is Plex's word for a missing artist: show the album alone instead (UX review item 34)
    artist = hArtist(tr.artist)
    album = hClean(tr.album)
    sub2 = artist
    if album <> ""
        if sub2 <> "" then sub2 = sub2 + "  ·  " + album else sub2 = album
    end if
    e = e + "  ·  " + (p.index + 1).toStr() + " OF " + p.queue.count().toStr()
    if p.liked = "like" then e = e + "  ·  LIKED"
    return { eyebrow: e, title: hClean(tr.title), sub: sub2, track: tr }
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
    m.muB = { labels: [], subs: [], icons: [], kinds: [], pics: [], heads: {} }
    ic = "pkg:/images/music/icons/"
    muHead("Playback")
    if p.shuffle then muAdd("Shuffle: On", "shuffle", "Mix up what is queued", ic + "shuffle.png") else muAdd("Shuffle: Off", "shuffle", "Mix up what is queued", ic + "shuffle.png")
    r = "Off"
    if p.repeat = "all" then r = "All"
    if p.repeat = "one" then r = "One song"
    muAdd("Repeat: " + r, "repeat", "Off, all, or one song", ic + "repeat.png")
    muHead("More like this")
    muAdd("More like this song", "more", "A mix that starts from this song", ic + "wave.png")
    if p.radioOn
        muAdd("Radio options...", "radioMenu", "Steer the radio that is playing", ic + "radio.png")
    else
        muAdd("Start a radio...", "radio", "Pick a mood and let it run", ic + "radio.png")
    end if
    if p.lyricsActive
        muAdd("Lyrics...", "lyricsMenu", "Show, hide or nudge the words", ic + "lyrics.png")
    end if
    ' the right-hand column
    split = m.muB.labels.count()
    if views
        muHead("On screen")
        n = muNow()
        coverPic = ""
        if n.track <> invalid then coverPic = pxImage(n.track.thumb, 360, 240)
        muPic("Cover", "cover", coverPic)
        muPic("Visualizer", "milk", "pkg:/images/music/viz/10.jpg")
        muPic("Hearth fire", "hearth", "pkg:/images/amb/tile-hearth.jpg")
    end if
    muHead("Last.fm")
    muAdd("Love this song", "love", "Saved to your Last.fm loves", ic + "heart.png")
    muAdd("Last.fm...", "lastfm", "Connect it, or see what it sends", ic + "scrobble.png")
    muHead("Library")
    muAdd("Music schedules...", "schedules", "Music that starts by itself", ic + "clock.png")
    libs = p.libraries
    if libs <> invalid and libs.Count() > 1
        muAdd("Library: " + p.sectionName, "library", "Switch between your music libraries", ic + "disc.png")
    end if
    d = CreateObject("roSGNode", "HearthDialog")
    d.title = "Music"
    d.icon = ic + "disc.png"
    n = muNow()
    if n.track <> invalid
        k = "Playing now"
        if p.state <> "playing" and p.state <> "buffering" then k = "Paused"
        d.now = { art: pxImage(n.track.thumb, 208, 208), kicker: k, title: n.title, sub: n.sub }
    else
        d.message = ["Nothing is playing"]
    end if
    b = m.muB
    d.buttons = b.labels
    d.subs = b.subs
    d.icons = b.icons
    d.kinds = b.kinds
    d.pics = b.pics
    d.heads = b.heads
    d.split = split
    d.observeField("buttonSelected", "onMuOption")
    d.observeField("wasClosed", "onMuClosed")
    m.muDialog = d
    hShowDialog(d)
end sub

sub muHead(words as string)
    m.muB.heads[m.muB.labels.count().toStr()] = words
end sub

sub muAdd(caption as string, action as string, line as string, iconUri as string)
    b = m.muB
    b.labels.push(caption)
    b.subs.push(line)
    b.icons.push(iconUri)
    b.kinds.push("")
    b.pics.push("")
    m.muActions.push(action)
end sub

sub muPic(caption as string, action as string, picUri as string)
    b = m.muB
    b.labels.push(caption)
    b.subs.push("")
    b.icons.push("")
    b.kinds.push("pic")
    b.pics.push(picUri)
    m.muActions.push(action)
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
    d = CreateObject("roSGNode", "HearthDialog")
    d.title = title
    d.message = [""]
    d.buttons = labels
    ic = "pkg:/images/music/icons/"
    about = {
        radioNope: [ic + "thumbdown.png", "It stays out of radios for a month"],
        radioCloser: [ic + "collapse.png", "Stay near the song or mood you picked"],
        radioWander: [ic + "expand.png", "Roam further from where it started"],
        radioStop: [ic + "close.png", "Back to your own queue"],
        lyricsToggle: [ic + "lyrics.png", "The words beside the cover"],
        lyricsEarlier: [ic + "left.png", "When the words come in late"],
        lyricsLater: [ic + "right.png", "When the words come in early"],
        close: [ic + "left.png", "Back to the music menu"]
    }
    icons = []
    subs = []
    for each a in actions
        info = about[a]
        if info <> invalid
            icons.push(info[0])
            subs.push(info[1])
        else
            icons.push("")
            subs.push("")
        end if
    end for
    d.icons = icons
    d.subs = subs
    if Left(title, 5) = "Radio" then d.icon = ic + "radio.png" else d.icon = ic + "lyrics.png"
    d.observeField("buttonSelected", "onMuOption")
    d.observeField("wasClosed", "onMuClosed")
    m.muDialog = d
    hShowDialog(d)
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
    else if a = "cover" or a = "milk" or a = "hearth" or a = "request" or a = "radio" or a = "lastfm" or a = "schedules"
        m.top.request = { action: "musicView", mode: a }
    end if
end sub
