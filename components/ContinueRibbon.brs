sub init()
    m.box = m.top.findNode("box")
    m.kicker = m.top.findNode("kicker")
    m.title = m.top.findNode("title")
    m.meta = m.top.findNode("meta")
    m.kicker.font = hFont("caps", 22)
    m.title.font = hFont("bold", 34)
    m.meta.font = hFont("regular", 22)
    m.top.findNode("lab").font = hFont("bold", 24)
    m.top.findNode("hideTimer").observeField("fire", "onHide")
    m.pct = hBraid(m.box, 520, 100)
    m.pct.translation = [308, 100]
    m.top.visible = false
end sub

sub paint()
    i = m.top.info
    if i = invalid then return
    m.kicker.text = UCase(hStr(i.kicker))
    m.title.text = UCase(hStr(i.title))
    m.meta.text = hStr(i.meta)
    m.top.findNode("thumb").uri = hStr(i.thumb)
    pct = 0.0
    if i.pct <> invalid then pct = i.pct
    ' the title sits above the bar; with no progress the bar hides
    hBraidSet(m.pct, pct)
end sub

sub show(unused = invalid as dynamic)
    m.top.visible = true
    m.top.shown = true
    m.top.findNode("slideTo").keyValue = [[0, 1080], [0, 910]]
    m.top.findNode("slide").control = "start"
    m.top.findNode("hideTimer").control = "stop"
    m.top.findNode("hideTimer").control = "start"
end sub

sub hide(unused = invalid as dynamic)
    m.top.findNode("hideTimer").control = "stop"
    m.top.findNode("slide").control = "stop"
    m.top.shown = false
    m.top.visible = false
    m.box.translation = [0, 1080]
end sub

sub onHide()
    hide()
end sub

function hStr(v as dynamic) as string
    if v = invalid then return ""
    if type(v) = "roString" or type(v) = "String" then return v
    return v.toStr()
end function
