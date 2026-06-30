# Background sound assets

These ambient loops drive Pilcrow's background-sound player (`AmbientPlayer` /
`SoundLibrary`). The player reads two playlists by folder, plus a single break
track:

```
Sounds/
  instrument/    # the "piano" icon — every track in this folder
  nature/        # the "nature" icon — every track in this folder
  break-music.mp3  # plays during Pomodoro breaks
```

`SoundLibrary` enumerates whatever audio files are in `instrument/` and
`nature/` (no fixed names required). The third toolbar icon — "your own music" —
plays a file you pick at runtime and is not bundled. After adding or removing
files, run `xcodegen generate` and rebuild so the bundle is refreshed (the
`Sounds` folder is a folder-reference resource).

## Provenance & license

All bundled tracks were downloaded from **[Pixabay](https://pixabay.com)** and
are used under the **[Pixabay Content License](https://pixabay.com/service/license-summary/)**
(free to use, no attribution required; redistribution of the unmodified file *on
its own* is not permitted — here they are bundled as integrated app assets, not
offered as a standalone audio pack). Each filename keeps its original uploader
slug and Pixabay content ID; search the ID on pixabay.com to find the source page.

| File | Pixabay uploader | Content ID |
| --- | --- | --- |
| `instrument/clavier-music-beautiful-relaxing-piano-for-videos-239494.mp3` | clavier-music | 239494 |
| `instrument/clavier-music-calm-piano-music-melody-238224.mp3` | clavier-music | 238224 |
| `instrument/clavier-music-lonely-beautiful-piano-music-233867.mp3` | clavier-music | 233867 |
| `instrument/clavier-music-peace-piano-song-216338.mp3` | clavier-music | 216338 |
| `instrument/clavier-music-peaceful-piano-music-519828.mp3` | clavier-music | 519828 |
| `instrument/clavier-music-rainy-noon-relaxing-uplifting-piano-221782.mp3` | clavier-music | 221782 |
| `instrument/clavier-music-reading-soft-piano-221781.mp3` | clavier-music | 221781 |
| `instrument/clavier-music-relaxing-piano-fireplace-354454.mp3` | clavier-music | 354454 |
| `instrument/denis-pavlov-music-piano-amp-cello-beautiful-poetic-music-370131.mp3` | denis-pavlov-music | 370131 |
| `instrument/icsilviu-whispered-memories-piano-and-cello-456449.mp3` | icsilviu | 456449 |
| `instrument/kaazoom-when-we-were-free-soothing-piano-and-cello-361038.mp3` | kaazoom | 361038 |
| `instrument/musicword-forest-river-240225.mp3` | musicword | 240225 |
| `instrument/sunnyscy-peaceful-piano-music-453463.mp3` | sunnyscy | 453463 |
| `instrument/vividillustrate-anxiety-relief-healing-cello-amp-ocean-waves-relaxation-361113.mp3` | vividillustrate | 361113 |
| `nature/soundsforyou-campfire-crackling-fireplace-sound-119594.mp3` | soundsforyou | 119594 |
| `nature/soundsforyou-meditative-rain-114484.mp3` | soundsforyou | 114484 |
| `nature/soundsforyou-rain-in-forest-birds-nature-111405.mp3` | soundsforyou | 111405 |
| `nature/soundsforyou-rain-thunder-sounds-186390.mp3` | soundsforyou | 186390 |
| `break-music.mp3` | Pixabay (renamed locally) | — |

> If you intend to redistribute these audio files outside an integrated app
> build, confirm each track's current Pixabay license on its source page first.
