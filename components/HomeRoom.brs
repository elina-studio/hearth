' Home. Focus zones, top to bottom:
'   "hero"  Resume / From start / Details. Left on the first button or Right on the last steps to the
'           previous or next of the top 3 Continue items.
'   "dash"  0 prev, 1 play/pause, 2 next, 8 like, 9 radio (Now playing; when idle 0 shuffle, 1 rediscover, 2 favourites), 3 Requests, 4..7 the 2x2 mood tiles
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
    m.mRings = [m.top.findNode("mRing0"), m.top.findNode("mRing1"), m.top.findNode("mRing2"), m.top.findNode("mRing3"), m.top.findNode("mRing4")]
    m.mDash = [0, 1, 2, 8, 9]
    m.mRing5 = m.top.findNode("mRing5")
    m.spkOpen = false
    m.spkIdx = 0
    m.spkRows = []
    m.top.findNode("spkTitle").font = hFont("caps", 20)
    holder = m.top.findNode("spkRows")
    for i = 0 to 4
        bg = holder.createChild("Rectangle")
        bg.translation = [0, i * 30]
        bg.width = 364
        bg.height = 28
        bg.color = "0x00000000"
        nm = holder.createChild("Label")
        nm.translation = [10, i * 30]
        nm.width = 230
        nm.height = 28
        nm.vertAlign = "center"
        nm.font = hFont("regular", 20)
        st = holder.createChild("Label")
        st.translation = [244, i * 30]
        st.width = 110
        st.height = 28
        st.vertAlign = "center"
        st.horizAlign = "right"
        st.font = hFont("regular", 18)
        m.spkRows.push({ bg: bg, nm: nm, st: st })
    end for
    m.top.findNode("mSpk").font = hFont("regular", 22)
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
    buildTonight()
    buildMoods()
    buildReqLines()

    m.zone = "hero"
    m.btn = 0
    m.dash = 1
    m.row = 0
    m.heroIndex = 0
    m.heroItems = []
    m.offline = false
    m.tn = 0
    m.tBump = 0
    m.tMovies = []
    m.tLists = []
    m.tData = []
    m.resume = []
    m.next = []
    m.new = []
    m.heroNext = invalid
    m.heroNextAsk = {}
    m.tasks = {}
    mp = m.global.music
    if mp <> invalid
        for each f in ["track", "state", "queue", "index", "position", "rooms", "castCount", "liked", "radioOn"]
            mp.observeField(f, "showMusic")
        end for
    end if
    showGreeting()
    showMusic()
    refresh(invalid)
end sub

' ---------- Tonight: a short episode, a film and a playlist picked for the time of day ----------
sub buildTonight()
    m.tCards = []
    m.top.findNode("tnTitle").font = hFont("fell", 34)
    m.top.findNode("tnNote").font = hFont("regular", 20)
    holder = m.top.findNode("tnCards")
    icons = ["episode", "film", "home-note"]
    for i = 0 to 2
        g = holder.createChild("Group")
        g.translation = [i * 316, 0]
        back = g.createChild("Rectangle")
        back.width = 296
        back.height = 90
        back.color = "0x1C2418FF"
        art = g.createChild("Poster")
        art.width = 296
        art.height = 90
        art.loadDisplayMode = "scaleToZoom"
        ic = g.createChild("Poster")
        ic.uri = "pkg:/images/icons/" + icons[i] + ".png"
        ic.width = 22
        ic.height = 22
        ic.translation = [0, 102]
        ic.blendColor = "0xE0B34AFF"
        kick = g.createChild("Label")
        kick.font = hFont("caps", 17)
        kick.translation = [30, 100]
        kick.height = 26
        kick.vertAlign = "center"
        kick.color = "0xE0B34AFF"
        ttl = g.createChild("Label")
        ttl.font = hFont("bold", 24)
        ttl.translation = [0, 128]
        ttl.width = 296
        ttl.maxLines = 1
        ttl.color = "0xEDE6CAFF"
        ring = g.createChild("Poster")
        ring.uri = "pkg:/images/ring" + hVar(i + 2) + ".9.png"
        ring.blendColor = "0xD9A066FF"
        ring.translation = [-10, -10]
        ring.width = 316
        ring.height = 176
        ring.visible = false
        g.addFields({ art: art, kick: kick, ttl: ttl, ring: ring })
        g.visible = false
        m.tCards.push(g)
    end for
