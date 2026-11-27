sub init()
    m.top.findNode("title").font = hFont("fell", 52)
    m.sub = m.top.findNode("sub")
    m.sub.font = hFont("regular", 26)
    m.note = m.top.findNode("note")
    m.note.font = hFont("bold", 24)
    m.dyn = m.top.findNode("dyn")
    m.poll = m.top.findNode("poll")
    m.poll.observeField("fire", "refresh")
    m.st = { state: "loading", recent: [] }
    m.items = []
    m.f = 0
    m.code = ""
    m.qr = Rnd(100000).toStr()
end sub

sub onShown(unused as dynamic)
    m.top.setFocus(true)
    checkAgain()
end sub

' first look (and Try again): say we're asking, so the screen isn't blank while the helper answers
sub checkAgain()
    m.st = { state: "loading", recent: [] }
    m.f = 0
    build()
    refresh()
end sub

sub refresh()
    nasCall("GET", "/api/lastfm/status", "", "onStatus", "")
end sub

sub onStatus(event as object)
    t = hTaskFrom(event)
    if not t.ok
        m.st = { state: "unreachable", recent: [] }
    else
        m.st = t.response
        if m.st.recent = invalid then m.st.recent = []
    end if
    reg = CreateObject("roRegistrySection", "hearth")
    if m.st.state = "connected"
        if reg.Read("lastfmOn") <> "1"
            reg.Write("lastfmOn", "1")
            reg.Flush()
            muSend("lfmReload")
        end if
        m.poll.control = "stop"
    else if m.st.state = "waiting"
        m.poll.control = "start"
    else
        m.poll.control = "stop"
        if t.ok and reg.Read("lastfmOn") = "1"
            reg.Write("lastfmOn", "0")
            reg.Flush()
            muSend("lfmReload")
        end if
    end if
    build()
end sub

function lbl(parent as object, x as integer, y as integer, w as integer, text as string, kind as string, size as integer, color as string) as object
    l = parent.createChild("Label")
    l.translation = [x, y]
    l.width = w
    l.font = hFont(kind, size)
    l.color = color
    l.text = text
    return l
end function

sub addStep(n as integer, title as string, desc as string, y as integer, active as boolean)
    c = "0xB5AF8CFF"
    if active then c = "0xE0B34AFF"
    lbl(m.dyn, 100, y, 48, n.toStr(), "bold", 34, c)
    t = "0xEDE6CAFF"
    if not active then t = "0xB5AF8C99"
    lbl(m.dyn, 160, y, 800, title, "bold", 30, t)
    lbl(m.dyn, 160, y + 38, 800, desc, "regular", 24, "0xB5AF8C99")
end sub

function chip(icon as string, text as string, y as integer, action as string, on = false as boolean) as object
    c = m.dyn.createChild("MusicChip")
    c.icon = icon
    c.text = text
    c.big = true
    c.on = on
    c.translation = [100, y]
    m.items.push({ node: c, action: action })
    return c
end function

sub build()
    m.dyn.removeChildrenIndex(m.dyn.getChildCount(), 0)
    m.items = []
    s = m.st
    reg = CreateObject("roRegistrySection", "hearth")
    m.note.text = ""
    if s.state = "loading"
        m.sub.text = "Keep a record of everything you play in Hearth, on the TV and on speakers."
        ic = m.dyn.createChild("Poster")
        ic.uri = "pkg:/images/music/icons/clock.png"
        ic.blendColor = "0xE0B34AFF"
        ic.width = 30
        ic.height = 30
        ic.translation = [100, 335]
        lbl(m.dyn, 146, 330, 900, "Checking with the Hearth helper" + Chr(8230), "regular", 26, "0xB5AF8CFF")
        chip("left", "Back", 420, "back")
    else if s.state = "unreachable"
        m.sub.text = "Hearth can't reach its helper on the NAS (" + nasBase() + ")."
        lbl(m.dyn, 100, 330, 900, "The helper didn" + Chr(8217) + "t answer.", "bold", 26, "0xF0907CFF")
        chip("repeat", "Try again", 420, "retry")
        chip("left", "Back", 520, "back")
    else if s.state = "off" or s.configured = false
        m.sub.text = "The NAS helper needs your free Last.fm API key first. Steps are in tools/remote/README.md: create the key at last.fm/api/account/create, put it in the hearth-remote .env file, and rebuild the container."
        chip("left", "Back", 480, "back")
    else if s.state = "connected"
        m.sub.text = "Connected as " + pxStr(s.user) + ". Everything you play, on the TV or on speakers, is counted."
        castOn = (reg.Read("lastfmCast") <> "0")
        nowOn = (reg.Read("lastfmNow") <> "0")
        loveOn = (reg.Read("lastfmLove") <> "0")
        lbl(m.dyn, 100, 330, 600, "WHAT TO SEND", "caps", 24, "0xE0B34AFF")
        ' each switch says On or Off in words, so focus (gold) and state can't be confused (UX review item 14)
        chip("cast", "Scrobble when casting: " + onOff(castOn), 380, "cast", castOn)
        chip("scrobble", "Tell Last.fm what's playing now: " + onOff(nowOn), 480, "now", nowOn)
        chip("heart", "Love in the * options: " + onOff(loveOn), 580, "love", loveOn)
        chip("left", "Disconnect", 740, "disconnect")
        chip("check", "Done", 840, "back")
        ' today
        lbl(m.dyn, 1140, 190, 680, "Today", "fell", 44, "0xEDE6CAFF")
        lbl(m.dyn, 1140, 262, 680, s.today.toStr() + " scrobbled, " + s.queued.toStr() + " waiting to send", "regular", 24, "0xB5AF8CFF")
        y = 320
        for each e in s.recent
            ic = "check"
            col = "0xE0B34AFF"
            if e.ok <> true
                ic = "clock"
                col = "0xB5AF8CFF"
            end if
            p = m.dyn.createChild("Poster")
            p.uri = "pkg:/images/music/icons/" + ic + ".png"
            p.blendColor = col
            p.width = 30
            p.height = 30
            p.translation = [1140, y + 8]
            lbl(m.dyn, 1190, y, 620, pxStr(e.title), "bold", 28, "0xEDE6CAFF")
            lbl(m.dyn, 1190, y + 38, 620, pxStr(e.artist), "regular", 22, "0xB5AF8CFF")
            y = y + 96
        end for
        if s.recent.Count() = 0 then lbl(m.dyn, 1140, 320, 680, "Nothing yet. Play a song and it appears here.", "regular", 24, "0xB5AF8CFF")
    else
        waiting = (s.state = "waiting")
        if waiting
            m.sub.text = "Keep your phone handy."
        else
            m.sub.text = "Keep a record of everything you play in Hearth, on the TV and on speakers."
        end if
        addStep(1, "Scan with your phone", "Or open " + nasBase() + "/lastfm on any device at home.", 330, waiting)
        addStep(2, "Sign in to Last.fm and allow Hearth", "Your password goes to Last.fm only, never to the TV.", 440, false)
        addStep(3, "Done", "This screen turns to Connected.", 550, false)
        if waiting
            q = m.dyn.createChild("Poster")
            q.uri = nasBase() + "/lastfm/qr.png?x=" + m.qr
            q.translation = [1140, 210]
            q.width = 300
            q.height = 300
            lbl(m.dyn, 1480, 250, 360, "WAITING FOR YOUR PHONE", "caps", 24, "0xE0B34AFF")
            lbl(m.dyn, 1480, 296, 360, "Code " + s.code, "regular", 26, "0xEDE6CAFF")
            chip("phone", "Start again", 660, "begin")
        else
            chip("phone", "Connect Last.fm", 660, "begin")
        end if
        chip("left", "Back", 760, "back")
    end if
    if m.f >= m.items.Count() then m.f = 0
    paint()
