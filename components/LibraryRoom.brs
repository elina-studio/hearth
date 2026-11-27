' Movies or Shows. Focus zones: "grid" (posters), "letters" and "chips" (A to Z only), "tabs", "buttons" (Play / Captions / Details).
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
    ' 160 x 240 with a 30 px row gap: two rows plus their progress braids end above the key hint strip
    m.cw = 160
    m.ch = 240
    m.gapX = 36
    m.gapY = 30
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
    m.subsFor = invalid
    m.subsNote = ""
    m.genre = invalid
    ' A to Z filters (Sort B) and letters (Letters B)
    m.gridClip = m.top.findNode("gridClip")
    m.chipsG = m.top.findNode("chips")
    m.lettersG = m.top.findNode("letters")
    m.sorts = [["A to Z", "titleSort"], ["Recently added", "addedAt:desc"], ["Newest first", "originallyAvailableAt:desc"], ["Top rated", "audienceRating:desc"]]
    m.sortIdx = 0
    m.unw = false
    m.genreF = invalid
    m.decade = ""
    m.chip = 0
    m.letter = 1
    m.firstAt = []
    m.dialog = invalid
    m.wantGenrePick = false
    buildLetters()
    m.hints = m.top.findNode("hints")
    m.hintSig = ""
    rowsInit()
end sub

' ---------- slots ----------
sub buildSlots()
    m.slots = []
    for i = 0 to m.cols * m.visRows - 1
        g = m.grid.createChild("Group")
        bg = g.createChild("Rectangle")
        bg.width = m.cw
        bg.height = m.ch
        bg.color = "0x262A1CFF"
        fb = g.createChild("Label")
        ' no poster yet: the title in the book face, not shouting caps (UX review item 19)
        fb.font = hFontCached("book", 30)
        fb.width = m.cw - 24
        fb.height = m.ch - 24
        fb.translation = [12, 12]
        fb.wrap = true
        fb.lineSpacing = 2
        fb.horizAlign = "center"
        fb.vertAlign = "center"
        fb.color = "0xEDE6CAFF"
        pic = g.createChild("Poster")
        pic.width = m.cw
        pic.height = m.ch
        pic.loadDisplayMode = "scaleToZoom"
        hFbWatch(pic)
        bar = hBraid(g, m.cw, m.ch + 10)
        ring = g.createChild("Poster")
        ring.uri = "pkg:/images/ring" + hVar(i) + ".9.png"
        ring.blendColor = "0xD9A066FF"
        ring.translation = [-10, -10]
        ring.width = m.cw + 20
        ring.height = m.ch + 20
        moss = g.createChild("Poster")
        moss.visible = false
        g.addFields({ bg: bg, fb: fb, pic: pic, bar: bar, ring: ring, moss: moss, at: -1 })
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
                    g.bar.visible = false
                else
                    yr = ""
                    if it.ProductionYear <> invalid then yr = Chr(10) + it.ProductionYear.toStr()
                    g.fb.text = hTitle(it) + yr
                    g.pic.uri = hImageAny(it, ["Primary"], 180)
                    hBraidSet(g.bar, hPercent(it))
                end if
            end if
            g.visible = true
            on = (m.focused and m.zone = "grid" and i = m.index)
            g.ring.visible = on
            if on
                k = i.toStr()
                if m.items[i].Id <> invalid then k = m.items[i].Id.toStr()
                hMossHug(g.moss, -7, -7, m.cw + 7, k)
            end if
            g.moss.visible = on
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
        idle.uri = "pkg:/images/pill-ring" + hVar(i) + ".9.png"
        idle.blendColor = "0xB5AF8CAA"
        fill = b.createChild("Poster")
        fill.uri = "pkg:/images/pill" + hVar(i) + ".9.png"
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
        if it.Type <> "Series"
            lab = "Subtitles"
            if m.subsFor = it.Id then lab = m.subsNote
            kinds.push(["cc", lab, "home-cc"])
            kinds.push(["details", "Details", "home-info"])
        end if
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
    m.tabsW = x - 44
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
        hWaitOn(m.empty, "Plex")
        if m.global.hasField("plexDown") and m.global.plexDown = true
            m.empty.text = "Can't reach Plex. Check the server is on. Hearth tries again every 15 seconds."
            m.top.ready = true
        end if
        ' the library list has arrived and this kind isn't in it: nothing to wait for
        if libs <> invalid and libs.count() > 0
            m.top.ready = true
            what = "Movies"
            if m.top.kind = "tvshows" then what = "TV Shows"
            m.empty.text = "Plex has no " + what + " library yet. Add one in Plex, then open Hearth again."
        end if
        return
    end if
    m.section = libs[m.top.kind]
    if m.view = "rows"
        m.data = {}
        loadRows()
        return
    end if
    ' coming back from details or after Options: keep the poster (and genre) you were on
    g = m.genre
    m.keepAt = invalid
    if m.items.count() > 0 then m.keepAt = m.index
    m.data = {}
    m.genre = invalid
    loadTab(m.tab)
    if g <> invalid then openGenre(g)
