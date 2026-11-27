' Generic player side sheet. Items (all optional fields):
'   { kind: "kicker", text }                       gold caps label
'   { kind: "head", icon, text }                   Fell italic sub-header with an icon
'   { kind: "twig" }                               dark-bark twig divider
'   { kind: "note", text }                         muted sentence
'   { kind: "row", id, title, desc, on, lead, tag, chevron, thumb, progress, h }
'        lead: "tick" (default; gold when on), "none", or an icon name from images/player
'   { kind: "step", id, icon, title, value }       Left/Right changes it
'   { kind: "presets", id, options: [{ name, color, bx, outline, size }], sel }
'   { kind: "ruler", id, value, label }            subtitle timing, seconds (-2..+2 drawn)
'   { kind: "stats", kicker, note, nums: [[value, label], ...] }
'   { kind: "pipe", steps: [{ icon, title, desc }], note }
'   { kind: "pills", id, options: [label, ...], sel }
sub init()
    m.c = hColors()
    m.top.findNode("title").font = hFont("fell", 40)
    m.content = m.top.findNode("content")
    m.hints = m.top.findNode("hints")
    m.nodes = []
    m.focusables = []
    m.f = 0
    m.scroll = 0
    m.viewH = 840
end sub

sub onTitle()
    m.top.findNode("title").text = m.top.sheetTitle
    if m.top.sheetIcon <> "" then m.top.findNode("icon").uri = "pkg:/images/player/" + m.top.sheetIcon + ".png"
end sub

function lbl(parent as object, text as dynamic, font as object, color as dynamic, x as integer, y as integer, w = 0 as integer) as object
    l = parent.createChild("Label")
    l.font = font
    l.color = color
    l.text = sval(text)
    l.translation = [x, y]
    if w > 0
        l.width = w
        l.maxLines = 1
    end if
    return l
end function

function pic(parent as object, uri as string, x as integer, y as integer, w as integer, h as integer, tint = invalid as dynamic) as object
    p = parent.createChild("Poster")
    p.uri = uri
    p.translation = [x, y]
    p.width = w
    p.height = h
    if tint <> invalid and sval(tint) <> "" then p.blendColor = tint
    return p
end function

function sval(v as dynamic) as string
    if v = invalid then return ""
    if type(v) = "roString" or type(v) = "String" then return v
    return v.toStr()
end function

sub build()
    keepId = m.top.focusId
    if m.focusables.count() > 0 and m.f < m.focusables.count() and keepId = "" then keepId = m.focusables[m.f].it.id
    m.content.removeChildrenIndex(m.content.getChildCount(), 0)
    m.nodes = []
    m.focusables = []
    y = 0
    for each it in m.top.items
        g = m.content.createChild("Group")
        g.translation = [0, y]
        h = drawItem(g, it)
        entry = { it: it, g: g, y: y, h: h }
        m.nodes.push(entry)
        if it.id <> invalid and (it.kind = "row" or it.kind = "step" or it.kind = "presets" or it.kind = "ruler" or it.kind = "pills")
            m.focusables.push(entry)
        end if
        y = y + h
    end for
    m.f = 0
    for k = 0 to m.focusables.count() - 1
        if m.focusables[k].it.id = keepId then m.f = k
    end for
    m.top.focusId = ""
    paintFocus()
end sub

