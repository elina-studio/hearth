sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.eyebrow = m.top.findNode("eyebrow")
    m.eyebrow.font = hFont("caps", 28)
    m.title = m.top.findNode("title")
    m.title.font = hFont("caps", 80)
    m.cast = m.top.findNode("cast")
    m.cast.font = hFont("regular", 24)
    m.meta = m.top.findNode("meta")
    m.meta.font = hFont("regular", 26)
    m.overview = m.top.findNode("overview")
    m.overview.font = hFont("regular", 28)
    m.track = m.top.findNode("track")
    m.bar = m.top.findNode("bar")
    m.buttons = m.top.findNode("buttons")
    m.below = m.top.findNode("below")
    m.content = m.top.findNode("content")
    m.scroll = m.top.findNode("scroll")
    m.scrollTo = m.top.findNode("scrollTo")
    m.zone = 0
    m.btn = 0
    m.actions = []
    m.full = invalid
    m.nextEpisode = invalid
end sub

sub onShown(unused as dynamic)
    if m.full <> invalid then load()
    m.top.setFocus(true)
end sub

sub load()
    it = m.top.item
    if it = invalid then return
    show(it)
    hPlex("item", { id: it.Id }, "onItem")
end sub

sub onItem(event as object)
    t = hTaskFrom(event)
    if not t.ok or t.response.Id = invalid then return
    m.full = t.response
    show(m.full)
    if m.full.Type = "Series"
        hPlex("episodes", { id: m.full.Id }, "onEpisodes")
    else if m.full.Type = "Movie"
        hPlex("similar", { id: m.full.Id }, "onSimilar")
    end if
end sub

sub show(it as object)
    kind = "MOVIE"
    if it.Type = "Series" then kind = "SHOW"
    if it.Type = "Episode" then kind = "EPISODE · " + hSubtitle(it)
    m.eyebrow.text = kind
    m.title.text = UCase(hTitle(it))
    parts = []
    if it.ProductionYear <> invalid then parts.push(it.ProductionYear.toStr())
    if it.RunTimeTicks <> invalid and it.Type <> "Series" then parts.push(Int(it.RunTimeTicks / 600000000).toStr() + " min")
    if it.OfficialRating <> invalid then parts.push(it.OfficialRating)
    if it.Genres <> invalid and it.Genres.count() > 0 then parts.push(it.Genres[0])
    if it.Type = "Series" and it.SeasonCount <> invalid and it.SeasonCount > 0
        if it.SeasonCount = 1 then parts.push("1 season") else parts.push(it.SeasonCount.toStr() + " seasons")
    end if
    cast = ""
    if it.Cast <> invalid and it.Cast.count() > 0 then cast = "Starring " + it.Cast.join(", ")
    if it.Directors <> invalid and it.Directors.count() > 0
        if cast <> "" then cast = cast + "  ·  "
        cast = cast + "Directed by " + it.Directors[0]
    end if
    m.cast.text = cast
    m.meta.text = parts.join("  ·  ")
    ov = it.Overview
    if ov = invalid then ov = ""
    m.overview.text = ov
    ' the poster: for an episode this is the show's poster
    m.backdrop.uri = hImageAny(it, ["Primary", "Thumb"], 340)
    pct = hPercent(it)
    m.track.visible = pct > 0 and it.Type <> "Series"
    if it.Type <> "Series" then m.bar.width = 420 * pct / 100 else m.bar.width = 0
    buildButtons(it)
end sub

sub buildButtons(it as object)
    list = []
    played = (it.UserData <> invalid and it.UserData.Played = true)
    if it.Type = "Series"
        if m.nextEpisode <> invalid
            list.push({ label: "Play S" + hNum(m.nextEpisode.ParentIndexNumber) + " E" + hNum(m.nextEpisode.IndexNumber), action: "playNext" })
        end if
    else
        pct = hPercent(it)
        if pct > 0 and not played
            list.push({ label: "Resume", action: "resume" })
            list.push({ label: "From the start", action: "restart" })
        else
            list.push({ label: "Play", action: "restart" })
        end if
    end if
    if it.Type <> "Series"
        lab = "CC  Subtitles"
        if it._media <> invalid then lab = "CC  " + hSubsLabel(it)
        list.push({ label: lab, action: "subs" })
    end if
    if played then list.push({ label: "Watched", action: "unplayed" }) else list.push({ label: "Mark watched", action: "played" })

    m.buttons.removeChildrenIndex(m.buttons.getChildCount(), 0)
    m.actions = []
    for each b in list
        p = m.buttons.createChild("HearthPill")
        p.button = true
        p.text = b.label
        m.actions.push(b.action)
    end for
    if m.btn >= m.actions.count() then m.btn = 0
    paint()
