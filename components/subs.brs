' Subtitle picker shared by the details page, the Movies/Shows strip and the player, like the Plex app's:
' None plus every subtitle Plex knows for the title (files next to it, Bazarr's, and embedded ones).
' The pick is saved on the Plex server (PUT /library/parts), so it sticks for that title everywhere.
' The calling component defines sub hSubsChanged(label as string) to update its button.

' Short label for the current choice of an item fetched with hPlex("item")
function hSubsLabel(it as object) as string
    st = hSubsStreams(it)
    for each s in st
        if s.selected = true then return "Subtitles: " + hSubsName(s)
    end for
    if st.count() = 0 then return "No subtitles"
    return "Subtitles off"
end function

function hSubsStreams(it as object) as object
    out = []
    if it = invalid or it._media = invalid or it._media.count() = 0 then return out
    if it._media[0].Part = invalid or it._media[0].Part.count() = 0 then return out
    part = it._media[0].Part[0]
    if part = invalid or part.Stream = invalid then return out
    for each s in part.Stream
        if s.streamType = 3 then out.push(s)
    end for
    return out
end function

function hSubsName(s as object) as string
    n = s.displayTitle
    if n = invalid or n = "" then n = s.language
    if n = invalid or n = "" then n = "Unknown"
    if s.title <> invalid and s.title <> "" and Instr(1, n, s.title) = 0 then n = n + " · " + s.title
    return n
end function

' Open the picker for an item. Fetches the item first when it has no file details.
sub hSubsPick(it as object)
    if it = invalid then return
    if it._media = invalid
        hPlex("item", { id: it.Id }, "hSubsOnItem")
        return
    end if
    hSubsDialog(it)
end sub

sub hSubsOnItem(event as object)
    t = hTaskFrom(event)
    if not t.ok or t.response = invalid or t.response.Id = invalid
        hMessage("Subtitles", "Couldn't reach Plex to list subtitles. Try again in a moment.")
        return
    end if
    hSubsDialog(t.response)
end sub

sub hSubsDialog(it as object)
    st = hSubsStreams(it)
    m.subsItem = it
    m.subsList = st
    labels = ["None"]
    focusAt = 0
    i = 1
    lines = [""]
    for each s in st
        tag = "Inside the video"
        if s.key <> invalid then tag = "A subtitle file beside the video"
        if s.forced = true then tag = tag + "  ·  only the foreign parts"
        labels.push(hSubsName(s))
        lines.push(tag)
        if s.selected = true then focusAt = i
        i = i + 1
    end for
    if st.count() = 0
        labels = ["No subtitles for this one"]
        lines = [""]
    end if
    d = CreateObject("roSGNode", "HearthDialog")
    d.title = "Subtitles"
    d.icon = "pkg:/images/icons/d-cc.png"
    d.buttons = labels
    d.subs = lines
    if st.count() > 0 then d.icons = hPickIcons(labels.count(), focusAt, "pkg:/images/icons/d-cc.png")
    d.buttonFocused = focusAt
    d.observeField("buttonSelected", "hSubsOnPicked")
    d.observeField("wasClosed", "hSubsOnClosed")
    m.subsDialog = d
    hShowDialog(d)
end sub

sub hSubsOnPicked()
    i = m.subsDialog.buttonSelected
    m.subsDialog.close = true
    if m.subsList.count() = 0 then return
    it = m.subsItem
    part = it._media[0].Part[0]
    reg = CreateObject("roRegistrySection", "hearth")
    if i = 0
        streamId = "0"
        label = "Subtitles off"
        reg.Write("captions", "off")
    else
        s = m.subsList[i - 1]
        streamId = s.id.toStr()
        label = "Subtitles: " + hSubsName(s)
        reg.Write("captions", "on")
    end if
    reg.Flush()
    ' reflect the choice locally right away
    for k = 0 to m.subsList.count() - 1
        m.subsList[k].selected = (k = i - 1)
    end for
    hPlex("setSubtitle", { part: part.id, stream: streamId }, "hSubsOnSaved")
    hSubsChanged(label)
end sub

sub hSubsOnSaved(event as object)
    t = hTaskFrom(event)
    if not t.ok then print "[hearth] couldn't save the subtitle choice in Plex (status "; t.status; ")"
end sub

sub hSubsOnClosed()
    m.top.setFocus(true)
end sub
