' Home. Focus zones, top to bottom:
'   "hero"  Resume / From start / Details. Left on the first button or Right on the last steps to the
'           previous or next of the top 3 Continue items.
'   "dash"  0 prev, 1 play/pause, 2 next (Now playing), 3 Requests, 4..7 the 2x2 mood tiles
'   "rows"  Next up, then Recently added
sub init()
    m.content = m.top.findNode("content")
    m.scroll = m.top.findNode("scroll")
    m.scrollTo = m.top.findNode("scrollTo")
    m.heroArt = m.top.findNode("heroArt")
    m.greeting = m.top.findNode("greeting")
    m.greeting.font = hFont("fell", 38)
    m.heroEyebrow = m.top.findNode("heroEyebrow")
    m.heroEyebrow.font = hFont("caps", 24)
    m.heroTitle = m.top.findNode("heroTitle")
    m.heroTitle.font = hFont("caps", 70)
    m.heroProgress = m.top.findNode("heroProgress")
    m.heroBar = m.top.findNode("heroBar")
    m.heroLeft = m.top.findNode("heroLeft")
    m.heroLeft.font = hFont("regular", 24)
    m.pager = m.top.findNode("pager")
    m.dots = m.top.findNode("dots")
    m.pgText = m.top.findNode("pgText")
    m.pgText.font = hFont("regular", 24)

    for each id in ["musicEyebrow", "reqEyebrow", "moodEyebrow"]
        m.top.findNode(id).font = hFont("caps", 24)
    end for
    m.top.findNode("musicTitle").font = hFont("bold", 30)
    m.top.findNode("musicSub").font = hFont("regular", 24)
    m.top.findNode("reqFoot").font = hFont("regular", 26)
    m.mRings = [m.top.findNode("mRing0"), m.top.findNode("mRing1"), m.top.findNode("mRing2")]
    m.reqRing = m.top.findNode("reqRing")
    m.musicBar = m.top.findNode("musicBar")

    m.nextUp = m.top.findNode("nextUp")
    m.latest = m.top.findNode("latest")
    m.rows = [m.nextUp, m.latest, m.top.findNode("musicRow"), m.top.findNode("reqRow"), m.top.findNode("photoRow")]
    m.rowY = [540, 880, 1220, 1560, 1900]
    for each r in m.rows
        r.visible = false
    end for

    buildButtons()
    buildMoods()
    buildReqLines()

    m.zone = "hero"
    m.btn = 0
    m.dash = 1
    m.row = 0
    m.heroIndex = 0
    m.heroItems = []
    m.offline = false
    m.resume = []
    m.next = []
    m.new = []
    m.tasks = {}
    mp = m.global.music
    if mp <> invalid
        for each f in ["track", "state", "queue", "index", "position"]
            mp.observeField(f, "showMusic")
        end for
    end if
    showGreeting()
    showMusic()
    refresh(invalid)
end sub

' ---------- hero buttons ----------
sub buildButtons()
    m.buttons = []
    holder = m.top.findNode("buttons")
    for i = 0 to 2
        b = holder.createChild("Group")
        b.addFields({ idle: b.createChild("Poster"), fill: b.createChild("Poster"), ring: b.createChild("Poster") })
        b.idle.uri = "pkg:/images/pill-ring.9.png"
        b.idle.blendColor = "0xB5AF8CAA"
        b.fill.uri = "pkg:/images/pill.9.png"
        b.fill.blendColor = "0xE0B34AFF"
        b.ring.uri = "pkg:/images/pill-ring.9.png"
        b.ring.blendColor = "0xEDE6CAFF"
        b.ring.translation = [-7, -7]
        icon = b.createChild("Poster")
        icon.width = 24
        icon.height = 24
        icon.translation = [26, 16]
        label = b.createChild("Label")
        label.font = hFont("bold", 26)
        label.height = 56
        label.vertAlign = "center"
        label.translation = [60, 0]
        b.addFields({ icon: icon, label: label, act: "" })
        m.buttons.push(b)
    end for
end sub

