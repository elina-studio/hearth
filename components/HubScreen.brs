sub init()
    m.names = ["Home", "Shows", "Movies", "Music", "Requests", "Ambiance", "Photos", "Search"]
    m.pillsGroup = m.top.findNode("pills")
    ' x and width of each pre-rendered label PNG (2px side padding), from the whimsy spec
    m.tabX = [100, 240, 398, 570, 719, 931, 1152, 1324]
    m.tabW = [101, 120, 133, 110, 174, 182, 134, 136]
    for i = 0 to m.names.count() - 1
        p = m.pillsGroup.createChild("Poster")
        p.translation = [m.tabX[i], 42]
        p.width = m.tabW[i]
        p.height = 44
        p.loadDisplayMode = "noScale"
    end for
    m.flyGlow = m.top.findNode("flyGlow")
    m.flyMain = m.top.findNode("flyMain")
    m.flyFriend1 = m.top.findNode("flyFriend1")
    m.flyFriend2 = m.top.findNode("flyFriend2")
    m.flyMove = m.top.findNode("flyMove")
    m.flyTo = m.top.findNode("flyTo")
    m.friendsIn = m.top.findNode("friendsIn")
    m.flyAt = -1
    m.settledAt = -1
    m.roomHolder = m.top.findNode("roomHolder")
    m.clock = m.top.findNode("clock")
    m.clock.font = hFont("clock", 54)
    m.clockFly = m.top.findNode("clockFly")
    m.weather = m.top.findNode("weather")
    m.weather.font = hFont("book", 26)
    m.wxIcon = m.top.findNode("wxIcon")
    m.buildTag = m.top.findNode("buildTag")
    m.buildTag.font = hFont("regular", 16)
    m.buildTag.text = "build " + CreateObject("roAppInfo").GetValue("build_version")
    ' weather from Home Assistant (same settings as the photo slideshow), refreshed every 15 minutes
    wt = m.top.findNode("weatherTimer")
    wt.observeField("fire", "loadWeather")
    wt.control = "start"
    loadWeather()
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
    paintPills()
end sub

sub onShown(unused as dynamic)
    room = m.rooms[m.current]
    if room <> invalid then room.callFunc("refresh", invalid)
    if m.zone = "pills"
        m.pillsGroup.getChild(m.pillIndex).setFocus(true)
    else if room <> invalid
        ' coming back from a screen: keep the place the room had (Home otherwise jumps to its first button)
        room.callFunc("focusIn", { keep: true })
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
    ' right-align to 1824 by measuring, so the firefly can sit just left of the time
    w = m.clock.localBoundingRect().width
    m.clock.translation = [1824 - w, 12]
    m.clockFly.translation = [1824 - w - 34, 40]
end sub

' Lays out the weather line: icon, then text, right-aligned to 1824
sub layoutWeather()
    w = m.weather.localBoundingRect().width
    m.weather.translation = [1824 - w, 96]
    m.wxIcon.translation = [1824 - w - 38, 100]
    m.wxIcon.visible = (m.weather.text <> "" and m.wxIcon.uri <> "")
end sub

' Home Assistant condition to one of the eight clock icons
function wxIconFor(s as string) as string
    k = "cloudy"
    if s = "sunny" then k = "clear"
    if s = "clear-night" then k = "night"
    if s = "partlycloudy" then k = "partlycloudy"
    if s = "rainy" or s = "pouring" or s = "snowy-rainy" then k = "rain"
    if s = "snowy" or s = "hail" then k = "snow"
    if s = "fog" then k = "fog"
    if s = "lightning" or s = "lightning-rainy" then k = "storm"
    return "pkg:/images/clock/w-" + k + ".png"
end function

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
        else if name = "Music"
            room = CreateObject("roSGNode", "MusicRoom")
        else if name = "Photos"
            room = CreateObject("roSGNode", "PhotosRoom")
        else if name = "Ambiance"
            room = CreateObject("roSGNode", "AmbianceRoom")
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
    ci = indexOf(m.current)
    for i = 0 to m.pillsGroup.getChildCount() - 1
        p = m.pillsGroup.getChild(i)
        state = "dim"
        if i = ci then state = "current"
        if m.zone = "pills" and i = m.pillIndex then state = "focused"
        p.uri = "pkg:/images/w/room-" + LCase(m.names[i]) + "-" + state + ".png"
    end for
    ' the settled room: glow plus two small friends (they fade in when a room is entered)
    left = m.tabX[ci] + 2
    right = m.tabX[ci] + m.tabW[ci] - 2
    m.flyGlow.translation = [left - 24, 34]
    m.flyGlow.width = right - left + 48
    if m.zone = "pills" and m.pillIndex <> ci then m.flyGlow.opacity = 0.6 else m.flyGlow.opacity = 1.0
    m.flyFriend1.translation = [right - 10, 19]
    m.flyFriend2.translation = [left - 36, 55]
    if m.settledAt <> ci
        m.settledAt = ci
        m.friendsIn.control = "stop"
        m.flyFriend1.opacity = 0
        m.flyFriend2.opacity = 0
        m.friendsIn.control = "start"
    end if
    ' one firefly: under the focused label on the bar, else under the settled room
    fi = ci
    if m.zone = "pills" then fi = m.pillIndex
    target = [m.tabX[fi] + Int(m.tabW[fi] / 2) - 32, 64]
    if m.flyAt < 0
        m.flyMain.translation = target
    else if m.flyAt <> fi
        m.flyMove.control = "stop"
        m.flyTo.keyValue = [m.flyMain.translation, target]
        m.flyMove.control = "start"
    end if
    m.flyAt = fi
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

'' Phone remote: { go: "search" | "request", text }
sub remoteGo(r as object)
    if r.go = "room"
        ' from the rooms bar on a details page: text is the room name
        showRoom(r.text, true)
        m.pillIndex = indexOf(r.text)
        paintPills()
    else if r.go = "request"
        showRoom("Requests", true)
        m.pillIndex = indexOf("Requests")
        paintPills()
        if r.text <> "" then m.rooms["Requests"].searchTerm = r.text
    else
        showRoom("Search", true)
        m.pillIndex = indexOf("Search")
        paintPills()
        kb = m.rooms["Search"].findNode("kb")
        if kb <> invalid then kb.text = r.text
    end if
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

sub loadWeather()
    c = pCfg()
    if c.haToken = ""
        m.weather.text = ""
        layoutWeather()
        return
    end if
    pHa("/api/states/" + c.haEntity, "onWeather")
end sub

sub onWeather(event as object)
    t = pTaskFrom(event)
    if not t.ok or t.response.state = invalid then return
    s = pWeatherWord(t.response.state)
    s = UCase(Left(s, 1)) + Mid(s, 2)
    a = t.response.attributes
    if a <> invalid and a.temperature <> invalid then s = s + ", " + Int(a.temperature + 0.5).toStr() + "°"
    m.wxIcon.uri = wxIconFor(t.response.state)
    m.weather.text = s
    layoutWeather()
end sub
