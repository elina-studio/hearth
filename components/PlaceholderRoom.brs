sub init()
    m.title = m.top.findNode("title")
    m.title.font = hFont("caps", 96)
    m.body = m.top.findNode("body")
    m.body.font = hFont("regular", 32)
end sub

sub onName()
    m.title.text = UCase(m.top.name)
    notes = {
        Music: "Your music through Music Assistant, with the cover wall and the visualizer. Coming in the music build.",
        Requests: "Ask Overseerr for movies and shows, and see what's on the way. Coming in the requests build.",
        Ambiance: "Hearth fire, rain on the roof, fireflies and lights out, with music underneath. Coming in the ambiance build.",
        Photos: "The Window: a slideshow from Immich with the clock and weather. Coming in the photos build.",
        Search: "Type a few letters, see matches as you type. Coming in the next build."
    }
    t = notes[m.top.name]
    if t = invalid then t = "Coming soon."
    m.body.text = t + Chr(10) + Chr(10) + "Press Back to return to the pills."
end sub

sub focusIn(unused as dynamic)
    m.top.setFocus(true)
end sub

sub refresh(unused as dynamic)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
    if key = "back" or key = "up"
        m.top.request = { action: "pills" }
    end if
    return true
end function
