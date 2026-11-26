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
    m.warmHolder = m.top.findNode("warmHolder")
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
    initChip()

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
    ' the first time the hub appears the rooms were just warmed up: don't fetch it all a second time
    if m.shownOnce = invalid and m.top.warm
        m.shownOnce = true
    else if room <> invalid
        room.callFunc("refresh", invalid)
    end if
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
    if m.npChip <> invalid then layoutChip()
end sub

' ---------- now playing chip: display only, left of the clock ----------
sub initChip()
    m.npChip = m.top.findNode("npChip")
    m.npBack = m.top.findNode("npBack")
    m.npArt = m.top.findNode("npArt")
    m.npArtBack = m.top.findNode("npArtBack")
    m.npTitle = m.top.findNode("npTitle")
    m.npTitle.font = hFont("bold", 20)
    m.npArtist = m.top.findNode("npArtist")
    m.npArtist.font = hFont("regular", 16)
    m.npBars = m.top.findNode("npBars")
    m.npPulse = m.top.findNode("npPulse")
    m.npThumb = ""
    m.npArt.observeField("loadStatus", "onChipArt")
    mp = m.global.music
    if mp <> invalid
        mp.observeField("track", "updateChip")
        mp.observeField("state", "updateChip")
    end if
    updateChip()
end sub

sub updateChip()
    if m.npChip = invalid then return
    mp = m.global.music
    tr = invalid
    on = false
    if mp <> invalid
        tr = mp.track
        on = (tr <> invalid and (mp.state = "playing" or mp.state = "buffering"))
    end if
    ' the Music room shows its own now playing
    if m.shown <> invalid and m.shown = "Music" then on = false
    if not on
        if m.npChip.visible
            m.npChip.visible = false
            m.npPulse.control = "stop"
            m.clockFly.visible = true
        end if
        return
    end if
    m.npTitle.text = pxStr(tr.title)
    m.npArtist.text = pxStr(tr.artist)
    th = pxStr(tr.thumb)
    if th <> m.npThumb
        m.npThumb = th
        m.npArtBack.visible = false
        if th = ""
            m.npArt.uri = ""
        else
            ' cut round by the NAS helper; onChipArt falls back to the square cover if that is unreachable
            m.npArt.uri = pxRound(pxImage(th, 120, 120), 120)
        end if
    end if
    if not m.npChip.visible
        m.npChip.visible = true
        m.clockFly.visible = false
        m.npPulse.control = "start"
    end if
    layoutChip()
end sub

sub onChipArt()
    if m.npArt.loadStatus = "failed" and m.npThumb <> ""
        sq = pxImage(m.npThumb, 120, 120)
        if m.npArt.uri <> sq
            m.npArtBack.visible = true
            m.npArt.uri = sq
        end if
    end if
end sub

' Sizes the chip to its words and right-aligns it just left of the clock (the steady firefly steps aside for it).
' It must stay clear of the Search label on the left and the twig's leaf under the clock.
sub layoutChip()
    if not m.npChip.visible then return
    right = m.clock.translation[0] - 14
    if right > 1684 then right = 1684
    left = 1474
    fixed = 60 + 10 + 18 + 18
    m.npTitle.width = 0
    m.npArtist.width = 0
    tw = m.npTitle.localBoundingRect().width
    aw = m.npArtist.localBoundingRect().width
    if aw > tw then tw = aw
    room = right - left - fixed
    if room < 40 then room = 40
    if tw > room then tw = room
    tw = Int(tw)
    m.npTitle.width = tw
    m.npArtist.width = tw
    w = fixed + tw
    m.npBack.width = w
    m.npBars.translation = [60 + tw + 10, 18]
    m.npChip.translation = [right - w, 26]
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
    if not t.ok
        ' Plex unreachable: nothing to warm, let the app open (it shows its offline notes)
        m.top.warm = true
        return
    end if
    libs = {}
    for each v in t.response.Items
        ct = v.CollectionType
        if ct <> invalid and libs[ct] = invalid then libs[ct] = v.Id
    end for
    m.global.libraries = libs
    ' first launch only: build every room now so they all load their data in the background
    ' (rooms are built lazily when opened; startWarm stays unused until preloading is retested)
    for each k in m.rooms
        m.rooms[k].callFunc("refresh", invalid)
    end for
    checkWarm()
