' Subtitle finder (see SubsFinder.xml). Logs start with [hearth-subs] (nc <TV IP> 8085).

sub init()
    m.top.visible = false
    m.c = hColors()
    m.top.findNode("heading").font = hFont("fell", 40)
    m.tab0 = m.top.findNode("tab0")
    m.tab1 = m.top.findNode("tab1")
    m.tab0.font = hFont("caps", 24)
    m.tab1.font = hFont("caps", 24)
    m.tabMark = m.top.findNode("tabMark")
    m.chipGroup = m.top.findNode("chips")
    m.count = m.top.findNode("count")
    m.count.font = hFont("caps", 22)
    m.list = m.top.findNode("list")
    m.note = m.top.findNode("note")
    m.note.font = hFont("regular", 23)
    m.hint = m.top.findNode("hint")
    m.hintKey = ""
    m.poll = m.top.findNode("poll")
    m.poll.observeField("fire", "onPoll")

    m.langs = ["en", "es", "fr", "de", "it", "pt", "nl", "sv", "da", "no", "fi", "pl", "ru", "ja", "ko", "zh"]
    m.langNames = { en: "English", es: "Spanish", fr: "French", de: "German", it: "Italian", pt: "Portuguese", nl: "Dutch", sv: "Swedish", da: "Danish", no: "Norwegian", fi: "Finnish", pl: "Polish", ru: "Russian", ja: "Japanese", ko: "Korean", zh: "Chinese" }
    m.hiModes = ["any", "no", "only"]
    m.srcModes = ["both", "plex", "bazarr"]
    reg = CreateObject("roRegistrySection", "hearth")
    m.lang = reg.Read("subsLang")
    if m.lang = "" then m.lang = "en"
    m.hi = "any"
    m.src = "both"

    ' chips: language, hearing impaired, source
    m.chips = []
    xs = [0, 214, 520]
    ws = [200, 292, 192]
    for i = 0 to 2
        g = m.chipGroup.createChild("Group")
        g.translation = [xs[i], 0]
        bg = g.createChild("Poster")
        bg.uri = "pkg:/images/w/chip.9.png"
        bg.width = ws[i]
        bg.height = 52
        lb = g.createChild("Label")
        lb.width = ws[i]
        lb.height = 52
        lb.horizAlign = "center"
        lb.vertAlign = "center"
        lb.font = hFont("bold", 22)
        m.chips.push({ bg: bg, label: lb })
    end for

    ' six reusable rows
    m.rowH = 104
    m.pitch = 116
    m.visibleRows = 5
    m.rowNodes = []
    for i = 0 to 5
        g = m.list.createChild("Group")
        g.translation = [0, i * m.pitch]
        ring = g.createChild("Poster")
        ring.uri = "pkg:/images/w/focus-ring.9.png"
        ring.translation = [-20, -20]
        ring.width = 752
        ring.height = m.rowH + 40
        bg = g.createChild("Poster")
        bg.uri = "pkg:/images/w/panel.9.png"
        bg.width = 712
        bg.height = m.rowH
        bg.blendColor = "0x1E2716FF"
        tick = g.createChild("Poster")
        tick.uri = "pkg:/images/icons/home-check.png"
        tick.translation = [18, 34]
        tick.width = 36
        tick.height = 36
        tick.blendColor = "0xE0B34AFF"
        title = g.createChild("Label")
        title.translation = [22, 16]
        title.width = 560
        title.maxLines = 1
        title.font = hFont("bold", 24)
        title.color = m.c.ink
        score = g.createChild("Label")
        score.translation = [592, 14]
        score.width = 98
        score.horizAlign = "right"
        score.font = hFont("bold", 28)
        score.color = m.c.gold
        detail = g.createChild("Label")
        detail.translation = [22, 60]
        detail.width = 170
        detail.maxLines = 1
        detail.font = hFont("regular", 21)
        detail.color = m.c.muted
        bar = hBraid(g, 120, 66)
        bar.translation = [194, 66]
        tags = g.createChild("Label")
        tags.translation = [334, 60]
        tags.width = 360
        tags.maxLines = 1
        tags.font = hFont("caps", 18)
        tags.color = m.c.muted
        m.rowNodes.push({ g: g, ring: ring, bg: bg, tick: tick, title: title, score: score, detail: detail, bar: bar, tags: tags })
    end for
