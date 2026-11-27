sub init()
    m.top.findNode("fallback").font = hFontCached("caps", 30)
    m.top.findNode("tileTitle").font = hFontCached("caps", 36)
    m.top.findNode("tileSub").font = hFontCached("regular", 22)
    m.chipText = m.top.findNode("chipText")
    m.chipText.font = hFontCached("caps", 22)
    m.top.findNode("imdbText").font = hFontCached("bold", 17)
    m.top.findNode("rtText").font = hFontCached("bold", 17)
    m.poster = m.top.findNode("poster")
    m.cap = m.top.findNode("cap")
    m.cap.font = hFontCached("bold", 22)
    m.cap.color = "0xEDE6CAFF"
    m.capSub = m.top.findNode("capSub")
    m.capSub.font = hFontCached("regular", 22)
    m.capSub.color = "0xB5AF8CFF"
end sub

sub draw()
    c = m.top.card
    if c = invalid then return
    isTile = (c.kind = "search" or c.kind = "music")
    if c.kind = "chiponly"
        for each id in ["bg", "fallback", "poster", "tile", "bar", "cap", "capSub", "ring"]
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
        fb.font = hFontCached("regular", 22)
        fb.text = t
    else
        m.poster.height = 270
        m.poster.translation = [0, 0]
        fb.translation = [12, 10]
        fb.height = 250
        fb.font = hFontCached("caps", 30)
    end if
    m.poster.uri = ""
    drawScores()
    onLoad()
    drawChip(c.chip)
    p = c.progress
    if p = invalid then p = -1
    ' braid bar (whimsy spec 5): fill is the gold body clipped to the percentage, with a leaf tip
    m.top.findNode("bar").visible = (p >= 0)
    fw = 0
    if p > 0 then fw = Int((178 * p / 100))
    if p > 0 and fw < 15 then fw = 15
    cw = fw - 12
    if cw < 0 then cw = 0
    m.top.findNode("clip").clippingRect = [0, 0, cw, 10]
    tip = m.top.findNode("tip")
    tip.visible = (p > 0)
    tip.translation = [1 + fw - 12, 1]
    ' caption under the bar: title, then what it is doing (only on Your requests)
    hasCap = (c.caption <> invalid and c.caption <> "")
    m.cap.visible = hasCap
    m.capSub.visible = hasCap
    if hasCap
        m.cap.text = c.title
        m.capSub.text = c.caption
    end if
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
    ' a "+ REQUEST" label on every card was noise: only In library / Requested / problem badges show (UX review item 35)
    if g.visible and chip.tone = "out" and chip.text = "Request" then g.visible = false
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

' One small badge, top right of the poster: IMDb number in yellow, then the tomato (fresh, gold-ringed when
' certified) or green splat (rotten) and the critics %. Either half is left out when there's no score.
sub drawScores()
    g = m.top.findNode("score")
    c = m.top.card
    v = m.top.scores
    if c = invalid or c.kind <> "media" or c.square = true or v = invalid
        g.visible = false
        return
    end if
    im =m.top.findNode("imdbText")
    ic = m.top.findNode("rtIcon")
    rt = m.top.findNode("rtText")
    x = 7
    im.visible = (v.imdb <> invalid)
    if im.visible
        im.text = rqScore1(v.imdb)
        im.translation = [x, 0]
        x = x + im.boundingRect().width + 6
    end if
    has = (v.rt <> invalid)
    ic.visible = has
    rt.visible = has
    if has
        ic.uri = rqTomato(v)
        ic.translation = [x, 5]
        rt.text = Int(v.rt).toStr() + "%"
        rt.translation = [x + 18, 0]
        x = x + 18 + rt.boundingRect().width + 1
    end if
    if x <= 7
        g.visible = false
        return
    end if
    w = x + 6
    m.top.findNode("scoreBg").width = w
    g.translation = [180 - 6 - w, 6]
    g.visible = true
end sub
