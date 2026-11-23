sub init()
    m.title = m.top.findNode("title")
    m.title.font = hFont("fell", 40)
    m.icon = m.top.findNode("icon")
    m.twig = m.top.findNode("twig")
    m.count = m.top.findNode("count")
    m.count.font = hFont("bold", 24)
    m.strip = m.top.findNode("strip")
    m.gap = 24
end sub

sub onTitle()
    m.title.text = m.top.title
    m.icon.visible = m.top.icon <> ""
    if m.top.icon <> "" then m.icon.uri = m.top.icon
    tw = m.title.boundingRect().width
    s = (m.top.seed mod 4) + 4
    ' the twig starts after the title: the short one for long titles
    if tw > 230
        m.twig.uri = "pkg:/images/w/twig-1220-s" + s.toStr() + ".png"
        m.twig.width = 1260
        m.twig.translation = [354, -32]
    else
        m.twig.uri = "pkg:/images/w/twig-1290-s" + s.toStr() + ".png"
        m.twig.width = 1330
        m.twig.translation = [284, -32]
    end if
    m.twig.height = 120
    paintCount()
end sub

sub paintCount()
    n = 0
    if m.top.cards <> invalid then n = m.top.cards.count()
    if m.top.countNoun = "" or n = 0
        m.count.text = ""
        return
    end if
    m.count.text = UCase(n.toStr() + " " + m.top.countNoun)
    m.count.width = 400
    m.count.translation = [m.top.viewWidth - 400, 4]
end sub

' A stable 0-3 for a card, so it always gets the same moss
function mossKind(c as object) as integer
    k = ""
    if c.item <> invalid and c.item.Id <> invalid then k = c.item.Id.toStr()
    if k = "" and c.title <> invalid then k = c.title
    h = 0
    for i = 1 to Len(k)
        h = (h * 31 + Asc(Mid(k, i, 1))) mod 1000003
    end for
    return (h mod 4) + 1
end function

' Only the cards that fit on screen (plus one either side) exist as nodes. They are reused as the row scrolls,
' so a 300-title row costs the same as a 7-title one and the visible posters load first.
sub build()
    w = m.top.cardWidth
    h = m.top.cardHeight
    n = m.top.cards.count()
    slots = Int(m.top.viewWidth / (w + m.gap)) + 3
    if slots > n then slots = n
    if m.slotW <> w or m.slotH <> h or m.strip.getChildCount() <> slots
        m.strip.removeChildrenIndex(m.strip.getChildCount(), 0)
        for k = 0 to slots - 1
            makeSlot(w, h, k)
        end for
        m.slotW = w
        m.slotH = h
    end if
    m.slotFor = []
    for k = 0 to slots - 1
        m.slotFor.push(-1)
    end for
    extra = 0
    if m.top.showCaption then extra = 96
    m.top.rowHeight = 74 + h + extra
    paintCount()
    if m.top.index >= n then m.top.index = 0
    paint()
end sub

