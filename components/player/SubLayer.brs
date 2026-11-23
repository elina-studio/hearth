' style: { size: "S"|"M"|"L"|"XL", color: "0xRRGGBBFF", bg: "none"|"soft"|"solid", outline: "none"|"thin"|"thick", pos: "bottom"|"raised"|"top" }
sub init()
    m.text = m.top.findNode("text")
    m.box = m.top.findNode("box")
    m.shadows = m.top.findNode("shadows")
    m.idx = 0
    m.shown = ""
    m.measure = CreateObject("roSGNode", "Label")
    onStyle()
end sub

function hSubStyleDefault() as object
    return { size: "M", color: "0xFFFFFFFF", bg: "none", outline: "thin", pos: "bottom" }
end function

sub onStyle()
    st = m.top.style
    if st = invalid or st.size = invalid then st = hSubStyleDefault()
    m.st = st
    sizes = { S: 36, M: 44, L: 54, XL: 64 }
    sz = sizes[st.size]
    if sz = invalid then sz = 44
    m.font = hFont("regular", sz)
    m.text.font = m.font
    m.measure.font = m.font
    m.text.color = st.color
    m.shadows.removeChildrenIndex(m.shadows.getChildCount(), 0)
    offs = []
    if st.outline = "thin" then offs = [[-2, 0], [2, 0], [0, -2], [0, 2], [2, 2]]
    if st.outline = "thick" then offs = [[-3, 0], [3, 0], [0, -3], [0, 3], [-2, -2], [2, 2], [-2, 2], [2, -2], [3, 3]]
    for each o in offs
        s = m.shadows.createChild("Label")
        s.font = m.font
        s.color = "0x000000FF"
        s.width = 1600
        s.wrap = true
        s.maxLines = 4
        s.horizAlign = "center"
        s.addFields({ off: o })
    end for
    m.shown = "~"
    show(m.cur)
end sub

sub onCues()
    m.idx = 0
    m.cur = ""
    show("")
end sub

sub onTime()
    cues = m.top.cues
    if cues = invalid or cues.count() = 0 then return
    t = m.top.time - m.top.delay
    n = cues.count()
    i = m.idx
    if i >= n then i = n - 1
    if i < 0 then i = 0
    ' far jump (seek): binary search for the last cue starting at or before t
    if t < cues[i].s - 10 or (i + 1 < n and t > cues[i + 1].s + 10)
        lo = 0
        hi = n - 1
        while lo < hi
            mid = Int((lo + hi + 1) / 2)
            if cues[mid].s <= t then lo = mid else hi = mid - 1
        end while
        i = lo
    end if
    while i + 1 < n and cues[i + 1].s <= t
        i = i + 1
    end while
    while i > 0 and cues[i].s > t
        i = i - 1
    end while
    m.idx = i
    c = cues[i]
    txt = ""
    if t >= c.s and t <= c.e then txt = c.t
    m.cur = txt
    show(txt)
end sub

sub show(txt as dynamic)
    if txt = invalid then txt = ""
    if txt = m.shown then return
    m.shown = txt
    m.text.text = txt
    for each s in m.shadows.getChildren(-1, 0)
        s.text = txt
    end for
    if txt = ""
        m.box.visible = false
        return
    end if
    h = m.text.boundingRect().height
    base = 1010
    if m.st.pos = "raised" then base = 900
    if m.top.lifted = true and base > 780 then base = 780
    y = base - h
    if m.st.pos = "top" then y = 70
    m.text.translation = [160, y]
    for each s in m.shadows.getChildren(-1, 0)
        s.translation = [160 + s.off[0], y + s.off[1]]
    end for
    if m.st.bg = "none"
        m.box.visible = false
    else
        w = 0
        for each ln in txt.Split(Chr(10))
            m.measure.text = ln
            lw = m.measure.boundingRect().width
            if lw > w then w = lw
        end for
        if w > 1600 then w = 1600
        m.box.width = w + 36
        m.box.height = h + 16
        m.box.translation = [960 - (w + 36) / 2, y - 8]
        if m.st.bg = "solid" then m.box.color = "0x000000E0" else m.box.color = "0x000000A0"
        m.box.visible = true
    end if
end sub
