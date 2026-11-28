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
    muNextTiles(m.next)
end sub

function hKeyInner(key as string, press as boolean) as boolean
    if not press then return false
    if hKeyTooFast(120, key) then return true
    if muMediaKey(key) then return true
    if key = "back"
        leaveWith({ action: "back" })
        return true
    end if
    m.panel.callFunc("handleKey", key)
    return true
end function

' menu sound for whatever the handler above took (source/util.brs hKeySfx)
function onKeyEvent(key as string, press as boolean) as boolean
    return hKeySfx(key, press, hKeyInner(key, press))
end function
