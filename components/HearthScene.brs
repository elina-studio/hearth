sub init()
    m.top.backgroundColor = "0x0B0E09FF"
    m.top.backgroundUri = ""
    m.stack = m.top.findNode("stack")
    m.reg = CreateObject("roRegistrySection", "hearth")

    di = CreateObject("roDeviceInfo")
    deviceId = m.reg.Read("deviceId")
    if deviceId = "" or deviceId = invalid
        deviceId = "hearth-" + di.GetRandomUUID()
        m.reg.Write("deviceId", deviceId)
        m.reg.Flush()
    end if
    server = m.reg.Read("server")
    if server = "" or server = invalid then server = "http://192.168.254.41:8096"
    m.global.addFields({ server: server, token: m.reg.Read("token"), userId: m.reg.Read("userId"), deviceId: deviceId, libraries: {} })
    ' Plex: plexToken is the plex.tv account token; plexServer/plexServerToken reach the chosen Plex Media Server
    m.global.addFields({ plexToken: m.reg.Read("plexToken"), plexServer: m.reg.Read("plexServer"), plexServerToken: m.reg.Read("plexServerToken"), plexServerName: m.reg.Read("plexServerName") })
    ' one music player for the whole app, so music carries on from room to room
    m.music = CreateObject("roSGNode", "MusicPlayer")
    m.top.appendChild(m.music)
    m.global.addFields({ music: m.music })
    m.global.observeField("remote", "onRemote")
    m.ribbon = m.top.findNode("ribbon")
    m.music.observeField("track", "onMusicTrack")
    initSfx()
    initWalk()

    ' the lantern intro plays while the saved login is checked
    m.introDone = false
    m.next = ""
    intro = CreateObject("roSGNode", "IntroScreen")
    intro.mode = "intro"
    pushScreen(intro)
    if m.global.plexServer <> "" and m.global.plexServerToken <> ""
        hPlex("check", {}, "onUserChecked")
    else
        m.next = "setup"
        m.warmDone = true
    end if
end sub

sub goNext()
    if not m.introDone or m.next = "" then return
    ' the lantern keeps burning until the rooms have their first data (warmDone), or the time limit below passes
    if m.next = "hub" and not m.warmDone then return
    if m.next = "hub" then showHub() else signOut()
end sub

' Launch warm-up: the Hub is built behind the intro so every room loads its data before the first screen.
' At most 20 seconds in all; if Plex is slow or down the Hub opens anyway.
sub startWarm()
    if m.hub <> invalid then return
    m.warmDone = false
    m.warmClock = CreateObject("roTimespan")
    m.hub = CreateObject("roSGNode", "HubScreen")
    m.hub.observeField("warm", "onWarm")
    t = CreateObject("roSGNode", "Timer")
    t.duration = 20
    t.observeField("fire", "onWarmLimit")
    m.top.appendChild(t)
    t.control = "start"
    m.warmTimer = t
end sub

sub onWarm()
    if m.hub = invalid or not m.hub.warm then return
    print "[hearth] rooms warm after "; m.warmClock.TotalMilliseconds(); " ms"
    m.warmDone = true
    goNext()
end sub

sub onWarmLimit()
    if m.warmDone then return
    print "[hearth] warm-up limit reached, opening anyway"
    m.warmDone = true
    goNext()
end sub

sub onUserChecked(event as object)
    t = hTaskFrom(event)
    ' a 401 means the login is gone; offline or slow still opens the hub, which shows the offline banner
    if t.status = 401 then m.next = "setup" else m.next = "hub"
    ' Preloading is off: a Hub built before it is on screen never gets its posters (builds 81-88 showed placeholders).
    ' Rooms load lazily when opened, as before. startWarm is kept for a later, tested attempt.
    m.warmDone = true
    goNext()
end sub

sub showHub()
    while m.stack.getChildCount() > 0
        m.stack.removeChildIndex(m.stack.getChildCount() - 1)
    end while
    hub = m.hub
    m.hub = invalid
    if m.warmTimer <> invalid then m.warmTimer.control = "stop"
    if hub = invalid then hub = CreateObject("roSGNode", "HubScreen")
    pushScreen(hub)
end sub

sub signOut()
    if m.music <> invalid then m.music.command = { cmd: "stop" }
    for each k in ["plexToken", "plexServer", "plexServerToken", "plexServerName"]
        m.reg.Delete(k)
        m.global[k] = ""
    end for
    m.reg.Flush()
    while m.stack.getChildCount() > 0
        m.stack.removeChildIndex(m.stack.getChildCount() - 1)
    end while
    pushScreen(CreateObject("roSGNode", "SetupScreen"))
end sub

