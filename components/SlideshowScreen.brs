' The Window. One photo at a time, crossfading every few seconds.
' Left/Right step through photos, OK pauses, Down or ✱ opens the options card, Back closes.
' Photos stay still (no pan and zoom) and crossfade softly.
' Play, Rewind and Fast forward stay with the music.
sub init()
    m.layers = [
        { group: m.top.findNode("layerA"), back: m.top.findNode("backA"), photo: m.top.findNode("photoA"), photo2: m.top.findNode("photoA2"), pan: m.top.findNode("panA"), name: "layerA", panName: "panA", frame: m.top.findNode("frameA"), plate: m.top.findNode("plateA"), fT: m.top.findNode("frameAT"), fB: m.top.findNode("frameAB"), fL: m.top.findNode("frameAL"), fR: m.top.findNode("frameAR") },
        { group: m.top.findNode("layerB"), back: m.top.findNode("backB"), photo: m.top.findNode("photoB"), photo2: m.top.findNode("photoB2"), pan: m.top.findNode("panB"), name: "layerB", panName: "panB", frame: m.top.findNode("frameB"), plate: m.top.findNode("plateB"), fT: m.top.findNode("frameBT"), fB: m.top.findNode("frameBB"), fL: m.top.findNode("frameBL"), fR: m.top.findNode("frameBR") }
    ]
    m.front = 1 ' index of the layer on screen; the first photo goes to the other one
    m.prefetch = m.top.findNode("prefetch")
    m.clock = m.top.findNode("clock")
    m.clock.font = hFont("clock", 72)
    m.clockFly = m.top.findNode("clockFly")
    m.wxIcon = m.top.findNode("wxIcon")
    m.date = m.top.findNode("date")
    m.date.font = hFont("fell", 36)
    m.weather = m.top.findNode("weather")
    m.wxLooked = false
    m.weather.font = hFont("book", 28)
    m.album = m.top.findNode("album")
    m.album.font = hFont("caps", 28)
    m.caption = m.top.findNode("caption")
    m.caption.font = hFont("regular", 32)
    m.star = m.top.findNode("star")
    m.star.font = hFont("caps", 26)
    m.captionGroup = m.top.findNode("captionGroup")
    m.captionFade = m.top.findNode("captionFade")
    m.nowPlaying = m.top.findNode("nowPlaying")
    npEyebrow = m.top.findNode("npEyebrow")
    npEyebrow.font = hFont("caps", 24)
    ' the note icon sits just left of the eyebrow (the ♪ character isn't in the fonts)
    m.top.findNode("npIcon").translation = [1824 - npEyebrow.localBoundingRect().width - 34, 940]
    m.npTitle = m.top.findNode("npTitle")
    m.npTitle.font = hFont("book", 30)
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
    m.advance = m.top.findNode("advance")
    m.advance.observeField("fire", "onAdvance")
    m.loadTimeout = m.top.findNode("loadTimeout")
    m.loadTimeout.observeField("fire", "onLoadTimeout")
    m.clockTimer = m.top.findNode("clockTimer")
    m.clockTimer.observeField("fire", "tick")
    m.weatherTimer = m.top.findNode("weatherTimer")
    m.weatherTimer.observeField("fire", "loadWeather")
    for each l in m.layers
        l.plate.font = hFont("fell", 32)
        l.photo.observeField("loadStatus", "onLoadStatus")
        l.photo2.observeField("loadStatus", "onLoadStatus")
    end for
    mp = m.global.music
    if mp <> invalid
        ' scoped: a plain unobserveField later would also drop every other screen's observers on the player
        mp.observeFieldScoped("state", "showMusic")
        mp.observeFieldScoped("track", "showMusic")
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
        if not m.top.saver then m.top.findNode("lyrics").callFunc("start", invalid)
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
    m.framed = (pPref("photoFrame", "off") = "on")
end sub

function normalHint() as object
    return [{ icon: "lr", label: "Photos" }, { text: "OK", label: "Pause" }, { icon: "down", label: "Options" }, { icon: "back", label: "Back" }]
end function

