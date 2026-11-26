' Shared helpers. Included by components with <script uri="pkg:/source/util.brs" />.

' Keys that always belong to the music outside video. Rooms return false for them so they reach the scene.
function hMediaKey(key as string) as boolean
    return key = "play" or key = "rewind" or key = "fastforward" or key = "replay"
end function

function hFont(kind as string, size as integer) as object
    f = CreateObject("roSGNode", "Font")
    ' final font set (whimsy spec): HearthSans = Ysabeau Bold with tall digits, for titles, caps kickers,
    ' card titles and buttons; Atkinson stays for small meta; Fell italic for section headers; DW Pica for rooms
    if kind = "bold" or kind = "caps"
        f.uri = "pkg:/fonts/HearthSans-Bold.ttf"
    else if kind = "pica"
        f.uri = "pkg:/fonts/IMFellDWPicaSC.ttf"
    else if kind = "fell"
        f.uri = "pkg:/fonts/HearthFell-Italic.ttf"
    else if kind = "clock"
        ' clock digits (whimsy clock B); swap here when the app-wide font set is picked
        f.uri = "pkg:/fonts/Cinzel-SemiBold.ttf"
    else if kind = "book"
        f.uri = "pkg:/fonts/EBGaramond-Regular.ttf"
    else
        f.uri = "pkg:/fonts/HearthText-Regular.ttf"
    end if
    f.size = size
    return f
end function

' One shared Font per kind and size. Making a Font node for every label is slow, and a Discover grid of 100 posters
' or a sheet of 50 chips would make hundreds of them.
function hFontCached(kind as string, size as integer) as object
    if not m.global.hasField("fontCache") then m.global.addFields({ fontCache: {} })
    key = kind + "|" + size.toStr()
    cache = m.global.fontCache
    f = cache[key]
    if f = invalid
        f = hFont(kind, size)
        cache[key] = f
        m.global.fontCache = cache
    end if
    return f
end function

function hColors() as object
    return { night: "0x0B0E09FF", panel: "0x141A11FF", ink: "0xEDE6CAFF", muted: "0xB5AF8CFF", gold: "0xE0B34AFF", goldInk: "0x1F1606FF", olive: "0xA3A35AFF", rope: "0xD9A066FF", ember: "0xF0907CFF" }
end function

' Image URL for an item, or "" when the item has no image of that kind
function hImage(item as object, kind as string, width as integer) as string
    if item = invalid then return ""
    if item._img <> invalid
        path = item._img[kind]
        if path = invalid or path = "" then return ""
        return hPlexImage(path, width, kind)
    end if
    server = m.global.server
    id = invalid
    tag = invalid
    if kind = "Backdrop"
        tags = item.BackdropImageTags
        if tags <> invalid and tags.count() > 0
            id = item.Id
            tag = tags[0]
        else if item.ParentBackdropItemId <> invalid and item.ParentBackdropImageTags <> invalid and item.ParentBackdropImageTags.count() > 0
            id = item.ParentBackdropItemId
            tag = item.ParentBackdropImageTags[0]
        end if
    else
        if item.ImageTags <> invalid and item.ImageTags[kind] <> invalid
            id = item.Id
            tag = item.ImageTags[kind]
        else if kind = "Thumb" and item.ParentThumbItemId <> invalid
            id = item.ParentThumbItemId
            tag = item.ParentThumbImageTag
        else if kind = "Primary" and item.SeriesId <> invalid and item.SeriesPrimaryImageTag <> invalid
            id = item.SeriesId
            tag = item.SeriesPrimaryImageTag
        end if
    end if
    if id = invalid then return ""
    url = server + "/Items/" + id + "/Images/" + kind + "?maxWidth=" + width.toStr() + "&quality=90"
    if tag <> invalid then url = url + "&tag=" + tag
    return url
end function

