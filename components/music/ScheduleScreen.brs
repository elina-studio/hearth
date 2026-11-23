' Rows: 0 which schedule, 1 on/off, 2 time, 3 days, 4 rooms, 5 plays, 6 volume, 7 ramp, 8 stops, 9 buttons.
' Morning ("wake"): starts quiet, rises to the volume over the ramp, holds, fades out over the last 5 minutes, stops.
' Evening ("wind"): starts at the volume, holds, fades to nothing over the ramp, stops at the stop time.
sub init()
    m.top.findNode("title").font = hFont("fell", 52)
    m.top.findNode("gTitle").font = hFont("caps", 24)
    m.top.findNode("gA").font = hFont("regular", 22)
    m.top.findNode("gB").font = hFont("regular", 22)
    m.top.findNode("gMax").font = hFont("regular", 22)
    m.top.findNode("gText").font = hFont("regular", 24)
    m.note = m.top.findNode("note")
    m.note.font = hFont("bold", 24)
    m.enableTimer = m.top.findNode("enableTimer")
    m.enableTimer.observeField("fire", "applyEnabled")
    m.DAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    m.HAD = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
    m.all = defaults()
    raw = CreateObject("roRegistrySection", "hearth").Read("musicSchedules")
    if raw <> ""
        j = ParseJson(raw)
        if type(j) = "roAssociativeArray"
            for each k in ["morning", "evening"]
                if j[k] <> invalid then m.all[k] = j[k]
            end for
        end if
    end if
    m.which = "morning"
    m.row = 2
    m.day = 0
    m.btn = 0
    m.playlists = []
    m.rowNodes = []
    buildRows()
    buildButtons()
    buildGraph()
    refresh()
end sub

function defaults() as object
    return {
        morning: { on: false, time: 420, days: "1111100", rooms: [], roomNames: [], plId: "", plTitle: "", vol: 30, ramp: 20, stop: 540 },
        evening: { on: false, time: 1290, days: "1111111", rooms: [], roomNames: [], plId: "", plTitle: "", vol: 25, ramp: 30, stop: 1380 }
    }
end function

sub onShown(unused as dynamic)
    m.top.setFocus(true)
    muSend("castRefresh")
    if muPlayer().section <> "" or pxReady() then pxApi("/playlists", { playlistType: "audio" }, "onPlaylists")
end sub

sub onPlaylists(event as object)
    t = hTaskFrom(event)
    m.playlists = []
    for each d in pxItems(t)
        if m.playlists.Count() < 8 then m.playlists.push({ id: pxStr(d.ratingKey), title: pxStr(d.title) })
    end for
end sub

function cur() as object
    return m.all[m.which]
end function

function clockText(mins as integer) as string
    mins = ((mins mod 1440) + 1440) mod 1440
    h = Int(mins / 60)
    mm = mins mod 60
    ap = "AM"
    if h >= 12 then ap = "PM"
    h12 = h mod 12
    if h12 = 0 then h12 = 12
    t = mm.toStr()
    if mm < 10 then t = "0" + t
    return h12.toStr() + ":" + t + " " + ap
end function