' kinds: list of [act, text, icon]
sub setButtons(kinds as object)
    x = 0
    for i = 0 to 2
        b = m.buttons[i]
        if i < kinds.count()
            k = kinds[i]
            b.act = k[0]
            b.label.text = k[1]
            b.icon.uri = "pkg:/images/icons/" + k[2] + ".png"
            w = Int(b.label.localBoundingRect().width) + 86
            for each p in [b.idle, b.fill]
                p.width = w
                p.height = 56
            end for
            b.ring.width = w + 14
            b.ring.height = 70
            b.translation = [x, 0]
            b.visible = true
            x = x + w + 12
        else
            b.visible = false
            b.act = ""
        end if
    end for
    if m.btn >= kinds.count() then m.btn = 0
end sub

function buttonCount() as integer
    n = 0
    for each b in m.buttons
        if b.visible then n = n + 1
    end for
    return n
end function

' ---------- greeting ----------
sub showGreeting()
    t = CreateObject("roDateTime")
    t.toLocalTime()
    h = t.getHours()
    if h < 5
        g = "Still up by the fire"
    else if h < 12
        g = "Good morning"
    else if h < 17
        g = "Good afternoon"
    else
        g = "Good evening"
    end if
    m.greeting.text = g
end sub

' ---------- Now playing ----------
sub showMusic()
    mp = m.global.music
    eb = m.top.findNode("musicEyebrow")
    ti = m.top.findNode("musicTitle")
    su = m.top.findNode("musicSub")
    art = m.top.findNode("musicArt")
    tog = m.top.findNode("mToggle")
    if mp = invalid or mp.track = invalid or mp.queue = invalid or mp.queue.count() = 0
        eb.text = "MUSIC"
        ti.text = "Shuffle my music"
        su.text = "Play starts a random mix"
        art.uri = ""
        tog.uri = "pkg:/images/icons/home-play.png"
        m.musicBar.width = 0
        return
    end if
    tr = mp.track
    if mp.state = "playing"
        eb.text = "NOW PLAYING"
    else if mp.state = "buffering"
        eb.text = "LOADING"
    else
        eb.text = "PAUSED"
    end if
    if mp.state = "playing" or mp.state = "buffering"
        tog.uri = "pkg:/images/icons/home-pause.png"
    else
        tog.uri = "pkg:/images/icons/home-play.png"
    end if
    ti.text = pxStr(tr.title)
    line = pxStr(tr.artist)
    if tr.album <> invalid and tr.album <> "" then line = line + " · " + tr.album
    su.text = line
    u = pxImage(tr.thumb, 180, 180)
    if art.uri <> u then art.uri = u
    w = 0
    if mp.duration > 0 then w = Int(180 * mp.position / mp.duration)
    if w > 180 then w = 180
    m.musicBar.width = w
end sub

sub musicCommand(cmd as string)
    mp = m.global.music
    if mp <> invalid then mp.command = { cmd: cmd }
end sub

' ---------- Requests: up to 3 on the way, and how many recent ones are ready ----------
sub buildReqLines()
    m.reqLines = []
    holder = m.top.findNode("reqLines")
    for i = 0 to 2
        g = holder.createChild("Group")
        g.translation = [0, i * 38]
        name = g.createChild("Label")
        name.font = hFont("regular", 26)
        name.width = 290
        name.maxLines = 1
        name.color = "0xEDE6CAFF"
        track = g.createChild("Rectangle")
        track.translation = [300, 16]
        track.width = 110
        track.height = 6
        track.color = "0xFFFFFF1F"
        fill = g.createChild("Rectangle")
        fill.translation = [300, 16]
        fill.height = 6
        fill.color = "0xA3A35AFF"
        note = g.createChild("Label")
        note.font = hFont("regular", 26)
        note.width = 160
        note.translation = [316, 0]
        note.horizAlign = "right"
        g.addFields({ name: name, track: track, fill: fill, note: note })
        g.visible = false
        m.reqLines.push(g)
    end for
end sub

sub loadRequests()
    foot = m.top.findNode("reqFoot")
    reg = CreateObject("roRegistrySection", "hearth")
    if reg.Read("overseerrKey") = ""
        foot.text = "Open Requests to link Overseerr"
        return
    end if
    if m.tasks.req <> invalid then return
    t = CreateObject("roSGNode", "OverseerrTask")
    t.mode = "requests"
    t.query = { take: "10" }
    m.tasks.req = t
    t.observeField("done", "onRequests")
    t.control = "RUN"
