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

function ambMood(name as string) as object
    for each it in ambMoods()
        if it.mood = name then return it
    end for
    return invalid
end function

function ambHasVideo(it as object) as boolean
    if it = invalid or it.video = "" then return false
    return CreateObject("roFileSystem").Exists(it.video)
end function
