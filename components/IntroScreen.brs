sub init()
    m.flame = m.top.findNode("flame")
    m.sheet = m.top.findNode("lanternSheet")
    m.glow = m.top.findNode("glow")
    m.sparks = m.top.findNode("sparks")
    m.flameClip = m.top.findNode("flameClip")
    m.quote = m.top.findNode("quote")
    m.quote.font = hFont("fell", 32)
    m.qL = m.top.findNode("qL")
    m.qR = m.top.findNode("qR")
    m.fadeOut = m.top.findNode("fadeOut")
    m.fadeIn = m.top.findNode("fadeIn")
    m.frame = 0
    m.dir = 1
    m.lastK = -1
    m.ticks = 0
    m.clock = CreateObject("roTimespan")
    m.toStart = [m.top.findNode("glowAnim")]

    makeSparks()
    makeFlies()

    m.quotes = loadQuotes()
    m.qi = 0
    m.fadeOut.observeField("state", "onFadedOut")

    ' everything stays hidden until the big images have loaded, then fades in, so the first frames never glitch
    m.shown = false
    m.waiting = [m.top.findNode("bg"), m.sheet, m.flame, m.glow]
    for each p in m.waiting
        p.observeField("loadStatus", "onLoaded")
    end for
    fb = CreateObject("roSGNode", "Timer")
    fb.duration = 1.5
    fb.observeField("fire", "reveal")
    m.top.appendChild(fb)
    fb.control = "start"
    m.fallback = fb
    onLoaded()
end sub

sub onLoaded()
    for each p in m.waiting
        if p.loadStatus <> "ready" then return
    end for
    reveal()
end sub

sub reveal()
    if m.shown then return
    m.shown = true
    print "[hearth] intro reveal"
    m.clock.Mark()
    onSway()
    ap = m.top.findNode("appear")
    ap.observeField("state", "onAppeared")
    ap.control = "start"
    st = m.top.findNode("swayTimer")
    st.observeField("fire", "onSway")
    st.control = "start"
    ft = m.top.findNode("flameTimer")
    ft.observeField("fire", "onFlame")
    ft.control = "start"
    for each a in m.toStart
        a.control = "start"
    end for
    for i = 0 to m.flyData.count() - 1
        planFly(i)
    end for
    showQuote()
    qt = m.top.findNode("quoteTimer")
    qt.observeField("fire", "onQuoteTimer")
    qt.control = "start"
end sub

sub onAppeared(event as object)
    if event.getData() = "stopped" then m.top.findNode("still").visible = false
end sub

sub onMode()
    if m.top.mode = "intro"
        lt = m.top.findNode("leaveTimer")
        lt.observeField("fire", "leave")
        lt.control = "start"
    end if
end sub

sub onShown(unused as dynamic)
    m.top.setFocus(true)
end sub

' snap to whole 720p pixels (1.5 fhd units) so nothing shimmers on this HD TV
function px(v as float) as float
    return Int(v / 1.5 + 0.5) * 1.5
end function

' +-3 degrees, 7 s per full swing. Picks the nearest of 21 pre-rotated frames; the flame, glow and sparks follow by translation.
sub onSway()
    t = m.clock.TotalMilliseconds() / 1000.0
    deg = 3.0 * Sin(t * 6.2832 / 7.0)
    k = Int((deg + 3.0) / 6.0 * 20.0 + 0.5)
    if k < 0 then k = 0
    if k > 20 then k = 20
    if k = m.lastK then return
    m.lastK = k
    a = (-3.0 + 6.0 * k / 20.0) * 3.14159265 / 180.0
    m.sheet.translation = [-(k mod 7) * 252, -Int(k / 7) * 690]
    m.flameClip.translation = [px(900 + 540 * Sin(a)), px(453 + 540 * (Cos(a) - 1))]
    m.glow.translation = [px(744 + 553 * Sin(a)), px(337 + 553 * (Cos(a) - 1))]
    m.sparks.translation = [px(540 * Sin(a)), px(540 * (Cos(a) - 1))]
    m.ticks = m.ticks + 1
    if m.ticks mod 10 = 0 then print "[hearth] sway frame " k
end sub

' ---------- flame: 96 pre-rendered frames in a 12 x 8 sheet (120 x 177 each = 80 x 118 at 720p), played back and forth ----------
sub onFlame()
    m.frame = m.frame + m.dir
    if m.frame >= 95 then m.dir = -1
    if m.frame <= 0 then m.dir = 1
    m.flame.translation = [-(m.frame mod 12) * 120, -Int(m.frame / 12) * 177]
end sub

