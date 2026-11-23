sub init()
    m.top.functionName = "runTask"
end sub

function le32(b as object, i as integer) as integer
    return b[i] + b[i + 1] * 256 + b[i + 2] * 65536 + b[i + 3] * 16777216
end function

sub runTask()
    path = "tmp:/hearth-preview.bif"
    xfer = CreateObject("roUrlTransfer")
    xfer.SetUrl(m.top.url)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    code = xfer.GetToFile(path)
    if code <> 200
        print "[hearth-play] no scrub thumbnails (Plex said "; code; "; turn on video preview thumbnails in Plex)"
        return
    end if
    head = CreateObject("roByteArray")
    if not head.ReadFile(path, 0, 64) or head.count() < 64 then return
    if head[0] <> &h89 or head[1] <> &h42 or head[2] <> &h49 or head[3] <> &h46 then return
    count = le32(head, 12)
    interval = le32(head, 16)
    if interval <= 0 then interval = 1000
    idx = CreateObject("roByteArray")
    if not idx.ReadFile(path, 64, (count + 1) * 8) then return
    offs = []
    for i = 0 to count
        offs.push(le32(idx, i * 8 + 4))
    end for
    print "[hearth-play] scrub thumbnails: "; count; " frames every "; interval; " ms"
    ' a fresh folder per video, so a cached frame never shows another video's picture
    fs = CreateObject("roFileSystem")
    if fs.Exists("tmp:/bif") then fs.Delete("tmp:/bif")
    dir = "tmp:/bif/" + Rnd(1000000).toStr()
    fs.CreateDirectory("tmp:/bif")
    fs.CreateDirectory(dir)
    port = CreateObject("roMessagePort")
    m.top.observeField("want", port)
    m.top.observeField("quit", port)
    m.top.ready = true
    while true
        msg = wait(0, port)
        if type(msg) = "roSGNodeEvent"
            if msg.getField() = "quit" then return
            n = Int(m.top.want * 1000 / interval)
            if n < 0 then n = 0
            if n > count - 1 then n = count - 1
            out = dir + "/" + n.toStr() + ".jpg"
            if not fs.Exists(out)
                img = CreateObject("roByteArray")
                if img.ReadFile(path, offs[n], offs[n + 1] - offs[n]) then img.WriteFile(out)
            end if
            m.top.frameAt = n * interval / 1000
            m.top.frameUri = out
        end if
    end while
end sub
