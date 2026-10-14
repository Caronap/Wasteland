# Wasteland Frontier for Luanti

This is a Luanti/Minetest game prototype.

## Install

Copy or symlink this folder into Luanti's `games` directory, then select `Wasteland Frontier` when creating a world.

On macOS the games directory is commonly:

```sh
~/Library/Application Support/luanti/games/
```

or for older Minetest builds:

```sh
~/Library/Application Support/minetest/games/
```

This local machine is already configured with a direct-launch script:

```text
/Users/caronap/Desktop/WastelandProject/luanti_wasteland_game/run_wasteland_frontier.command
```

Double-click it to enter the Wasteland Frontier world directly. The script
name may differ in a local checkout; the packaged demo uses the platform
launchers in its root folder.

## Current Features

- Ruined street map generation.
- Placeable/breakable wasteland blocks.
- Empty-player start with starter supplies in shelter crates.
- Craft recipes for tools, weapons, survival items, and shelter/vehicle kits.
- Inventory item name list and selected-item HUD.
- RPG quest HUD on the left side of the screen.
- Mining difficulty system with tool-specific speed and durability.
- Bow and arrows with click-to-charge shooting.
- Throwable spear with click-to-charge throwing and pickup after landing.
- Placeable workbench with a dedicated crafting UI.
- Dog that chases and removes rabbits.
- Rabbits that flee from dogs.

## Commands

Run these in chat:

```text
/new_start
/wf_reset
/wf_creatures
/wf_new_start
```

`/new_start` starts a fresh run in the same world: it clears your inventory, resets quest progress, rebuilds the starter area, and returns you to spawn.

`/wf_reset` rebuilds the central ruined district and respawns creatures.

`/wf_creatures` respawns dog, rabbits, bears, and the builder villager.

`/wf_new_start` does the same full fresh-run reset as `/new_start`, using the original debug-style command name.

Inventory commands:

```text
/bag
/i
/starter
/wf_tools
/quest
```

Press the Luanti inventory key, usually `I`, to open the custom Wasteland Pack.

If your client keybinding differs, type `/bag` or `/i`.

`/starter` restores starter tools and block stacks.

`/wf_tools` explains the current mining rules.

`/quest` refreshes and prints current quest progress.

## Quest System

The game uses a main/side quest style HUD, not Minecraft-style achievements.

Current first main quest:

```text
Task Tree
- Gather Wood
  Collect 12 Rotted Wood.
- Open Crates
  Open 2 supply crates or shelf caches.
```

The quest tracker appears on the left side of the screen and updates as your inventory changes.

## Mining Rules

Each block has a difficulty value. Higher difficulty means slower mining and more durability pressure.

Tool matching:

- Pickaxe is fastest on cracked asphalt, rubble, and scrap metal.
- Axe is fastest on rotted wood.
- Shovel is fastest on dry grass and dirty water cells.
- Wrong tools still work, but mine slower and consume durability faster.

## Ranged Weapons

- Scrap Bow uses Arrow items as ammo.
- Throwing Spear is removed from your stack when thrown.
- Click once with bow or spear to start charging.
- Click again to release.
- Higher charge means faster projectile and more damage.
- Spears drop back as pickup items after hitting terrain or a target.

## Workbench

- The starter shelter contains a Workbench.
- Right-click the Workbench to open crafting.
- It can craft tools, bow, arrows, and throwing spear from wasteland materials.
- You can also craft a Workbench from four Rotted Wood blocks.

## CLI

The game id is:

```text
luanti_wasteland
```

For this local install:

```sh
~/Applications/luanti.app/Contents/MacOS/luanti --gameid luanti_wasteland --go
```