end sub

sub onTonightMovies(event as object)
    t = hTaskFrom(event)
    m.tMovies = []
    if t.ok and t.response.Items <> invalid then m.tMovies = t.response.Items
    pickTonight()
end sub

sub onTonightLists(event as object)
    t = hTaskFrom(event)
    m.tLists = pxItems(t)
    pickTonight()
end sub

function tnMinutes(item as object) as integer
    if item = invalid or item.RunTimeTicks = invalid then return 0
    return Int(item.RunTimeTicks / 600000000)
end function

function tnLen(min as integer) as string
    if min >= 60
        r = min mod 60
        if r = 0 then return Int(min / 60).toStr() + " h"
        return Int(min / 60).toStr() + " h " + r.toStr()
    end if
    return min.toStr() + " min"
end function

function tnPlayed(item as object) as boolean
    return item.UserData <> invalid and item.UserData.Played = true
end function

' One pick of each kind. Time of day sets the length budget; the date and time bucket seed the choice, so the
' same three stay all evening and change tomorrow.
sub pickTonight()
    t = CreateObject("roDateTime")
    t.toLocalTime()
    h = t.getHours()
    dow = t.getDayOfWeek()
    late = (h >= 22 or h < 5)
    bucket = 0
    note = "Morning"
    if late
        bucket = 3
        note = "Late evening"
    else if h >= 17
        bucket = 2
        note = "Evening"
    else if h >= 11
        bucket = 1
        note = "Afternoon"
    end if
    epMax = 45
    if bucket = 2 then epMax = 35
    if late then epMax = 25
    movieMax = 180
    if late or (bucket = 2 and dow <= 4) then movieMax = 100
    seed = t.getYear() * 372 + t.getMonth() * 31 + t.getDayOfMonth() + bucket * 7 + m.tBump

    out = []
    ' a short episode: next up, unwatched, within the budget (else the shortest one there is)
    c = []
    shortest = invalid
    for each it in m.next
        mins = tnMinutes(it)
        if it.Type = "Episode" and mins > 0 and not tnPlayed(it)
            if mins <= epMax then c.push(it)
            if shortest = invalid or mins < tnMinutes(shortest) then shortest = it
        end if
    end for
    if c.count() = 0 and shortest <> invalid then c.push(shortest)
    if c.count() > 0
        it = c[seed mod c.count()]
        card = hCard(it, "wide")
        out.push({ kind: "ep", item: it, title: card.title, kick: "A QUICK ONE · " + UCase(tnLen(tnMinutes(it))), image: card.image })
    end if
    ' a film that fits tonight
    c = []
    for each it in m.tMovies
        mins = tnMinutes(it)
        if it.Type = "Movie" and mins > 0 and mins <= movieMax and not tnPlayed(it) then c.push(it)
    end for
    if c.count() > 0
        it = c[(seed * 3 + 1) mod c.count()]
        card = hCard(it, "wide")
        out.push({ kind: "film", item: it, title: card.title, kick: "A FILM · " + UCase(tnLen(tnMinutes(it))), image: card.image })
    end if
    ' a playlist: calm ones for evening and late
    c = []
    calm = []
    rx = CreateObject("roRegex", "calm|quiet|soft|sleep|wind|chill|night|evening|ambient|relax|mellow|lull", "i")
    for each md in m.tLists
        if md.leafCount <> invalid and md.leafCount > 0
            c.push(md)
            if rx.isMatch(pxStr(md.title)) then calm.push(md)
        end if
    end for
    if bucket >= 2 and calm.count() > 0 then c = calm
    if c.count() > 0
        md = c[(seed * 5 + 2) mod c.count()]
        mins = 0
        if md.duration <> invalid then mins = Int(md.duration / 60000)
        k = "A PLAYLIST"
        if mins > 0 then k = k + " · " + UCase(tnLen(mins))
        th = md.composite
        if th = invalid then th = md.thumb
        out.push({ kind: "list", item: md, title: pxStr(md.title), kick: k, image: pxImage(th, 300, 300) })
    end if
    m.tData = out
    m.top.findNode("tnNote").text = note
    for i = 0 to 2
        g = m.tCards[i]
        if i < out.count()
            g.art.uri = out[i].image
            g.kick.text = out[i].kick
            g.ttl.text = out[i].title
            g.visible = true
        else
            g.visible = false
        end if
    end for
    m.top.findNode("tonight").visible = out.count() > 0
    if m.tn >= out.count() then m.tn = 0