end sub

sub onRequests(event as object)
    t = event.getRoSGNode()
    m.tasks.delete("req")
    foot = m.top.findNode("reqFoot")
    for each g in m.reqLines
        g.visible = false
    end for
    if not t.ok or t.response = invalid or t.response.results = invalid
        foot.text = "Couldn't reach Overseerr"
        return
    end if
    shown = 0
    ready = 0
    for each r in t.response.results
        q = r.request
        ms = -1
        if q.media <> invalid then ms = rqNum(q.media.status)
        rs = rqNum(q.status)
        if ms = 5
            ready = ready + 1
        else if rs <> 3 and shown < 3
            g = m.reqLines[shown]
            title = r.info.title
            if title = invalid or title = "" then title = "Untitled"
            g.name.text = title
            pct = rqProgress(q.media)
            if rs = 4
                g.note.text = "failed"
                g.note.color = "0xF0907CFF"
                pct = -1
            else if pct >= 0
                g.note.text = pct.toStr() + "%"
                g.note.color = "0xA3A35AFF"
            else if rs = 1
                g.note.text = "waiting"
                g.note.color = "0xB5AF8CFF"
            else
                g.note.text = "approved"
                g.note.color = "0xB5AF8CFF"
            end if
            g.track.visible = pct >= 0
            g.fill.visible = pct >= 0
            if pct >= 0
                g.fill.width = Int(110 * pct / 100)
                g.note.translation = [316, 0]
                g.note.width = 160
                g.name.color = "0xEDE6CAFF"
            else
                g.name.color = "0xB5AF8CFF"
            end if
            g.visible = true
            shown = shown + 1
        end if
    end for
    if shown = 0
        m.reqLines[0].name.text = "Nothing on the way"
        m.reqLines[0].name.color = "0xB5AF8CFF"
        m.reqLines[0].note.text = ""
        m.reqLines[0].track.visible = false
        m.reqLines[0].fill.visible = false
        m.reqLines[0].visible = true
    end if
    rcards = []
    for each r in t.response.results
        if r.info <> invalid and r.info.title <> invalid and r.info.title <> ""
            c = rqRequestCard(r.request, r.info)
            rcards.push({ title: c.title, sub: c.chip.text, image: c.image, progress: 0, item: c.data })
        end if
    end for
    setRow(3, rcards)
    if ready = 1
        foot.text = "1 ready to watch"
    else if ready > 1
        foot.text = ready.toStr() + " ready to watch"
    else
        foot.text = "OK opens Requests"
    end if
end sub

' ---------- Set the mood ----------
sub buildMoods()
    m.moodKeys = ["hearth", "rain", "lightsout", "fireflies"]
    names = ["HEARTH", "RAIN", "LIGHTS LOW", "FIREFLIES"]
    m.moodRings = []
    holder = m.top.findNode("moodTiles")
    for i = 0 to 3
        g = holder.createChild("Group")
        g.translation = [(i mod 2) * 242, Int(i / 2) * 74]
        pic = g.createChild("Poster")
        pic.uri = "pkg:/images/amb/tile-" + m.moodKeys[i] + ".jpg"
        pic.width = 230
        pic.height = 62
        pic.loadDisplayMode = "scaleToZoom"
        shade = g.createChild("Rectangle")
        shade.width = 230
        shade.height = 62
        shade.color = "0x0A0D08A6"
        l = g.createChild("Label")
        l.font = hFont("caps", 24)
        l.text = names[i]
        l.translation = [18, 0]
        l.height = 62
        l.vertAlign = "center"
        l.color = "0xEDE6CAFF"
        ring = g.createChild("Poster")
        ring.uri = "pkg:/images/ring.9.png"
        ring.blendColor = "0xE0B34AFF"
        ring.translation = [-10, -10]
        ring.width = 250
        ring.height = 82
        ring.visible = false
        m.moodRings.push(ring)
    end for
end sub

