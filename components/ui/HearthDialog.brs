' Hearth's popup. See HearthDialog.xml for the fields. Layout: a header (title, hero picture or "playing now" box),
' then one or two columns of lines. A line is a group title, a row, one wide button, or a strip of tiles.

sub init()
    m.card = m.top.findNode("card")
    m.twig = m.top.findNode("twig")
    m.fly = m.top.findNode("fly")
    m.headG = m.top.findNode("headG")
    m.body = m.top.findNode("body")
    m.foot = m.top.findNode("foot")
    m.hold = m.top.findNode("hold")
    m.hold.observeField("fire", "onHold")
    m.isOpen = false
    m.done = false
    m.prev = invalid
    m.ink = "0xEDE6CAFF"
    m.muted = "0xB5AF8CFF"
    m.gold = "0xE0B34AFF"
    m.goldInk = "0x1F1606FF"
    m.lit = "0xFFE7A0FF"
end sub

function strAt(list as dynamic, i as integer) as string
    if list = invalid or i >= list.count() then return ""
    v = list[i]
    if v = invalid then return ""
    return v
end function

function bodyText() as string
    lines = m.top.message
    out = ""
    if lines <> invalid
        for each ln in lines
            if ln <> invalid and ln <> ""
                if out <> "" then out = out + Chr(10)
                out = out + ln
            end if
        end for
    end if
    return out
end function

