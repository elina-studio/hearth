sub init()
    m.step = m.top.findNode("step")
    m.step.font = hFont("caps", 30)
    m.heading = m.top.findNode("heading")
    m.heading.font = hFont("caps", 84)
    m.body = m.top.findNode("body")
    m.body.font = hFont("regular", 32)
    m.big = m.top.findNode("big")
    m.big.font = hFont("bold", 96)
    m.buttons = m.top.findNode("buttons")
    m.error = m.top.findNode("error")
    m.error.font = hFont("regular", 28)
    m.poll = m.top.findNode("poll")
    m.poll.observeField("fire", "pollQuickConnect")
    m.btnIndex = 0
    m.actions = []
    showServerStep()
end sub

sub onShown(unused as dynamic)
end sub

sub setButtons(list as object)
    m.buttons.removeChildrenIndex(m.buttons.getChildCount(), 0)
    m.actions = []
    for each b in list
        p = m.buttons.createChild("HearthPill")
        p.button = true
        p.text = b.label
        m.actions.push(b.action)
    end for
    m.btnIndex = 0
    paintButtons()
end sub

sub paintButtons()
    for i = 0 to m.buttons.getChildCount() - 1
        m.buttons.getChild(i).focused = (i = m.btnIndex)
    end for
end sub

sub showServerStep()
    m.poll.control = "stop"
    m.step.text = "SETUP · 1 OF 2"
    m.heading.text = "YOUR JELLYFIN SERVER"
    m.body.text = "Hearth will connect to this address. Change it if your server moved."
    m.big.text = m.global.server
    m.error.text = ""
    setButtons([{ label: "Connect", action: "connect" }, { label: "Change address", action: "editServer" }])
end sub

sub connect()
    m.error.text = "Connecting…"
    hApi("GET", "/System/Info/Public", {}, invalid, "onServerInfo")
end sub

sub onServerInfo(event as object)
    t = hTaskFrom(event)
    if not t.ok
        m.error.text = "Can't reach " + m.global.server + ". Check the address starts with http:// and ends with :8096."
        return
    end if
    m.error.text = ""
    startQuickConnect()
end sub

sub startQuickConnect()
    m.step.text = "SETUP · 2 OF 2"
    m.heading.text = "SIGN IN WITH QUICK CONNECT"
    m.body.text = "On your Mac, open Jellyfin, go to your profile, choose Quick Connect and enter this code."
    m.big.text = "…"
    setButtons([{ label: "Use a password instead", action: "password" }, { label: "Back", action: "server" }])
    hApi("POST", "/QuickConnect/Initiate", {}, invalid, "onInitiate")
end sub

sub onInitiate(event as object)
    t = hTaskFrom(event)
    r = t.response
    if not t.ok or r.Secret = invalid
        m.big.text = ""
        m.error.text = "Quick Connect is turned off on the server. Use a password, or turn it on in Jellyfin's dashboard (General settings)."
        return
    end if
    m.secret = r.Secret
    code = r.Code
    if Len(code) = 6 then code = Left(code, 3) + " " + Right(code, 3)
    m.big.text = code
    m.poll.control = "start"
end sub

sub pollQuickConnect()
    if m.secret = invalid then return
    hApi("GET", "/QuickConnect/Connect", { secret: m.secret }, invalid, "onPoll")
end sub

sub onPoll(event as object)
    t = hTaskFrom(event)
    if t.ok and t.response.Authenticated = true
        m.poll.control = "stop"
        hApi("POST", "/Users/AuthenticateWithQuickConnect", {}, { Secret: m.secret }, "onAuthenticated")
    end if
end sub

sub onAuthenticated(event as object)
    t = hTaskFrom(event)
    r = t.response
    if t.ok and r.AccessToken <> invalid and r.User <> invalid
        m.global.token = r.AccessToken
        m.global.userId = r.User.Id
        m.top.request = { action: "loggedIn" }
    else
        m.error.text = "Sign-in failed (" + t.status.toStr() + "). Try again."
    end if
end sub

' ---------- keyboard dialogs ----------
sub askText(title as string, text as string, secure as boolean, cb as string)
    d = CreateObject("roSGNode", "StandardKeyboardDialog")
    d.title = title
    d.text = text
    d.buttons = ["OK", "Cancel"]
    if secure then d.textEditBox.secureMode = true
    d.observeField("buttonSelected", cb)
    m.top.getScene().dialog = d
    m.dialog = d
end sub

sub closeDialog()
    if m.dialog <> invalid then m.dialog.close = true
    m.dialog = invalid
    m.top.setFocus(true)
end sub

sub onServerEntered()
    if m.dialog.buttonSelected = 0
        s = m.dialog.text.trim()
        if s.right(1) = "/" then s = s.left(Len(s) - 1)
        if Left(LCase(s), 4) <> "http" then s = "http://" + s
        m.global.server = s
        m.big.text = s
    end if
    closeDialog()
end sub

sub onUsername()
    if m.dialog.buttonSelected = 0
        m.username = m.dialog.text
        closeDialog()
        askText("Password", "", true, "onPassword")
        return
    end if
    closeDialog()
end sub

sub onPassword()
    if m.dialog.buttonSelected = 0
        pw = m.dialog.text
        closeDialog()
        m.error.text = "Signing in…"
        hApi("POST", "/Users/AuthenticateByName", {}, { Username: m.username, Pw: pw }, "onAuthenticated")
        return
    end if
    closeDialog()
end sub

sub runAction(a as string)
    if a = "connect"
        connect()
    else if a = "editServer"
        askText("Server address", m.global.server, false, "onServerEntered")
    else if a = "password"
        m.poll.control = "stop"
        askText("Jellyfin username", "", false, "onUsername")
    else if a = "server"
        showServerStep()
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    n = m.buttons.getChildCount()
    if key = "left" and m.btnIndex > 0
        m.btnIndex = m.btnIndex - 1
        paintButtons()
        return true
    else if key = "right" and m.btnIndex < n - 1
        m.btnIndex = m.btnIndex + 1
        paintButtons()
        return true
    else if key = "OK"
        runAction(m.actions[m.btnIndex])
        return true
    else if key = "back"
        if m.step.text = "SETUP · 2 OF 2"
            showServerStep()
            return true
        end if
        return false
    end if
    return false
end function
