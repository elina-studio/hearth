sub build()
    row = m.top.findNode("row")
    row.removeChildrenIndex(row.getChildCount(), 0)
    x = 0
    items = m.top.keys
    if items = invalid then return
    font = hFont("regular", 24)
    chipFont = hFont("bold", 22)
    ' lay out from the right edge leftwards
    for i = items.count() - 1 to 0 step -1
        k = items[i]
        lab = CreateObject("roSGNode", "Label")
        lab.font = font
        lab.color = "0xEDE6CAFF"
        lab.text = k.label
        w = lab.boundingRect().width
        x = x - w
        lab.translation = [x, 9]
        row.appendChild(lab)
        x = x - 12 - 46
        chip = row.createChild("Poster")
        chip.uri = "pkg:/images/pill.9.png"
        chip.blendColor = "0xEDE6CA2A"
        chip.translation = [x, 0]
        chip.width = 46
        chip.height = 46
        if k.icon <> invalid
            ic = row.createChild("Poster")
            ic.uri = "pkg:/images/icons/icon-" + k.icon + ".png"
            ic.blendColor = "0xEDE6CAFF"
            ic.width = 26
            ic.height = 26
            ic.translation = [x + 10, 10]
        else
            t = row.createChild("Label")
            t.font = chipFont
            t.color = "0xEDE6CAFF"
            t.text = k.text
            t.width = 46
            t.height = 46
            t.horizAlign = "center"
            t.vertAlign = "center"
            t.translation = [x, 0]
        end if
        x = x - 30
    end for
end sub

