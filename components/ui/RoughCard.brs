sub init()
end sub

' set width first, then height: height builds it
sub build()
    m.top.removeChildrenIndex(m.top.getChildCount(), 0)
    w = m.top.width
    h = m.top.height
    if w < 120 or h < 120 then return
    D = 16
    L = 160
    C = 40
    fc = m.top.fillColor
    lc = m.top.lineColor
    rect(D, D, w - 2 * D, h - 2 * D, fc)
    nx = Int((w - 2 * C) / L)
    px = Int((w - 2 * C - nx * L) / 2)
    ny = Int((h - 2 * C) / L)
    py = Int((h - 2 * C - ny * L) / 2)
    ex = C + px + nx * L
    ey = C + py + ny * L
    ' the straight stretches beside each corner
    if px > 0
        rect(C, 0, px, D, fc)
        rect(C, h - D, px, D, fc)
    end if
    if w - C - ex > 0
        rect(ex, 0, w - C - ex, D, fc)
        rect(ex, h - D, w - C - ex, D, fc)
    end if
    if py > 0
        rect(0, C, D, py, fc)
        rect(w - D, C, D, py, fc)
    end if
    if h - C - ey > 0
        rect(0, ey, D, h - C - ey, fc)
        rect(w - D, ey, D, h - C - ey, fc)
    end if
    for pass = 0 to 1
        kind = "fill"
        col = fc
        if pass = 1
            kind = "line"
            col = lc
        end if
        piece("tl", kind, 0, 0, C, C, col)
        piece("tr", kind, w - C, 0, C, C, col)
        piece("bl", kind, 0, h - C, C, C, col)
        piece("br", kind, w - C, h - C, C, C, col)
        for i = 0 to nx - 1
            piece("top", kind, C + px + i * L, 0, L, D, col)
            piece("bottom", kind, C + px + i * L, h - D, L, D, col)
        end for
        for i = 0 to ny - 1
            piece("left", kind, 0, C + py + i * L, D, L, col)
            piece("right", kind, w - D, C + py + i * L, D, L, col)
        end for
    end for
    if px > 0
        rect(C, 0, px, 2, lc)
        rect(C, h - 2, px, 2, lc)
    end if
    if w - C - ex > 0
        rect(ex, 0, w - C - ex, 2, lc)
        rect(ex, h - 2, w - C - ex, 2, lc)
    end if
    if py > 0
        rect(0, C, 2, py, lc)
        rect(w - 2, C, 2, py, lc)
    end if
    if h - C - ey > 0
        rect(0, ey, 2, h - C - ey, lc)
        rect(w - 2, ey, 2, h - C - ey, lc)
    end if
end sub

sub rect(x as integer, y as integer, w as integer, h as integer, col as string)
    r = m.top.createChild("Rectangle")
    r.translation = [x, y]
    r.width = w
    r.height = h
    r.color = col
end sub

sub piece(name as string, kind as string, x as integer, y as integer, w as integer, h as integer, col as string)
    p = m.top.createChild("Poster")
    p.uri = "pkg:/images/w/rough/" + name + "-" + kind + ".png"
    p.translation = [x, y]
    p.width = w
    p.height = h
    p.blendColor = col
end sub