end sub

' ---------------------------------------------------------------- open / close

sub open(unused = invalid as dynamic)
    it = m.top.item
    if it = invalid then return
    m.item = it
    m.tab = 0
    m.zone = "list"
    m.sel = 0
    m.first = 0
    m.results = []
    m.plexDone = false
    m.bzDone = false
    m.bzRaw = invalid
    m.bzIds = invalid
    m.bzError = ""
    m.busy = false
    m.bzAsked = false
    m.plexRaw = invalid
    m.searched = false
    m.message = ""
    m.seq = 0
    m.top.visible = true
    m.top.setFocus(true)
    loadTracks()
    ' no subtitles yet: go straight to Find more
    if m.tracks.count() <= 1 then switchTab(1) else paint()
end sub

sub close()
    m.poll.control = "stop"
    m.top.visible = false
    m.top.closed = true
end sub

' ---------------------------------------------------------------- tab 0: what is on the title

sub loadTracks()
    m.tracks = [{ kind: "off", name: "Off", detail: "No subtitles", on: true }]
    if m.item._media = invalid or m.item._media.count() = 0 then return
    part = m.item._media[0].Part[0]
    if part = invalid or part.Stream = invalid then return
    for each s in part.Stream
        if numOf(s.streamType) = 3
            name = strOf(s.displayTitle)
            if name = "" then name = strOf(s.language)
            if name = "" then name = "Unknown"
            where = "In the file"
            if s.key <> invalid then where = "Subtitle file"
            if strOf(s.codec) <> "" then where = where + " · " + LCase(strOf(s.codec))
            if isTrue(s.forced) then where = where + " · forced"
            row = { kind: "track", stream: s, name: name, detail: where, on: isTrue(s.selected) }
            st = strOf(s.title)
            if st <> "" and Instr(1, name, st) = 0 then row.name = name + " · " + st
            if row.on then m.tracks[0].on = false
            m.tracks.push(row)
        end if
    end for
end sub

' ---------------------------------------------------------------- tab 1: search

sub search()
    m.seq = m.seq + 1
    m.results = []
    m.sel = 0
    m.first = 0
    m.searched = true
    m.plexRaw = invalid
    m.plexDone = (m.src = "bazarr")
    m.bzDone = (m.src = "plex")
    if m.src <> "bazarr"
        hiArg = "0"
        if m.hi = "only" then hiArg = "2"
        if m.hi = "no" then hiArg = "3"
        hPlex("subSearch", { id: m.item.Id, language: m.lang, hi: hiArg }, "onPlexFound", m.seq.toStr())
    end if
    if m.src <> "plex"
        if m.bzRaw <> invalid
            m.bzDone = true
        else if not m.bzAsked
            m.bzAsked = true
            bazarr("search", searchArgs(), "onBazarrFound")
        end if
    end if
    merge()
end sub

function searchArgs() as object
    it = m.item
    file = ""
    if it._media <> invalid and it._media.count() > 0 and it._media[0].Part[0].file <> invalid then file = it._media[0].Part[0].file
    return { file: file, movie: (it.Type = "Movie"), title: hTitle(it), year: it.ProductionYear, series: it.SeriesName, season: it.ParentIndexNumber, episode: it.IndexNumber }
end function

function bazarr(op as string, args as object, cb as string) as object
    t = CreateObject("roSGNode", "BazarrTask")
    t.op = op
    t.args = args
    t.observeField("done", cb)
    if m.hTasks = invalid then m.hTasks = {}
    key = "b" + Rnd(1000000).toStr()
    m.hTasks[key] = t
    t.key = key
    t.control = "RUN"
    return t
end function

sub onPlexFound(event as object)
    t = hTaskFrom(event)
    if t.tag <> m.seq.toStr() then return
    m.plexDone = true
    m.plexRaw = []
    if t.ok and t.response.Items <> invalid then m.plexRaw = t.response.Items
    m.resultKeys = {}
    for each r in m.plexRaw
        m.resultKeys[strOf(r.key)] = true
    end for
    if not t.ok then print "[hearth-subs] Plex search failed (status "; t.status; ")"
    merge()
end sub

