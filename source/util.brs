' Shared helpers. Included by components with <script uri="pkg:/source/util.brs" />.

function hFont(kind as string, size as integer) as object
    f = CreateObject("roSGNode", "Font")
    if kind = "bold"
        f.uri = "pkg:/fonts/AtkinsonHyperlegible-Bold.ttf"
    else if kind = "fell"
        f.uri = "pkg:/fonts/IMFellEnglish-Italic.ttf"
    else if kind = "caps"
        f.uri = "pkg:/fonts/BarlowCondensed-Bold.ttf"
    else
        f.uri = "pkg:/fonts/AtkinsonHyperlegible-Regular.ttf"
    end if
    f.size = size
    return f
end function

function hColors() as object
    return { night: "0x0B0E09FF", panel: "0x141A11FF", ink: "0xEDE6CAFF", muted: "0xB5AF8CFF", gold: "0xE0B34AFF", goldInk: "0x1F1606FF", olive: "0xA3A35AFF", rope: "0xD9A066FF", ember: "0xF0907CFF" }
end function

' Image URL for an item, or "" when the item has no image of that kind
function hImage(item as object, kind as string, width as integer) as string
    if item = invalid then return ""
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
