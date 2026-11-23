' Player UI for PlayerScreen: the pause screen (PauseOverlay), side sheets (subtitles & audio, look & timing,
' episodes, info & quality, sleep & watched), the chapters strip, Hearth-drawn subtitles (SubLayer) and the
' sleep timer. Included by PlayerScreen.xml; PlayerScreen.brs calls the ui* hooks.

sub uiInit()
    m.ov = m.top.findNode("overlay")
    m.ov.observeField("action", "onOverlayAction")
    m.sheet = m.top.findNode("sheet")
    m.sheet.visible = false
    m.sheet.observeField("action", "onSheetAction")
    m.chapters = m.top.findNode("chapters")
    m.chapters.observeField("action", "onChapterAction")
    m.subs = m.top.findNode("subs")
    m.subDelay = 0.0
    m.subMode = "none"
    m.subStream = invalid
    m.sleepAt = invalid
    m.sleepMode = "off"
    m.forceQuality = invalid
    m.reopenOverlay = false
    m.subs.style = subStyle()
end sub

' ---------- per video ----------
sub uiOnItem(it as object)
    server = m.global.plexServer
    token = m.global.plexServerToken
    info = { title: hNameOr(it.Name), isEpisode: (it.Type = "Episode") }
    if it.Type = "Episode"
        info.kicker = hTitle(it) + " · S" + hNum(it.ParentIndexNumber) + " E" + hNum(it.IndexNumber)
    else
        k = ""
        if it.ProductionYear <> invalid then k = it.ProductionYear.toStr()
        if it.OfficialRating <> invalid then k = k + " · " + it.OfficialRating
        info.kicker = k
    end if
    ' chapters
    ch = []
    if it._chapters <> invalid
        for each c in it._chapters
            th = ""
            if c.thumb <> invalid then th = server + c.thumb + "?X-Plex-Token=" + token
            st = 0
            if c.startTimeOffset <> invalid then st = c.startTimeOffset / 1000
            name = "Chapter " + (ch.count() + 1).toStr()
            if c.tag <> invalid and c.tag <> "" then name = c.tag
            ch.push({ title: name, start: st, thumb: th })
        end for
    end if
    info.hasChapters = ch.count() > 1
    m.ov.info = info
    m.ov.duration = m.durationMs / 1000
    m.ov.canNext = false
    m.chapters.duration = m.durationMs / 1000
    m.chapters.chapters = ch
    ' scrub thumbnails (Plex "video preview thumbnails")
    bif = ""
    if m.part.indexes <> invalid and m.part.id <> invalid then bif = server + "/library/parts/" + m.part.id.toStr() + "/indexes/sd?X-Plex-Token=" + token
    if bif <> m.ov.bifUrl then m.ov.bifUrl = bif
end sub

function hNameOr(v as dynamic) as string
    if v = invalid then return ""
    return v
end function

sub uiOnState(s as string)
    m.ov.playing = (s = "playing")
end sub

sub uiOnPosition()
    p = position()
    m.ov.position = p
    if m.subMode = "hearth" then m.subs.time = p
end sub

' A new video in the same player (autoplay, an episode from the list, a reload): forget per-video state.
sub uiReset(keepSubs as boolean)
    m.ov.callFunc("close", invalid)
    m.sheet.visible = false
    m.chapters.visible = false
    if not keepSubs
        m.subDelay = 0.0
        m.subs.delay = 0
    end if
    m.subs.cues = []
    m.subMode = "none"
end sub

' ---------- keys while no panel has focus ----------
function uiKey(key as string) as boolean
    if not m.ready then return false
    if m.upnext.visible then return false
    st = m.video.state
    if key = "OK" or key = "play"
        if st = "paused"
            m.video.control = "resume"
        else
            if st = "playing" then m.video.control = "pause"
            openOverlay("pause")
        end if
        return true
    else if key = "down" or key = "up"
        openOverlay("peek")
        return true
    else if key = "left" or key = "right" or key = "rewind" or key = "fastforward" or key = "replay"
        openOverlay("peek")
        m.ov.callFunc("nudge", key)
        return true
    else if key = "options"
        openSheet("subs", "")
        return true
    end if
    return false
end function

sub openOverlay(mode as string)
    m.ov.position = position()
    m.ov.playing = (m.video.state = "playing")
    m.ov.callFunc("open", mode)
    m.subs.lifted = true
end sub

