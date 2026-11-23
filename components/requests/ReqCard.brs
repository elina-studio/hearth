sub init()
    m.top.findNode("fallback").font = hFont("caps", 30)
    m.top.findNode("tileTitle").font = hFont("caps", 36)
    m.top.findNode("tileSub").font = hFont("regular", 20)
    m.chipText = m.top.findNode("chipText")
    m.chipText.font = hFont("caps", 21)
    m.poster = m.top.findNode("poster")
end sub

sub draw()
    c = m.top.card
    if c = invalid then return
    isTile = (c.kind = "search" or c.kind = "music")
    if c.kind = "chiponly"
        for each id in ["bg", "fallback", "poster", "tile", "track", "fill", "ring"]
            m.top.findNode(id).visible = false
        end for
        drawChip(c.chip)
        return
    end if
    m.top.findNode("tile").visible = isTile
    m.poster.visible = not isTile
    m.top.findNode("bg").visible = not isTile
    fb = m.top.findNode("fallback")
    fb.visible = not isTile
    if isTile
        m.top.findNode("tileIcon").uri = "pkg:/images/requests/" + c.icon + ".png"
        m.top.findNode("tileTitle").text = UCase(c.title)
        m.top.findNode("tileSub").text = c.sub
    else
        t = c.title
        if t = invalid then t = ""
        fb.text = UCase(t)
    end if
    ' album covers are square: centred in the poster frame, title under them
    if c.square = true
        m.poster.height = 180
        m.poster.translation = [0, 30]
        fb.translation = [12, 214]
        fb.height = 50
        fb.font = hFont("regular", 20)
        fb.text = t
    else
        m.poster.height = 270
        m.poster.translation = [0, 0]
        fb.translation = [12, 10]
        fb.height = 250
        fb.font = hFont("caps", 30)
    end if
    m.poster.uri = ""
    onLoad()
    drawChip(c.chip)
    p = c.progress
    if p = invalid then p = -1
    m.top.findNode("track").visible = (p >= 0)
    f = m.top.findNode("fill")
    f.visible = (p > 0)
    f.width = 180 * p / 100
end sub

' Posters load only once the card is near the screen (the room sets load)
sub onLoad()
    c = m.top.card
    if c = invalid or not m.top.load then return
    if c.image <> invalid and c.image <> "" and m.poster.uri <> c.image then m.poster.uri = c.image
end sub

sub drawChip(chip as dynamic)
    g = m.top.findNode("chip")
    g.visible = (chip <> invalid and chip.text <> invalid and chip.text <> "")
    if not g.visible then return
    bg = m.top.findNode("chipBg")
    icon = m.top.findNode("chipIcon")
    tone = chip.tone
    ink = "0x1F1606FF"
    if tone = "gold"
        bg.color = "0xE0B34AFF"
    else if tone = "olive"
        bg.color = "0xA3A35AFF"
    else if tone = "ember"
        bg.color = "0xF0907CFF"
    else
        bg.color = "0x0B0E09D9"
        ink = "0xEDE6CAFF"
    end if
    icon.uri = "pkg:/images/requests/" + chip.icon + ".png"
    icon.blendColor = ink
    m.chipText.color = ink
    m.chipText.text = UCase(chip.text)
    w = m.chipText.boundingRect().width + 26
    if w > 172 then w = 172
    m.top.findNode("chipInner").translation = [Int((180 - w) / 2), 0]
end sub

sub onFocused()
    m.top.findNode("ring").visible = m.top.focused
end sub
