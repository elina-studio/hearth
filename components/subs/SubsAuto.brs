' See SubsAuto.xml. Logs start with [hearth-subs].

sub init()
    m.busy = false
    m.pollTimer = CreateObject("roSGNode", "Timer")
    m.pollTimer.duration = 2
    m.pollTimer.repeat = true
    m.pollTimer.observeField("fire", "onPoll")
end sub

sub go(unused = invalid as dynamic)
    it = m.top.item
    if m.busy or it = invalid or it.Id = invalid or it._media = invalid or it._media.count() = 0 then return
    if hCaptions() = "off" then
        finish(false, "captions off")
        return
    end if
    if it.Type <> "Movie" and it.Type <> "Episode" then return
    if hasEnglish(it) then
        finish(false, "already has English")
        return
    end if
    ' "<seconds>|busy" while a search runs (the details page starts one before Play; the player then
    ' just waits for it), "<seconds>|none" after finding nothing, so it doesn't search every visit
    reg = CreateObject("roRegistrySection", "hearthSubsAuto")
    now = CreateObject("roDateTime").AsSeconds()
    mark = reg.Read(it.Id).split("|")
    last = 0
    if mark.count() = 2 then last = Val(mark[0])
    m.item = it
    m.busy = true
    m.before = streamIds(it)
    m.resultKeys = {}
    if mark.count() = 2 and mark[1] = "busy" and now - last < 120
        print "[hearth-subs] auto: a search for this title is already running; waiting for it"
        m.tries = 40
        m.pollTimer.control = "start"
        return
    end if
    if mark.count() = 2 and mark[1] = "none" and now - last < 86400
        m.busy = false
        finish(false, "found nothing earlier today")
        return
    end if
    reg.Write(it.Id, now.toStr() + "|busy")
    reg.Flush()
    print "[hearth-subs] auto: "; hTitle(it); " has no English subtitle; searching Plex"
    hPlex("subSearch", { id: it.Id, language: "en", hi: "0" }, "onPlexFound")
end sub

function hasEnglish(it as object) as boolean
    for each s in streamList(it)
        lang = LCase(strOf(s.languageCode))
        if lang = "" then lang = LCase(strOf(s.language))
        if (Left(lang, 2) = "en" or lang = "eng") and not isTrue(s.forced) and hPlayTextSub(LCase(strOf(s.codec))) then return true
    end for
    return false
end function

sub onPlexFound(event as object)
    t = hTaskFrom(event)
    best = invalid
    bestScore = -1
    m.resultKeys = {}
    if t.ok and t.response.Items <> invalid
        for each s in t.response.Items
            m.resultKeys[strOf(s.key)] = true
        end for
        for each s in t.response.Items
            if not isTrue(s.forced) and s.key <> invalid
                ' an exact match for this file beats any download count
                sc = numOf(s.score)
                if isTrue(s.perfectMatch) then sc = sc + 100000000
                if not isTrue(s.hearingImpaired) then sc = sc + 1
                if sc > bestScore
                    best = s
                    bestScore = sc
                end if
            end if
        end for
    end if
    if best <> invalid
        print "[hearth-subs] auto: downloading "; strOf(best.title); " ("; numOf(best.score); " downloads)"
        hPlex("subDownload", { id: m.item.Id, key: best.key }, "onDownloaded")
        return
    end if
    ' nothing from Plex: ask Bazarr if it is set up
    if CreateObject("roRegistrySection", "hearth").Read("bazarrKey") = ""
        done(false, "Plex found no English subtitle")
        return
    end if
    print "[hearth-subs] auto: Plex found none; asking Bazarr"
    file = ""
    if m.item._media[0].Part[0].file <> invalid then file = m.item._media[0].Part[0].file
    t2 = CreateObject("roSGNode", "BazarrTask")
    t2.op = "search"
    t2.args = { file: file, movie: (m.item.Type = "Movie"), title: hTitle(m.item), year: m.item.ProductionYear, series: m.item.SeriesName, season: m.item.ParentIndexNumber, episode: m.item.IndexNumber }
    t2.observeField("done", "onBazarrFound")
    m.bzTask = t2
    t2.control = "RUN"
end sub