sub pushScreen(screen as object)
    top = topScreen()
    if top <> invalid then top.visible = false
    m.stack.appendChild(screen)
    screen.observeField("request", "onScreenRequest")
    screen.visible = true
    screen.setFocus(true)
    screen.callFunc("onShown", invalid)
end sub

sub popScreen()
    n = m.stack.getChildCount()
    if n <= 1 then return
    m.stack.removeChildIndex(n - 1)
    top = topScreen()
    top.visible = true
    top.setFocus(true)
    top.callFunc("onShown", invalid)
end sub

function topScreen() as object
    n = m.stack.getChildCount()
    if n = 0 then return invalid
    return m.stack.getChild(n - 1)
end function

sub onScreenRequest(event as object)
    handle(event.getData())
end sub

sub onRequest()
    handle(m.top.request)
end sub

' Requests from screens: { action: ..., ... }
sub handle(r as object)
    if r = invalid then return
    a = r.action
    if a = "loggedIn"
        m.reg.Write("plexToken", m.global.plexToken)
        m.reg.Write("plexServer", m.global.plexServer)
        m.reg.Write("plexServerToken", m.global.plexServerToken)
        m.reg.Write("plexServerName", m.global.plexServerName)
        m.reg.Flush()
        showHub()
    else if a = "signOut"
        signOut()
    else if a = "details"
        s = CreateObject("roSGNode", "DetailsScreen")
        s.item = r.item
        pushScreen(s)
    else if a = "play"
        lastFromItem(r.item)
        ' the TV plays one stream at a time: a paused Audio node still holds it, so music stops for video
        m.music.command = { cmd: "stop" }
        ' the next queued episode replaces the player that just finished
        if r.replace = true and topScreen() <> invalid and topScreen().subtype() = "PlayerScreen" then popScreen()
        s = CreateObject("roSGNode", "PlayerScreen")
        s.resume = (r.resume = true)
        if r.queue <> invalid then s.queue = r.queue
        s.item = r.item
        pushScreen(s)
    else if a = "slideshow"
        lastSave({ kind: "photos", albumId: r.albumId, albumName: r.albumName })
        s = CreateObject("roSGNode", "SlideshowScreen")
        s.albumId = r.albumId
        s.albumName = r.albumName
        pushScreen(s)
    else if a = "mood"
        lastSave({ kind: "mood", mood: r.mood })
        s = CreateObject("roSGNode", "MoodScreen")
        s.mood = r.mood
        pushScreen(s)
    else if a = "back"
        popScreen()
    else if a = "room"
        ' the rooms bar on a details page: back to the hub, on that room
        while m.stack.getChildCount() > 1 and topScreen().subtype() <> "HubScreen"
            popScreen()
        end while
        hub = topScreen()
        if hub <> invalid and hub.subtype() = "HubScreen" then hub.callFunc("remoteGo", { go: "room", text: r.name })
    else if a = "musicView" and r.mode = "artist"
        s = CreateObject("roSGNode", "MusicArtistScreen")
        s.artistId = r.artistId
        if r.albumId <> invalid then s.openAlbumId = r.albumId
        pushScreen(s)
        s.callFunc("load", invalid)
    else if a = "musicView" and r.mode = "request"
        s = CreateObject("roSGNode", "LidarrScreen")
        pushScreen(s)
        if r.term <> invalid then s.term = r.term
    else if a = "musicView" and r.mode = "radio"
        pushScreen(CreateObject("roSGNode", "RadioScreen"))
    else if a = "musicView" and r.mode = "lastfm"
        pushScreen(CreateObject("roSGNode", "LastfmScreen"))
    else if a = "musicView" and r.mode = "schedules"
        pushScreen(CreateObject("roSGNode", "ScheduleScreen"))
    else if a = "musicView" and r.mode = "big"
        pushScreen(CreateObject("roSGNode", "MusicBigView"))
    else if a = "musicView"
        s = CreateObject("roSGNode", "MusicView")
        pushScreen(s)
        s.mode = r.mode
    else if a = "playMusic"
        m.music.command = { cmd: "search", kind: r.kind, title: r.title, artist: r.artist }
    else if a = "introDone"
        m.introDone = true
        goNext()
    else if a = "exit"
        m.top.exitApp = true
    end if
end sub

'' Phone remote. Text goes to an open Roku keyboard dialog; the Hearth keyboard listens itself.
' go = "search" or "request" climbs back to the hub and opens that room with the text.
sub onRemote()
    r = m.global.remote
    if r = invalid or r.n = invalid then return
    if Left(r.go, 5) = "walk:"
        walkOpen(Mid(r.go, 6))
        return
    end if
    d = m.top.dialog
    if r.go = "" and d <> invalid and d.subtype() = "StandardKeyboardDialog"
        d.text = r.text
        return
    end if
    if r.go <> "search" and r.go <> "request" then return
    if d <> invalid then d.close = true
    while m.stack.getChildCount() > 1 and topScreen().subtype() <> "HubScreen"
        popScreen()
    end while
    hub = topScreen()
    if hub = invalid or hub.subtype() <> "HubScreen" then return
    hub.callFunc("remoteGo", { go: r.go, text: r.text })
