' Saved keys on the NAS helper (GET <nas>/api/keys, the file tools/remote/sync-keys.sh writes).
' These block for up to 5 s, so call them only from main() or a Task thread, never from a screen.

' The helper's saved keys as an associative array, or invalid (with the reason in the log).
function hNasKeys() as dynamic
    reg = CreateObject("roRegistrySection", "hearth")
    nas = reg.Read("nasUrl")
    if nas = "" then nas = "http://192.168.254.41:8765"
    port = CreateObject("roMessagePort")
    x = CreateObject("roUrlTransfer")
    x.setMessagePort(port)
    x.setUrl(nas + "/api/keys")
    if not x.asyncGetToString()
        print "[hearth-keys] couldn't start the request to "; nas
        return invalid
    end if
    msg = wait(5000, port)
    if type(msg) <> "roUrlEvent"
        x.asyncCancel()
        print "[hearth-keys] the NAS helper at "; nas; " didn't answer in 5 s"
        return invalid
    end if
    code = msg.getResponseCode()
    if code <> 200
        why = ""
        if code = 401 or code = 403 then why = " (the helper only trusts the TV's address: has the TV's IP changed?)"
        print "[hearth-keys] the NAS helper said "; code; why
        return invalid
    end if
    d = ParseJson(msg.getString())
    if d = invalid or type(d) <> "roAssociativeArray"
        print "[hearth-keys] the NAS helper's answer wasn't a key list"
        return invalid
    end if
    return d
end function

' A service said the saved key is wrong (401/403): if the NAS helper holds a different one, save it
' on the TV and return it. Returns "" when there is nothing better.
function hKeyFromNas(name as string, current as string) as string
    d = hNasKeys()
    if d = invalid then return ""
    k = d[name]
    t = type(k)
    if (t <> "String" and t <> "roString") or k = "" or k = current then return ""
    reg = CreateObject("roRegistrySection", "hearth")
    reg.Write(name, k)
    reg.Flush()
    print "[hearth-keys] "; name; " refreshed from the NAS helper"
    return k
end function

' Fill in every key the TV is missing. Returns the names it wrote.
function hFillKeysFromNas() as object
    wrote = []
    d = hNasKeys()
    if d = invalid then return wrote
    reg = CreateObject("roRegistrySection", "hearth")
    names = ["plexToken", "plexServer", "plexServerToken", "plexServerName", "overseerrUrl", "overseerrKey", "lidarrUrl", "lidarrKey", "bazarrUrl", "bazarrKey", "radarrUrl", "radarrKey", "sonarrUrl", "sonarrKey", "haUrl", "haToken", "haEntity", "lastfmOn"]
    for each k in names
        ' fill in only what the TV is missing; a key typed or sent later always wins
        t = type(d[k])
        if (t = "String" or t = "roString") and d[k] <> "" and reg.Read(k) = ""
            reg.Write(k, d[k])
            wrote.push(k)
        end if
    end for
    if wrote.count() > 0 then reg.Flush()
    return wrote
end function