' Draws one item into g (local x 0..760; rows are 700 wide at x 20). Returns its height.
function drawItem(g as object, it as object) as integer
    k = it.kind
    if k = "kicker"
        lbl(g, UCase(sval(it.text)), hFont("caps", 22), m.c.gold, 30, 8)
        return 44
    else if k = "head"
        if it.icon <> invalid then pic(g, "pkg:/images/player/" + it.icon + ".png", 30, 16, 32, 32, m.c.gold)
        lbl(g, sval(it.text), hFont("fell", 36), m.c.ink, 76, 4)
        return 70
    else if k = "twig"
        pic(g, "pkg:/images/w/twig-1290-s5.png", 20, 0, 680, 61)
        return 50
    else if k = "note"
        l = lbl(g, sval(it.text), hFont("regular", 20), "0xC9C3A2FF", 30, 4)
        l.width = 680
        l.wrap = true
        l.lineSpacing = 2
        l.maxLines = 3
        return 30 + Int(l.boundingRect().height)
    else if k = "row"
        h = 70
        if it.h <> invalid then h = it.h
        hi = g.createChild("Rectangle")
        hi.width = 700
        hi.height = h
        hi.translation = [20, 0]
        hi.color = "0x26301CFF"
        hi.visible = false
        tx = 82
        lead = it.lead
        if lead = invalid then lead = "tick"
        if lead = "tick"
            tint = "0x2E3824FF"
            if it.on = true then tint = m.c.gold
            pic(g, "pkg:/images/player/check.png", 38, Int(h / 2) - 14, 28, 28, tint)
        else if lead <> "none"
            pic(g, "pkg:/images/player/" + lead + ".png", 38, Int(h / 2) - 15, 30, 30, m.c.gold)
        else
            tx = 40
        end if
        if it.thumb <> invalid
            bg = g.createChild("Rectangle")
            bg.width = 156
            bg.height = 88
            bg.color = "0x1A2214FF"
            bg.translation = [tx - 4, Int((h - 88) / 2)]
            p = pic(g, it.thumb, tx - 4, Int((h - 88) / 2), 156, 88)
            p.loadDisplayMode = "scaleToZoom"
            tx = tx + 172
        end if
        tw = 700 - tx - 20
        if it.tag <> invalid or it.chevron = true then tw = tw - 120
        hasSub = (it.desc <> invalid and it.desc <> "")
        ty = Int(h / 2) - 16
        if hasSub then ty = Int(h / 2) - 30
        t = lbl(g, sval(it.title), hFont("bold", 24), m.c.ink, tx, ty, tw)
        if hasSub then lbl(g, sval(it.desc), hFont("regular", 19), m.c.muted, tx, ty + 32, tw)
        if it.progress <> invalid and it.progress > 0
            bar = hBraid(g, 300, h - 16)
            bar.translation = [tx, h - 16]
            hBraidSet(bar, it.progress * 100)
        end if
        if it.tag <> invalid
            tl = lbl(g, UCase(sval(it.tag)), hFont("caps", 16), m.c.muted, 0, 0)
            tagW = Int(tl.boundingRect().width) + 20
            bx = g.createChild("Poster")
            bx.uri = "pkg:/images/w/button-outline.9.png"
            bx.blendColor = "0x5F6E45FF"
            bx.width = tagW + 24
            bx.height = 34 + 24
            bx.translation = [700 - 10 - tagW - 12, Int(h / 2) - 17 - 12]
            tl.translation = [700 - 10 - tagW + 10, Int(h / 2) - 11]
            tl.reparent(g, false)
        else if it.chevron = true
            pic(g, "pkg:/images/icons/home-right.png", 670, Int(h / 2) - 12, 24, 24, "0x5F6E45FF")
        end if
        g.addFields({ hi: hi, titleNode: t, ringH: h })
        return h + 10
    else if k = "step"
        hi = g.createChild("Rectangle")
        hi.width = 700
        hi.height = 58
        hi.translation = [20, 0]
        hi.color = "0x26301CFF"
        hi.visible = false
        pic(g, "pkg:/images/player/" + sval(it.icon) + ".png", 38, 15, 28, 28, m.c.gold)
        t = lbl(g, sval(it.title), hFont("bold", 23), m.c.ink, 82, 13)
        pic(g, "pkg:/images/icons/home-left.png", 500, 19, 20, 20, "0x5F6E45FF")
        v = lbl(g, sval(it.value), hFont("bold", 22), m.c.ink, 524, 14)
        v.width = 150
        v.horizAlign = "center"
        pic(g, "pkg:/images/icons/home-right.png", 680, 19, 20, 20, "0x5F6E45FF")
        g.addFields({ hi: hi, titleNode: t, ringH: 58 })
        return 66
    else if k = "presets"
        tiles = []
        x = 30
        sel = it.sel
        if sel = invalid then sel = -1
        for i = 0 to it.options.count() - 1
            o = it.options[i]
            tg = g.createChild("Group")
            tg.translation = [x, 0]
            r = tg.createChild("Rectangle")
            r.width = 124
            r.height = 70
            r.color = "0x23303AFF"
            sample = sampleLabel(tg, o)
            n = lbl(tg, sval(o.name), hFont("bold", 18), m.c.muted, -10, 80)
            n.width = 144
            n.horizAlign = "center"
            if i = sel then n.color = "0xFFE7A0FF"
            ring = pic(tg, "pkg:/images/w/focus-ring.9.png", -20, -20, 164, 110)
            ring.visible = false
            tiles.push(ring)
            x = x + 138
        end for
        g.addFields({ tiles: tiles, ringH: 0 })
        return 126
    else if k = "ruler"
        hi = g.createChild("Rectangle")
        hi.width = 700
        hi.height = 150
        hi.translation = [20, 0]
        hi.color = "0x26301CFF"
        v = it.value
        if v = invalid then v = 0
        txt = fmtDelay(v)
        big = lbl(g, txt, hFont("bold", 54), "0xFFE7A0FF", 20, 8)
        big.width = 560
        big.horizAlign = "center"
        sideTxt = "IN SYNC"
        if v < 0 then sideTxt = "EARLIER"
        if v > 0 then sideTxt = "LATER"
        lbl(g, sideTxt, hFont("caps", 20), m.c.muted, 560, 32)
        for t = -20 to 20
            tk = g.createChild("Rectangle")
            th = 11
            tk.color = "0x5F6E45FF"
            if t mod 5 = 0
                th = 24
                tk.color = m.c.muted
            end if
            tk.width = 2
            tk.height = th
            tk.translation = [370 + t * 15, 104 - Int(th / 2)]
        end for
        cv = v
        if cv < -2 then cv = -2
        if cv > 2 then cv = 2
        mk = g.createChild("Rectangle")
        mk.width = 8
        mk.height = 30
        mk.color = m.c.gold
        mk.translation = [370 + Int(cv * 150) - 3, 89]
        lbl(g, "−2 s", hFont("regular", 18), m.c.muted, 34, 92)
        lbl(g, "+2 s", hFont("regular", 18), m.c.muted, 668, 92)
        g.addFields({ hi: hi, ringH: 150 })
        return 164
    else if k = "stats"
        pic(g, "pkg:/images/player/check.png", 30, 6, 24, 24, m.c.gold)
        kk = lbl(g, UCase(sval(it.kicker)), hFont("caps", 24), m.c.gold, 64, 2)
        nt = lbl(g, sval(it.note), hFont("regular", 20), m.c.muted, 74 + Int(kk.boundingRect().width), 4)
        x = 30
        for each nv in it.nums
            a = lbl(g, sval(nv[0]), hFont("bold", 56), m.c.ink, x, 44)
            b = lbl(g, UCase(sval(nv[1])), hFont("regular", 16), m.c.muted, x, 112)
            w = a.boundingRect().width
            if b.boundingRect().width > w then w = b.boundingRect().width
            x = x + Int(w) + 42
        end for
        return 150
    else if k = "pipe"
        y = 0
        for i = 0 to it.steps.count() - 1
            s = it.steps[i]
            bx = g.createChild("Poster")
            bx.uri = "pkg:/images/w/button-outline.9.png"
            stepTint = m.c.gold
            if i = 1 then stepTint = m.c.rope
            bx.blendColor = stepTint
            bx.translation = [20 - 12, y - 12]
            bx.width = 724
            bx.height = 96
            fill = g.createChild("Rectangle")
            fill.color = "0x1A2214FF"
            fill.width = 690
            fill.height = 62
            fill.translation = [25, y + 5]
            pic(g, "pkg:/images/player/" + sval(s.icon) + ".png", 40, y + 21, 30, 30, stepTint)
            lbl(g, sval(s.title), hFont("bold", 22), m.c.ink, 84, y + 8, 610)
            lbl(g, sval(s.desc), hFont("regular", 18), m.c.muted, 84, y + 38, 610)
            if i < it.steps.count() - 1 then pic(g, "pkg:/images/icons/home-down.png", 358, y + 74, 22, 22, "0x6E4526FF")
            y = y + 98
        end for
        if it.note <> invalid and it.note <> ""
            l = lbl(g, sval(it.note), hFont("regular", 19), "0xC9C3A2FF", 30, y - 4)
            l.width = 680
            l.wrap = true
            l.lineSpacing = 2
            l.maxLines = 2
            y = y + Int(l.boundingRect().height) + 10
        end if
        return y + 10
    else if k = "pills"
        x = 30
        sel = it.sel
        if sel = invalid then sel = 0
        pills = []
        for i = 0 to it.options.count() - 1
            t = lbl(g, sval(it.options[i]), hFont("bold", 22), m.c.ink, 0, 0)
            w = Int(t.boundingRect().width) + 40
            if w < 70 then w = 70
            bg = g.createChild("Poster")
            bg.translation = [x - 12, -12]
            bg.width = w + 24
            bg.height = 80
            if i = sel
                bg.uri = "pkg:/images/w/button-outline.9.png"
                bg.blendColor = m.c.gold
                t.color = "0xFFE7A0FF"
            else
                bg.uri = "pkg:/images/w/button-outline.9.png"
                bg.blendColor = "0x404B2DFF"
            end if
            t.reparent(g, false)
            t.width = w
            t.horizAlign = "center"
            t.translation = [x, 15]
            pills.push({ bg: bg, x: x, w: w })
            x = x + w + 10
        end for
        g.addFields({ pills: pills, ringH: 0 })
        return 80
    end if
    return 0
