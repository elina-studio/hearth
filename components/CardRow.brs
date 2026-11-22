sub init()
    m.title = m.top.findNode("title")
    m.title.font = hFont("regular", 28)
    m.rule = m.top.findNode("rule")
    m.strip = m.top.findNode("strip")
    m.gap = 30
end sub

sub onTitle()
    m.title.text = m.top.title
    bounds = m.title.boundingRect()
    m.rule.translation = [bounds.width + 20, 20]
    m.rule.width = m.top.viewWidth - bounds.width - 20
end sub

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
            makeSlot(w, h)
        end for
        m.slotW = w
        m.slotH = h
    end if
    m.slotFor = []
    for k = 0 to slots - 1
        m.slotFor.push(-1)
    end for
    extra = 0
    if m.top.showCaption then extra = 84
    m.top.rowHeight = 56 + h + extra
    if m.top.index >= n then m.top.index = 0
    paint()
end sub

sub makeSlot(w as integer, h as integer)
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
    fb.font = hFont("caps", 34)
    ' the framed title sits under the picture: it shows while the poster loads, and stays when there is none
    frame = g.createChild("Poster")
    frame.uri = "pkg:/images/ring.9.png"
    frame.blendColor = "0xD9A06655"
    frame.translation = [0, 0]
    frame.width = w
    frame.height = h
    p = g.createChild("Poster")
    p.width = w
    p.height = h
    p.loadDisplayMode = "scaleToZoom"
    if m.top.maskUri <> ""
        mask = g.createChild("Poster")
        mask.uri = m.top.maskUri
        mask.width = w
        mask.height = h
    end if
    fb.color = "0xEDE6CAFF"
    track = g.createChild("Rectangle")
    track.width = w
    track.height = 8
    track.translation = [0, h + 8]
    track.color = "0xFFFFFF1A"
    fill = g.createChild("Rectangle")
    fill.height = 8
    fill.translation = [0, h + 8]
    fill.color = "0xA3A35AFF"
    cap = g.createChild("Label")
    cap.width = w
    cap.translation = [0, h + 22]
    cap.font = hFont("bold", 24)
    cap.color = "0xEDE6CAFF"
    sub2 = g.createChild("Label")
    sub2.width = w
    sub2.translation = [0, h + 52]
    sub2.font = hFont("regular", 22)
    sub2.color = "0xB5AF8CFF"
    ring = g.createChild("Poster")
    ring.uri = "pkg:/images/ring.9.png"
    ring.blendColor = "0xE0B34AFF"
    ring.translation = [-10, -10]
    ring.width = w + 20
    ring.height = h + 20
    ring.visible = false
    g.addFields({ poster: p, fb: fb, track: track, fill: fill, cap: cap, sub2: sub2, ring: ring })
end sub

sub fillSlot(g as object, c as object, w as integer)
    img = c.image
    if img = invalid then img = ""
    g.poster.uri = img
    title = c.title
    if title = invalid then title = ""
    g.fb.text = UCase(title)
    hasBar = (c.progress <> invalid and c.progress > 0)
    g.track.visible = hasBar
    g.fill.visible = hasBar
    if hasBar then g.fill.width = w * c.progress / 100
    g.cap.visible = m.top.showCaption
    g.sub2.visible = m.top.showCaption
    g.cap.text = title
    if c.sub <> invalid then g.sub2.text = c.sub else g.sub2.text = ""
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
        g.ring.visible = (m.top.active and i = m.top.index)
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
