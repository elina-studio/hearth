' Hearth: a small, fast Roku front end for a home Jellyfin server.
sub Main(args as dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    scene = screen.CreateScene("HearthScene")
    screen.show()
    scene.observeField("exitApp", port)
    while true
        msg = wait(0, port)
        if type(msg) = "roSGScreenEvent" and msg.isScreenClosed() then return
        if type(msg) = "roSGNodeEvent" and msg.getField() = "exitApp" and msg.getData() = true then return
    end while
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
