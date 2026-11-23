' Playback planning for Plex movies and episodes: play the file as-is whenever this TV can decode it,
' otherwise let Plex repackage it (remux) and convert only what the TV can't handle (usually the audio).
' A full video convert is the last resort: the DS923+ has no GPU for it, which is what made playback stutter.
'
' Every decision is printed to the debug console with the prefix [hearth-play], so you can see what happened:
'   nc 192.168.254.9 8085

' Which video/audio codecs this TV says it can decode. Printed once per app run.
sub hPlayLogCaps()
    if m.global.hasField("hPlayCapsLogged") then return
    m.global.addFields({ hPlayCapsLogged: true })
    di = CreateObject("roDeviceInfo")
    print "[hearth-play] TV "; di.GetModel(); " OS "; di.GetOSVersion().major; "."; di.GetOSVersion().minor; " video mode "; di.GetVideoMode()
    vids = [["h264", "mpeg4 avc", "high"], ["h264 10-bit", "mpeg4 avc", "high 10"], ["hevc", "hevc", "main"], ["hevc 10-bit/HDR", "hevc", "main 10"], ["vp9", "vp9", ""], ["av1", "av1", ""], ["mpeg2", "mpeg2", ""], ["mpeg4 part 2 (xvid)", "mpeg4 part 2", ""], ["vc1", "vc1", ""]]
    line = "[hearth-play] video:"
    for each v in vids
        q = { Codec: v[1] }
        if v[2] <> "" then q.Profile = v[2]
        line = line + " " + v[0] + "=" + yesNo(di.CanDecodeVideo(q).result)
    end for
    print line
    line = "[hearth-play] audio:"
    for each a in ["aac", "mp3", "ac3", "eac3", "dts", "truehd", "flac", "alac", "opus", "vorbis", "pcm", "mp2"]
        line = line + " " + a + "=" + yesNo(di.CanDecodeAudio({ Codec: a }).result)
    end for
    print line
end sub

function yesNo(b as dynamic) as string
    if b = true then return "yes"
    return "no"
end function

function pStr(v as dynamic) as string
    if v = invalid then return ""
    return LCase(v.toStr())
end function

' The streams Plex will use: the selected (or first) video, audio and subtitle stream of the part.
function hPlayStreams(part as object) as object
    out = { video: invalid, audio: invalid, sub: invalid, embeddedTextSub: false }
    if part = invalid or part.Stream = invalid then return out
    for each s in part.Stream
        if s.streamType = 1 and out.video = invalid then out.video = s
        if s.streamType = 2
            if out.audio = invalid or s.selected = true then out.audio = s
        end if
        if s.streamType = 3 and s.selected = true then out.sub = s
    end for
    if out.sub <> invalid and out.sub.key = invalid and hPlayTextSub(pStr(out.sub.codec)) then out.embeddedTextSub = true
    return out
end function

function hPlayTextSub(codec as string) as boolean
    return (codec = "srt" or codec = "subrip" or codec = "vtt" or codec = "webvtt" or codec = "mov_text" or codec = "tx3g" or codec = "ass" or codec = "ssa" or codec = "smi")
end function

' Roku names for Plex's codec names
function rokuVideoCodec(v as string) as string
    if v = "h264" or v = "avc" then return "mpeg4 avc"
    if v = "hevc" or v = "h265" then return "hevc"
    if v = "mpeg4" then return "mpeg4 part 2"
    return v
end function

function rokuAudioCodec(a as string) as string
    if a = "dca" or a = "dts-hd ma" or a = "dts-hd" then return "dts"
    if a = "pcm_s16le" or a = "pcm_s24le" or a = "lpcm" then return "pcm"
    return a
end function

' Highest video height this TV is outputting (4K TVs report a 2160 video mode).
function hPlayMaxHeight() as integer
    mode = LCase(CreateObject("roDeviceInfo").GetVideoMode())
    if Instr(1, mode, "2160") > 0 or Instr(1, mode, "4k") > 0 then return 2160
    return 1080
end function

