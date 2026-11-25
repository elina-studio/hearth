' Radio: endless songs from your own library. Included by MusicPlayer. Hearth keeps the queue, so it works the same on the TV and
' on speakers. How it picks (see mockups/ideas/music-ideas-plan.md):
'   1. Seeds: what you're starting from, plus the last 3 songs you let play for 30 s or more (the "taste window").
'   2. Candidates (a refill gathers about 100): Plex sonic neighbours of each seed (/nearest, needs Plex Pass and sonic analysis),
'      the seed artist's other songs, and for favourites / forgotten / mood radios a library query, plus some random ones when Variety is high.
'   3. Score = sonic * a + tags * b + your affinity * c + freshness * d - skip penalty. Variety (0 to 4) moves the weights and widens the pool.
'   4. Hard rules: not in the last 50 played, nothing thumbed down in the last 30 days, nothing already queued, optionally nothing played
'      this week, no artist twice within 4 songs, at most 2 from one album among the last 10.
'   5. Weighted-random pick from the top of the list (so it varies), keep about 10 songs queued ahead, refill when 3 are left.
' Commands (music.command): radioStart {kind: song|artist|mood|favs|forgotten, variety, skipWeek, mood, moodName}, radioStop, radioNope, radioVariety {delta}.

sub radioInit()
    reg = CreateObject("roRegistrySection", "hearth")
    m.radio = invalid
    m.radioLoading = false
    m.keepTried = ""
    m.wantNext = false
    m.radioBans = {}
    raw = reg.Read("radioBans")
    if raw <> ""
        j = ParseJson(raw)
        if type(j) = "roAssociativeArray"
            now = CreateObject("roDateTime").AsSeconds()
            for each k in j
                if now - j[k] < 30 * 86400 then m.radioBans[k] = j[k]
            end for
        end if
    end if
    m.radioVar = 2
    v = reg.Read("radioVariety")
    if v <> "" then m.radioVar = Val(v)
    m.top.observeField("index", "radioCheck")
end sub

function radioVarName(v as integer) as string
    names = ["Very familiar", "Familiar", "Balanced", "Adventurous", "Very adventurous"]
    return names[v]
end function

sub radioStart(c as object)
    kind = pxStr(c.kind)
    tr = m.top.track
    seed = invalid
    if kind = "song" or kind = "artist"
        if tr = invalid or tr.id = invalid or tr.id = ""
            say("Play a song first, then start a radio from it.")
            return
        end if
        seed = tr
    end if
    v = m.radioVar
    if c.variety <> invalid then v = c.variety
    if v < 0 then v = 0
    if v > 4 then v = 4
    m.radioVar = v
    skipWeek = true
    if c.skipWeek = false then skipWeek = false
    r = { kind: kind, seed: seed, variety: v, skipWeek: skipWeek, mood: pxStr(c.mood), window: [], played: [], artists: [], skips: {}, pending: 0, cands: {}, busy: false, first: true, noSonic: false, said: false }
    name = "your library"
    if kind = "song" then name = seed.title
    if kind = "artist" then name = seed.artist
    if kind = "mood" then name = pxStr(c.moodName)
    if kind = "favs" then name = "your favourites"
    if kind = "forgotten" then name = "songs you haven't heard lately"
    if c.label <> invalid and c.label <> "" then name = c.label
    r.name = name
    if seed <> invalid then r.window.push(seed)
    ' what was lined up after the current song gives way to the radio
    q = m.top.queue
    if c.keep <> true and q <> invalid and q.Count() > 0 and (m.top.state = "playing" or m.top.state = "paused" or m.top.state = "buffering")
        kept = []
        for i = 0 to m.top.index
            kept.push(q[i])
        end for
        m.top.queue = kept
        m.original = invalid
    end if
    m.radio = r
    m.top.radioName = name
    m.top.radioOn = true
    if kind <> "song" and kind <> "artist" then saveLastPlay("r", kind, pxStr(c.mood), name)
    reg = CreateObject("roRegistrySection", "hearth")
    reg.Write("radioVariety", v.toStr())
    reg.Flush()
    say("Radio: " + name)
    if m.top.section = ""
        withSection({ tag: "radioGo", path: "/library/sections", query: {}, label: "" })
    else
        radioRefill()
    end if
end sub

sub radioStop()
    if m.radio = invalid then return
    m.radio = invalid
    m.top.radioOn = false
    say("Radio off")
end sub

' something else loaded a queue: the radio is over (quietly)
sub radioDetach()
    if m.radio <> invalid and not m.radioLoading
        m.radio = invalid
        m.top.radioOn = false
    end if
end sub

sub radioVariety(delta as dynamic)
    if m.radio = invalid then return
    v = m.radio.variety + delta
    if v < 0 then v = 0
    if v > 4 then v = 4
    m.radio.variety = v
    m.radioVar = v
    reg = CreateObject("roRegistrySection", "hearth")
    reg.Write("radioVariety", v.toStr())
    reg.Flush()
    say("Radio: " + radioVarName(v))