' Called by hShowDialog once the popup is in the scene. prev is whatever had focus, and gets it back on close.
sub open(prev = invalid as dynamic)
    m.prev = prev
    btns = m.top.buttons
    if btns = invalid then btns = []
    heads = m.top.heads
    if heads = invalid then heads = {}
    n = btns.count()
    m.ask = (m.top.popup = true and n <= 3)
    hero = m.top.hero
    now = m.top.now
    split = m.top.split
    if m.ask then split = 0
    poster = (hero <> invalid and hero.shape = "poster" and not m.ask)

    ' ---- the buttons, as items ----
    m.items = []
    rich = (hero <> invalid or now <> invalid)
    for i = 0 to n - 1
        caption = btns[i]
        if caption = invalid then caption = ""
        if not ((LCase(caption) = "close" or LCase(caption) = "cancel") and n > 1 and not m.ask)
            it = { i: i, name: caption, value: "", go: false, sub: strAt(m.top.subs, i), icon: strAt(m.top.icons, i), pic: strAt(m.top.pics, i), kind: strAt(m.top.kinds, i) }
            if m.ask then it.kind = "btn"
            if it.kind = "" then it.kind = "row"
            if it.kind <> "row" then rich = true
            if it.sub <> "" or it.icon <> "" then rich = true
            if it.kind = "row"
                ' only a short "Name: value" is a setting; a title that happens to hold a colon stays whole
                at = Instr(1, caption, ": ")
                if at > 1 and at < 26 and Len(caption) - at - 1 <= 24
                    it.name = Left(caption, at - 1)
                    it.value = Mid(caption, at + 2)
                end if
                if Right(it.name, 3) = "..."
                    it.name = Left(it.name, Len(it.name) - 3)
                    it.go = true
                end if
            end if
            m.items.push(it)
        end if
    end for
    ' when any row has an icon, every row leaves room for one so the names line up
    m.anyIcon = false
    for each it in m.items
        if it.kind = "row" and it.icon <> "" then m.anyIcon = true
    end for

    ' ---- size of the card ----
    w = 760
    if rich then w = 960
    if split > 0 then w = 1260
    if poster then w = 1080
    pad = 48
    colW = w - 2 * pad
    colX = [pad, pad]
    if split > 0
        colW = Int((w - 2 * pad - 44) / 2)
        colX = [pad, pad + colW + 44]
    end if
    if poster
        colW = w - 2 * pad - 342
        colX = [pad + 342, pad + 342]
    end if
    m.colW = colW
    m.colX = colX

    ' ---- the header ----
    m.headG.removeChildrenIndex(m.headG.getChildCount(), 0)
    y = 44
    words = bodyText()
    if m.ask
        t = addLabel(m.headG, m.top.title, "bold", 48, m.ink, pad + 12, y, w - 2 * pad - 24)
        t.horizAlign = "center"
        t.wrap = true
        t.maxLines = 2
        y = y + t.boundingRect().height + 12
        if words <> ""
            ms = addLabel(m.headG, words, "regular", 26, m.muted, pad + 12, y, w - 2 * pad - 24)
            ms.horizAlign = "center"
            ms.wrap = true
            ms.maxLines = 6
            ms.lineSpacing = 2
            y = y + ms.boundingRect().height + 12
        end if
        y = y + 24
    else if hero <> invalid
        ax = pad
        tx = pad + 160 + 28
        aw = 160
        ah = 160
        if hero.shape = "logo" then aw = 91
        if poster
            aw = 300
            ah = 450
            tx = colX[0]
        end if
        if hero.shape = "logo" then tx = pad + aw + 28
        back = m.headG.createChild("Rectangle")
        back.translation = [ax, y]
        back.width = aw
        back.height = ah
        back.color = "0x1D2418FF"
        if hero.shape = "logo" then back.visible = false
        art = m.headG.createChild("Poster")
        art.translation = [ax, y]
        art.width = aw
        art.height = ah
        if hero.shape <> "logo" then art.loadDisplayMode = "scaleToZoom"
        if hero.art <> invalid then art.uri = hero.art
        tw = w - pad - tx - 70
        ty = y
        if not poster then ty = y + 14
        if hero.kicker <> invalid and hero.kicker <> ""
            addLabel(m.headG, UCase(hero.kicker), "caps", 22, m.gold, tx, ty, tw)
            ty = ty + 34
        end if
        t = addLabel(m.headG, m.top.title, "bold", 44, m.ink, tx, ty, tw)
        dlgText(t, m.top.title, "bold")
        if poster
            t.wrap = true
            t.maxLines = 2
            t.lineSpacing = 0
        end if
        ty = ty + t.boundingRect().height + 4
        if words <> ""
            ms = addLabel(m.headG, words, "regular", 24, m.muted, tx, ty, tw)
            ms.wrap = true
            ms.maxLines = 2
            ms.lineSpacing = 2
            ty = ty + ms.boundingRect().height + 6
        end if
        if hero.chips <> invalid and hero.chips.count() > 0
            cx = tx
            ty = ty + 8
            for each c in hero.chips
                if c <> invalid and c <> "" then cx = cx + chip(m.headG, c, cx, ty) + 10
            end for
            ty = ty + 40
        end if
        if poster
            m.posterBottom = y + ah
            y = ty + 22
        else
            if ty < y + ah then ty = y + ah
            y = ty + 30
        end if
    else
        tx = pad
        if m.top.icon <> ""
            ic = m.headG.createChild("Poster")
            ic.uri = m.top.icon
            ic.width = 40
            ic.height = 40
            ic.blendColor = m.gold
            ic.translation = [pad, y + 6]
            tx = pad + 56
        end if
        t = addLabel(m.headG, m.top.title, "fell", 42, m.ink, tx, y, w - pad - tx - 70)
        if hOutsideFont(m.top.title) then t.font = hSysFont("bold", 38)
        y = y + 64
        if now <> invalid
            nbox = m.headG.createChild("Rectangle")
            nbox.translation = [pad, y]
            nbox.width = w - 2 * pad
            nbox.height = 132
            nbox.color = "0x0B0E0988"
            ab = m.headG.createChild("Rectangle")
            ab.translation = [pad + 14, y + 14]
            ab.width = 104
            ab.height = 104
            ab.color = "0x1D2418FF"
            art = m.headG.createChild("Poster")
            art.translation = [pad + 14, y + 14]
            art.width = 104
            art.height = 104
            art.loadDisplayMode = "scaleToZoom"
            if now.art <> invalid then art.uri = now.art
            nx = pad + 140
            nw = w - 2 * pad - 160
            if now.kicker <> invalid then addLabel(m.headG, UCase(now.kicker), "caps", 22, m.gold, nx, y + 16, nw)
            nt = addLabel(m.headG, "", "bold", 34, m.ink, nx, y + 44, nw)
            if now.title <> invalid then dlgText(nt, now.title, "bold")
            ns = addLabel(m.headG, "", "regular", 24, m.muted, nx, y + 88, nw)
            if now.sub <> invalid then dlgText(ns, now.sub, "regular")
            y = y + 132 + 26
        else if words <> ""
            ms = addLabel(m.headG, words, "regular", 24, m.muted, pad, y, w - 2 * pad)
            ms.wrap = true
            ms.maxLines = 8
            ms.lineSpacing = 2
            y = y + ms.boundingRect().height + 20
        end if
    end if
    m.bodyY = y

    ' ---- the lines of each column ----
    m.cols = [[], []]
    colH = [0, 0]
    lastStrip = invalid
    for each it in m.items
        c = 0
        if split > 0 and it.i >= split then c = 1
        yy = colH[c]
        h = heads[it.i.toStr()]
        if h <> invalid
            if yy > 0 then yy = yy + 18
            m.cols[c].push({ type: "head", y: yy, h: 36, text: h })
            yy = yy + 36
            lastStrip = invalid
        end if
        if it.kind = "row"
            m.cols[c].push({ type: "row", y: yy, h: 76, items: [it] })
            yy = yy + 76
            lastStrip = invalid
        else if it.kind = "main"
            m.cols[c].push({ type: "main", y: yy, h: 76, items: [it] })
            yy = yy + 76 + 12
            lastStrip = invalid
        else
            sh = 150
            if it.kind = "pic" then sh = 116
            if it.kind = "btn" then sh = 72
            if lastStrip <> invalid and lastStrip.kind = it.kind and lastStrip.col = c
                lastStrip.items.push(it)
            else
                lastStrip = { type: "strip", kind: it.kind, col: c, y: yy, h: sh, items: [it] }
                m.cols[c].push(lastStrip)
                yy = yy + sh + 14
            end if
        end if
        colH[c] = yy
    end for
    full = colH[0]
    if colH[1] > full then full = colH[1]
    footH = 26 + 30 + 36
    m.viewH = full
    if m.viewH > 1000 - m.bodyY - footH then m.viewH = 1000 - m.bodyY - footH
    if m.viewH < 0 then m.viewH = 0
    cardH = m.bodyY + m.viewH + footH
    if poster and cardH < m.posterBottom + 44 then cardH = m.posterBottom + 44
    m.cardW = w
    m.cardH = cardH
    m.x0 = Int((1920 - w) / 2)
    m.y0 = Int((1080 - cardH) / 2)
    m.card.translation = [m.x0, m.y0]
    m.card.width = w
    m.card.height = cardH
    m.headG.translation = [m.x0, m.y0]
    m.body.translation = [m.x0, m.y0 + m.bodyY]
    m.foot.translation = [m.x0, m.y0]
    ' a sprig over the top right corner and one firefly inside it: the same pair that sits by the clock
    m.twig.translation = [m.x0 + w - 330, m.y0 - 38]
    m.twig.visible = true
    m.fly.translation = [m.x0 + w - 84, m.y0 + 30]
    m.fly.visible = true

    ' ---- where focus starts ----
    m.sel = -1
    want = m.top.buttonFocused
    for each it in m.items
        if it.i = want then m.sel = want
    end for
    if m.sel < 0 and m.items.count() > 0 then m.sel = m.items[0].i
    m.scroll = 0
    m.isOpen = true
    m.top.setFocus(true)
    m.hold.control = "start"
    draw()
