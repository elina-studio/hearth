sub init()
    m.audio = m.top.findNode("audio")
    m.audio.loop = true
    m.sfx = m.top.findNode("sfx")
    m.sfx.observeField("state", "onSfxState")
    m.audio.observeField("state", "onAudioState")
    m.uri = ""
    ' follow the shared music player, when the Music room provides one
    if m.global.hasField("music") and m.global.music <> invalid
        m.global.music.observeField("state", "update")
    end if
end sub

' the file name for a mood (lights out reuses the embers of the fire)
function soundName() as string
    md = m.top.mood
    if md = "hearth" or md = "lightsout" then return "fire"
    if md = "rain" then return "rain"
    if md = "fireflies" then return "night"
    return ""
end function

function musicPlaying() as boolean
    if not m.global.hasField("music") then return false
    mu = m.global.music
    if mu = invalid then return false
    return (mu.state = "playing")
end function

sub update()
    name = soundName()
    want = m.top.on and m.top.active and name <> ""
    prev = m.top.backend
    if not want
        nxt = "off"
    else if musicPlaying() or m.audioBroken = true
        nxt = "sfx"
    else
        nxt = "audio"
    end if
    ' switch the field first, so the state observers see where we are going
    m.top.backend = nxt
    if prev = "audio" and nxt <> "audio"
        m.audio.control = "stop"
        m.uri = ""
    end if
    if prev = "sfx" and nxt <> "sfx" then m.sfx.control = "stop"
    if nxt = "sfx"
        uri = "pkg:/sounds/" + name + "-loop.wav"
        if prev <> "sfx" or m.sfx.uri <> uri
            m.sfx.uri = uri
            m.sfx.control = "play"
        end if
    else if nxt = "audio"
        uri = "pkg:/sounds/" + name + ".mp3"
        if prev <> "audio" or m.uri <> uri
            c = CreateObject("roSGNode", "ContentNode")
            c.url = uri
            c.streamFormat = "mp3"
            m.audio.content = c
            m.uri = uri
            m.audio.control = "play"
        end if
    end if
end sub

' SoundEffect has no loop field: start it again whenever it finishes
sub onSfxState()
    st = m.sfx.state
    print "[ambiance] sfx state "; st
    if m.top.backend = "sfx" and (st = "finished" or st = "stopped")
        m.sfx.control = "play"
    end if
end sub

sub onAudioState()
    print "[ambiance] audio state "; m.audio.state
    ' if this TV won't play the mp3 from the package, use the SoundEffect loop instead
    if m.audio.state = "error" and m.top.backend = "audio"
        print "[ambiance] audio error: "; m.audio.errorMsg
        m.audioBroken = true
        m.top.backend = "off"
        update()
        return
    end if
    ' the music player can take the audio pipeline; if ours was stopped by it, fall back to the SoundEffect
    if m.top.backend = "audio" and m.audio.state = "stopped" and musicPlaying()
        m.top.backend = "off"
        update()
    end if
end sub
