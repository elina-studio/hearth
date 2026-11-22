' The moods, in room order. still = the column picture (shown cropped to the column),
' video = the full-screen loop (played only if the file is in the package), credit = on-screen attribution.
function ambMoods() as object
    return [
        { mood: "hearth", title: "Hearth", sub: "A log fire, crackling", still: "pkg:/images/amb/col-hearth.jpg", video: "pkg:/videos/hearth.mp4", credit: "" },
        { mood: "rain", title: "Rain", sub: "On the glass, after dark", still: "pkg:/images/amb/col-rain.jpg", video: "pkg:/videos/rain.mp4", credit: "" },
        { mood: "fireflies", title: "Fireflies", sub: "A summer night outside", still: "pkg:/images/amb/col-fireflies.jpg", video: "pkg:/videos/fireflies.mp4", credit: "" },
        { mood: "lightsout", title: "Lights out", sub: "Embers, then dark in 30 min", still: "pkg:/images/amb/col-lightsout.jpg", video: "pkg:/videos/lightsout.mp4", credit: "" },
        { mood: "window", title: "The Window", sub: "Your photos", still: "pkg:/images/amb/col-window.jpg", video: "", credit: "" }
    ]
end function

' The moods the room and the mood screen use: the built-in list, with the clips from the person's
' Plex "Ambiance" library merged in by AmbianceRoom (see ambMerge) once they've loaded.
function ambItems() as object
    if m.global <> invalid and m.global.hasField("ambItems") and m.global.ambItems <> invalid and m.global.ambItems.count() > 0 then return m.global.ambItems
    return ambMoods()
end function

function ambMood(name as string) as object
    for each it in ambItems()
        if it.mood = name then return it
    end for
    return invalid
end function

function ambHasVideo(it as object) as boolean
    if it = invalid then return false
    if it.clip <> invalid then return true
    if it.video = "" then return false
    return CreateObject("roFileSystem").Exists(it.video)
end function

' Which built-in mood a clip belongs to, from the start of its file name or title ("rain-creek.mp4" -> rain).
' "" means it's a new mood of its own.
function ambClipMood(name as string) as string
    n = LCase(name)
    n = n.replace(" ", "").replace("-", "").replace("_", "")
    for each pair in [["firefl", "fireflies"], ["lightsout", "lightsout"], ["embers", "lightsout"], ["hearth", "hearth"], ["fireplace", "hearth"], ["campfire", "hearth"], ["fire", "hearth"], ["rain", "rain"]]
        if Left(n, Len(pair[0])) = pair[0] then return pair[1]
    end for
    return ""
end function

' Merge Plex clips (PlexTask "clips") into the built-in moods. A clip that matches a mood replaces its
' picture and footage; the rest become new moods, placed before The Window. The first match wins.
function ambMerge(clips as object) as object
    items = ambMoods()
    extra = []
    taken = {}
    for each c in clips
        md = ambClipMood(c.file)
        if md = "" then md = ambClipMood(c.Name)
        if md <> "" and taken[md] = invalid
            taken[md] = true
            for each it in items
                if it.mood = md
                    it.clip = c
                    ' the clip's own name says what it is ("Fire in the woods")
                    if c.Name <> invalid and c.Name <> "" then it.sub = c.Name
                    if c.thumb <> invalid then it.plexStill = c.thumb
                end if
            end for
        else
            extra.push({ mood: "plex" + c.Id.toStr(), title: c.Name, sub: "From your own footage", still: "pkg:/images/amb/col-window.jpg", plexStill: c.thumb, video: "", credit: "", clip: c })
        end if
    end for
    out = []
    for each it in items
        if it.mood = "window"
            for each x in extra
                out.push(x)
            end for
        end if
        out.push(it)
    end for
    return out
end function