sub makeSlot(w as integer, h as integer, k as integer)
    g = m.strip.createChild("Group")
    bg = g.createChild("Rectangle")
    bg.width = w
    bg.height = h
    bg.color = "0x1D2418FF"
    fb = g.createChild("Label")
    fb.width = w - 30
    fb.height = h - 20
    fb.translation = [15, 10]
    fb.wrap = true
    fb.vertAlign = "center"
    fb.horizAlign = "center"
    fb.font = hFont("bold", 18)
    fb.color = "0xEDE6CAFF"
    p = g.createChild("Poster")
    p.width = w
    p.height = h
    p.loadDisplayMode = "scaleToZoom"
    hFbWatch(p)
    if m.top.maskUri <> ""
        mask = g.createChild("Poster")
        mask.uri = m.top.maskUri
        mask.width = w
        mask.height = h
    end if
    ' braid progress bar (whimsy spec 5): 12px track, gold fill clipped to the percentage, leaf tip
    bar = g.createChild("Group")
    bar.translation = [0, h + 14]
    track = bar.createChild("Poster")
    track.uri = "pkg:/images/w/progress-track.9.png"
    track.width = w
    track.height = 12
    clip = bar.createChild("Group")
    clip.translation = [1, 1]
    body = clip.createChild("Poster")
    body.uri = "pkg:/images/w/progress-fill-body.png"
    body.width = 1900
    body.height = 10
    tip = bar.createChild("Poster")
    tip.uri = "pkg:/images/w/progress-fill-tip.png"
    tip.width = 12
    tip.height = 10
    cap = g.createChild("Label")
    cap.width = w
    cap.translation = [0, h + 34]
    cap.font = hFont("bold", 22)
    cap.color = "0xEDE6CAFF"
    sub2 = g.createChild("Label")
    sub2.width = w
    sub2.translation = [0, h + 64]
    sub2.font = hFont("regular", 20)
    sub2.color = "0xB5AF8CFF"
    ' focus (whimsy spec 4): rough rope-gold line with a soft glow, and moss on the focused card only
    ring = g.createChild("Poster")
    if w = 320 and h = 180
        ring.uri = "pkg:/images/w/focus-ring-334x194" + hVar(k) + ".png"
    else if w = 200 and h = 300
        ring.uri = "pkg:/images/w/focus-ring-214x314" + hVar(k) + ".png"
    else
        ring.uri = "pkg:/images/w/focus-ring" + hVar(k) + ".9.png"
    end if
    ring.translation = [-27, -27]
    ring.width = w + 54
    ring.height = h + 54
    if m.top.maskUri <> ""
        ' round artist cards: a circle focus ring in gold, not the square rope
        ring.uri = "pkg:/images/music/round-ring.png"
        ring.blendColor = "0xE0B34AFF"
        ring.translation = [-10, -10]
        ring.width = w + 20
        ring.height = h + 20
    end if
    ring.visible = false
    moss = g.createChild("Poster")
    moss.visible = false
    g.addFields({ poster: p, fb: fb, bar: bar, clip: clip, tip: tip, cap: cap, sub2: sub2, ring: ring, moss: moss })
end sub

sub fillSlot(g as object, c as object, w as integer)
    img = c.image
    if img = invalid then img = ""
    g.poster.uri = img
    title = c.title
    if title = invalid then title = ""
    g.fb.text = UCase(title)
    hasBar = (c.progress <> invalid and c.progress > 0)
    g.bar.visible = hasBar
    if hasBar
        fillW = Int((w - 2) * c.progress / 100)
        if fillW < 15 then fillW = 15
        g.clip.clippingRect = [0, 0, fillW - 12, 10]
        g.tip.translation = [1 + fillW - 12, 1]
    end if
    g.cap.visible = m.top.showCaption
    g.sub2.visible = m.top.showCaption
    g.cap.text = title
    if c.sub <> invalid then g.sub2.text = c.sub else g.sub2.text = ""
    key = ""
    if c.item <> invalid and c.item.Id <> invalid then key = c.item.Id.toStr()
    if key = "" then key = title
    hMossHug(g.moss, -7, -7, w + 7, key)
end sub

sub paint()
    cards = m.top.cards
    if cards = invalid or m.slotFor = invalid then return
    w = m.top.cardWidth + m.gap
    ' keep the focused card on screen
    right = (m.top.index + 1) * w - m.gap
    shift = 0
    if right > m.top.viewWidth then shift = right - m.top.viewWidth
    m.strip.translation = [-shift, 0]
    first = Int(shift / w) - 1
    if first < 0 then first = 0
    slots = m.strip.getChildCount()
    if first + slots > cards.count() then first = cards.count() - slots
    if first < 0 then first = 0
    ' each card index always lands in slot (index mod slots), so scrolling by one refills one slot
    for i = first to first + slots - 1
        k = i mod slots
        g = m.strip.getChild(k)
        if m.slotFor[k] <> i
            m.slotFor[k] = i
            fillSlot(g, cards[i], m.top.cardWidth)
            g.translation = [i * w, 0]
        end if
        on = (m.top.active and i = m.top.index)
        g.ring.visible = on
        g.moss.visible = on and not m.top.noMoss
    end for
end sub

' dx = -1 or 1. Returns true when focus moved (no wrap).
function move(dx as integer) as boolean
    i = m.top.index + dx
    if i < 0 or i >= m.top.cards.count() then return false
    m.top.index = i
    paint()
    return true
end function

function current(unused = invalid as dynamic) as object
    if m.top.cards = invalid or m.top.cards.count() = 0 then return invalid
    return m.top.cards[m.top.index]
end function

function count(unused = invalid as dynamic) as integer
    if m.top.cards = invalid then return 0
    return m.top.cards.count()
end function