end sub

' ---------- hero buttons ----------
sub buildButtons()
    m.buttons = []
    holder = m.top.findNode("buttons")
    for i = 0 to 2
        b = holder.createChild("Group")
        b.addFields({ idle: b.createChild("Poster"), fill: b.createChild("Poster"), ring: b.createChild("Poster") })
        b.idle.uri = "pkg:/images/pill-ring" + hVar(i) + ".9.png"
        b.idle.blendColor = "0xB5AF8CAA"
        b.fill.uri = "pkg:/images/pill" + hVar(i) + ".9.png"
        b.fill.blendColor = "0xE0B34AFF"
        b.ring.uri = "pkg:/images/ring" + hVar(i + 3) + ".9.png"
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
    ' natural widths first; if the row would run past the hero text column (into Tonight), the first
    ' button's label gives way and ends in an ellipsis
    ws = []
    total = 0
    for i = 0 to 2
        b = m.buttons[i]
        b.label.width = 0
        if i < kinds.count()
            b.label.text = kinds[i][1]
            w = Int(b.label.localBoundingRect().width) + 86
            ws.push(w)
            total = total + w + 12
        end if
    end for
    over = total - 12 - 690
    if over > 0 and ws.count() > 1
        w0 = ws[0] - over
        if w0 < 220 then w0 = 220
        ws[0] = w0
        m.buttons[0].label.width = w0 - 86
    end if
    x = 0
    for i = 0 to 2
        b = m.buttons[i]
        if i < kinds.count()
            k = kinds[i]
            b.act = k[0]
            b.icon.uri = "pkg:/images/icons/" + k[2] + ".png"
            w = ws[i]
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
function inArr(a as object, v as integer) as boolean
    return indexOfArr(a, v) >= 0
end function

function indexOfArr(a as object, v as integer) as integer
    for i = 0 to a.count() - 1
        if a[i] = v then return i
    end for
    return -1
end function

' the card's buttons, in left-to-right order
function musicSeq() as object
    if musicIdle()
        if lastPlayed() <> invalid then return [0, 1, 2, 8]
        return [0, 1, 2]
    end if
    return [0, 1, 2, 8, 9]
end function

' the last thing played, saved by the player: { mode: "c" | "r" | "s", kind, id, label }
function lastPlayed() as dynamic
    reg = CreateObject("roRegistrySection", "hearth")
    v = reg.Read("lastPlay")
    if v = invalid or v = "" then return invalid
    p = v.Split("|")
    if p.count() < 4 then return invalid
    return { mode: p[0], kind: p[1], id: p[2], label: p[3] }
end function

function musicIdle() as boolean
    mp = m.global.music
    return mp = invalid or mp.track = invalid or mp.queue = invalid or mp.queue.count() = 0
end function

' idle: the three buttons start something. 0 shuffle everything, 1 songs not heard lately, 2 favourites
sub idleStart(i as integer)
    mp = m.global.music
    if mp = invalid then return
    lp = lastPlayed()
    if i = 0 and lp <> invalid
        if lp.mode = "c"
            mp.command = { cmd: "playContainer", kind: lp.kind, id: lp.id, shuffle: false, label: lp.label }
        else if lp.mode = "r"
            mp.command = { cmd: "radioStart", kind: lp.kind, mood: lp.id, moodName: lp.label }
        else
            mp.command = { cmd: "shuffleAll" }
        end if
    else if i = 8 or i = 0
        mp.command = { cmd: "shuffleAll" }
    else if i = 1
        mp.command = { cmd: "radioStart", kind: "forgotten" }
    else if i = 2
        mp.command = { cmd: "radioStart", kind: "favs" }
    end if
end sub

