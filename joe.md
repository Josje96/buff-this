# Joe's Tasks

## Pixel Art Specs

### Grid & Tile
| Thing              | Size (px) |
|--------------------|-----------|
| Tile (solid/hazard)| 40 × 40   |
| Player             | 28 × 36   |
| Enemy (patrol)     | 28 × 32   |
| Stalactite fixture | 40 × 40   |
| Stalactite spike   | 8 × 22    |

Draw at 1x pixel = 1 game pixel. The engine uses nearest-neighbour filtering
so pixel art will stay crisp at any resolution.

---

## Biome Background Images

Each biome needs one background tile that the engine will loop (tile) to fill
the level and parallax at 30% camera speed.

**Spec:**
- Size: **320 × 180 px**
- Format: PNG, 24-bit (transparency optional)
- Seamlessly tileable on both axes
- Save to: `assets/backgrounds/<biome>.png`

| File                           | Biome   | Mood / Feel        |
|--------------------------------|---------|--------------------|
| assets/backgrounds/forest.png  | forest  | Dark woods, vines  |
| assets/backgrounds/ocean.png   | ocean   | Deep water, bubbles|
| assets/backgrounds/lava.png    | lava    | Volcanic, embers   |
| assets/backgrounds/night.png   | night   | City skyline, stars|
| assets/backgrounds/candy.png   | candy   | Bright, pastel     |
| assets/backgrounds/desert.png  | desert  | Dunes, distant sun |
| assets/backgrounds/neon.png    | neon    | Cyberpunk grid     |
| assets/backgrounds/ice.png     | ice     | Snowflakes, frost  |
| assets/backgrounds/void.png    | void    | Space, nebula      |

The engine will show a solid colour (existing palette bg) for any biome that
doesn't have a file yet, so you can add them one at a time.

---

## Soundtrack
- [ ] Compose and export tracks (per biome or per zone — your call)
- Suggested format: OGG Vorbis, loopable
- Drop files into `assets/music/` when ready and ping to wire them up
