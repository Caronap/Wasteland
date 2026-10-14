# Wasteland Game Engineering Changes - 2026-06-18

This document summarizes the main engineering changes made to
`luanti_wasteland_game`. The work focused on
`mods/wasteland_core/init.lua`,
`mods/wasteland_core/world_scenegraph.lua`, and
`docs/world_scenegraph.json`. The goal was to turn incomplete survival,
exploration, quest, map, and narrative systems into a playable single-player
prototype with a complete main route.

## 1. Core Goals

This development pass focused on the following goals:

- Replace the large amount of bad water around the city with a broad rainforest.
- Make the city roughly one tenth the radius of the rainforest.
- Generate storm clouds above the city and rainforest to block the sun.
- Trigger victory when the player leaves the cloud-covered rainforest.
- Add torches, a handheld lamp, glowing fungus, and glowing story signs for
  low-light navigation.
- Improve health bars and combat feedback so NPC names and bars do not fill the
  screen.
- Remove the jump-training quest and use a unified task tree and task boards.
- Improve the map, vehicle, shelter, narrative guidance, and AI scene graph
  records.

## 2. World Generation and Map Structure

### 2.1 City, Rainforest, Storm Clouds, and Escape Radius

Key parameters:

```lua
CITY_RADIUS = 80
FOREST_RADIUS = CITY_RADIUS * 10
CLOUD_RADIUS = FOREST_RADIUS
CLOUD_Y = 26
ESCAPE_RADIUS = FOREST_RADIUS + 12
```

The current structure is:

- The city core has a radius of 80.
- The rainforest has a radius of 800, approximately ten times the city radius.
- Storm clouds cover the city and rainforest.
- Victory is triggered when the player reaches beyond
  `ESCAPE_RADIUS = 812` while meeting the height condition.

### 2.2 Reduced Bad Water

The map-generation aliases map default water sources to `dry_grass` so that
bad water does not dominate the world:

- `mapgen_water_source -> dry_grass`
- `mapgen_river_water_source -> dry_grass`

Bad water remains as a small number of random ground puddles for atmosphere
and danger, but it no longer defines the surrounding terrain.

### 2.3 Rainforest Generation

The rainforest is generated primarily from dense trees:

- The city outskirts use large areas of `dry_grass`.
- Tree density is layered by distance, with denser growth near the city.
- Trunk height is increased by two to three blocks over the earlier random range.
- Roads, buildings, and guidance routes clear local space so the forest does not
  completely block traversal.

### 2.4 Escape Route

A narrow route extends south so that the player can navigate the 800-block
rainforest:

```text
z = 24 -> 72 -> 112 -> 220 -> 360 -> 520 -> 680 -> 792 -> 808
```

The route has a narrow broken road or dry-ground center, dense trees on both
sides, and a glowing story sign at every major point. The final sign is near
the forest and cloud boundary and tells the player to continue outward to win.

## 3. Light Sources, Items, and Pickups

### 3.1 Storm Torch

A new `torch` node provides basic light in the storm environment. It can appear
as a starting resource, crate resource, crafting result, and route marker near
story signs.

### 3.2 Hand Lamp

A new `hand_lamp` node and item:

- Can be picked up directly.
- Spawns randomly in the city and rainforest.
- Spawns more often in the city than in the rainforest.
- Provides moving light through `player:set_lighting(...)` while held.
- Is more useful during travel than fixed block lighting alone.

### 3.3 Glow Fungus

Two glowing fungus types were added:

- `glow_fungus`: ground fungus.
- `wall_glow_fungus`: wall fungus.

Fungus appears more often on building exteriors, with smaller amounts in the
forest for atmosphere and weak route guidance. A small amount can also grow
near players during runtime.

## 4. Creature NPCs, Behavior, and Drops

The main entities are:

- Rabbit: small animal with a hidden health bar.
- Dog: small animal with a hidden health bar.
- Bear: hostile creature that pursues and attacks the player.
- Builder Villager: narrative and utility NPC connected to shelter guidance.

Drop rules include:

- Rabbits and dogs drop meat, leather, and other basic resources.
- Bears drop more meat and bear pelt, with a chance to drop machine parts and
  fuel cans.
- Spears and arrows travel as projectile entities and trigger damage and drop
  logic on impact.

## 5. Health Bars and Combat

### 5.1 Health Bar Display

Health bars were changed from long `########` strings to compact bar text:

```text
Bear
HP 30/30 |========|
```

The display rules are:

- A health bar appears only when the player is close to an entity.
- The default display distance is approximately eight blocks.
- Rabbit and Dog health bars remain hidden.
- Bear and other combat targets keep a close-range health bar.

