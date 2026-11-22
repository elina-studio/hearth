sub init()
    m.cards = []
    m.title = m.top.findNode("title")
    m.title.font = hFont("regular", 28)
    m.rule = m.top.findNode("rule")
    m.strip = m.top.findNode("strip")
    m.w = 200
    m.h = 300
    m.gap = 30
    m.viewWidth = 1728
    m.chipFont = hFont("caps", 24)
end sub

sub onTitle()
    m.title.text = m.top.title
    b = m.title.boundingRect()
    m.rule.translation = [b.width + 20, 20]
    m.rule.width = m.viewWidth - b.width - 20
end sub

sub build()
    m.strip.removeChildrenIndex(m.strip.getChildCount(), 0)
    m.cards = m.top.cards
    if m.cards = invalid then m.cards = []
    x = 0
    for each c in m.cards
        g = m.strip.createChild("Group")
        g.translation = [x, 0]
        bg = g.createChild("Rectangle")
        bg.width = m.w
        bg.height = m.h
        bg.color = "0x1D2418FF"
        if c.kind = "search"
            bg.color = "0xFFFFFF0F"
            lab = g.createChild("Label")
            lab.width = m.w - 30
            lab.height = m.h - 20
            lab.translation = [15, 10]
            lab.wrap = true
            lab.horizAlign = "center"
            lab.vertAlign = "center"
            lab.font = hFont("caps", 40)
            lab.color = "0xE0B34AFF"
            lab.text = "SEARCH" + Chr(10) + "TO REQUEST"
        else
            ' title sits under the poster, so it shows whenever the poster is missing or fails to load
            lab = g.createChild("Label")
            lab.width = m.w - 30
            lab.height = m.h - 20
            lab.translation = [15, 10]
            lab.wrap = true
            lab.horizAlign = "center"
            lab.vertAlign = "center"
            lab.font = hFont("caps", 32)
            lab.color = "0xEDE6CAFF"
            t = c.title
            if t = invalid or t = "" then t = "Untitled"
            lab.text = UCase(t)
            p = g.createChild("Poster")
            p.width = m.w
            p.height = m.h
            p.loadDisplayMode = "scaleToZoom"
            if c.image <> invalid and c.image <> "" then p.uri = c.image
        end if
        ' status chip (an empty Group keeps child positions fixed for setChip)
        chip = g.createChild("Group")
        chip.translation = [0, m.h + 16]
        if c.chip <> invalid and c.chip <> ""
            drawChip(chip, c.chip, c.lit = true)
        end if
        ring = g.createChild("Poster")
        ring.uri = "pkg:/images/ring.9.png"
        ring.blendColor = "0xE0B34AFF"
        ring.translation = [-10, -10]
        ring.width = m.w + 20
        ring.height = m.h + 20
        ring.visible = false
        x = x + m.w + m.gap
    end for
    m.top.rowHeight = 56 + m.h + 16 + 46
    if m.top.index >= m.cards.count() then m.top.index = 0
    paint()
end sub

sub drawChip(chip as object, text as string, lit as boolean)
    chip.removeChildrenIndex(chip.getChildCount(), 0)
    if text = "" then return
    bg = chip.createChild("Poster")
    if lit
        bg.uri = "pkg:/images/pill.9.png"
        bg.blendColor = "0xE0B34AFF"
    else
        bg.uri = "pkg:/images/pill-ring.9.png"
        bg.blendColor = "0xFFFFFF40"
    end if
    bg.width = m.w
    bg.height = 46
    lab = chip.createChild("Label")
    lab.width = m.w
    lab.height = 46
    lab.horizAlign = "center"
    lab.vertAlign = "center"
    lab.font = m.chipFont
    if lit then lab.color = "0x1F1606FF" else lab.color = "0xEDE6CAFF"
    lab.text = UCase(text)
end sub

sub paint()
    n = m.strip.getChildCount()
    for i = 0 to n - 1
        g = m.strip.getChild(i)
        g.getChild(g.getChildCount() - 1).visible = (m.top.active and i = m.top.index)
    end for
    w = m.w + m.gap
    right = (m.top.index + 1) * w - m.gap
    shift = 0
    if right > m.viewWidth then shift = right - m.viewWidth
    m.strip.translation = [-shift, 0]
end sub

function move(dx as integer) as boolean
    i = m.top.index + dx
    if m.cards = invalid or i < 0 or i >= m.cards.count() then return false
    m.top.index = i
    paint()
    return true
end function

function current(unused = invalid as dynamic) as object
    if m.cards = invalid or m.cards.count() = 0 then return invalid
    return m.cards[m.top.index]
end function

' After a request: change the focused card's chip without rebuilding the row.
sub setChip(args as object)
    i = m.top.index
    if m.cards = invalid or i >= m.cards.count() then return
    m.cards[i].chip = args.chip
    m.cards[i].lit = args.lit
    g = m.strip.getChild(i)
    chip = g.getChild(g.getChildCount() - 2)
    drawChip(chip, args.chip, args.lit = true)
end sub
