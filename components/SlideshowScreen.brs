' The Window. Shows one photo at a time, crossfading every 12 seconds.
' Left/Right step through photos, OK pauses, Back closes.
sub init()
    m.layers = [
        { group: m.top.findNode("layerA"), back: m.top.findNode("backA"), photo: m.top.findNode("photoA"), name: "layerA" },
        { group: m.top.findNode("layerB"), back: m.top.findNode("backB"), photo: m.top.findNode("photoB"), name: "layerB" }
    ]
    m.front = 1 ' index of the layer on screen; the first photo goes to the other one
    m.clock = m.top.findNode("clock")
    m.clock.font = hFont("bold", 120)
    m.date = m.top.findNode("date")
    m.date.font = hFont("fell", 48)
    m.weather = m.top.findNode("weather")
    m.weather.font = hFont("regular", 32)
    m.album = m.top.findNode("album")
    m.album.font = hFont("caps", 28)
    m.caption = m.top.findNode("caption")
    m.caption.font = hFont("regular", 32)
    m.status = m.top.findNode("status")
    m.status.font = hFont("regular", 32)
    m.hint = m.top.findNode("hint")
    m.hintText = m.top.findNode("hintText")
    m.hintText.font = hFont("regular", 24)
    m.hintFade = m.top.findNode("hintFade")
    m.fade = m.top.findNode("fade")
    m.fadeIn = m.top.findNode("fadeIn")
    m.fadeOut = m.top.findNode("fadeOut")
    m.advance = m.top.findNode("advance")
    m.advance.observeField("fire", "onAdvance")
    m.clockTimer = m.top.findNode("clockTimer")
    m.clockTimer.observeField("fire", "tick")
    m.weatherTimer = m.top.findNode("weatherTimer")
    m.weatherTimer.observeField("fire", "loadWeather")
    for each l in m.layers
        l.photo.observeField("loadStatus", "onLoadStatus")
    end for

    m.queue = []      ' assets from the current batch
    m.pos = -1        ' index in m.queue of the photo on screen (or loading)
    m.history = []    ' assets already shown, for Left
    m.back = 0        ' how far back in history we've stepped
    m.loading = false
    m.paused = false
    m.fails = 0
    m.shown = invalid
    m.status.text = "Opening the window…"
    showHint("◂ ▸ photos    OK pause    Back closes")
    tick()
    m.clockTimer.control = "start"
    loadWeather()
    m.weatherTimer.control = "start"
end sub

sub onShown(unused as dynamic)
    m.top.setFocus(true)
    if m.started = invalid
        m.started = true
        if m.top.albumName <> "" then m.album.text = UCase(m.top.albumName) else m.album.text = "ALL PHOTOS"
        fetchBatch()
    end if
end sub

' ---------- photos ----------
sub fetchBatch()
    lib = pLibrary()
    if lib = ""
        m.status.text = "No photos library in Plex yet. Press Back."
        return
    end if
    if m.top.albumId <> ""
        pPhotos("album", { id: m.top.albumId }, "onBatch")
    else
        pPhotos("random", { section: lib, limit: 60 }, "onBatch")
    end if
end sub

sub onBatch(event as object)
    t = pTaskFrom(event)
    if not t.ok
        m.status.text = "Can't get photos from Plex (" + t.status.toStr() + "). Press Back and try again."
        return
    end if
    photos = t.response.Items
    if photos = invalid or photos.count() = 0
        m.status.text = "No photos here yet."
        return
    end if
    shuffle(photos)
    m.queue = photos
    m.pos = -1
    showNext()
end sub

sub shuffle(a as object)
    for i = a.count() - 1 to 1 step -1
        j = Rnd(i + 1) - 1
        tmp = a[i] : a[i] = a[j] : a[j] = tmp
    end for
end sub

' Forward: step back toward the newest photo first, then take the next from the queue
sub showNext()
    if m.back > 0
        m.back = m.back - 1
        load(m.history[m.history.count() - 1 - m.back])
        return
    end if
    m.pos = m.pos + 1
    if m.pos >= m.queue.count()
        fetchBatch()
        return
    end if
    load(m.queue[m.pos])
end sub

sub showPrevious()
    if m.back + 1 >= m.history.count() then return
    m.back = m.back + 1
    load(m.history[m.history.count() - 1 - m.back])
