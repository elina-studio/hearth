' The Window. One photo at a time with a slow pan and zoom, crossfading every few seconds.
' Left/Right step through photos, OK pauses, ✱ opens the options panel, Back closes.
' Play, Rewind and Fast forward stay with the music.
sub init()
    m.layers = [
        { group: m.top.findNode("layerA"), back: m.top.findNode("backA"), photo: m.top.findNode("photoA"), photo2: m.top.findNode("photoA2"), pan: m.top.findNode("panA"), name: "layerA", panName: "panA" },
        { group: m.top.findNode("layerB"), back: m.top.findNode("backB"), photo: m.top.findNode("photoB"), photo2: m.top.findNode("photoB2"), pan: m.top.findNode("panB"), name: "layerB", panName: "panB" }
    ]
    m.front = 1 ' index of the layer on screen; the first photo goes to the other one
    m.prefetch = m.top.findNode("prefetch")
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
    m.star = m.top.findNode("star")
    m.star.font = hFont("caps", 26)
    m.captionGroup = m.top.findNode("captionGroup")
    m.captionFade = m.top.findNode("captionFade")
    m.nowPlaying = m.top.findNode("nowPlaying")
    m.top.findNode("npEyebrow").font = hFont("caps", 24)
    m.npTitle = m.top.findNode("npTitle")
    m.npTitle.font = hFont("regular", 28)
    m.pausedBadge = m.top.findNode("paused")
    m.top.findNode("pausedText").font = hFont("bold", 32)
    m.status = m.top.findNode("status")
    m.status.font = hFont("regular", 32)
    m.hint = m.top.findNode("hint")
    m.hintKeys = m.top.findNode("hintKeys")
    m.hintFade = m.top.findNode("hintFade")
    m.optionsHolder = m.top.findNode("optionsHolder")
    m.fade = m.top.findNode("fade")
    m.fadeIn = m.top.findNode("fadeIn")
    m.fadeOut = m.top.findNode("fadeOut")
    m.panAnim = m.top.findNode("panAnim")
    m.panScale = m.top.findNode("panScale")
    m.panMove = m.top.findNode("panMove")
    m.advance = m.top.findNode("advance")
    m.advance.observeField("fire", "onAdvance")
    m.clockTimer = m.top.findNode("clockTimer")
    m.clockTimer.observeField("fire", "tick")
    m.weatherTimer = m.top.findNode("weatherTimer")
    m.weatherTimer.observeField("fire", "loadWeather")
    for each l in m.layers
        l.photo.observeField("loadStatus", "onLoadStatus")
        l.photo2.observeField("loadStatus", "onLoadStatus")
    end for
    mp = m.global.music
    if mp <> invalid
        mp.observeField("state", "showMusic")
        mp.observeField("track", "showMusic")
    end if

    m.queue = []      ' photos from the current batch
    m.next = 0        ' index in m.queue of the next photo not yet shown
    m.history = []    ' slides already shown, for Left (a slide is one photo, or two portraits)
    m.back = 0        ' how far back in history we've stepped
    m.offset = 0      ' next page when showing every photo in order
    m.loading = false
    m.paused = false
    m.fails = 0
    applyPrefs()
    m.status.text = "Opening the window…"
    showHint(normalHint())
    tick()
    m.clockTimer.control = "start"
    loadWeather()
    m.weatherTimer.control = "start"
    showMusic()
end sub

sub onShown(unused as dynamic)
    if m.options <> invalid
        m.options.setFocus(true)
    else
        m.top.setFocus(true)
    end if
    if m.started = invalid
        m.started = true
        if m.top.saver then m.hint.visible = false
        if m.top.albumName <> "" then m.album.text = UCase(m.top.albumName) else m.album.text = "ALL PHOTOS"
        fetchBatch()
    end if
end sub

sub applyPrefs()
    m.seconds = pPref("photoSeconds", "8").toInt()
    if m.seconds < 3 then m.seconds = 8
    m.advance.duration = m.seconds
    m.order = pPref("photoOrder", "shuffle")
    m.pan = (pPref("photoPan", "on") = "on")
end sub

function normalHint() as object
    return [{ icon: "lr", label: "Photos" }, { text: "OK", label: "Pause" }, { icon: "asterisk", label: "Options" }, { icon: "back", label: "Back" }]
end function

' ---------- photos ----------
sub fetchBatch()
    lib = pLibrary()
    if lib = ""
        m.status.text = "No photos library in Plex yet. Press Back."
        return
    end if
    if m.top.albumId = "@favourites"
        pPhotos("favourites", { section: lib }, "onBatch")
    else if m.top.albumId = "@onthisday"
        pPhotos("onthisday", { section: lib }, "onBatch")
    else if m.top.albumId <> ""
        pPhotos("album", { id: m.top.albumId }, "onBatch")
    else if m.order = "order"
        pPhotos("ordered", { section: lib, start: m.offset, limit: 60 }, "onBatch")
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
    if photos = invalid then photos = []
    if m.top.albumId = "" and m.order = "order"
        if photos.count() = 0 and m.offset > 0
            ' reached the newest photo: start again from the oldest
            m.offset = 0
            fetchBatch()
            return
        end if
        m.offset = m.offset + 60
    end if
    if photos.count() = 0
        m.status.text = "No photos here yet."
        return
    end if
    if m.order = "shuffle" then shuffle(photos)
    m.queue = photos
    m.next = 0
    showNext()
