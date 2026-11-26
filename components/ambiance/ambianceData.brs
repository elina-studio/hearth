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

' Footage comes from Plex only (the package has no videos), so no file checks here: roFileSystem
' can't be created on the render thread.
function ambHasVideo(it as object) as boolean
    return it <> invalid and it.clip <> invalid
end function

' Which built-in mood a clip belongs to, from the start of its file name or title ("rain-creek.mp4" -> rain).
' "" means it's a new mood of its own.
function ambClipMood(name as string) as string
    ' letters and digits only, lower case (no String.Replace: older Roku OS doesn't have it)
    n = ""
    low = LCase(name)
    for i = 1 to Len(low)
        ch = Mid(low, i, 1)
        if ch <> " " and ch <> "-" and ch <> "_" then n = n + ch
    end for
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
    ' a TV-friendly copy named "<name>-tv.mp4" (made with the ffmpeg command) stands in for "<name>.<ext>"
    tvOf = {}
    for each c in clips
        b = ambBase(c.file)
        if Len(b) > 3 and Right(b, 3) = "-tv" then tvOf[Left(b, Len(b) - 3)] = c
    end for
    picked = []
    for each c in clips
        b = ambBase(c.file)
        if Len(b) > 3 and Right(b, 3) = "-tv"
            ' only used through its original, unless the original isn't in the library
            hasOrig = false
            for each o in clips
                if ambBase(o.file) = Left(b, Len(b) - 3) then hasOrig = true
            end for
            if not hasOrig then picked.push(c)
        else if tvOf[b] <> invalid
            t = tvOf[b]
            t.Name = c.Name
            picked.push(t)
        else
            picked.push(c)
        end if
    end for
    clips = picked
    ' Several clips can start with the same mood word (say "Rain on glass.mov" from the phone and
    ' "rain-tv.mp4" made for the TV). The first one in Plex's title order used to win, which could be the
    ' 4K HEVC original this TV can't play: the mood then fell back to a picture. Pick the best one:
    ' a "-tv" copy first, then one the TV plays as it is (H.264, 1080p or less), then the first.
    best = {}
    for each c in clips
        md = ambClipMood(c.file)
        if md = "" then md = ambClipMood(c.Name)
        c._md = md
        print "[ambiance] clip '"; c.file; "' -> mood '"; md; "' score "; ambClipScore(c); " codec "; c.videoCodec; " "; c.width; "x"; c.height
        if md <> ""
            if best[md] = invalid or ambClipScore(c) > ambClipScore(best[md]) then best[md] = c
        end if
    end for
    for each c in clips
        md = c._md
        if md <> "" and best[md] <> invalid and best[md].Id = c.Id
            for each it in items
                if it.mood = md
                    it.clip = c
                    ' the clip's own name says what it is ("Fire in the woods")
                    if c.Name <> invalid and c.Name <> "" then it.sub = c.Name
                    if c.thumb <> invalid then it.plexStill = c.thumb
                end if
            end for
        else
            extra.push({ mood: "plex" + c.Id.toStr(), title: c.Name, sub: "Your own footage", still: "pkg:/images/amb/col-window.jpg", plexStill: c.thumb, video: "", credit: "", clip: c })
        end if
    end for
    for each it in items
        if it.clip <> invalid then print "[ambiance] mood "; it.mood; " plays '"; it.clip.file; "'" else print "[ambiance] mood "; it.mood; " has NO clip"
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

' How well the TV will play a clip: 2 for a "-tv" copy, +1 when it needs no converting
function ambClipScore(c as object) as integer
    n = 0
    b = ambBase(c.file)
    if Len(b) > 3 and Right(b, 3) = "-tv" then n = n + 2
    vc = ""
    if c.videoCodec <> invalid then vc = LCase(c.videoCodec.toStr())
    ok = (vc = "" or vc = "h264")
    if c.width <> invalid and Val(c.width.toStr()) > 1920 then ok = false
    if c.height <> invalid and Val(c.height.toStr()) > 1080 then ok = false
    if ok then n = n + 1
    return n
end function

' Which generated sound goes with a mood (for "Both"): built-ins use their own; your clips by name.
function ambSoundMood(it as dynamic) as string
    if it = invalid then return "hearth"
    md = it.mood
    if md = "hearth" or md = "rain" or md = "fireflies" or md = "lightsout" then return md
    n = LCase(it.title)
    for each w in ["creek", "river", "water", "stream", "brook", "rain", "lake", "ocean", "wave", "falls"]
        if Instr(1, n, w) > 0 then return "rain"
    end for
    for each w in ["fire", "camp", "ember", "hearth"]
        if Instr(1, n, w) > 0 then return "hearth"
    end for
    return "fireflies"
end function

' The word and icon for a mood's own sound on the switch.
function ambSoundLabel(it as dynamic) as object
    md = ambSoundMood(it)
    if it <> invalid and it.mood = "lightsout" then return { word: "Embers", icon: "flame" }
    if md = "hearth" then return { word: "Fire", icon: "flame" }
    if md = "rain"
        if it <> invalid and it.mood = "rain" then return { word: "Rain", icon: "drop" }
        return { word: "Water", icon: "drop" }
    end if
    if it <> invalid and it.mood = "fireflies" then return { word: "Night", icon: "moon" }
    return { word: "Nature", icon: "leaf" }
end function

' file name without folders or extension, lower case
function ambBase(path as dynamic) as string
    if path = invalid then return ""
    p = LCase(path.toStr())
    i = Len(p)
    while i > 0
        if Mid(p, i, 1) = "/" then exit while
        i = i - 1
    end while
    p = Mid(p, i + 1)
    j = Len(p)
    while j > 0
        if Mid(p, j, 1) = "." then exit while
        j = j - 1
    end while
    if j > 1 then p = Left(p, j - 1)
    return p
end function
