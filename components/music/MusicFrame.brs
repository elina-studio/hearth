' see MusicFrame.xml
sub init()
    m.top.findNode("crumb").font = hFont("caps", 26)
    m.top.findNode("footText").font = hFont("regular", 22)
end sub

sub paint()
    m.top.findNode("crumb").text = "MUSIC  " + Chr(8250) + "  " + UCase(m.top.page)
    m.top.findNode("footRule").visible = m.top.foot
    m.top.findNode("footText").visible = m.top.foot
end sub
