# Wasteland Frontier Engineering Changes - 2026-10-14

This document uses `engineering_changes_2026-06-18.docx` as the engineering
record reference and summarizes the actual changes present in the current
`luanti_wasteland_game` project. It also records the packaging work completed
for teacher playtesting, personal website hosting, and application materials.

The earlier document is a reference for engineering history, not an additional
feature request. This report describes the current code and release artifacts.

## 1. Objectives

This release has two goals:

- Complete a playable single-player prototype in which the opening, quests,
  city exploration, rainforest crossing, and escape ending form one route.
- Package the project for external review as a website showcase, a downloadable
  Luanti demo, and a source-code archive.

The release remains a Luanti game package. The static website is a project
showcase and download page; it is not presented as a browser-native game build.

## 2. World Structure and Map Generation

### 2.1 City, Rainforest, Clouds, and Escape Boundary

The world keeps a clear spatial ratio:

```lua
CITY_RADIUS = 80
FOREST_RADIUS = CITY_RADIUS * 10
CLOUD_RADIUS = FOREST_RADIUS
ESCAPE_RADIUS = FOREST_RADIUS + 12
```

This means:

- The city core has a radius of 80.
- The rainforest has a radius of 800, approximately ten times the city radius.
- Storm clouds cover the city and rainforest to create a low-light environment.
- Victory is triggered after the player leaves the forest and cloud boundary.

### 2.2 Stable Spawn and Starter Shelter

The current spawn is fixed near the starter shelter:

```lua
WF_STARTER_SHELTER_ORIGIN = {x = 10, z = 54}
WF_PLAYER_SPAWN_POS = {x = 14, y = 3, z = 52}
```

First entry, respawn, and `/new_start` return the player to this area. The
Starter Shelter contains a workbench, supply crate, task board, and opening
guidance so an external playtester can begin without searching for critical
resources.

The city rebuild token is:

```lua
CITY_REBUILD_TOKEN = "spawn_near_shelter_2026_10_13_a"
```

When an old world detects a new token, the central area is rebuilt so that new
structures and task entrances are available.

### 2.3 Reduced Bad Water and Rainforest Replacement

Default map water is aliased to `dry_grass` so that large bad-water areas do not
block the city outskirts:

```text
mapgen_water_source -> dry_grass
mapgen_river_water_source -> dry_grass
```

Small puddles remain as environmental hazards. The outskirts now generate a
large rainforest, with tree density varying by distance from the city. Roads,
buildings, and the story route clear local space to preserve traversal.

## 3. Persistent Southern Escape Route

### 3.1 Route Construction

The southern route is maintained as an independent persistent build process:

```lua
STORY_PATH_START_Z = 0
STORY_PATH_END_Z = ESCAPE_RADIUS + 8
STORY_PATH_BUILD_TOKEN = "permanent_south_escape_route_2026_10_14_a"
```

The route:

- Clears a continuous passage across `x = -4..4`.
- Removes trees and blocks above the passage.
- Replants a controlled amount of forest on both sides.
- Places glowing story signs at the city, forest, forest edge, and escape line.
- Adds torches and glowing fungus near the signs.
- Stores a route token and supports repair through `/wf_escape_route`.

### 3.2 Route Markers

The current story-sign points are:

```text
z = 24, 72, 112, 220, 360, 520, 680, 792, 808
```

The route is not a teleport system. It creates a readable sequence through the
large rainforest: wake in the city, enter the forest, use light, approach the
cloud boundary, and reach open sky.

## 4. Light Sources and Environmental Guidance

### 4.1 Storm Torch

The `torch` node provides basic light in the storm. It can appear in starting
supplies, crates, crafting recipes, and near story signs.

### 4.2 Hand Lamp

The `hand_lamp` item:

- Can be picked up directly.
- Spawns randomly in the city and rainforest.
- Spawns more densely in the city.
- Provides moving light through `player:set_lighting(...)` while held.
- Restores normal lighting after the player switches items.

### 4.3 Glow Fungus

The project includes:

- `glow_fungus` for ground lighting.
- `wall_glow_fungus` for wall lighting.

Fungus appears more often on building exteriors and less often in the forest.
It supports atmosphere and weak visual navigation around the southern route.

## 5. Quests, HUD, and Interaction

### 5.1 Jump Training Removal

The current version keeps the earlier decision to remove jump training:

- `main_002_jump_training` is removed.
- `jump_in_place` progress tracking is removed.
- The related globalstep detection is removed.
- The related chat messages are removed.

Old saves containing the legacy quest id advance to the first incomplete quest
in the current chain.

### 5.2 Unified Task Tree

The upper-left HUD uses one task tree:

