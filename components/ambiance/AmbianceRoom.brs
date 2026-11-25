' Geometry (1920 x 930 under the pills): PEEK px of the neighbours show at each edge, three panels of
' W px fill the middle, RULE px dividers sit between. The focused panel is kept in the middle slot
' (or the first/last slot at the ends) by sliding the whole strip.
sub init()
    m.H = 930
    m.RULE = 24
    m.PEEK = 120
    m.W = Int((1920 - 2 * m.RULE - 2 * m.PEEK) / 3)
    m.active = false
    m.strip = m.top.findNode("strip")
    m.dotsGroup = m.top.findNode("dots")
    m.clipsAsked = false
    ' true once Plex has said which clips there are; only then can a mood say "no clip yet"
    m.clipsKnown = false
    build(ambItems(), CreateObject("roRegistrySection", "hearth").Read("ambLast"))
    m.slideTo = m.top.findNode("slideTo")
    m.slide = m.top.findNode("slide")
    m.strip.translation = [stripX(), 0]
    paint()
    loadClips()
end sub

' (Re)build the panels, dividers and dots for a list of moods, focusing the one named keep.
sub build(items as object, keep as string)
    m.items = items
    m.n = items.count()
    m.index = 0
    for i = 0 to m.n - 1
        if m.items[i].mood = keep then m.index = i
    end for
    m.strip.removeChildrenIndex(m.strip.getChildCount(), 0)
    m.dotsGroup.removeChildrenIndex(m.dotsGroup.getChildCount(), 0)
    m.panels = []
    for i = 0 to m.n - 1
        m.panels.push(makePanel(i))
        if i < m.n - 1
            r = m.strip.createChild("Poster")
            r.uri = "pkg:/images/amb/divider.png"
            r.width = m.RULE
            r.height = m.H
            r.translation = [panelX(i) + m.W, 0]
        end if
    end for
    m.dots = []
    for i = 0 to m.n - 1
        dt = m.dotsGroup.createChild("Rectangle")
        dt.width = 12
        dt.height = 12
        dt.translation = [960 - (m.n * 26) / 2 + i * 26, m.H - 26]
        m.dots.push(dt)
    end for
    m.strip.translation = [stripX(), 0]
end sub

' A Plex picture cropped to the panel's shape (Plex scales it to cover, the Poster trims the rest).
function plexStill(path as string) as string
    w = 760
    h = 930
    if CreateObject("roDeviceInfo").GetUIResolution().name = "HD"
        w = 507
        h = 620
    end if
    return m.global.plexServer + "/photo/:/transcode?width=" + w.toStr() + "&height=" + h.toStr() + "&minSize=1&upscale=1&url=" + hEscape(path) + "&X-Plex-Token=" + m.global.plexServerToken
end function

' Ask Plex for the clips in the "Ambiance" library once it's known.
sub loadClips()
    if m.clipsAsked then return
    libs = m.global.libraries
    if libs = invalid or libs.Count() = 0
        print "[ambiance] Plex libraries not loaded yet"
        return
    end if
    m.clipsAsked = true
    ' no Ambiance library: PlexTask looks for a hearth folder inside the movie libraries instead
    sec = ""
    if libs.ambiance <> invalid then sec = libs.ambiance
    print "[ambiance] asking Plex for clips, library '"; sec; "'"
    hPlex("clips", { section: sec }, "onClips")
end sub

sub onClips(event as object)
    t = hTaskFrom(event)
    m.top.ready = true
    if not t.ok or t.response.Clips = invalid
        print "[ambiance] clips request failed, status "; t.status
        m.clipsAsked = false
        return
    end if
    print "[ambiance] plex clips: "; t.response.Clips.count()
    m.clipsKnown = true
    if t.response.Clips.count() = 0
        build(ambMoods(), m.items[m.index].mood)
        paint()
        return
    end if
    items = ambMerge(t.response.Clips)
    if not m.global.hasField("ambItems") then m.global.addFields({ ambItems: [] })
    m.global.ambItems = items
    keep = m.items[m.index].mood
    build(items, keep)
    paint()