' the speakers the music is going to: "This TV", "Kitchen", "Kitchen + 1"
function speakerLine() as string
    mp = m.global.music
    if mp = invalid or mp.castCount = invalid or mp.castCount < 1 then return "This TV"
    names = []
    for each r in mp.rooms
        if r.kind <> "tv" and r.on = true then names.push(pxStr(r.name))
    end for
    if names.count() = 0 then return "This TV"
    line = names[0]
    if names.count() > 1 then line = line + " + " + (names.count() - 1).toStr()
    if mp.rooms[0].on = true then line = "TV + " + line
    return line
end function

' ---------- Now playing / Listen now ----------
sub showMusic()
    if m.spkOpen = true then drawSpeakers()
    ' the like and radio buttons come and go with the music; focus on one that is gone would be invisible and dead
    if (m.dash = 8 or m.dash = 9) and not inArr(musicSeq(), m.dash)
        m.dash = 1
        paint()
    end if
    mp = m.global.music
    eb = m.top.findNode("musicEyebrow")
    ti = m.top.findNode("musicTitle")
    su = m.top.findNode("musicSub")
    art = m.top.findNode("musicArt")
    tog = m.top.findNode("mToggle")
    prv = m.top.findNode("mPrev")
    nxt = m.top.findNode("mNext")
    lk = m.top.findNode("mLike")
    rd = m.top.findNode("mRadio")
    sp = m.top.findNode("mSpk")
    spi = m.top.findNode("mSpkIcon")
    if musicIdle()
        dt = CreateObject("roDateTime")
        dt.ToLocalTime()
        h = dt.GetHours()
        if h < 12
            when = "Morning"
        else if h < 18
            when = "Afternoon"
        else
            when = "Evening"
        end if
        lp = lastPlayed()
        art.uri = ""
        if lp <> invalid
            eb.text = "PICK UP WHERE YOU LEFT OFF"
            setMusicTitle(ti, pxStr(lp.label))
            su.text = "OK to play it again"
            prv.uri = "pkg:/images/icons/home-play.png"
            lk.uri = "pkg:/images/music/icons/shuffle.png"
            lk.visible = true
        else
            eb.text = "LISTEN NOW"
            setMusicTitle(ti, when + " music")
            su.text = "Shuffle, rediscover, or favourites"
            prv.uri = "pkg:/images/music/icons/shuffle.png"
            lk.visible = false
        end if
        tog.uri = "pkg:/images/icons/history.png"
        nxt.uri = "pkg:/images/music/icons/heart.png"
        lk.blendColor = "0xEDE6CAFF"
        rd.visible = false
        sp.text = speakerLine()
        m.musicBar.width = 0
        return
    end if
    lk.visible = true
    lk.uri = "pkg:/images/music/icons/heart.png"
    rd.visible = true
    prv.uri = "pkg:/images/icons/home-prev.png"
    nxt.uri = "pkg:/images/icons/home-next.png"
    tr = mp.track
    if mp.state = "playing"
        eb.text = "NOW PLAYING"
    else if mp.state = "buffering"
        eb.text = "LOADING"
    else
        eb.text = "PAUSED"
    end if
    if mp.radioOn = true then eb.text = eb.text + " · RADIO"
    if mp.state = "playing" or mp.state = "buffering"
        tog.uri = "pkg:/images/icons/home-pause.png"
    else
        tog.uri = "pkg:/images/icons/home-play.png"
    end if
    if mp.liked = "like" then lk.blendColor = "0xE0B34AFF" else lk.blendColor = "0xEDE6CAFF"
    setMusicTitle(ti, pxStr(tr.title))
    line = pxStr(tr.artist)
    if tr.album <> invalid and tr.album <> "" then line = line + " · " + tr.album
    su.text = line
    sp.text = speakerLine()
    u = pxImage(tr.thumb, 180, 180)
    if art.uri <> u then art.uri = u
    w = 0
    if mp.duration > 0 then w = Int(352 * mp.position / mp.duration)
    if w > 352 then w = 352
    m.musicBar.width = w
end sub

' ---------- the speaker picker, drawn over the card ----------
sub openSpeakers()
    mp = m.global.music
    if mp = invalid then return
    mp.command = { cmd: "castRefresh" }
    m.spkOpen = true
    m.spkIdx = 0
    m.top.findNode("spkPanel").visible = true
    m.mRing5.visible = false
    drawSpeakers()
end sub

sub closeSpeakers()
    m.spkOpen = false
    m.top.findNode("spkPanel").visible = false