sub buildRows()
    defs = [["which", "sun", "Schedule"], ["on", "check", "Runs"], ["time", "clock", "Starts"], ["days", "sun", "Days"], ["rooms", "cast", "Rooms"], ["plays", "radio", "Plays"], ["vol", "wave", "Volume"], ["ramp", "clock", "Ramp"], ["stop", "moon", "Stops"]]
    g = m.top.findNode("rows")
    y = 0
    for each d in defs
        r = g.createChild("Group")
        r.translation = [0, y]
        bg = r.createChild("Rectangle")
        bg.width = 860
        bg.height = 64
        bg.color = "0x141A11FF"
        ring = r.createChild("Poster")
        ring.uri = "pkg:/images/w/focus-ring" + hVar(y) + ".9.png"
        ring.translation = [-27, -27]
        ring.width = 860 + 54
        ring.height = 64 + 54
        ring.visible = false
        ic = r.createChild("Poster")
        ic.uri = "pkg:/images/music/icons/" + d[1] + ".png"
        ic.width = 34
        ic.height = 34
        ic.translation = [20, 15]
        ic.blendColor = "0xE0B34AFF"
        lb = r.createChild("Label")
        lb.translation = [74, 16]
        lb.font = hFont("regular", 24)
        lb.color = "0xB5AF8CFF"
        lb.text = d[2]
        v = r.createChild("Label")
        v.translation = [250, 12]
        v.width = 580
        v.maxLines = 1
        v.font = hFont("bold", 30)
        v.color = "0xEDE6CAFF"
        node = { g: r, ring: ring, val: v, key: d[0], boxes: [] }
        if d[0] = "days"
            for i = 0 to 6
                b = r.createChild("Rectangle")
                b.translation = [250 + i * 84, 6]
                b.width = 76
                b.height = 52
                b.color = "0x00000000"
                t = r.createChild("Label")
                t.translation = [250 + i * 84, 6]
                t.width = 76
                t.height = 52
                t.horizAlign = "center"
                t.vertAlign = "center"
                t.font = hFont("bold", 24)
                t.text = m.DAYS[i]
                node.boxes.push({ b: b, t: t })
            end for
        end if
        m.rowNodes.push(node)
        y = y + 74
    end for
end sub

sub buildButtons()
    g = m.top.findNode("btns")
    m.btnNodes = []
    x = 0
    for each d in [["check", "Save"], ["play2", "Test now"], ["trash", "Delete"], ["left", "Back"]]
        c = g.createChild("MusicChip")
        c.icon = d[0]
        c.text = d[1]
        c.big = true
        c.translation = [x, 0]
        x = x + c.width + 16
        m.btnNodes.push(c)
    end for
end sub

sub buildGraph()
    g = m.top.findNode("graph")
    m.cols = []
    for i = 0 to 47
        c = g.createChild("Rectangle")
        c.width = 14
        c.color = "0xE0B34AFF"
        c.translation = [i * 16, 340]
        c.height = 2
        m.cols.push(c)
    end for
end sub

' volume (0 to 100) at minute t of a schedule that runs `dur` minutes
function volAt(s as object, kind as string, t as float, dur as integer) as float
    ramp = s.ramp
    if kind = "wake"
        fade = 5
        if t < 0 or t >= dur then return 0.0
        if t < ramp
            start = 5.0
            return start + (s.vol - start) * t / ramp
        end if
        if t > dur - fade then return s.vol * (dur - t) / fade
        return s.vol * 1.0
    end if
    if t < 0 or t >= dur then return 0.0
    if t > dur - ramp then return s.vol * (dur - t) / ramp
    return s.vol * 1.0
end function

function durationOf(s as object) as integer
    d = s.stop - s.time
    if d <= 0 then d = d + 1440
    return d
end function

function kindOf() as string
    if m.which = "morning" then return "wake"
    return "wind"
end function

sub refresh()
    s = cur()
    if m.which = "morning" then m.top.findNode("title").text = "Morning music" else m.top.findNode("title").text = "Evening music"
    for each n in m.rowNodes
        k = n.key
        v = ""
        if k = "which"
            v = "Morning  /  Evening"
        else if k = "on"
            if s.on then v = "On" else v = "Off"
        else if k = "time"
            v = clockText(s.time)
        else if k = "rooms"
            if s.roomNames.Count() = 0 then v = "None picked yet" else v = s.roomNames.join(", ")
        else if k = "plays"
            if s.plTitle = "" then v = "Pick a playlist" else v = "Playlist: " + s.plTitle
        else if k = "vol"
            v = s.vol.toStr() + "% " + tern(kindOf() = "wake", "at the loudest", "to start with")
        else if k = "ramp"
            v = s.ramp.toStr() + " minutes " + tern(kindOf() = "wake", "to rise", "to fade out")
        else if k = "stop"
            v = clockText(s.stop)
        end if
        n.val.visible = (k <> "days")
        n.val.text = v
        if k = "days"
            for i = 0 to 6
                on = (Mid(s.days, i + 1, 1) = "1")
                cell = n.boxes[i]
                if on
                    cell.b.color = "0xE0B34AFF"
                    cell.t.color = "0x1F1606FF"
                else
                    cell.b.color = "0x00000000"
                    cell.t.color = "0xB5AF8CFF"
                end if
            end for
        end if
    end for
    paint()
    drawGraph()
