' Movies or Shows. Focus zones: "grid" (posters), "tabs", "buttons" (Play / Captions / Details).
' Down from the pills lands on the grid. Up from the grid's top row reaches the tabs, then the buttons,
' then the pills. Down from the tabs or buttons returns to the grid.
' The strip at the top always describes the last poster you were on.
sub init()
    m.eyebrow = m.top.findNode("eyebrow")
    m.eyebrow.font = hFont("caps", 24)
    m.title = m.top.findNode("title")
    m.title.font = hFont("caps", 64)
    m.overview = m.top.findNode("overview")
    m.overview.font = hFont("regular", 24)
    m.art = m.top.findNode("art")
    m.empty = m.top.findNode("empty")
    m.empty.font = hFont("regular", 30)
    m.countLabel = m.top.findNode("count")
    m.countLabel.font = hFont("regular", 24)
    m.grid = m.top.findNode("grid")
    m.cols = 9
    m.cw = 170
    m.ch = 255
    m.gapX = 24
    m.gapY = 36
    m.visRows = 3
    buildSlots()
    buildButtons()
    m.tabNames = ["Continue", "New", "Unwatched", "A to Z", "Genres"]
    buildTabs()
    m.zone = "grid"
    m.btn = 0
    m.tab = 0
    m.focused = false
    m.data = {}
    m.items = []
    m.index = 0
    m.top0 = 0
    m.item = invalid
    m.genre = invalid
end sub

' ---------- slots ----------
sub buildSlots()
    m.slots = []
    for i = 0 to m.cols * m.visRows - 1
        g = m.grid.createChild("Group")
        bg = g.createChild("Rectangle")
        bg.width = m.cw
        bg.height = m.ch
        bg.color = "0x1A2016FF"
        fb = g.createChild("Label")
        fb.font = hFont("caps", 28)
        fb.width = m.cw - 24
        fb.height = m.ch - 24
        fb.translation = [12, 12]
        fb.wrap = true
        fb.horizAlign = "center"
        fb.vertAlign = "center"
        fb.color = "0xEDE6CAFF"
        pic = g.createChild("Poster")
        pic.width = m.cw
        pic.height = m.ch
        pic.loadDisplayMode = "scaleToZoom"
        track = g.createChild("Rectangle")
        track.translation = [0, m.ch + 8]
        track.width = m.cw
        track.height = 6
        track.color = "0xFFFFFF1F"
        fill = g.createChild("Rectangle")
        fill.translation = [0, m.ch + 8]
        fill.height = 6
        fill.color = "0xA3A35AFF"
        ring = g.createChild("Poster")
        ring.uri = "pkg:/images/ring.9.png"
        ring.blendColor = "0xE0B34AFF"
        ring.translation = [-10, -10]
        ring.width = m.cw + 20
        ring.height = m.ch + 20
        g.addFields({ bg: bg, fb: fb, pic: pic, track: track, fill: fill, ring: ring, at: -1 })
        g.visible = false
        m.slots.push(g)
    end for
end sub

' Show rows top0 .. top0+visRows-1, reusing the slots
sub drawGrid()
    n = m.items.count()
    for s = 0 to m.slots.count() - 1
        g = m.slots[s]
        i = m.top0 * m.cols + s
        if i < n
            r = Int(s / m.cols)
            c = s mod m.cols
            g.translation = [c * (m.cw + m.gapX), r * (m.ch + m.gapY)]
            if g.at <> i
                g.at = i
                it = m.items[i]
                if it.genreName <> invalid
                    g.fb.text = UCase(it.genreName)
                    g.pic.uri = ""
                    g.track.visible = false
                    g.fill.visible = false
                else
                    g.fb.text = UCase(hTitle(it))
                    g.pic.uri = hImageAny(it, ["Primary"], 180)
                    pct = hPercent(it)
                    g.track.visible = pct > 0
                    g.fill.visible = pct > 0
                    g.fill.width = Int(m.cw * pct / 100)
                end if
            end if
            g.visible = true
            g.ring.visible = (m.focused and m.zone = "grid" and i = m.index)
        else
            g.visible = false
            g.at = -1
        end if
    end for