end sub

' Build a room once and keep it. Rooms start loading their own data as soon as they exist.
function makeRoom(name as string) as object
    room = m.rooms[name]
    if room <> invalid then return room
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
    return room
end function

' ---------- launch warm-up ----------
' While the lantern intro plays, every room is built (hidden) and fetches its first screen of data, so rooms open instantly.
' m.top.warm turns true when each room has answered (or has nothing to load); HearthScene waits for it, with a time limit.
sub startWarm()
    m.warmRooms = ["Home", "Shows", "Movies", "Music", "Requests", "Ambiance", "Photos"]
    for each n in m.warmRooms
        room = makeRoom(n)
        ' park it in the tree (off screen) so images load; Home is already in the roomHolder
        if room.getParent() = invalid then m.warmHolder.appendChild(room)
        room.observeField("ready", "onRoomReady")
    end for
    checkWarm()
end sub

sub onRoomReady()
    checkWarm()
end sub

sub checkWarm()
    if m.top.warm or m.warmRooms = invalid then return
    libs = m.global.libraries
    for each n in m.warmRooms
        room = m.rooms[n]
        if room <> invalid and not room.ready
            ' no library of that kind on the server: nothing to preload
            absent = false
            if libs <> invalid and libs.count() > 0
                if n = "Shows" and libs.tvshows = invalid then absent = true
                if n = "Movies" and libs.movies = invalid then absent = true
                if n = "Music" and libs.music = invalid then absent = true
                if n = "Photos" and libs.photos = invalid then absent = true
            end if
            if not absent then return
        end if
    end for
    print "[hearth] warm-up done: all rooms have their first data"
    m.top.warm = true
end sub

' Build (once) and show a room. focus=false keeps focus on the pills (preview).
sub showRoom(name as string, focus as boolean)
    room = makeRoom(name)
    if m.roomHolder.getChildCount() > 0 then m.roomHolder.removeChildIndex(0)
    p = room.getParent()
    if p <> invalid then p.removeChild(room)
    m.roomHolder.appendChild(room)
    ' belt and braces: any poster that did not finish loading while the room was parked is asked again
    if m.kicked = invalid then m.kicked = {}
    if m.kicked[name] = invalid
        m.kicked[name] = true
        kickImages(room)
    end if
    m.shown = name
    updateChip()
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
        if r.tab = "new" and r.name = "Requests" then m.rooms["Requests"].callFunc("openNew", invalid)
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
        print "[weather] no haToken saved on this TV"
        m.weather.text = ""
        layoutWeather()
        return
    end if
    print "[weather] asking " + c.haUrl + "/api/states/" + c.haEntity
    pHa("/api/states/" + c.haEntity, "onWeather")
end sub

sub onWeather(event as object)
    t = pTaskFrom(event)
    if not t.ok or t.response.state = invalid
        print "[weather] failed: HTTP " + t.status.toStr() + " (-1 = no answer, 401 = bad token, 404 = wrong entity)"
        return
    end if
    s = pWeatherWord(t.response.state)
    s = UCase(Left(s, 1)) + Mid(s, 2)
    a = t.response.attributes
    if a <> invalid and a.temperature <> invalid then s = s + ", " + Int(a.temperature + 0.5).toStr() + "°"
    m.wxIcon.uri = wxIconFor(t.response.state)
    m.weather.text = s
    layoutWeather()
end sub

' Ask again for every poster that is not loaded yet (same address, so no extra requests for the ones that are fine).
sub kickImages(node as object)
    for i = 0 to node.getChildCount() - 1
        c = node.getChild(i)
        if c <> invalid
            if c.subtype() = "Poster"
                u = c.uri
                if u <> "" and c.loadStatus <> "ready" and Left(u, 4) = "http"
                    c.uri = ""
                    c.uri = u
                end if
            end if
            kickImages(c)
        end if
    end for
end sub
