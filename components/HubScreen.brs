sub init()
    m.names = ["Home", "Movies", "Shows", "Music", "Requests", "Ambiance", "Photos", "Search"]
    m.pillsGroup = m.top.findNode("pills")
    for each n in m.names
        p = m.pillsGroup.createChild("HearthPill")
        p.text = n
    end for
    m.roomHolder = m.top.findNode("roomHolder")
    m.clock = m.top.findNode("clock")
    m.clock.font = hFont("bold", 40)
    m.weather = m.top.findNode("weather")
    m.weather.font = hFont("regular", 22)
    m.weather.text = "build 9"
    m.clockTimer = m.top.findNode("clockTimer")
    m.clockTimer.observeField("fire", "tick")
    m.clockTimer.control = "start"
    tick()
    m.preview = m.top.findNode("previewTimer")
    m.preview.observeField("fire", "onPreview")

    m.rooms = {}
    m.current = "Home"
    m.pillIndex = 0
    m.zone = "room"
    loadLibraries()
    showRoom("Home", false)
end sub

sub onShown(unused as dynamic)
    room = m.rooms[m.current]
    if room <> invalid then room.callFunc("refresh", invalid)
    if m.zone = "pills"
        m.pillsGroup.getChild(m.pillIndex).setFocus(true)
    else if room <> invalid
        room.callFunc("focusIn", invalid)
    end if
end sub

sub tick()
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    h = dt.GetHours()
    mi = dt.GetMinutes()
    h12 = h mod 12
    if h12 = 0 then h12 = 12
    mm = mi.toStr()
    if mi < 10 then mm = "0" + mm
    m.clock.text = h12.toStr() + ":" + mm
end sub

sub loadLibraries()
    hPlex("libraries", {}, "onLibraries")
end sub

sub onLibraries(event as object)
    t = hTaskFrom(event)
    if not t.ok then return
    libs = {}
    for each v in t.response.Items
        ct = v.CollectionType
        if ct <> invalid and libs[ct] = invalid then libs[ct] = v.Id
    end for
    m.global.libraries = libs
    for each k in m.rooms
        m.rooms[k].callFunc("refresh", invalid)
    end for
end sub

' Build (once) and show a room. focus=false keeps focus on the pills (preview).
sub showRoom(name as string, focus as boolean)
    room = m.rooms[name]
    if room = invalid
        if name = "Home"
            room = CreateObject("roSGNode", "HomeRoom")
        else if name = "Movies" or name = "Shows"
            room = CreateObject("roSGNode", "LibraryRoom")
            if name = "Movies" then room.kind = "movies" else room.kind = "tvshows"
        else if name = "Search"
            room = CreateObject("roSGNode", "SearchRoom")
        else if name = "Requests"
            room = CreateObject("roSGNode", "RequestsRoom")
        else
            room = CreateObject("roSGNode", "PlaceholderRoom")
            room.name = name
        end if
        room.observeField("request", "onRoomRequest")
        m.rooms[name] = room
    end if
    if m.roomHolder.getChildCount() > 0 then m.roomHolder.removeChildIndex(0)
    m.roomHolder.appendChild(room)
    m.shown = name
    room.opacity = 1.0
    if focus
        m.current = name
        m.zone = "room"
        paintPills()
        room.callFunc("focusIn", invalid)
    else
        room.opacity = 0.55
    end if
end sub

sub paintPills()
    for i = 0 to m.pillsGroup.getChildCount() - 1
        p = m.pillsGroup.getChild(i)
        p.current = (m.names[i] = m.current)
        p.focused = (m.zone = "pills" and i = m.pillIndex)
    end for
end sub

sub toPills()
    m.zone = "pills"
    m.pillIndex = indexOf(m.current)
    paintPills()
    m.pillsGroup.getChild(m.pillIndex).setFocus(true)
    room = m.rooms[m.shown]
    if room <> invalid then room.opacity = 0.55
end sub

function indexOf(name as string) as integer
    for i = 0 to m.names.count() - 1
        if m.names[i] = name then return i
    end for
    return 0
end function

sub onPreview()
    if m.zone = "pills" then showRoom(m.names[m.pillIndex], false)
end sub

sub onRoomRequest(event as object)
    r = event.getData()
    if r = invalid then return
    if r.action = "pills"
        toPills()
    else if r.action = "room"
        m.pillIndex = indexOf(r.name)
        showRoom(r.name, true)
        if r.search <> invalid and r.name = "Requests" then m.rooms["Requests"].searchTerm = r.search
    else
        m.top.request = r
    end if
end sub

sub leavePrompt()
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = "Leave Hearth?"
    d.message = [""]
    d.buttons = ["Stay", "Leave"]
    d.observeField("buttonSelected", "onLeave")
    d.observeField("wasClosed", "onLeaveClosed")
    m.dialog = d
    m.top.getScene().dialog = d
end sub

sub onLeave()
    choice = m.dialog.buttonSelected
    m.dialog.close = true
    if choice = 1
        m.top.request = { action: "exit" }
    else
        m.pillsGroup.getChild(m.pillIndex).setFocus(true)
    end if
end sub

sub onLeaveClosed()
    m.pillsGroup.getChild(m.pillIndex).setFocus(true)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if m.zone <> "pills" then return false
    n = m.names.count()
    if key = "left" or key = "right"
        if key = "left" then d = -1 else d = 1
        m.pillIndex = (m.pillIndex + d + n) mod n
        paintPills()
        m.pillsGroup.getChild(m.pillIndex).setFocus(true)
        m.preview.control = "stop"
        m.preview.control = "start"
        return true
    else if key = "down" or key = "OK"
        m.preview.control = "stop"
        showRoom(m.names[m.pillIndex], true)
        return true
    else if key = "back"
        m.preview.control = "stop"
        if m.pillIndex <> 0 or m.current <> "Home" or m.shown <> "Home"
            m.current = "Home"
            m.pillIndex = 0
            showRoom("Home", false)
            paintPills()
            m.pillsGroup.getChild(0).setFocus(true)
        else
            leavePrompt()
        end if
        return true
    else if key = "options"
        d = CreateObject("roSGNode", "StandardMessageDialog")
        d.title = "Hearth"
        d.message = ["Signed in to " + m.global.server]
        d.buttons = ["Close", "Sign out"]
        d.observeField("buttonSelected", "onMenu")
        m.dialog = d
        m.top.getScene().dialog = d
        return true
    end if
    return false
end function

sub onMenu()
    choice = m.dialog.buttonSelected
    m.dialog.close = true
    if choice = 1 then m.top.request = { action: "signOut" } else m.pillsGroup.getChild(m.pillIndex).setFocus(true)
end sub