end sub

'the words, in the TV's own font when the app font lacks their letters
sub dlgText(node as object, words as dynamic, kind as string)
    if words = invalid then words = ""
    hFontText(node, words, kind)
    node.text = words
end sub

function addLabel(par as object, words as string, kind as string, size as integer, col as string, x as integer, y as integer, width as integer) as object
    l = par.createChild("Label")
    l.font = hFont(kind, size)
    l.color = col
    l.translation = [x, y]
    if width > 0 then l.width = width
    l.maxLines = 1
    l.text = words
    return l
end function

' a small outlined chip; returns its width
function chip(par as object, words as string, x as integer, y as integer) as integer
    l = par.createChild("Label")
    l.font = hFont("bold", 22)
    l.color = m.gold
    l.text = UCase(words)
    l.height = 36
    l.vertAlign = "center"
    cw = Int(l.boundingRect().width) + 28
    ring = par.createChild("Poster")
    ring.uri = "pkg:/images/pill-ring.9.png"
    ring.blendColor = "0x5F6E45FF"
    ring.width = cw
    ring.height = 36
    ring.translation = [x, y]
    l.translation = [x + 14, y]
    return cw
end function

' a room that grabs focus when its data lands must not leave the popup open and deaf
sub onHold()
    if m.isOpen and not m.top.isInFocusChain() then m.top.setFocus(true)
end sub

sub onClose()
    if not m.top.close or m.done then return
    m.done = true
    m.isOpen = false
    m.hold.control = "stop"
    m.top.visible = false
    sc = m.top.getScene()
    mine = false
    if sc <> invalid and sc.hasField("sheet")
        if sc.sheet <> invalid and sc.sheet.isSameNode(m.top)
            mine = true
            sc.sheet = invalid
        end if
    end if
    par = m.top.getParent()
    ' focus goes back where it was, as it does when a Roku dialog closes; a newer popup keeps it instead
    if mine and m.prev <> invalid then m.prev.setFocus(true)
    m.prev = invalid
    m.top.wasClosed = true
    if par <> invalid then par.removeChild(m.top)