end sub

sub load(item as object)
    m.loading = true
    m.advance.control = "stop"
    m.pending = item
    url = pPhotoUrl(item, 1920, 1080)
    nextLayer = m.layers[1 - m.front]
    ' stepping back can land on the photo this layer already holds; no reload event comes then
    if nextLayer.photo.uri = url and nextLayer.photo.loadStatus = "ready"
        reveal()
    else
        nextLayer.back.uri = url
        nextLayer.photo.uri = url
    end if
    ' tell the TV someone's here, so its own screensaver doesn't cover the slideshow
    pHa("", "", true)
end sub

sub onLoadStatus(event as object)
    s = event.getData()
    node = event.getRoSGNode()
    nextLayer = m.layers[1 - m.front]
    if not node.isSameNode(nextLayer.photo) then return
    if s = "ready"
        reveal()
    else if s = "failed"
        skip()
    end if
end sub

' A photo that won't download or draw is passed over, up to a point
sub skip()
    m.loading = false
    m.fails = m.fails + 1
    if m.fails >= 5
        m.status.text = "Photos aren't loading. Press Back and check the Photos room."
        return
    end if
    showNext()
end sub

sub reveal()
    m.loading = false
    m.fails = 0
    m.status.text = ""
    incoming = m.layers[1 - m.front]
    outgoing = m.layers[m.front]
    m.fade.control = "stop"
    m.fadeIn.fieldToInterp = incoming.name + ".opacity"
    m.fadeOut.fieldToInterp = outgoing.name + ".opacity"
    m.fadeOut.keyValue = [outgoing.group.opacity, 0.0]
    m.fade.control = "start"
    m.front = 1 - m.front
    if m.back = 0 and (m.history.count() = 0 or m.history.peek().Id <> m.pending.Id) then m.history.push(m.pending)
    if m.history.count() > 50 then m.history.shift()
    m.caption.text = pPhotoCaption(m.pending)
    if not m.paused then m.advance.control = "start"
end sub

sub onAdvance()
    if not m.paused and not m.loading then showNext()
end sub

' ---------- clock and weather ----------
sub tick()
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    h = dt.GetHours()
    mi = dt.GetMinutes()
    h12 = h mod 12
    if h12 = 0 then h12 = 12
    mm = mi.toStr()
    if mi < 10 then mm = "0" + mm
    m.clock.text = h12.toStr() + ":" + mm
    m.date.text = dt.GetWeekday() + " " + dt.GetDayOfMonth().toStr() + " " + pMonthName(dt.GetMonth())
end sub

sub loadWeather()
    c = pCfg()
    if c.haToken = ""
        m.weather.text = ""
        return
    end if
    pHa("/api/states/" + c.haEntity, "onWeather")
end sub

sub onWeather(event as object)
    t = pTaskFrom(event)
    if not t.ok or t.response.state = invalid
        m.weather.text = ""
        return
    end if
    s = pWeatherWord(t.response.state)
    a = t.response.attributes
    if a <> invalid and a.temperature <> invalid
        temp = Int(a.temperature + 0.5).toStr() + "°"
        s = temp + " · " + s
    end if
    m.weather.text = s
end sub

' ---------- keys ----------
sub showHint(text as string)
    m.hintText.text = text
    m.hint.opacity = 1.0
    m.hintFade.control = "stop"
    m.hintFade.control = "start"
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
    if key = "back"
        cleanup()
        m.top.request = { action: "back" }
    else if key = "right"
        if not m.loading then showNext()
        if m.paused then showHint("Paused    OK resumes")
    else if key = "left"
        if not m.loading then showPrevious()
        if m.paused then showHint("Paused    OK resumes")
    else if key = "OK"
        m.paused = not m.paused
        if m.paused
            m.advance.control = "stop"
            showHint("Paused    OK resumes")
        else
            showHint("◂ ▸ photos    OK pause    Back closes")
            if not m.loading then showNext()
        end if
    else if key = "up" or key = "down"
        showHint("◂ ▸ photos    OK pause    Back closes")
    else
        return false
    end if
    return true
end function

sub cleanup()
    m.advance.control = "stop"
    m.clockTimer.control = "stop"
    m.weatherTimer.control = "stop"
end sub
