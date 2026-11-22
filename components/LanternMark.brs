sub init()
    m.flame = m.top.findNode("flame")
    m.frame = 0
    m.dir = 1
    t = m.top.findNode("tick")
    t.observeField("fire", "onTick")
    t.control = "start"
end sub

' 96 frames (12 x 8 sheet, 18 x 27 each = 12 x 18 at 720p at this size), played back and forth
sub onTick()
    m.frame = m.frame + m.dir
    if m.frame >= 95 then m.dir = -1
    if m.frame <= 0 then m.dir = 1
    m.flame.translation = [-(m.frame mod 12) * 18, -Int(m.frame / 12) * 27]
end sub
