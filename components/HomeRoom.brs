sub init()
    m.content = m.top.findNode("content")
    m.scroll = m.top.findNode("scroll")
    m.scrollTo = m.top.findNode("scrollTo")
    m.heroArt = m.top.findNode("heroArt")
    m.heroEyebrow = m.top.findNode("heroEyebrow")
    m.heroEyebrow.font = hFont("caps", 30)
    m.heroTitle = m.top.findNode("heroTitle")
    m.heroTitle.font = hFont("caps", 84)
    m.heroBar = m.top.findNode("heroBar")
    m.heroTrack = m.top.findNode("heroTrack")
    m.top.findNode("nowEyebrow").font = hFont("caps", 26)
    m.top.findNode("nowTitle").font = hFont("bold", 38)
    m.top.findNode("nowSub").font = hFont("regular", 24)
    m.top.findNode("reqEyebrow").font = hFont("caps", 26)
    m.top.findNode("reqBig").font = hFont("bold", 64)
    m.top.findNode("reqSub").font = hFont("regular", 24)
    m.rings = [m.top.findNode("heroRing"), m.top.findNode("nowRing"), m.top.findNode("reqRing")]
    m.nextUp = m.top.findNode("nextUp")
    m.mood = m.top.findNode("mood")
    m.latest = m.top.findNode("latest")
    m.mood.cards = [{ title: "Hearth", sub: "", image: "", progress: 0 }, { title: "Rain on the roof", sub: "", image: "", progress: 0 }, { title: "Lights out", sub: "", image: "", progress: 0 }, { title: "Fireflies", sub: "", image: "", progress: 0 }]
    ' rows: 0 dashboard, 1 next up, 2 mood, 3 recently added
    m.rows = [invalid, m.nextUp, m.mood, m.latest]
    m.rowY = [0, 540, 880, 1100]
    m.row = 0
    m.dashIndex = 0
    m.hero = invalid
    m.heroMode = ""
    m.offline = false
    m.resume = []
    m.next = []
    m.new = []
    m.tasks = {}
    mp = m.global.music
    if mp <> invalid
        for each f in ["track", "state", "queue", "index"]
            mp.observeField(f, "showMusic")
        end for
    end if
    showMusic()
    refresh(invalid)
end sub

' ---------- side tiles: what's playing, and how many requests are on the way ----------
sub showMusic()
    mp = m.global.music
    eb = m.top.findNode("nowEyebrow")
    ti = m.top.findNode("nowTitle")
    su = m.top.findNode("nowSub")
    if mp = invalid or mp.track = invalid or mp.queue = invalid or mp.queue.count() = 0
        eb.text = "MUSIC"
        ti.text = "Shuffle my music"
        su.text = "Press Play for a random mix, or OK to open Music"
        return
    end if
    tr = mp.track
    if mp.state = "playing" then eb.text = "NOW PLAYING" else if mp.state = "buffering" then eb.text = "LOADING" else eb.text = "PAUSED"
    ti.text = tr.title
    line = tr.artist
    if tr.album <> invalid and tr.album <> "" then line = line + "  ·  " + tr.album
    su.text = line
end sub

sub loadRequestCount()
    reg = CreateObject("roRegistrySection", "hearth")
    if reg.Read("overseerrKey") = ""
        m.top.findNode("reqBig").text = "Set up"
        m.top.findNode("reqSub").text = "Open Requests to link Overseerr"
        return
    end if
    t = CreateObject("roSGNode", "OverseerrTask")
    t.method = "GET"
    t.path = "/api/v1/request/count"
    t.key = "reqCount"
    m.tasks.reqCount = t
    t.observeField("done", "onRequestCount")
    t.control = "RUN"
end sub

sub onRequestCount(event as object)
    t = event.getRoSGNode()
    m.tasks.delete("reqCount")
    big = m.top.findNode("reqBig")
    su = m.top.findNode("reqSub")
    r = t.response
    if not t.ok or r = invalid
        big.text = "—"
        su.text = "Couldn't reach Overseerr"
        return
    end if
    coming = cnt(r.pending) + cnt(r.processing)
    avail = cnt(r.available)
    big.text = coming.toStr()
    line = "on the way"
    if avail > 0 then line = line + "  ·  " + avail.toStr() + " ready to watch"
    su.text = line
end sub

function cnt(v as dynamic) as integer
    if v = invalid then return 0
    return v
end function

sub refresh(unused as dynamic)
    loadRequestCount()
    hPlex("resume", { limit: 12 }, "onResume")
    hPlex("nextup", { limit: 12 }, "onNextUp")
    hPlex("latest", { limit: 16 }, "onLatest")
end sub

sub onResume(event as object)
    t = hTaskFrom(event)
    m.offline = (t.status <= 0)
    if t.ok then m.resume = t.response.Items else m.resume = []
    updateHero()
end sub

sub onNextUp(event as object)
    t = hTaskFrom(event)
    m.next = []
    if t.ok then m.next = t.response.Items
    cards = []
    for each it in m.next
        cards.push(hCard(it, "wide"))
    end for
    m.nextUp.cards = cards
    m.nextUp.visible = cards.count() > 0
    updateHero()
end sub

sub onLatest(event as object)
    t = hTaskFrom(event)
    m.new = []
    if t.ok then m.new = t.response.Items
    cards = []
    for each it in m.new
        cards.push(hCard(it, "wide"))
    end for
    m.latest.cards = cards
    m.latest.visible = cards.count() > 0
    updateHero()