```text
Task Tree
[>] Gather Wood 8/12
[ ] Open Crates locked
[ ] Raise a Shelter locked
```

After the city route is restored:

```text
Task Tree
[x] Restore the city route
[>] Follow glowing signs south
[ ] Leave the cloud forest
```

After victory:

```text
Task Tree
[x] Escape the cloud forest
Victory reached
```

### 5.3 Region and Distance Feedback

The player HUD includes:

- Temporary region labels such as `Central District`, `Outer Rainforest`, and
  `Open Sky`.
- Coordinates and remaining distance to the escape line.
- Player health, raincoat status, and weapon charge feedback.
- Hand-lamp lighting feedback.

The coordinate HUD can be toggled with `/coords`.

### 5.4 Task Boards

The `task_board` node:

- Emits light.
- Appears near spawn and at the Starter Shelter entrance.
- Opens the complete task tree through a formspec on right-click.
- Shows task titles, descriptions, states, and the current hint.

## 6. Creatures, Combat, and Vehicles

The current main entities are:

- Rabbit: low-threat animal with no health bar.
- Dog: low-threat animal with no health bar.
- Ocelot: avoids the player.
- Bear: hostile creature with a close-range health bar and pursuit behavior.
- Builder Villager: narrative and utility NPC for shelter and quest guidance.

Combat includes:

- Melee tools.
- A chargeable Scrap Bow.
- A chargeable Throwing Spear that can be recovered after impact.
- Bears that pursue and attack at close range.
- Resource drops from animals and bears.

The `salvage_cart` supports:

- Placement through `salvage_cart_kit`.
- Driving.
- Driver-state cleanup on exit or disconnect.
- Recovery after being hit.
- A `vehicle_deployed` quest event.

## 7. Resources, Crafting, and Shelters

Starting supplies include an axe, pickaxe, shovel, bow, arrows, spear,
raincoat, and map.

Resources come from:

- Rotted wood in trees and ruins.
- Loot crates.
- Food, parts, and industrial shelves.
- Animal drops.
- Factory and bear-related materials.
- Hand lamps scattered through the city and rainforest.

The workbench can craft bandages, maps, shelter kits, Salvage Cart Kits, Storm
Torches, weapons, and tools.

The shelter system includes:

- Starter Shelter with a workbench, crate, task guidance, and task board.
- Player Built Shelter placed through a shelter kit.

Shelter roofs block acid rain and other dangerous rain. Players take rain
damage when exposed without cover.

## 8. Map and Scene Graph Records

The map records:

- Spawn.
- Starter Shelter.
- Builder.
- Market.
- Depot.
- Factory.
- Forest edge.
- Escape line.
- Guide signs.
- Last guide sign.

The map description is:

```text
City core at center
Forest radius x10 city
Follow south guide signs
Leave forest/cloud to win
```

The scene graph sources are:

- `mods/wasteland_core/world_scenegraph.lua`
- `docs/world_scenegraph.json`

The current records include:

- `cloud_forest_escape`
- `south_glowing_sign_route`
- `survival_progression`
- `quest_hud`
- `task_notice_board`

## 9. Release Packaging

The website archive contains:

- The static `index.html` project page.
- Actual game screenshots.
- The downloadable demo archive.
- The English project overview.
- The English engineering-change report in Markdown and DOCX.

The source archive contains:

- The Lua game source.
- Luanti configuration.
- Runtime textures and models.
- English project documentation.
- English engineering history.
- Documentation and model-generation tools.

The release archives exclude development distribution folders, old nested zip
files, Blender temporary files, system metadata, and non-English explanatory
documents.

Luanti itself is not bundled. A reviewer installs Luanti, extracts the demo,
runs the launcher for the target platform, creates a single-player world, and
selects `Wasteland Frontier`.

## 10. Verification and Known Boundaries

The following checks were completed:

- Static inspection of nodes, entities, commands, HUD systems, lighting,
  escape-route logic, and victory detection.
- Archive inspection to confirm that the website and source packages contain
  only the intended files.
- Link and asset-path inspection for the static website.
- Regeneration of the English DOCX reports from Markdown.
- Local Luanti version check on macOS.

Remaining boundaries:

- Windows and Linux graphical launch have not been tested on physical machines.
- Long-distance rainforest generation, vehicle collision, and unusual legacy
  save states remain prototype-level risks.
- Hosting still requires uploading the website archive contents to a static
  website provider.

## 11. Recommended Next Steps

1. Split `init.lua` into quest, map-generation, entity, UI, and interaction
   modules.
2. Add automated smoke tests for node registration, quest progression, reset
   commands, and escape detection.
3. Add more language options to signs and task boards.
4. Confirm platform, license, and distribution-size requirements before
   bundling the Luanti engine itself.