end sub

function speakerItems() as object
    mp = m.global.music
    items = []
    if mp <> invalid and mp.rooms <> invalid then items.append(mp.rooms)
    items.push({ id: "all", name: "Whole house", kind: "all", on: false, vol: -1 })
    return items
end function

sub drawSpeakers()
    items = speakerItems()
    if m.spkIdx >= items.count() then m.spkIdx = items.count() - 1
    top = 0
    if m.spkIdx > 4 then top = m.spkIdx - 4
    for i = 0 to 4
        r = m.spkRows[i]
        at = top + i
        if at < items.count()
            it = items[at]
            r.nm.visible = true
            r.st.visible = true
            r.nm.text = pxStr(it.name)
            if it.kind = "all"
                r.st.text = ""
            else if it.on = true
                if it.vol <> invalid and it.vol >= 0 then r.st.text = "on · " + it.vol.toStr() + "%" else r.st.text = "on"
            else
                r.st.text = "off"
            end if
            if it.on = true then r.nm.color = "0xE0B34AFF" else r.nm.color = "0xEDE6CAFF"
            r.st.color = "0xB5AF8CFF"
            if at = m.spkIdx then r.bg.color = "0x2E3B22FF" else r.bg.color = "0x00000000"
        else
            r.nm.visible = false
            r.st.visible = false
            r.bg.color = "0x00000000"
        end if
    end for
end sub

sub speakerKey(key as string)
    mp = m.global.music
    items = speakerItems()
    if key = "back"
        closeSpeakers()
        paint()
        return
    end if
    if key = "up"
        if m.spkIdx > 0 then m.spkIdx = m.spkIdx - 1
    else if key = "down"
        if m.spkIdx < items.count() - 1 then m.spkIdx = m.spkIdx + 1
    else if key = "OK" and mp <> invalid
        it = items[m.spkIdx]
        if it.kind = "all" then mp.command = { cmd: "castAll" } else mp.command = { cmd: "castToggle", id: it.id }
    else if (key = "left" or key = "right") and mp <> invalid
        it = items[m.spkIdx]
        if it.kind = "speaker"
            d = 5
            if key = "left" then d = -5
            mp.command = { cmd: "castVolume", id: it.id, delta: d }
        end if
    end if
    drawSpeakers()
end sub

sub musicCommand(cmd as string)
    mp = m.global.music
    if mp <> invalid then mp.command = { cmd: cmd }
end sub

' ---------- Requests card: what just finished downloading (newest first), plus a count of what is still on the way ----------
sub buildReqLines()
    m.reqNote = m.top.findNode("reqNote")
    m.reqNote.font = hFont("regular", 22)
    m.reqEmpty = m.top.findNode("reqEmpty")
    m.reqEmpty.font = hFont("regular", 26)
    m.reqEmpty.text = "Looking for new arrivals..."
    m.reqCells = []
    holder = m.top.findNode("reqLines")
    for i = 0 to 4
        g = holder.createChild("Group")
        g.translation = [i * 98, 0]
        back = g.createChild("Rectangle")
        back.width = 84
        back.height = 126
        back.color = "0xFFFFFF14"
        pic = g.createChild("Poster")
        pic.width = 84
        pic.height = 126
        pic.loadDisplayMode = "scaleToZoom"
        nm = g.createChild("Label")
        nm.font = hFont("regular", 18)
        nm.width = 90
        nm.height = 24
        nm.translation = [0, 130]
        nm.maxLines = 1
        nm.color = "0xEDE6CAFF"
        g.addFields({ pic: pic, name: nm })
        g.visible = false
        m.reqCells.push(g)
    end for
end sub

' Overseerr is only used for the little "downloading" count in the corner; the posters come from Plex
sub loadRequests()
    reg = CreateObject("roRegistrySection", "hearth")
    if reg.Read("overseerrKey") <> "" and m.tasks.req = invalid
        t = CreateObject("roSGNode", "OverseerrTask")
        t.mode = "requests"
        t.query = { take: "20" }
        m.tasks.req = t
        t.observeField("done", "onRequests")
        t.control = "RUN"
    end if
    if m.tasks.arr = invalid
        m.tasks.arr = true
        hPlex("arrived", { limit: 12 }, "onArrivedHome")
    end if