end sub

sub shuffle(a as object)
    for i = a.count() - 1 to 1 step -1
        j = Rnd(i + 1) - 1
        tmp = a[i] : a[i] = a[j] : a[j] = tmp
    end for
end sub

function isPortrait(item as object) as boolean
    return item <> invalid and item.w <> invalid and item.h <> invalid and item.h > item.w
end function

' The next slide in the queue: two portrait photos in a row share one slide
function peekSlide() as dynamic
    if m.next >= m.queue.count() then return invalid
    a = m.queue[m.next]
    if isPortrait(a) and m.next + 1 < m.queue.count() and isPortrait(m.queue[m.next + 1])
        b = m.queue[m.next + 1]
        return { items: [a, b], Id: a.Id + "|" + b.Id }
    end if
    return { items: [a], Id: a.Id }
end function

' Forward: step back toward the newest slide first, then take the next from the queue
sub showNext()
    if m.back > 0
        m.back = m.back - 1
        load(m.history[m.history.count() - 1 - m.back])
        return
    end if
    sl = peekSlide()
    if sl = invalid
        fetchBatch()
        return
    end if
    m.next = m.next + sl.items.count()
    load(sl)
end sub

sub showPrevious()
    if m.back + 1 >= m.history.count() then return
    m.back = m.back + 1
    load(m.history[m.history.count() - 1 - m.back])
end sub

' The slide that will come after this one, if we know it already
function upcoming() as dynamic
    if m.back > 0 then return m.history[m.history.count() - m.back]
    return peekSlide()
end function

sub load(slide as object)
    m.loading = true
    m.advance.control = "stop"
    m.pending = slide
    L = m.layers[1 - m.front]
    L.pan.scale = [1.0, 1.0]
    L.pan.translation = [0, 0]
    url = pPhotoUrl(slide.items[0], 1280, 720)
    m.need = 0
    m.expect = {}
    if slide.items.count() = 2
        ' two portraits flush, each filling half the screen at full height
        L.photo.translation = [0, 0]
        L.photo.width = 960
        L.photo.height = 1080
        L.photo.loadDisplayMode = "scaleToZoom"
        url2 = pPhotoUrl(slide.items[1], 960, 1080)
        L.photo2.visible = true
        setPhoto(L.photo2, url2)
        url = pPhotoUrl(slide.items[0], 960, 1080)
    else
        L.photo.translation = [0, 0]
        L.photo.width = 1920
        L.photo.height = 1080
        L.photo.loadDisplayMode = "scaleToFit"
        L.photo2.visible = false
    end if
    L.back.uri = url
    setPhoto(L.photo, url)
    if m.need = 0 then reveal()
    ' tell the TV someone's here, so its own screensaver doesn't cover the slideshow
    if not m.top.saver then pHa("", "", true)
end sub

' Count a poster as still loading unless it already holds this exact photo
sub setPhoto(p as object, url as string)
    if p.uri = url and p.loadStatus = "ready" then return
    m.expect[url] = true
    m.need = m.need + 1
    p.uri = url
end sub

sub onLoadStatus(event as object)
    s = event.getData()
    node = event.getRoSGNode()
    L = m.layers[1 - m.front]
    if not node.isSameNode(L.photo) and not node.isSameNode(L.photo2) then return
    if not m.loading then return
    ' a late answer for a photo we've already skipped past
    if m.expect = invalid or m.expect[node.uri] <> true then return
    m.expect.delete(node.uri)
    if s = "ready"
        m.need = m.need - 1
        if m.need <= 0 then reveal()
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
    startPan(incoming)
    if m.back = 0 and (m.history.count() = 0 or m.history.peek().Id <> m.pending.Id) then m.history.push(m.pending)
    if m.history.count() > 50 then m.history.shift()
    m.caption.text = slideCaption(m.pending)
    showStar()
    m.captionGroup.opacity = 1.0
    m.captionFade.control = "stop"
    m.captionFade.control = "start"
    nx = upcoming()
    if nx <> invalid and nx.items.count() = 1 then m.prefetch.uri = pPhotoUrl(nx.items[0], 1280, 720)
    if not m.paused and m.options = invalid then m.advance.control = "start"
end sub

function slideCaption(sl as object) as string
    a = pPhotoCaption(sl.items[0])
    if sl.items.count() = 2
        b = pPhotoCaption(sl.items[1])
        if b <> "" and b <> a
            if a = "" then return b
            return a + " · " + b
        end if
    end if
    return a
end function

function slideFav(sl as object) as boolean
    if sl = invalid then return false
    for each it in sl.items
        if it.fav <> true then return false
    end for
    return true
end function

sub showStar()
    if slideFav(m.pending) then m.star.text = "★ FAVOURITE" else m.star.text = ""
end sub