sub onBazarrFound(event as object)
    t = hTaskFrom(event)
    m.bzAsked = false
    m.bzDone = true
    m.bzError = t.error
    if t.ok
        m.bzRaw = t.response.Items
        m.bzIds = t.response.ids
        print "[hearth-subs] Bazarr found "; m.bzRaw.count(); " subtitles (all languages)"
    else
        print "[hearth-subs] Bazarr: "; t.error; " (status "; t.status; ")"
    end if
    merge()
end sub

' Bazarr's strongest matches (90+) first, then Plex's in Plex's own order, then the rest of Bazarr's.
sub merge()
    plex = []
    if m.src <> "bazarr" and m.plexRaw <> invalid
        for each s in m.plexRaw
            name = strOf(s.title)
            if name = "" then name = strOf(s.displayTitle)
            if name = "" then name = "Subtitle"
            prov = strOf(s.providerTitle)
            if prov = "" then prov = "OpenSubtitles"
            ' Plex's score is the download count on OpenSubtitles, like the Plex app shows
            downloads = numOf(s.score)
            tags = []
            if downloads >= 0 then tags.push("downloads")
            if isTrue(s.hearingImpaired) then tags.push("HI")
            if isTrue(s.forced) then tags.push("forced")
            exact = isTrue(s.perfectMatch)
            if exact then tags.unshift("exact match")
            if isTrue(s.downloaded) then tags.push("already here")
            sortKey = downloads
            if exact then sortKey = sortKey + 1000000000
            plex.push({ from: "plex", key: s.key, name: name, provider: "Plex · " + prov, score: downloads, scoreText: fmtCount(downloads), sortKey: sortKey, tags: tags })
        end for
    end if
    bzTop = []
    bzRest = []
    if m.src <> "plex" and m.bzRaw <> invalid
        for each s in m.bzRaw
            lang = LCase(strOf(s.language))
            hi = isTrue(s.hearing_impaired)
            keep = (Left(lang, 2) = m.lang)
            if m.hi = "no" and hi then keep = false
            if m.hi = "only" and not hi then keep = false
            if keep
                name = ""
                if type(s.release_info) = "roArray" and s.release_info.count() > 0 then name = strOf(s.release_info[0])
                if name = "" then name = "Subtitle from " + strOf(s.provider)
                tags = ["match"]
                if hi then tags.push("HI")
                if isTrue(s.forced) then tags.push("forced")
                if type(s.matches) = "roArray"
                    for each mt in s.matches
                        if strOf(mt) = "hash" then tags.unshift("hash match")
                    end for
                    if tags.count() < 3 and s.matches.count() > 0 then tags.push(s.matches.count().toStr() + " matches")
                end if
                score = numOf(s.score)
                if score < 0 then score = 0
                r = { from: "bazarr", provider: "Bazarr · " + strOf(s.provider), subtitle: s.subtitle, hi: s.hearing_impaired, forced: s.forced, name: name, score: score, scoreText: score.toStr() + "%", bar: score, tags: tags }
                if score >= 90 then bzTop.push(r) else bzRest.push(r)
            end if
        end for
        bzTop.sortBy("score", "r")
        bzRest.sortBy("score", "r")
    end if
    ' most downloaded first (exact matches for this file above all); the braid shows downloads against the top one
    plex.sortBy("sortKey", "r")
    top = 0
    for each r in plex
        if r.score > top then top = r.score
    end for
    for each r in plex
        r.bar = 0
        if top > 0 and r.score > 0 then r.bar = Int(r.score * 100 / top)
        if r.score < 0 then r.scoreText = ""
    end for
    m.results = []
    m.results.append(bzTop)
    m.results.append(plex)
    m.results.append(bzRest)
    if m.sel >= m.results.count() then m.sel = 0
    paint()
end sub

' ---------------------------------------------------------------- download

sub pick(r as object)
    if m.busy then return
    m.busy = true
    m.busyRow = r
    r.state = "Downloading…"
    m.before = streamIds(m.item)
    print "[hearth-subs] downloading "; r.name; " from "; r.from
    if r.from = "plex"
        hPlex("subDownload", { id: m.item.Id, key: r.key }, "onPlexDownloaded")
    else
        bazarr("download", { ids: m.bzIds, provider: r.provider, subtitle: r.subtitle, hi: r.hi, forced: r.forced }, "onBazarrDownloaded")
    end if
    paint()
end sub

sub onPlexDownloaded(event as object)
    t = hTaskFrom(event)
    if not t.ok
        failed("Plex couldn't download that one (status " + t.status.toStr() + "). Try another.")
        return
    end if
    startPolling(30)
