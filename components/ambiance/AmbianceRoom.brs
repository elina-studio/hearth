' Column geometry: the room is 1920 x 930 under the pills. The focused column is WIDE px,
' the others share the rest; RULE px of gold weave sits between neighbours.
sub init()
    m.H = 930
    m.WIDE = 760
    m.RULE = 14
    m.items = ambMoods()
    m.n = m.items.count()
    m.narrow = (1920 - m.WIDE - (m.n - 1) * m.RULE) / (m.n - 1)
    ' open on the mood used last
    m.index = 0
    last = CreateObject("roRegistrySection", "hearth").Read("ambLast")
    for i = 0 to m.items.count() - 1
        if m.items[i].mood = last then m.index = i
    end for
    m.active = false
    m.cols = []
    holder = m.top.findNode("cols")
    for i = 0 to m.n - 1
        it = m.items[i]
        c = {}
        g = holder.createChild("Group")
        c.group = g
        p = g.createChild("Poster")
        ' the picture is always drawn at the wide size and centred; the clip shows the middle of it
        p.width = m.WIDE
        p.height = m.H
        p.loadDisplayMode = "scaleToZoom"
        p.uri = it.still
        c.poster = p
        sh = g.createChild("Poster")
        sh.uri = "pkg:/images/shade.png"
        sh.height = 520
        sh.translation = [0, m.H - 520]
        c.shade = sh
        t = g.createChild("Label")
        t.font = hFont("caps", 64)
        t.wrap = true
        t.maxLines = 2
        t.vertAlign = "bottom"
        t.height = 160
        t.color = "0xEDE6CAFF"
        t.text = UCase(it.title)
        c.title = t
        s = g.createChild("Label")
        s.font = hFont("fell", 30)
        s.color = "0xB5AF8CFF"
        s.text = it.sub
        c.sub = s
        bar = g.createChild("Rectangle")
        bar.height = 6
        bar.color = "0xE0B34AFF"
        c.bar = bar
        m.cols.push(c)
        if i < m.n - 1
            w = holder.createChild("Poster")
            w.uri = "pkg:/images/amb/weave.png"
            w.width = m.RULE
            w.height = m.H
            c.rule = w
        end if
    end for
    m.cur = targets()
    layout(m.cur)
    m.step = m.top.findNode("step")
    m.step.observeField("fire", "onStep")
end sub

' target width for each column
function targets() as object
    out = []
    for i = 0 to m.n - 1
        if i = m.index then out.push(m.WIDE) else out.push(m.narrow)
    end for
    return out
end function

sub layout(widths as object)
    x = 0
    for i = 0 to m.n - 1
        c = m.cols[i]
        w = widths[i]
        c.group.translation = [x, 0]
        c.group.clippingRect = [0, 0, w, m.H]
        c.poster.translation = [(w - m.WIDE) / 2, 0]
        c.shade.width = w
        focused = (m.active and i = m.index)
        c.title.translation = [28, m.H - 250]
        c.title.width = w - 50
        c.sub.translation = [30, m.H - 78]
        c.sub.width = w - 50
        c.sub.visible = (w > m.narrow + 200)
        if focused then c.title.color = "0xE0B34AFF" else c.title.color = "0xEDE6CAFF"
        c.bar.width = w
        c.bar.translation = [0, m.H - 6]
        c.bar.visible = focused
        if focused or not m.active then c.group.opacity = 1.0 else c.group.opacity = 0.62
        x = x + w
        if c.rule <> invalid
            c.rule.translation = [x, 0]
            x = x + m.RULE
        end if
    end for
end sub

' ease the widths toward their targets, about a quarter of a second
sub onStep()
    goal = targets()
    done = true
    for i = 0 to m.n - 1
        d = goal[i] - m.cur[i]
        if Abs(d) < 2
            m.cur[i] = goal[i]
        else
            m.cur[i] = m.cur[i] + d * 0.35
            done = false
        end if
    end for
    layout(m.cur)
    if done then m.step.control = "stop"
end sub

sub focusIn(unused as dynamic)
    m.active = true
    layout(m.cur)
    m.top.setFocus(true)
end sub

sub refresh(unused as dynamic)
end sub

sub move(d as integer)
    i = m.index + d
    if i < 0 or i >= m.n then return
    m.index = i
    m.step.control = "start"
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if hMediaKey(key) then return false
    if not press then return false
    if key = "left"
        move(-1)
        return true
    else if key = "right"
        move(1)
        return true
    else if key = "OK"
        it = m.items[m.index]
        if it.mood = "window"
            m.top.request = { action: "room", name: "Photos" }
        else
            m.top.request = { action: "mood", mood: it.mood }
        end if
        return true
    else if key = "up" or key = "back"
        m.active = false
        layout(m.cur)
        m.top.request = { action: "pills" }
        return true
    end if
    return true
end function
