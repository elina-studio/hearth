' The MilkDrop looks the Visualizer can show (made from tools/viz/looks.json; the NucBox renders them,
' the NAS keeps a ready-made loop of each). Pictures for the picker: pkg:/images/music/viz/<n>.jpg
' Registry "hearth": vizLook = "shuffle" (default) or a look number; vizStars = starred numbers, comma separated.
function vizLooks() as object
    return [
        { n: "3", label: "Wanderer in curved space" },
        { n: "8", label: "Mig 85" },
        { n: "10", label: "Airhandler" },
        { n: "14", label: "Tack tiles" },
        { n: "17", label: "Cubetrace" },
        { n: "18", label: "Skylight" },
        { n: "25", label: "Pogo cubes" },
        { n: "30", label: "Area 51" },
        { n: "35", label: "Why the sky looks different" },
        { n: "40", label: "Truly soft" },
        { n: "53", label: "Star of Annon" },
        { n: "54", label: "Spiral movement" },
        { n: "56", label: "Acid wiring" },
        { n: "57", label: "Angel flight" },
        { n: "58", label: "Another kind of groove" },
        { n: "59", label: "Bombyx mori" },
        { n: "60", label: "Castle in the air" },
        { n: "61", label: "Chain breaker" },
        { n: "62", label: "Charisma" },
        { n: "63", label: "Disco mix" },
        { n: "65", label: "Frosty caves" },
        { n: "73", label: "Surface turbulence" },
        { n: "74", label: "Reflections on black tiles" },
        { n: "75", label: "Stormy sea" },
        { n: "77", label: "Witchcraft" },
        { n: "78", label: "Fata morgana" },
        { n: "79", label: "Enterstate" },
        { n: "83", label: "Fractal drop" },
        { n: "94", label: "Rewop" },
        { n: "98", label: "Star ornament" },
        { n: "99", label: "True visionary" }
    ]
end function

function vizLabel(n as string) as string
    for each l in vizLooks()
        if l.n = n then return l.label
    end for
    return ""
end function

function vizChoice() as string
    c = CreateObject("roRegistrySection", "hearth").Read("vizLook")
    if c = "" or vizLabel(c) = "" then c = "shuffle"
    return c
end function

sub vizSetChoice(c as string)
    r = CreateObject("roRegistrySection", "hearth")
    r.Write("vizLook", c)
    r.Flush()
end sub

' starred looks as { "57": true, ... }
function vizStars() as object
    out = {}
    raw = CreateObject("roRegistrySection", "hearth").Read("vizStars")
    for each part in raw.Tokenize(",")
        if vizLabel(part) <> "" then out[part] = true
    end for
    return out
end function

sub vizSetStar(n as string, on as boolean)
    s = vizStars()
    if on then s[n] = true else s.Delete(n)
    r = CreateObject("roRegistrySection", "hearth")
    r.Write("vizStars", s.Keys().Join(","))
    r.Flush()
end sub

' the look for a song: the one picked, or a random starred one (any look when nothing is starred)
function vizPick() as string
    c = vizChoice()
    if c <> "shuffle" then return c
    pool = vizStars().Keys()
    if pool.Count() = 0
        for each l in vizLooks()
            pool.push(l.n)
        end for
    end if
    return pool[Rnd(pool.Count()) - 1]
end function