end sub

sub onEpisodes(event as object)
    t = hTaskFrom(event)
    if not t.ok then return
    cards = []
    first = -1
    i = 0
    for each ep in t.response.Items
        c = hCard(ep, "wide")
        c.title = "S" + hNum(ep.ParentIndexNumber) + " E" + hNum(ep.IndexNumber)
        if ep.Name <> invalid then c.sub = ep.Name else c.sub = ""
        cards.push(c)
        if first = -1 and (ep.UserData = invalid or ep.UserData.Played <> true) then first = i
        i = i + 1
    end for
    m.nextEpisode = invalid
    if first >= 0 then m.nextEpisode = t.response.Items[first]
    buildButtons(m.full)
    m.below.title = "Episodes"
    m.below.cards = cards
    if first >= 0 then m.below.index = first
    m.below.callFunc("move", 0)
end sub


sub onSimilar(event as object)
    t = hTaskFrom(event)
    if not t.ok then return
    cards = []
    for each it in t.response.Items
        cards.push(hCard(it, "wide"))
    end for
    m.below.title = "More like this"
    m.below.cards = cards
end sub

sub paint()
    for i = 0 to m.buttons.getChildCount() - 1
        m.buttons.getChild(i).focused = (m.zone = 0 and i = m.btn)
    end for
    m.below.active = (m.zone = 1)
    y = 0
    if m.zone = 1 then y = -300
    m.scroll.control = "stop"
    m.scrollTo.keyValue = [m.content.translation, [0, y]]
    m.scroll.control = "start"
end sub

sub runAction(a as string)
    it = m.full
    if it = invalid then it = m.top.item
    if a = "resume"
        m.top.request = { action: "play", item: it, resume: true }
    else if a = "restart"
        m.top.request = { action: "play", item: it, resume: false }
    else if a = "playNext" and m.nextEpisode <> invalid
        m.top.request = { action: "play", item: m.nextEpisode, resume: true }
    else if a = "subs"
        hSubsPick(it)
    else if a = "played" or a = "unplayed"
        hPlex(a, { id: it.Id }, "onChanged")
    end if
end sub

sub onChanged(event as object)
    hTaskFrom(event)
    load()
end sub

sub restoreFocus()
    m.top.setFocus(true)
end sub

sub afterOptions()
    load()
end sub

sub onOptions()
    hOptionsChosen()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
    if key = "back"
        m.top.request = { action: "back" }
        return true
    end if
    if m.zone = 0
        n = m.buttons.getChildCount()
        if key = "left" and m.btn > 0
            m.btn = m.btn - 1
        else if key = "right" and m.btn < n - 1
            m.btn = m.btn + 1
        else if key = "down" and m.below.callFunc("count", invalid) > 0
            m.zone = 1
        else if key = "OK" and n > 0
            runAction(m.actions[m.btn])
        end if
        paint()
        return true
    end if
    ' zone 1: the row below
    if key = "left" or key = "right"
        if key = "left" then d = -1 else d = 1
        m.below.callFunc("move", d)
    else if key = "up"
        m.zone = 0
    else if key = "OK"
        c = m.below.callFunc("current", invalid)
        if c <> invalid
            if c.item.Type = "Episode"
                m.top.request = { action: "play", item: c.item, resume: true }
            else
                m.top.request = { action: "details", item: c.item }
            end if
        end if
    else if key = "options"
        c = m.below.callFunc("current", invalid)
        if c <> invalid then hOptions(c.item)
    end if
    paint()
    return true
end function

' the subtitle picker (subs.brs) calls this after a pick
sub hSubsChanged(label as string)
    if m.full <> invalid then buildButtons(m.full)
end sub