end function

function fmtDelay(v as float) as string
    if Abs(v) < 0.05 then return "0.0 s"
    s = Str(Int(Abs(v) * 10 + 0.5) / 10).Trim()
    if Instr(1, s, ".") = 0 then s = s + ".0"
    if v < 0 then return "−" + s + " s"
    return "+" + s + " s"
end function

' A tiny "Sammy." in the preset's style for the preset tiles.
function sampleLabel(parent as object, o as object) as object
    size = 22
    if o.size = "L" then size = 27
    y = 38
    if o.raised = true then y = 14
    if o.bx = true
        b = parent.createChild("Rectangle")
        b.color = "0x000000B0"
        b.width = 84
        b.height = 28
        b.translation = [20, y - 2]
    end if
    if o.outline = true
        sh = parent.createChild("Label")
        sh.font = hFont("regular", size)
        sh.color = "0x000000FF"
        sh.text = "Sammy."
        sh.width = 124
        sh.horizAlign = "center"
        sh.translation = [1, y + 1]
    end if
    l = parent.createChild("Label")
    l.font = hFont("regular", size)
    l.color = o.color
    l.text = "Sammy."
    l.width = 124
    l.horizAlign = "center"
    l.translation = [0, y]
    return l
end function

' ---------- focus ----------
sub paintFocus()
    if m.ring = invalid
        m.ring = m.content.createChild("Poster")
        m.ring.uri = "pkg:/images/w/focus-ring.9.png"
        m.moss = m.content.createChild("Poster")
        m.moss.width = 125
        m.moss.height = 96
    end if
    ' keep ring and moss on top
    m.content.removeChild(m.ring)
    m.content.removeChild(m.moss)
    m.content.appendChild(m.ring)
    m.content.appendChild(m.moss)
    for each e in m.nodes
        if e.g.hasField("hi") then e.g.hi.visible = (e.it.kind = "ruler")
        if e.g.hasField("titleNode") then e.g.titleNode.color = m.c.ink
        if e.g.hasField("tiles")
            for each t in e.g.tiles
                t.visible = false
            end for
        end if
    end for
    m.ring.visible = false
    m.moss.visible = false
    if m.focusables.count() = 0
        paintHints("")
        return
    end if
    e = m.focusables[m.f]
    kind = e.it.kind
    if e.g.hasField("hi") then e.g.hi.visible = true
    if e.g.hasField("titleNode") then e.g.titleNode.color = "0xFFE7A0FF"
    if e.g.hasField("tiles")
        sel = e.it.sel
        if sel = invalid then sel = 0
        if sel >= 0 and sel < e.g.tiles.count() then e.g.tiles[sel].visible = true
    else if kind = "pills"
        ' the gold outline on the chosen pill is the focus
    else
        m.ring.translation = [0, e.y - 20]
        m.ring.width = 740
        m.ring.height = e.g.ringH + 40
        m.ring.visible = true
        hMossHug(m.moss, 20, e.y, 720, sval(e.it.id))
        m.moss.visible = true
    end if
    ' scroll so the focused item shows
    top = e.y - 30
    bottom = e.y + e.g.ringH + 40
    if top < m.scroll then m.scroll = top
    if bottom > m.scroll + m.viewH then m.scroll = bottom - m.viewH
    if m.scroll < 0 then m.scroll = 0
    if m.f = 0 then m.scroll = 0
    m.content.translation = [0, -m.scroll]
    paintHints(kind)