' ---------- sparks rise from the flame ----------
sub makeSparks()
    g = m.top.findNode("sparks")
    data = [[206, 300, 2.6, 2.3, 8, -44, 0], [238, 296, 2.2, 3.1, -6, -52, 1.1], [226, 290, 2.8, 2.7, 4, -38, 2.0], [214, 296, 2.0, 3.7, -10, -58, 0.55], [232, 304, 2.4, 4.3, 7, -48, 1.7]]
    for each d in data
        size = 16 * (0.8 * d[2] / 3)
        x = 784 + 0.8 * d[0] - size / 2
        y = 281 + 0.8 * d[1] - size / 2
        n = g.getChildCount()
        p = g.createChild("Poster")
        p.id = "spark" + n.toStr()
        p.uri = "pkg:/images/spark.png"
        p.width = size
        p.height = size
        p.opacity = 0
        a = g.createChild("Animation")
        a.duration = d[3]
        a.repeat = true
        a.easeFunction = "outQuad"
        a.delay = d[6]
        v = a.createChild("Vector2DFieldInterpolator")
        v.key = [0.0, 1.0]
        v.keyValue = [[x, y], [x + 0.8 * d[4], y + 0.8 * d[5]]]
        v.fieldToInterp = p.id + ".translation"
        o = a.createChild("FloatFieldInterpolator")
        o.key = [0.0, 0.15, 1.0]
        o.keyValue = [0.0, 1.0, 0.0]
        o.fieldToInterp = p.id + ".opacity"
        m.toStart.push(a)
    end for
end sub

' ---------- fireflies: each always flying on its own lazy path, simulated in 8 s windows ----------
sub makeFlies()
    m.flyData = []
    seeds = [[672, 151, 3.3], [1572, 652, 5.4], [1364, 586, 5.9], [746, 601, 5.5], [1169, 904, 4.7], [1320, 105, 3.7], [589, 138, 3.7], [258, 332, 4.9], [722, 423, 3.6], [550, 978, 4.9], [1152, 228, 5.2], [368, 432, 6.0], [1206, 606, 5.1], [1563, 820, 3.7], [136, 369, 3.8], [451, 984, 5.6]]
    for each s in seeds
        addFly(s[0], s[1], s[2], false, invalid)
    end for
    for k = 0 to 2
        if Rnd(0) < 0.5 then x = 150 + Rnd(0) * 450 else x = 1320 + Rnd(0) * 450
        addFly(x, 150 + Rnd(0) * 700, 3.5 + Rnd(0) * 2, true, invalid)
    end for
    ' side dwellers drift in and out of frame along the left and right edges
    for k = 0 to 9
        left = (k mod 2 = 0)
        if left then x = 20 + Rnd(0) * 180 else x = 1720 + Rnd(0) * 180
        y = 80 + Rnd(0) * 900
        if left then hx = 70 else hx = 1850
        addFly(x, y, 2.5 + Rnd(0) * 3, Rnd(0) < 0.25, { x: hx, y: y, r: 120 + Rnd(0) * 80 })
    end for
    for each f in m.flyData
        if f.home = invalid and Rnd(0) < 0.35
            if f.x < 960 then hx = 110 else hx = 1810
            f.home = { x: hx, y: f.y, r: 200 }
        end if
    end for
end sub

sub addFly(x as float, y as float, r as float, fast as boolean, home as dynamic)
    g = m.top.findNode("flies")
    i = m.flyData.count()
    size = Int(48 * r / 7 * 1.2)
    p = g.createChild("Poster")
    p.id = "fly" + i.toStr()
    p.uri = "pkg:/images/firefly.png"
    p.width = size
    p.height = size
    p.translation = [x - size / 2, y - size / 2]
    if fast then v = 55 + Rnd(0) * 35 else v = 12 + Rnd(0) * 22
    if fast then turn = 0.5 else turn = 0.9
    f = { x: x, y: y, size: size, a: Rnd(0) * 6.283, v: v, ph: Rnd(0) * 20, per: 2.2 + Rnd(0) * 3.5, turn: turn, lo: 0.12 + Rnd(0) * 0.15, home: home, t: 0 }

    ' path animation, replanned every window
    a = g.createChild("Animation")
    a.id = "flyAnim" + i.toStr()
    a.duration = 8
    a.easeFunction = "linear"
    vi = a.createChild("Vector2DFieldInterpolator")
    vi.fieldToInterp = p.id + ".translation"
    a.observeField("state", "onFlyDone")
    f.anim = a
    f.interp = vi

    ' glow up and dim on its own rhythm
    ga = g.createChild("Animation")
    ga.duration = f.per
    ga.repeat = true
    ga.easeFunction = "linear"
    ga.delay = Rnd(0) * f.per
    gi = ga.createChild("FloatFieldInterpolator")
    gi.fieldToInterp = p.id + ".opacity"
    ks = [] : vs = []
    for j = 0 to 16
        ph = j / 16
        s = Sin(3.14159 * ph)
        ks.push(ph)
        vs.push(f.lo + (1 - f.lo) * s * s * s)
    end for
    gi.key = ks
    gi.keyValue = vs
    p.opacity = f.lo
    m.toStart.push(ga)
    m.flyData.push(f)
