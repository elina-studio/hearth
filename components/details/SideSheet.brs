sub init()
    m.top.visible = false
    m.list = m.top.findNode("list")
    m.heading = m.top.findNode("heading")
    m.heading.font = hFont("fell", 40)
    m.hIcon = m.top.findNode("hIcon")
    m.note = m.top.findNode("note")
    m.note.font = hFont("regular", 22)
    m.more = m.top.findNode("more")
    m.more.font = hFont("bold", 22)
    m.hint = m.top.findNode("hint")
    m.hint.font = hFont("regular", 22)
    m.rowH = 56
    m.headH = 46
    m.viewH = 780
end sub

sub open(unused = invalid as dynamic)
    m.heading.text = m.top.heading
    m.hIcon.uri = "pkg:/images/icons/d-" + m.top.icon + ".png"
    m.note.text = m.top.note
    top = 160
    if m.top.note <> "" then top = 196
    m.list.translation = [1206, top]
    m.viewH = 940 - top
    m.rows = m.top.rows
    if m.rows = invalid then m.rows = []
    ' y of every row, so the list can scroll by whole rows
    m.ys = []
    y = 0
    m.sel = -1
    for i = 0 to m.rows.count() - 1
        r = m.rows[i]
        if r.header <> invalid
            if i > 0 then y = y + 10
            m.ys.push(y)
            y = y + m.headH
        else
            m.ys.push(y)
            y = y + m.rowH
            if m.sel = -1 and r.action <> invalid then m.sel = i
        end if
    end for
    m.total = y
    m.scroll = 0
    hasAction = (m.sel >= 0)
    if hasAction then m.hint.text = "OK  Choose      BACK  Close" else m.hint.text = "BACK  Close"
    m.top.visible = true
    m.top.setFocus(true)
    draw()
end sub

sub close(unused = invalid as dynamic)
    if not m.top.visible then return
    m.top.visible = false
    m.top.closed = true
end sub

sub draw()
    m.list.removeChildrenIndex(m.list.getChildCount(), 0)
    ' keep the selected row in view
    if m.sel >= 0
        y = m.ys[m.sel]
        if y - m.scroll > m.viewH - m.rowH then m.scroll = y - m.viewH + m.rowH
        if y - m.scroll < 0 then m.scroll = y
        ' show the group title above the first row of a group too
        if m.sel > 0 and m.rows[m.sel - 1].header <> invalid and m.ys[m.sel - 1] < m.scroll then m.scroll = m.ys[m.sel - 1]
    end if
    hidden = 0
    for i = 0 to m.rows.count() - 1
        r = m.rows[i]
        y = m.ys[i] - m.scroll
        h = m.rowH
        if r.header <> invalid then h = m.headH
        if y >= 0 and y + h <= m.viewH
            g = m.list.createChild("Group")
            g.translation = [0, y]
            if r.header <> invalid
                l = g.createChild("Label")
                l.font = hFont("caps", 22)
                l.color = "0xB5AF8CFF"
                l.text = UCase(r.header)
                l.translation = [14, 12]
            else
                drawRow(g, r, i = m.sel)
            end if
        else if y + h > m.viewH
            hidden = hidden + 1
        end if
    end for
    if hidden > 0 then m.more.text = "▼ " + hidden.toStr() + " more" else m.more.text = ""
end sub

sub drawRow(g as object, r as object, focused as boolean)
    if focused
        bg = g.createChild("Poster")
        bg.uri = "pkg:/images/w/panel.9.png"
        bg.blendColor = "0x1E2716FF"
        bg.translation = [-12, -12]
        bg.width = 608 + 24
        bg.height = 52 + 24
        ring = g.createChild("Poster")
        ring.uri = "pkg:/images/w/focus-ring.9.png"
        ring.translation = [-27, -27]
        ring.width = 608 + 54
        ring.height = 52 + 54
    end if
    x = 20
    if r.icon <> invalid and r.icon <> ""
        ic = g.createChild("Poster")
        ic.uri = "pkg:/images/icons/d-" + r.icon + ".png"
        ic.width = 28
        ic.height = 28
        ic.translation = [x, 12]
        ic.blendColor = "0xE0B34AFF"
        if r.action = invalid then ic.blendColor = "0x7E8A62FF"
        x = x + 44
    end if
    lab = g.createChild("Label")
    lab.font = hFont("bold", 23)
    lab.text = r.label
    lab.translation = [x, 0]
    lab.height = 52
    lab.vertAlign = "center"
    lab.maxLines = 1
    if focused then lab.color = "0xFFE7A0FF" else lab.color = "0xEDE6CAFF"
    right = g.createChild("Group")
    if r.stars <> invalid
        for k = 0 to 4
            s = right.createChild("Poster")
            if k < r.stars then s.uri = "pkg:/images/icons/d-starf.png" else s.uri = "pkg:/images/icons/d-star.png"
            s.width = 26
            s.height = 26
            s.blendColor = "0xE0B34AFF"
            s.translation = [460 + k * 30, 13]
        end for
        lab.width = 420
    else if r.checked = true
        c = right.createChild("Poster")
        c.uri = "pkg:/images/icons/d-check.png"
        c.width = 28
        c.height = 28
        c.translation = [576 - 28, 12]
        c.blendColor = "0xE0B34AFF"
        lab.width = 520 - x
    else if r.sub <> invalid and r.sub <> ""
        sl = g.createChild("Label")
        sl.font = hFont("regular", 22)
        sl.color = "0xB5AF8CFF"
        sl.text = r.sub
        sl.horizAlign = "right"
        sl.width = 300
        sl.height = 52
        sl.vertAlign = "center"
        sl.translation = [276, 0]
        lw = lab.boundingRect().width
        if x + lw > 270
            ' long label: let it run and drop the right-hand text
            if x + lw > 570 then lab.width = 576 - x
            if x + lw + sl.boundingRect().width + 20 > 576 then sl.visible = false
        end if
    else
        lab.width = 576 - x
    end if
end sub

function hKeyInner(key as string, press as boolean) as boolean
    if not m.top.visible then return false
    if hMediaKey(key) then return false
    if not press then return true
    if key = "back" or key = "options"
        close()
        return true
    end if
    if m.sel < 0 then return true
    r = m.rows[m.sel]
    if key = "up" or key = "down"
        d = 1
        if key = "up" then d = -1
        i = m.sel + d
        while i >= 0 and i < m.rows.count() and m.rows[i].action = invalid
            i = i + d
        end while
        if i >= 0 and i < m.rows.count()
            m.sel = i
        else if key = "up"
            m.scroll = 0
        end if
        draw()
    else if (key = "left" or key = "right") and r.stars <> invalid
        s = r.stars
        if key = "left" and s > 0 then s = s - 1
        if key = "right" and s < 5 then s = s + 1
        r.stars = s
        m.rows[m.sel] = r
        draw()
    else if key = "OK"
        m.top.visible = false
        m.top.result = r
        m.top.closed = true
    end if
    return true
end function

' menu sound for whatever the handler above took (source/util.brs hKeySfx)
function onKeyEvent(key as string, press as boolean) as boolean
    return hKeySfx(key, press, hKeyInner(key, press))
end function
