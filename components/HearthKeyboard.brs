' Hearth keyboard. See HearthKeyboard.xml for how a parent uses it.

sub init()
    m.display = m.top.findNode("display")
    m.display.font = hFont("bold", 48)
    m.chipsGroup = m.top.findNode("chips")
    m.keysGroup = m.top.findNode("keys")
    m.cleaner = CreateObject("roRegex", "[^a-z0-9]+", "")

    m.keyW = 84
    m.keyH = 70
    m.gap = 10
    m.width = 6 * m.keyW + 5 * m.gap

    m.pages = [
        charsOf("abcdefghijklmnopqrstuvwxyz1234567890"),
        [".", "-", "_", ":", "/", "@", "'", "&", "!", "?", ",", "#", "(", ")", "+", "=", "%", "*", "~", "$", ";", Chr(34), "<", ">", "[", "]", "{", "}", "|", "\", "http://", "https://", ".com", ".local", ":8096", "www."]
    ]
    m.page = 0
    m.zone = "keys"
    m.r = 0
    m.c = 0
    m.chip = 0
    m.chipTexts = []
    m.norm = []
    m.vocab = []
    m.nextSet = invalid

    buildKeys()
    onText()
    ' phone remote: live text lands in whichever Hearth keyboard has focus
    m.global.observeField("remote", "onRemote")
end sub

sub onRemote()
    r = m.global.remote
    if r = invalid or r.go <> "" or not m.top.active then return
    t = r.text
    if t = invalid then return
    if Len(t) > m.top.maxLength then t = Left(t, m.top.maxLength)
    m.top.text = t
end sub

function charsOf(s as string) as object
    out = []
    for i = 1 to Len(s)
        out.push(Mid(s, i, 1))
    end for
    return out
end function

' ---------- building ----------

sub buildKeys()
    m.keysGroup.removeChildrenIndex(m.keysGroup.getChildCount(), 0)
    m.keyNodes = []
    for r = 0 to 5
        row = []
        for c = 0 to 5
            row.push(makeKey(c * (m.keyW + m.gap), r * (m.keyH + m.gap), m.keyW))
        end for
        m.keyNodes.push(row)
    end for
    m.wideNodes = []
    wideW = m.keyW * 2 + m.gap
    for k = 0 to 2
        m.wideNodes.push(makeKey(k * (wideW + m.gap), 6 * (m.keyH + m.gap), wideW))
    end for
    labelKeys()
end sub

function makeKey(x as integer, y as integer, w as integer) as object
    g = m.keysGroup.createChild("Group")
    g.translation = [x, y]
    glow = g.createChild("Poster")
    glow.uri = "pkg:/images/ring.9.png"
    glow.blendColor = "0xE0B34A70"
    glow.translation = [-8, -8]
    glow.width = w + 16
    glow.height = m.keyH + 16
    glow.visible = false
    base = g.createChild("Poster")
    base.uri = "pkg:/images/tile.9.png"
    base.width = w
    base.height = m.keyH
    lab = g.createChild("Label")
    lab.width = w
    lab.height = m.keyH
    lab.horizAlign = "center"
    lab.vertAlign = "center"
    icon = g.createChild("Poster")
    icon.width = 32
    icon.height = 32
    icon.translation = [26, 19]
    icon.visible = false
    return g
end function

sub setKeyLabel(g as object, text as string)
    lab = g.getChild(2)
    icon = g.getChild(3)
    size = 34
    if Len(text) > 1 then size = 26
    if Len(text) > 5 then size = 19
    lab.font = hFont("bold", size)
    lab.text = text
    icons = { Space: "space", Delete: "backspace", Clear: "clear" }
    w = g.getChild(1).width
    if icons[text] <> invalid
        ' icon on the left, word beside it
        icon.uri = "pkg:/images/icons/" + icons[text] + ".png"
        icon.visible = true
        lab.horizAlign = "left"
        lab.translation = [68, 0]
        lab.width = w - 76
    else
        icon.visible = false
        lab.horizAlign = "center"
        lab.translation = [0, 0]
        lab.width = w
    end if
end sub

sub labelKeys()
    chars = m.pages[m.page]
    for r = 0 to 5
        for c = 0 to 5
            ch = chars[r * 6 + c]
            if m.page = 0 then ch = UCase(ch)
            setKeyLabel(m.keyNodes[r][c], ch)
        end for
    end for
    labels = wideLabels()
    for k = 0 to 2
        setKeyLabel(m.wideNodes[k], labels[k])
    end for
end sub

function wideLabels() as object
    if m.top.mode = "full"
        if m.page = 0 then return ["#+=", "Space", "Delete"]
        return ["ABC", "Space", "Delete"]
    end if
    return ["Space", "Delete", "Clear"]
end function

sub onMode()
    ' full mode types keys and addresses (an Overseerr key is about 68 characters): lift the 40 character search limit
    if m.top.mode = "full" and m.top.maxLength = 40 then m.top.maxLength = 120
    m.page = 0
    labelKeys()
    paint()
end sub

' ---------- text and predictions ----------

sub onText()
    t = m.top.text
    if t = ""
        m.display.text = m.top.placeholder
        m.display.color = "0xB5AF8C99"
        if m.top.placeholder = "" then m.display.text = "_"
        if m.top.placeholder = "" then m.display.color = "0xE0B34AFF"
    else
        shown = t
        if Len(shown) > 18 then shown = "..." + Right(shown, 17)
        m.display.text = shown + "_"
        m.display.color = "0xE0B34AFF"
    end if
    predict()
end sub

sub onWords()
    m.vocab = []
    m.norm = []
    if m.top.words <> invalid
        for each w in m.top.words
            if w <> invalid and w <> ""
                n = m.cleaner.ReplaceAll(LCase(w), " ").Trim()
                if n <> ""
                    m.vocab.push(w)
                    m.norm.push(" " + n)
                end if
            end if
        end for
    end if
    predict()
end sub

' Suggest whole entries that contain what's typed at a word start, and work out which
' characters could come next so the other keys can be dimmed.
sub predict()
    m.nextSet = invalid
    chips = []
    raw = LCase(m.top.text)
    q = m.cleaner.ReplaceAll(raw, " ")
    while Left(q, 1) = " "
        q = Mid(q, 2)
    end while
    if q <> "" and m.norm.count() > 0
        qn = " " + q
        whole = " " + q.Trim()
        nextSet = {}
        found = false
        starts = []
        inside = []
        seen = {}
        for i = 0 to m.norm.count() - 1
            n = m.norm[i]
            hit = Instr(1, n, qn)
            if hit > 0
                found = true
                ch = Mid(n, hit + Len(qn), 1)
                if ch = " " then nextSet["space"] = true else if ch <> "" then nextSet[ch] = true
                if n <> whole and not seen.doesExist(n)
                    ' keep a pool, then show the shortest: the closest fit to what's typed
                    if hit = 1
                        if starts.count() < 40 then starts.push({ s: m.vocab[i], n: Len(n) })
                    else if inside.count() < 40
                        inside.push({ s: m.vocab[i], n: Len(n) })
                    end if
                    seen[n] = true
                end if
            end if
        end for
        if found and nextSet.count() > 0 then m.nextSet = nextSet
        starts.SortBy("n")
        inside.SortBy("n")
        for each c in starts
            if chips.count() < 3 then chips.push(c.s)
        end for
        for each c in inside
            if chips.count() < 3 then chips.push(c.s)
        end for
    end if
    buildChips(chips)
    paint()
end sub

sub buildChips(list as object)
    m.chipsGroup.removeChildrenIndex(m.chipsGroup.getChildCount(), 0)
    m.chipTexts = []
    x = 0
    for each s in list
        if m.chipTexts.count() >= 3 then exit for
        w = Len(s) * 14 + 44
        if w > m.width then w = m.width
        if x > 0 and x + w > m.width
            ' try a shorter chip only if a decent amount of room is left
            if m.width - x < 150 then exit for
            w = m.width - x
        end if
        g = m.chipsGroup.createChild("Group")
        g.translation = [x, 0]
        base = g.createChild("Poster")
        base.uri = "pkg:/images/pill.9.png"
        base.width = w
        base.height = 52
        lab = g.createChild("Label")
        lab.width = w - 28
        lab.height = 52
        lab.translation = [14, 0]
        lab.horizAlign = "center"
        lab.vertAlign = "center"
        lab.font = hFont("bold", 24)
        lab.text = s
        m.chipTexts.push(s)
        x = x + w + 10
    end for
    if m.chipTexts.count() = 0 and m.zone = "chips" then m.zone = "keys"
    if m.chip >= m.chipTexts.count() then m.chip = 0
end sub

' ---------- painting ----------

sub paint()
    if m.keyNodes = invalid then return
    on = m.top.active
    for r = 0 to 5
        for c = 0 to 5
            ch = m.pages[m.page][r * 6 + c]
            lit = true
            if m.page = 0 and m.nextSet <> invalid then lit = m.nextSet.doesExist(ch)
            paintKey(m.keyNodes[r][c], on and m.zone = "keys" and m.r = r and m.c = c, lit)
        end for
    end for
    for k = 0 to 2
        lit = true
        if wideLabels()[k] = "Space" and m.nextSet <> invalid then lit = m.nextSet.doesExist("space")
        paintKey(m.wideNodes[k], on and m.zone = "keys" and m.r = 6 and (m.c \ 2) = k, lit)
    end for
    for i = 0 to m.chipsGroup.getChildCount() - 1
        g = m.chipsGroup.getChild(i)
        focused = (on and m.zone = "chips" and m.chip = i)
        if focused
            g.getChild(0).blendColor = "0xE0B34AFF"
            g.getChild(1).color = "0x1F1606FF"
        else
            g.getChild(0).blendColor = "0x2A2410FF"
            g.getChild(1).color = "0xE0B34AFF"
        end if
    end for
end sub

sub paintKey(g as object, focused as boolean, lit as boolean)
    glow = g.getChild(0)
    base = g.getChild(1)
    lab = g.getChild(2)
    icon = g.getChild(3)
    glow.visible = focused
    if focused
        base.blendColor = "0xE0B34AFF"
        lab.color = "0x1F1606FF"
    else if lit
        base.blendColor = "0x1D2418FF"
        lab.color = "0xEDE6CAFF"
    else
        base.blendColor = "0x12160FFF"
        lab.color = "0xEDE6CA44"
    end if
    icon.blendColor = lab.color
end sub

' ---------- typing ----------

sub typeText(s as string)
    if Len(m.top.text) + Len(s) > m.top.maxLength then return
    m.top.text = m.top.text + s
end sub

sub deleteLetter()
    t = m.top.text
    if t = "" then return
    m.top.text = Left(t, Len(t) - 1)
end sub

sub pressKey()
    if m.r < 6
        typeText(m.pages[m.page][m.r * 6 + m.c])
        return
    end if
    label = wideLabels()[m.c \ 2]
    if label = "Space"
        t = m.top.text
        if t <> "" and Right(t, 1) <> " " then typeText(" ")
    else if label = "Delete"
        deleteLetter()
    else if label = "Clear"
        m.top.text = ""
    else if label = "#+=" or label = "ABC"
        m.page = 1 - m.page
        labelKeys()
    end if
end sub

sub reset(unused = invalid as dynamic)
    m.page = 0
    m.zone = "keys"
    m.r = 0
    m.c = 0
    labelKeys()
    m.top.text = ""
end sub

' Returns "" when the key was used here, otherwise the key (an edge) for the parent.
function handleKey(k as string) as string
    if Left(k, 4) = "Lit_"
        ' full mode types keys and addresses, which are case-sensitive; search mode matches lower case
        if m.top.mode = "full" then typeText(Mid(k, 5)) else typeText(LCase(Mid(k, 5)))
        return ""
    else if k = "backspace"
        deleteLetter()
        return ""
    end if

    if m.zone = "chips"
        n = m.chipTexts.count()
        if k = "left"
            if m.chip > 0 then m.chip = m.chip - 1
        else if k = "right"
            if m.chip < n - 1 then m.chip = m.chip + 1
        else if k = "down"
            m.zone = "keys"
            m.r = 0
        else if k = "OK"
            choice = m.chipTexts[m.chip]
            m.zone = "keys"
            m.top.text = choice
            m.top.picked = choice
        else
            return k
        end if
        paint()
        return ""
    end if

    if k = "up"
        if m.r > 0
            m.r = m.r - 1
        else if m.chipTexts.count() > 0
            m.zone = "chips"
            m.chip = 0
        else
            return "up"
        end if
    else if k = "down"
        if m.r = 6 then return "down"
        m.r = m.r + 1
    else if k = "left"
        if m.r = 6
            if m.c \ 2 = 0 then return "left"
            m.c = (m.c \ 2 - 1) * 2
        else
            if m.c = 0 then return "left"
            m.c = m.c - 1
        end if
    else if k = "right"
        if m.r = 6
            if m.c \ 2 = 2 then return "right"
            m.c = (m.c \ 2 + 1) * 2
        else
            if m.c = 5 then return "right"
            m.c = m.c + 1
        end if
    else if k = "OK"
        pressKey()
    else
        return k
    end if
    paint()
    return ""
end function
