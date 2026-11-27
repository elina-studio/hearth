sub init()
    m.top.visible = false
    m.top.findNode("lab").font = hFont("bold", 28)
    m.top.findNode("hint").font = hFont("regular", 22)
end sub

sub paint()
    m.top.findNode("lab").text = m.top.label
end sub

sub show(unused = invalid as dynamic)
    m.top.visible = true
end sub

sub hide(unused = invalid as dynamic)
    m.top.visible = false
end sub