end sub

function tern(c as boolean, a as string, b as string) as string
    if c then return a
    return b
end function

sub paint()
    for i = 0 to m.rowNodes.Count() - 1
        m.rowNodes[i].ring.visible = (m.row = i)
    end for
    for i = 0 to m.btnNodes.Count() - 1
        m.btnNodes[i].focused = (m.row = 9 and m.btn = i)
    end for
end sub

sub drawGraph()
    s = cur()
    kind = kindOf()
    dur = durationOf(s)
    span = dur + 10
    for i = 0 to 47
        t = (i + 0.5) * span / 48
        v = volAt(s, kind, t, dur)
        h = Int(v / 100 * 3 * 100)
        if h < 2 then h = 2
        m.cols[i].height = h
        m.cols[i].translation = [i * 16, 340 - h]
    end for
    m.top.findNode("gA").text = clockText(s.time)
    m.top.findNode("gB").text = clockText(s.stop)
    m.top.findNode("gMax").text = s.vol.toStr() + "%"
    if kind = "wake"
        txt = "Quiet at " + clockText(s.time) + ", full by " + clockText(s.time + s.ramp) + ", a short fade before it stops. "
    else
        txt = "Starts at " + s.vol.toStr() + "%, fades out over " + s.ramp.toStr() + " minutes and stops at " + clockText(s.stop) + ". "
    end if
    txt = txt + "Hearth saves this as a Home Assistant automation, so it plays even with the TV off."
    m.top.findNode("gText").text = txt
end sub

' ---------- keys ----------
function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if muMediaKey(key) then return true
    m.note.text = ""
    s = cur()
    if key = "back"
        m.top.request = { action: "back" }
        return true
    end if
    if key = "up"
        if m.row > 0 then m.row = m.row - 1
    else if key = "down"
        if m.row < 9 then m.row = m.row + 1
    else if m.row = 0
        if key = "left" or key = "right" or key = "OK"
            if m.which = "morning" then m.which = "evening" else m.which = "morning"
        end if
    else if m.row = 1
        if key = "OK" or key = "left" or key = "right" then s.on = not s.on
    else if m.row = 2
        if key = "left" then s.time = (s.time + 1440 - 5) mod 1440
        if key = "right" then s.time = (s.time + 5) mod 1440
    else if m.row = 3
        if key = "left" and m.day > 0 then m.day = m.day - 1
        if key = "right" and m.day < 6 then m.day = m.day + 1
        if key = "OK"
            d = s.days
            c = "1"
            if Mid(d, m.day + 1, 1) = "1" then c = "0"
            s.days = Left(d, m.day) + c + Mid(d, m.day + 2)
        end if
    else if m.row = 4
        if key = "OK" then pickRooms()
    else if m.row = 5
        if key = "OK" then pickPlaylist()
    else if m.row = 6
        if key = "left" and s.vol > 5 then s.vol = s.vol - 5
        if key = "right" and s.vol < 80 then s.vol = s.vol + 5
    else if m.row = 7
        if key = "left" and s.ramp > 5 then s.ramp = s.ramp - 5
        if key = "right" and s.ramp < 60 then s.ramp = s.ramp + 5
    else if m.row = 8
        if key = "left" then s.stop = (s.stop + 1440 - 5) mod 1440
        if key = "right" then s.stop = (s.stop + 5) mod 1440
    else
        if key = "left" and m.btn > 0 then m.btn = m.btn - 1
        if key = "right" and m.btn < 3 then m.btn = m.btn + 1
        if key = "OK" then doButton(m.btn)
    end if
    refresh()
    return true
