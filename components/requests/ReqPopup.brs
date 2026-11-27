sub init()
    m.top.findNode("eyebrow").font = hFont("caps", 26)
    m.top.findNode("rating").font = hFont("caps", 26)
    m.top.findNode("title").font = hFont("caps", 64)
    m.top.findNode("overview").font = hFont("regular", 24)
    m.items = m.top.findNode("items")
    m.btnFont = hFont("bold", 28)
    m.subFont = hFont("regular", 22)
    m.tagFont = hFont("caps", 22)
    m.sel = 0
    m.list = []
end sub

sub build()
    md = m.top.model
    if md = invalid then return
    eb = m.top.findNode("eyebrow")
    eb.text = md.eyebrow
    star = m.top.findNode("star")
    rating = m.top.findNode("rating")
    hasRating = (md.rating <> invalid and md.rating <> "")
    star.visible = hasRating
    rating.visible = hasRating
    if hasRating
        x = eb.boundingRect().width + 14
        star.translation = [x, 4]
        rating.translation = [x + 30, 0]
        rating.text = md.rating
    end if
    ' title: 64, then 52 on one line; longer takes two lines at 44 and everything under it moves down
    ttl = md.title
    if ttl = invalid then ttl = ""
    fit = hFitTitle2(m.top.findNode("title"), UCase(ttl), "caps", [64, 52, 44], 660)
    m.top.findNode("title").translation = [0, 34 + fit.drop]
    m.push = 0
    if fit.lines = 2 then m.push = fit.height - 80
    if m.push < 0 then m.push = 0
    ov = md.overview
    if ov = invalid then ov = ""
    m.top.findNode("overview").text = ov
    m.top.findNode("overview").translation = [0, 124 + m.push]
    m.items.translation = [0, 250 + m.push]
    m.top.findNode("poster").uri = md.poster
    m.list = md.items
    m.sel = 0
    ' first selectable item
    drawItems()
    ' hints under the list
    hints = m.top.findNode("hints")
    hints.removeChildrenIndex(hints.getChildCount(), 0)
    y = 250 + m.push + m.list.count() * 84 + 14
    hints.translation = [0, y]
    x = 0
    if md.hints <> invalid
        for each h in md.hints
            ic = hints.createChild("Poster")
            ic.uri = "pkg:/images/requests/" + h.icon + ".png"
            ic.width = 22
            ic.height = 22
            ic.blendColor = "0xB5AF8CFF"
            ic.translation = [x, 3]
            lab = hints.createChild("Label")
            lab.font = m.subFont
            lab.color = "0xB5AF8CFF"
            lab.text = h.text
            lab.translation = [x + 30, 0]
            x = x + 30 + lab.boundingRect().width + 36
        end for
    end if
    m.listH = 50 + y + 40 + 50
    m.top.findNode("scoreCard").visible = false
    m.cardH = 0
    layoutPanel()
end sub

' The panel is as tall as the list, or as the poster plus the score card under it
sub layoutPanel()
    h = m.listH
    if h < 550 then h = 550
    if m.cardH > 0 and 520 + m.cardH + 40 > h then h = 520 + m.cardH + 40
    m.top.findNode("panelBg").height = h
    m.top.findNode("panel").translation = [400, Int((930 - h) / 2) - 20]
end sub

sub drawItems()
    m.items.removeChildrenIndex(m.items.getChildCount(), 0)
    y = 0
    for i = 0 to m.list.count() - 1
        it = m.list[i]
        on = (i = m.sel)
        g = m.items.createChild("Group")
        g.translation = [0, y]
        bg = g.createChild("Poster")
        bg.uri = "pkg:/images/pill.9.png"
        bg.width = 660
        bg.height = 68
        if on then bg.blendColor = "0xE0B34AFF" else bg.blendColor = "0xFFFFFF12"
        ink = "0xEDE6CAFF"
        if on then ink = "0x1F1606FF"
        x = 30
        if it.check <> invalid
            tick = g.createChild("Poster")
            tick.uri = "pkg:/images/requests/" + iif(isTrue(it.check), "boxcheck", "box") + ".png"
            tick.width = 30
            tick.height = 30
            tick.translation = [x, 19]
            tick.blendColor = ink
            x = x + 46
        else if it.icon <> invalid
            ic = g.createChild("Poster")
            ic.uri = "pkg:/images/requests/" + it.icon + ".png"
            ic.width = 28
            ic.height = 28
            ic.translation = [x, 20]
            ic.blendColor = ink
            x = x + 46
        end if
        lab = g.createChild("Label")
        lab.font = m.btnFont
        lab.color = ink
        lab.text = it.label
        lab.height = 68
        lab.vertAlign = "center"
        lab.translation = [x, 0]
        x = x + lab.boundingRect().width + 14
        if it.sub <> invalid and it.sub <> ""
            s = g.createChild("Label")
            s.font = m.subFont
            s.color = ink
            s.opacity = 0.75
            s.text = it.sub
            s.height = 68
            s.vertAlign = "center"
            s.translation = [x, 0]
        end if
        if it.right <> invalid and it.right <> ""
            r = g.createChild("Label")
            r.font = m.tagFont
            if on then r.color = ink else r.color = "0xA3A35AFF"
            r.text = UCase(it.right)
            r.width = 610
            r.height = 68
            r.horizAlign = "right"
            r.vertAlign = "center"
        end if
        y = y + 84
    end for
