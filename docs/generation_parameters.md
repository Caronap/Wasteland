# Generation Parameters

## World Bounds

| Parameter | Value |
|---|---:|
| City rebuild min X/Z | -80 |
| City rebuild max X/Z | 80 |
| City rebuild min Y | 0 |
| City rebuild max Y | 36 |
| Spawn origin | `(0, 4, 0)` |
| City center | `(0, 0)` |

## Zones

| Zone | Radius | Purpose |
|---|---:|---|
| CBD | 24 | Dense high-rise center, best loot, low danger building count |
| Residential | 45 | Huts, apartments, yards, medium loot, more dangerous buildings |
| Factory | 65 | Warehouses, walls, smokestacks, industrial loot, high danger, bear chance |
| City Edge | 80 | Sparse ruins, farmland, wildlife, low loot, guaranteed bear |

## Roads

| Road | Bounds |
|---|---|
| North-south main road | `x=-6..6`, `z=-76..76`, `y=1` |
| East-west main road | `x=-76..76`, `z=-6..6`, `y=1` |
| North belt road | `x=-42..42`, `z=-42..-38`, `y=1` |
| South belt road | `x=-42..42`, `z=38..42`, `y=1` |
| West belt road | `x=-42..-38`, `z=-42..42`, `y=1` |
| East belt road | `x=38..42`, `z=-42..42`, `y=1` |

## Buildings

| Structure | Position | Size/Params | Material |
|---|---|---|---|
| Villager hut | `(10, -9)` | `7x6` base, `3` wall height, layered roof | rotted wood, rubble |
| Template tower A | `(-23, -23)` | `2x3x8`, actual body `14x18x24` | bedrock |
| Template tower B | `(4, 14)` | `1x3x6`, actual body `7x18x18` | bedrock |
| Template tower C | `(-21, 9)` | `1x1x3`, actual body `7x6x9` | bedrock |
| CBD box A | `(16, -22)` | `9x8x10` | bedrock |
| CBD box B | `(-8, 18)` | `10x8x8` | bedrock |
| Residential hut A | `(28, -18)` | villager hut | rotted wood, rubble |
| Residential hut B | `(-36, 18)` | villager hut | rotted wood, rubble |
| Residential apartment A | `(27, 15)` | `10x8x5` | rotted wood |
| Residential apartment B | `(-45, -24)` | `9x7x4` | rotted wood |
| Factory complex W | `(-68, -28)` | warehouse `16x10x7`, warehouse `12x8x6`, chimney `3x3x14` | scrap metal, rubble |
| Factory complex E | `(44, 34)` | warehouse `16x10x7`, warehouse `12x8x6`, chimney `3x3x14` | scrap metal, rubble |
| Edge farm | `x=-72..-56`, `z=-8..8` | crop rows every 4 nodes | dry grass, rotted wood |
| Edge ruin | `(58, -56)` | `8x7x4` | rubble |

## Template Building Internals

| Feature | Parameter |
|---|---|
| Base unit | `7x6x3` |
| Floor interval | every `3` vertical nodes |
| Floor Y positions | `5, 8, 11...height-1` |
| First-floor shop wall depth | `min(7, width - 2)` |
| Shop divider X positions | `floor(length / 3)`, `floor(length * 2 / 3)` |
| Door size | `3` wide, `2` high |
| Shelves | rotted wood shelf, scrap metal goods |

## Loot

| Crate | Items |
|---|---|
| CBD | canned food, weapon parts, arrows, scrap metal, rust axe, stone pick |
| Residential | canned food, rotted wood, arrows, field shovel |
| Factory | machine parts, fuel cans, scrap metal, weapon parts, throwing spear |

## Creatures

| Entity | Spawn Rule | Notes |
|---|---|---|
| Dog | near spawn if missing | passive ground animal |
| Rabbit | near spawn if missing | passive/fleeing ground animal |
| Bear | factory chance `65%` west/east, guaranteed edge bear | hostile, detects player within `16`, attacks within `1.8`, damage `4` |

## Hazards

| Hazard | Parameter |
|---|---|
| Rain exposure check | no walkable node above player within `24` nodes |
| Rain damage | `1` HP every `3` seconds |
| Raincoat | blocks rain damage while equipped |
| Rain particles | `24` particles per second around exposed player |
| Interior debris chance | `3%` per hazard tick while covered |
| Debris damage | `3` HP |
| Floor crumble chance | `1%` per hazard tick while covered |
| Floor crumble immunity | bedrock does not crumble |

## Projectiles

| Projectile | Key Parameters |
|---|---|
| Arrow | mesh visual, `visual_size=1.15`, sticky, stick offset `0.56`, stuck life `8s` |
| Spear | mesh visual, `visual_size=1.15`, sticky, stick offset `0.58`, stuck life `10s`, drops spear after stuck expiry |

## Rebuild

| Parameter | Value |
|---|---|
| Rebuild token | `full_sample_city_2026_06_09_a` |
| Rebuild command | `/wf_reset` |
| Runtime ensure | city is rebuilt once when token changes |