' Plex photo transcoder URL for a server image path
function hPlexImage(path as string, width as integer, kind as string) as string
    ' widths are in 1080p units; on an HD (720p) TV ask Plex for 2/3 the pixels so posters arrive faster
    if m.hImgScale = invalid
        m.hImgScale = 1.0
        if CreateObject("roDeviceInfo").GetUIResolution().name = "HD" then m.hImgScale = 0.6667
    end if
    width = Int(width * m.hImgScale)
    h = Int(width * 9 / 16)
    if kind = "Primary" then h = Int(width * 3 / 2)
    return m.global.plexServer + "/photo/:/transcode?width=" + width.toStr() + "&height=" + h.toStr() + "&minSize=1&upscale=1&url=" + hEscape(path) + "&X-Plex-Token=" + m.global.plexServerToken
end function

' Start a Plex request (see PlexTask). cb is the callback name taking the event.
function hPlex(op as string, args as object, cb as string, tag = "" as string) as object
    t = CreateObject("roSGNode", "PlexTask")
    t.op = op
    t.args = args
    t.tag = tag
    t.observeField("done", cb)
    if m.hTasks = invalid then m.hTasks = {}
    key = "p" + Rnd(1000000).toStr()
    m.hTasks[key] = t
    t.key = key
    t.control = "RUN"
    return t
end function

' First image found among kinds
function hImageAny(item as object, kinds as object, width as integer) as string
    for each k in kinds
        u = hImage(item, k, width)
        if u <> "" then return u
    end for
    return ""
end function

function hPercent(item as object) as float
    if item = invalid or item.UserData = invalid then return 0
    p = item.UserData.PlayedPercentage
    if p = invalid then return 0
    return p
end function

' Display title: series name for episodes
function hTitle(item as object) as string
    if item = invalid then return ""
    if item.Type = "Episode" and item.SeriesName <> invalid then return item.SeriesName
    if item.Name = invalid then return ""
    return item.Name
end function

function hSubtitle(item as object) as string
    if item = invalid then return ""
    if item.Type = "Episode"
        s = "S" + hNum(item.ParentIndexNumber) + " E" + hNum(item.IndexNumber)
        if item.Name <> invalid then s = s + " · " + item.Name
        return s
    end if
    if item.ProductionYear <> invalid then return item.ProductionYear.toStr()
    return ""
end function

function hNum(n as dynamic) as string
    if n = invalid then return "?"
    return n.toStr()
end function

function hMinutesLeft(item as object) as string
    if item = invalid or item.RunTimeTicks = invalid or item.UserData = invalid then return ""
    at = item.UserData.PlaybackPositionTicks
    if at = invalid then at = 0
    left = (item.RunTimeTicks - at) / 600000000
    return Int(left).toStr() + " min left"
end function

' Card data for CardRow from a Jellyfin item. shape: "wide" or "tall"
function hCard(item as object, shape as string) as object
    if shape = "tall"
        img = hImageAny(item, ["Primary"], 300)
    else
        img = hImageAny(item, ["Thumb", "Backdrop", "Primary"], 420)
    end if
    return { item: item, title: hTitle(item), sub: hSubtitle(item), image: img, progress: hPercent(item) }
end function

' Start an API call. cb is the name of a function in the caller taking the event.
function hApi(method as string, path as string, query as object, body as dynamic, cb as string, tag = "" as string) as object
    t = CreateObject("roSGNode", "ApiTask")
    t.method = method
    t.path = path
    t.query = query
    if body <> invalid then t.body = body
    t.tag = tag
    t.observeField("done", cb)
    t.control = "RUN"
    if m.hTasks = invalid then m.hTasks = {}
    key = "t" + Rnd(1000000).toStr()
    m.hTasks[key] = t
    t.key = key
    return t
end function

' Call at the top of an API callback: returns the task and releases it
function hTaskFrom(event as object) as object
    t = event.getRoSGNode()
    if m.hTasks <> invalid and t.key <> invalid then m.hTasks.delete(t.key)
    return t
end function

function hUser() as string
    return m.global.userId
end function

' Common item query fields
function hFields() as string
    return "Overview,PrimaryImageAspectRatio,ProductionYear,ParentId"
end function