end sub

sub onBazarrDownloaded(event as object)
    t = hTaskFrom(event)
    if not t.ok
        failed("Bazarr couldn't download that one. Try another.")
        return
    end if
    ' Bazarr saved the file next to the video; ask Plex to look again
    hPlex("refresh", { id: m.item.Id }, "onRefreshed")
end sub

sub onRefreshed(event as object)
    hTaskFrom(event)
    startPolling(20)
end sub

sub startPolling(tries as integer)
    m.tries = tries
    m.busyRow.state = "Adding to Plex…"
    paint()
    m.poll.control = "start"
end sub

sub onPoll()
    m.tries = m.tries - 1
    if m.tries < 0
        m.poll.control = "stop"
        failed("Downloaded, but Plex hasn't listed it yet. Close this and open it again in a minute.")
        return
    end if
    hPlex("item", { id: m.item.Id }, "onPolled")
end sub

sub onPolled(event as object)
    t = hTaskFrom(event)
    if not m.busy or not t.ok or t.response = invalid or t.response._media = invalid then return
    newest = invalid
    for each s in streamList(t.response)
        isNew = not m.before.doesExist(strOf(s.id))
        lang = LCase(strOf(s.languageCode))
        print "[hearth-subs] poll: stream "; strOf(s.id); " "; lang; " "; strOf(s.codec); " key "; strOf(s.key); " transient "; strOf(s.transient); " new "; isNew; " "; strOf(s.displayTitle)
        ' only a new subtitle in the language that was searched counts
        ' search results can show up on the item as temporary ("transient") streams; only a real file counts
        if isTrue(s.transient) or strOf(s.transient) = "download" then isNew = false
        if isNew and m.resultKeys <> invalid and m.resultKeys.doesExist(strOf(s.key)) then isNew = false
        if isNew and (Left(lang, 2) = m.lang or lang = "") then newest = s
    end for
    if newest = invalid then return
    m.poll.control = "stop"
    m.item = t.response
    print "[hearth-subs] Plex lists the new subtitle as stream "; newest.id
    ' turn it on everywhere (Plex remembers the pick for the title) and in Hearth's CC setting
    part = m.item._media[0].Part[0]
    hPlex("setSubtitle", { part: part.id, stream: newest.id }, "onSaved")
    reg = CreateObject("roRegistrySection", "hearth")
    reg.Write("captions", "on")
    reg.Flush()
    newest.selected = true
    m.busy = false
    m.busyRow.state = "Turned on"
    m.lastNew = newest
    paint()
    m.top.result = { action: "downloaded", stream: newest }
end sub

sub onSaved(event as object)
    t = hTaskFrom(event)
    ' refresh the first tab so the new one shows as picked
    hPlex("item", { id: m.item.Id }, "onReloaded")
end sub

sub onReloaded(event as object)
    t = hTaskFrom(event)
    if t.ok and t.response <> invalid and t.response._media <> invalid then m.item = t.response
    loadTracks()
    ' Plex sometimes lists a fresh download a moment later; keep showing the one just turned on
    if m.lastNew <> invalid
        found = false
        for each r in m.tracks
            if r.stream <> invalid and strOf(r.stream.id) = strOf(m.lastNew.id) then found = true
        end for
        if not found
            print "[hearth-subs] Plex's item doesn't list stream "; strOf(m.lastNew.id); " yet; keeping it in the list"
            for each r in m.tracks
                r.on = false
            end for
            nm = strOf(m.lastNew.displayTitle)
            if nm = "" then nm = "Downloaded subtitle"
            m.tracks.push({ kind: "track", stream: m.lastNew, name: nm, detail: "Just downloaded", on: true })
        end if
    end if
    paint()
end sub

sub failed(msg as string)
    m.busy = false
    if m.busyRow <> invalid then m.busyRow.state = ""
    m.message = msg
    print "[hearth-subs] "; msg
    paint()
end sub

function streamList(it as object) as object
    out = []
    if it._media = invalid or it._media.count() = 0 then return out
    part = it._media[0].Part[0]
    if part = invalid or part.Stream = invalid then return out
    for each s in part.Stream
        if s.streamType = 3 then out.push(s)
    end for
    return out
end function

