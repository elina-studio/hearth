sub init()
    m.list = m.top.findNode("list")
    m.titleL = m.top.findNode("title")
    m.titleL.font = hFont("bold", 38)
    m.msg = m.top.findNode("msg")
    m.msg.font = hFont("regular", 24)
    m.rule = m.top.findNode("rule")
    m.more = m.top.findNode("more")
    m.more.font = hFont("bold", 22)
    m.hint = m.top.findNode("hint")
    m.hint.font = hFont("regular", 22)
    m.hold = m.top.findNode("hold")
    m.hold.observeField("fire", "onHold")
    m.rowH = 64
    m.headH = 44
    m.isOpen = false
    m.done = false
    m.prev = invalid
end sub

' Called by hShowDialog once the sheet is in the scene. prev is whatever had focus, and gets it back on close.
sub open(prev = invalid as dynamic)
    m.prev = prev
    m.btns = m.top.buttons
    if m.btns = invalid then m.btns = []
    m.heads = m.top.heads
    if m.heads = invalid then m.heads = {}
    m.pop = (m.top.popup = true and m.btns.count() <= 3)
    if m.pop
        openPopup()
        return
    end if
    m.titleL.text = m.top.title
    y = 68 + m.titleL.boundingRect().height + 10
    lines = m.top.message
    body = ""
    if lines <> invalid
        for each ln in lines
            if ln <> invalid and ln <> ""
                if body <> "" then body = body + Chr(10)
                body = body + ln
            end if
        end for
    end if
    m.msg.text = body
    if body <> ""
        m.msg.translation = [1220, y]
        y = y + m.msg.boundingRect().height + 14
    else
        y = y + 4
    end if
    m.rule.translation = [1220, y]
    y = y + 20
    m.list.translation = [1206, y]
    m.viewH = 936 - y
    ' y of every row; a group title sits above the button it is keyed to
    m.ys = []
    m.headY = {}
    yy = 0
    for i = 0 to m.btns.count() - 1
        h = m.heads[i.toStr()]
        if h <> invalid
            if i > 0 then yy = yy + 12
            m.headY[i.toStr()] = yy
            yy = yy + m.headH
        end if
        m.ys.push(yy)
        yy = yy + m.rowH
    end for
    m.sel = m.top.buttonFocused
    if m.sel < 0 or m.sel >= m.btns.count() then m.sel = 0
    m.scroll = 0
    if m.btns.count() > 1 then m.hint.text = "OK  Choose      BACK  Close" else m.hint.text = "OK  Close"
    m.isOpen = true
    m.top.setFocus(true)
    m.hold.control = "start"
    draw()
end sub

function bodyText() as string
    lines = m.top.message
    body = ""
    if lines <> invalid
        for each ln in lines
            if ln <> invalid and ln <> ""
                if body <> "" then body = body + Chr(10)
                body = body + ln
            end if
        end for
    end if
    return body
end function

' The centred card: title, words, then the buttons in one row. 760 wide, as tall as its words need.
sub openPopup()
    m.top.findNode("shade").color = "0x0B0E09D9"
    m.rule.visible = false
    m.more.visible = false
    w = 760
    x = Int((1920 - w) / 2)
    m.titleL.horizAlign = "center"
    m.titleL.font = hFont("bold", 48)
    m.titleL.width = w - 120
    m.titleL.text = m.top.title
    th = m.titleL.boundingRect().height
    body = bodyText()
    m.msg.horizAlign = "center"
    m.msg.font = hFont("regular", 26)
    m.msg.width = w - 120
    m.msg.maxLines = 6
    m.msg.text = body
    bh = 0
    if body <> "" then bh = m.msg.boundingRect().height + 12
    n = m.btns.count()
    btnH = 0
    if n > 0 then btnH = 72 + 36
    ' 56 above the title, 36 between the words and the buttons, then the hint line and 40 below it
    h = Int(56 + th + bh + 36 + btnH + 28 + 40)
    y = Int((1080 - h) / 2)
    panel = m.top.findNode("panel")
    ring = m.top.findNode("panelRing")
    ' panel.9 carries 13 px of clear edge on every side
    ring.translation = [x - 15, y - 15]
    ring.width = w + 30
    ring.height = h + 30
    ring.visible = true
    panel.translation = [x - 13, y - 13]
    panel.width = w + 26
    panel.height = h + 26
    m.titleL.translation = [x + 60, y + 56]
    m.msg.translation = [x + 60, y + 56 + th + 12]
    m.popY = y + 56 + th + bh + 36
    m.popX = x
    m.popW = w
    m.hint.horizAlign = "center"
    m.hint.width = w
    m.hint.translation = [x, y + h - 40 - 28]
    if n > 1
        m.hint.text = "OK  Choose      BACK  Close"
    else
        m.hint.text = "OK  Close"
    end if
    m.list.translation = [0, 0]
    m.sel = m.top.buttonFocused
    if m.sel < 0 or m.sel >= n then m.sel = 0
    m.isOpen = true
    m.top.setFocus(true)
    m.hold.control = "start"
    draw()
end sub

