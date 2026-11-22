' Mood pictures are built from a few big textures plus SceneGraph animations, so the TV's GPU does
' the work: the fire is a 48-frame sheet flipped by a timer, the rain is two scrolling streak layers,
' the fireflies are small posters on planned paths. Art comes from tools/ambiance (see build.sh).

sub init()
    m.layers = m.top.findNode("layers")
    m.anims = []
    m.timers = []
    m.flies = []
end sub

sub build()
    stopAll()
    m.layers.removeChildrenIndex(m.layers.getChildCount(), 0)
    m.anims = []
    m.timers = []
    m.flies = []
    mood = m.top.mood
    if mood = "hearth"
        buildHearth()
    else if mood = "rain"
        buildRain()
    else if mood = "fireflies"
        buildFireflies()
    else if mood = "lightsout"
        buildLightsOut()
    end if
    if m.top.running then startAll()
end sub

sub onRunning()
    if m.top.running then startAll() else stopAll()
end sub

sub startAll()
    for each a in m.anims
        a.control = "start"
    end for
    for each t in m.timers
        t.control = "start"
    end for
    for i = 0 to m.flies.count() - 1
        planFly(i)
    end for
end sub

sub stopAll()
    for each a in m.anims
        a.control = "stop"
    end for
    for each t in m.timers
        t.control = "stop"
    end for
    for each f in m.flies
        f.anim.control = "stop"
    end for
end sub

function poster(uri as string, x as float, y as float, w as float, h as float) as object
    p = m.layers.createChild("Poster")
    p.uri = uri
    p.translation = [x, y]
    p.width = w
    p.height = h
    return p
end function

function anim(parent as object, duration as float, ease as string) as object
    a = parent.createChild("Animation")
    a.duration = duration
    a.repeat = true
    a.easeFunction = ease
    m.anims.push(a)
    return a
end function

' ---------------------------------------------------------------- hearth
sub buildHearth()
    poster("pkg:/images/amb/hearth-bg.jpg", 0, 0, 1920, 1080)
    ' fire: 8 x 6 frames of 240 x 180, drawn 3x into a 720 x 540 window (matches tools/ambiance/compose.py)
    clip = m.layers.createChild("Group")
    clip.translation = [600, 420]
    clip.clippingRect = [0, 0, 720, 540]
    m.fire = clip.createChild("Poster")
    m.fire.uri = "pkg:/images/amb/fire.jpg"
    m.fire.width = 5760
    m.fire.height = 3240
    m.frame = 0
    t = m.layers.createChild("Timer")
    t.duration = 0.083
    t.repeat = true
    t.observeField("fire", "onFireFrame")
    m.timers.push(t)

    glow = poster("pkg:/images/amb/hearth-glow.png", 0, 0, 1920, 1080)
    glow.id = "hearthGlow"
    a = anim(m.layers, 6.1, "linear")
    gi = a.createChild("FloatFieldInterpolator")
    gi.fieldToInterp = "hearthGlow.opacity"
    gi.key = [0.0, 0.13, 0.27, 0.4, 0.55, 0.68, 0.82, 1.0]
    gi.keyValue = [0.85, 1.0, 0.8, 0.95, 0.75, 1.0, 0.88, 0.85]
    poster("pkg:/images/amb/hearth-logs.png", 580, 830, 760, 170)
    makeSparks(10, 860, 1060, 880, 0)
end sub

sub onFireFrame()
    m.frame = (m.frame + 1) mod 48
    m.fire.translation = [-(m.frame mod 8) * 720, -Int(m.frame / 8) * 540]
end sub

' sparks rise from a band and fade
sub makeSparks(n as integer, x0 as float, x1 as float, y0 as float, slow as integer)
    for k = 0 to n - 1
        size = 6 + Rnd(0) * 10
        p = poster("pkg:/images/spark.png", 0, 0, size, size)
        p.id = "spark" + k.toStr()
        p.opacity = 0
        x = x0 + Rnd(0) * (x1 - x0)
        rise = 260 + Rnd(0) * 280
        if slow = 1 then rise = rise * 0.4
        a = anim(m.layers, 2.2 + Rnd(0) * 2.6 + slow * 3, "outQuad")
        a.delay = Rnd(0) * 4
        v = a.createChild("Vector2DFieldInterpolator")
        v.fieldToInterp = p.id + ".translation"
        drift = (Rnd(0) - 0.5) * 120
        v.key = [0.0, 0.5, 1.0]
        v.keyValue = [[x, y0], [x + drift * 0.6, y0 - rise * 0.55], [x + drift, y0 - rise]]
        o = a.createChild("FloatFieldInterpolator")
        o.fieldToInterp = p.id + ".opacity"
        o.key = [0.0, 0.12, 0.6, 1.0]
        o.keyValue = [0.0, 1.0, 0.7, 0.0]
    end for
end sub

' ---------------------------------------------------------------- rain
sub buildRain()
    poster("pkg:/images/amb/rain-bg.jpg", 0, 0, 1920, 1080)
    ' streaks only inside the window square; the overlay on top hides the corners
    clip = m.layers.createChild("Group")
    clip.translation = [540, 60]
    clip.clippingRect = [0, 0, 840, 840]
    rainLayer(clip, "pkg:/images/amb/rain-far.png", "rainFar", 1.5)
    rainLayer(clip, "pkg:/images/amb/rain-near.png", "rainNear", 0.75)
    poster("pkg:/images/amb/rain-window.png", 540, 60, 840, 840)