end sub

function isTrue(v as dynamic) as boolean
    if type(v) = "roBoolean" or type(v) = "Boolean" then return v
    return false
end function

function iif(c as boolean, a as string, b as string) as string
    if c then return a
    return b
end function

function handleKey(key as string) as boolean
    n = m.list.count()
    if key = "up"
        if m.sel > 0 then m.sel = m.sel - 1
        drawItems()
    else if key = "down"
        if m.sel < n - 1 then m.sel = m.sel + 1
        drawItems()
    else if key = "OK"
        it = m.list[m.sel]
        if it.check <> invalid
            if not isTrue(it.locked)
                it.check = not isTrue(it.check)
                m.list[m.sel] = it
                drawItems()
                m.top.picked = "toggle"
            end if
        else
            m.top.picked = it.tag
        end if
    else if key = "back"
        m.top.picked = "back"
    end if
    return true
end function

' Tags of ticked items
function checked(unused = invalid as dynamic) as object
    out = []
    for each it in m.list
        if isTrue(it.check) and not isTrue(it.locked) then out.push(it.tag)
    end for
    return out
end function

' Change one item's label (e.g. "Request 2 seasons")
sub setLabel(args as object)
    for i = 0 to m.list.count() - 1
        if m.list[i].tag = args.tag then m.list[i].label = args.label
    end for
    drawItems()
end sub

' Scores from the NAS helper ({ imdb, rt, aud, cert }): one row each under the poster, the number big,
' what it is small on the right. The TMDB star in the eyebrow goes once there is a real score.
sub setScores(v as object)
    g = m.top.findNode("scoreCard")
    g.removeChildrenIndex(g.getChildCount(), 0)
    rows = []
    if v.imdb <> invalid then rows.push({ icon: "pkg:/images/requests/star.png", gold: true, big: rqScore1(v.imdb), small: " / 10", label: "IMDb" })
    if v.rt <> invalid
        lab = "Critics"
        if v.cert = true then lab = "Certified"
        rows.push({ icon: rqTomato(v), big: Int(v.rt).toStr() + "%", small: "", label: lab })
    end if
    if v.aud <> invalid then rows.push({ icon: "pkg:/images/requests/popcorn.png", big: Int(v.aud).toStr() + "%", small: "", label: "Audience" })
    if rows.count() = 0
        g.visible = false
        m.cardH = 0
        layoutPanel()
        return
    end if
    m.top.findNode("star").visible = false
    m.top.findNode("rating").visible = false
    h = 20 + rows.count() * 46
    bg = g.createChild("Poster")
    bg.uri = "pkg:/images/tile.9.png"
    bg.blendColor = "0xFFFFFF10"
    bg.width = 300
    bg.height = h
    y = 10
    for each r in rows
        col = "0xEDE6CAFF"
        ic = g.createChild("Poster")
        ic.uri = r.icon
        ic.width = 28
        ic.height = 28
        ic.translation = [20, y + 9]
        if r.gold = true
            ' IMDb: a gold star and the number in yellow, like on the posters
            col = "0xE0B34AFF"
            ic.blendColor = col
            ic.width = 24
            ic.height = 24
            ic.translation = [22, y + 11]
        end if
        big = g.createChild("Label")
        big.font = m.btnFont
        big.color = col
        big.text = r.big
        big.height = 46
        big.vertAlign = "center"
        x = 62
        big.translation = [x, y]
        if r.small <> ""
            sm = g.createChild("Label")
            sm.font = m.subFont
            sm.color = "0xB5AF8CFF"
            sm.text = r.small
            sm.height = 46
            sm.vertAlign = "center"
            sm.translation = [x + big.boundingRect().width + 4, y + 2]
        end if
        lab = g.createChild("Label")
        lab.font = m.subFont
        lab.color = "0xB5AF8CFF"
        lab.text = r.label
        lab.width = 260
        lab.height = 46
        lab.horizAlign = "right"
        lab.vertAlign = "center"
        lab.translation = [20, y]
        y = y + 46
    end for
    g.visible = true
    m.cardH = h
    layoutPanel()
end sub