end sub

' Outside video, Play, Rewind, Fast forward and Replay always control the music.
function hKeyInner(key as string, press as boolean) as boolean
    if press and key = "back"
        top = topScreen()
        if top <> invalid and top.subtype() = "MoodScreen"
            top.callFunc("leave", invalid)
            return true
        end if
    end if
    if not press or not hMediaKey(key) then return false
    top = topScreen()
    if top <> invalid and top.subtype() = "PlayerScreen" then return false
    if m.ribbon.shown
        ' second press: go
        m.ribbon.callFunc("hide", invalid)
        if key = "play"
            lastContinue()
            return true
        end if
    else if key = "play" and not musicLive() and lastLoad() <> invalid
        lastShow()
        return true
    end if
    if key = "play"
        m.music.command = { cmd: "toggle" }
    else if key = "fastforward"
        m.music.command = { cmd: "next" }
    else if key = "rewind"
        m.music.command = { cmd: "prev" }
    else
        m.music.command = { cmd: "restart" }
    end if
    return true
end function

' ---------- Continue ribbon (Play with nothing playing) ----------
' registry hearth/last = the last thing played: { kind: video | music | mood | photos, ... }
function musicLive() as boolean
    s = m.music.state
    if s = "playing" or s = "buffering" or s = "paused" then return true
    q = m.music.queue
    return (s = "stopped" and q <> invalid and q.count() > 0)
end function

sub lastSave(d as object)
    m.last = d
    m.reg.Write("last", FormatJson(d))
    m.reg.Flush()
end sub

function lastLoad() as dynamic
    if m.last <> invalid then return m.last
    j = m.reg.Read("last")
    if j = invalid or j = "" then return invalid
    d = ParseJson(j)
    if type(d) <> "roAssociativeArray" then return invalid
    m.last = d
    return d
end function

sub lastFromItem(it as dynamic)
    if it = invalid or it.Id = invalid then return
    if it.Type <> "Episode" and it.Type <> "Movie" then return
    ' Continue itself replays the saved entry: keep it as it is
    if it._cont = true then return
    title = it.Name
    tag = ""
    epName = ""
    if it.Type = "Episode"
        title = it.SeriesName
        tag = "S" + hNum(it.ParentIndexNumber) + " E" + hNum(it.IndexNumber)
        epName = it.Name
    end if
    thumb = ""
    if it._img <> invalid
        if it._img.Thumb <> invalid then thumb = it._img.Thumb else if it._img.Primary <> invalid then thumb = it._img.Primary else if it._img.Backdrop <> invalid then thumb = it._img.Backdrop
    end if
    lastSave({ kind: "video", id: it.Id.toStr(), title: title, tag: tag, epName: epName, thumb: thumb })
end sub


sub onMusicTrack()
    tr = m.music.track
    if tr = invalid or tr.album = invalid or tr.album = "" then return
    lastSave({ kind: "music", album: tr.album, artist: tr.artist, title: tr.title })
end sub

sub lastShow()
    d = lastLoad()
    if d = invalid then return
    info = { kicker: "Continue", title: "", meta: "", thumb: "", pct: 0.0 }
    if d.kind = "video"
        info.kicker = "Continue"
        if d.tag <> invalid and d.tag <> "" then info.kicker = "Continue - " + d.tag
        info.title = d.title
        info.meta = ""
        if d.epName <> invalid then info.meta = d.epName
        if d.thumb <> invalid and d.thumb <> "" then info.thumb = hPlexImage(d.thumb, 320, "Thumb")
        hPlex("item", { id: d.id }, "onLastItem")
    else if d.kind = "music"
        info.kicker = "Continue - music"
        info.title = d.album
        info.meta = d.artist
    else if d.kind = "mood"
        info.kicker = "Continue - ambiance"
        info.title = d.mood
        info.meta = "Back to the room"
    else
        info.kicker = "Continue - photos"
        info.title = d.albumName
        info.meta = "Slideshow"
    end if
    m.ribbon.info = info
    m.ribbon.callFunc("show", invalid)
end sub

