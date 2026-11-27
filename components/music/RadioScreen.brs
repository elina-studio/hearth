sub init()
    m.top.findNode("title").font = hFont("fell", 52)
    m.top.findNode("sub").font = hFont("regular", 26)
    m.note = m.top.findNode("note")
    m.note.font = hFont("bold", 24)
    p = muPlayer()
    m.variety = 2
    v = CreateObject("roRegistrySection", "hearth").Read("radioVariety")
    if v <> "" then m.variety = Val(v)
    m.skipWeek = true
    m.sel = 0
    m.row = 0
    m.moods = []
    m.defs = [
        { kind: "song", icon: "disc", title: "This song", sub: "" },
        { kind: "artist", icon: "star", title: "This artist", sub: "" },
        { kind: "mood", icon: "moon", title: "A mood", sub: "Calm, Late, Upbeat" },
        { kind: "favs", icon: "heart", title: "My favourites", sub: "Most played" },
        { kind: "forgotten", icon: "clock", title: "Rediscover", sub: "Not heard lately" }
    ]
    tr = p.track
    if tr <> invalid and tr.title <> invalid
        m.defs[0].sub = tr.title
        m.defs[1].sub = tr.artist
    else
        m.defs[0].sub = "Play a song first"
        m.defs[1].sub = "Play a song first"
        m.sel = 3
    end if
    buildTiles()
    buildVariety()
    buildSkip()
    buildButtons()
    paint()
end sub

sub onShown(unused as dynamic)
    m.top.setFocus(true)
end sub

sub buildTiles()
    m.tileNodes = []
    g = m.top.findNode("tiles")
    for i = 0 to m.defs.Count() - 1
        d = m.defs[i]
        t = g.createChild("Group")
        t.translation = [i * 268, 0]
        bg = t.createChild("Rectangle")
        bg.width = 232
        bg.height = 140
        bg.color = "0x141A11FF"
        ic = t.createChild("Poster")
        ic.uri = "pkg:/images/music/icons/" + d.icon + ".png"
        ic.width = 64
        ic.height = 64
        ic.translation = [84, 38]
        ring = t.createChild("Poster")
        ring.uri = "pkg:/images/w/focus-ring" + hVar(i) + ".9.png"
        ring.translation = [-27, -27]
        ring.width = 232 + 54
        ring.height = 140 + 54
        ring.visible = false
        a = t.createChild("Label")
        a.translation = [0, 156]
        a.width = 232
        a.horizAlign = "center"
        a.font = hFont("bold", 28)
        a.text = d.title
        b = t.createChild("Label")
        b.translation = [0, 194]
        b.width = 232
        b.horizAlign = "center"
        b.maxLines = 1
        b.font = hFont("regular", 21)
        b.color = "0xB5AF8CFF"
        b.text = d.sub
        m.tileNodes.push({ g: t, ic: ic, ring: ring, a: a })
    end for
end sub

