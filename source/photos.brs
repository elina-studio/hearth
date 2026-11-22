' Photos room helpers. Photos come from a NAS folder that Plex serves as a
' Photos library, so they use Hearth's Plex sign-in.
' The optional Home Assistant weather settings live in the registry, sent from a
' computer with an ECP launch command (never in the code or the zip).

function pSettingKeys() as object
    return ["haUrl", "haToken", "haEntity"]
end function

' Save any settings found in launch or input arguments. Returns true if something changed.
function pSaveSettings(args as dynamic) as boolean
    if args = invalid or type(args) <> "roAssociativeArray" then return false
    reg = CreateObject("roRegistrySection", "hearth")
    changed = false
    for each k in pSettingKeys()
        v = args[k]
        if v <> invalid and type(v) <> "roAssociativeArray"
            v = v.toStr().trim()
            if k = "haUrl"
                if v.right(1) = "/" then v = v.left(Len(v) - 1)
                if v <> "" and Left(LCase(v), 4) <> "http" then v = "http://" + v
            end if
            if v = "" or LCase(v) = "clear" then reg.Delete(k) else reg.Write(k, v)
            changed = true
        end if
    end for
    if changed then reg.Flush()
    return changed
end function

function pCfg() as object
    reg = CreateObject("roRegistrySection", "hearth")
    c = {}
    for each k in pSettingKeys()
        v = reg.Read(k)
        if v = invalid then v = ""
        c[k] = v
    end for
    if c.haUrl = "" then c.haUrl = "http://192.168.254.41:8123"
    if c.haEntity = "" then c.haEntity = "weather.forecast_home"
    return c
end function

' The Plex photo library (the NAS photos folder), or ""
function pLibrary() as string
    libs = m.global.libraries
    if libs = invalid or libs.photos = invalid then return ""
    return libs.photos.toStr()
end function

' A photo (or album cover) sized for the TV, through Plex's photo transcoder
function pPhotoUrl(item as object, w as integer, h as integer) as string
    if item = invalid or item.path = invalid or item.path = "" then return ""
    x = CreateObject("roUrlTransfer")
    return m.global.plexServer + "/photo/:/transcode?width=" + w.toStr() + "&height=" + h.toStr() + "&minSize=0&upscale=0&url=" + x.Escape(item.path) + "&X-Plex-Token=" + m.global.plexServerToken
end function

' Start a PhotoTask (see PhotoTask.brs). cb takes the event.
function pPhotos(op as string, args as object, cb as string, tag = "" as string) as object
    t = CreateObject("roSGNode", "PhotoTask")
    t.op = op
    t.args = args
    t.tag = tag
    t.observeField("done", cb)
    if m.pTasks = invalid then m.pTasks = {}
    key = "p" + Rnd(1000000).toStr()
    t.key = key
    m.pTasks[key] = t
    t.control = "RUN"
    return t
end function

' Home Assistant call (weather), or a keep-awake ping when path is ""
function pHa(path as string, cb as string, keepAwake = false as boolean) as object
    t = CreateObject("roSGNode", "HaTask")
    t.path = path
    t.keepAwake = keepAwake
    if cb <> "" then t.observeField("done", cb)
    t.control = "RUN"
    if m.pTasks = invalid then m.pTasks = {}
    key = "p" + Rnd(1000000).toStr()
    t.key = key
    m.pTasks[key] = t
    if cb = "" then t.observeField("done", "pRelease")
    return t
end function

sub pRelease(event as object)
    pTaskFrom(event)
end sub

function pTaskFrom(event as object) as object
    t = event.getRoSGNode()
    if m.pTasks <> invalid and t.key <> invalid then m.pTasks.delete(t.key)
    return t
end function

function pMonthName(n as integer) as string
    names = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    if n < 1 or n > 12 then return ""
    return names[n - 1]
end function

' "March 2019" from the date Plex read out of the photo (when it has one)
function pPhotoCaption(item as object) as string
    if item = invalid or item.date = invalid then return ""
    d = item.date
    if Len(d) >= 7
        mo = pMonthName(Mid(d, 6, 2).toInt())
        if mo <> "" then return mo + " " + Left(d, 4)
    end if
    return Left(d, 4)
end function

' Weather words for Home Assistant conditions
function pWeatherWord(s as string) as string
    w = {
        "clear-night": "clear", cloudy: "cloudy", exceptional: "unusual weather", fog: "fog", hail: "hail",
        lightning: "lightning", "lightning-rainy": "thunderstorms", partlycloudy: "partly cloudy", pouring: "heavy rain",
        rainy: "rain", snowy: "snow", "snowy-rainy": "sleet", sunny: "sunny", windy: "windy", "windy-variant": "windy and cloudy"
    }
    v = w[s]
    if v = invalid then return s
    return v
end function
