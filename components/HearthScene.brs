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

    ' the lantern intro plays while the saved login is checked
    m.introDone = false
    m.next = ""
    intro = CreateObject("roSGNode", "IntroScreen")
    intro.mode = "intro"
    pushScreen(intro)
    if m.global.token <> "" and m.global.userId <> ""
        hApi("GET", "/Users/" + m.global.userId, {}, invalid, "onUserChecked")
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
    m.reg.Delete("token")
    m.reg.Delete("userId")
    m.reg.Flush()
    m.global.token = ""
    m.global.userId = ""
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
        m.reg.Write("server", m.global.server)
        m.reg.Write("token", m.global.token)
        m.reg.Write("userId", m.global.userId)
        m.reg.Flush()
        showHub()
    else if a = "signOut"
        signOut()
    else if a = "details"
        s = CreateObject("roSGNode", "DetailsScreen")
        s.item = r.item
        pushScreen(s)
    else if a = "play"
        s = CreateObject("roSGNode", "PlayerScreen")
        s.resume = (r.resume = true)
        s.item = r.item
        pushScreen(s)
    else if a = "back"
        popScreen()
    else if a = "introDone"
        m.introDone = true
        goNext()
    else if a = "exit"
        m.top.exitApp = true
    end if
end sub