end sub

sub updateHero()
    item = invalid
    if m.offline
        m.heroMode = "offline"
        m.heroEyebrow.text = "CAN'T REACH YOUR LIBRARY"
        m.heroTitle.text = "PRESS OK TO TRY AGAIN"
        m.heroArt.uri = ""
        m.heroBar.width = 0
        m.heroTrack.visible = false
        m.hero = invalid
        return
    end if
    if m.resume <> invalid and m.resume.count() > 0
        item = m.resume[0]
        m.heroMode = "resume"
        eyebrow = "CONTINUE"
    else if m.next <> invalid and m.next.count() > 0
        item = m.next[0]
        m.heroMode = "next"
        eyebrow = "NEXT UP"
    else if m.new <> invalid and m.new.count() > 0
        item = m.new[0]
        m.heroMode = "new"
        eyebrow = "NEW THIS WEEK"
    end if
    m.hero = item
    if item = invalid
        m.heroEyebrow.text = "WELCOME HOME"
        m.heroTitle.text = "NOTHING HERE YET"
        m.heroArt.uri = ""
        m.heroTrack.visible = false
        m.heroBar.width = 0
        return
    end if
    sub1 = hSubtitle(item)
    if item.Type = "Episode" then eyebrow = eyebrow + " · S" + hNum(item.ParentIndexNumber) + " E" + hNum(item.IndexNumber)
    left = hMinutesLeft(item)
    if m.heroMode = "resume" and left <> "" then eyebrow = eyebrow + " · " + UCase(left)
    m.heroEyebrow.text = eyebrow
    m.heroTitle.text = UCase(hTitle(item))
    m.heroArt.uri = hImageAny(item, ["Backdrop", "Thumb", "Primary"], 1100)
    pct = hPercent(item)
    m.heroTrack.visible = pct > 0
    m.heroBar.width = 520 * pct / 100
end sub

' ---------- focus ----------
sub focusIn(unused as dynamic)
    m.top.setFocus(true)
    paint()
end sub

sub paint()
    for i = 0 to 2
        m.rings[i].visible = (m.row = 0 and m.dashIndex = i)
    end for
    for r = 1 to 3
        m.rows[r].active = (m.row = r)
    end for
    y = 0
    if m.row > 0 then y = -(m.rowY[m.row] - 40)
    m.scroll.control = "stop"
    m.scrollTo.keyValue = [m.content.translation, [0, y]]
    m.scroll.control = "start"
end sub

function rowUsable(r as integer) as boolean
    if r = 0 then return true
    return m.rows[r].callFunc("count", invalid) > 0
end function

sub restoreFocus()
    m.top.setFocus(true)
end sub

sub afterOptions()
    refresh(invalid)
end sub

sub onOptions()
    hOptionsChosen()
end sub

sub activate()
    if m.row = 0
        if m.dashIndex = 0
            if m.heroMode = "offline"
                refresh(invalid)
            else if m.hero <> invalid
                if m.heroMode = "new" and m.hero.Type = "Series"
                    m.top.request = { action: "details", item: m.hero }
                else
                    m.top.request = { action: "play", item: m.hero, resume: (m.heroMode = "resume") }
                end if
            end if
        else if m.dashIndex = 1
            m.top.request = { action: "room", name: "Music" }
        else
            m.top.request = { action: "room", name: "Requests" }
        end if
        return
    end if
    card = m.rows[m.row].callFunc("current", invalid)
    if card = invalid then return
    if m.row = 1
        m.top.request = { action: "play", item: card.item, resume: true }
    else if m.row = 2
        moods = ["hearth", "rain", "lightsout", "fireflies"]
        m.top.request = { action: "mood", mood: moods[m.mood.index] }
    else
        m.top.request = { action: "details", item: card.item }
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
    if key = "back"
        hideFocus()
        m.top.request = { action: "pills" }
        return true
    end if
    if key = "OK"
        activate()
        return true
    end if
    if key = "options"
        item = invalid
        if m.row = 0 and m.dashIndex = 0 then item = m.hero
        if m.row = 1 or m.row = 3
            card = m.rows[m.row].callFunc("current", invalid)
            if card <> invalid then item = card.item
        end if
        if item <> invalid then hOptions(item)
        return true
    end if
    if key = "left" or key = "right"
        if key = "left" then d = -1 else d = 1
        if m.row = 0
            i = m.dashIndex + d
            if i >= 0 and i <= 2 then m.dashIndex = i
        else
            m.rows[m.row].callFunc("move", d)
        end if
        paint()
        return true
    end if
    if key = "up"
        r = m.row - 1
        while r > 0 and not rowUsable(r)
            r = r - 1
        end while
        if m.row = 0
            hideFocus()
            m.top.request = { action: "pills" }
            return true
        end if
        m.row = r
        paint()
        return true
    end if
    if key = "down"
        r = m.row + 1
        while r <= 3 and not rowUsable(r)
            r = r + 1
        end while
        if r <= 3 then m.row = r
        paint()
        return true
    end if
    return false
end function

sub hideFocus()
    for each ring in m.rings
        ring.visible = false
    end for
    for r = 1 to 3
        m.rows[r].active = false
    end for
end sub