' ---------- data ----------
sub refresh(unused as dynamic)
    showGreeting()
    loadRequests()
    hPlex("resume", { limit: 12 }, "onResume")
    hPlex("nextup", { limit: 12 }, "onNextUp")
    hPlex("latest", { limit: 16 }, "onLatest")
    libs = m.global.libraries
    if libs <> invalid
        if libs.music <> invalid then hPlex("latest", { section: libs.music, limit: 16 }, "onMusicRow")
        if libs.photos <> invalid then hPlex("latest", { section: libs.photos, limit: 16 }, "onPhotoRow")
    end if
end sub

sub onMusicRow(event as object)
    t = hTaskFrom(event)
    cards = []
    if t.ok and t.response.Items <> invalid
        for each it in t.response.Items
            c = hCard(it, "tall")
            if it.ArtistName <> invalid then c.sub = it.ArtistName
            cards.push(c)
        end for
    end if
    setRow(2, cards)
end sub

sub onPhotoRow(event as object)
    t = hTaskFrom(event)
    cards = []
    if t.ok and t.response.Items <> invalid
        for each it in t.response.Items
            c = hCard(it, "wide")
            c.sub = ""
            cards.push(c)
        end for
    end if
    setRow(4, cards)
end sub

sub setRow(r as integer, cards as object)
    m.rows[r].cards = cards
    m.rows[r].visible = cards.count() > 0
    layoutRows()
end sub

sub onResume(event as object)
    t = hTaskFrom(event)
    m.offline = (t.status <= 0)
    if t.ok then m.resume = t.response.Items else m.resume = []
    pickHero()
end sub

sub onNextUp(event as object)
    t = hTaskFrom(event)
    m.next = []
    if t.ok then m.next = t.response.Items
    fillRow(m.nextUp, m.next)
    pickHero()
end sub

sub onLatest(event as object)
    t = hTaskFrom(event)
    m.new = []
    if t.ok then m.new = t.response.Items
    fillRow(m.latest, m.new)
    pickHero()
end sub

sub fillRow(row as object, items as object)
    cards = []
    for each it in items
        cards.push(hCard(it, "wide"))
    end for
    row.cards = cards
    row.visible = cards.count() > 0
    layoutRows()
end sub

' stack the rows under the cards with no gaps for hidden ones
sub layoutRows()
    y = 540
    for r = 0 to m.rows.count() - 1
        row = m.rows[r]
        if row.visible
            row.translation = [96, y]
            m.rowY[r] = y
            h = row.rowHeight
            if h = 0 then h = 300
            y = y + h + 40
        end if
    end for
end sub

' The hero steps through up to 3 items: what you're in the middle of first, then next up, then new.
sub pickHero()
    keep = invalid
    if m.heroItems.count() > m.heroIndex then keep = m.heroItems[m.heroIndex].item
    list = []
    seen = {}
    for each src in [[m.resume, "CONTINUE"], [m.next, "NEXT UP"], [m.new, "NEW THIS WEEK"]]
        for each it in src[0]
            if list.count() < 3 and it.Id <> invalid and not seen.doesExist(it.Id)
                seen[it.Id] = true
                list.push({ item: it, label: src[1] })
            end if
        end for
    end for
    m.heroItems = list
    m.heroIndex = 0
    if keep <> invalid
        for i = 0 to list.count() - 1
            if list[i].item.Id = keep.Id then m.heroIndex = i
        end for
    end if
    showHero()
end sub

sub showHero()
    if m.heroItems.count() = 0
        m.heroArt.uri = ""
        m.heroProgress.visible = false
        m.pager.visible = false
        if m.offline
            m.heroEyebrow.text = "CAN'T REACH YOUR LIBRARY"
            m.heroTitle.text = "TRY AGAIN IN A MOMENT"
            setButtons([["retry", "Try again", "home-restart"]])
        else
            m.heroEyebrow.text = "WELCOME HOME"
            m.heroTitle.text = "NOTHING HERE YET"
            setButtons([])
        end if
        paint()
        return
    end if
    h = m.heroItems[m.heroIndex]
    item = h.item
    eyebrow = h.label
    if item.Type = "Episode"
        eyebrow = eyebrow + " · " + hSubtitle(item)
    else if item.ProductionYear <> invalid
        eyebrow = eyebrow + " · " + item.ProductionYear.toStr()
    end if
    m.heroEyebrow.text = UCase(eyebrow)
    m.heroTitle.text = UCase(hTitle(item))
    m.heroArt.uri = hImageAny(item, ["Backdrop", "Thumb", "Primary"], 1920)
    pct = hPercent(item)
    m.heroProgress.visible = pct > 0
    m.heroBar.width = Int(300 * pct / 100)
    m.heroLeft.text = hMinutesLeft(item)
    if item.Type = "Series"
        setButtons([["details", "Open", "home-info"]])
    else if pct > 0
        setButtons([["resume", "Resume", "home-play"], ["start", "From start", "home-restart"], ["details", "Details", "home-info"]])
    else
        setButtons([["start", "Play", "home-play"], ["details", "Details", "home-info"]])
    end if
    showPager()
    paint()
