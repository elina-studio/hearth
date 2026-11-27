# Hearth screen and key map (from the code, build 110)

Read from every `hKeyInner` handler on branch `claude/project-thread-y3pfpr`. Key names are the app's:
OK, Back, Up/Down/Left/Right, * (options), Play, Rewind, Fast forward, Replay.
"Media keys" below means Play, Rewind, Fast forward and Replay: outside the player they always control the music
(HearthScene: Play toggles, or shows the Continue ribbon when no music is live; Rewind = previous, Fast forward = next).
Every handler is wrapped by `hKeySfx` (menu sound) and, in the walk build, prints one `HWALK key=` line.

| Screen | Zones (focus areas) | Keys |
|---|---|---|
| **Intro** (lantern) | none | All keys swallowed while it plays; it moves on by itself. |
| **Setup** (Plex sign-in) | buttons | Left/Right move, OK runs New PIN / Find server. Back is passed up (Roku leaves the app: nothing below Setup). |
| **Hub room bar** | pills | Left/Right move round the 8 pills (wraps), Down/OK enter the room, * opens the Hearth menu (Close, Menu sounds, Sign out). Back: to Home pill; on Home asks "Leave Hearth?" (Stay/Leave). |
| **Home** | hero, tonight, dash, rows | Arrows move; OK: hero buttons play/resume/next ep/details or Retry; Tonight plays; dash = music transport, Requests, moods, speakers; rows: Continue plays, Albums play, Requests/Photos rows open those rooms, others open Details. * = item options. Back: to hero, then to the room bar. Speaker sheet takes all keys while open. |
| **Shows / Movies** (LibraryRoom) | buttons, tabs, chips, letters, grid | Grid: arrows, OK opens Details (or a genre), Play plays a playable item, * options. Tabs: Left/Right switch tab, Down/OK to chips. Chips: Left/Right, OK runs the chip, Left at the first chip back to tabs. Letters: Left/Right jump letter. Up from the top leaves to the room bar. Back: leaves a genre, then back to grid, then to the room bar. Loading, "Can't reach Plex" (retries every 15 s) and "no library" states exist. |
| **Details** | bar, act, tabs, eps, below | Back always pops. Bar (rooms): Left/Right, OK jumps to that room. Act: Left/Right buttons, OK runs (Play, Resume, Trailer...), * More sheet, Down to seasons/below. Seasons: Left/Right, OK loads. Episodes: Up/Down, OK plays, Right or * opens the episode sheet. Below rows: Left/Right, OK opens, * options. Season load failure shows a message. |
| **Side sheet** (More, episode sheet) | rows | Up/Down skip headers, Left/Right set stars on a rating row, OK picks, Back/* close. |
| **Player** | video, pause overlay, sheet, chapters, up next | OK/Play pause and open the pause screen; Up/Down peek; Left/Right/Rewind/FF/Replay peek and seek; * opens Subtitles. Back: closes what is open, then leaves the player. Skip intro: OK when the Skip button shows. |
| **Pause overlay** | bar, big, chips | Bar: Left -10 s / Right +30 s (held = repeat), OK toggles or commits a scrub, Down to the big buttons. Big buttons: Back 10 s, Play/Pause, Ahead 30 s, [Next episode]; Down to the chips, Up to the bar. Chips: Subtitles, Audio, [Chapters], [Episodes], Quality, Sleep, More (a Hearth sheet: what is playing, mark watched); Up to the big buttons. Rewind/FF scrub, Replay -10 s, Back cancels scrub then closes. |
| **Player sheet** (subs, audio, quality, info, sleep) | rows | Up/Down move, Left/Right step/pick, Left on a plain row closes, OK on a row acts, Back closes. Play still pauses. |
| **Subtitle finder** | tabs, chips, list | Left/Right switch tabs, Down into chips/list, OK picks/downloads, Back/* close. |
| **Chapters strip** | cells | Left/Right, OK jumps, Back/Up close. |
| **Up next card** | 2 buttons | Left/Right, OK plays or dismisses, * toggles autoplay, Back dismisses. |
| **Music room** | panel, tabs, letters, banner, content, queue | Panel (now playing): its own keys; Right leaves to the right side. Tabs: For you, Artists, Albums, Playlists, New, Discover, Radio*, Request* (*OK opens a screen). Up leaves to the room bar. * opens the Music menu (Shuffle, Repeat, More like this, Radio, Lyrics, Last.fm, Schedules, Library switch, Cover, Visualizer, Hearth fire, Close). Back closes casting, else to the room bar. Media keys control music. |
| **Artist page** | top, albums, abtn, songs, bar | Up/Down albums, Right/OK into songs, * album options, Back to albums then out. |
| **Music views** (cover, visualizer, hearth) | none | Up toggles lyrics (not cover), Left/Right nudge lyrics (hearth) or change preset (visualizer), * menu, Back leaves. |
| **Big view** | panel | Panel keys, Back leaves. |
| **Radio** | 4 rows | Up/Down rows, Left/Right pick, OK chooses/starts, Back leaves. |
| **Schedules** | 10 rows + buttons | Up/Down rows, Left/Right change values (draft only), OK on Save/Cancel. Saved only by Save. |
| **Last.fm** | items | Up/Down, OK acts, Back leaves. |
| **Music request** (Lidarr) | kb, matches, actions, albums | Keyboard edges move to matches/actions; OK on an album requests it. Back to keyboard, then out. |
| **Requests** | rail, grid, tabs, bar, kb, results, popup, sheet, setup, save | Rail: Up/Down lists (Search, New, Trending, Popular movies, Popular shows, Coming soon, Your requests, Music), Right/OK enter, * filters, Up at the top or Back leaves. Grid: arrows, OK popup, Play plays a New movie. Bar: OK/* filters. Popup and filter sheet take all keys. Pending request: Back undoes it. Setup (no key): type the key, Save. |
| **Ambiance** | moods | Left/Right, OK opens the mood (Window opens Photos), Up/Back to the room bar. |
| **Mood screen** | full screen, controls | Back leaves (also handled by the scene). OK/Down open controls, Left/Right next mood, Up shows the HUD, * sleep menu. Any key wakes it from sleep. |
| **Mood controls** | stops | Left/Right, OK acts, Up/Back close. |
| **Photos** | buttons, albums | Arrows, OK opens the slideshow (or retries when not loaded), Up/Back to the room bar. |
| **Slideshow** | none | Left/Right previous/next, OK pause, Down/* options, Up shows caption, Back leaves. |
| **Photo options** | rows | Left/Right, OK changes, Back/* close. |
| **Search** | kb, results | Keyboard edge Up/Back leave to the room bar, Right to results. Results: Up/Down, Right to the Request pill, Left/Back to keyboard, OK opens, * forgets a recent search or opens options. Letters typed anywhere go to the keyboard. |
| **Keyboard** (shared) | chips, keys | Arrows move, OK types/picks a suggestion; returns the edge it left by. |

## What the walk covers

Paths P01 to P17 in `walk.sh`. Every path ends by pressing Back until the room bar is focused (at most 10).
Nothing that changes data is pressed: Request, Sign out, Cancel request, Watched, Rate, Love, schedule Save.

## Not covered on the TV

Screensaver, error and loading states that need the NAS or Plex off, casting, voice and the phone page.
