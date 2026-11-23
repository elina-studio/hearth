sub init()
    ' same order and label positions as HubScreen (whimsy spec 2)
    m.names = ["Home", "Shows", "Movies", "Music", "Requests", "Ambiance", "Photos", "Search"]
    m.tabX = [280, 420, 578, 750, 899, 1111, 1332, 1504]
    m.tabW = [101, 120, 133, 110, 174, 182, 134, 136]
    m.labels = m.top.findNode("labels")
    for i = 0 to m.names.count() - 1
        p = m.labels.createChild("Poster")
        p.translation = [m.tabX[i], 42]
        p.width = m.tabW[i]
        p.height = 44
        p.loadDisplayMode = "noScale"
    end for
    m.glow = m.top.findNode("glow")
    m.f1 = m.top.findNode("f1")
    m.f2 = m.top.findNode("f2")
    m.fly = m.top.findNode("fly")
    paint()
end sub

function cur() as integer
    for i = 0 to m.names.count() - 1
        if m.names[i] = m.top.current then return i
    end for
    return 1
end function

sub paint()
    ci = cur()
    if not m.top.focused then m.top.index = ci
    fi = m.top.index
    if fi < 0 then fi = ci
    for i = 0 to m.labels.getChildCount() - 1
        st = "dim"
        if i = ci then st = "current"
        if m.top.focused and i = fi then st = "focused"
        m.labels.getChild(i).uri = "pkg:/images/w/room-" + LCase(m.names[i]) + "-" + st + ".png"
    end for
    l = m.tabX[ci] + 2
    r = m.tabX[ci] + m.tabW[ci] - 2
    m.glow.translation = [l - 24, 34]
    m.glow.width = r - l + 48
    if m.top.focused and fi <> ci then m.glow.opacity = 0.6 else m.glow.opacity = 1.0
    m.f1.translation = [r - 10, 19]
    m.f2.translation = [l - 36, 55]
    m.fly.translation = [m.tabX[fi] + Int(m.tabW[fi] / 2) - 32, 64]
end sub

function move(d as integer) as boolean
    i = m.top.index + d
    if i < 0 or i >= m.names.count() then return false
    m.top.index = i
    paint()
    return true
end function

function chosen(unused = invalid as dynamic) as string
    return m.names[m.top.index]
end function