end sub

sub paintHints(kind as string)
    if kind = "step" or kind = "ruler"
        keys = [{ icon: "lr", label: "Change" }, { icon: "down", label: "Next" }, { icon: "back", label: "Done" }]
    else if kind = "presets" or kind = "pills"
        keys = [{ icon: "lr", label: "Choose" }, { icon: "back", label: "Done" }]
    else
        keys = [{ text: "OK", label: "Choose" }, { icon: "back", label: "Close" }]
    end if
    m.hints.keys = keys
end sub

function hKeyInner(key as string, press as boolean) as boolean
    ' hidden but still holding focus (Roku keeps focus on a hidden child): let the screen behind take the key
    if not m.top.visible then return false
    if not press then return false
    if key = "back"
        m.top.action = { cmd: "close" }
        return true
    end if
    if m.focusables.count() = 0 then return true
    e = m.focusables[m.f]
    kind = e.it.kind
    if key = "up"
        if m.f > 0
            m.f = m.f - 1
            paintFocus()
        end if
    else if key = "down"
        if m.f < m.focusables.count() - 1
            m.f = m.f + 1
            paintFocus()
        end if
    else if key = "left" or key = "right"
        dir = 1
        if key = "left" then dir = -1
        if kind = "step" or kind = "ruler"
            m.top.action = { id: e.it.id, cmd: "step", dir: dir }
        else if kind = "presets" or kind = "pills"
            sel = e.it.sel
            if sel = invalid or sel < 0 then sel = 0
            sel = sel + dir
            if sel < 0 then sel = 0
            if sel > e.it.options.count() - 1 then sel = e.it.options.count() - 1
            m.top.action = { id: e.it.id, cmd: "pick", index: sel }
        else if key = "left"
            m.top.action = { cmd: "close" }
        end if
    else if key = "OK"
        if kind = "row" then m.top.action = { id: e.it.id, cmd: "ok" }
    else
        return false
    end if
    return true
end function

' menu sound for whatever the handler above took (source/util.brs hKeySfx)
function onKeyEvent(key as string, press as boolean) as boolean
    return hKeySfx(key, press, hKeyInner(key, press))
end function