' Percent-encode for URLs. roUrlTransfer can't be created on the render thread (it fails and the
' next call crashes the app), so screens must use this instead of roUrlTransfer.Escape.
function hEscape(s as string) as string
    b = CreateObject("roByteArray")
    b.FromAsciiString(s)
    hex = "0123456789ABCDEF"
    out = ""
    for i = 0 to b.count() - 1
        c = b[i]
        if (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c = 45 or c = 46 or c = 95 or c = 126
            out = out + Chr(c)
        else
            out = out + "%" + Mid(hex, (c >> 4) + 1, 1) + Mid(hex, (c and 15) + 1, 1)
        end if
    end for
    return out
end function

' Captions preference shared by the CC buttons and the player: "on", "off", or "" (follow Plex's pick)
' Subtitles are on by default (English, see components/subs/SubsAuto): "" means never set, so "on".
function hCaptions() as string
    v = CreateObject("roRegistrySection", "hearth").Read("captions")
    if v = "" then v = "on"
    return v
end function

function hCaptionsOn() as boolean
    return hCaptions() = "on"
end function

sub hToggleCaptions()
    reg = CreateObject("roRegistrySection", "hearth")
    if reg.Read("captions") = "on" then reg.Write("captions", "off") else reg.Write("captions", "on")
    reg.Flush()
end sub

' ---------- whimsy spec pieces shared by grids ----------
' A 12px braid progress bar under a card: call hBraidSet to show a percentage
function hBraid(parent as object, w as integer, y as integer) as object
    bar = parent.createChild("Group")
    bar.translation = [0, y]
    brTrack = bar.createChild("Poster")
    brTrack.uri = "pkg:/images/w/progress-track.9.png"
    brTrack.width = w
    brTrack.height = 12
    brClip = bar.createChild("Group")
    brClip.translation = [1, 1]
    brBody = brClip.createChild("Poster")
    brBody.uri = "pkg:/images/w/progress-fill-body.png"
    brBody.width = 512
    brBody.height = 10
    brTip = bar.createChild("Poster")
    brTip.uri = "pkg:/images/w/progress-fill-tip.png"
    brTip.width = 12
    brTip.height = 10
    bar.addFields({ clip: brClip, tip: brTip, w: w })
    return bar
end function

sub hBraidSet(bar as object, amount as float)
    bar.visible = amount > 0
    if amount <= 0 then return
    fillW = Int((bar.w - 2) * amount / 100)
    if fillW < 15 then fillW = 15
    bar.clip.clippingRect = [0, 0, fillW - 12, 10]
    bar.tip.translation = [1 + fillW - 12, 1]
end sub

' The corner moss for a card, the same one every time for the same key
function hMossUri(key as string) as string
    h = 0
    for i = 1 to Len(key)
        h = (h * 31 + Asc(Mid(key, i, 1))) mod 1000003
    end for
    kinds = ["1-round-caps", "2-tall-caps", "3-golden-funnels", "4-two-acorns"]
    return "pkg:/images/w/moss-corner-" + kinds[h mod 4] + ".png"
end function

' Rough-edge variant suffix for the n-th box in a row or group, so neighbours differ: "-v1" .. "-v6"
function hVar(n as integer) as string
    if n < 0 then n = -n
    return "-v" + ((n mod 6) + 1).toStr()
end function

' Moss hugs the focused box (whimsy spec 4). (lx, ty) and rx are the box's visible left, top and right.
' Size is 0.6 x the box width, 80 to 125. Kind is fixed per key (hash mod 4); one key in three gets the
' top-left corner (anchor 15, 55), the rest top-right (anchor 110, 55).
sub hMossHug(moss as object, lx as integer, ty as integer, rx as integer, key as string)
    h = 0
    for i = 1 to Len(key)
        h = (h * 31 + Asc(Mid(key, i, 1))) mod 1000003
    end for
    kinds = ["1-round-caps", "2-tall-caps", "3-golden-funnels", "4-two-acorns"]
    left = (h mod 3 = 0)
    side = ""
    if left then side = "-left"
    moss.uri = "pkg:/images/w/moss-corner-" + kinds[h mod 4] + side + ".png"
    mw = Int((rx - lx) * 0.6)
    if mw < 80 then mw = 80
    if mw > 125 then mw = 125
    s = mw / 125.0
    moss.width = mw
    moss.height = Int(96 * s)
    if left
        moss.translation = [Int(lx - 15 * s), Int(ty - 55 * s)]
    else
        moss.translation = [Int(rx - 110 * s), Int(ty - 55 * s)]
    end if
end sub

' After an Overseerr request succeeds: have Radarr/Sonarr search right away (ArrKickTask).
' r is Overseerr's reply to POST /api/v1/request.
sub hArrKick(r as object)
    if r = invalid or r.media = invalid then return
    ' still waiting for approval in Overseerr: Radarr/Sonarr don't have it yet
    if r.status <> invalid and r.status = 1 then return
    t = CreateObject("roSGNode", "ArrKickTask")
    mt = r.type
    if mt = invalid then mt = r.media.mediaType
    if mt = invalid then return
    t.mediaType = mt
    if r.media.tmdbId <> invalid then t.tmdbId = r.media.tmdbId
    if r.media.tvdbId <> invalid then t.tvdbId = r.media.tvdbId
    nums = []
    if r.seasons <> invalid
        for each s in r.seasons
            if s.seasonNumber <> invalid then nums.push(s.seasonNumber.toStr())
        end for
    end if
    if nums.count() > 0 then t.seasons = nums.join(",") else t.seasons = "all"
    t.observeField("done", "hArrKicked")
    if m.hArrTasks = invalid then m.hArrTasks = []
    m.hArrTasks.push(t)
    t.control = "RUN"
end sub

sub hArrKicked(event as object)
    t = event.getRoSGNode()
    if m.hArrTasks <> invalid
        stillRunning = []
        for each x in m.hArrTasks
            if not x.isSameNode(t) then stillRunning.push(x)
        end for
        m.hArrTasks = stillRunning
    end if
end sub

' Poster cards show their title in a fallback label until the art has loaded; hide it once it has.
' Call on each slot's Poster; the poster's parent group must carry a "fb" field.
sub hFbWatch(p as object)
    p.observeField("loadStatus", "hFbStatus")
end sub

sub hFbStatus(event as object)
    p = event.getRoSGNode()
    g = p.getParent()
    if g <> invalid and g.hasField("fb") then g.fb.visible = (p.loadStatus <> "ready")
    if p.loadStatus = "failed"
        print "[hearth-img] failed: "; Left(p.uri, 110)
        hFbRetryLater(p, g)
    end if
end sub

' A poster that failed (Plex's image transcoder drops requests when many arrive at once) is asked again after 2, 5 and 10 seconds,
' as long as it still shows the same picture and is on a visible, still-attached tile.
sub hFbRetryLater(p as object, g as dynamic)
    if g = invalid or p.uri = "" or Left(p.uri, 4) <> "http" then return
    if not p.hasField("hTries") then p.addFields({ hTries: 0, hTriesUri: "" })
    if p.hTriesUri <> p.uri
        p.hTriesUri = p.uri
        p.hTries = 0
    end if
    n = p.hTries
    if n >= 3 then return
    p.hTries = n + 1
    d = [2, 5, 10]
    t = CreateObject("roSGNode", "Timer")
    t.duration = d[n]
    t.repeat = false
    t.addFields({ poster: p, wantUri: p.uri })
    t.observeField("fire", "hFbRetry")
    g.appendChild(t)
    t.control = "start"
end sub

sub hFbRetry(event as object)
    t = event.getRoSGNode()
    p = t.poster
    g = t.getParent()
    if g <> invalid then g.removeChild(t)
    if p = invalid then return
    if p.uri = t.wantUri and p.loadStatus = "failed"
        print "[hearth-img] retry "; p.hTries; ": "; Left(p.uri, 110)
        u = p.uri
        p.uri = ""
        p.uri = u
    end if
end sub

' Names kept out of every shelf and list (Home, Music New/albums, search): matched anywhere in an item's title, album or artist.
' Add more here, lower case.
function hearthHiddenWords() as object
    return ["pimsleur"]
end function

function isHiddenItem(md as dynamic) as boolean
    if md = invalid or Type(md) <> "roAssociativeArray" then return false
    t = ""
    if md.title <> invalid then t = t + " " + md.title.toStr()
    if md.parentTitle <> invalid then t = t + " " + md.parentTitle.toStr()
    if md.grandparentTitle <> invalid then t = t + " " + md.grandparentTitle.toStr()
    t = LCase(t)
    for each w in hearthHiddenWords()
        if Instr(1, t, w) > 0 then return true
    end for
    return false
end function
