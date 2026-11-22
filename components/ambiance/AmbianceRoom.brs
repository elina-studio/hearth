sub init()
    m.top.findNode("title").font = hFont("fell", 52)
    note = m.top.findNode("note")
    note.font = hFont("regular", 28)
    note.text = "Inside a mood: OK turns its sound on or off, Left and Right change the mood, and the * button sets a sleep timer. Music keeps playing underneath."
    m.row = m.top.findNode("row")
    m.items = [
        { mood: "hearth", title: "Hearth", sub: "Fire and crackle", image: "pkg:/images/amb/tile-hearth.jpg" },
        { mood: "rain", title: "Rain on the roof", sub: "A wet night outside", image: "pkg:/images/amb/tile-rain.jpg" },
        { mood: "fireflies", title: "Fireflies", sub: "Crickets in the meadow", image: "pkg:/images/amb/tile-fireflies.jpg" },
        { mood: "lightsout", title: "Lights out", sub: "Embers, stops in 30 min", image: "pkg:/images/amb/tile-lightsout.jpg" },
        { mood: "window", title: "The Window", sub: "Your photos", image: "pkg:/images/amb/tile-window.jpg" }
    ]
    cards = []
    for each it in m.items
        cards.push({ title: it.title, sub: it.sub, image: it.image, progress: 0 })
    end for
    m.row.cards = cards
end sub

sub focusIn(unused as dynamic)
    m.row.active = true
    m.top.setFocus(true)
end sub

sub refresh(unused as dynamic)
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
    if key = "left" or key = "right"
        if key = "left" then d = -1 else d = 1
        m.row.callFunc("move", d)
        return true
    else if key = "OK"
        it = m.items[m.row.index]
        if it.mood = "window"
            m.top.request = { action: "room", name: "Photos" }
        else
            m.top.request = { action: "mood", mood: it.mood }
        end if
        return true
    else if key = "up" or key = "back"
        m.row.active = false
        m.top.request = { action: "pills" }
        return true
    end if
    return true
end function