' Can the TV play this file straight from the NAS? Returns { ok, why } where why says what blocks it.
function hPlayDirectCheck(media as object, st as object) as object
    di = CreateObject("roDeviceInfo")
    c = pStr(media.container)
    if not (c = "mp4" or c = "m4v" or c = "mov" or c = "mkv")
        return { ok: false, why: "container " + c }
    end if
    v = pStr(media.videoCodec)
    q = { Codec: rokuVideoCodec(v), Container: c }
    if c = "m4v" or c = "mov" then q.Container = "mp4"
    if st.video <> invalid and st.video.profile <> invalid then q.Profile = pStr(st.video.profile)
    r = di.CanDecodeVideo(q)
    if r.result <> true and q.Profile <> invalid
        ' Plex and Roku name some profiles differently; trust the codec check, but never for 10-bit
        p = q.Profile
        q.delete("Profile")
        if Instr(1, p, "10") = 0 then r = di.CanDecodeVideo(q)
    end if
    if r.result <> true
        why = "video " + v
        if st.video <> invalid and st.video.profile <> invalid then why = why + " (" + pStr(st.video.profile) + ")"
        return { ok: false, why: why }
    end if
    h = 0
    if media.height <> invalid then h = media.height
    if h > hPlayMaxHeight() + 8 then return { ok: false, why: "resolution " + h.toStr() + "p on a " + hPlayMaxHeight().toStr() + "p screen" }
    a = pStr(media.audioCodec)
    if st.audio <> invalid and st.audio.codec <> invalid then a = pStr(st.audio.codec)
    if a <> ""
        if di.CanDecodeAudio({ Codec: rokuAudioCodec(a) }).result <> true then return { ok: false, why: "audio " + a }
    end if
    return { ok: true, why: "" }
end function

' Query for Plex's HLS remux. Video is copied when the TV can decode it (h264, and hevc when supported);
' audio is converted to AC3/E-AC3/AAC only when needed. subs is "none" or "auto".
function hPlayHlsQuery(itemId as string, startSec as dynamic, subs as string, session as string, token as string) as string
    di = CreateObject("roDeviceInfo")
    vcodecs = "h264"
    if di.CanDecodeVideo({ Codec: "hevc" }).result = true then vcodecs = "h264,hevc"
    acodecs = "aac"
    if di.CanDecodeAudio({ Codec: "ac3" }).result = true then acodecs = acodecs + ",ac3"
    if di.CanDecodeAudio({ Codec: "eac3" }).result = true then acodecs = acodecs + ",eac3"
    res = "1920x1080"
    if hPlayMaxHeight() >= 2160 then res = "3840x2160"
    quality = "&videoQuality=100&maxVideoBitrate=200000"
    if m.hlsLight
        ' Plex has to convert the video anyway: 720p at 3 Mbps is what the DS923+ CPU can keep up with in real time
        res = "1280x720"
        quality = "&videoQuality=60&maxVideoBitrate=3000"
    end if
    extra = "add-transcode-target(type=videoProfile&context=streaming&protocol=hls&container=mpegts&videoCodec=" + vcodecs + "&audioCodec=" + acodecs + ")"
    if Instr(1, vcodecs, "hevc") > 0 then extra = extra + "+append-transcode-target-codec(type=videoProfile&context=streaming&protocol=hls&videoCodec=hevc)"
    extra = extra + "+add-transcode-target-audio-codec(type=videoProfile&context=streaming&protocol=hls&audioCodec=" + acodecs + ")"
    q = "path=" + hEscape("/library/metadata/" + itemId) + "&mediaIndex=0&partIndex=0&protocol=hls&fastSeek=1&copyts=1"
    ' copy video whenever possible; the LAN can carry a full-quality file, so don't trigger a convert for size
    q = q + "&directPlay=0&directStream=1&directStreamAudio=1&videoResolution=" + res + quality
    q = q + "&offset=" + Int(startSec).toStr() + "&subtitles=" + subs + "&session=" + hEscape(session)
    q = q + "&X-Plex-Client-Identifier=" + hEscape(m.global.deviceId) + "&X-Plex-Product=Hearth&X-Plex-Platform=Roku&X-Plex-Token=" + token
    q = q + "&X-Plex-Client-Profile-Extra=" + hEscape(extra)
    return q
end function