end sub

' ---------- buttons ----------
sub buildButtons()
    m.buttons = []
    holder = m.top.findNode("buttons")
    for i = 0 to 2
        b = holder.createChild("Group")
        idle = b.createChild("Poster")
        idle.uri = "pkg:/images/pill-ring.9.png"
        idle.blendColor = "0xB5AF8CAA"
        fill = b.createChild("Poster")
        fill.uri = "pkg:/images/pill.9.png"
        fill.blendColor = "0xE0B34AFF"
        icon = b.createChild("Poster")
        icon.width = 24
        icon.height = 24
        icon.translation = [24, 14]
        label = b.createChild("Label")
        label.font = hFont("bold", 24)
        label.height = 52
        label.vertAlign = "center"
        label.translation = [58, 0]
        b.addFields({ idle: idle, fill: fill, icon: icon, label: label, act: "" })
        m.buttons.push(b)
    end for
end sub

sub showButtons()
    it = m.item
    kinds = []
    if it <> invalid and it.genreName = invalid
        if it.Type = "Series"
            kinds.push(["details", "Open", "home-play"])
        else if hPercent(it) > 0
            kinds.push(["resume", "Resume", "home-play"])
        else
            kinds.push(["play", "Play", "home-play"])
        end if
        if hCaptionsOn() then kinds.push(["cc", "Captions on", "home-cc"]) else kinds.push(["cc", "Captions off", "home-cc"])
        if it.Type <> "Series" then kinds.push(["details", "Details", "home-info"])
    end if
    x = 0
    for i = 0 to 2
        b = m.buttons[i]
        if i < kinds.count()
            b.act = kinds[i][0]
            b.label.text = kinds[i][1]
            b.icon.uri = "pkg:/images/icons/" + kinds[i][2] + ".png"
            w = Int(b.label.localBoundingRect().width) + 82
            b.idle.width = w
            b.idle.height = 52
            b.fill.width = w
            b.fill.height = 52
            b.translation = [x, 0]
            b.visible = true
            x = x + w + 12
        else
            b.visible = false
            b.act = ""
        end if
    end for
    if m.btn >= kinds.count() then m.btn = 0
    paintButtons()
end sub

sub paintButtons()
    for i = 0 to 2
        b = m.buttons[i]
        on = m.focused and m.zone = "buttons" and m.btn = i
        b.fill.visible = on
        b.idle.visible = not on
        if on then col = "0x1F1606FF" else col = "0xEDE6CAFF"
        b.label.color = col
        b.icon.blendColor = col
    end for
end sub

function buttonCount() as integer
    n = 0
    for each b in m.buttons
        if b.visible then n = n + 1
    end for
    return n
end function

' ---------- tabs ----------
sub buildTabs()
    m.tabLabels = []
    holder = m.top.findNode("tabs")
    x = 0
    for each name in m.tabNames
        g = holder.createChild("Group")
        g.translation = [x, 0]
        l = g.createChild("Label")
        l.font = hFont("regular", 28)
        l.text = name
        w = Int(l.localBoundingRect().width)
        u = g.createChild("Rectangle")
        u.translation = [0, 40]
        u.width = w
        u.height = 3
        u.color = "0xE0B34AFF"
        g.addFields({ label: l, under: u, w: w })
        m.tabLabels.push(g)
        x = x + w + 44
    end for
end sub

sub paintTabs()
    for i = 0 to m.tabLabels.count() - 1
        g = m.tabLabels[i]
        cur = (i = m.tab)
        g.under.visible = cur
        if cur and m.focused and m.zone = "tabs"
            g.label.color = "0xE0B34AFF"
        else if cur
            g.label.color = "0xEDE6CAFF"
        else
            g.label.color = "0xB5AF8CFF"
        end if
    end for
end sub