sub focusBack()
    if m.sheet.visible
        m.sheet.setFocus(true)
    else if m.chapters.visible
        m.chapters.setFocus(true)
    else if m.ov.visible
        m.ov.setFocus(true)
    else
        m.top.setFocus(true)
    end if
end sub

sub onOverlayAction()
    a = m.ov.action
    if a = invalid then return
    if a.cmd = "seek"
        seekTo(a.to)
        if a.play = true and m.video.state = "paused" then m.video.control = "resume"
    else if a.cmd = "toggle"
        if m.video.state = "playing" then m.video.control = "pause" else m.video.control = "resume"
    else if a.cmd = "hidden"
        m.subs.lifted = false
        if not m.sheet.visible and not m.chapters.visible then m.top.setFocus(true)
    else if a.cmd = "button"
        id = a.id
        if id = "cc"
            openSheet("subs", "")
        else if id = "audio"
            openSheet("subs", "audio")
        else if id = "chapters"
            m.reopenOverlay = true
            m.ov.callFunc("close", invalid)
            m.chapters.position = position()
            m.chapters.callFunc("open", invalid)
        else if id = "episodes"
            openSheet("eps", "")
        else if id = "next"
            playNext()
        else if id = "quality" or id = "info"
            openSheet("info", "")
        else if id = "sleep" or id = "watched"
            openSheet("sleep", "")
        end if
    end if
end sub

sub onChapterAction()
    a = m.chapters.action
    if a.cmd = "jump"
        seekTo(a.to)
        if m.video.state = "paused" then m.video.control = "resume"
        m.reopenOverlay = false
        m.top.setFocus(true)
    else
        if m.reopenOverlay then openOverlay("pause") else m.top.setFocus(true)
        m.reopenOverlay = false
    end if
end sub

' Jumps to t seconds. A Plex remux starts at the resume point, so going back before it means restarting the stream.
sub seekTo(t as float)
    if t < 0 then t = 0
    if m.mode = "hls" and t < m.offset - 1
        reloadAt(t)
        return
    end if
    m.video.seek = t - m.offset
    if m.subMode = "hearth" then m.subs.time = t
end sub

' Starts this video again from t (after a download, an audio or quality change, or a seek before a remux).
sub reloadAt(t as float)
    print "[hearth-play] restarting at "; Int(t); " s"
    m.resumeAt = t
    m.tick.control = "stop"
    m.ready = false
    m.started = false
    m.subApplied = false
    m.retried5 = false
    m.hlsLight = false
    m.reloading = true
    m.video.control = "stop"
    m.status.visible = true
    uiReset(true)
    hPlex("item", { id: m.item.Id }, "onItem")
end sub

' ---------- subtitles drawn by Hearth ----------
function isTextSub(s as object) as boolean
    if s = invalid then return false
    return hPlayTextSub(LCase(toStr(s.codec))) and LCase(toStr(s.codec)) <> "ass" and LCase(toStr(s.codec)) <> "ssa"
end function

function subStreams() as object
    out = []
    if m.part = invalid or m.part.Stream = invalid then return out
    for each s in m.part.Stream
        if s.streamType = 3 then out.push(s)
    end for
    return out
end function

function audioStreams() as object
    out = []
    if m.part = invalid or m.part.Stream = invalid then return out
    for each s in m.part.Stream
        if s.streamType = 2 then out.push(s)
    end for
    return out
end function

' Called once the video first plays: which subtitle to show, if any.
sub uiStartSubs()
    pref = hCaptions()
    s = invalid
    if m.subStream <> invalid and m.reloading = true
        s = m.subStream
    else if pref <> "off"
        if m.streams.sub <> invalid then s = m.streams.sub
        if s = invalid and (pref = "on" or pref = "forced")
            for each x in subStreams()
                lang = LCase(toStr(x.languageCode))
                wantForced = (pref = "forced")
                if s = invalid and Left(lang, 2) = "en" and isTextSub(x) and ((x.forced = true) = wantForced) then s = x
            end for
        end if
    end if
    m.reloading = false
    if s <> invalid and isTextSub(s)
        useHearthSub(s)
    else
        m.subStream = s
        legacySubs()
    end if
end sub