end sub

sub showPager()
    n = m.heroItems.count()
    m.pager.visible = n > 1
    if n <= 1 then return
    while m.dots.getChildCount() > 0
        m.dots.removeChildIndex(0)
    end while
    x = 0
    for i = 0 to n - 1
        d = m.dots.createChild("Rectangle")
        if i = m.heroIndex
            d.width = 34
            d.color = "0xE0B34AFF"
        else
            d.width = 10
            d.color = "0xB5AF8C80"
        end if
        d.height = 10
        d.translation = [x, 10]
        x = x + d.width + 12
    end for
    nxt = m.heroItems[(m.heroIndex + 1) mod n].item
    m.pgText.text = (m.heroIndex + 1).toStr() + " of " + n.toStr() + " · next: " + hTitle(nxt)
    ' lay out right to left so the line ends at the right margin
    tw = Int(m.pgText.localBoundingRect().width)
    right = 1794
    m.pgText.translation = [right - tw, 0]
    m.top.findNode("pgRight").translation = [right - tw - 44, 0]
    dw = x - 12
    m.dots.translation = [right - tw - 58 - dw, 0]
    m.top.findNode("pgLeft").translation = [right - tw - 72 - dw - 30, 0]
end sub

sub stepHero(d as integer)
    n = m.heroItems.count()
    if n <= 1 then return
    m.heroIndex = (m.heroIndex + d + n) mod n
    showHero()
end sub

' ---------- focus ----------
sub focusIn(unused as dynamic)
    ' coming down from the pills always lands on the hero's first button, not wherever you were last
    m.zone = "hero"
    m.btn = 0
    m.top.setFocus(true)
    showGreeting()
    paint()
end sub

sub paint()
    focused = m.top.hasFocus()
    for i = 0 to 2
        b = m.buttons[i]
        on = focused and m.zone = "hero" and m.btn = i
        b.fill.visible = on
        b.ring.visible = on
        b.idle.visible = not on
        if on
            b.label.color = "0x1F1606FF"
            b.icon.blendColor = "0x1F1606FF"
        else
            b.label.color = "0xEDE6CAFF"
            b.icon.blendColor = "0xEDE6CAFF"
        end if
    end for
    for i = 0 to 2
        m.mRings[i].visible = focused and m.zone = "dash" and m.dash = i
    end for
    m.reqRing.visible = focused and m.zone = "dash" and m.dash = 3
    for i = 0 to 3
        m.moodRings[i].visible = focused and m.zone = "dash" and m.dash = i + 4
    end for
    for r = 0 to m.rows.count() - 1
        m.rows[r].active = focused and m.zone = "rows" and m.row = r
    end for
    y = 0
    if m.zone = "rows" then y = -(m.rowY[m.row] - 60)
    m.scroll.control = "stop"
    m.scrollTo.keyValue = [m.content.translation, [0, y]]
    m.scroll.control = "start"
end sub

function rowUsable(r as integer) as boolean
    return m.rows[r].visible and m.rows[r].callFunc("count", invalid) > 0
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

