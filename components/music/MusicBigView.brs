sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.panel = m.top.findNode("panel")
    m.panel.observeField("request", "onPanelRequest")
    m.top.findNode("nextTitle").font = hFont("fell", 40)
    m.next = m.top.findNode("next")
    p = muPlayer()
    p.observeFieldScoped("track", "showNext")
    p.observeFieldScoped("queue", "showNext")
    showNext()
end sub

sub onShown(unused as dynamic)
    m.top.setFocus(true)
end sub

sub onPanelRequest()
    r = m.panel.request
    if r = invalid then return
    if r.action = "refocus" then m.top.setFocus(true) else leaveWith(r)
end sub

sub leaveWith(r as object)
    if r.action = "back"
        p = muPlayer()
        p.unobserveFieldScoped("track")
        p.unobserveFieldScoped("queue")
    end if
    m.top.request = r
end sub

sub muRestoreFocus()
    m.top.setFocus(true)
end sub

' the next four songs in the queue, and the cover blurred behind everything
sub showNext()
    p = muPlayer()
    tr = p.track
    if tr <> invalid then m.backdrop.uri = pxImage(tr.thumb, 640, 360, 40) else m.backdrop.uri = ""
    m.next.removeChildrenIndex(m.next.getChildCount(), 0)
    q = p.queue
    if q = invalid then return
    k = 0
    for i = p.index + 1 to q.Count() - 1
        if k >= 4 then exit for
        t = q[i]
        g = m.next.createChild("Group")
        g.translation = [k * 430, 0]
        bg = g.createChild("Rectangle")
        bg.width = 90
        bg.height = 90
        bg.color = "0x1D2418FF"
        art = g.createChild("Poster")
        art.width = 90
        art.height = 90
        art.loadDisplayMode = "scaleToZoom"
        art.uri = pxImage(t.thumb, 90, 90)
        a = g.createChild("Label")
        a.translation = [106, 16]
        a.width = 300
        a.maxLines = 1
        a.font = hFont("bold", 24)
        a.color = "0xEDE6CAFF"
        a.text = t.title
        b = g.createChild("Label")
        b.translation = [106, 50]
        b.width = 300
        b.maxLines = 1
        b.font = hFont("regular", 20)
        b.color = "0xB5AF8CFF"
        b.text = t.artist + "  ·  " + pxClock(t.duration)
        k = k + 1
    end for
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if muMediaKey(key) then return true
    if key = "back"
        leaveWith({ action: "back" })
        return true
    end if
    m.panel.callFunc("handleKey", key)
    return true
end function