end sub

sub onRequests(event as object)
    t = event.getRoSGNode()
    m.tasks.delete("req")
    if not t.ok or t.response = invalid or t.response.results = invalid then return
    going = 0
    failed = 0
    for each r in t.response.results
        q = r.request
        if rqNum(q.status) = 4
            failed = failed + 1
        else if rqNum(q.status) <> 3 and rqProgress(q.media) >= 0
            going = going + 1
        end if
    end for
    if failed > 0
        m.reqNote.color = "0xF0907CFF"
        m.reqNote.text = failed.toStr() + " failed"
    else if going > 0
        m.reqNote.color = "0xA3A35AFF"
        m.reqNote.text = going.toStr() + " downloading"
    else
        m.reqNote.text = ""
    end if
end sub

sub onArrivedHome(event as object)
    t = hTaskFrom(event)
    m.tasks.delete("arr")
    items = []
    seen = {}
    if t.ok and t.response <> invalid and t.response.Items <> invalid
        for each it in t.response.Items
            key = it.Id
            if it.Type = "Episode" and it.SeriesId <> invalid then key = it.SeriesId
            if key <> invalid and seen[key] = invalid
                c = rqArrivedCard(it, hImage(it, "Primary", 200))
                if c <> invalid
                    seen[key] = true
                    items.push(c)
                end if
            end if
        end for
    end if
    for i = 0 to 4
        g = m.reqCells[i]
        if i < items.count()
            g.pic.uri = items[i].image
            g.name.text = items[i].title
            g.visible = true
        else
            g.visible = false
        end if
    end for
    if items.count() > 0
        m.reqEmpty.text = ""
    else if not t.ok
        m.reqEmpty.text = "Couldn't reach Plex"
    else
        m.reqEmpty.text = "Nothing new yet"
    end if
    rcards = []
    for each c in items
        rcards.push({ title: c.title, sub: c.chip.text, image: c.image, progress: 0, item: c.data })
    end for
    setRow(3, rcards)
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
        ring.uri = "pkg:/images/ring" + hVar(i + 1) + ".9.png"
        ring.blendColor = "0xD9A066FF"
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
        if libs.movies <> invalid then hPlex("latest", { section: libs.movies, limit: 60 }, "onTonightMovies")
    end if
    pxApi("/playlists", { playlistType: "audio" }, "onTonightLists", "tonight")
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
    pickTonight()
end sub

sub onLatest(event as object)
    t = hTaskFrom(event)
    ' launch warm-up: the shelves are filled once the library list is known (an earlier answer is refreshed after it)
    if m.global.libraries <> invalid and m.global.libraries.count() > 0 then m.top.ready = true
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

' Now Playing card title: 30, then 26, then 22 on one line; longer still scrolls
sub setMusicTitle(ti as object, t as string)
    drop = hFitTitle(ti, t, "bold", [30, 26, 22], 350)
    ti.translation = [228, 64 + drop]
end sub

' Hero title: 70, then 56, then 46 on one line; longer still scrolls
sub setHeroTitle(t as string)
    ' the hero panel is the left half only (x 84 to 824), so the title gets 680
    drop = hFitTitle(m.heroTitle, t, "caps", [70, 56, 46, 38], 680)
    m.heroTitle.translation = [136, 48 + drop]
end sub