' ---------- photos ----------
sub fetchBatch()
    lib = pLibrary()
    if lib = ""
        m.status.text = "No photos library in Plex yet. Press Back."
        return
    end if
    ' one request at a time: Right or the timer can ask again while a batch is still on its way
    if m.fetching = true then return
    m.fetching = true
    if m.top.albumId = "@favourites"
        pPhotos("favourites", { section: lib }, "onBatch")
    else if m.top.albumId = "@onthisday"
        ' this looks through every past year, so it can take a few seconds
        if m.queue.count() = 0 then m.status.text = "Looking back through the years…"
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
    m.fetching = false
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
        if m.top.albumId = "@onthisday" then m.status.text = "No photos from this day in other years." else m.status.text = "No photos here yet."
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
    url = pPhotoUrl(slide.items[0], 1280, 720)
    m.need = 0
    m.expect = {}
    ' the Frame look shows the photo inside a box (60 px at the sides, room for the date line below)
    bx = 0 : by = 0 : bw = 1920 : bh = 1080
    if m.framed
        bx = 60 : by = 50 : bw = 1800 : bh = 910
    end if
    L.back.visible = not m.framed
    L.frame.visible = false
    if slide.items.count() = 2
        ' two portraits flush, each filling half the screen (or half the frame) at full height
        L.photo.translation = [bx, by]
        L.photo.width = bw / 2
        L.photo.height = bh
        L.photo2.translation = [bx + bw / 2, by]
        L.photo2.width = bw / 2
        L.photo2.height = bh
        L.photo.loadDisplayMode = "scaleToZoom"
        ' decode at the half-screen shape (like photo2), not the 16:9 default
        L.photo.loadWidth = 640
        L.photo.loadHeight = 720
        url2 = pPhotoUrl(slide.items[1], 960, 1080, true)
        L.photo2.visible = true
        setPhoto(L.photo2, url2)
        url = pPhotoUrl(slide.items[0], 960, 1080, true)
    else
        L.photo.translation = [bx, by]
        L.photo.width = bw
        L.photo.height = bh
        L.photo.loadDisplayMode = "scaleToFit"
        L.photo.loadWidth = 1280
        L.photo.loadHeight = 720
        L.photo2.visible = false
    end if
    L.back.uri = url
    setPhoto(L.photo, url)
    if m.need = 0
        reveal()
    else
        m.loadTimeout.control = "stop"
        m.loadTimeout.control = "start"
    end if
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
    ' "loading" comes first; wait for the answer before crossing the photo off
    if s = "ready"
        m.expect.delete(node.uri)
        m.need = m.need - 1
        if m.need <= 0 then reveal()
    else if s = "failed"
        m.expect.delete(node.uri)
        skip()
    end if
end sub

' Safety net: a photo that hasn't answered in 20 seconds is passed over
sub onLoadTimeout()
    if not m.loading then return
    L = m.layers[1 - m.front]
    ready = true
    for each p in [L.photo, L.photo2]
        if m.expect[p.uri] = true
            if p.loadStatus = "ready" then m.expect.delete(p.uri) else ready = false
        end if
    end for
    if ready then reveal() else skip()
end sub

' A photo that won't download or draw is passed over, up to a point
sub skip()
    m.loadTimeout.control = "stop"
    m.loading = false
    m.fails = m.fails + 1
    if m.fails >= 5
        m.status.text = "Photos aren't loading. Press Back and check the Photos room."
        return
    end if
    showNext()
end sub

sub reveal()
    m.loadTimeout.control = "stop"
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
    placeFrame(incoming, m.pending)
    if m.back = 0 and (m.history.count() = 0 or m.history.peek().Id <> m.pending.Id) then m.history.push(m.pending)
    if m.history.count() > 50 then m.history.shift()
    ' with the Frame look the date sits under the photo instead
    if m.framed then m.caption.text = "" else m.caption.text = slideCaption(m.pending)
    showStar()
    m.captionGroup.opacity = 1.0
    m.captionFade.control = "stop"
    m.captionFade.control = "start"
    nx = upcoming()
    if nx <> invalid and nx.items.count() = 1 then m.prefetch.uri = pPhotoUrl(nx.items[0], 1280, 720)
    if not m.paused and m.options = invalid then m.advance.control = "start"
end sub