function streamIds(it as object) as object
    ids = {}
    for each s in streamList(it)
        ids[s.id.toStr()] = true
    end for
    return ids
end function

' ---------------------------------------------------------------- choose a track (tab 0)

sub choose(row as object)
    if m.item._media = invalid then return
    part = m.item._media[0].Part[0]
    reg = CreateObject("roRegistrySection", "hearth")
    if row.kind = "off"
        hPlex("setSubtitle", { part: part.id, stream: "0" }, "onChosen")
        reg.Write("captions", "off")
        m.top.result = { action: "off" }
    else
        hPlex("setSubtitle", { part: part.id, stream: row.stream.id }, "onChosen")
        reg.Write("captions", "on")
        m.top.result = { action: "select", stream: row.stream }
    end if
    reg.Flush()
    for each t in m.tracks
        t.on = false
    end for
    row.on = true
    paint()
end sub

sub onChosen(event as object)
    t = hTaskFrom(event)
    if not t.ok then print "[hearth-subs] couldn't save the pick in Plex (status "; t.status; ")"
end sub

' ---------------------------------------------------------------- drawing

function rows() as object
    if m.tab = 0 then return m.tracks
    return m.results
end function

sub switchTab(t as integer)
    m.tab = t
    m.sel = 0
    m.first = 0
    m.message = ""
    if t = 1 and not m.searched then search()
    paint()
end sub

sub paint()
    gold = m.c.gold
    if m.tab = 0 then m.tab0.color = "0xFFE7A0FF" else m.tab0.color = m.c.muted
    if m.tab = 1 then m.tab1.color = "0xFFE7A0FF" else m.tab1.color = m.c.muted
    kind = "MOVIE"
    if m.item.Type = "Episode" then kind = "EPISODE"
    m.tab0.text = "ON THIS " + kind + " · " + (m.tracks.count() - 1).toStr()
    if m.tab = 0
        m.tabMark.translation = [1084, 210]
        m.tabMark.width = 300
    else
        m.tabMark.translation = [1430, 210]
        m.tabMark.width = 150
    end if
    if m.zone = "tabs"
        m.tabMark.color = "0xFFE7A0FF"
    else
        m.tabMark.color = gold
    end if

    ' chips only on Find more
    m.chipGroup.visible = (m.tab = 1)
    langName = m.langNames[m.lang]
    if langName = invalid then langName = m.lang
    hiText = { any: "Hearing impaired: any", no: "Hearing impaired: no", only: "Hearing impaired only" }
    srcText = { both: "Plex + Bazarr", plex: "Plex only", bazarr: "Bazarr only" }
    texts = [langName, hiText[m.hi], srcText[m.src]]
    for i = 0 to 2
        ch = m.chips[i]
        ch.label.text = texts[i]
        focused = (m.zone = "chips" and m.chip = i)
        if focused
            ch.bg.blendColor = gold
            ch.label.color = m.c.goldInk
        else
            ch.bg.blendColor = "0x1F2818FF"
            ch.label.color = m.c.ink
        end if
    end for

    list = rows()
    listTop = 360
    if m.tab = 0 then listTop = 250
    m.list.translation = [1084, listTop]
    m.count.visible = (m.tab = 1)
    if m.tab = 1
        if not m.plexDone or not m.bzDone
            waiting = []
            if not m.plexDone then waiting.push("Plex")
            if not m.bzDone then waiting.push("Bazarr")
            m.count.text = "SEARCHING " + UCase(waiting.join(" AND ")) + "… " + list.count().toStr() + " SO FAR"
        else
            m.count.text = list.count().toStr() + " FOUND · BEST MATCH FIRST"
        end if
    end if

    ' notes: errors, Bazarr setup, nothing found. With a note, one row fewer so it never runs into the hints.
    note = ""
    if m.message <> invalid and m.message <> "" then note = m.message
    if m.tab = 1 and note = "" and m.bzDone and m.src <> "plex" and m.bzError <> ""
        note = bazarrNote(m.bzError)
    end if
    if m.tab = 1 and note = "" and list.count() = 0 and m.plexDone and m.bzDone then note = "Nothing found in " + langName + ". Try another language or source."
    m.visibleRows = 5
    if note <> "" then m.visibleRows = 4
    if m.tab = 0 and m.visibleRows = 5 then m.visibleRows = 6

    ' keep the focused row in view
    if m.sel < m.first then m.first = m.sel
    if m.sel > m.first + m.visibleRows - 1 then m.first = m.sel - m.visibleRows + 1
    for i = 0 to m.rowNodes.count() - 1
        node = m.rowNodes[i]
        idx = m.first + i
        if idx >= list.count() or i >= m.visibleRows
            node.g.visible = false
        else
            node.g.visible = true
            r = list[idx]
            focused = (m.zone = "list" and idx = m.sel)
            node.ring.visible = focused
            node.ring.blendColor = m.c.rope
            node.bg.visible = focused or (m.tab = 0 and isTrue(r.on))
            if m.tab = 0
                node.tick.visible = isTrue(r.on)
                node.title.translation = [72, 16]
                node.title.text = r.name
                node.detail.translation = [72, 60]
                node.detail.width = 600
                node.detail.text = r.detail
                node.score.text = ""
                node.tags.text = ""
                node.bar.visible = false
            else
                node.tick.visible = false
                node.title.translation = [22, 16]
                node.title.text = r.name
                node.detail.translation = [22, 60]
                node.detail.width = 170
                node.detail.text = r.provider
                tagText = UCase(r.tags.join("  ·  "))
                if r.state <> invalid and r.state <> "" then tagText = UCase(r.state)
                node.tags.text = tagText
                if r.state <> invalid and r.state <> "" then node.tags.color = gold else node.tags.color = m.c.muted
                if strOf(r.scoreText) <> ""
                    node.score.text = r.scoreText
                    hBraidSet(node.bar, r.bar)
                else
                    node.score.text = ""
                    node.bar.visible = false
                end if
            end if
        end if
    end for

    m.note.text = note
    shown = list.count()
    if shown > m.visibleRows then shown = m.visibleRows
    m.note.translation = [1084, listTop + shown * m.pitch + 8]
    m.note.visible = (note <> "")

    ' key hints with icons (the fonts have no arrow glyphs)
    if m.tab = 0
        hints([["ok", "Turn on"], ["right", "Find more"], ["back", "Close"]])
    else if m.zone = "chips"
        hints([["ok", "Change"], ["lr", "Filters"], ["down", "Results"]])
    else
        hints([["ok", "Download and turn on"], ["left", "Back to the tracks"], ["back", "Close"]])
    end if