end sub

sub loadTab(t as integer)
    m.tab = t
    m.genre = invalid
    paintTabs()
    name = m.tabNames[t]
    layoutAZ()
    key = tabKey()
    if m.data[key] <> invalid
        showItems(m.data[key])
        return
    end if
    m.items = []
    m.index = 0
    m.top0 = 0
    drawGrid()
    hWaitOn(m.empty, "Plex")
    m.countLabel.text = ""
    if name = "Continue"
        hPlex("resume", { section: m.section, limit: 45 }, "onTab", name)
    else if name = "New"
        hPlex("latest", { section: m.section, limit: 45 }, "onTab", name)
    else if name = "Unwatched"
        hPlex("list", { section: m.section, unwatched: true, sort: "random", limit: 90 }, "onTab", name)
    else if name = "A to Z"
        q = { section: m.section, sort: m.sorts[m.sortIdx][1], limit: 2000 }
        if m.unw then q.unwatched = true
        if m.genreF <> invalid then q.genre = m.genreF.genreKey
        if m.decade <> "" then q.decade = m.decade
        hPlex("list", q, "onTab", key)
    else
        hPlex("genres", { section: m.section }, "onGenres", name)
    end if
end sub

sub onTab(event as object)
    t = hTaskFrom(event)
    m.top.ready = true
    items = []
    if not t.ok
        ' don't cache a failure as "empty"
        if tabKey() = t.tag and m.genre = invalid then m.empty.text = "Couldn't reach Plex. Change tab to try again."
        return
    end if
    if t.response.Items <> invalid then items = t.response.Items
    m.data[t.tag] = items
    if tabKey() = t.tag and m.genre = invalid then showItems(items)
end sub

' A to Z answers are kept per filter set, so going back to a filter is instant
function tabKey() as string
    name = m.tabNames[m.tab]
    if name <> "A to Z" then return name
    k = name + "|" + m.sortIdx.toStr() + "|" + m.unw.toStr() + "|" + m.decade
    if m.genreF <> invalid then k = k + "|" + m.genreF.genreKey
    return k
end function

sub onGenres(event as object)
    t = hTaskFrom(event)
    items = []
    if not t.ok
        m.wantGenrePick = false
        if m.tabNames[m.tab] = "Genres" and m.genre = invalid then m.empty.text = "Couldn't reach Plex. Change tab to try again."
        return
    end if
    if t.response.Genres <> invalid
        for each g in t.response.Genres
            items.push({ genreName: g.name, genreKey: g.key })
        end for
    end if
    m.data["Genres"] = items
    if m.tabNames[m.tab] = "Genres" and m.genre = invalid then showItems(items)
    if m.wantGenrePick
        m.wantGenrePick = false
        pickGenre()
    end if
end sub