end sub

sub radioNope()
    tr = m.top.track
    if tr = invalid or tr.id = invalid or tr.id = "" then return
    m.radioBans[tr.id] = CreateObject("roDateTime").AsSeconds()
    reg = CreateObject("roRegistrySection", "hearth")
    reg.Write("radioBans", FormatJson(m.radioBans))
    reg.Flush()
    say("Won't play " + tr.title + " again for a month")
    skip(1)
end sub

' called from playIndex before the song changes: learn from the song we're leaving
sub radioLeaving(nt as object)
    r = m.radio
    old = m.top.track
    if r = invalid or old = invalid or old.id = invalid or old.id = nt.id then return
    heard = (m.top.position >= 30)
    if m.top.duration > 0 and m.top.position >= m.top.duration - 3 then heard = true
    r.played.push(old.id)
    while r.played.Count() > 50
        r.played.shift()
    end while
    if heard
        r.window.push(old)
        while r.window.Count() > 4
            r.window.shift()
        end while
    else
        n = r.skips[old.artistId]
        if n = invalid then n = 0
        r.skips[old.artistId] = n + 1
    end if
end sub

sub radioCheck()
    r = m.radio
    q = m.top.queue
    if q = invalid then return
    if r = invalid
        ' the album or playlist is on its last song: line up more like it so the music never just stops
        if q.Count() > 0 and q.Count() - 1 - m.top.index <= 0 and m.top.repeat <> "one" and m.top.repeat <> "all" then keepPlaying()
        return
    end if
    if r.busy then return
    if q.Count() - 1 - m.top.index <= 3 then radioRefill()
end sub

' Carry on after the queue: a radio seeded from the song playing now (Plex sonic neighbours + that artist),
' added after what's already queued, shown in the queue sheet. Once per queue end.
sub keepPlaying()
    if m.radio <> invalid then return
    tr = m.top.track
    if tr = invalid or tr.id = invalid or tr.id = "" then return
    if m.keepTried = tr.id then return
    m.keepTried = tr.id
    label = "More like " + pxStr(tr.album)
    if pxStr(tr.album) = "" then label = "More like " + pxStr(tr.artist)
    radioStart({ kind: "song", keep: true, label: label })
end sub

sub radioFetch(path as string, query as object, src as string)
    m.radio.pending = m.radio.pending + 1
    pxApi(path, query, "onRadioTracks", src)
end sub