sub activate()
    if m.zone = "hero"
        if buttonCount() = 0 then return
        act = m.buttons[m.btn].act
        if act = "retry"
            refresh(invalid)
            return
        end if
        if m.heroItems.count() = 0 then return
        item = m.heroItems[m.heroIndex].item
        if act = "resume"
            m.top.request = { action: "play", item: item, resume: true }
        else if act = "start"
            m.top.request = { action: "play", item: item, resume: false }
        else
            m.top.request = { action: "details", item: item }
        end if
    else if m.zone = "dash"
        if m.dash = 0
            musicCommand("prev")
        else if m.dash = 1
            musicCommand("toggle")
        else if m.dash = 2
            musicCommand("next")
        else if m.dash = 3
            m.top.request = { action: "room", name: "Requests" }
        else
            m.top.request = { action: "mood", mood: m.moodKeys[m.dash - 4] }
        end if
    else
        card = m.rows[m.row].callFunc("current", invalid)
        if card = invalid then return
        if m.row = 0
            m.top.request = { action: "play", item: card.item, resume: true }
        else if m.row = 2
            mp = m.global.music
            if mp <> invalid then mp.command = { cmd: "playContainer", kind: "album", id: card.item.Id.toStr(), shuffle: false, label: card.title }
        else if m.row = 3
            m.top.request = { action: "room", name: "Requests" }
        else if m.row = 4
            m.top.request = { action: "room", name: "Photos" }
        else
            m.top.request = { action: "details", item: card.item }
        end if
    end if
end sub

function focusedItem() as dynamic
    if m.zone = "hero" and m.heroItems.count() > 0 then return m.heroItems[m.heroIndex].item
    if m.zone = "rows"
        card = m.rows[m.row].callFunc("current", invalid)
        if card <> invalid then return card.item
    end if
    return invalid
end function

sub moveSide(d as integer)
    if m.zone = "hero"
        n = buttonCount()
        i = m.btn + d
        if i < 0
            stepHero(-1)
            m.btn = 0
        else if i >= n
            stepHero(1)
            m.btn = 0
        else
            m.btn = i
        end if
    else if m.zone = "dash"
        x = m.dash
        if d > 0
            if x <= 4 or x = 6 then x = x + 1
        else
            if x >= 1 and x <= 3
                x = x - 1
            else if x = 4 or x = 6
                x = 3
            else if x = 5 or x = 7
                x = x - 1
            end if
        end if
        m.dash = x
    else
        m.rows[m.row].callFunc("move", d)
    end if
end sub

sub moveUp()
    if m.zone = "hero"
        hideFocus()
        m.top.request = { action: "pills" }
        return
    end if
    if m.zone = "dash"
        if m.dash >= 6
            m.dash = m.dash - 2
        else
            m.zone = "hero"
        end if
    else
        r = m.row - 1
        while r >= 0 and not rowUsable(r)
            r = r - 1
        end while
        if r >= 0 then m.row = r else m.zone = "dash"
    end if
    paint()
end sub

sub moveDown()
    if m.zone = "hero"
        m.zone = "dash"
    else if m.zone = "dash"
        if m.dash = 4 or m.dash = 5
            m.dash = m.dash + 2
        else
            r = firstRow(0)
            if r >= 0
                m.zone = "rows"
                m.row = r
            end if
        end if
    else
        r = firstRow(m.row + 1)
        if r >= 0 then m.row = r
    end if
    paint()
end sub

function firstRow(from as integer) as integer
    for r = from to m.rows.count() - 1
        if rowUsable(r) then return r
    end for
    return -1
end function

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
    if key = "back"
        if m.zone <> "hero"
            m.zone = "hero"
            paint()
            return true
        end if
        hideFocus()
        m.top.request = { action: "pills" }
        return true
    end if
    if key = "OK"
        activate()
        return true
    end if
    if key = "options"
        item = focusedItem()
        if item <> invalid then hOptions(item)
        return true
    end if
    if key = "left" or key = "right"
        if key = "left" then moveSide(-1) else moveSide(1)
        paint()
        return true
    end if
    if key = "up"
        moveUp()
        return true
    end if
    if key = "down"
        moveDown()
        return true
    end if
    return false
end function

sub hideFocus()
    for each b in m.buttons
        b.fill.visible = false
        b.ring.visible = false
        b.idle.visible = true
        b.label.color = "0xEDE6CAFF"
        b.icon.blendColor = "0xEDE6CAFF"
    end for
    for each r in m.mRings
        r.visible = false
    end for
    m.reqRing.visible = false
    for each r in m.moodRings
        r.visible = false
    end for
    for r = 0 to m.rows.count() - 1
        m.rows[r].active = false
    end for
end sub