end sub

function atan2(y as float, x as float) as float
    if x > 0 then return Atn(y / x)
    if x < 0 and y >= 0 then return Atn(y / x) + 3.14159265
    if x < 0 then return Atn(y / x) - 3.14159265
    if y > 0 then return 1.5707963
    if y < 0 then return -1.5707963
    return 0
end function

function turnTo(f as object, target as float, k as float, dt as float) as void
    df = target - f.a
    df = atan2(Sin(df), Cos(df))
    f.a = f.a + df * dt * k
end function

sub planFly(i as integer)
    f = m.flyData[i]
    keys = [] : vals = []
    dt = 0.1
    for s = 0 to 80
        if s mod 5 = 0
            keys.push(s / 80)
            vals.push([f.x - f.size / 2, f.y - f.size / 2])
        end if
        t = f.t
        f.a = f.a + dt * f.turn * (Sin(t * 0.5 + f.ph) + 0.6 * Sin(t * 1.13 + f.ph * 1.7))
        dx = f.x - 960
        dy = f.y - 510
        if f.home <> invalid
            hx = f.home.x - f.x
            hy = f.home.y - f.y
            if Sqr(hx * hx + hy * hy) > f.home.r then turnTo(f, atan2(hy, hx), 0.9, dt)
            f.home.y = f.home.y + Sin(t * 0.13 + f.ph) * 8 * dt
        end if
        if Abs(dx) < 300 and Abs(dy) < 320 then turnTo(f, atan2(dy, dx), 2.5, dt)
        if f.home <> invalid then lo = -30 else lo = 50
        if f.home <> invalid then hi = 1950 else hi = 1870
        if f.x < lo or f.x > hi or f.y < 50 or f.y > 990 then turnTo(f, atan2(510 - f.y, 960 - f.x), 2, dt)
        sp = f.v * (0.7 + 0.3 * Sin(t * 0.9 + f.ph * 2.3))
        f.x = f.x + Cos(f.a) * sp * dt
        f.y = f.y + Sin(f.a) * sp * dt + 3 * Sin(t * 2.1 + f.ph) * dt
        f.t = t + dt
    end for
    f.interp.key = keys
    f.interp.keyValue = vals
    f.anim.control = "start"
end sub

sub onFlyDone(event as object)
    if event.getData() <> "stopped" then return
    id = event.getNode()
    i = Val(Mid(id, 8))
    ' the simulation sits one small step past the last key, so the next window picks up where this one ended
    planFly(i)
end sub

' ---------- quotes ----------
function loadQuotes() as object
    text = ReadAsciiFile("pkg:/data/quotes.txt")
    lines = []
    for each l in text.Split(Chr(10))
        l = l.Trim()
        if l <> "" then lines.push(l)
    end for
    for k = lines.count() - 1 to 1 step -1
        j = Rnd(k + 1) - 1
        tmp = lines[k] : lines[k] = lines[j] : lines[j] = tmp
    end for
    return lines
end function

sub showQuote()
    if m.quotes.count() = 0 then return
    m.quote.text = m.quotes[m.qi] + "  " + Chr(8212) + " Rumi"
    r = m.quote.boundingRect()
    w = r.width
    m.quote.translation = [960 - w / 2, 994]
    ' scroll flourishes sit 40 px out from the text, anchored at the text's midline
    m.qL.translation = [960 - w / 2 - 40 - 114, 1018 - 30]
    m.qR.translation = [960 + w / 2 + 40 + 4, 1018 - 30]
    m.fadeIn.control = "start"
end sub

sub onQuoteTimer()
    m.fadeOut.control = "start"
end sub

sub onFadedOut()
    if m.fadeOut.state <> "stopped" then return
    m.qi = (m.qi + 1) mod m.quotes.count()
    showQuote()
end sub

' ---------- leaving ----------
sub leave()
    if m.left = true then return
    m.left = true
    m.top.request = { action: "introDone" }
end sub

' the intro always runs its full 10 seconds; buttons are swallowed until then
function onKeyEvent(key as string, press as boolean) as boolean
    if m.top.mode <> "intro" then return false
    return true
end function