sub onBazarrFound()
    t = m.bzTask
    best = invalid
    bestScore = -1
    if t.ok and t.response.Items <> invalid
        for each s in t.response.Items
            lang = LCase(strOf(s.language))
            if Left(lang, 2) = "en" and not isTrue(s.forced)
                sc = numOf(s.score) * 10
                if not isTrue(s.hearing_impaired) then sc = sc + 1
                if sc > bestScore
                    best = s
                    bestScore = sc
                end if
            end if
        end for
    end if
    ' below 70% Bazarr's guesses are often for another release; leave those to the finder
    if best = invalid or numOf(best.score) < 70
        done(false, "no good English subtitle found")
        return
    end if
    print "[hearth-subs] auto: Bazarr download from "; strOf(best.provider); " ("; numOf(best.score); "%)"
    t2 = CreateObject("roSGNode", "BazarrTask")
    t2.op = "download"
    t2.args = { ids: t.response.ids, provider: best.provider, subtitle: best.subtitle, hi: best.hearing_impaired, forced: best.forced }
    t2.observeField("done", "onBazarrDownloaded")
    m.bzTask = t2
    t2.control = "RUN"
end sub

sub onBazarrDownloaded()
    if not m.bzTask.ok
        done(false, "Bazarr download failed")
        return
    end if
    hPlex("refresh", { id: m.item.Id }, "onDownloaded")
end sub

sub onDownloaded(event as object)
    t = hTaskFrom(event)
    m.tries = 30
    m.pollTimer.control = "start"
end sub

sub onPoll()
    m.tries = m.tries - 1
    if m.tries < 0
        m.pollTimer.control = "stop"
        done(false, "downloaded, but Plex hasn't listed it yet")
        return
    end if
    hPlex("item", { id: m.item.Id }, "onPolled")
end sub

sub onPolled(event as object)
    t = hTaskFrom(event)
    if not m.busy or not t.ok or t.response = invalid or t.response._media = invalid then return
    newest = invalid
    for each s in streamList(t.response)
        real = not m.resultKeys.doesExist(strOf(s.key))
        if real and not m.before.doesExist(strOf(s.id)) and Left(LCase(strOf(s.languageCode)), 2) = "en" then newest = s
    end for
    if newest = invalid then return
    m.pollTimer.control = "stop"
    part = t.response._media[0].Part[0]
    hPlex("setSubtitle", { part: part.id, stream: newest.id }, "onSaved")
    newest.selected = true
    print "[hearth-subs] auto: English subtitle ready (stream "; strOf(newest.id); ")"
    m.busy = false
    reg = CreateObject("roRegistrySection", "hearthSubsAuto")
    reg.Delete(m.item.Id)
    reg.Flush()
    m.top.result = { ok: true, stream: newest, item: t.response }
end sub

sub onSaved(event as object)
    hTaskFrom(event)
end sub

sub done(ok as boolean, why as string)
    m.busy = false
    reg = CreateObject("roRegistrySection", "hearthSubsAuto")
    if ok then reg.Delete(m.item.Id) else reg.Write(m.item.Id, CreateObject("roDateTime").AsSeconds().toStr() + "|none")
    reg.Flush()
    finish(ok, why)
end sub

sub finish(ok as boolean, why as string)
    print "[hearth-subs] auto: "; why
    m.top.result = { ok: ok, why: why }
end sub

function streamList(it as object) as object
    out = []
    if it._media = invalid or it._media.count() = 0 then return out
    part = it._media[0].Part[0]
    if part = invalid or part.Stream = invalid then return out
    for each s in part.Stream
        if numOf(s.streamType) = 3 then out.push(s)
    end for
    return out
end function

function streamIds(it as object) as object
    ids = {}
    for each s in streamList(it)
        ids[strOf(s.id)] = true
    end for
    return ids
end function

function isTrue(v as dynamic) as boolean
    if GetInterface(v, "ifBoolean") <> invalid then return v
    if GetInterface(v, "ifString") <> invalid
        s = LCase(v)
        return s = "1" or s = "true" or s = "yes"
    end if
    if GetInterface(v, "ifInt") <> invalid or GetInterface(v, "ifLongInt") <> invalid or GetInterface(v, "ifFloat") <> invalid or GetInterface(v, "ifDouble") <> invalid then return v <> 0
    return false
end function

function numOf(v as dynamic) as integer
    if GetInterface(v, "ifInt") <> invalid or GetInterface(v, "ifLongInt") <> invalid or GetInterface(v, "ifFloat") <> invalid or GetInterface(v, "ifDouble") <> invalid then return Int(v)
    if GetInterface(v, "ifString") <> invalid
        if v = "" then return -1
        return Int(Val(v))
    end if
    return -1
end function

function strOf(v as dynamic) as string
    if GetInterface(v, "ifString") <> invalid then return v
    if GetInterface(v, "ifToStr") <> invalid and GetInterface(v, "ifAssociativeArray") = invalid and GetInterface(v, "ifArray") = invalid then return v.toStr()
    return ""
end function