end sub

function panelX(i as integer) as integer
    return i * (m.W + m.RULE)
end function

' strip offset that puts the focused panel in its slot (slot 1 of 0..2 when possible)
function stripX() as integer
    slot = 1
    if m.index = 0 then slot = 0
    if m.index = m.n - 1 then slot = 2
    return m.PEEK + slot * (m.W + m.RULE) - panelX(m.index)
end function

function makePanel(i as integer) as object
    it = m.items[i]
    p = {}
    g = m.strip.createChild("Group")
    g.translation = [panelX(i), 0]
    p.group = g
    pic = g.createChild("Poster")
    pic.width = m.W
    pic.height = m.H
    pic.loadDisplayMode = "scaleToZoom"
    ' decode at the TV's real 720p size, not the file's
    pic.loadWidth = Int(m.W * 2 / 3)
    pic.loadHeight = Int(m.H * 2 / 3)
    pic.uri = it.still
    if it.plexStill <> invalid and it.plexStill <> "" then pic.uri = plexStill(it.plexStill)
    ' a built-in mood with no clip of the person's own: a dashed panel with the file name to add
    hint = clipHint(it.mood)
    if m.clipsKnown and it.clip = invalid and hint <> "" then missingPanel(g, pic, hint)
    top = g.createChild("Poster")
    top.uri = "pkg:/images/amb/shade-top.png"
    top.width = m.W
    top.height = 420
    bot = g.createChild("Poster")
    bot.uri = "pkg:/images/shade.png"
    bot.width = m.W
    bot.height = 220
    bot.translation = [0, m.H - 220]
    p.bottomShade = bot
    num = g.createChild("Label")
    num.font = hFont("caps", 34)
    num.translation = [40, 40]
    nn = (i + 1).toStr()
    if i + 1 < 10 then nn = "0" + nn
    num.text = nn
    p.num = num
    t = g.createChild("Label")
    ' your own clips can have long names: step the size down so they stay on one line
    size = 92
    if Len(it.title) > 10 then size = 66
    if Len(it.title) > 15 then size = 52
    t.font = hFont("caps", size)
    t.translation = [40, 76]
    t.width = m.W - 60
    t.text = UCase(it.title)
    p.title = t
    s = g.createChild("Label")
    s.font = hFont("fell", 34)
    s.color = "0xB5AF8CFF"
    s.translation = [44, 190]
    s.width = m.W - 70
    s.text = it.sub
    ' controls on the focused panel: OK Play, and the sound state
    c = g.createChild("Group")
    c.translation = [40, m.H - 82]
    ok = c.createChild("Poster")
    ok.uri = "pkg:/images/amb/icon-ok.png"
    ok.width = 62
    ok.height = 44
    lab = c.createChild("Label")
    lab.font = hFont("regular", 26)
    lab.color = "0xB5AF8CFF"
    lab.translation = [76, 6]
    if it.mood = "window" then lab.text = "Open" else lab.text = "Play"
    snd = c.createChild("Poster")
    snd.width = 46
    snd.height = 34
    snd.translation = [170, 5]
    sl = c.createChild("Label")
    sl.font = hFont("regular", 26)
    sl.color = "0xB5AF8CFF"
    sl.translation = [228, 6]
    p.soundIcon = snd
    p.soundLabel = sl
    p.controls = c
    bar = g.createChild("Rectangle")
    bar.width = m.W
    bar.height = 6
    bar.color = "0xE0B34AFF"
    bar.translation = [0, m.H - 6]
    p.bar = bar
    p.mood = it.mood
    return p
end function

' The file-name start ambClipMood matches for each built-in mood ("" = no hint)
function clipHint(md as string) as string
    pre = { hearth: "fire", rain: "rain", fireflies: "firefly", lightsout: "embers" }
    if pre[md] = invalid then return ""
    return pre[md] + "-anything.mp4"
