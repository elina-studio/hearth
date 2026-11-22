' Hearth: a small, fast Roku front end for a home Jellyfin server.
sub Main(args as dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    scene = screen.CreateScene("HearthScene")
    screen.show()
    scene.observeField("exitApp", port)
    ' settings sent from the Mac over ECP: POST http://<tv>:8060/input?overseerrKey=...
    input = CreateObject("roInput")
    input.setMessagePort(port)
    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.isScreenClosed() then return
        if type(msg) = "roSGNodeEvent" and msg.getField() = "exitApp" and msg.getData() = true then return
        if type(msg) = "roInputEvent" and msg.isInput() then saveInput(screen, msg.getInfo())
    end while
end sub

' Keys and addresses for other services stay on the TV (registry), never in the repo.
sub saveInput(screen as object, info as object)
    if info = invalid then return
    reg = CreateObject("roRegistrySection", "hearth")
    g = screen.getGlobalNode()
    if not g.hasField("overseerrKey") then g.addFields({ overseerrKey: "" })
    if info.overseerrUrl <> invalid and info.overseerrUrl <> ""
        reg.Write("overseerrUrl", info.overseerrUrl)
        reg.Flush()
    end if
    if info.overseerrKey <> invalid and info.overseerrKey <> ""
        reg.Write("overseerrKey", info.overseerrKey)
        reg.Flush()
        g.overseerrKey = info.overseerrKey
    end if
end sub

' Screensaver entry: the lantern, fireflies and quotes. Roku ends it on any key.
sub RunScreenSaver()
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    screen.CreateScene("SaverScene")
    screen.show()
    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.isScreenClosed() then return
    end while
end sub