end sub

function bazarrNote(err as string) as string
    if err = "nokey"
        ip = "<TV IP>"
        addrs = CreateObject("roDeviceInfo").GetIPAddrs()
        for each k in addrs
            ip = addrs[k]
        end for
        q = Chr(34)
        return "Bazarr isn't set up yet. With Hearth open, run this on your Mac:" + Chr(10) + "curl -X POST -G --data-urlencode " + q + "bazarrKey=YOUR-KEY" + q + " http://" + ip + ":8060/input"
    else if err = "badkey"
        return "Bazarr said the key is wrong. Send it again with the curl command."
    else if err = "notfound"
        return "Bazarr doesn't have this title. It only covers shows in Sonarr and movies in Radarr."
    else if err = "noepisode"
        return "Bazarr has the show but not this episode's file yet. Sonarr may need a rescan."
    else if err = "unreachable"
        return "Couldn't reach Bazarr. Is it running?"
    end if
    return "Bazarr's search failed. Plex results are still here."
end function

' ---------------------------------------------------------------- keys

function onKeyEvent(key as string, press as boolean) as boolean
    if not press or not m.top.visible then return false
    if key = "back" or key = "options"
        close()
        return true
    end if
    list = rows()
    if m.zone = "tabs"
        if key = "left" and m.tab = 1 then switchTab(0)
        if key = "right" and m.tab = 0 then switchTab(1)
        if key = "down"
            if m.tab = 1
                m.zone = "chips"
                m.chip = 0
            else if list.count() > 0
                m.zone = "list"
            end if
        end if
    else if m.zone = "chips"
        if key = "left" and m.chip > 0 then m.chip = m.chip - 1
        if key = "right" and m.chip < 2 then m.chip = m.chip + 1
        if key = "up" then m.zone = "tabs"
        if key = "down" and list.count() > 0
            m.zone = "list"
            m.sel = 0
        end if
        if key = "OK" then cycleChip()
    else
        if key = "up"
            if m.sel > 0
                m.sel = m.sel - 1
            else if m.tab = 1
                m.zone = "chips"
                m.chip = 0
            else
                m.zone = "tabs"
            end if
        end if
        if key = "down" and m.sel < list.count() - 1 then m.sel = m.sel + 1
        if key = "left" and m.tab = 1 then switchTab(0)
        if key = "right" and m.tab = 0 then switchTab(1)
        if key = "OK" and m.sel < list.count()
            if m.tab = 0 then choose(list[m.sel]) else pick(list[m.sel])
        end if
    end if
    paint()
    return true
