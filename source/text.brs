' Hearth's fonts have no glyph for some punctuation that shows up in song, album and artist names
' (Plex keeps them exactly as tagged), so the TV drew a box: "Anti☐Pioneer" was "Anti‐Pioneer" with
' U+2010. Swap them for look-alikes the fonts do have. Run on the raw JSON text before ParseJson
' (every task does), or on a single string before showing it. The one helper for the whole app.
function hFixText(s as string) as string
    if s = "" then return s
    for each c in [8208, 8209, 8210, 8213, 8722, 8259]
        s = s.Replace(Chr(c), "-")
    end for
    ' thin, narrow and other odd spaces -> plain space
    for each c in [8199, 8200, 8201, 8202, 8239, 8287, 12288]
        s = s.Replace(Chr(c), " ")
    end for
    ' soft hyphens, invisible joiners and byte-order marks -> nothing
    for each c in [173, 8203, 8204, 8205, 8288, 65279]
        s = s.Replace(Chr(c), "")
    end for
    s = s.Replace(Chr(8242), "'")
    s = s.Replace(Chr(8243), Chr(34))
    s = s.Replace(Chr(8228), ".")
    return s
end function