' ---------- data ----------
sub refresh(unused as dynamic)
    if m.top.kind = "" then return
    libs = m.global.libraries
    if libs = invalid or libs[m.top.kind] = invalid
        m.empty.text = "Loading your library…"
        return
    end if
    m.section = libs[m.top.kind]
    m.data = {}
    m.genre = invalid
    loadTab(m.tab)
end sub

sub loadTab(t as integer)
    m.tab = t
    m.genre = invalid
    paintTabs()
    name = m.tabNames[t]
    if m.data[name] <> invalid
        showItems(m.data[name])
        return
    end if
    m.items = []
    m.index = 0
    m.top0 = 0
    drawGrid()
    m.empty.text = "Loading…"
    m.countLabel.text = ""
    if name = "Continue"
        hPlex("resume", { section: m.section, limit: 45 }, "onTab", name)
    else if name = "New"
        hPlex("latest", { section: m.section, limit: 45 }, "onTab", name)
    else if name = "Unwatched"
        hPlex("list", { section: m.section, unwatched: true, sort: "random", limit: 90 }, "onTab", name)
    else if name = "A to Z"
        hPlex("list", { section: m.section, sort: "titleSort", limit: 2000 }, "onTab", name)
    else
        hPlex("genres", { section: m.section }, "onGenres", name)
    end if
end sub

sub onTab(event as object)
    t = hTaskFrom(event)
    items = []
    if t.ok and t.response.Items <> invalid then items = t.response.Items
    m.data[t.tag] = items
    if m.tabNames[m.tab] = t.tag and m.genre = invalid then showItems(items)
end sub

sub onGenres(event as object)
    t = hTaskFrom(event)
    items = []
    if t.ok and t.response.Genres <> invalid
        for each g in t.response.Genres
            items.push({ genreName: g.name, genreKey: g.key })
        end for
    end if
    m.data["Genres"] = items
    if m.tabNames[m.tab] = "Genres" and m.genre = invalid then showItems(items)
end sub

sub openGenre(g as object)
    m.genre = g
    m.items = []
    drawGrid()
    m.empty.text = "Loading " + g.genreName + "…"
    hPlex("list", { section: m.section, genre: g.genreKey, sort: "titleSort", limit: 500 }, "onGenre", g.genreName)
end sub

sub onGenre(event as object)
    t = hTaskFrom(event)
    if m.genre = invalid or m.genre.genreName <> t.tag then return
    items = []
    if t.ok and t.response.Items <> invalid then items = t.response.Items
    showItems(items)
end sub

sub showItems(items as object)
    m.items = items
    m.index = 0
    m.top0 = 0
    for each g in m.slots
        g.at = -1
    end for
    if items.count() = 0
        if m.genre <> invalid then m.empty.text = "Nothing in " + m.genre.genreName + "." else m.empty.text = "Nothing here yet."
    else
        m.empty.text = ""
    end if
    word = "titles"
    if m.tabNames[m.tab] = "Genres" and m.genre = invalid then word = "genres"
    if m.genre <> invalid
        m.countLabel.text = m.genre.genreName + " · " + items.count().toStr()
    else if items.count() > 0
        m.countLabel.text = items.count().toStr() + " " + word
    else
        m.countLabel.text = ""
    end if
    if m.zone = "grid" and items.count() = 0 and m.focused then m.zone = "tabs"
    paint()
end sub

' ---------- strip ----------
sub showInfo()
    if m.index < m.items.count() then m.item = m.items[m.index]
    it = m.item
    if it = invalid or it.genreName <> invalid
        if it <> invalid
            m.eyebrow.text = "GENRE"
            m.title.text = UCase(it.genreName)
            m.overview.text = "OK shows everything in " + it.genreName + "."
            m.art.uri = ""
        end if
        showButtons()
        return
    end if
    bits = []
    if it.ProductionYear <> invalid then bits.push(it.ProductionYear.toStr())
    if it.RunTimeTicks <> invalid and it.Type <> "Series"
        mins = Int(it.RunTimeTicks / 600000000)
        if mins >= 60 then bits.push(Int(mins / 60).toStr() + " H " + (mins mod 60).toStr() + " M") else bits.push(mins.toStr() + " M")
    end if
    if it.OfficialRating <> invalid and it.OfficialRating <> "" then bits.push(it.OfficialRating)
    if it.Type = "Episode" then bits.unshift(hSubtitle(it))
    m.eyebrow.text = UCase(bits.join(" · "))
    m.title.text = UCase(hTitle(it))
    ov = it.Overview
    if ov = invalid then ov = ""
    m.overview.text = ov
    u = hImageAny(it, ["Backdrop", "Thumb"], 400)
    if m.art.uri <> u then m.art.uri = u
    showButtons()
