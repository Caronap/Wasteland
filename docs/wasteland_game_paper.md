# Wasteland Frontier: Game Systems Design and Implementation

## Abstract

Wasteland Frontier is a single-player survival and exploration prototype built
with Luanti. The project centers on a simple objective: wake inside a ruined
city covered by an abnormal storm, gather enough resources to survive, cross a
large rainforest, and leave the cloud-covered region. The prototype combines
procedural map generation, environmental storytelling, creature behavior,
resource loops, combat feedback, quests, shelters, and vehicles in one
playable structure.

The city is intentionally compact while the rainforest has ten times the city
radius. Storm clouds cover both spaces and make light management, spatial
awareness, and route selection central parts of the experience. Glowing story
signs, task boards, a minimap, handheld lamps, torches, and glowing fungus
create layered guidance so that the player can navigate a large space without
depending on a long tutorial.

The prototype is valuable less because any single system is unusually complex
and more because the systems form a complete loop from starting supplies to a
clear escape condition. It demonstrates a practical path for iterating on a
small voxel survival game with limited assets and a concentrated codebase.

**Keywords:** Luanti; voxel world; procedural generation; survival game; quest
system; environmental storytelling

## 1. Background and Design Goals

Voxel survival games often combine curiosity about an unknown environment with
continuous pressure from resources, danger, and long-term goals. Wasteland
Frontier is designed around that intersection. The player learns the world
from ruined buildings, storm clouds, puddles, glowing fungus, animals, and
signs rather than from a complete instruction manual.

The game does not rely on long cinematic sequences. Instead, its story is
embedded in the map and in objects the player can approach and use. The city
represents a damaged human order. The rainforest represents uncontrolled
ecological expansion. The cloud layer marks the disaster zone. Leaving the
forest and cloud boundary is both the logical victory condition and the
clearest narrative goal.

From an engineering perspective, the first priority was to connect incomplete
features into one verifiable route. The prototype needed a stable spawn, a
visible task tree, accessible starting resources, gathering, crafting, hostile
creatures, combat, shelters, a minimap, a guided rainforest route, and an
explicit ending. This reflects a useful small-project principle: establish
goals, paths, feedback, and completion conditions before expanding optional
content.

## 2. System Structure and Core Loop

The core loop can be described as:

```text
Read the task
Gather resources
Craft tools
Build or find safety
Handle threats
Advance along the route
Leave the boundary
```

The task system organizes this loop. The earlier jump-training quest was
removed because it was weakly connected to the survival theme and produced
irrelevant movement prompts. The current HUD uses a unified task tree with
`[>]` for the active task, `[x]` for completed tasks, and locked entries for
future tasks. Task boards near the spawn and Starter Shelter provide more
context when the player wants details.

Resources include rotted wood, scrap materials, food, parts, animal drops,
lamps, and workbench recipes. The player begins with enough equipment to
understand the prototype, but must continue gathering and exploring to
maintain supplies and unlock shelter, combat, and vehicle options. The
workbench links resources to progression by producing bandages, maps, torches,
shelter kits, vehicle kits, tools, and weapons.

Shelters make weather a meaningful part of the resource loop. Exposed players
can take rain damage, while a roof creates a safe space. Survival therefore
depends on spatial organization and preparation, not only on fighting.

## 3. Creature Behavior and Combat Feedback

Creature feedback is differentiated to keep the screen readable. Rabbits and
dogs are low-threat animals and do not display health bars. Bears are hostile
targets and display a compact bar only when the player is nearby. The system
uses ranged and close-range options: a chargeable Scrap Bow, a throwable
spear, and melee tools.

Drops connect combat to progression. Small animals provide basic food and
materials. Bears provide more valuable resources, including bear pelt and
occasional machine parts or fuel cans. This produces a simple risk-reward
relationship: hostile creatures are harder to approach but may provide
materials needed for more advanced equipment.

The Salvage Cart extends the same idea to movement. It can be crafted, placed,
driven, and recovered. It does not replace exploration on foot; it reduces
repetitive travel across the city and records a vehicle-deployment quest event.

## 4. Environmental Storytelling and Guidance

The project treats the environment as both level and narrative. City
structures, factories, storm clouds, rainforest density, glowing fungus,
torches, handheld lamps, task boards, and story signs work together as a
visual language.

The southern story route is especially important because the rainforest radius
is much larger than the city. A minimap provides the macro direction, while
physical signs, torches, and glowing fungus provide local confirmation. The
route is persistent and uses controlled clearing so that the player can always
find a readable passage without removing the pressure created by the forest.

The lighting system has multiple meanings. Torches and handheld lamps are
tools that reveal space. Glowing fungus suggests ecological change. Story
signs and task boards represent traces of human order. The density of these
elements changes by region, allowing the player to sense the transition from
city to forest without relying entirely on text.

## 5. Engineering Implementation

The prototype currently concentrates many systems in `init.lua`: nodes, tools,
entities, map generation, HUD, quests, vehicles, and interactions. This makes
rapid iteration possible but creates a maintainability risk because the Lua
main chunk is close to its top-level local-variable limit.

Several helper functions use `_wf_*` names as a short-term solution. A longer
term architecture should split the code into modules such as:

```text
quests.lua
mapgen.lua
entities.lua
ui.lua
interactions.lua
```

Map generation combines a fixed central city with on-demand outer-region
generation. A city rebuild token lets older worlds refresh new structures.
Rainforest, storm-cloud, and route content are generated by chunk so that the
whole 800-radius area does not need to be built at startup.

The scene graph records the relationships among the city, cloud-forest escape,
southern sign route, survival progression, task HUD, shelters, and Salvage
Cart. It acts as an engineering index for future expansion and helps keep
world-generation and quest decisions consistent.

## 6. Validation and Future Work

The current project has been checked through static Lua and JSON inspection,
local Luanti startup, archive inspection, and Markdown-to-DOCX generation. The
main remaining risks are long-distance rainforest generation, vehicle
collision on complex terrain, and unusual legacy save states.

The next engineering priorities are:

1. Split the concentrated Lua file into stable modules.
2. Add smoke tests for node registration, quest progression, reset commands,
   and escape detection.
3. Add more language options to signs and task boards.
4. Improve UI, visual assets, and sound after the gameplay loop is stable.
5. Add optional events and quest branches so the rainforest route can support
   more than one linear escape sequence.

## Conclusion

Wasteland Frontier has progressed from a feature list into a playable prototype
with a complete main route. Its city, rainforest, clouds, and escape boundary
establish the spatial goal. Resources, crafting, combat, shelters, and the
vehicle establish survival pressure. The task tree, task boards, minimap,
glowing signs, and light sources establish readable guidance. Together these
systems show how a small voxel prototype can create direction, danger, and
completion through clear relationships rather than through large amounts of
content.
