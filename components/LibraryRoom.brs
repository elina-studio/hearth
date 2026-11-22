sub init()
    m.backdrop = m.top.findNode("backdrop")
    m.eyebrow = m.top.findNode("eyebrow")
    m.eyebrow.font = hFont("caps", 28)
    m.title = m.top.findNode("title")
    m.title.font = hFont("caps", 84)
    m.overview = m.top.findNode("overview")
    m.overview.font = hFont("regular", 28)
    m.empty = m.top.findNode("empty")
    m.empty.font = hFont("regular", 32)
    m.content = m.top.findNode("content")
    m.scroll = m.top.findNode("scroll")
    m.scrollTo = m.top.findNode("scrollTo")
    m.rows = []
    m.row = 0
    m.focused = false
end sub

sub refresh(unused as dynamic)
    if m.top.kind = "" then return
    libs = m.global.libraries
    if libs = invalid or libs[m.top.kind] = invalid
        m.empty.text = "Loading your library…"
        return
    end if
    m.parent = libs[m.top.kind]
    m.empty.text = ""
    if m.top.kind = "movies" then types = "Movie" else types = "Series"
    m.types = types
    m.pending = {}
    m.results = {}
    m.content.removeChildrenIndex(m.content.getChildCount(), 0)
    m.rowByName = {}
    m.rows = []
    m.row = 0
    if types = "Movie"
        hPlex("resume", { section: m.parent, limit: 12 }, "onRow", "Continue")
    end if
    hPlex("latest", { section: m.parent, limit: 24 }, "onRow", "Recently added")
    if types = "Movie" then hPlex("list", { section: m.parent, unwatched: true, sort: "random", limit: 24 }, "onRow", "Unwatched")
    hPlex("list", { section: m.parent, sort: "titleSort", limit: 300 }, "onRow", "A to Z")
end sub

sub onRow(event as object)
    t = hTaskFrom(event)
    items = []
    if t.ok and t.response.Items <> invalid then items = t.response.Items
    m.results[t.tag] = items
    build()
end sub

' Each shelf is made once, when its answer arrives; later answers only slot in and shift the rows below.
sub build()
    order = ["Continue", "Recently added", "Unwatched", "A to Z"]
    if m.rowByName = invalid then m.rowByName = {}
    keep = invalid
    if m.row < m.rows.count() then keep = m.rows[m.row]
    m.rows = []
    y = 0
    for each name in order
        items = m.results[name]
        r = m.rowByName[name]
        if r = invalid and items <> invalid and items.count() > 0
            r = m.content.createChild("CardRow")
            r.title = name
            shape = "wide"
            if name = "A to Z"
                r.cardWidth = 236
                r.cardHeight = 354
                shape = "tall"
            end if
            cards = []
            for each it in items
                cards.push(hCard(it, shape))
            end for
            r.cards = cards
            m.rowByName[name] = r
        end if
        if r <> invalid
            r.translation = [96, y]
            m.rows.push(r)
            y = y + r.rowHeight + 30
        end if
    end for
    m.row = 0
    for i = 0 to m.rows.count() - 1
        if keep <> invalid and m.rows[i].isSameNode(keep) then m.row = i
    end for
    if m.rows.count() = 0 and m.empty.text = "" and m.results.count() >= 2 then m.empty.text = "Nothing here yet."
    if m.rows.count() > 0 then m.empty.text = ""
    paint()
end sub

sub focusIn(unused as dynamic)
    m.focused = true
    m.top.setFocus(true)
    paint()
end sub

sub paint()
    for i = 0 to m.rows.count() - 1
        m.rows[i].active = (m.focused and i = m.row)
    end for
    y = 0
    if m.row > 0 and m.row < m.rows.count() then y = -m.rows[m.row].translation[1]
    m.scroll.control = "stop"
    m.scrollTo.keyValue = [m.content.translation, [0, y]]
    m.scroll.control = "start"
    showInfo()
end sub

sub showInfo()
    item = invalid
    if m.row < m.rows.count()
        c = m.rows[m.row].callFunc("current", invalid)
        if c <> invalid then item = c.item
    end if
    if item = invalid then return
    if m.top.kind = "movies" then m.eyebrow.text = "MOVIES" else m.eyebrow.text = "SHOWS"
    if item.ProductionYear <> invalid then m.eyebrow.text = m.eyebrow.text + " · " + item.ProductionYear.toStr()
    m.title.text = UCase(hTitle(item))
    ov = item.Overview
    if ov = invalid then ov = ""
    m.overview.text = ov
    ' the synopsis sits under however many lines the title took
    th = m.title.boundingRect().height
    m.overview.translation = [0, 36 + th + 10]
    if th > 100 then m.overview.maxLines = 2 else m.overview.maxLines = 3
    m.backdrop.uri = hImageAny(item, ["Backdrop", "Thumb"], 1300)
end sub

sub restoreFocus()
    m.top.setFocus(true)
end sub

sub afterOptions()
    refresh(invalid)
end sub

sub onOptions()
    hOptionsChosen()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if hMediaKey(key) then return false
    if key = "back" or (key = "up" and m.row = 0)
        m.focused = false
        paint()
        m.top.request = { action: "pills" }
        return true
    end if
    if m.rows.count() = 0 then return true
    current = m.rows[m.row]
    if key = "left" or key = "right"
        if key = "left" then d = -1 else d = 1
        current.callFunc("move", d)
        showInfo()
        return true
    else if key = "up"
        m.row = m.row - 1
        paint()
        return true
    else if key = "down"
        if m.row < m.rows.count() - 1
            m.row = m.row + 1
            paint()
        end if
        return true
    else if key = "OK"
        c = current.callFunc("current", invalid)
        if c <> invalid then m.top.request = { action: "details", item: c.item }
        return true
    else if key = "options"
        c = current.callFunc("current", invalid)
        if c <> invalid then hOptions(c.item)
        return true
    end if
    return true
end function