' Slow drift in one of four directions, lasting the photo's whole time on screen
sub startPan(layer as object)
    m.panAnim.control = "stop"
    if not m.pan then return
    dirs = [[-30, -16], [30, -16], [-30, 16], [30, 16]]
    m.panScale.fieldToInterp = layer.panName + ".scale"
    m.panMove.fieldToInterp = layer.panName + ".translation"
    m.panMove.keyValue = [[0, 0], dirs[Rnd(4) - 1]]
    m.panAnim.duration = m.seconds + 1.5
    m.panAnim.control = "start"
    if m.paused then m.panAnim.control = "pause"
end sub

sub onAdvance()
    if not m.paused and not m.loading and m.options = invalid then showNext()
end sub

' ---------- clock, weather, music ----------
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
        s = Int(a.temperature + 0.5).toStr() + "° · " + s
    end if
    m.weather.text = s
end sub

' Only while music is actually playing
sub showMusic()
    mp = m.global.music
    if mp = invalid or mp.state <> "playing" or mp.track = invalid
        m.nowPlaying.visible = false
        return
    end if
    t = mp.track.title
    if t = invalid then t = ""
    if mp.track.artist <> invalid and mp.track.artist <> "" then t = t + " · " + mp.track.artist
    m.npTitle.text = t
    m.nowPlaying.visible = (t <> "")
end sub

' ---------- options panel (✱) ----------
sub openOptions()
    m.advance.control = "stop"
    m.panAnim.control = "pause"
    m.captionGroup.visible = false
    m.hint.visible = false
    o = CreateObject("roSGNode", "PhotoOptions")
    if m.top.albumName <> "" then o.eyebrowText = UCase(m.top.albumName) else o.eyebrowText = "ALL PHOTOS"
    if m.pending <> invalid
        o.captionText = slideCaption(m.pending)
        o.thumbUri = pPhotoUrl(m.pending.items[0], 240, 160)
    end if
    if m.top.albumId <> "" then o.saverChoice = m.top.albumId else o.saverChoice = "all"
    o.favourite = slideFav(m.pending)
    o.callFunc("setup", invalid)
    o.observeField("changed", "onOptionChanged")
    o.observeField("closed", "closeOptions")
    m.optionsHolder.appendChild(o)
    m.options = o
    o.setFocus(true)
end sub

sub onOptionChanged(event as object)
    c = event.getData()
    if c.key = "fav" and m.pending <> invalid
        if c.value then rating = 10 else rating = -1
        for each it in m.pending.items
            it.fav = c.value
            pPhotos("rate", { id: it.Id, rating: rating }, "onRated")
        end for
        showStar()
    else if c.key = "photoSaver"
        pSetPref("photoSaverName", m.top.albumName)
    else if c.key = "photoOrder"
        m.reorder = true
    end if
    applyPrefs()
    if not m.pan then m.panAnim.control = "stop"
end sub

sub onRated(event as object)
    t = pTaskFrom(event)
    if not t.ok
        m.status.text = "Couldn't save the favourite (" + t.status.toStr() + ")"
    end if
end sub

sub closeOptions()
    if m.options = invalid then return
    m.optionsHolder.removeChild(m.options)
    m.options = invalid
    m.captionGroup.visible = true
    m.hint.visible = not m.top.saver
    m.top.setFocus(true)
    if m.reorder = true
        ' new order starts with the next photo
        m.reorder = false
        m.offset = 0
        m.queue = []
        m.next = 0
        m.back = 0
    end if
    if not m.paused
        if m.pan then m.panAnim.control = "resume"
        if not m.loading then m.advance.control = "start"
    end if
end sub

' ---------- keys ----------
sub showHint(keys as object)
    if m.top.saver then return
    m.hintKeys.keys = keys
    m.hint.opacity = 1.0
    m.hintFade.control = "stop"
    m.hintFade.control = "start"
end sub

sub setPaused(p as boolean)
    m.paused = p
    m.pausedBadge.visible = p
    if p
        m.advance.control = "stop"
        m.panAnim.control = "pause"
        showHint([{ icon: "lr", label: "Photos" }, { text: "OK", label: "Resume" }, { icon: "asterisk", label: "Options" }, { icon: "back", label: "Back" }])
    else
        showHint(normalHint())
        if m.pan then m.panAnim.control = "resume"
        if not m.loading then showNext()
    end if
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
    if key = "back"
        cleanup()
        m.top.request = { action: "back" }
    else if key = "right"
        if not m.loading then showNext()
        showHint(normalHint())
    else if key = "left"
        if not m.loading then showPrevious()
        showHint(normalHint())
    else if key = "OK"
        setPaused(not m.paused)
    else if key = "options"
        openOptions()
    else if key = "up" or key = "down"
        showHint(normalHint())
        m.captionGroup.opacity = 1.0
        m.captionFade.control = "stop"
        m.captionFade.control = "start"
    else
        return false
    end if
    return true
end function

sub cleanup()
    m.advance.control = "stop"
    m.clockTimer.control = "stop"
    m.weatherTimer.control = "stop"
    m.panAnim.control = "stop"
    mp = m.global.music
    if mp <> invalid
        mp.unobserveField("state")
        mp.unobserveField("track")
    end if
end sub