end function

sub cycleChip()
    if m.busy then return
    if m.chip = 0
        i = 0
        for k = 0 to m.langs.count() - 1
            if m.langs[k] = m.lang then i = k
        end for
        m.lang = m.langs[(i + 1) mod m.langs.count()]
        reg = CreateObject("roRegistrySection", "hearth")
        reg.Write("subsLang", m.lang)
        reg.Flush()
    else if m.chip = 1
        m.hi = nextOf(m.hiModes, m.hi)
    else
        m.src = nextOf(m.srcModes, m.src)
    end if
    m.message = ""
    search()
end sub

function nextOf(list as object, v as string) as string
    for k = 0 to list.count() - 1
        if list[k] = v then return list[(k + 1) mod list.count()]
    end for
    return list[0]
end function

' Type-safe checks: Plex and Bazarr send flags as true, 1, "1" or "True" depending on the field
' and server version, and BrightScript can't compare a string with a boolean or a number.
function isTrue(v as dynamic) as boolean
    t = type(v)
    if t = "Boolean" or t = "roBoolean" then return v
    if t = "Integer" or t = "roInteger" or t = "LongInteger" or t = "Float" or t = "Double" then return v <> 0
    if t = "String" or t = "roString"
        s = LCase(v)
        return s = "1" or s = "true" or s = "yes"
    end if
    return false
end function

function numOf(v as dynamic) as integer
    t = type(v)
    if t = "Integer" or t = "roInteger" or t = "LongInteger" or t = "Float" or t = "Double" or t = "roFloat" then return Int(v)
    if t = "String" or t = "roString" then return Int(Val(v))
    return -1
end function

function sameNum(a as dynamic, b as dynamic) as boolean
    x = numOf(a)
    return x >= 0 and x = numOf(b)
end function

function strOf(v as dynamic) as string
    t = type(v)
    if t = "String" or t = "roString" then return v
    if v = invalid then return ""
    if t = "Integer" or t = "roInteger" or t = "LongInteger" or t = "Float" or t = "Double" or t = "Boolean" or t = "roBoolean" then return v.toStr()
    return ""
end function

' One row of key hints: [icon, words] pairs. icon: ok, left, right, lr, down, back.
sub hints(list as object)
    k = ""
    for each h in list
        k = k + h[0] + h[1] + "|"
    end for
    if k = m.hintKey then return
    m.hintKey = k
    m.hint.removeChildrenIndex(m.hint.getChildCount(), 0)
    icons = { left: "home-left", right: "home-right", down: "home-down", back: "icon-back", lr: "icon-lr" }
    for each h in list
        if h[0] = "ok"
            badge = m.hint.createChild("Group")
            bg = badge.createChild("Poster")
            bg.uri = "pkg:/images/w/chip.9.png"
            bg.width = 46
            bg.height = 30
            bg.blendColor = m.c.muted
            lb = badge.createChild("Label")
            lb.width = 46
            lb.height = 30
            lb.horizAlign = "center"
            lb.vertAlign = "center"
            lb.font = hFont("bold", 18)
            lb.color = m.c.goldInk
            lb.text = "OK"
        else
            ic = m.hint.createChild("Poster")
            ic.uri = "pkg:/images/icons/" + icons[h[0]] + ".png"
            ic.width = 30
            ic.height = 30
            ic.blendColor = m.c.gold
        end if
        t = m.hint.createChild("Label")
        t.font = hFont("regular", 20)
        t.color = m.c.muted
        t.height = 30
        t.vertAlign = "center"
        t.text = h[1]
    end for
end sub

' 2895 -> "2,895"
function fmtCount(n as integer) as string
    if n < 0 then return ""
    s = n.toStr()
    out = ""
    while Len(s) > 3
        out = "," + Right(s, 3) + out
        s = Left(s, Len(s) - 3)
    end while
    return s + out
end function