sub showHero()
    if m.heroItems.count() = 0
        m.heroArt.uri = ""
        m.heroProgress.visible = false
        m.pager.visible = false
        if m.offline
            m.heroEyebrow.text = "CAN'T REACH YOUR LIBRARY"
            setHeroTitle("TRY AGAIN IN A MOMENT")
            setButtons([["retry", "Try again", "home-restart"]])
        else
            m.heroEyebrow.text = "WELCOME HOME"
            setHeroTitle("NOTHING HERE YET")
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
    setHeroTitle(UCase(hTitle(item)))
    m.heroArt.uri = hImageAny(item, ["Backdrop", "Thumb", "Primary"], 1920)
    pct = hPercent(item)
    m.heroProgress.visible = pct > 0
    m.heroBar.width = Int(300 * pct / 100)
    m.heroLeft.text = hMinutesLeft(item)
    nxt = invalid
    if h.label = "CONTINUE" and heroFinished(item) then nxt = heroNextFor(item)
    m.heroNext = nxt
    if nxt <> invalid
        lab = "Next: S" + hNum(nxt.ParentIndexNumber) + " · E" + hNum(nxt.IndexNumber)
        if nxt.Name <> invalid and nxt.Name <> "" then lab = lab + " " + Chr(8220) + nxt.Name + Chr(8221)
        setButtons([["nextEp", lab, "home-next"], ["start", "Watch E" + hNum(item.IndexNumber) + " again", "home-restart"], ["details", "Details", "home-info"]])
    else if item.Type = "Series"
        setButtons([["details", "Open", "home-info"]])
    else if pct > 0
        setButtons([["resume", "Resume", "home-play"], ["start", "From start", "home-restart"], ["details", "Details", "home-info"]])
    else
        setButtons([["start", "Play", "home-play"], ["details", "Details", "home-info"]])
    end if
    showPager()
    paint()
end sub

' An episode you watched to the credits (or Plex marked played) that still sits in Continue.
function heroFinished(item as object) as boolean
    if item.Type <> "Episode" or item.SeriesId = invalid then return false
    return (item.UserData <> invalid and item.UserData.Played = true) or hPercent(item) >= 85
end function

' The episode after item: from Next up when it is there, else asked of Plex once (onHeroNext re-shows the hero).
function heroNextFor(item as object) as dynamic
    s = item.ParentIndexNumber
    e = item.IndexNumber
    for each it in m.next
        if it.Type = "Episode" and it.SeriesId <> invalid and it.SeriesId.toStr() = item.SeriesId.toStr() and it.Id <> item.Id
            if s = invalid or e = invalid or it.ParentIndexNumber = invalid or it.IndexNumber = invalid then return it
            if it.ParentIndexNumber > s or (it.ParentIndexNumber = s and it.IndexNumber > e) then return it
        end if
    end for
    if m.heroNextAsk = invalid then m.heroNextAsk = {}
    key = item.Id.toStr()
    if m.heroNextAsk.doesExist(key)
        got = m.heroNextAsk[key]
        if type(got) = "roAssociativeArray" then return got
        return invalid
    end if
    m.heroNextAsk[key] = false
    hPlex("nextEp", { show: item.SeriesId.toStr(), id: key }, "onHeroNext", key)
    return invalid
end function

sub onHeroNext(event as object)
    t = hTaskFrom(event)
    n = t.response
    if not t.ok or n = invalid or n.Id = invalid then return
    if m.heroNextAsk = invalid then m.heroNextAsk = {}
    m.heroNextAsk[t.tag] = n
    if m.heroItems.count() > m.heroIndex and m.heroItems[m.heroIndex].item.Id.toStr() = t.tag
        keepBtn = m.btn
        showHero()
        if keepBtn < buttonCount() then m.btn = keepBtn
        paint()
    end if
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
    ' just the dots now (the Tonight picks sit to the right): they end at the divider
    m.pgText.visible = false
    m.top.findNode("pgRight").visible = false
    m.top.findNode("pgLeft").visible = false
    dw = x - 12
    m.dots.translation = [776 - dw, 0]
end sub

sub stepHero(d as integer)
    n = m.heroItems.count()
    if n <= 1 then return
    m.heroIndex = (m.heroIndex + d + n) mod n
    showHero()
end sub