end sub

' where the selected button sits: { c, l, k } column, line, place in the line
function findSel() as object
    for c = 0 to 1
        for l = 0 to m.cols[c].count() - 1
            ln = m.cols[c][l]
            if ln.type <> "head"
                for k = 0 to ln.items.count() - 1
                    if ln.items[k].i = m.sel then return { c: c, l: l, k: k }
                end for
            end if
        end for
    end for
    return invalid
end function

sub draw()
    m.body.removeChildrenIndex(m.body.getChildCount(), 0)
    at = findSel()
    hidden = 0
    if at <> invalid
        ln = m.cols[at.c][at.l]
        if ln.y + ln.h - m.scroll > m.viewH then m.scroll = ln.y + ln.h - m.viewH
        if ln.y - m.scroll < 0 then m.scroll = ln.y
        ' keep a group title in view with its first line
        if at.l > 0
            pr = m.cols[at.c][at.l - 1]
            if pr.type = "head" and pr.y < m.scroll then m.scroll = pr.y
        end if
        if at.l = 0 then m.scroll = 0
    end if
    for c = 0 to 1
        for each ln in m.cols[c]
            y = ln.y - m.scroll
            if y >= 0 and y + ln.h <= m.viewH + 1
                g = m.body.createChild("Group")
                g.translation = [m.colX[c], y]
                if ln.type = "head"
                    addLabel(g, UCase(ln.text), "caps", 22, m.gold, 18, 6, m.colW - 18)
                else if ln.type = "row"
                    drawRow(g, ln.items[0])
                else if ln.type = "main"
                    drawWide(g, ln.items[0], 0, m.colW, 76, true)
                else
                    drawStrip(g, ln)
                end if
            else if y + ln.h > m.viewH + 1 and ln.type <> "head"
                hidden = hidden + ln.items.count()
            end if
        end for
    end for
    drawFoot(hidden)
end sub

sub ringAround(g as object, x as integer, y as integer, w as integer, h as integer)
    ' focus-ring-v3.9 has 13 px of clear edge on the left and top, 19 and 18 on the right and bottom
    ring = g.createChild("Poster")
    ring.uri = "pkg:/images/w/focus-ring-v3.9.png"
    ring.translation = [x - 13, y - 13]
    ring.width = w + 32
    ring.height = h + 31
end sub

sub drawRow(g as object, it as object)
    focused = (it.i = m.sel)
    w = m.colW
    if focused
        bg = g.createChild("Rectangle")
        bg.translation = [0, 4]
        bg.width = w
        bg.height = 68
        bg.color = "0x26301CFF"
        ringAround(g, -6, -2, w + 12, 80)
    end if
    tx = 22
    if m.anyIcon then tx = 70
    if it.icon <> ""
        ic = g.createChild("Poster")
        ic.uri = it.icon
        ic.width = 34
        ic.height = 34
        ic.translation = [18, 21]
        if focused then ic.blendColor = m.gold else ic.blendColor = m.muted
        tx = 70
    end if
    ' what sits on the right: a switch, a value chip or a chevron
    rightW = 0
    v = LCase(it.value)
    if v = "on" or v = "off"
        sw = g.createChild("Poster")
        sw.uri = "pkg:/images/w/switch-" + v + ".png"
        sw.width = 64
        sw.height = 34
        sw.translation = [w - 18 - 64, 21]
        rightW = 64
    else if it.value <> ""
        vl = g.createChild("Label")
        vl.font = hFont("bold", 22)
        vl.color = m.gold
        vl.text = it.value
        vl.height = 36
        vl.vertAlign = "center"
        vl.maxLines = 1
        vw = Int(vl.boundingRect().width)
        if vw > 250
            vw = 250
            vl.width = 250
        end if
        ring = g.createChild("Poster")
        ring.uri = "pkg:/images/pill-ring.9.png"
        ring.blendColor = "0x5F6E45FF"
        ring.width = vw + 28
        ring.height = 36
        ring.translation = [w - 18 - vw - 28, 20]
        vl.translation = [w - 18 - vw - 14, 20]
        rightW = vw + 28
    else if it.go
        ch = addLabel(g, Chr(8250), "bold", 34, m.muted, w - 18 - 20, 0, 20)
        ch.height = 76
        ch.vertAlign = "center"
        rightW = 20
    end if
    tw = w - tx - 18 - rightW - 20
    col = m.ink
    if focused then col = m.lit
    t = addLabel(g, "", "bold", 27, col, tx, 0, tw)
    dlgText(t, it.name, "bold")
    if it.sub <> ""
        t.translation = [tx, 9]
        s = addLabel(g, "", "regular", 22, m.muted, tx, 41, tw)
        dlgText(s, it.sub, "regular")
    else
        t.height = 76
        t.vertAlign = "center"
    end if
