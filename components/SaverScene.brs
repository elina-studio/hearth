sub init()
    m.top.backgroundColor = "0x060805FF"
    m.top.backgroundUri = ""
    reg = CreateObject("roRegistrySection", "hearth")
    choice = pPref("photoSaver", "")
    server = reg.Read("plexServer")
    token = reg.Read("plexServerToken")
    section = pPref("photoSection", "")
    intro = m.top.findNode("intro")
    if choice = "" or server = "" or token = "" or section = ""
        intro.visible = true
        return
    end if
    ' the slideshow reads these the same way it does inside the app
    m.global.addFields({ plexServer: server, plexServerToken: token, deviceId: reg.Read("deviceId"), libraries: { photos: section } })
    m.top.removeChild(intro)
    s = CreateObject("roSGNode", "SlideshowScreen")
    s.saver = true
    if choice <> "all"
        s.albumId = choice
        s.albumName = pPref("photoSaverName", "")
    end if
    m.top.appendChild(s)
    s.setFocus(true)
    s.callFunc("onShown", invalid)
end sub