sub openGenre(g as object)
    m.genre = g
    layoutAZ()
    m.items = []
    drawGrid()
    hWaitOn(m.empty, "Plex")
    hPlex("list", { section: m.section, genre: g.genreKey, sort: "titleSort", limit: 500 }, "onGenre", g.genreName)
end sub

sub onGenre(event as object)
    t = hTaskFrom(event)
    if m.genre = invalid or m.genre.genreName <> t.tag then return
    if not t.ok
        m.empty.text = "Couldn't load " + t.tag + ". Press Back and try again."
        return
    end if
    items = []
    if t.response.Items <> invalid then items = t.response.Items
    showItems(items)
end sub

sub showItems(items as object)
    m.items = items
    m.index = 0
    if m.keepAt <> invalid and m.keepAt < items.count() then m.index = m.keepAt
    m.keepAt = invalid
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
    indexLetters()
    paint()
end sub

' ---------- strip ----------
' Strip title: 64, then 52, then 40 on one line; longer still scrolls
sub setStripTitle(t as string)
    drop = hFitTitle(m.title, t, "caps", [64, 52, 40], 1240)
    m.title.translation = [96, 30 + drop]
end sub

sub showInfo()
    if m.view <> "rows" and m.index < m.items.count() then m.item = m.items[m.index]
    it = m.item
    if it = invalid or it.genreName <> invalid
        if it <> invalid
            m.eyebrow.text = "GENRE"
            setStripTitle(UCase(it.genreName))
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
    setStripTitle(UCase(hTitle(it)))
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
    if m.view = "rows"
        m.zone = "rows"
        m.top.setFocus(true)
        paintRows()
        return
    end if
    if m.items.count() > 0 or m.keepAt <> invalid then m.zone = "grid" else m.zone = "tabs"
    m.top.setFocus(true)
    paint()
end sub

sub paint()
    if m.view = "rows"
        paintRows()
        return
    end if
    row = Int(m.index / m.cols)
    if row < m.top0 then m.top0 = row
    if row > m.top0 + 1 then m.top0 = row - 1
    drawGrid()
    paintTabs()
    paintChips()
    paintLetters()
    showInfo()
    paintHints()
end sub

' The bottom strip: what OK, Play, * and Back do right now. Hidden when the room is only previewed and
' while the A to Z letter row pushes the grid down onto it.
sub paintHints()
    show = m.focused and not lettersOn()
    m.hints.visible = show
    if not show then return
    keys = []
    it = invalid
    if m.zone = "grid" and m.index < m.items.count() then it = m.items[m.index]
    if it <> invalid then keys.push({ text: "OK", label: "Open" })
    if playable(it) then keys.push({ icon: "play", label: "Play" })
    if m.item <> invalid and m.item.genreName = invalid and m.item.Id <> invalid
        ' * opens the options menu (dialogs.brs hOptions), so the hint says so (UX review item 8)
        opt = "Options"
        keys.push({ icon: "asterisk", label: opt })
    end if
    back = "Rows"
    if m.genre <> invalid
        back = "Genres"
    else if m.zone <> "grid" and m.items.count() > 0
        back = "Posters"
    end if
    keys.push({ icon: "back", label: back })
    sig = FormatJson(keys)
    if sig <> m.hintSig
        m.hintSig = sig
        m.hints.keys = keys
        ' KeyHints lays out leftwards from x = 0; shift it so the strip starts at x = 96
        m.hints.translation = [96 + Int(m.hints.localBoundingRect().width), 868]
    end if
end sub

' A movie or episode on the grid (not a show or a genre tile): Play starts it, resuming when part-watched
function playable(it as dynamic) as boolean
    if it = invalid or it.genreName <> invalid or it.Id = invalid then return false
    return it.Type <> "Series"
end function

sub restoreFocus()
    m.top.setFocus(true)
    paint()
end sub

sub afterOptions()
    refresh(invalid)
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
        hSubsPick(m.item)
    else if act = "resume"
        m.top.request = { action: "play", item: m.item, resume: true }
    else if act = "play"
        m.top.request = { action: "play", item: m.item, resume: false }
    else
        m.top.request = { action: "details", item: m.item }
    end if