end sub

' one wide button (the main action, or a button of a question)
sub drawWide(g as object, it as object, x as integer, w as integer, h as integer, gold as boolean)
    focused = (it.i = m.sel)
    bg = g.createChild("Poster")
    ' the button art has 13 px of clear edge on every side
    bg.translation = [x - 13, -13]
    bg.width = w + 26
    bg.height = h + 26
    ink = m.ink
    if focused
        bg.uri = "pkg:/images/w/button-fill-v2.9.png"
        bg.blendColor = m.gold
        ink = m.goldInk
    else
        bg.uri = "pkg:/images/w/button-outline-v2.9.png"
        if gold then bg.blendColor = m.gold else bg.blendColor = "0x5F6E45FF"
    end if
    l = g.createChild("Label")
    l.font = hFont("bold", 30)
    l.color = ink
    l.maxLines = 1
    l.text = it.name
    l.height = h
    l.vertAlign = "center"
    lw = Int(l.boundingRect().width)
    if lw > w - 80
        lw = w - 80
        l.width = lw
    end if
    iw = 0
    if it.icon <> "" then iw = 30 + 14
    sx = x + Int((w - iw - lw) / 2)
    if it.icon <> ""
        ic = g.createChild("Poster")
        ic.uri = it.icon
        ic.width = 30
        ic.height = 30
        ic.blendColor = ink
        ic.translation = [sx, Int(h / 2) - 15]
    end if
    l.translation = [sx + iw, 0]
end sub

sub drawStrip(g as object, ln as object)
    n = ln.items.count()
    gap = 14
    tw = Int((m.colW - (n - 1) * gap) / n)
    x = 0
    if ln.kind = "btn"
        ' a question's buttons: side by side in the middle
        gap = 24
        tw = 300
        if n = 3 then tw = 204
        x = Int((m.colW - n * tw - (n - 1) * gap) / 2)
    end if
    for each it in ln.items
        focused = (it.i = m.sel)
        if ln.kind = "btn"
            drawWide(g, it, x, tw, ln.h, false)
        else if ln.kind = "pic"
            back = g.createChild("Rectangle")
            back.translation = [x, 0]
            back.width = tw
            back.height = ln.h
            back.color = "0x1D2418FF"
            p = g.createChild("Poster")
            p.translation = [x, 0]
            p.width = tw
            p.height = ln.h
            p.loadDisplayMode = "scaleToZoom"
            p.uri = it.pic
            band = g.createChild("Rectangle")
            band.translation = [x, ln.h - 40]
            band.width = tw
            band.height = 40
            band.color = "0x0B0E09CC"
            col = m.ink
            if focused then col = m.lit
            l = addLabel(g, it.name, "bold", 24, col, x + 12, ln.h - 40, tw - 24)
            l.height = 40
            l.vertAlign = "center"
            if focused then ringAround(g, x - 5, -5, tw + 10, ln.h + 10)
        else
            bg = g.createChild("Poster")
            bg.translation = [x - 13, -13]
            bg.width = tw + 26
            bg.height = ln.h + 26
            ink = m.ink
            sink = m.muted
            if focused
                bg.uri = "pkg:/images/w/button-fill-v2.9.png"
                bg.blendColor = m.gold
                ink = m.goldInk
                sink = m.goldInk
            else
                bg.uri = "pkg:/images/w/button-outline-v2.9.png"
                bg.blendColor = "0x5F6E45FF"
            end if
            ty = 50
            if it.icon <> ""
                ic = g.createChild("Poster")
                ic.uri = it.icon
                ic.width = 44
                ic.height = 44
                ic.blendColor = ink
                ic.translation = [x + Int(tw / 2) - 22, 22]
                ty = 76
            end if
            if it.sub = "" then ty = ty + 14
            l = addLabel(g, it.name, "bold", 28, ink, x + 8, ty, tw - 16)
            l.horizAlign = "center"
            if it.sub <> ""
                s = addLabel(g, it.sub, "regular", 22, sink, x + 8, ty + 34, tw - 16)
                s.horizAlign = "center"
            end if
        end if
        x = x + tw + gap
    end for
