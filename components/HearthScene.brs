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
    end if
end sub

sub goNext()
    if not m.introDone or m.next = "" then return
    if m.next = "hub" then showHub() else signOut()
end sub

sub onUserChecked(event as object)
    t = hTaskFrom(event)
    ' a 401 means the login is gone; offline or slow still opens the hub, which shows the offline banner
    if t.status = 401 then m.next = "setup" else m.next = "hub"
    goNext()
end sub

sub showHub()
    while m.stack.getChildCount() > 0
        m.stack.removeChildIndex(m.stack.getChildCount() - 1)
    end while
    pushScreen(CreateObject("roSGNode", "HubScreen"))
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
        ' the TV plays one stream at a time: music pauses for video
        m.music.command = { cmd: "pause" }
        s = CreateObject("roSGNode", "PlayerScreen")
        s.resume = (r.resume = true)
        s.item = r.item
        pushScreen(s)
    else if a = "slideshow"
        s = CreateObject("roSGNode", "SlideshowScreen")
        s.albumId = r.albumId
        s.albumName = r.albumName
        pushScreen(s)
    else if a = "mood"
        s = CreateObject("roSGNode", "MoodScreen")
        s.mood = r.mood
        pushScreen(s)
    else if a = "back"
        popScreen()
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

' Outside video, Play, Rewind, Fast forward and Replay always control the music.
function onKeyEvent(key as string, press as boolean) as boolean
    if not press or not hMediaKey(key) then return false
    top = topScreen()
    if top <> invalid and top.subtype() = "PlayerScreen" then return false
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