' the old path: the TV's own captions (image subtitles, or when Hearth couldn't fetch the file)
sub legacySubs()
    if m.wantSub <> invalid
        m.video.globalCaptionMode = "On"
        m.video.subtitleTrack = m.wantSub
        m.subApplied = true
    else if m.capsPref = "off"
        m.video.globalCaptionMode = "Off"
    else
        applyEmbeddedSub()
    end if
    m.subMode = "native"
end sub

sub useHearthSub(s as object)
    m.subStream = s
    m.video.globalCaptionMode = "Off"
    m.subs.cues = []
    path = s.key
    if path = invalid then path = "/library/streams/" + s.id.toStr()
    url = m.global.plexServer + path + "?encoding=utf-8&X-Plex-Token=" + m.global.plexServerToken
    if s.key = invalid then url = url + "&format=srt"
    print "[hearth-subs] loading "; toStr(s.displayTitle); " ("; toStr(s.codec); ") for Hearth to draw"
    t = CreateObject("roSGNode", "SubTask")
    t.url = url
    t.observeField("done", "onSubCues")
    m.subTask = t
    t.control = "RUN"
end sub

sub onSubCues()
    t = m.subTask
    if t = invalid then return
    if t.ok
        m.subs.cues = t.cues
        m.subs.delay = m.subDelay
        m.subMode = "hearth"
        m.video.notificationInterval = 0.1
        m.subs.time = position()
    else
        ' fall back to the TV drawing it
        s = m.subStream
        print "[hearth-subs] couldn't fetch it; letting the TV draw it"
        if s <> invalid and s.key <> invalid
            m.wantSub = m.global.plexServer + s.key + "?X-Plex-Token=" + m.global.plexServerToken
        else
            m.wantSub = invalid
            m.streams.sub = s
            m.subApplied = false
        end if
        legacySubs()
    end if
    m.subTask = invalid
end sub

sub subsOff()
    m.subStream = invalid
    m.subs.cues = []
    m.subMode = "none"
    m.video.globalCaptionMode = "Off"
    m.video.notificationInterval = 0.5
end sub

' The look, saved on the TV for every video
function subStyle() as object
    raw = CreateObject("roRegistrySection", "hearth").Read("subStyle")
    st = invalid
    if raw <> "" then st = ParseJson(raw)
    if st = invalid or st.size = invalid then st = { size: "M", color: "0xFFFFFFFF", bg: "none", outline: "thin", pos: "bottom" }
    return st
end function

sub saveSubStyle(st as object)
    reg = CreateObject("roRegistrySection", "hearth")
    reg.Write("subStyle", FormatJson(st))
    reg.Flush()
    m.subs.style = st
end sub

function presets() as object
    return [
        { name: "Classic", color: "0xFFFFFFFF", box: false, outline: true, size: "M", st: { size: "M", color: "0xFFFFFFFF", bg: "none", outline: "thin", pos: "bottom" } },
        { name: "Hearth gold", color: "0xF3D27AFF", box: false, outline: true, size: "M", st: { size: "M", color: "0xF3D27AFF", bg: "none", outline: "thin", pos: "bottom" } },
        { name: "Boxed", color: "0xFFFFFFFF", box: true, outline: false, size: "M", st: { size: "M", color: "0xFFFFFFFF", bg: "solid", outline: "none", pos: "bottom" } },
        { name: "Large", color: "0xFFFFFFFF", box: false, outline: true, size: "L", st: { size: "L", color: "0xFFFFFFFF", bg: "none", outline: "thick", pos: "bottom" } },
        { name: "Raised cream", color: "0xEDE6CAFF", box: true, outline: false, size: "M", raised: true, st: { size: "M", color: "0xEDE6CAFF", bg: "soft", outline: "none", pos: "raised" } }
    ]
end function

function optLists() as object
    return {
        size: { vals: ["S", "M", "L", "XL"], names: ["Small", "Medium", "Large", "Extra large"] },
        color: { vals: ["0xFFFFFFFF", "0xEDE6CAFF", "0xF3D27AFF", "0xFFF26BFF"], names: ["White", "Cream", "Hearth gold", "Yellow"] },
        bg: { vals: ["none", "soft", "solid"], names: ["None", "Soft box", "Solid box"] },
        outline: { vals: ["none", "thin", "thick"], names: ["None", "Thin", "Thick"] },
        pos: { vals: ["bottom", "raised", "top"], names: ["Bottom", "Raised", "Top"] },
        when: { vals: ["on", "forced", "off"], names: ["Always", "Foreign parts", "Off"] }
    }
end function

function optName(key as string, v as dynamic) as string
    o = optLists()[key]
    for i = 0 to o.vals.count() - 1
        if o.vals[i] = v then return o.names[i]
    end for
    return o.names[0]
end function

function optStep(key as string, v as dynamic, dir as integer) as dynamic
    o = optLists()[key]
    i = 0
    for k = 0 to o.vals.count() - 1
        if o.vals[k] = v then i = k
    end for
    i = (i + dir + o.vals.count()) mod o.vals.count()
    return o.vals[i]
end function

' ---------- side sheets ----------
sub openSheet(kind as string, focusId as string)
    if m.ov.visible
        m.reopenOverlay = true
        m.ov.callFunc("close", invalid)
    end if
    m.sheetKind = kind
    fillSheet(focusId)
    m.sheet.visible = true
    m.sheet.setFocus(true)
    if kind = "eps" and m.epSeasons = invalid then loadSeasons()
end sub

sub closeSheet()
    m.sheet.visible = false
    if m.reopenOverlay
        m.reopenOverlay = false
        openOverlay("pause")
    else
        m.top.setFocus(true)
    end if
end sub

sub refreshSheet(keepId as string)
    if not m.sheet.visible then return
    fillSheet(keepId)
end sub

sub fillSheet(focusId as string)
    k = m.sheetKind
    items = []
    if k = "subs"
        m.sheet.sheetTitle = "Subtitles & audio"
        m.sheet.sheetIcon = "cc"
        items.push({ kind: "kicker", text: "Subtitles" })
        items.push({ kind: "row", id: "sub:off", title: "Off", on: (m.subStream = invalid) })
        ss = subStreams()
        for i = 0 to ss.count() - 1
            s = ss[i]
            title = toStr(s.displayTitle)
            if title = "" then title = toStr(s.language)
            if title = "" then title = "Subtitles " + (i + 1).toStr()
            src = "In the file"
            if s.key <> invalid then src = "Subtitle file"
            desc = src + " · " + UCase(toStr(s.codec))
            if not hPlayTextSub(LCase(toStr(s.codec))) then desc = "Picture subtitles · can't show without converting the video"
            row = { kind: "row", id: "sub:" + i.toStr(), title: title, desc: desc, on: (m.subStream <> invalid and toStr(m.subStream.id) = toStr(s.id)) }
            if s.hearingImpaired = true then row.tag = "SDH"
            if s.forced = true then row.tag = "forced"
            items.push(row)
        end for
        items.push({ kind: "row", id: "find", lead: "search", title: "Find more subtitles", desc: "Search Plex + Bazarr", chevron: true })
        items.push({ kind: "row", id: "look", lead: "aa", title: "Subtitle look & timing", desc: optName("size", subStyle().size) + " · " + fmtDelayUi(m.subDelay), chevron: true })
        items.push({ kind: "twig" })
        items.push({ kind: "kicker", text: "Audio" })
        au = audioStreams()
        di = CreateObject("roDeviceInfo")
        for i = 0 to au.count() - 1
            s = au[i]
            title = toStr(s.displayTitle)
            if title = "" then title = toStr(s.language)
            codec = LCase(toStr(s.codec))
            ch = chName(s.channels)
            desc = ch + " · " + UCase(codec)
            row = { kind: "row", id: "aud:" + i.toStr(), title: title, desc: desc, on: (m.streams.audio <> invalid and toStr(m.streams.audio.id) = toStr(s.id)) }
            if s.title <> invalid and Instr(1, LCase(s.title), "comment") > 0 then row.desc = "Commentary · " + desc
            if di.CanDecodeAudio({ Codec: rokuAudioCodec(codec) }).result <> true then row.tag = "converts"
            items.push(row)
        end for
        if focusId = "audio" and au.count() > 0 then focusId = "aud:0"
    else if k = "look"
        m.sheet.sheetTitle = "Subtitle look & timing"
        m.sheet.sheetIcon = "aa"
        st = subStyle()
        ps = presets()
        sel = -1
        for i = 0 to ps.count() - 1
            p = ps[i].st
            if p.size = st.size and p.color = st.color and p.bg = st.bg and p.outline = st.outline and p.pos = st.pos then sel = i
        end for
        if m.subMode <> "hearth" then items.push({ kind: "note", text: "Turn on a text subtitle (SRT) to see changes live. Picture subtitles keep the TV's own look." })
        items.push({ kind: "kicker", text: "Style" })
        items.push({ kind: "presets", id: "preset", options: ps, sel: sel })
        items.push({ kind: "step", id: "size", icon: "aa", title: "Size", value: optName("size", st.size) })
        items.push({ kind: "step", id: "color", icon: "star", title: "Colour", value: optName("color", st.color) })
        items.push({ kind: "step", id: "bg", icon: "qual", title: "Background", value: optName("bg", st.bg) })
        items.push({ kind: "step", id: "outline", icon: "eye", title: "Outline", value: optName("outline", st.outline) })
        items.push({ kind: "step", id: "pos", icon: "restart", title: "Position", value: optName("pos", st.pos) })
        items.push({ kind: "step", id: "when", icon: "cc", title: "Show subtitles", value: optName("when", hCaptions()) })
        items.push({ kind: "twig" })
        items.push({ kind: "head", icon: "timing", text: "Timing" })
        items.push({ kind: "ruler", id: "delay", value: m.subDelay })
        items.push({ kind: "row", id: "sync", lead: "audio", title: "Sync to the audio", desc: "Bazarr fixes the file for good", chevron: true })
    else if k = "eps"
        m.sheet.sheetTitle = "Episodes"
        m.sheet.sheetIcon = "eps"
        if m.epSeasons <> invalid and m.epSeasons.count() > 0
            labels = []
            for each s in m.epSeasons
                labels.push(s.index.toStr())
            end for
            items.push({ kind: "pills", id: "season", options: labels, sel: m.epSeasonSel })
        end if
        if m.epList = invalid
            items.push({ kind: "note", text: "Finding the episodes..." })
        else
            for each ep in m.epList
                cur = (ep.Id = m.item.Id)
                desc = ""
                if ep.RunTimeTicks <> invalid then desc = Int(ep.RunTimeTicks / 600000000).toStr() + " min"
                if cur then desc = desc + " · playing now"
                row = { kind: "row", id: "ep:" + ep.Id, lead: "none", h: 104, title: hNum(ep.IndexNumber) + "  " + hNameOr(ep.Name), desc: desc, thumb: hImage(ep, "Thumb", 240) }
                if ep.UserData <> invalid
                    if ep.UserData.Played = true
                        row.tag = "watched"
                    else if ep.UserData.PlayedPercentage <> invalid and ep.UserData.PlayedPercentage > 0
                        row.progress = ep.UserData.PlayedPercentage / 100
                    end if
                end if
                items.push(row)
                if focusId = "" and cur then focusId = row.id
            end for
        end if
    else if k = "info"
        m.sheet.sheetTitle = "Playing"
        m.sheet.sheetIcon = "info"
        items = infoItems()
    else if k = "sleep"
        m.sheet.sheetTitle = "Sleep timer"
        m.sheet.sheetIcon = "moon"
        dur = m.durationMs / 1000
        left = dur - position()
        items.push({ kind: "row", id: "sleep:off", title: "Off", desc: "Keep playing", on: (m.sleepMode = "off") })
        items.push({ kind: "row", id: "sleep:ep", title: "End of this one", desc: "Stops at " + wallClock(left), on: (m.sleepMode = "ep") })
        for each mins in [30, 60, 90]
            items.push({ kind: "row", id: "sleep:" + mins.toStr(), title: mins.toStr() + " min", desc: "Stops at " + wallClock(mins * 60), on: (m.sleepMode = mins.toStr()) })
        end for
        items.push({ kind: "twig" })
        items.push({ kind: "head", icon: "check", text: "This one" })
        items.push({ kind: "row", id: "w:leave", lead: "check", title: "Mark watched and leave", desc: "Back to the page" })
        if m.next <> invalid then items.push({ kind: "row", id: "w:next", lead: "next", title: "Mark watched, play next", desc: hSubtitle(m.next) })
        items.push({ kind: "row", id: "w:unwatched", lead: "restart", title: "Mark unwatched", desc: "Keeps it in Continue" })
    end if
    m.sheet.focusId = focusId
    m.sheet.items = items
end sub

function chName(n as dynamic) as string
    if n = invalid then return ""
    if n = 6 then return "5.1"
    if n = 8 then return "7.1"
    if n = 2 then return "stereo"
    if n = 1 then return "mono"
    return n.toStr() + " ch"
end function

function fmtDelayUi(v as float) as string
    if Abs(v) < 0.05 then return "in sync"
    s = Str(Int(Abs(v) * 10 + 0.5) / 10).Trim()
    if v < 0 then return s + " s earlier"
    return s + " s later"
end function

function wallClock(ahead as dynamic) as string
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    if ahead <> invalid and ahead > 0 then dt.FromSeconds(dt.AsSeconds() + Int(ahead))
    h = dt.GetHours()
    ap = "AM"
    if h >= 12 then ap = "PM"
    h = h mod 12
    if h = 0 then h = 12
    mm = dt.GetMinutes().toStr()
    if Len(mm) < 2 then mm = "0" + mm
    return h.toStr() + ":" + mm + " " + ap
end function

function infoItems() as object
    md = m.media
    if md = invalid then md = {}
    if m.streams = invalid then m.streams = {}
    d = m.decision
    items = []
    vcodec = UCase(toStr(md.videoCodec))
    acodec = UCase(toStr(md.audioCodec))
    if m.streams.audio <> invalid then acodec = UCase(toStr(m.streams.audio.codec))
    h = toStr(md.height)
    mbps = ""
    if md.bitrate <> invalid then mbps = Str(Int(Val(toStr(md.bitrate)) / 100) / 10).Trim()
    ch = "2.0"
    if m.streams.audio <> invalid then ch = chName(m.streams.audio.channels)
    kick = "Direct play"
    note = "the file plays as is"
    tvSub = ""
    plexSub = "Not needed: the TV reads the file itself"
    if m.mode = "hls"
        kick = "Plex repackages"
        note = "the picture is copied"
        vAct = "picture copied"
        aAct = "sound copied"
        if d <> invalid
            if d.video = "transcode"
                kick = "Plex converts"
                note = "the picture is re-encoded on the NAS"
                vAct = "picture converted to " + UCase(toStr(d.videoCodec))
            end if
            if d.audio = "transcode" then aAct = "sound " + acodec + " → " + UCase(toStr(d.audioCodec))
        end if
        plexSub = vAct + " · " + aAct
    end if
    items.push({ kind: "stats", kicker: kick, note: note, nums: [[h, "p · " + vcodec], [mbps, "Mbps"], [ch, acodec], [UCase(toStr(md.container)), "file"]] })
    items.push({ kind: "twig" })
    items.push({ kind: "kicker", text: "How it gets to the TV" })
    fileSub = UCase(toStr(md.container)) + " · " + vcodec + " " + h + "p · " + acodec + " " + ch
    if m.subStream <> invalid then fileSub = fileSub + " · " + UCase(toStr(m.subStream.codec))
    tvLine = h + "p · " + acodec + " " + ch
    if m.mode = "hls" and d <> invalid and d.audio = "transcode" then tvLine = h + "p · " + UCase(toStr(d.audioCodec)) + " " + ch
    if m.forceQuality <> invalid then tvLine = m.forceQuality + "p · converted"
    if m.subMode = "hearth" then tvLine = tvLine + " · Hearth draws the subtitles"
    if m.subMode = "native" then tvLine = tvLine + " · the TV draws the subtitles"
    why = ""
    if m.mode = "hls" and m.planWhy <> invalid and m.planWhy <> "" then why = "Why Plex is involved: this TV can't play the " + m.planWhy + "."
    items.push({ kind: "pipe", steps: [{ icon: "film", title: "The file", desc: fileSub }, { icon: "qual", title: "Plex on the NAS", desc: plexSub }, { icon: "info", title: "This TV", desc: tvLine }], note: why })
    items.push({ kind: "twig" })
    items.push({ kind: "head", icon: "qual", text: "Quality" })
    items.push({ kind: "row", id: "q:orig", title: "Original", desc: h + "p · as good as the file", on: (m.forceQuality = invalid) })
    items.push({ kind: "row", id: "q:720", title: "720p", desc: "Converted · 3 Mbps · easiest on the NAS", on: (m.forceQuality = "720") })
    items.push({ kind: "row", id: "q:480", title: "480p", desc: "Converted · 1.5 Mbps", on: (m.forceQuality = "480") })
    return items
end function

sub onSheetAction()
    a = m.sheet.action
    if a = invalid then return
    if a.cmd = "close"
        if m.sheetKind = "look"
            m.sheetKind = "subs"
            fillSheet("look")
            return
        end if
        closeSheet()
        return
    end if
    id = a.id
    if id = invalid then return
    k = m.sheetKind
    if k = "subs"
        if id = "sub:off"
            subsOff()
            saveSubPick(invalid)
            refreshSheet(id)
        else if Left(id, 4) = "sub:"
            s = subStreams()[Mid(id, 5).ToInt()]
            if not hPlayTextSub(LCase(toStr(s.codec)))
                hMessage("Picture subtitles", "These subtitles are pictures, so Plex would have to convert the whole video to show them. Try Find more subtitles for a text version.")
                return
            end if
            if isTextSub(s)
                useHearthSub(s)
            else
                m.subStream = s
                m.streams.sub = s
                m.subApplied = false
                m.wantSub = invalid
                if s.key <> invalid then m.wantSub = m.global.plexServer + s.key + "?X-Plex-Token=" + m.global.plexServerToken
                m.capsPref = "on"
                legacySubs()
            end if
            saveSubPick(s)
            refreshSheet(id)
        else if id = "find"
            m.sheet.visible = false
            m.reopenOverlay = false
            openFinder()
        else if id = "look"
            m.sheetKind = "look"
            fillSheet("")
        else if Left(id, 4) = "aud:"
            switchAudio(audioStreams()[Mid(id, 5).ToInt()])
            refreshSheet(id)
        end if
    else if k = "look"
        st = subStyle()
        if a.cmd = "pick" and id = "preset"
            saveSubStyle(presets()[a.index].st)
        else if a.cmd = "step"
            if id = "delay"
                m.subDelay = m.subDelay + a.dir * 0.1
                if Abs(m.subDelay) < 0.05 then m.subDelay = 0
                m.subs.delay = m.subDelay
            else if id = "when"
                v = optStep("when", hCaptions(), a.dir)
                reg = CreateObject("roRegistrySection", "hearth")
                reg.Write("captions", v)
                reg.Flush()
                if v = "off" then subsOff()
            else
                st[id] = optStep(id, st[id], a.dir)
                saveSubStyle(st)
            end if
        else if id = "sync"
            syncSubs()
            return
        end if
        refreshSheet(id)
    else if k = "eps"
        if a.cmd = "pick" and id = "season"
            m.epSeasonSel = a.index
            m.epList = invalid
            refreshSheet("season")
            hPlex("seasonEpisodes", { id: m.epSeasons[a.index].Id }, "onSheetEpisodes")
        else if Left(id, 3) = "ep:"
            epId = Mid(id, 4)
            if epId = m.item.Id
                closeSheet()
                return
            end if
            for each ep in m.epList
                if ep.Id = epId then playOther(ep)
            end for
        end if
    else if k = "info"
        q = invalid
        if id = "q:720" then q = "720"
        if id = "q:480" then q = "480"
        if q = invalid and m.forceQuality = invalid then return
        if q <> invalid and m.forceQuality <> invalid and q = m.forceQuality then return
        m.forceQuality = q
        closeSheet()
        reloadAt(position())
    else if k = "sleep"
        if Left(id, 6) = "sleep:"
            setSleep(Mid(id, 7))
            refreshSheet(id)
        else if id = "w:leave"
            m.markWatched = true
            m.sheet.visible = false
            leave()
        else if id = "w:next"
            m.sheet.visible = false
            playNext()
        else if id = "w:unwatched"
            hPlex("unplayed", { id: m.item.Id }, "onReported")
            closeSheet()
        end if
    end if
end sub

' Plex remembers the pick for every player; the registry remembers on/off for the CC buttons.
sub saveSubPick(s as dynamic)
    sid = "0"
    if s <> invalid then sid = toStr(s.id)
    if m.part.id <> invalid then hPlex("setSubtitle", { part: m.part.id, stream: sid }, "onReported")
    reg = CreateObject("roRegistrySection", "hearth")
    if s = invalid
        reg.Write("captions", "off")
        m.capsPref = "off"
    else if reg.Read("captions") <> "forced"
        reg.Write("captions", "on")
        m.capsPref = "on"
    end if
    reg.Flush()
end sub

' Plays the chosen audio track. A file the TV plays itself can switch live; otherwise Plex has to repackage.
sub switchAudio(s as object)
    if s = invalid then return
    if m.part.id <> invalid then hPlex("setAudio", { part: m.part.id, stream: s.id }, "onReported")
    m.streams.audio = s
    di = CreateObject("roDeviceInfo")
    decodable = di.CanDecodeAudio({ Codec: rokuAudioCodec(LCase(toStr(s.codec))) }).result = true
    tracks = m.video.availableAudioTracks
    au = audioStreams()
    k = -1
    for i = 0 to au.count() - 1
        if toStr(au[i].id) = toStr(s.id) then k = i
    end for
    if m.mode = "direct" and decodable and tracks <> invalid and k >= 0 and k < tracks.count()
        print "[hearth-play] audio: switching live to "; toStr(s.displayTitle)
        m.video.audioTrack = tracks[k].Track
    else
        print "[hearth-play] audio: "; toStr(s.displayTitle); " needs Plex; restarting here"
        closeSheet()
        reloadAt(position())
    end if
end sub

' Bazarr's subsync: re-times the subtitle file against the audio and saves it.
sub syncSubs()
    s = m.subStream
    if s = invalid or s.key = invalid
        hMessage("Sync to the audio", "Turn on a subtitle file first (Bazarr can only fix files saved next to the video).")
        return
    end if
    file = ""
    if m.part.file <> invalid then file = m.part.file
    args = { file: file, title: hTitle(m.item), series: hTitle(m.item), movie: (m.item.Type <> "Episode"), year: m.item.ProductionYear, season: m.item.ParentIndexNumber, episode: m.item.IndexNumber, language: toStr(s.languageCode), forced: (s.forced = true), hi: (s.hearingImpaired = true) }
    t = CreateObject("roSGNode", "BazarrTask")
    t.op = "sync"
    t.args = args
    t.observeField("done", "onSynced")
    m.syncTask = t
    t.control = "RUN"
    hMessage("Sync to the audio", "Bazarr is matching the subtitles to the sound. This takes a minute or two; the fixed file loads by itself when it's done.")
end sub

sub onSynced()
    t = m.syncTask
    m.syncTask = invalid
    if t = invalid then return
    if t.ok
        print "[hearth-subs] Bazarr synced the subtitle; reloading it"
        m.subDelay = 0
        m.subs.delay = 0
        if m.subStream <> invalid then useHearthSub(m.subStream)
    else
        msg = "Bazarr couldn't sync it (" + toStr(t.error) + ")."
        if t.error = "nokey" then msg = "Bazarr isn't set up on this TV yet. Add its API key the same way as in Find more subtitles."
        hMessage("Sync to the audio", msg)
    end if
end sub

' ---------- episodes ----------
sub loadSeasons()
    if m.item.SeriesId = invalid then return
    hPlex("seasons", { id: m.item.SeriesId }, "onSheetSeasons")
end sub

sub onSheetSeasons(event as object)
    t = hTaskFrom(event)
    if not t.ok or t.response.Items = invalid then return
    m.epSeasons = []
    m.epSeasonSel = 0
    for each s in t.response.Items
        if s.index > 0 or t.response.Items.count() = 1 then m.epSeasons.push(s)
    end for
    for i = 0 to m.epSeasons.count() - 1
        if m.epSeasons[i].index = m.item.ParentIndexNumber then m.epSeasonSel = i
    end for
    if m.epSeasons.count() > 0 then hPlex("seasonEpisodes", { id: m.epSeasons[m.epSeasonSel].Id }, "onSheetEpisodes")
    if m.sheetKind = "eps" then refreshSheet("")
end sub

sub onSheetEpisodes(event as object)
    t = hTaskFrom(event)
    if t.ok and t.response.Items <> invalid then m.epList = t.response.Items else m.epList = []
    if m.sheetKind = "eps" then refreshSheet("")
end sub

' Plays another title in this player (an episode from the list).
sub playOther(ep as object)
    m.sheet.visible = false
    m.reopenOverlay = false
    m.next = ep
    m.nextFromQueue = false
    m.top.queue = []
    m.noMarkOnNext = true
    playNext()
end sub

' ---------- sleep ----------
sub setSleep(v as string)
    m.sleepMode = v
    m.sleepAt = invalid
    if v <> "off" and v <> "ep"
        dt = CreateObject("roDateTime")
        m.sleepAt = dt.AsSeconds() + v.ToInt() * 60
    end if
    print "[hearth-play] sleep timer: "; v
end sub

' called from the 10 s tick
sub checkSleep()
    if m.sleepAt = invalid then return
    if CreateObject("roDateTime").AsSeconds() >= m.sleepAt
        print "[hearth-play] sleep timer: stopping"
        m.sleepAt = invalid
        m.sleepMode = "off"
        leave()
    end if
end sub