end sub

' the key hints, and how many choices are below the fold
sub drawFoot(hidden as integer)
    m.foot.removeChildrenIndex(m.foot.getChildCount(), 0)
    y = m.cardH - 36 - 30
    n = m.items.count()
    keys = []
    if n = 0
        keys.push(["BACK", "Close"])
    else if n = 1 and m.ask
        keys.push(["OK", "Close"])
    else
        keys.push(["OK", "Choose"])
        keys.push(["BACK", "Close"])
    end if
    widths = []
    total = 0
    nodes = []
    for each k in keys
        cap = m.foot.createChild("Rectangle")
        cap.color = m.muted
        cap.height = 30
        kl = m.foot.createChild("Label")
        kl.font = hFont("bold", 22)
        kl.color = m.goldInk
        kl.text = k[0]
        kl.height = 30
        kl.vertAlign = "center"
        kw = Int(kl.boundingRect().width) + 18
        cap.width = kw
        tl = m.foot.createChild("Label")
        tl.font = hFont("regular", 22)
        tl.color = m.muted
        tl.text = k[1]
        tl.height = 30
        tl.vertAlign = "center"
        tw = Int(tl.boundingRect().width)
        nodes.push({ cap: cap, kl: kl, tl: tl, kw: kw, tw: tw })
        total = total + kw + 10 + tw
    end for
    total = total + (nodes.count() - 1) * 28
    x = 48
    if m.ask then x = Int((m.cardW - total) / 2)
    if m.colX[0] > 48 then x = m.colX[0]
    for each nd in nodes
        nd.cap.translation = [x, y]
        nd.kl.translation = [x + 9, y]
        nd.tl.translation = [x + nd.kw + 10, y]
        x = x + nd.kw + 10 + nd.tw + 28
    end for
    if hidden > 0
        more = addLabel(m.foot, Chr(9660) + " " + hidden.toStr() + " more", "bold", 22, m.muted, m.cardW - 48 - 200, y, 200)
        more.horizAlign = "right"
        more.height = 30
        more.vertAlign = "center"
    end if
end sub

' the nearest line you can land on in a column, by height on the card
function nearest(c as integer, y as integer) as integer
    best = -1
    bestD = 100000
    for l = 0 to m.cols[c].count() - 1
        ln = m.cols[c][l]
        if ln.type <> "head"
            d = Abs(ln.y - y)
            if d < bestD
                bestD = d
                best = l
            end if
        end if
    end for
    return best
end function

sub moveTo(c as integer, l as integer, k as integer)
    ln = m.cols[c][l]
    if k > ln.items.count() - 1 then k = ln.items.count() - 1
    if k < 0 then k = 0
    m.sel = ln.items[k].i
    m.top.buttonFocused = m.sel
    draw()
end sub

function hKeyInner(key as string, press as boolean) as boolean
    if not m.isOpen then return false
    if hMediaKey(key) then return false
    if not press then return true
    if key = "back"
        m.top.close = true
        return true
    end if
    at = findSel()
    if at = invalid
        if key = "OK" then m.top.close = true
        return true
    end if
    if key = "up" or key = "down"
        dir = 1
        if key = "up" then dir = -1
        l = at.l + dir
        while l >= 0 and l < m.cols[at.c].count()
            if m.cols[at.c][l].type <> "head"
                moveTo(at.c, l, at.k)
                return true
            end if
            l = l + dir
        end while
    else if key = "left" or key = "right"
        dir = 1
        if key = "left" then dir = -1
        ln = m.cols[at.c][at.l]
        k = at.k + dir
        if k >= 0 and k < ln.items.count()
            moveTo(at.c, at.l, k)
        else
            c = at.c + dir
            if c >= 0 and c <= 1 and m.cols[c].count() > 0
                l = nearest(c, ln.y)
                ' into a strip from its far side
                k = 0
                if dir < 0 then k = 99
                if l >= 0 then moveTo(c, l, k)
            end if
        end if
    else if key = "OK"
        m.top.buttonSelected = m.sel
    end if
    return true
end function

' menu sound for whatever the handler above took (source/util.brs hKeySfx)
function onKeyEvent(key as string, press as boolean) as boolean
    return hKeySfx(key, press, hKeyInner(key, press))
end function