end sub

sub rainLayer(clip as object, uri as string, id as string, period as float)
    g = clip.createChild("Group")
    g.id = id
    for each y in [0, -840]
        p = g.createChild("Poster")
        p.uri = uri
        p.width = 840
        p.height = 840
        p.translation = [0, y]
    end for
    a = anim(clip, period, "linear")
    v = a.createChild("Vector2DFieldInterpolator")
    v.fieldToInterp = id + ".translation"
    ' a slight slant so the drops fall with the streaks
    v.key = [0.0, 1.0]
    v.keyValue = [[0, 0], [100, 840]]
    ' the second poster covers the gap the slant leaves on the left
    g.getChild(1).translation = [-100, -840]
end sub

' ---------------------------------------------------------------- fireflies
sub buildFireflies()
    poster("pkg:/images/amb/night-bg.jpg", 0, 0, 1920, 1080)
    m.flyBox = { x0: 60, x1: 1860, y0: 330, y1: 1020 }
    for k = 0 to 27
        fast = (k < 3)
        addFly(m.flyBox.x0 + Rnd(0) * (m.flyBox.x1 - m.flyBox.x0), m.flyBox.y0 + Rnd(0) * (m.flyBox.y1 - m.flyBox.y0), 3 + Rnd(0) * 3, fast)
    end for
end sub

' ---------------------------------------------------------------- lights out
sub buildLightsOut()
    m.top.findNode("base").color = "0x030403FF"
    glow = poster("pkg:/images/amb/hearth-glow.png", 0, 360, 1920, 1080)
    glow.id = "outGlow"
    a = anim(m.layers, 9, "inOutQuad")
    gi = a.createChild("FloatFieldInterpolator")
    gi.fieldToInterp = "outGlow.opacity"
    gi.key = [0.0, 0.5, 1.0]
    gi.keyValue = [0.18, 0.3, 0.18]
    makeSparks(5, 880, 1040, 1060, 1)
    m.flyBox = { x0: 200, x1: 1720, y0: 200, y1: 900 }
    for k = 0 to 4
        addFly(m.flyBox.x0 + Rnd(0) * 1500, 200 + Rnd(0) * 700, 2.5, false)
    end for
end sub

' ---------------------------------------------------------------- firefly motion (as in the intro)
sub addFly(x as float, y as float, r as float, fast as boolean)
    i = m.flies.count()
    size = Int(48 * r / 7 * 1.2)
    p = poster("pkg:/images/firefly.png", x - size / 2, y - size / 2, size, size)
    p.id = "fly" + i.toStr()
    if fast then v = 55 + Rnd(0) * 35 else v = 12 + Rnd(0) * 22
    if fast then turn = 0.5 else turn = 0.9
    f = { x: x, y: y, size: size, a: Rnd(0) * 6.283, v: v, ph: Rnd(0) * 20, turn: turn, t: 0 }
    a = m.layers.createChild("Animation")
    a.id = "flyAnim" + i.toStr()
    a.duration = 8
    a.easeFunction = "linear"
    vi = a.createChild("Vector2DFieldInterpolator")
    vi.fieldToInterp = p.id + ".translation"
    a.observeField("state", "onFlyDone")
    f.anim = a
    f.interp = vi
    per = 2.2 + Rnd(0) * 3.5
    lo = 0.12 + Rnd(0) * 0.15
    ga = anim(m.layers, per, "linear")
    ga.delay = Rnd(0) * per
    gi = ga.createChild("FloatFieldInterpolator")
    gi.fieldToInterp = p.id + ".opacity"
    ks = [] : vs = []
    for j = 0 to 16
        s = Sin(3.14159 * j / 16)
        ks.push(j / 16)
        vs.push(lo + (1 - lo) * s * s * s)
    end for
    gi.key = ks
    gi.keyValue = vs
    p.opacity = lo
    m.flies.push(f)
end sub

function atan2(y as float, x as float) as float
    if x > 0 then return Atn(y / x)
    if x < 0 and y >= 0 then return Atn(y / x) + 3.14159265
    if x < 0 then return Atn(y / x) - 3.14159265
    if y > 0 then return 1.5707963
    if y < 0 then return -1.5707963
    return 0
end function

sub planFly(i as integer)
    f = m.flies[i]
    b = m.flyBox
    keys = [] : vals = []
    dt = 0.1
    cx = (b.x0 + b.x1) / 2
    cy = (b.y0 + b.y1) / 2
    for s = 0 to 80
        if s mod 5 = 0
            keys.push(s / 80)
            vals.push([f.x - f.size / 2, f.y - f.size / 2])
        end if
        t = f.t
        f.a = f.a + dt * f.turn * (Sin(t * 0.5 + f.ph) + 0.6 * Sin(t * 1.13 + f.ph * 1.7))
        if f.x < b.x0 or f.x > b.x1 or f.y < b.y0 or f.y > b.y1
            df = atan2(cy - f.y, cx - f.x) - f.a
            df = atan2(Sin(df), Cos(df))
            f.a = f.a + df * dt * 2
        end if
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
    if not m.top.running then return
    i = Val(Mid(event.getNode(), 8))
    if i < m.flies.count() then planFly(i)
end sub