end sub

function hKeyInner(key as string, press as boolean) as boolean
    if not press then return false
    if m.view = "rows" then return rowsKey(key)
    if key = "play" and m.zone = "grid" and m.index < m.items.count()
        it = m.items[m.index]
        if playable(it)
            m.top.request = { action: "play", item: it, resume: hPercent(it) > 0 }
            return true
        end if
    end if
    if hMediaKey(key) then return false
    if key = "back"
        if m.genre <> invalid
            m.genre = invalid
            layoutAZ()
            gl = m.data["Genres"]
            if gl = invalid then gl = []
            showItems(gl)
            return true
        end if
        if m.zone <> "grid" and m.items.count() > 0
            m.zone = "grid"
            paint()
            return true
        end if
        leaveGrid()
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
            if m.index >= m.cols then m.index = m.index - m.cols else m.zone = zoneNext("grid", -1)
        else if key = "OK" and n > 0
            it = m.items[m.index]
            if it.genreName <> invalid then openGenre(it) else m.top.request = { action: "details", item: it }
            return true
        end if
    else if m.zone = "tabs"
        if key = "left" or key = "right" then m.keepAt = invalid
        if key = "left" and m.tab > 0
            loadTab(m.tab - 1)
        else if key = "right" and m.tab < m.tabNames.count() - 1
            loadTab(m.tab + 1)
        else if key = "right" and onAZ()
            ' the filter chips sit on the same line, right of the tabs
            m.zone = "chips"
            m.chip = 0
        else if key = "down" or key = "OK"
            m.zone = zoneNext("chips", 1)
        else if key = "up"
            if buttonCount() = 0
                leaveToPills()
                return true
            end if
            m.zone = "buttons"
        end if
    else if m.zone = "chips"
        if key = "left" and m.chip > 0
            m.chip = m.chip - 1
        else if key = "left"
            m.zone = "tabs"
        else if key = "right" and m.chip < 4
            m.chip = m.chip + 1
        else if key = "up"
            m.zone = zoneNext("tabs", -1)
        else if key = "down"
            m.zone = zoneNext("chips", 1)
        else if key = "OK"
            runChip()
            return true
        end if
    else if m.zone = "letters"
        if key = "left" or key = "right"
            if key = "left" then d = -1 else d = 1
            j = m.letter + d
            while j >= 0 and j <= 26 and m.firstAt[j] < 0
                j = j + d
            end while
            if j >= 0 and j <= 26
                m.letter = j
                m.index = m.firstAt[j]
                m.top0 = Int(m.index / m.cols)
            end if
        else if key = "up" or key = "down" or key = "OK"
            if key = "up" then d = -1 else d = 1
            m.zone = zoneNext("letters", d)
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

' ---------- A to Z: chips and letters ----------
function onAZ() as boolean
    return m.tabNames[m.tab] = "A to Z" and m.genre = invalid
end function

function lettersOn() as boolean
    return onAZ() and m.sortIdx = 0
end function

' The zone above (d = -1) or below (d = 1) a zone, skipping ones that aren't showing
function zoneNext(z as string, d as integer) as string
    order = ["buttons", "tabs", "chips", "letters", "grid"]
    i = 0
    for k = 0 to order.count() - 1
        if order[k] = z then i = k
    end for
    i = i + d
    while i >= 0 and i < order.count()
        c = order[i]
        ok = true
        if c = "buttons" then ok = buttonCount() > 0
        if c = "chips" then ok = onAZ()
        if c = "letters" then ok = lettersOn() and m.items.count() > 0
        if c = "grid" then ok = m.items.count() > 0
        if ok then return c
        i = i + d
    end while
    return z
end function

