' Calls to the Hearth helper on the NAS. Included by anything that needs it; the callback gets the finished NasTask.
function nasBase() as string
    b = CreateObject("roRegistrySection", "hearth").Read("nasUrl")
    if b = "" then b = "http://192.168.254.41:8765"
    return b
end function

function nasCall(method as string, path as string, body as string, cb as string, tag = "" as string) as object
    t = CreateObject("roSGNode", "NasTask")
    t.method = method
    t.path = path
    t.bodyText = body
    t.tag = tag
    t.observeField("done", cb)
    if m.hTasks = invalid then m.hTasks = {}
    key = "n" + Rnd(1000000).toStr()
    m.hTasks[key] = t
    t.key = key
    t.control = "RUN"
    return t
end function