sub buildVariety()
    g = m.top.findNode("vrow")
    m.vFrame = g.createChild("Poster")
    m.vFrame.uri = "pkg:/images/w/focus-ring-v2.9.png"
    m.vFrame.translation = [-27, -27]
    m.vFrame.width = 1304 + 54
    m.vFrame.height = 64 + 54
    l = g.createChild("Label")
    l.translation = [16, 14]
    l.font = hFont("caps", 26)
    l.color = "0xE0B34AFF"
    l.text = "VARIETY"
    l2 = g.createChild("Label")
    l2.translation = [190, 16]
    l2.font = hFont("regular", 24)
    l2.color = "0xB5AF8CFF"
    l2.text = "Familiar"
    m.vTrack = g.createChild("Rectangle")
    m.vTrack.translation = [320, 26]
    m.vTrack.width = 640
    m.vTrack.height = 12
    m.vTrack.color = "0x0F140CFF"
    for i = 0 to 4
        n = g.createChild("Rectangle")
        nx = 320 + i * 160
        if i = 4 then nx = nx - 3
        n.translation = [nx, 16]
        n.width = 3
        n.height = 32
        n.color = "0x5F6E45FF"
    end for
    m.vFill = g.createChild("Rectangle")
    m.vFill.translation = [320, 27]
    m.vFill.height = 10
    m.vFill.color = "0xE0B34AFF"
    m.vKnob = g.createChild("Rectangle")
    m.vKnob.width = 30
    m.vKnob.height = 30
    m.vKnob.color = "0xFFE7A0FF"
    l3 = g.createChild("Label")
    l3.translation = [996, 16]
    l3.font = hFont("regular", 24)
    l3.color = "0xB5AF8CFF"
    l3.text = "Adventurous"
    m.vName = g.createChild("Label")
    m.vName.translation = [1160, 16]
    m.vName.width = 140
    m.vName.horizAlign = "right"
    m.vName.font = hFont("bold", 24)
    m.vName.color = "0xEDE6CAFF"
    ' the chosen setting was cut off at the box edge (UX review item 13); the Start button already reads it back
    m.vName.visible = false
end sub

sub buildSkip()
    g = m.top.findNode("skip")
    m.sFrame = g.createChild("Poster")
    m.sFrame.uri = "pkg:/images/w/focus-ring-v3.9.png"
    m.sFrame.translation = [-27, -27]
    m.sFrame.width = 640 + 54
    m.sFrame.height = 56 + 54
    m.sIcon = g.createChild("Poster")
    m.sIcon.uri = "pkg:/images/music/icons/check.png"
    m.sIcon.width = 36
    m.sIcon.height = 36
    m.sIcon.translation = [16, 10]
    l = g.createChild("Label")
    l.translation = [72, 10]
    l.font = hFont("regular", 26)
    l.text = "Skip songs I played this week"
end sub

sub buildButtons()
    g = m.top.findNode("btns")
    m.btnNodes = []
    x = 0
    for each d in [["radio", "Start radio"], ["left", "Back"]]
        c = g.createChild("MusicChip")
        c.icon = d[0]
        c.text = d[1]
        c.big = true
        c.translation = [x, 0]
        x = x + c.width + 18
        m.btnNodes.push(c)
    end for
    m.btn = 0
end sub

sub paint()
    for i = 0 to m.tileNodes.Count() - 1
        t = m.tileNodes[i]
        chosen = (i = m.sel)
        if chosen then t.ic.blendColor = "0xE0B34AFF" else t.ic.blendColor = "0xB5AF8CFF"
        if chosen then t.a.color = "0xFFE7A0FF" else t.a.color = "0xEDE6CAFF"
        t.ring.visible = (m.row = 0 and chosen)
    end for
    m.vFrame.visible = (m.row = 1)
    m.vFill.width = 160 * m.variety
    m.vKnob.translation = [320 + 160 * m.variety - 15, 17]
    names = ["Very familiar", "Familiar", "Balanced", "Adventurous", "Very adventurous"]
    m.vName.text = names[m.variety]
    ' the Start button reads back the mix: "Start radio · Calm, Adventurous"
    m.btnNodes[0].text = "Start radio · " + mixName() + ", " + names[m.variety]
    m.btnNodes[1].translation = [m.btnNodes[0].width + 18, 0]
    m.sFrame.visible = (m.row = 2)
    if m.skipWeek then m.sIcon.blendColor = "0xE0B34AFF" else m.sIcon.blendColor = "0x5E5A44FF"
    for i = 0 to m.btnNodes.Count() - 1
        m.btnNodes[i].focused = (m.row = 3 and i = m.btn)
    end for
end sub

' what the radio plays from, for the Start button
function mixName() as string
    d = m.defs[m.sel]
    n = d.title
    if d.kind = "mood" and m.moodName <> invalid and m.moodName <> "" then n = m.moodName
    if Len(n) > 22 then n = Left(n, 21) + Chr(8230)
    return n
