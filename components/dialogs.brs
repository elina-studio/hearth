' Dialog helpers. The including component must define onOptions, afterOptions and restoreFocus.

' ---------- poster options (the * key on any card) ----------
' The caller must define: sub onOptions() : hOptionsChosen() : end sub, and sub afterOptions() (refresh)
sub hOptions(item as object)
    if item = invalid or item.Id = invalid then return
    m.optItem = item
    played = (item.UserData <> invalid and item.UserData.Played = true)
    favorite = (item.UserData <> invalid and item.UserData.IsFavorite = true)
    m.optActions = []
    labels = []
    ' Open details first: the watched switch changes data, so it is never the button the dialog opens on
    labels.push("Open details") : m.optActions.push("details")
    if played
        labels.push("Mark unwatched") : m.optActions.push("unplayed")
        seen = "It shows as not watched again"
    else
        labels.push("Mark watched") : m.optActions.push("played")
        seen = "It leaves Continue watching"
    end if
    labels.push("Close") : m.optActions.push("close")
    d = CreateObject("roSGNode", "HearthDialog")
    d.title = hTitle(item)
    d.message = [hSubtitle(item)]
    ' the poster leads for a film or a show; an episode's picture is wide, so it gets the square
    kind = "Film"
    shape = "poster"
    pw = 300
    if item.Type = "Series" then kind = "Show"
    if item.Type = "Episode"
        kind = "Episode"
        shape = "square"
        pw = 320
    end if
    chips = []
    if played then chips.push("Watched")
    d.hero = { art: hImage(item, "Primary", pw), shape: shape, kicker: kind, chips: chips }
    d.buttons = labels
    d.kinds = ["main", "", ""]
    d.icons = ["pkg:/images/icons/d-info.png", "pkg:/images/icons/d-check.png", ""]
    d.subs = ["", seen, ""]
    d.observeField("buttonSelected", "onOptions")
    m.optDialog = d
    hShowDialog(d)
end sub

sub hOptionsChosen()
    a = m.optActions[m.optDialog.buttonSelected]
    m.optDialog.close = true
    item = m.optItem
    if a = "played" or a = "unplayed"
        hPlex(a, { id: item.Id }, "onOptionDone")
    else if a = "details"
        m.top.request = { action: "details", item: item }
    end if
    restoreFocus()
end sub

sub onOptionDone(event as object)
    hTaskFrom(event)
    afterOptions()
end sub

sub hMessage(title as string, text as string)
    d = CreateObject("roSGNode", "HearthDialog")
    d.title = title
    d.message = [text]
    d.buttons = ["OK"]
    d.popup = true
    d.observeField("buttonSelected", "onMessageClosed")
    m.msgDialog = d
    hShowDialog(d)
end sub

sub onMessageClosed()
    m.msgDialog.close = true
    restoreFocus()
end sub

