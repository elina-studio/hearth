' Hearth: a small, fast Roku front end for a home Jellyfin server.
sub Main(args as dynamic)
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.setMessagePort(port)
    ' phone remote (tools/remote): POST /input?hearthText=...&hearthGo=search|request
    screen.getGlobalNode().addFields({ remote: {} })
    restoreKeys()
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
    if info.hearthText <> invalid or info.hearthGo <> invalid
        g = screen.getGlobalNode()
        n = 1
        if g.remote <> invalid and g.remote.n <> invalid then n = g.remote.n + 1
        text = info.hearthText
        if text = invalid then text = ""
        dest = info.hearthGo
        if dest = invalid then dest = ""
        ' n changes every time, so the same text sent twice still notifies
        g.remote = { text: text, go: dest, n: n }
        return
    end if
    ' the phone's microphone measured the TV against the speakers: move the TV by this many seconds
    if info.castTrim <> invalid
        mu = screen.getGlobalNode().music
        if mu <> invalid then mu.command = { cmd: "castNudge", delta: Val(info.castTrim) }
        return
    end if
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
        ' clear first so Requests notices (and says "key saved") even when the same key is sent again
        g.overseerrKey = ""
        g.overseerrKey = info.overseerrKey
    end if
    ' Lidarr (music requests): lidarrUrl, lidarrKey
    if not g.hasField("lidarrKey") then g.addFields({ lidarrKey: "" })
    if info.lidarrUrl <> invalid and info.lidarrUrl <> ""
        reg.Write("lidarrUrl", info.lidarrUrl)
        reg.Flush()
    end if
    if info.lidarrKey <> invalid and info.lidarrKey <> ""
        reg.Write("lidarrKey", info.lidarrKey)
        reg.Flush()
        g.lidarrKey = info.lidarrKey
    end if
    ' Bazarr (subtitle finder): bazarrUrl, bazarrKey
    if info.bazarrUrl <> invalid and info.bazarrUrl <> ""
        reg.Write("bazarrUrl", info.bazarrUrl)
        reg.Flush()
    end if
    if info.bazarrKey <> invalid and info.bazarrKey <> ""
        reg.Write("bazarrKey", info.bazarrKey)
        reg.Flush()
        print "[hearth-subs] Bazarr key saved on the TV"
    end if
    ' Radarr / Sonarr (start downloads right after an Overseerr request): radarrUrl, radarrKey, sonarrUrl, sonarrKey
    for each k in ["radarrUrl", "radarrKey", "sonarrUrl", "sonarrKey"]
        if info[k] <> invalid and info[k] <> ""
            reg.Write(k, info[k])
            reg.Flush()
            print "[hearth-arr] saved "; k
        end if
    end for
    ' Photos weather: haUrl, haToken, haEntity (source/photos.brs)
    pSaveSettings(info)
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

' After a reinstall the TV's registry is empty. If the NAS helper holds a copy of the keys
' (tools/remote/save-keys.sh puts them in data/hearth-keys.json), pull them back before the app starts.
sub restoreKeys()
    reg = CreateObject("roRegistrySection", "hearth")
    if reg.Read("plexToken") <> "" then return
    base = reg.Read("nasUrl")
    if base = "" then base = "http://192.168.254.41:8765"
    port = CreateObject("roMessagePort")
    xfer = CreateObject("roUrlTransfer")
    xfer.setMessagePort(port)
    xfer.setUrl(base + "/api/keys")
    if not xfer.asyncGetToString() then return
    msg = wait(3000, port)
    if type(msg) <> "roUrlEvent" or msg.getResponseCode() <> 200 then return
    data = ParseJson(msg.getString())
    if data = invalid or type(data) <> "roAssociativeArray" then return
    ok = ["plexToken", "plexServer", "plexServerToken", "plexServerName", "overseerrUrl", "overseerrKey", "lidarrUrl", "lidarrKey", "bazarrUrl", "bazarrKey", "radarrUrl", "radarrKey", "sonarrUrl", "sonarrKey", "haUrl", "haToken", "haEntity", "lastfmOn"]
    n = 0
    for each k in ok
        if data[k] <> invalid and type(data[k]) = "String" and data[k] <> ""
            reg.Write(k, data[k])
            n = n + 1
        end if
    end for
    if n > 0 then reg.Flush()
    print "[hearth] restored "; n; " saved keys from the NAS helper"
end sub