end function

sub start()
    d = m.defs[m.sel]
    tr = muPlayer().track
    if (d.kind = "song" or d.kind = "artist") and (tr = invalid or tr.id = invalid)
        m.note.text = "Play a song first, then start a radio from it."
        return
    end if
    if d.kind = "mood"
        if m.moodName = invalid
            m.note.text = "Pick a mood first (OK on the tile)."
            return
        end if
    end if
    muSend("radioStart", { kind: d.kind, variety: m.variety, skipWeek: m.skipWeek, mood: m.moodKey, moodName: m.moodName })
    m.top.request = { action: "back" }
end sub

sub pickMood()
    if muPlayer().section = ""
        m.note.text = "Play something first so Hearth knows your music library."
        return
    end if
    m.note.text = "Looking up moods..."
    pxApi("/library/sections/" + muPlayer().section + "/mood", {}, "onMoods")
end sub

sub onMoods(event as object)
    t = hTaskFrom(event)
    items = pxItems(t)
    ' the screen was left while Plex was answering: don't open a dialog over another screen
    if m.top.getScene() = invalid then return
    m.note.text = ""
    if items.Count() = 0
        m.note.text = "Plex has no mood tags for this library. Try a song or favourites radio."
        return
    end if
    m.moods = []
    labels = []
    for each d in items
        if m.moods.Count() < 8
            m.moods.push({ key: pxStr(d.key), title: pxStr(d.title) })
            labels.push(pxStr(d.title))
        end if
    end for
    labels.push("Cancel")
    dlg = CreateObject("roSGNode", "StandardMessageDialog")
    dlg.title = "A mood"
    dlg.message = ["Pick a mood. The radio plays songs Plex has tagged with it."]
    dlg.buttons = labels
    dlg.observeField("buttonSelected", "onMoodPick")
    dlg.observeField("wasClosed", "onMuClosed")
    m.moodDialog = dlg
    m.top.getScene().dialog = dlg
end sub

sub onMoodPick()
    b = m.moodDialog.buttonSelected
    m.moodDialog.close = true
    if b < m.moods.Count()
        m.moodKey = m.moods[b].key
        m.moodName = m.moods[b].title
        m.defs[2].sub = m.moodName
        m.tileNodes[2].g.getChild(4).text = m.moodName
        m.sel = 2
        paint()
    end if
end sub

sub muRestoreFocus()
    m.top.setFocus(true)
end sub

function hKeyInner(key as string, press as boolean) as boolean
    if not press then return false
    if muMediaKey(key) then return true
    m.note.text = ""
    if key = "back"
        m.top.request = { action: "back" }
        return true
    end if
    if key = "up"
        if m.row > 0 then m.row = m.row - 1
    else if key = "down"
        if m.row < 3 then m.row = m.row + 1
    else if m.row = 0
        if key = "left" and m.sel > 0 then m.sel = m.sel - 1
        if key = "right" and m.sel < m.defs.Count() - 1 then m.sel = m.sel + 1
        if key = "OK"
            if m.defs[m.sel].kind = "mood" then pickMood() else m.row = 1
        end if
    else if m.row = 1
        if key = "left" and m.variety > 0 then m.variety = m.variety - 1
        if key = "right" and m.variety < 4 then m.variety = m.variety + 1
        if key = "OK" then m.row = 2
    else if m.row = 2
        if key = "OK" then m.skipWeek = not m.skipWeek
    else
        if key = "left" and m.btn > 0 then m.btn = m.btn - 1
        if key = "right" and m.btn < 1 then m.btn = m.btn + 1
        if key = "OK"
            if m.btn = 0 then start() else m.top.request = { action: "back" }
        end if
    end if
    paint()
    return true
end function

' menu sound for whatever the handler above took (source/util.brs hKeySfx)
function onKeyEvent(key as string, press as boolean) as boolean
    return hKeySfx(key, press, hKeyInner(key, press))
end function