' Sort B: the chips share the tab line (right of the tabs); only the letter row pushes the grid down
sub layoutAZ()
    tw = 600
    if m.tabsW <> invalid then tw = m.tabsW
    m.chipsG.translation = [96 + tw + 48, 268]
    m.lettersG.translation = [96, 324]
    y = 330
    if lettersOn() then y = 384
    m.gridClip.translation = [0, y]
    m.empty.translation = [96, y + 30]
    m.chipsG.visible = onAZ()
    m.lettersG.visible = lettersOn()
end sub

sub buildChips()
    m.chipsG.removeChildrenIndex(m.chipsG.getChildCount(), 0)
    sortName = m.sorts[m.sortIdx][0]
    genre = "Genre"
    if m.genreF <> invalid then genre = m.genreF.genreName
    decade = "Decade"
    if m.decade <> "" then decade = m.decade + "s"
    active = [m.sortIdx > 0, m.unw, m.genreF <> invalid, m.decade <> "", false]
    unwIcon = "home-check"
    specs = [[sortName, "home-sort"], ["Unwatched", unwIcon], [genre, "home-filter"], [decade, "home-cal"], ["Clear", "home-x"]]
    x = 0
    for i = 0 to 4
        g = m.chipsG.createChild("Group")
        g.translation = [x, 0]
        idle = g.createChild("Poster")
        fill = g.createChild("Poster")
        ring = g.createChild("Poster")
        icon = g.createChild("Poster")
        icon.uri = "pkg:/images/icons/" + specs[i][1] + ".png"
        icon.width = 20
        icon.height = 20
        icon.translation = [18, 12]
        l = g.createChild("Label")
        l.font = hFont("regular", 22)
        l.text = specs[i][0]
        l.height = 44
        l.vertAlign = "center"
        l.translation = [46, 0]
        w = Int(l.localBoundingRect().width) + 66
        idle.uri = "pkg:/images/pill-ring" + hVar(i) + ".9.png"
        idle.blendColor = "0x5E6450FF"
        fill.uri = "pkg:/images/pill" + hVar(i) + ".9.png"
        fill.blendColor = "0xE0B34AFF"
        ring.uri = "pkg:/images/pill-ring" + hVar(i) + ".9.png"
        ring.blendColor = "0xEDE6CAFF"
        ring.translation = [-6, -6]
        for each p in [idle, fill]
            p.width = w
            p.height = 44
        end for
        ring.width = w + 12
        ring.height = 56
        g.addFields({ fill: fill, idle: idle, ring: ring, icon: icon, label: l, on: active[i] })
        x = x + w + 12
    end for
    paintChips()
end sub

sub paintChips()
    if m.chipsG.getChildCount() = 0
        buildChips()
        return
    end if
    for i = 0 to m.chipsG.getChildCount() - 1
        g = m.chipsG.getChild(i)
        g.fill.visible = g.on
        g.idle.visible = not g.on
        g.ring.visible = (m.focused and m.zone = "chips" and m.chip = i)
        if g.on then col = "0x1F1606FF" else col = "0xEDE6CAFF"
        g.label.color = col
        g.icon.blendColor = col
    end for
end sub

sub runChip()
    if m.chip = 0
        m.sortIdx = (m.sortIdx + 1) mod m.sorts.count()
        applyFilters()
    else if m.chip = 1
        m.unw = not m.unw
        applyFilters()
    else if m.chip = 2
        if m.data["Genres"] = invalid
            m.wantGenrePick = true
            hPlex("genres", { section: m.section }, "onGenres", "Genres")
        else
            pickGenre()
        end if
    else if m.chip = 3
        pick("decade", "Decade", ["Any decade", "2020s", "2010s", "2000s", "1990s", "1980s", "1970s", "1960s", "1950s"])
    else
        m.sortIdx = 0
        m.unw = false
        m.genreF = invalid
        m.decade = ""
        applyFilters()
    end if
end sub

sub applyFilters()
    buildChips()
    loadTab(m.tab)
    m.zone = "chips"
    paint()
end sub

sub pickGenre()
    labels = ["Any genre"]
    for each g in m.data["Genres"]
        labels.push(g.genreName)
    end for
    pick("genre", "Genre", labels)
