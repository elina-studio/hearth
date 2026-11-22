sub init()
    m.step = m.top.findNode("step")
    m.step.font = hFont("caps", 30)
    m.heading = m.top.findNode("heading")
    m.heading.font = hFont("caps", 84)
    m.body = m.top.findNode("body")
    m.body.font = hFont("regular", 32)
    m.big = m.top.findNode("big")
    m.big.font = hFont("bold", 120)
    m.buttons = m.top.findNode("buttons")
    m.error = m.top.findNode("error")
    m.error.font = hFont("regular", 28)
    m.poll = m.top.findNode("poll")
    m.poll.observeField("fire", "pollPin")
    m.btnIndex = 0
    m.actions = []
    m.pinId = invalid
    newPin()
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

' ---------- step 1: link code ----------
sub newPin()
    m.poll.control = "stop"
    m.step.text = "SETUP · 1 OF 2"
    m.heading.text = "SIGN IN WITH PLEX"
    m.body.text = "On your phone or computer, go to plex.tv/link and enter this code."
    m.big.text = "…"
    m.error.text = ""
    setButtons([{ label: "New code", action: "newPin" }])
    hPlex("pin.create", {}, "onPin")
end sub

sub onPin(event as object)
    t = hTaskFrom(event)
    r = t.response
    if not t.ok or r = invalid or r.code = invalid
        m.big.text = ""
        m.error.text = "Can't reach plex.tv. Check the TV is online, then press OK for a new code."
        return
    end if
    m.pinId = r.id
    m.big.text = UCase(r.code)
    m.poll.control = "start"
end sub

sub pollPin()
    if m.pinId = invalid then return
    hPlex("pin.check", { id: m.pinId }, "onPinChecked")
end sub

sub onPinChecked(event as object)
    t = hTaskFrom(event)
    if t.status = 404
        ' codes expire after a while
        newPin()
        return
    end if
    r = t.response
    if t.ok and r <> invalid and r.authToken <> invalid and r.authToken <> ""
        m.poll.control = "stop"
        m.global.plexToken = r.authToken
        findServer()
    end if
end sub

' ---------- step 2: find the server ----------
sub findServer()
    m.step.text = "SETUP · 2 OF 2"
    m.heading.text = "FINDING YOUR SERVER"
    m.body.text = "Looking for your Plex server on this network…"
    m.big.text = ""
    m.error.text = ""
    setButtons([])
    hPlex("servers", { token: m.global.plexToken }, "onServer")
end sub

sub onServer(event as object)
    t = hTaskFrom(event)
    r = t.response
    if not t.ok or r = invalid or r.url = invalid
        m.heading.text = "NO SERVER FOUND"
        m.body.text = "Signed in, but no Plex server answered from this TV. Make sure Plex Media Server is running, then try again."
        setButtons([{ label: "Try again", action: "findServer" }, { label: "Use another account", action: "newPin" }])
        return
    end if
    m.global.plexServer = r.url
    m.global.plexServerToken = r.token
    m.global.plexServerName = r.name
    m.top.request = { action: "loggedIn" }
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    n = m.actions.count()
    if key = "left" and m.btnIndex > 0
        m.btnIndex = m.btnIndex - 1
        paintButtons()
    else if key = "right" and m.btnIndex < n - 1
        m.btnIndex = m.btnIndex + 1
        paintButtons()
    else if key = "OK" and n > 0
        a = m.actions[m.btnIndex]
        if a = "newPin" then newPin()
        if a = "findServer" then findServer()
    else if key = "back"
        return false
    end if
    return true
end function
