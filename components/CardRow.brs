sub init()
    m.title = m.top.findNode("title")
    m.title.font = hFont("regular", 28)
    m.rule = m.top.findNode("rule")
    m.strip = m.top.findNode("strip")
    m.gap = 30
    m.viewWidth = 1728
end sub

sub onTitle()
    m.title.text = m.top.title
    bounds = m.title.boundingRect()
    m.rule.translation = [bounds.width + 20, 20]
    m.rule.width = m.viewWidth - bounds.width - 20
end sub

sub build()
    m.strip.removeChildrenIndex(m.strip.getChildCount(), 0)
    w = m.top.cardWidth
    h = m.top.cardHeight
    x = 0
    for each c in m.top.cards
        g = m.strip.createChild("Group")
        g.translation = [x, 0]
        bg = g.createChild("Rectangle")
        bg.width = w
        bg.height = h
        bg.color = "0x1D2418FF"
        p = g.createChild("Poster")
        p.width = w
        p.height = h
        p.loadDisplayMode = "scaleToZoom"
        p.uri = c.image
        if c.image = "" or c.image = invalid
            fallback = g.createChild("Label")
            fallback.width = w - 30
            fallback.height = h - 20
            fallback.translation = [15, 10]
            fallback.wrap = true
            fallback.vertAlign = "center"
            fallback.horizAlign = "center"
            fallback.font = hFont("caps", 34)
            fallback.color = "0xEDE6CAFF"
            fallback.text = UCase(c.title)
        end if
        if c.progress <> invalid and c.progress > 0
            track = g.createChild("Rectangle")
            track.width = w
            track.height = 8
            track.translation = [0, h + 8]
            track.color = "0xFFFFFF1A"
            fill = g.createChild("Rectangle")
            fill.width = w * c.progress / 100
            fill.height = 8
            fill.translation = [0, h + 8]
            fill.color = "0xA3A35AFF"
        end if
        if m.top.showCaption
            cap = g.createChild("Label")
            cap.width = w
            cap.translation = [0, h + 22]
            cap.font = hFont("bold", 24)
            cap.color = "0xEDE6CAFF"
            cap.text = c.title
            sub2 = g.createChild("Label")
            sub2.width = w
            sub2.translation = [0, h + 52]
            sub2.font = hFont("regular", 22)
            sub2.color = "0xB5AF8CFF"
            sub2.text = c.sub
        end if
        ring = g.createChild("Poster")
        ring.uri = "pkg:/images/ring.9.png"
        ring.blendColor = "0xE0B34AFF"
        ring.translation = [-10, -10]
        ring.width = w + 20
        ring.height = h + 20
        ring.visible = false
        x = x + w + m.gap
    end for
    extra = 0
    if m.top.showCaption then extra = 84
    m.top.rowHeight = 56 + h + extra
    if m.top.index >= m.top.cards.count() then m.top.index = 0
    paint()
end sub

sub paint()
    n = m.strip.getChildCount()
    for i = 0 to n - 1
        g = m.strip.getChild(i)
        ring = g.getChild(g.getChildCount() - 1)
        ring.visible = (m.top.active and i = m.top.index)
    end for
    ' keep the focused card on screen
    w = m.top.cardWidth + m.gap
    right = (m.top.index + 1) * w - m.gap
    shift = 0
    if right > m.viewWidth then shift = right - m.viewWidth
    m.strip.translation = [-shift, 0]
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
