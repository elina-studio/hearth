sub init()
    m.top.findNode("eyebrow").font = hFont("caps", 28)
    m.kb = m.top.findNode("kb")
    m.hint = m.top.findNode("hint")
    m.hint.font = hFont("regular", 30)
    m.hint.text = "Type a few letters. Movies, shows and episodes show up here as you go."
    m.results = m.top.findNode("results")
    m.debounce = m.top.findNode("debounce")
    m.debounce.observeField("fire", "runSearch")
    m.kb.observeField("text", "onText")
    m.rows = []
    m.row = 0
    m.zone = "kb"
    m.term = ""
    m.seq = 0
end sub

sub focusIn(unused as dynamic)
    m.zone = "kb"
    m.kb.setFocus(true)
    paint()
end sub

sub refresh(unused as dynamic)
end sub

sub onText()
    m.debounce.control = "stop"
    m.debounce.control = "start"
end sub

sub runSearch()
    term = m.kb.text.Trim()
    m.term = term
    if Len(term) < 2
        clearRows()
        m.hint.text = "Type a few letters. Movies, shows and episodes show up here as you go."
        return
    end if
    m.seq = m.seq + 1
    q = { userId: hUser(), searchTerm: term, Recursive: "true", IncludeItemTypes: "Movie,Series,Episode", Limit: 60, Fields: hFields(), EnableImageTypes: "Primary,Backdrop,Thumb" }
    hApi("GET", "/Items", q, invalid, "onResults", m.seq.toStr())
end sub

sub onResults(event as object)
    t = hTaskFrom(event)
    if t.tag <> m.seq.toStr() then return ' an older search finished late
    clearRows()
    if not t.ok
        m.hint.text = "Couldn't reach Jellyfin."
        return
    end if
    groups = { Movie: [], Series: [], Episode: [] }
    for each it in t.response.Items
        if groups[it.Type] <> invalid then groups[it.Type].push(it)
    end for
    y = 0
    for each g in [["Movie", "Movies"], ["Series", "Shows"], ["Episode", "Episodes"]]
        items = groups[g[0]]
        if items.count() > 0
            r = m.results.createChild("CardRow")
            r.viewWidth = 1184
            r.translation = [0, y]
            r.title = g[1]
            cards = []
            for each it in items
                cards.push(hCard(it, "wide"))
            end for
            r.cards = cards
            m.rows.push(r)
            y = y + r.rowHeight + 24
        end if
    end for
    if m.rows.count() = 0
        m.hint.text = "Nothing matches " + Chr(34) + m.term + Chr(34) + "."
    else
        m.hint.text = ""
    end if
    m.row = 0
    paint()
end sub

sub clearRows()
    m.results.removeChildrenIndex(m.results.getChildCount(), 0)
    m.rows = []
    m.row = 0
    if m.zone = "rows"
        m.zone = "kb"
        m.kb.setFocus(true)
    end if
end sub

sub paint()
    for i = 0 to m.rows.count() - 1
        m.rows[i].active = (m.zone = "rows" and i = m.row)
    end for
    ' keep the focused row in view
    y = 0
    if m.zone = "rows" and m.row > 0 then y = -m.rows[m.row].translation[1]
    m.results.translation = [640, 60 + y]
end sub

sub restoreFocus()
    if m.zone = "rows" then m.top.setFocus(true) else m.kb.setFocus(true)
end sub

sub afterOptions()
    runSearch()
end sub

sub onOptions()
    hOptionsChosen()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if m.zone = "kb"
        ' the keyboard handles its own keys; we get the ones it doesn't use
        if key = "right" and m.rows.count() > 0
            m.zone = "rows"
            m.top.setFocus(true)
            paint()
            return true
        else if key = "back" or key = "up"
            m.top.request = { action: "pills" }
            return true
        end if
        return false
    end if
    current = m.rows[m.row]
    if key = "back"
        m.zone = "kb"
        m.kb.setFocus(true)
        paint()
    else if key = "left"
        if current.index = 0
            m.zone = "kb"
            m.kb.setFocus(true)
            paint()
        else
            current.callFunc("move", -1)
        end if
    else if key = "right"
        current.callFunc("move", 1)
    else if key = "up"
        if m.row > 0
            m.row = m.row - 1
            paint()
        else
            m.zone = "kb"
            m.kb.setFocus(true)
            paint()
        end if
    else if key = "down"
        if m.row < m.rows.count() - 1
            m.row = m.row + 1
            paint()
        end if
    else if key = "OK"
        c = current.callFunc("current", invalid)
        if c <> invalid
            if c.item.Type = "Episode"
                m.top.request = { action: "play", item: c.item, resume: true }
            else
                m.top.request = { action: "details", item: c.item }
            end if
        end if
    else if key = "options"
        c = current.callFunc("current", invalid)
        if c <> invalid then hOptions(c.item)
    end if
    return true
end function