end sub

sub pick(kind as string, title as string, labels as object)
    m.pickKind = kind
    d = CreateObject("roSGNode", "HearthDialog")
    d.title = title
    d.icon = "pkg:/images/icons/home-filter.png"
    d.buttons = labels
    ' a tick on the one in use, and focus starts there
    now = 0
    for i = 1 to labels.count() - 1
        if kind = "decade" and m.decade <> invalid and m.decade <> "" and Left(labels[i], 4) = m.decade then now = i
        if kind = "genre" and m.genreF <> invalid and labels[i] = m.genreF.genreName then now = i
    end for
    d.icons = hPickIcons(labels.count(), now, "")
    d.buttonFocused = now
    d.observeField("buttonSelected", "onPicked")
    d.observeField("wasClosed", "onPickClosed")
    m.dialog = d
    hShowDialog(d)
end sub

sub onPicked()
    i = m.dialog.buttonSelected
    m.dialog.close = true
    if m.pickKind = "genre"
        if i = 0 then m.genreF = invalid else m.genreF = m.data["Genres"][i - 1]
    else
        if i = 0 then m.decade = "" else m.decade = Left(m.dialog.buttons[i], 4)
    end if
    m.top.setFocus(true)
    applyFilters()
end sub

sub onPickClosed()
    m.top.setFocus(true)
end sub

' Letters B: # then A to Z; each knows the first title that starts with it
sub buildLetters()
    m.letterChars = "#ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    for i = 0 to 26
        g = m.lettersG.createChild("Group")
        g.translation = [i * 58, 0]
        bg = g.createChild("Poster")
        bg.uri = "pkg:/images/pill" + hVar(i) + ".9.png"
        bg.width = 52
        bg.height = 44
        l = g.createChild("Label")
        l.font = hFont("caps", 28)
        l.text = Mid(m.letterChars, i + 1, 1)
        l.width = 52
        l.height = 44
        l.horizAlign = "center"
        l.vertAlign = "center"
        g.addFields({ bg: bg, label: l })
    end for
end sub

function letterOf(it as object) as integer
    t = it.SortName
    if t = invalid or t = "" then t = hTitle(it)
    c = UCase(Left(t, 1))
    p = Instr(1, m.letterChars, c)
    if p <= 1 then return 0
    return p - 1
end function

sub indexLetters()
    m.firstAt = []
    for i = 0 to 26
        m.firstAt.push(-1)
    end for
    if not lettersOn() then return
    for i = 0 to m.items.count() - 1
        k = letterOf(m.items[i])
        if m.firstAt[k] < 0 then m.firstAt[k] = i
    end for
end sub

sub paintLetters()
    if not m.lettersG.visible or m.firstAt.count() < 27 then return
    cur = -1
    if m.index < m.items.count() then cur = letterOf(m.items[m.index])
    if m.zone <> "letters" and cur >= 0 then m.letter = cur
    for i = 0 to 26
        g = m.lettersG.getChild(i)
        focusedHere = (m.focused and m.zone = "letters" and m.letter = i)
        g.bg.visible = focusedHere or i = cur
        if focusedHere
            g.bg.blendColor = "0xE0B34AFF"
            g.label.color = "0x1F1606FF"
        else if i = cur
            g.bg.blendColor = "0xFFFFFF1A"
            g.label.color = "0xEDE6CAFF"
        else if m.firstAt[i] < 0
            g.label.color = "0x5E645099"
        else
            g.label.color = "0xB5AF8CFF"
        end if
    end for
end sub

' the subtitle picker (subs.brs) calls this after a pick
sub hSubsChanged(label as string)
    if m.item <> invalid
        m.subsFor = m.item.Id
        m.subsNote = label
    end if
    showButtons()
end sub

' menu sound for whatever the handler above took (source/util.brs hKeySfx)
function onKeyEvent(key as string, press as boolean) as boolean
    return hKeySfx(key, press, hKeyInner(key, press))
end function