end function

sub missingPanel(g as object, pic as object, file as string)
    pic.uri = ""
    pic.visible = false
    bg = g.createChild("Rectangle")
    bg.width = m.W
    bg.height = m.H
    bg.color = "0xFFFFFF06"
    ' dashes along the four edges (no dashed-line image in the package)
    dash = 16
    gap = 10
    col = "0xFFFFFF22"
    x = 0
    while x < m.W
        l = dash
        if x + l > m.W then l = m.W - x
        for each y in [0, m.H - 3]
            r = g.createChild("Rectangle")
            r.width = l
            r.height = 3
            r.color = col
            r.translation = [x, y]
        end for
        x = x + dash + gap
    end while
    y = 0
    while y < m.H
        l = dash
        if y + l > m.H then l = m.H - y
        for each x in [0, m.W - 3]
            r = g.createChild("Rectangle")
            r.width = 3
            r.height = l
            r.color = col
            r.translation = [x, y]
        end for
        y = y + dash + gap
    end while
    a = g.createChild("Label")
    a.font = hFont("regular", 26)
    a.color = "0xB5AF8CFF"
    a.horizAlign = "center"
    a.width = m.W - 60
    a.wrap = true
    a.lineSpacing = 10
    a.translation = [30, 430]
    a.text = "No clip yet." + Chr(10) + "Add one to Plex named"
    f = g.createChild("Label")
    f.font = hFont("bold", 28)
    f.color = "0xE0B34AFF"
    f.horizAlign = "center"
    f.width = m.W - 60
    f.translation = [30, 518]
    f.text = file
end sub

sub paint()
    reg = CreateObject("roRegistrySection", "hearth")
    for i = 0 to m.n - 1
        p = m.panels[i]
        foc = (i = m.index)
        lit = foc and m.active
        if lit
            p.title.color = "0xE0B34AFF"
            p.num.color = "0xE0B34AFF"
            p.group.opacity = 1.0
        else
            p.title.color = "0xEDE6CAFF"
            p.num.color = "0xB5AF8CFF"
            if foc then p.group.opacity = 1.0 else p.group.opacity = 0.55
        end if
        p.bar.visible = lit
        p.controls.visible = lit
        p.bottomShade.visible = lit
        if p.mood = "window"
            p.soundIcon.visible = false
            p.soundLabel.visible = false
        else
            on = (reg.Read("ambSound_" + p.mood) <> "0")
            if on then p.soundIcon.uri = "pkg:/images/amb/icon-sound-on.png" else p.soundIcon.uri = "pkg:/images/amb/icon-sound-off.png"
            if on then p.soundLabel.text = "Sound on" else p.soundLabel.text = "Sound off"
        end if
    end for
    for i = 0 to m.n - 1
        if i = m.index then m.dots[i].color = "0xE0B34AFF" else m.dots[i].color = "0x464638FF"
    end for
end sub

sub focusIn(unused as dynamic)
    loadClips()
    m.active = true
    paint()
    m.top.setFocus(true)
end sub

' sound settings can change inside a mood; repaint when we come back
sub refresh(unused as dynamic)
    loadClips()
    paint()
end sub

sub move(d as integer)
    i = m.index + d
    if i < 0 or i >= m.n then return
    m.index = i
    m.slideTo.keyValue = [m.strip.translation, [stripX(), 0]]
    m.slide.control = "start"
    paint()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if hMediaKey(key) then return false
    if not press then return false
    if key = "left"
        move(-1)
        return true
    else if key = "right"
        move(1)
        return true
    else if key = "OK"
        it = m.items[m.index]
        if it.mood = "window"
            m.top.request = { action: "room", name: "Photos" }
        else
            m.top.request = { action: "mood", mood: it.mood }
        end if
        return true
    else if key = "up" or key = "back"
        m.active = false
        paint()
        m.top.request = { action: "pills" }
        return true
    end if
    return true
end function
