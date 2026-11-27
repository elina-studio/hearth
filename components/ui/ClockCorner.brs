sub init()
    m.clock = m.top.findNode("clock")
    m.clock.font = hFont("clock", 54)
    m.clockFly = m.top.findNode("clockFly")
    m.weather = m.top.findNode("weather")
    m.weather.font = hFont("book", 26)
    m.wxIcon = m.top.findNode("wxIcon")
    m.npChip = m.top.findNode("npChip")
    m.npBack = m.top.findNode("npBack")
    m.npArt = m.top.findNode("npArt")
    m.npArtBack = m.top.findNode("npArtBack")
    m.npTitle = m.top.findNode("npTitle")
    m.npTitle.font = hFont("bold", 22)
    m.npArtist = m.top.findNode("npArtist")
    m.npArtist.font = hFont("regular", 22)
    m.npBars = m.top.findNode("npBars")
    m.npPulse = m.top.findNode("npPulse")
    m.npThumb = ""
    m.npArt.observeField("loadStatus", "onChipArt")
    t = m.top.findNode("clockTimer")
    t.observeField("fire", "tick")
    t.control = "start"
    mp = m.global.music
    if mp <> invalid
        ' scoped: other screens watch the same fields
        mp.observeFieldScoped("track", "updateChip")
        mp.observeFieldScoped("state", "updateChip")
    end if
    if m.global.hasField("wx") then m.global.observeFieldScoped("wx", "paintWeather")
    tick()
    paintWeather()
    updateChip()
end sub

sub tick()
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    h12 = dt.GetHours() mod 12
    if h12 = 0 then h12 = 12
    mi = dt.GetMinutes()
    mm = mi.toStr()
    if mi < 10 then mm = "0" + mm
    m.clock.text = h12.toStr() + ":" + mm
    w = m.clock.localBoundingRect().width
    m.clock.translation = [1824 - w, 12]
    m.clockFly.translation = [1824 - w - 34, 40]
    layoutChip()
end sub

sub paintWeather()
    wx = invalid
    if m.global.hasField("wx") then wx = m.global.wx
    if wx = invalid or wx.text = invalid or wx.text = ""
        m.weather.text = ""
        m.wxIcon.visible = false
        return
    end if
    m.weather.text = wx.text
    if wx.icon <> invalid then m.wxIcon.uri = wx.icon
    w = m.weather.localBoundingRect().width
    m.weather.translation = [1824 - w, 96]
    m.wxIcon.translation = [1824 - w - 38, 100]
    m.wxIcon.visible = (m.wxIcon.uri <> "")
end sub

sub updateChip()
    mp = m.global.music
    tr = invalid
    on = false
    if mp <> invalid
        tr = mp.track
        on = (tr <> invalid and (mp.state = "playing" or mp.state = "buffering"))
    end if
    if not on
        if m.npChip.visible
            m.npChip.visible = false
            m.npPulse.control = "stop"
            m.clockFly.visible = true
        end if
        return
    end if
    hFontText(m.npTitle, tr.title, "bold")
    hFontText(m.npArtist, tr.artist, "regular")
    m.npTitle.text = pxStr(tr.title)
    m.npArtist.text = pxStr(tr.artist)
    th = pxStr(tr.thumb)
    if th <> m.npThumb
        m.npThumb = th
        m.npArtBack.visible = false
        if th = "" then m.npArt.uri = "" else m.npArt.uri = pxRound(pxImage(th, 120, 120), 120)
    end if
    if not m.npChip.visible
        m.npChip.visible = true
        m.clockFly.visible = false
        m.npPulse.control = "start"
    end if
    layoutChip()
end sub

sub onChipArt()
    if m.npArt.loadStatus = "failed" and m.npThumb <> ""
        sq = pxImage(m.npThumb, 120, 120)
        if m.npArt.uri <> sq
            m.npArtBack.visible = true
            m.npArt.uri = sq
        end if
    end if
end sub

' same rule as the hub: centred between the Search glass and the twig's leaf
sub layoutChip()
    if not m.npChip.visible then return
    ' the gap it lives in: from the Search glass (its picture ends at 1370) to the twig's first leaf (1663);
    ' 20 px clear of the glass, and short of the twig's left tip at 1634
    left = 1390
    right = 1622
    fixed = 60 + 10 + 18 + 18
    m.npTitle.width = 0
    m.npArtist.width = 0
    tw = m.npTitle.localBoundingRect().width
    aw = m.npArtist.localBoundingRect().width
    if aw > tw then tw = aw
    room = right - left - fixed
    if room < 40 then room = 40
    if tw > room then tw = room
    tw = Int(tw)
    m.npTitle.width = tw
    m.npArtist.width = tw
    w = fixed + tw
    m.npBack.width = w
    m.npBars.translation = [60 + tw + 10, 18]
    ' centred in the gap between the Search glass and the twig's leaf, and on the same line as the room names
    x = Int((left + right - w) / 2)
    m.npChip.translation = [x, 35]
end sub
