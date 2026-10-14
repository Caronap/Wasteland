# Wasteland World Scenegraph

```text
wasteland_world [world] origin=(0,0,0) bounds=(-80,0,-80)..(80,36,80)
├─ weather_rain [system] position=global
│  ├─ exposed players take rain damage
│  ├─ raincoat blocks rain damage
│  └─ covered players are safe
├─ sample_city [city] center=(0,1,0) bounds=(-80,0,-80)..(80,36,80)
│  ├─ roads
│  │  ├─ main_ns bounds=(-6,1,-76)..(6,1,76)
│  │  ├─ main_ew bounds=(-76,1,-6)..(76,1,6)
│  │  ├─ belt_north bounds=(-42,1,-42)..(42,1,-38)
│  │  ├─ belt_south bounds=(-42,1,38)..(42,1,42)
│  │  ├─ belt_west bounds=(-42,1,-42)..(-38,1,42)
│  │  └─ belt_east bounds=(38,1,-42)..(42,1,42)
│  ├─ cbd [zone] center=(0,1,0) radius=24
│  │  ├─ villager_hut_spawn pos=(10,1,-9) size=(7,7,6)
│  │  ├─ template_tower_a pos=(-23,1,-23) scale=2x3x8 size=(14,24,18)
│  │  ├─ template_tower_b pos=(4,1,14) scale=1x3x6 size=(7,18,18)
│  │  ├─ template_tower_c pos=(-21,1,9) scale=1x1x3 size=(7,9,6)
│  │  ├─ cbd_box_a pos=(16,1,-22) size=(9,10,8)
│  │  ├─ cbd_box_b pos=(-8,1,18) size=(10,8,8)
│  │  └─ loot: loot_crate_cbd
│  ├─ residential [zone] center=(0,1,0) radius=45
│  │  ├─ residential_hut_a pos=(28,1,-18) size=(7,7,6)
│  │  ├─ residential_hut_b pos=(-36,1,18) size=(7,7,6)
│  │  ├─ residential_apartment_a pos=(27,1,15) size=(10,5,8)
│  │  ├─ residential_apartment_b pos=(-45,1,-24) size=(9,4,7)
│  │  └─ loot: loot_crate_residential
│  ├─ factory [zone] center=(0,1,0) radius=65
│  │  ├─ factory_complex_west pos=(-68,1,-28) bounds=(-70,1,-30)..(-34,16,-14)
│  │  ├─ factory_complex_east pos=(44,1,34) bounds=(42,1,32)..(78,16,48)
│  │  ├─ bear_factory_west pos=(-56,1,-18) spawnChance=0.65
│  │  ├─ bear_factory_east pos=(56,1,42) spawnChance=0.65
│  │  └─ loot: loot_crate_factory
│  └─ city_edge [zone] center=(0,1,0) radius=80
│     ├─ edge_farm bounds=(-72,1,-8)..(-56,1,8)
│     ├─ edge_ruin pos=(58,1,-56) size=(8,4,7)
│     ├─ edge_hut pos=(-70,1,48) size=(7,3,6)
│     ├─ bear_edge_guaranteed pos=(70,1,-64) spawnChance=1.0
│     ├─ dog_spawn pos=(2,1,2)
│     ├─ rabbit_spawn_a pos=(-2,1,2)
│     └─ rabbit_spawn_b pos=(5,1,1)
├─ building_hazards [system] position=covered player interiors
│  ├─ covered interiors can spawn falling brick debris
│  ├─ debris damages players on impact
│  └─ non-bedrock floors can crumble under players
└─ projectiles [system] position=runtime entities
   ├─ arrow_projectile [entity]
   │  ├─ velocity-aligned mesh
   │  └─ sticks into surfaces
   └─ spear_projectile [entity]
      ├─ velocity-aligned mesh
      └─ sticks then drops spear item
```

Source JSON: `docs/world_scenegraph.json`
Runtime Lua source: `mods/wasteland_core/world_scenegraph.lua`