sub radioRefill()
    r = m.radio
    if r = invalid or r.busy then return
    r.busy = true
    r.cands = {}
    r.pending = 0
    r.noSonic = true
    v = r.variety
    dist = 0.12 + 0.08 * v
    seeds = []
    for i = r.window.Count() - 1 to 0 step -1
        if seeds.Count() < 3 then seeds.push(r.window[i])
    end for
    for each s in seeds
        radioFetch("/library/metadata/" + s.id + "/nearest", { limit: "40", maxDistance: Str(dist).Trim() }, "nearest")
    end for
    if seeds.Count() > 0 and seeds[0].artistId <> ""
        radioFetch("/library/metadata/" + seeds[0].artistId + "/allLeaves", { "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "30" }, "artist")
    end if
    sec = "/library/sections/" + m.top.section + "/all"
    if r.kind = "favs"
        radioFetch(sec, { type: "10", sort: "viewCount:desc", "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "80" }, "base")
    else if r.kind = "forgotten"
        radioFetch(sec, { type: "10", sort: "random", "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "100" }, "base")
    else if r.kind = "mood"
        radioFetch(sec, { type: "10", mood: r.mood, sort: "random", "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "80" }, "base")
    end if
    if v >= 2 or r.pending = 0
        radioFetch(sec, { type: "10", sort: "random", "X-Plex-Container-Start": "0", "X-Plex-Container-Size": "40" }, "random")
    end if
end sub

sub onRadioTracks(event as object)
    t = hTaskFrom(event)
    r = m.radio
    if r = invalid then return
    r.pending = r.pending - 1
    items = pxItems(t)
    n = items.Count()
    rank = 0
    for each md in items
        if md.type = "track"
            id = pxStr(md.ratingKey)
            c = r.cands[id]
            if c = invalid
                tr = pxTrack(md)
                tags = []
                for each kind in ["Genre", "Mood", "Style"]
                    if md[kind] <> invalid
                        for each g in md[kind]
                            tags.push(LCase(pxStr(g.tag)))
                        end for
                    end if
                end for
                tr.tags = tags
                c = { tr: tr, md: md, sonic: 0.0, score: 0.0 }
                r.cands[id] = c
            end if
            if t.tag = "nearest"
                r.noSonic = false
                s = 1.0 - rank / (n + 1.0)
                if s > c.sonic then c.sonic = s
            else if t.tag = "artist"
                if c.sonic < 0.45 then c.sonic = 0.45
            else if t.tag = "base"
                if c.sonic < 0.3 then c.sonic = 0.3
            end if
            rank = rank + 1
        end if
    end for
    if r.pending <= 0 then radioPick()
end sub

function radioWeights(v as integer) as object
    sonic = 0.6 - 0.06 * v
    aff = 0.25 - 0.05 * v
    fresh = 0.05 + 0.08 * v
    return { sonic: sonic, aff: aff, fresh: fresh, tag: 1.0 - sonic - aff - fresh }
end function

sub radioPick()
    r = m.radio
    r.busy = false
    now = CreateObject("roDateTime").AsSeconds()
    q = m.top.queue
    if q = invalid then q = []
    queued = {}
    for each t in q
        queued[t.id] = true
    end for
    played = {}
    for each id in r.played
        played[id] = true
    end for
    tagSet = {}
    for each t in r.window
        if t.tags <> invalid
            for each g in t.tags
                tagSet[g] = true
            end for
        end if
    end for
    w = radioWeights(r.variety)
    list = []
    for each id in r.cands
        c = r.cands[id]
        md = c.md
        ok = (c.tr.url <> "" and queued[id] = invalid and played[id] = invalid and m.radioBans[id] = invalid)
        if ok and r.skipWeek and md.lastViewedAt <> invalid and now - md.lastViewedAt < 7 * 86400 then ok = false
        if ok
            tagScore = 0.0
            if c.tr.tags.Count() > 0
                hit = 0
                for each g in c.tr.tags
                    if tagSet[g] <> invalid then hit = hit + 1
                end for
                tagScore = hit / c.tr.tags.Count()
            end if
            aff = 0.3
            if md.userRating <> invalid or md.viewCount <> invalid
                aff = 0.0
                if md.userRating <> invalid then aff = aff + 0.6 * md.userRating / 10
                if md.viewCount <> invalid
                    vc = md.viewCount
                    if vc > 20 then vc = 20
                    aff = aff + 0.4 * vc / 20
                end if
            end if
            fresh = 1.0
            if md.lastViewedAt <> invalid
                fresh = (now - md.lastViewedAt) / 86400 / 60
                if fresh > 1 then fresh = 1.0
                if fresh < 0 then fresh = 0.0
            end if
            pen = 0.0
            sk = r.skips[c.tr.artistId]
            if sk <> invalid then pen = sk * 0.12
            if pen > 0.36 then pen = 0.36
            c.score = w.sonic * c.sonic + w.tag * tagScore + w.aff * aff + w.fresh * fresh - pen
            list.push(c)
        end if
    end for
    if r.noSonic and r.kind = "song" and not r.said
        r.said = true
        say("No sonic matches (needs Plex Pass and sonic analysis). Using the artist and tags.")
    end if
    list.SortBy("score", "r")
    poolSize = 8 + 4 * r.variety
    pool = []
    for each c in list
        if pool.Count() < poolSize then pool.push(c)
    end for
    ' the last songs already lined up count towards the artist and album rules
    recent = []
    start = q.Count() - 4
    if start < 0 then start = 0
    for i = start to q.Count() - 1
        recent.push(q[i])
    end for
    albums = []
    start = q.Count() - 10
    if start < 0 then start = 0
    for i = start to q.Count() - 1
        albums.push(q[i].albumId)
    end for
    ahead = q.Count() - 1 - m.top.index
    if q.Count() = 0 then ahead = 0
    need = 10 - ahead
    if need < 1 then need = 1
    picks = []
    tries = 0
    while picks.Count() < need and pool.Count() > 0 and tries < 200
        tries = tries + 1
        total = 0.0
        for each c in pool
            total = total + c.score * c.score + 0.01
        end for
        x = Rnd(100000) / 100000.0 * total
        idx = 0
        for i = 0 to pool.Count() - 1
            x = x - (pool[i].score * pool[i].score + 0.01)
            if x <= 0
                idx = i
                exit for
            end if
        end for
        c = pool[idx]
        pool.Delete(idx)
        artistOk = true
        for each rt in recent
            if rt.artistId = c.tr.artistId then artistOk = false
        end for
        albumN = 0
        for each a in albums
            if a = c.tr.albumId then albumN = albumN + 1
        end for
        if artistOk and albumN < 2
            picks.push(c.tr)
            recent.push(c.tr)
            if recent.Count() > 4 then recent.shift()
            albums.push(c.tr.albumId)
        end if
    end while
    if picks.Count() = 0
        if q.Count() = 0 or ahead <= 0 then say("Radio couldn't find more songs to add.")
        return
    end if
    radioAppend(picks)
end sub

sub radioAppend(picks as object)
    r = m.radio
    q = m.top.queue
    if q = invalid or q.Count() = 0
        m.radioLoading = true
        load(picks, 0, false, "")
        m.radioLoading = false
    else
        out = []
        out.append(q)
        out.append(picks)
        m.top.queue = out
        if m.original <> invalid then m.original.append(picks)
        if m.wantNext = true or (r.first and (m.top.state = "none" or m.top.state = "stopped" or m.top.state = "ended"))
            m.wantNext = false
            playIndex(m.top.index + 1)
        end if
    end if
    r.first = false
end sub
