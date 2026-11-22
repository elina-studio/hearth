' Lidarr requests. The key lives only on the TV: registry "hearth" / "lidarrKey" (optional "lidarrUrl",
' default http://192.168.254.41:8686). It arrives from the Mac over ECP (/input?lidarrKey=...) via main.brs.
sub init()
    m.eyebrow = m.top.findNode("eyebrow")
    m.eyebrow.font = hFont("caps", 30)
    m.hint = m.top.findNode("hint")
    m.hint.font = hFont("regular", 26)
    m.kb = m.top.findNode("kb")
    m.kb.observeField("text", "onKbText")
    m.list = m.top.findNode("list")
    m.empty = m.top.findNode("empty")
    m.empty.font = hFont("regular", 30)
    m.setup = m.top.findNode("setup")
    m.setupText = m.top.findNode("setupText")
    m.setupText.font = hFont("regular", 30)
    m.toast = m.top.findNode("toast")
    m.toast.font = hFont("bold", 28)
    m.toastTimer = m.top.findNode("toastTimer")
    m.toastTimer.observeField("fire", "hideToast")
    m.debounce = m.top.findNode("debounce")
    m.debounce.observeField("fire", "lookup")
    m.results = []
    m.sel = 0
    m.zone = "kb"
    m.defaults = invalid
    m.adding = false
    if not m.global.hasField("lidarrKey") then m.global.addFields({ lidarrKey: "" })
    m.global.observeFieldScoped("lidarrKey", "onKeyArrived")
    start()
end sub

' Search hands over what was typed ("Ask Lidarr for ...")
sub onTerm()
    m.kb.text = m.top.term
end sub

sub onShown(unused as dynamic)
    m.top.setFocus(true)
end sub

function hasKey() as boolean
    return CreateObject("roRegistrySection", "hearth").Read("lidarrKey") <> ""
end function

sub start()
    if not hasKey()
        showSetup("")
        return
    end if
    m.setup.visible = false
    m.kb.visible = true
    m.hint.text = "Type an artist. OK asks Lidarr for all their albums; * offers just the latest one."
    m.empty.text = "Matches from Lidarr show up here."
    paint()
    ' the profiles and folder new artists go into: the first of each
    m.defaults = {}
    lApi("GET", "/qualityprofile", {}, invalid, "onDefaults", "quality")
    lApi("GET", "/metadataprofile", {}, invalid, "onDefaults", "metadata")
    lApi("GET", "/rootfolder", {}, invalid, "onDefaults", "root")
end sub

sub onKeyArrived()
    if m.setup.visible and hasKey() then start()
end sub

sub showSetup(problem as string)
    m.kb.visible = false
    m.kb.active = false
    m.list.removeChildrenIndex(m.list.getChildCount(), 0)
    m.empty.text = ""
    m.hint.text = ""
    q = Chr(34)
    lines = []
    if problem <> "" then lines.push(problem) : lines.push("")
    lines.push("Hearth needs Lidarr's API key once. With Hearth open on the TV, paste this into Terminal on your Mac:")
    lines.push("")
    lines.push("KEY=$(ssh -t Elina@192.168.254.41 " + q + "sudo /usr/local/bin/docker exec lidarr cat /config/config.xml" + q + " | sed -n 's/.*<ApiKey>\(.*\)<\/ApiKey>.*/\1/p' | tr -d '\r'); curl -X POST -G --data-urlencode " + q + "lidarrKey=$KEY" + q + " http://192.168.254.9:8060/input")
    lines.push("")
    lines.push("It asks for your NAS password, then this screen opens by itself. The key stays on the TV.")
    lines.push("Press Back to leave.")
    m.setupText.text = lines.join(Chr(10))
    m.setup.visible = true
end sub

' ---------- Lidarr calls ----------
function lApi(method as string, path as string, query as object, body as dynamic, cb as string, tag = "" as string) as object
    t = CreateObject("roSGNode", "LidarrTask")
    t.method = method
    t.path = path
    t.query = query
    if body <> invalid then t.body = body
    t.tag = tag
    t.observeField("done", cb)
    if m.hTasks = invalid then m.hTasks = {}
    key = "l" + Rnd(1000000).toStr()
    m.hTasks[key] = t
    t.key = key
    t.control = "RUN"
    return t
end function

function bad(t as object) as boolean
    if t.status = 401
        showSetup("Lidarr didn't accept the saved key.")
        return true
    end if
    if t.status <= 0
        say("Can't reach Lidarr at the NAS.")
        return true
    end if
    if not t.ok
        say("Lidarr said no (error " + t.status.toStr() + ").")
        return true
    end if
    return false
end function

sub onDefaults(event as object)
    t = hTaskFrom(event)
    if bad(t) then return
    items = t.response.Items
    if items = invalid or items.Count() = 0 then return
    first = items[0]
    if t.tag = "root" then m.defaults.root = first.path else m.defaults[t.tag] = first.id
end sub

sub onKbText()
    m.debounce.control = "stop"
    if Len(m.kb.text) >= 2 then m.debounce.control = "start"
end sub

sub lookup()
    m.term = m.kb.text
    m.empty.text = "Asking Lidarr" + Chr(8230)
    lApi("GET", "/artist/lookup", { term: m.term }, invalid, "onLookup", m.term)
end sub

sub onLookup(event as object)
    t = hTaskFrom(event)
    if t.tag <> m.kb.text then return
    if bad(t) then return
    m.results = []
    items = t.response.Items
    if items <> invalid
        for each a in items
            if m.results.Count() < 6 then m.results.push(a)
        end for
    end if
    m.sel = 0
    if m.results.Count() = 0 then m.empty.text = "Lidarr found nobody called " + m.kb.text + "." else m.empty.text = ""
    drawList()
    paint()
