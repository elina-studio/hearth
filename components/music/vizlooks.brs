' The MilkDrop looks the Visualizer can show (made from tools/viz/looks.json; the NucBox renders them,
' the NAS keeps a ready-made loop of each). Pictures for the picker: pkg:/images/music/viz/<n>.jpg
' Registry "hearth": vizLook = "shuffle" (default) or a look number; vizStars = starred numbers, comma separated.
function vizLooks() as object
    return [
        { n: "40", label: "Truly soft" },
        { n: "57", label: "Angel flight" },
        { n: "58", label: "Another kind of groove" },
        { n: "61", label: "Chain breaker" },
        { n: "62", label: "Charisma" },
        { n: "74", label: "Reflections on black tiles" },
        { n: "77", label: "Witchcraft" },
        { n: "78", label: "Fata morgana" },
        { n: "94", label: "Rewop" },
        { n: "99", label: "True visionary" },
        { n: "102", label: "Prismo" },
        { n: "108", label: "Hexcollie" },
        { n: "109", label: "Spark" },
        { n: "110", label: "In da mash" },
        { n: "111", label: "Disco mashup" },
        { n: "117", label: "Witchcraft 2" },
        { n: "119", label: "Bouncing balls" },
        { n: "201", label: "Leaf mandala" },
        { n: "202", label: "Ladybug swarm" },
        { n: "203", label: "Leaf down a creek" },
        { n: "204", label: "Dandelion drift" },
        { n: "205", label: "Firefly meadow" },
        { n: "206", label: "Rain on the pond" },
        { n: "213", label: "Dusk flight" },
        { n: "221", label: "Moth lantern" },
        { n: "222", label: "Murmuration" },
        { n: "223", label: "Mushrooms" },
        { n: "224", label: "Smoke rings" },
        { n: "225", label: "Tree rings" },
        { n: "226", label: "Fern crown" },
        { n: "227", label: "Fiddleheads" },
        { n: "228", label: "Moonlit fronds" },
        { n: "229", label: "Constellation weave" },
        { n: "230", label: "Honeycomb glow" },
        { n: "231", label: "Jellyfish" },
        { n: "232", label: "Aurora over the hills" },
        { n: "233", label: "Dew on the web" },
        { n: "234", label: "Mycelium" }
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

' Hearts are kept under the old registry name vizStars, so looks starred before stay hearted.
function vizHearts() as object
    return vizStars()
end function

sub vizSetHeart(n as string, on as boolean)
    vizSetStar(n, on)
end sub

' Play setting: "hearted" or "all" (registry hearth/vizPlay). Unset: hearted once any look is hearted.
function vizPlayMode() as string
    md = CreateObject("roRegistrySection", "hearth").Read("vizPlay")
    if md <> "hearted" and md <> "all"
        if vizHearts().Count() > 0 then md = "hearted" else md = "all"
    end if
    return md
end function

sub vizSetPlayMode(md as string)
    r = CreateObject("roRegistrySection", "hearth")
    r.Write("vizPlay", md)
    r.Flush()
end sub

' the looks that Shuffle, Next and Left/Right go through, in list order
function vizPool() as object
    hearts = vizHearts()
    useHearts = (vizPlayMode() = "hearted" and hearts.Count() > 0)
    pool = []
    for each l in vizLooks()
        if not useHearts or hearts[l.n] = true then pool.push(l.n)
    end for
    return pool
end function

' the look for a song: the one picked, or a random one from the pool (hearted looks, or all)
function vizPick() as string
    c = vizChoice()
    if c <> "shuffle" then return c
    pool = vizPool()
    return pool[Rnd(pool.Count()) - 1]
end function