end sub

sub paint()
    for i = 0 to m.items.Count() - 1
        m.items[i].node.focused = (i = m.f)
    end for
end sub

sub act(a as string)
    reg = CreateObject("roRegistrySection", "hearth")
    if a = "back"
        m.poll.control = "stop"
        m.top.request = { action: "back" }
    else if a = "begin"
        m.note.text = "Asking Last.fm..."
        nasCall("POST", "/api/lastfm/begin", "{}", "onBegin", "")
    else if a = "retry"
        checkAgain()
    else if a = "disconnect"
        ' re-pairing needs the phone, so ask first
        dlg = CreateObject("roSGNode", "HearthDialog")
        dlg.title = "Disconnect Last.fm?"
        dlg.popup = true
        dlg.message = ["Hearth stops sending what you play. To connect again you'll need your phone."]
        dlg.buttons = ["Disconnect", "Cancel"]
        dlg.observeField("buttonSelected", "onDisconnectPick")
        dlg.observeField("wasClosed", "onMuClosed")
        m.confirm = dlg
        hShowDialog(dlg)
    else if a = "cast" or a = "now" or a = "love"
        key = { cast: "lastfmCast", now: "lastfmNow", love: "lastfmLove" }[a]
        if reg.Read(key) = "0" then reg.Write(key, "1") else reg.Write(key, "0")
        reg.Flush()
        muSend("lfmReload")
        build()
    end if
end sub

sub onBegin(event as object)
    t = hTaskFrom(event)
    if t.ok and t.response.ok = true
        m.qr = Rnd(100000).toStr()
        refresh()
    else
        e = t.response.error
        if e = invalid then e = "The NAS helper didn't answer."
        m.note.text = e
    end if
end sub

sub onDisconnectPick()
    b = m.confirm.buttonSelected
    m.confirm.close = true
    if b = 0
        m.note.text = "Disconnecting..."
        nasCall("POST", "/api/lastfm/disconnect", "{}", "onDisconnected", "")
    end if
end sub

sub onDisconnected(event as object)
    hTaskFrom(event)
    reg = CreateObject("roRegistrySection", "hearth")
    reg.Write("lastfmOn", "0")
    reg.Flush()
    muSend("lfmReload")
    refresh()
end sub

sub muRestoreFocus()
    m.top.setFocus(true)
end sub

function hKeyInner(key as string, press as boolean) as boolean
    if not press then return false
    if muMediaKey(key) then return true
    if key = "back"
        act("back")
    else if key = "up"
        if m.f > 0 then m.f = m.f - 1
    else if key = "down"
        if m.f < m.items.Count() - 1 then m.f = m.f + 1
    else if key = "OK"
        if m.items.Count() > 0 then act(m.items[m.f].action)
    end if
    paint()
    return true
end function

' menu sound for whatever the handler above took (source/util.brs hKeySfx)
function onKeyEvent(key as string, press as boolean) as boolean
    return hKeySfx(key, press, hKeyInner(key, press))
end function

function onOff(v as boolean) as string
    if v then return "On"
    return "Off"
end function