end function

' ---------- pickers ----------
sub pickRooms()
    rooms = muPlayer().rooms
    m.pickList = []
    if rooms <> invalid
        for each r in rooms
            if r.kind <> "tv" then m.pickList.push(r)
        end for
    end if
    if m.pickList.Count() = 0
        m.note.text = "No speakers found yet. Check that Home Assistant is set up on this TV (casting uses the same)."
        return
    end if
    openRooms()
end sub

sub openRooms()
    s = cur()
    labels = []
    for each r in m.pickList
        mark = "  "
        for each id in s.rooms
            if id = r.id then mark = "ON  "
        end for
        labels.push(mark + r.name)
    end for
    labels.push("Done")
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = "Rooms"
    d.message = ["OK ticks or unticks a speaker."]
    d.buttons = labels
    d.observeField("buttonSelected", "onRoomPick")
    d.observeField("wasClosed", "onMuClosed")
    m.dlg = d
    m.top.getScene().dialog = d
end sub

sub onRoomPick()
    b = m.dlg.buttonSelected
    m.dlg.close = true
    if b >= m.pickList.Count() then return
    s = cur()
    r = m.pickList[b]
    ids = []
    names = []
    found = false
    for i = 0 to s.rooms.Count() - 1
        if s.rooms[i] = r.id
            found = true
        else
            ids.push(s.rooms[i])
            names.push(s.roomNames[i])
        end if
    end for
    if not found
        ids.push(r.id)
        names.push(r.name)
    end if
    s.rooms = ids
    s.roomNames = names
    refresh()
    openRooms()
end sub

sub pickPlaylist()
    if m.playlists.Count() = 0
        m.note.text = "No Plex playlists found. Make a playlist in Plex (Music) first, then come back."
        return
    end if
    labels = []
    for each p in m.playlists
        labels.push(p.title)
    end for
    labels.push("Cancel")
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = "Plays"
    d.message = ["Music Assistant plays this Plex playlist on the speakers."]
    d.buttons = labels
    d.observeField("buttonSelected", "onPlaylistPick")
    d.observeField("wasClosed", "onMuClosed")
    m.dlg = d
    m.top.getScene().dialog = d
end sub

sub onPlaylistPick()
    b = m.dlg.buttonSelected
    m.dlg.close = true
    if b < m.playlists.Count()
        s = cur()
        s.plId = m.playlists[b].id
        s.plTitle = m.playlists[b].title
        refresh()
    end if
end sub

sub muRestoreFocus()
    m.top.setFocus(true)
end sub

' ---------- save / test / delete ----------
function entityIds(s as object) as object
    return s.rooms
end function

function autoId() as string
    return "hearth_music_" + m.which
end function

function autoEntity() as string
    return "automation.hearth_" + m.which + "_music"
end function

function volStep(v as float) as float
    x = Int(v + 0.5)
    if x < 0 then x = 0
    if x > 100 then x = 100
    return x / 100.0
end function

' the automation's steps, with every volume change written out (one every 30 s)
function buildActions(s as object, kind as string) as object
    tgt = { entity_id: s.rooms }
    out = []
    dur = durationOf(s)
    out.push({ action: "media_player.volume_set", target: tgt, data: { volume_level: volStep(volAt(s, kind, 0, dur)) } })
    out.push({ action: "media_player.shuffle_set", target: tgt, data: { shuffle: true } })
    out.push({ action: "music_assistant.play_media", target: tgt, data: { media_id: s.plTitle, media_type: "playlist", enqueue: "replace" } })
    t = 0.0
    pend = 0
    last = volStep(volAt(s, kind, 0, dur))
    while t < dur
        t = t + 0.5
        if t > dur then t = dur
        pend = pend + 30
        v = volStep(volAt(s, kind, t, dur))
        if v <> last
            out.push({ delay: { seconds: pend } })
            out.push({ action: "media_player.volume_set", target: tgt, data: { volume_level: v } })
            pend = 0
            last = v
        end if
    end while
    if pend > 0 then out.push({ delay: { seconds: pend } })
    out.push({ action: "media_player.media_stop", target: tgt })
    out.push({ action: "media_player.volume_set", target: tgt, data: { volume_level: volStep(s.vol) } })
    return out