end sub

' ---------- focus ----------
sub focusIn(unused as dynamic)
    m.focused = true
    if m.items.count() > 0 then m.zone = "grid" else m.zone = "tabs"
    m.top.setFocus(true)
    paint()
end sub

sub paint()
    row = Int(m.index / m.cols)
    if row < m.top0 then m.top0 = row
    if row > m.top0 + 1 then m.top0 = row - 1
    drawGrid()
    paintTabs()
    showInfo()
end sub

sub restoreFocus()
    m.top.setFocus(true)
    paint()
end sub

sub afterOptions()
    m.data = {}
    loadTab(m.tab)
end sub

sub onOptions()
    hOptionsChosen()
end sub

sub leaveToPills()
    m.focused = false
    paint()
    m.top.request = { action: "pills" }
end sub

sub runButton()
    if buttonCount() = 0 or m.item = invalid then return
    act = m.buttons[m.btn].act
    if act = "cc"
        hToggleCaptions()
        showButtons()
    else if act = "resume"
        m.top.request = { action: "play", item: m.item, resume: true }
    else if act = "play"
        m.top.request = { action: "play", item: m.item, resume: false }
    else
        m.top.request = { action: "details", item: m.item }
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
    if key = "back"
        if m.genre <> invalid
            m.genre = invalid
            showItems(m.data["Genres"])
            return true
        end if
        if m.zone <> "grid" and m.items.count() > 0
            m.zone = "grid"
            paint()
            return true
        end if
        leaveToPills()
        return true
    end if
    if key = "options"
        if m.item <> invalid and m.item.genreName = invalid then hOptions(m.item)
        return true
    end if
    n = m.items.count()
    if m.zone = "grid"
        if key = "left" and m.index mod m.cols > 0
            m.index = m.index - 1
        else if key = "right" and m.index + 1 < n and (m.index + 1) mod m.cols > 0
            m.index = m.index + 1
        else if key = "down"
            if m.index + m.cols < n
                m.index = m.index + m.cols
            else if Int(m.index / m.cols) < Int((n - 1) / m.cols)
                m.index = n - 1
            end if
        else if key = "up"
            if m.index >= m.cols then m.index = m.index - m.cols else m.zone = "tabs"
        else if key = "OK" and n > 0
            it = m.items[m.index]
            if it.genreName <> invalid then openGenre(it) else m.top.request = { action: "details", item: it }
            return true
        end if
    else if m.zone = "tabs"
        if key = "left" and m.tab > 0
            loadTab(m.tab - 1)
        else if key = "right" and m.tab < m.tabNames.count() - 1
            loadTab(m.tab + 1)
        else if (key = "down" or key = "OK") and n > 0
            m.zone = "grid"
        else if key = "up"
            if buttonCount() = 0
                leaveToPills()
                return true
            end if
            m.zone = "buttons"
        end if
    else
        bc = buttonCount()
        if key = "left" and m.btn > 0
            m.btn = m.btn - 1
        else if key = "right" and m.btn < bc - 1
            m.btn = m.btn + 1
        else if key = "down"
            if n > 0 then m.zone = "grid" else m.zone = "tabs"
        else if key = "up"
            leaveToPills()
            return true
        else if key = "OK"
            runButton()
        end if
    end if
    paint()
    paintButtons()
    return true
end function
