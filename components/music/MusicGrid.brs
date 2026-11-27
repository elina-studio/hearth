sub init()
    m.strip = m.top.findNode("strip")
end sub

function rowH() as integer
    return m.top.cardSize + 90
end function

sub build()
    cards = m.top.cards
    if cards = invalid then cards = []
    rows = Int(m.top.viewHeight / rowH()) + 2
    slots = rows * m.top.cols
    if slots > cards.Count() then slots = cards.Count()
    m.strip.removeChildrenIndex(m.strip.getChildCount(), 0)
    for k = 0 to slots - 1
        makeSlot()
    end for
    m.slotFor = []
    for k = 0 to slots - 1
        m.slotFor.push(-1)
    end for
    if m.top.index >= cards.Count() then m.top.index = 0
    paint()
end sub

sub makeSlot()
    s = m.top.cardSize
    cw = m.top.colWidth
    x0 = (cw - s) / 2
    if not m.top.round then x0 = 0
    g = m.strip.createChild("Group")
    bg = g.createChild("Rectangle")
    bg.translation = [x0, 0]
    bg.width = s
    bg.height = s
    bg.color = "0x1D2418FF"
    if m.top.round then bg.visible = false
    p = g.createChild("Poster")
    p.translation = [x0, 0]
    p.width = s
    p.height = s
    p.loadWidth = s
    p.loadHeight = s
    p.loadDisplayMode = "scaleToZoom"
    hFbWatch(p)
    fb = g.createChild("Label")
    fb.translation = [x0 + 12, 10]
    fb.width = s - 24
    fb.height = s - 20
    fb.wrap = true
    fb.lineSpacing = 2
    fb.vertAlign = "center"
    fb.horizAlign = "center"
    fb.font = hFont("bold", 18)
    fb.color = "0xEDE6CAFF"
    cap = g.createChild("Label")
    cap.translation = [0, s + 14]
    cap.width = cw - 20
    cap.maxLines = 1
    cap.font = hFont("bold", 22)
    cap.color = "0xEDE6CAFF"
    sub2 = g.createChild("Label")
    sub2.translation = [0, s + 44]
    sub2.width = cw - 20
    sub2.maxLines = 1
    sub2.font = hFont("regular", 20)
    sub2.color = "0xB5AF8CFF"
    if m.top.round
        cap.width = cw
        cap.horizAlign = "center"
        sub2.visible = false
    end if
    ' optional gold tag in the cover's corner (card.tag, e.g. "REQUESTED")
    tagBg = g.createChild("Rectangle")
    tagBg.translation = [x0 + 10, 10]
    tagBg.height = 28
    tagBg.color = "0xE0B34AFF"
    tagBg.visible = false
    tagL = g.createChild("Label")
    tagL.translation = [x0 + 18, 10]
    tagL.height = 28
    tagL.vertAlign = "center"
    tagL.font = hFont("bold", 17)
    tagL.color = "0x1F1606FF"
    ring = g.createChild("Poster")
    if m.top.round
        ring.uri = "pkg:/images/music/round-ring.png"
        ring.translation = [x0 - 10, -10]
        ring.blendColor = "0xE0B34AFF"
        ring.width = s + 20
        ring.height = s + 20
    else
        ' whimsy spec 4: rough rope-gold line with a soft glow (20px padding + 7px gap), no moss in Music
        ring.uri = "pkg:/images/w/focus-ring" + hVar(m.strip.getChildCount()) + ".9.png"
        ring.translation = [-27, -27]
        ring.width = s + 54
        ring.height = s + 54
    end if
    ring.visible = false
    g.addFields({ poster: p, fb: fb, cap: cap, sub2: sub2, ring: ring, tagBg: tagBg, tagL: tagL })
end sub

sub fill(g as object, c as object)
    img = c.image
    if img = invalid then img = ""
    g.poster.uri = img
    g.fb.visible = (img = "")
    t = c.title
    if t = invalid then t = ""
    g.fb.text = UCase(t)
    g.cap.text = t
    if c.sub <> invalid then g.sub2.text = c.sub else g.sub2.text = ""
    tg = ""
    if c.tag <> invalid then tg = c.tag
    g.tagL.text = tg
    g.tagBg.visible = (tg <> "")
    g.tagL.visible = (tg <> "")
    if tg <> "" then g.tagBg.width = Len(tg) * 11 + 18
end sub

sub paint()
    cards = m.top.cards
    if cards = invalid or m.slotFor = invalid or m.slotFor.Count() = 0 then return
    cols = m.top.cols
    rh = rowH()
    visRows = Int(m.top.viewHeight / rh)
    if visRows < 1 then visRows = 1
    focusRow = Int(m.top.index / cols)
    totalRows = Int((cards.Count() + cols - 1) / cols)
    ' keep the focused row on screen, one row from the top once scrolling starts
    topRow = focusRow - 1
    if topRow > totalRows - visRows then topRow = totalRows - visRows
    if topRow < 0 then topRow = 0
    m.strip.translation = [0, -topRow * rh]
    slots = m.slotFor.Count()
    first = (topRow - 1) * cols
    if first < 0 then first = 0
    if first + slots > cards.Count() then first = cards.Count() - slots
    if first < 0 then first = 0
    ' card i always lands in slot (i mod slots), so a scroll refills one row
    for i = first to first + slots - 1
        k = i mod slots
        g = m.strip.getChild(k)
        if m.slotFor[k] <> i
            m.slotFor[k] = i
            fill(g, cards[i])
            r = Int(i / cols)
            g.translation = [(i - r * cols) * m.top.colWidth, r * rh]
        end if
        g.ring.visible = (m.top.active and i = m.top.index)
    end for
end sub

function move(dx as integer, dy as integer) as boolean
    cards = m.top.cards
    if cards = invalid or cards.Count() = 0 then return false
    cols = m.top.cols
    i = m.top.index
    col = i mod cols
    if dx <> 0
        if col + dx < 0 or col + dx >= cols then return false
        j = i + dx
    else
        j = i + dy * cols
        ' moving down onto a short last row lands on its last card
        if dy > 0 and j >= cards.Count() and Int(i / cols) < Int((cards.Count() - 1) / cols) then j = cards.Count() - 1
    end if
    if j < 0 or j >= cards.Count() then return false
    m.top.index = j
    paint()
    return true
end function

function jumpTo(i as integer) as boolean
    cards = m.top.cards
    if cards = invalid or i < 0 or i >= cards.Count() then return false
    m.top.index = i
    paint()
    return true
end function

function current(unused = invalid as dynamic) as object
    cards = m.top.cards
    if cards = invalid or cards.Count() = 0 then return invalid
    return cards[m.top.index]
end function
