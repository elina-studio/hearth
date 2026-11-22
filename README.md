# Hearth

A small Roku channel for a home media setup: Jellyfin movies and shows today; music, requests, ambiance and photos later.

Build: `npx bsc --project bsconfig.json` makes `out/hearth.zip`. Sideload it from the TV's developer installer.

Licensed GPL-2.0 (video playback approach follows jellyfin-roku).

## Ambiance

`components/ambiance/`: the Ambiance room, full-screen moods (Hearth, Rain on the roof, Fireflies, Lights out), and two shared pieces, `MoodScene` (picture only) and `AmbientSound` (the mood's looping sound with its own on/off). The room is five full-height columns split by gold weave rules (`components/ambiance/ambianceData.brs` lists the moods). A mood plays `videos/<mood>.mp4` full screen when the package has it (H.264, looping, its own sound muted with OK), and otherwise falls back to the drawn scene. Drawn art and generated sounds come from `tools/ambiance/` (`sh tools/ambiance/build.sh`). Footage credits go in `ambianceData.brs` and show on screen.