' ---------- focus ----------
sub focusIn(opts as dynamic)
    ' coming down from the pills always lands on the hero's first button, not wherever you were last;
    ' coming back from a screen (opts.keep) stays where it was, if that spot still exists
    keep = (type(opts) = "roAssociativeArray" and opts.keep = true)
    if keep and m.zone = "rows" and not rowUsable(m.row) then keep = false
    if not keep
        m.zone = "hero"
        m.btn = 0
    end if
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
    seq = musicSeq()
    for i = 0 to 4
        m.mRings[i].visible = focused and m.zone = "dash" and m.dash = m.mDash[i] and inArr(seq, m.mDash[i]) and not m.spkOpen
    end for
    m.mRing5.visible = focused and m.zone = "dash" and m.dash = 10 and not m.spkOpen
    m.reqRing.visible = focused and m.zone = "dash" and m.dash = 3
    for i = 0 to 2
        m.tCards[i].ring.visible = focused and m.zone = "tonight" and m.tn = i
    end for
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
        if act = "nextEp" and m.heroNext <> invalid
            m.top.request = { action: "play", item: m.heroNext, resume: (hPercent(m.heroNext) > 0) }
        else if act = "resume"
            m.top.request = { action: "play", item: item, resume: true }
        else if act = "start"
            m.top.request = { action: "play", item: item, resume: false }
        else
            m.top.request = { action: "details", item: item }
        end if
    else if m.zone = "tonight"
        if m.tn >= m.tData.count() then return
        d = m.tData[m.tn]
        if d.kind = "list"
            mp = m.global.music
            if mp <> invalid then mp.command = { cmd: "playContainer", kind: "playlist", id: pxStr(d.item.ratingKey), shuffle: false, label: d.title }
        else
            m.top.request = { action: "play", item: d.item, resume: true }
        end if
    else if m.zone = "dash"
        if m.dash = 10
            openSpeakers()
        else if musicIdle()
            idleStart(m.dash)
        else if m.dash = 0
            musicCommand("prev")
        else if m.dash = 1
            musicCommand("toggle")
        else if m.dash = 2
            musicCommand("next")
        else if m.dash = 8
            mp = m.global.music
            if mp <> invalid then mp.command = { cmd: "rate", value: "like" }
        else if m.dash = 9
            mp = m.global.music
            if mp <> invalid then mp.command = { cmd: "radioStart", kind: "song" }
        else if m.dash = 3
            m.top.request = { action: "room", name: "Requests", tab: "new" }
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
            m.top.request = { action: "room", name: "Requests", tab: "new" }
        else if m.row = 4
            m.top.request = { action: "room", name: "Photos" }
        else
            m.top.request = { action: "details", item: card.item }
        end if
    end if
end sub

function focusedItem() as dynamic
    if m.zone = "hero" and m.heroItems.count() > 0 then return m.heroItems[m.heroIndex].item
    if m.zone = "tonight" and m.tn < m.tData.count() and m.tData[m.tn].kind <> "list" then return m.tData[m.tn].item
    ' only the two video rows hold Plex video items; album, request and photo cards must not get the watched/details menu
    if m.zone = "rows" and m.row <= 1
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
            if m.heroIndex >= m.heroItems.count() - 1 and m.tData.count() > 0
                m.zone = "tonight"
                m.tn = 0
            else
                stepHero(1)
                m.btn = 0
            end if
        else
            m.btn = i
        end if
    else if m.zone = "tonight"
        i = m.tn + d
        if i < 0
            m.zone = "hero"
            m.btn = buttonCount() - 1
            if m.btn < 0 then m.btn = 0
        else if i < m.tData.count()
            m.tn = i
        end if
    else if m.zone = "dash"
        x = m.dash
        seq = musicSeq()
        if x = 10
            ' the speaker line has nothing to either side
        else if d > 0
            at = indexOfArr(seq, x)
            if at >= 0 and at < seq.count() - 1
                x = seq[at + 1]
            else if at >= 0
                x = 3
            else if x <= 4 or x = 6
                x = x + 1
            end if
        else
            at = indexOfArr(seq, x)
            if at > 0
                x = seq[at - 1]
            else if x = 3
                x = seq[seq.count() - 1]
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
    if m.zone = "hero" or m.zone = "tonight"
        hideFocus()
        m.top.request = { action: "pills" }
        return
    end if
    if m.zone = "dash"
        if m.dash = 6 or m.dash = 7
            m.dash = m.dash - 2
        else if inArr(musicSeq(), m.dash)
            m.dash = 10
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
    if m.zone = "hero" or m.zone = "tonight"
        m.zone = "dash"
    else if m.zone = "dash"
        if m.dash = 10
            m.dash = 1
        else if m.dash = 4 or m.dash = 5
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
    if m.spkOpen
        speakerKey(key)
        return true
    end if
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
    m.mRing5.visible = false
    closeSpeakers()
    m.reqRing.visible = false
    for each c in m.tCards
        c.ring.visible = false
    end for
    for each r in m.moodRings
        r.visible = false
    end for
    for r = 0 to m.rows.count() - 1
        m.rows[r].active = false
    end for
end sub