end function

function buildAutomation(s as object) as object
    kind = kindOf()
    h = Int(s.time / 60)
    mm = s.time mod 60
    at = h.toStr() + ":" + mm.toStr() + ":00"
    if h < 10 then at = "0" + at
    if mm < 10 then at = Left(at, 3) + "0" + Mid(at, 4)
    days = []
    for i = 0 to 6
        if Mid(s.days, i + 1, 1) = "1" then days.push(m.HAD[i])
    end for
    return {
        alias: "Hearth: " + m.which + " music",
        description: "Made by Hearth (Music > schedules). Change it in Hearth; edits here are overwritten when you save there.",
        mode: "restart",
        triggers: [{ trigger: "time", at: at }],
        conditions: [{ condition: "time", weekday: days }],
        actions: buildActions(s, kind)
    }
end function

sub doButton(i as integer)
    if i = 3
        m.top.request = { action: "back" }
        return
    end if
    s = cur()
    if i = 0
        if s.rooms.Count() = 0
            m.note.text = "Pick at least one room first."
            return
        end if
        if s.plId = ""
            m.note.text = "Pick a playlist first."
            return
        end if
        if Instr(1, s.days, "1") = 0
            m.note.text = "Pick at least one day."
            return
        end if
        if CreateObject("roRegistrySection", "hearth").Read("haToken") = ""
            m.note.text = "Home Assistant isn't set up on this TV yet (the same token casting uses)."
            return
        end if
        saveAll()
        m.note.text = "Saving to Home Assistant..."
        haDo("POST", "/api/config/automation/config/" + autoId(), FormatJson(buildAutomation(s)), "onSaved")
    else if i = 1
        haDo("POST", "/api/services/automation/trigger", FormatJson({ entity_id: autoEntity(), skip_condition: true }), "onTested")
    else if i = 2
        saveAll()
        haDo("DELETE", "/api/config/automation/config/" + autoId(), "", "onDeleted")
    end if
end sub

sub saveAll()
    reg = CreateObject("roRegistrySection", "hearth")
    reg.Write("musicSchedules", FormatJson(m.all))
    reg.Flush()
end sub

sub haDo(method as string, path as string, body as string, cb as string)
    t = CreateObject("roSGNode", "HaTask")
    t.method = method
    t.path = path
    t.bodyText = body
    t.observeField("done", cb)
    if m.hTasks = invalid then m.hTasks = {}
    key = "h" + Rnd(1000000).toStr()
    m.hTasks[key] = t
    t.key = key
    t.control = "RUN"
end sub

sub onSaved(event as object)
    t = hTaskFrom(event)
    if t.ok
        m.note.text = "Saved. Home Assistant will run it " + tern(cur().on, "as scheduled.", "when you turn it On.")
        m.enableTimer.control = "start"
    else if t.status = 0
        m.note.text = "Can't reach Home Assistant."
    else
        m.note.text = "Home Assistant said no (" + t.status.toStr() + "). The automation editor API may be turned off."
    end if
end sub

' the new automation takes a moment to appear: then switch it on or off
sub applyEnabled()
    if cur().on then svc = "turn_on" else svc = "turn_off"
    haDo("POST", "/api/services/automation/" + svc, FormatJson({ entity_id: autoEntity() }), "onEnabled")
end sub

sub onEnabled(event as object)
    hTaskFrom(event)
end sub

sub onTested(event as object)
    t = hTaskFrom(event)
    if t.ok then m.note.text = "Started. You should hear it in a moment." else m.note.text = "Couldn't start it. Save it first, then test."
end sub

sub onDeleted(event as object)
    t = hTaskFrom(event)
    if t.ok or t.status = 404 then m.note.text = "Deleted from Home Assistant." else m.note.text = "Couldn't delete it (" + t.status.toStr() + ")."
end sub
