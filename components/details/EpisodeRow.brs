sub init()
    m.bg = m.top.findNode("bg")
    m.num = m.top.findNode("num")
    m.num.font = hFont("bold", 40)
    m.thumb = m.top.findNode("thumb")
    m.title = m.top.findNode("title")
    m.title.font = hFont("bold", 26)
    m.syn = m.top.findNode("syn")
    m.syn.font = hFont("regular", 22)
    m.meta = m.top.findNode("meta")
    m.meta.font = hFont("regular", 22)
    m.status = m.top.findNode("status")
    m.ring = m.top.findNode("ring")
    m.moss = m.top.findNode("moss")
    m.braid = hBraid(m.top.findNode("braidAt"), 184, 0)
end sub

sub draw()
    d = m.top.data
    if d = invalid then return
    m.num.text = d.number
    m.title.text = d.title
    m.syn.text = d.synopsis
    m.meta.text = d.meta
    if d.image <> invalid then m.thumb.uri = d.image else m.thumb.uri = ""
    pct = 0
    if d.pct <> invalid and d.watched <> true then pct = d.pct
    hBraidSet(m.braid, pct)
    m.status.removeChildrenIndex(m.status.getChildCount(), 0)
    if d.missing <> invalid and d.missing <> "" then hTag(m.status, d.missing, "ccx", "warn")
    if d.hevc = true then hTag(m.status, "To 720p", "wand", "plain")
    if d.watched = true
        tick = m.status.createChild("Poster")
        tick.uri = "pkg:/images/icons/d-checkc.png"
        tick.width = 32
        tick.height = 32
        tick.blendColor = "0xE0B34AFF"
    end if
    m.moss.uri = hMossUri(d.key)
    paint()
end sub

sub paint()
    f = m.top.focused
    m.bg.visible = f
    m.ring.visible = f
    m.moss.visible = f
    if f then m.num.color = "0xE0B34AFF" else m.num.color = "0xB5AF8CFF"
end sub
