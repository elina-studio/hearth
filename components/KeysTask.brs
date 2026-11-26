sub init()
    m.top.functionName = "runTask"
end sub

sub runTask()
    wrote = hFillKeysFromNas()
    reg = CreateObject("roRegistrySection", "hearth")
    for each k in wrote
        ' the rooms that wait for a key watch these two
        if k = "overseerrKey" or k = "lidarrKey"
            if not m.global.hasField(k)
                f = {}
                f[k] = ""
                m.global.addFields(f)
            end if
            m.global.setField(k, reg.Read(k))
        end if
    end for
    m.top.wrote = wrote
    m.top.done = true
end sub