### 5.2 Attacks and Weapons

Current combat abilities include:

- Melee tools that deal damage.
- A chargeable bow.
- A throwable spear that can be recovered after impact.
- Bears that actively pursue and attack at close range.
- Persistent player health and raincoat HUD feedback.

## 6. Resources, Crafting, and Starting Supplies

### 6.1 Starting Supplies

The player starts with basic tools and exploration items, including an axe,
pickaxe, shovel, bow, arrows, spear, raincoat, and map.

### 6.2 Available Resources

Resources come from:

- `rotted_wood` in trees and ruins.
- Loot crates in buildings.
- Food, parts, and industrial shelves.
- Animal drops.
- Advanced factory and bear-related materials.
- Hand lamps scattered through the city and rainforest.

### 6.3 Workbench

The workbench can craft:

- Bandages.
- Maps.
- Shelter kits.
- Salvage Cart Kits.
- Storm Torches.
- Weapons and tool-related items.

## 7. City, Roads, and Buildings

The city includes:

- Central roads.
- Multiple district building templates.
- Starter Shelter.
- Builder Villager Hut.
- Factory Complex.
- Resource Market.
- Interactive Depot.
- Scenic Landmark.
- Farms, ruins, and cabins around the city edge.

Additional changes:

- The city outskirts now connect directly to the rainforest instead of large
  bad-water areas.
- Glowing fungus can appear on building exteriors.
- City rebuild tokens are updated so old worlds can refresh new structures.
- A task board is placed near the spawn area.

## 8. Minimap

The minimap records:

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

The map description was updated to:

```text
City core at center
Forest radius x10 city
Follow south guide signs
Leave forest/cloud to win
```

## 9. Vehicle System

The `salvage_cart` vehicle:

- Is deployed through `salvage_cart_kit`.
- Can be driven by the player.
- Handles driver state when the player exits, leaves, or recovers the cart.
- Records a `vehicle_deployed` quest event.
- Can be recovered as a kit after being hit.

## 10. Shelter System

The game contains two shelter types:

- Starter Shelter: the initial structure with a workbench, crate, and task
  guidance.
- Player Built Shelter: placed through a shelter kit.

A roof blocks acid rain and other dangerous rain. Players can take rain damage
when exposed outside a shelter.

The Starter Shelter now has a task board near its entrance, so the task entry
point is visible both from spawn and from the shelter.

## 11. Narrative, Quests, and Guidance

### 11.1 Removed Jump Training

The following jump-training elements were removed:

- `main_002_jump_training`.
- `jump_in_place` progress tracking.
- The related globalstep check.
- The related chat hints.

For old saves, a stored legacy quest id is advanced to the first incomplete
quest in the current chain.

### 11.2 Unified Task Tree

The HUD now uses one task tree:

```text
Task Tree
[>] Gather Wood 8/12
[ ] Open Crates locked
[ ] Raise a Shelter locked
```

After the main route is restored:

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

### 11.3 Task Boards

The new `task_board` node:

- Emits light.
- Is placed near spawn and at the Starter Shelter entrance.
- Opens the complete task tree through a formspec on right-click.
- Shows task titles, descriptions, states, and the current hint.

### 11.4 Glowing Story Signs

The new `story_sign` node emits light and provides narrative guidance. Signs
are distributed along the southern route and work with torches and glowing
fungus to guide the player through the dark forest.

The sign sequence covers:

- Waking up in the city.
- Following the southern road.
- Carrying a torch or handheld lamp in the rainforest.
- Continuing south toward the cloud boundary.
- Leaving the cloud and forest to complete the escape.

## 12. AI Scene Graph

The following records were synchronized:

- `mods/wasteland_core/world_scenegraph.lua`
- `docs/world_scenegraph.json`

The scene graph now includes:

- `cloud_forest_escape`
- `south_glowing_sign_route`
- `survival_progression`
- `quest_hud`
- `task_notice_board`

It explicitly records the city-to-forest scale relationship, cloud coverage,
the southern glowing-sign route, the task-tree HUD, the task-board interaction,
and the removal of jump training.

## 13. Engineering Notes

### 13.1 Lua Top-Level Local Limit

`init.lua` is close to the Lua main-chunk limit of approximately 200 local
variables. Several new helper functions therefore use `_wf_*` global names,
including:

```text
_wf_story_sign_route
_wf_clear_story_path_segment
_wf_place_story_sign
_wf_place_story_signs_in_chunk
_wf_task_board_formspec
_wf_show_task_board
_wf_scatter_loose_hand_lamps
```

Future work should avoid adding many more top-level locals. A longer-term
solution is to split the file into modules such as `quests.lua` and
`mapgen.lua`.
