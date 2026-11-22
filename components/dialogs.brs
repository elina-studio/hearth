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
    if played
        labels.push("Mark unwatched") : m.optActions.push("unplayed")
    else
        labels.push("Mark watched") : m.optActions.push("played")
    end if
    if favorite
        labels.push("Remove from favorites") : m.optActions.push("unfav")
    else
        labels.push("Add to favorites") : m.optActions.push("fav")
    end if
    labels.push("Open details") : m.optActions.push("details")
    labels.push("Close") : m.optActions.push("close")
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = hTitle(item)
    d.message = [hSubtitle(item)]
    d.buttons = labels
    d.observeField("buttonSelected", "onOptions")
    m.optDialog = d
    m.top.getScene().dialog = d
end sub

sub hOptionsChosen()
    a = m.optActions[m.optDialog.buttonSelected]
    m.optDialog.close = true
    item = m.optItem
    if a = "played"
        hApi("POST", "/UserPlayedItems/" + item.Id, { userId: hUser() }, invalid, "onOptionDone")
    else if a = "unplayed"
        hApi("DELETE", "/UserPlayedItems/" + item.Id, { userId: hUser() }, invalid, "onOptionDone")
    else if a = "fav"
        hApi("POST", "/UserFavoriteItems/" + item.Id, { userId: hUser() }, invalid, "onOptionDone")
    else if a = "unfav"
        hApi("DELETE", "/UserFavoriteItems/" + item.Id, { userId: hUser() }, invalid, "onOptionDone")
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
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = title
    d.message = [text]
    d.buttons = ["OK"]
    d.observeField("buttonSelected", "onMessageClosed")
    m.msgDialog = d
    m.top.getScene().dialog = d
end sub

sub onMessageClosed()
    m.msgDialog.close = true
    restoreFocus()
end sub

