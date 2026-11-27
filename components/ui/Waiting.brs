sub init()
    m.top.visible = false
    m.fly = m.top.findNode("fly")
    m.late = m.top.findNode("late")
    m.late.font = hFont("regular", 24)
    m.slow = m.top.findNode("slow")
    m.slow.observeField("fire", "onSlow")
    m.pulse = m.top.findNode("pulse")
    m.on = false
end sub

sub onLabel()
    l = m.top.label
    if l = invalid then return
    l.observeField("text", "onText")
    l.observeField("visible", "onText")
    onText()
end sub

sub onText()
    l = m.top.label
    if l = invalid then return
    t = l.text
    waiting = (t <> invalid and Left(t, 1) = Chr(8203))
    if not waiting
        if m.on
            m.on = false
            m.pulse.control = "stop"
            m.slow.control = "stop"
            m.top.visible = false
        end if
        l.opacity = 1
        return
    end if
    ' the label keeps its words (they name what is awaited) but does not draw them
    l.opacity = 0
    m.top.visible = l.visible
    if m.on then return
    m.on = true
    m.top.translation = l.translation
    w = l.width
    centred = (l.horizAlign = "center" and w > 0)
    if centred
        m.fly.translation = [w / 2 - 24, 0]
        m.late.width = w
        m.late.horizAlign = "center"
    else
        m.fly.translation = [0, 0]
        m.late.width = 900
        m.late.horizAlign = "left"
    end if
    m.late.visible = false
    m.late.text = "Still waiting on " + Mid(t, 2)
    m.slow.control = "stop"
    m.slow.control = "start"
    m.pulse.control = "start"
end sub

sub onSlow()
    if m.on then m.late.visible = true
end sub