' Frame look: hug the drawn photo (scaleToFit leaves bars inside the box) with the hairline, 10 px out,
' and put "Lake Tahoe · June 2019" under it
sub placeFrame(L as object, sl as object)
    if not m.framed or sl = invalid
        L.frame.visible = false
        return
    end if
    x = L.photo.translation[0]
    y = L.photo.translation[1]
    w = L.photo.width
    h = L.photo.height
    if sl.items.count() = 2
        w = w * 2
    else if L.photo.bitmapWidth > 0 and L.photo.bitmapHeight > 0
        sc = w / L.photo.bitmapWidth
        if h / L.photo.bitmapHeight < sc then sc = h / L.photo.bitmapHeight
        dw = L.photo.bitmapWidth * sc
        dh = L.photo.bitmapHeight * sc
        x = x + (w - dw) / 2
        y = y + (h - dh) / 2
        w = dw
        h = dh
    end if
    x0 = Int(x) - 12
    y0 = Int(y) - 12
    fw = Int(w) + 24
    fh = Int(h) + 24
    L.fT.translation = [x0, y0]
    L.fT.width = fw
    L.fB.translation = [x0, y0 + fh - 2]
    L.fB.width = fw
    L.fL.translation = [x0, y0]
    L.fL.height = fh
    L.fR.translation = [x0 + fw - 2, y0]
    L.fR.height = fh
    it = sl.items[0]
    parts = []
    if it.place <> invalid and it.place <> "" then parts.push(it.place)
    cap = slideCaption(sl)
    if cap <> "" then parts.push(cap)
    L.plate.text = parts.join(" · ")
    L.plate.translation = [0, y0 + fh + 8]
    L.frame.visible = true
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
    ' right-align by measuring, so the firefly can sit just left of the time
    w = m.clock.localBoundingRect().width
    m.clock.translation = [1824 - w, 48]
    m.clockFly.translation = [1824 - w - 40, 86]
    m.date.text = dt.GetWeekday() + " " + dt.GetDayOfMonth().toStr() + " " + pMonthName(dt.GetMonth())
end sub

sub loadWeather()
    c = pCfg()
    if c.haToken = ""
        m.weather.text = ""
        layoutWeather()
        return
    end if
    pHa("/api/states/" + c.haEntity, "onWeather")
end sub

sub onWeather(event as object)
    t = pTaskFrom(event)
    if not t.ok or t.response.state = invalid
        m.weather.text = ""
        layoutWeather()
        if t.status = 404 and not m.wxLooked
            m.wxLooked = true
            pHa("/api/states", "onWeatherList")
        end if
        return
    end if
    m.wxIcon.uri = pWxIcon(t.response.state)
    s = pWeatherWord(t.response.state)
    a = t.response.attributes
    if a <> invalid and a.temperature <> invalid
        s = Int(a.temperature + 0.5).toStr() + "° · " + s
    end if
    m.weather.text = s
    layoutWeather()
end sub

sub onWeatherList(event as object)
    t = pTaskFrom(event)
    if pPickWeather(t.response.items) <> "" then loadWeather()
end sub

' Weather line: gold icon, then text, right-aligned to 1824
sub layoutWeather()
    w = m.weather.localBoundingRect().width
    m.weather.translation = [1824 - w, 232]
    m.wxIcon.translation = [1824 - w - 38, 238]
    m.wxIcon.visible = (m.weather.text <> "" and m.wxIcon.uri <> "")
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
    m.npTitle.text = hFixText(t)
    m.nowPlaying.visible = (t <> "")
end sub

' ---------- options panel (✱) ----------
sub openOptions()
    m.advance.control = "stop"
    m.captionGroup.visible = false
    m.hint.visible = false
    o = CreateObject("roSGNode", "PhotoOptions")
    if m.top.albumName <> "" then o.eyebrowText = UCase(m.top.albumName) else o.eyebrowText = "ALL PHOTOS"
    if m.pending <> invalid
        o.captionText = slideCaption(m.pending)
        o.thumbUri = pPhotoUrl(m.pending.items[0], 240, 160, true)
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
    wasFramed = m.framed
    applyPrefs()
    ' show the Frame look (or take it off) on the photo that's up now
    if m.framed <> wasFramed and m.pending <> invalid and not m.loading then load(m.pending)
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
    if not m.paused and not m.loading then m.advance.control = "start"
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
        showHint([{ icon: "lr", label: "Photos" }, { text: "OK", label: "Resume" }, { icon: "down", label: "Options" }, { icon: "back", label: "Back" }])
    else
        showHint(normalHint())
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
    else if key = "options" or key = "down"
        openOptions()
    else if key = "up"
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
    m.top.findNode("lyrics").callFunc("lyricsStop", invalid)
    m.advance.control = "stop"
    m.clockTimer.control = "stop"
    m.weatherTimer.control = "stop"
    mp = m.global.music
    if mp <> invalid
        mp.unobserveFieldScoped("state")
        mp.unobserveFieldScoped("track")
    end if
end sub