' the video's progress arrives after the ribbon is up
sub onLastItem(event as object)
    t = hTaskFrom(event)
    if not t.ok or t.response = invalid or not m.ribbon.shown then return
    it = t.response
    i = m.ribbon.info
    pct = 0.0
    lft = ""
    if it.UserData <> invalid and it.UserData.PlayedPercentage <> invalid then pct = it.UserData.PlayedPercentage
    if it.RunTimeTicks <> invalid and it.RunTimeTicks > 0
        mins = Int(it.RunTimeTicks / 600000000 * (100 - pct) / 100)
        lft = mins.toStr() + " min left"
    end if
    if pct > 0
        if i.meta <> "" then i.meta = lft + " - " + i.meta else i.meta = lft
    end if
    i.pct = pct
    m.ribbon.info = i
end sub

sub lastContinue()
    d = lastLoad()
    if d = invalid then return
    if d.kind = "video"
        handle({ action: "play", item: { Id: d.id, Type: "Movie", Name: d.title, _cont: true }, resume: true })
    else if d.kind = "music"
        m.music.command = { cmd: "search", kind: "album", title: d.album, artist: d.artist }
    else if d.kind = "mood"
        handle({ action: "mood", mood: d.mood })
    else if d.kind = "photos"
        handle({ action: "slideshow", albumId: d.albumId, albumName: d.albumName })
    end if
end sub

' Every key goes through here first: the inner handler, then a menu sound (source/util.brs hKeySfx).
' Arrows nobody handled reach this scene last, so they get the faint dead-end tick.
function onKeyEvent(key as string, press as boolean) as boolean
    handled = hKeyInner(key, press)
    if press and not handled and (key = "up" or key = "down" or key = "left" or key = "right") then hSfx("deadend")
    return hKeySfx(key, press, handled)
end function

' ---------- menu sounds ----------
sub initSfx()
    m.sfxNodes = { move: m.top.findNode("sfxMove"), select: m.top.findNode("sfxSelect"), back: m.top.findNode("sfxBack"), deadend: m.top.findNode("sfxDead") }
    m.sfxClock = CreateObject("roTimespan")
    m.sfxLast = ""
    m.global.addFields({ sfxOn: m.reg.Read("uiSounds") <> "off" })
    m.global.addField("sfx", "string", true)
    m.global.observeField("sfx", "onSfx")
end sub

sub onSfx()
    name = m.global.sfx
    if not m.global.sfxOn then return
    node = m.sfxNodes[name]
    if node = invalid then return
    ' a held arrow repeats fast: one tick every 60 ms is plenty
    if name = m.sfxLast and m.sfxClock.TotalMilliseconds() < 60 then return
    top = topScreen()
    if top <> invalid
        kind = top.subtype()
        ' quiet while a mood or the slideshow fills the screen, and while a video is actually playing
        if kind = "MoodScreen" or kind = "SlideshowScreen" then return
        if kind = "PlayerScreen"
            v = top.findNode("video")
            if v <> invalid and v.state = "playing" then return
        end if
    end if
    m.sfxLast = name
    m.sfxClock.Mark()
    node.control = "play"
end sub

' ---------- walk trace (tools/walk): only when launched with ?walk=1 ----------
' Every 0.4 s, when something changed, one HWALK line: the screen stack, the focus chain, any dialog, the music state.
sub initWalk()
    m.walkLast = ""
    if not m.global.hasField("walk") then return
    if m.global.walk <> true then return
    t = CreateObject("roSGNode", "Timer")
    t.duration = 0.4
    t.repeat = true
    t.observeField("fire", "walkTick")
    m.top.appendChild(t)
    t.control = "start"
    m.walkTimer = t
    print "HWALK trace on"
end sub

sub walkTick()
    stk = ""
    for i = 0 to m.stack.getChildCount() - 1
        stk = stk + m.stack.getChild(i).subtype() + ">"
    end for
    chain = ""
    node = m.top
    n = 0
    while node <> invalid and n < 14
        f = node.focusedChild
        if f = invalid then exit while
        nm = f.subtype()
        if f.id <> "" then nm = nm + "#" + f.id
        chain = chain + nm + ">"
        node = f
        n = n + 1
    end while
    dlg = ""
    d = m.top.dialog
    if d <> invalid
        dlg = d.subtype()
        if d.title <> invalid and d.title <> "" then dlg = dlg + ":" + d.title
    end if
    ms = ""
    if m.music <> invalid and m.music.state <> invalid then ms = m.music.state
    sig = "stack=" + stk + " focus=" + chain + " dialog=" + dlg + " music=" + ms
    if sig <> m.walkLast
        m.walkLast = sig
        print "HWALK "; sig
    end if
end sub

' walk only: open one music screen on top of whatever is showing (radio, lastfm, schedules, big, cover, milk, hearth, request)
sub walkOpen(mode as string)
    if not m.global.hasField("walk") or m.global.walk <> true then return
    print "HWALK open "; mode
    handle({ action: "musicView", mode: mode })
end sub