sub drawPopup()
    m.list.removeChildrenIndex(m.list.getChildCount(), 0)
    n = m.btns.count()
    if n = 0 then return
    gap = 24
    bw = 300
    if n = 3 then bw = 208
    total = n * bw + (n - 1) * gap
    x = m.popX + Int((m.popW - total) / 2)
    for i = 0 to n - 1
        focused = (i = m.sel)
        bg = m.list.createChild("Poster")
        ' the button images carry 13 px of clear edge on every side
        bg.translation = [x - 13, m.popY - 13]
        bg.width = bw + 26
        bg.height = 72 + 26
        lab = m.list.createChild("Label")
        lab.font = hFont("bold", 30)
        lab.text = m.btns[i]
        lab.width = bw - 24
        lab.height = 72
        lab.horizAlign = "center"
        lab.vertAlign = "center"
        lab.maxLines = 1
        lab.translation = [x + 12, m.popY]
        if focused
            bg.uri = "pkg:/images/w/button-fill-v2.9.png"
            bg.blendColor = "0xE0B34AFF"
            lab.color = "0x1F1606FF"
        else
            bg.uri = "pkg:/images/w/button-outline-v2.9.png"
            bg.blendColor = "0x5F6E45FF"
            lab.color = "0xEDE6CAFF"
        end if
        x = x + bw + gap
    end for
end sub

' a room that grabs focus when its data lands must not leave the sheet open and deaf
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
    ' focus goes back where it was, as it does when a Roku dialog closes; a newer sheet keeps it instead
    if mine and m.prev <> invalid then m.prev.setFocus(true)
    m.prev = invalid
    m.top.wasClosed = true
    if par <> invalid then par.removeChild(m.top)
end sub

sub draw()
    if m.pop = true
        drawPopup()
        return
    end if
    m.list.removeChildrenIndex(m.list.getChildCount(), 0)
    n = m.btns.count()
    if n = 0 then return
    y = m.ys[m.sel]
    if y - m.scroll > m.viewH - m.rowH then m.scroll = y - m.viewH + m.rowH
    if y - m.scroll < 0 then m.scroll = y
    hy = m.headY[m.sel.toStr()]
    if hy <> invalid and hy < m.scroll then m.scroll = hy
    hidden = 0
    for i = 0 to n - 1
        hy = m.headY[i.toStr()]
        if hy <> invalid and hy - m.scroll >= 0 and hy - m.scroll + m.headH <= m.viewH
            l = m.list.createChild("Label")
            l.font = hFont("caps", 22)
            l.color = "0xB5AF8CFF"
            l.text = UCase(m.heads[i.toStr()])
            l.translation = [14, hy - m.scroll + 12]
        end if
        y = m.ys[i] - m.scroll
        if y >= 0 and y + m.rowH <= m.viewH
            g = m.list.createChild("Group")
            g.translation = [0, y]
            drawRow(g, m.btns[i], i = m.sel)
        else if y + m.rowH > m.viewH
            hidden = hidden + 1
        end if
    end for
    if hidden > 0 then m.more.text = "▼ " + hidden.toStr() + " more" else m.more.text = ""
end sub

' "Shuffle: Off" is drawn as the name on the left and the value on the right
sub drawRow(g as object, caption as string, focused as boolean)
    name = caption
    value = ""
    at = Instr(1, caption, ": ")
    ' only a short "Name: value" is a setting; a title that happens to hold a colon stays whole
    if at > 1 and at < 26 and Len(caption) - at - 1 <= 24
        name = Left(caption, at - 1)
        value = Mid(caption, at + 2)
    end if
    if focused
        bg = g.createChild("Poster")
        bg.uri = "pkg:/images/w/button-fill.9.png"
        bg.blendColor = "0xE0B34AFF"
        bg.width = 608
        bg.height = 56
    end if
    lab = g.createChild("Label")
    lab.font = hFont("bold", 27)
    lab.text = name
    lab.translation = [22, 0]
    lab.height = 56
    lab.vertAlign = "center"
    lab.maxLines = 1
    if focused then lab.color = "0x1F1606FF" else lab.color = "0xEDE6CAFF"
    if value = ""
        lab.width = 564
        return
    end if
    v = g.createChild("Label")
    v.font = hFont("bold", 24)
    v.text = value
    v.horizAlign = "right"
    v.height = 56
    v.vertAlign = "center"
    v.maxLines = 1
    if focused then v.color = "0x1F1606FF" else v.color = "0xE0B34AFF"
    ' the name keeps its room; a long value gets what is left, and is cut with an ellipsis
    lw = lab.boundingRect().width
    if lw > 330
        lw = 330
        lab.width = 330
    end if
    v.width = 564 - lw - 24
    v.translation = [22 + lw + 24, 0]
end sub

function hKeyInner(key as string, press as boolean) as boolean
    if not m.isOpen then return false
    if hMediaKey(key) then return false
    if not press then return true
    n = m.btns.count()
    if key = "back"
        m.top.close = true
    else if key = "up" or key = "down" or (m.pop = true and (key = "left" or key = "right"))
        if n = 0 then return true
        if key = "up" or key = "left" then m.sel = m.sel - 1 else m.sel = m.sel + 1
        if m.sel < 0 then m.sel = 0
        if m.sel > n - 1 then m.sel = n - 1
        m.top.buttonFocused = m.sel
        draw()
    else if key = "OK"
        if n = 0
            m.top.close = true
        else
            m.top.buttonSelected = m.sel
        end if
    end if
    return true
end function

' menu sound for whatever the handler above took (source/util.brs hKeySfx)
function onKeyEvent(key as string, press as boolean) as boolean
    return hKeySfx(key, press, hKeyInner(key, press))
end function