end sub

' ---------- the list ----------
function poster(a as object) as string
    if a.images = invalid then return ""
    for each im in a.images
        if im.coverType = "poster" and im.remoteUrl <> invalid then return im.remoteUrl
    end for
    for each im in a.images
        if im.remoteUrl <> invalid then return im.remoteUrl
    end for
    return ""
end function

function owned(a as object) as boolean
    return a.id <> invalid and a.id > 0
end function

sub drawList()
    m.list.removeChildrenIndex(m.list.getChildCount(), 0)
    y = 0
    for each a in m.results
        g = m.list.createChild("Group")
        g.translation = [0, y]
        ring = g.createChild("Rectangle")
        ring.width = 1064
        ring.height = 124
        ring.color = "0xE0B34A00"
        bg = g.createChild("Rectangle")
        bg.translation = [8, 8]
        bg.width = 108
        bg.height = 108
        bg.color = "0x1D2418FF"
        p = g.createChild("Poster")
        p.translation = [8, 8]
        p.width = 108
        p.height = 108
        p.loadWidth = 216
        p.loadHeight = 216
        p.loadDisplayMode = "scaleToZoom"
        p.uri = poster(a)
        name = g.createChild("Label")
        name.translation = [136, 18]
        name.width = 680
        name.font = hFont("bold", 34)
        name.color = "0xEDE6CAFF"
        name.text = a.artistName
        sub2 = g.createChild("Label")
        sub2.translation = [136, 66]
        sub2.width = 680
        sub2.font = hFont("regular", 24)
        sub2.color = "0xB5AF8CFF"
        d = ""
        if a.disambiguation <> invalid then d = a.disambiguation
        if d = "" and a.artistType <> invalid then d = a.artistType
        if a.genres <> invalid and a.genres.Count() > 0
            if d <> "" then d = d + "  ·  "
            d = d + a.genres[0]
        end if
        sub2.text = d
        chip = g.createChild("HearthPill")
        chip.translation = [840, 33]
        chip.width = 200
        chip.button = true
        if owned(a) then chip.text = "In Lidarr" else chip.text = "Request"
        y = y + 132
    end for
end sub

sub paint()
    m.kb.active = (m.zone = "kb" and m.kb.visible)
    for i = 0 to m.list.getChildCount() - 1
        g = m.list.getChild(i)
        on = (m.zone = "list" and i = m.sel)
        if on then g.getChild(0).color = "0xE0B34A33" else g.getChild(0).color = "0xE0B34A00"
        g.getChild(g.getChildCount() - 1).focused = on
    end for
end sub

' ---------- adding ----------
sub add(a as object, monitor as string)
    if owned(a)
        say(a.artistName + " is already in Lidarr.")
        return
    end if
    if m.adding then return
    d = m.defaults
    if d = invalid or d.root = invalid or d.quality = invalid or d.metadata = invalid
        say("Lidarr hasn't told Hearth its folders yet. Try again in a moment.")
        return
    end if
    m.adding = true
    body = { foreignArtistId: a.foreignArtistId, artistName: a.artistName, qualityProfileId: d.quality, metadataProfileId: d.metadata, rootFolderPath: d.root, monitored: true, monitorNewItems: "all", addOptions: { monitor: monitor, searchForMissingAlbums: true } }
    say("Asking Lidarr for " + a.artistName + Chr(8230))
    lApi("POST", "/artist", {}, body, "onAdded", a.artistName)
end sub

sub onAdded(event as object)
    t = hTaskFrom(event)
    m.adding = false
    if bad(t) then return
    say(t.tag + " is on the way. It shows up in Music once Lidarr has it and Plex scans it.")
    ' mark it so a second OK doesn't add twice
    r = t.response
    if r <> invalid and r.id <> invalid and m.sel < m.results.Count()
        m.results[m.sel].id = r.id
        drawList()
        paint()
    end if
end sub

sub say(text as string)
    m.toast.text = text
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub hideToast()
    m.toast.text = ""
end sub

sub options()
    if m.sel >= m.results.Count() then return
    a = m.results[m.sel]
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = a.artistName
    d.message = ["What should Lidarr get?"]
    d.buttons = ["All their albums", "Just the latest album", "Close"]
    d.observeField("buttonSelected", "onOption")
    d.observeField("wasClosed", "onShown")
    m.dialog = d
    m.top.getScene().dialog = d
end sub

sub onOption()
    b = m.dialog.buttonSelected
    m.dialog.close = true
    a = m.results[m.sel]
    if b = 0 then add(a, "all")
    if b = 1 then add(a, "latest")
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
    if key = "back"
        if m.zone = "list"
            m.zone = "kb"
            paint()
        else
            m.top.request = { action: "back" }
        end if
        return true
    end if
    if m.setup.visible then return true
    if m.zone = "kb"
        edge = m.kb.callFunc("handleKey", key)
        if edge = "right" and m.results.Count() > 0
            m.zone = "list"
        end if
        paint()
        return true
    end if
    ' the list
    if key = "up"
        if m.sel > 0 then m.sel = m.sel - 1
    else if key = "down"
        if m.sel < m.results.Count() - 1 then m.sel = m.sel + 1
    else if key = "left"
        m.zone = "kb"
    else if key = "OK"
        add(m.results[m.sel], "all")
    else if key = "options"
        options()
    end if
    paint()
    return true
end function
