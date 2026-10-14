local modname = minetest.get_current_modname()
local storage = minetest.get_mod_storage()

-- Compatibility shim for old worlds: remove saved ocelots after loading them.
minetest.register_entity(modname .. ":ocelot", {
    initial_properties = {
        physical = false,
        pointable = false,
        visual = "sprite",
        textures = {"blank.png"},
        visual_size = {x = 0, y = 0},
        static_save = false,
    },
    on_activate = function(self)
        self.object:remove()
    end,
    on_step = function(self)
        self.object:remove()
    end,
})

local function texture(name)
    return "wasteland_" .. name .. ".png"
end

local WORLD_SCENEGRAPH = dofile(minetest.get_modpath(modname) .. "/world_scenegraph.lua")
local CITY_RADIUS = 80
local FOREST_RADIUS = CITY_RADIUS * 10
local CLOUD_RADIUS = FOREST_RADIUS
local CLOUD_Y = 26
local ESCAPE_RADIUS = FOREST_RADIUS + 12
WF_STARTER_SHELTER_ORIGIN = {x = 10, z = 54}
WF_PLAYER_SPAWN_POS = {x = 14, y = 3, z = 52}
WF_PLAYER_VISUAL_SIZE = {x = 7, y = 7, z = 7}
WF_BEAR_SPAWN_POINTS = {
    west_factory = {x = -51, z = -16},
    east_factory = {x = 62, z = 46},
    edge_ruins = {x = 70, z = -64},
}
local fill_area
local place_player_shelter
local place_vehicle_entity
local minimap_formspec
local record_player_event
local advance_quests
local update_quest_hud
local world_span_distance

local BLOCK_DEFS = {
    cracked_asphalt = {
        description = "Cracked Asphalt",
        group = "wf_cracked_asphalt",
        material = "cracky",
        preferred_tool = "pick",
        difficulty = 1.25,
    },
    rubble = {
        description = "Rubble",
        group = "wf_rubble",
        material = "cracky",
        preferred_tool = "pick",
        difficulty = 1.1,
    },
    scrap_metal = {
        description = "Scrap Metal",
        group = "wf_scrap_metal",
        material = "cracky",
        preferred_tool = "pick",
        difficulty = 1.55,
    },
    rotted_wood = {
        description = "Rotted Wood",
        group = "wf_rotted_wood",
        material = "choppy",
        preferred_tool = "axe",
        difficulty = 0.8,
    },
    dry_grass = {
        description = "Dry Grass",
        group = "wf_dry_grass",
        material = "snappy",
        preferred_tool = "shovel",
        difficulty = 0.65,
    },
    dirty_water = {
        description = "Dirty Water Cell",
        group = "wf_dirty_water",
        material = "crumbly",
        preferred_tool = "shovel",
        difficulty = 0.55,
    },
}

local TOOL_DEFS = {
    rust_axe = {
        description = "Rust Axe",
        tool_type = "axe",
        damage = 4,
        speed = {
            choppy = 0.55,
            cracky = 3.3,
            crumbly = 1.8,
            snappy = 1.4,
        },
        uses = {
            choppy = 60,
            cracky = 10,
            crumbly = 18,
            snappy = 24,
        },
    },
    stone_pick = {
        description = "Stone Pickaxe",
        tool_type = "pick",
        damage = 3,
        speed = {
            cracky = 0.6,
            choppy = 3.4,
            crumbly = 2.1,
            snappy = 2.2,
        },
        uses = {
            cracky = 70,
            choppy = 9,
            crumbly = 16,
            snappy = 14,
        },
    },
    field_shovel = {
        description = "Field Shovel",
        tool_type = "shovel",
        damage = 2,
        speed = {
            crumbly = 0.45,
            snappy = 0.7,
            cracky = 2.8,
            choppy = 2.4,
        },
        uses = {
            crumbly = 65,
            snappy = 45,
            cracky = 12,
            choppy = 14,
        },
    },
    scrap_bow = {
        description = "Scrap Bow",
        tool_type = "bow",
        damage = 1,
        speed = {},
        uses = {},
    },
    throwing_spear = {
        description = "Throwing Spear",
        tool_type = "spear",
        damage = 5,
        speed = {},
        uses = {},
    },
}

minetest.register_alias("mapgen_stone", modname .. ":rubble")
minetest.register_alias("mapgen_dirt", modname .. ":dry_grass")
minetest.register_alias("mapgen_dirt_with_grass", modname .. ":dry_grass")
minetest.register_alias("mapgen_sand", modname .. ":dry_grass")
minetest.register_alias("mapgen_water_source", modname .. ":dry_grass")
minetest.register_alias("mapgen_river_water_source", modname .. ":dry_grass")

local function node_box(name, def)
    local groups = {
        oddly_breakable_by_hand = 3,
    }
    groups[def.group] = 1
    minetest.register_node(modname .. ":" .. name, {
        description = def.description,
        tiles = {
            texture(name),
        },
        groups = groups,
        drop = "",
        sounds = nil,
        _preferred_tool = def.preferred_tool,
        _difficulty = def.difficulty,
        after_dig_node = function(pos, oldnode)
            minetest.add_item(vector.add(pos, {x = 0.5, y = 0.25, z = 0.5}), oldnode.name)
        end,
    })
end

for name, def in pairs(BLOCK_DEFS) do
    node_box(name, def)
end

minetest.register_item(":", {
    type = "none",
    wield_image = "blank.png",
    wield_scale = {x = 1, y = 1, z = 1},
    tool_capabilities = {
        full_punch_interval = 0.9,
        max_drop_level = 0,
        groupcaps = {
            oddly_breakable_by_hand = {
                times = {
                    [1] = 2.0,
                    [2] = 2.8,
                    [3] = 3.6,
                },
                uses = 0,
                maxlevel = 1,
            },
            wf_rotted_wood = {
                times = {[1] = 3.2},
                uses = 0,
                maxlevel = 1,
            },
            wf_dry_grass = {
                times = {[1] = 1.4},
                uses = 0,
                maxlevel = 1,
            },
            wf_rubble = {
                times = {[1] = 5.5},
                uses = 0,
                maxlevel = 1,
            },
        },
        damage_groups = {fleshy = 1},
    },
})

minetest.register_node(modname .. ":bedrock", {
    description = "Bedrock",
    tiles = {
        texture("bedrock"),
    },
    groups = {},
    drop = "",
})

minetest.register_node(modname .. ":dead_leaves", {
    description = "Dead Leaves",
    tiles = {"wasteland_dry_grass.png^[colorize:#6b5b35:95"},
    groups = {oddly_breakable_by_hand = 2, wf_dry_grass = 1},
    drop = modname .. ":dry_grass",
})

minetest.register_node(modname .. ":storm_cloud", {
    description = "Storm Cloud",
    tiles = {"wasteland_plain.png^[colorize:#232833:220"},
    groups = {not_in_creative_inventory = 1},
    drop = "",
    pointable = false,
    diggable = false,
    sunlight_propagates = false,
})

minetest.register_node(modname .. ":torch", {
    description = "Storm Torch",
    drawtype = "plantlike",
    tiles = {"wasteland_plain.png^[colorize:#ffb24a:220"},
    inventory_image = "wasteland_plain.png^[colorize:#ffb24a:220",
    wield_image = "wasteland_plain.png^[colorize:#ffb24a:220",
    visual_scale = 0.65,
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    light_source = 12,
    groups = {oddly_breakable_by_hand = 3, attached_node = 1},
    selection_box = {
        type = "fixed",
        fixed = {-0.18, -0.5, -0.18, 0.18, 0.35, 0.18},
    },
})

minetest.register_node(modname .. ":glow_fungus", {
    description = "Glow Fungus",
    drawtype = "nodebox",
    tiles = {"wasteland_plain.png^[colorize:#63ffcf:220"},
    inventory_image = "wasteland_plain.png^[colorize:#63ffcf:220",
    wield_image = "wasteland_plain.png^[colorize:#63ffcf:220",
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    light_source = 8,
    groups = {oddly_breakable_by_hand = 2, attached_node = 1},
    node_box = {
        type = "fixed",
        fixed = {
            {-0.20, -0.50, -0.18, 0.02, -0.32, 0.04},
            {0.06, -0.50, -0.02, 0.22, -0.36, 0.16},
            {-0.02, -0.50, 0.10, 0.12, -0.38, 0.24},
        },
    },
    selection_box = {
        type = "fixed",
        fixed = {-0.24, -0.5, -0.24, 0.24, -0.06, 0.24},
    },
})

minetest.register_node(modname .. ":wall_glow_fungus", {
    description = "Wall Glow Fungus",
    drawtype = "nodebox",
    tiles = {"wasteland_plain.png^[colorize:#8bff9e:230"},
    inventory_image = "wasteland_plain.png^[colorize:#8bff9e:230",
    wield_image = "wasteland_plain.png^[colorize:#8bff9e:230",
    paramtype = "light",
    paramtype2 = "wallmounted",
    sunlight_propagates = true,
    walkable = false,
    light_source = 9,
    groups = {oddly_breakable_by_hand = 2, attached_node = 1},
    node_box = {
        type = "wallmounted",
        wall_top = {-0.18, 0.36, -0.18, 0.18, 0.50, 0.18},
        wall_bottom = {-0.18, -0.50, -0.18, 0.18, -0.36, 0.18},
        wall_side = {-0.50, -0.18, -0.18, -0.36, 0.18, 0.18},
    },
    selection_box = {
        type = "wallmounted",
    },
})

local function register_escape_route_node(name, def)
    def.groups = {not_in_creative_inventory = 1}
    def.drop = ""
    def.diggable = false
    def.is_ground_content = false
    minetest.register_node(modname .. ":" .. name, def)
end

register_escape_route_node("escape_path_grass", {
    description = "Permanent Escape Path Grass",
    tiles = {texture("dry_grass")},
})

register_escape_route_node("escape_path_asphalt", {
    description = "Permanent Escape Path Asphalt",
    tiles = {texture("cracked_asphalt")},
})

register_escape_route_node("escape_tree_wood", {
    description = "Permanent Escape Route Tree",
    tiles = {texture("rotted_wood")},
})

register_escape_route_node("escape_tree_leaves", {
    description = "Permanent Escape Route Leaves",
    tiles = {"wasteland_dry_grass.png^[colorize:#6b5b35:95"},
})

register_escape_route_node("escape_route_torch", {
    description = "Permanent Escape Route Torch",
    drawtype = "plantlike",
    tiles = {"wasteland_plain.png^[colorize:#ffb24a:220"},
    visual_scale = 0.65,
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    light_source = 12,
    selection_box = {
        type = "fixed",
        fixed = {-0.18, -0.5, -0.18, 0.18, 0.35, 0.18},
    },
})

register_escape_route_node("escape_route_glow_fungus", {
    description = "Permanent Escape Route Glow Fungus",
    drawtype = "nodebox",
    tiles = {"wasteland_plain.png^[colorize:#63ffcf:220"},
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    light_source = 8,
    node_box = {
        type = "fixed",
        fixed = {
            {-0.20, -0.50, -0.18, 0.02, -0.32, 0.04},
            {0.06, -0.50, -0.02, 0.22, -0.36, 0.16},
            {-0.02, -0.50, 0.10, 0.12, -0.38, 0.24},
        },
    },
    selection_box = {
        type = "fixed",
        fixed = {-0.24, -0.5, -0.24, 0.24, -0.06, 0.24},
    },
})

local handle_charge_weapon

local function register_tool(name, def)
    local groupcaps = {}
    if def.tool_type ~= "bow" and def.tool_type ~= "spear" then
        for block_name, block_def in pairs(BLOCK_DEFS) do
            local base_time = def.speed[block_def.material] or 4
            local use_count = def.uses[block_def.material] or 8
            local matches = def.tool_type == block_def.preferred_tool
            local time_multiplier = matches and 1.0 or 1.75
            local durability_multiplier = matches and 1.0 or 0.45
            groupcaps[block_def.group] = {
                times = {
                    [1] = base_time * block_def.difficulty * time_multiplier,
                },
                uses = math.max(1, math.floor(use_count * durability_multiplier / block_def.difficulty)),
                maxlevel = 1,
            }
        end
    end

    local tool_definition = {
        description = def.description,
        inventory_image = texture(name),
        wield_image = texture(name),
        stack_max = def.tool_type == "spear" and 8 or 1,
        tool_capabilities = {
            full_punch_interval = 0.85,
            max_drop_level = 1,
            groupcaps = groupcaps,
            damage_groups = {fleshy = def.damage},
        },
        _tool_type = def.tool_type,
    }

    if def.tool_type == "bow" or def.tool_type == "spear" then
        tool_definition.wield_scale = def.tool_type == "bow" and {x = 2.2, y = 2.2, z = 1.0} or {x = 1.6, y = 1.6, z = 1.0}
        tool_definition.on_use = function(itemstack, user)
            if not user or not user:is_player() then
                return itemstack
            end
            return handle_charge_weapon(itemstack, user, def.tool_type, "dig")
        end
        tool_definition.on_secondary_use = function(itemstack, user)
            if not user or not user:is_player() then
                return itemstack
            end
            return handle_charge_weapon(itemstack, user, def.tool_type, "place")
        end
    end

    minetest.register_tool(modname .. ":" .. name, tool_definition)
end

for name, def in pairs(TOOL_DEFS) do
    register_tool(name, def)
end

for stage = 1, 3 do
    minetest.register_tool(modname .. ":scrap_bow_pulling_" .. stage, {
        description = "Scrap Bow",
        inventory_image = texture("scrap_bow_pulling_" .. stage),
        wield_image = texture("scrap_bow_pulling_" .. stage),
        wield_scale = {x = 2.35, y = 2.35, z = 1.0},
        groups = {not_in_creative_inventory = 1},
        tool_capabilities = {
            full_punch_interval = 0.85,
            max_drop_level = 0,
            groupcaps = {},
            damage_groups = {fleshy = 1},
        },
        on_use = function(itemstack, user)
            if not user or not user:is_player() then
                return itemstack
            end
            return handle_charge_weapon(itemstack, user, "bow", "dig")
        end,
        on_secondary_use = function(itemstack, user)
            if not user or not user:is_player() then
                return itemstack
            end
            return handle_charge_weapon(itemstack, user, "bow", "place")
        end,
        _tool_type = "bow",
        _bow_stage = stage,
    })
end

minetest.register_craftitem(modname .. ":arrow", {
    description = "Arrow",
    inventory_image = texture("arrow"),
    stack_max = 64,
})

minetest.register_craft({
    output = modname .. ":rust_axe",
    recipe = {
        {modname .. ":scrap_metal", modname .. ":scrap_metal", ""},
        {modname .. ":scrap_metal", modname .. ":rotted_wood", ""},
        {"", modname .. ":rotted_wood", ""},
    },
})

minetest.register_craft({
    output = modname .. ":stone_pick",
    recipe = {
        {modname .. ":rubble", modname .. ":rubble", modname .. ":rubble"},
        {"", modname .. ":rotted_wood", ""},
        {"", modname .. ":rotted_wood", ""},
    },
})

minetest.register_craft({
    output = modname .. ":field_shovel",
    recipe = {
        {"", modname .. ":scrap_metal", ""},
        {"", modname .. ":rotted_wood", ""},
        {"", modname .. ":rotted_wood", ""},
    },
})

minetest.register_craft({
    output = modname .. ":scrap_bow",
    recipe = {
        {"", modname .. ":rotted_wood", modname .. ":scrap_metal"},
        {modname .. ":rotted_wood", "", modname .. ":scrap_metal"},
        {"", modname .. ":rotted_wood", modname .. ":scrap_metal"},
    },
})

minetest.register_craft({
    output = modname .. ":arrow 8",
    recipe = {
        {"", modname .. ":scrap_metal", ""},
        {"", modname .. ":rotted_wood", ""},
        {"", modname .. ":dry_grass", ""},
    },
})

minetest.register_craft({
    output = modname .. ":throwing_spear",
    recipe = {
        {"", modname .. ":scrap_metal", ""},
        {"", modname .. ":rotted_wood", ""},
        {"", modname .. ":rotted_wood", ""},
    },
})

minetest.register_craft({
    output = modname .. ":workbench",
    recipe = {
        {modname .. ":rotted_wood", modname .. ":rotted_wood"},
        {modname .. ":rotted_wood", modname .. ":rotted_wood"},
    },
})

minetest.register_craft({
    output = modname .. ":torch 4",
    recipe = {
        {modname .. ":dry_grass"},
        {modname .. ":rotted_wood"},
    },
})

local CHARGE_MAX_SECONDS = 2.0
local CHARGE_MID_SECONDS = 0.65
local CHARGE_FULL_SECONDS = 1.35

local CHARGE_TIERS = {
    light = {
        label = "Light",
        bow_speed = 15,
        bow_damage = 3,
        bow_gravity = 14.0,
        spear_speed = 12,
        spear_damage = 5,
        spear_gravity = 13.0,
    },
    mid = {
        label = "Mid",
        bow_speed = 22,
        bow_damage = 4,
        bow_gravity = 10.8,
        spear_speed = 17,
        spear_damage = 7,
        spear_gravity = 10.5,
    },
    full = {
        label = "Full",
        bow_speed = 30,
        bow_damage = 6,
        bow_gravity = 7.8,
        spear_speed = 23,
        spear_damage = 9,
        spear_gravity = 8.0,
    },
}

local function charge_tier(charge)
    if charge >= CHARGE_FULL_SECONDS then
        return CHARGE_TIERS.full
    end
    if charge >= CHARGE_MID_SECONDS then
        return CHARGE_TIERS.mid
    end
    return CHARGE_TIERS.light
end

local function charge_stage(charge)
    if charge >= CHARGE_FULL_SECONDS then
        return 3
    end
    if charge >= CHARGE_MID_SECONDS then
        return 2
    end
    return 1
end

local function clear_charge_state(meta)
    meta:set_string("wf_charging_weapon", "")
    meta:set_float("wf_charge_started", 0)
    meta:set_string("wf_charge_dig_was_down", "")
    meta:set_string("wf_charge_button", "")
end

local BOW_BONE_ANIMATIONS = {
    idle = {x = 1, y = 10},
    light = {x = 11, y = 20},
    mid = {x = 21, y = 30},
    full = {x = 31, y = 40},
    release = {x = 41, y = 50},
    spear_light = {x = 51, y = 60},
    spear_mid = {x = 51, y = 60},
    spear_full = {x = 61, y = 70},
    spear_release = {x = 71, y = 80},
}

local bow_bone_overlays = {}

minetest.register_entity(modname .. ":bow_bone_overlay", {
    initial_properties = {
        physical = false,
        pointable = false,
        visual = "mesh",
        mesh = "wasteland_mc_archer.b3d",
        textures = {texture("mc_archer")},
        visual_size = {x = 0.55, y = 0.55, z = 0.55},
        static_save = false,
        glow = 1,
    },
})

local function set_player_archer_visual(player)
    player:set_properties({
        visual = "mesh",
        mesh = "wasteland_mc_archer.b3d",
        textures = {texture("mc_archer")},
        visual_size = WF_PLAYER_VISUAL_SIZE,
    })
end

local function get_bow_bone_overlay(player)
    local name = player:get_player_name()
    local object = bow_bone_overlays[name]
    if object and object:get_pos() then
        return object
    end

    object = minetest.add_entity(player:get_pos(), modname .. ":bow_bone_overlay")
    if not object then
        return nil
    end
    object:set_attach(player, "", {x = 7, y = 5, z = 10}, {x = -8, y = 14, z = 0})
    bow_bone_overlays[name] = object
    return object
end

local function remove_bow_bone_overlay(player)
    local name = player:get_player_name()
    local object = bow_bone_overlays[name]
    if object and object:get_pos() then
        object:remove()
    end
    bow_bone_overlays[name] = nil
end

local function set_player_bone_animation(player, animation, speed, loop)
    local meta = player:get_meta()
    if meta:get_string("wf_bone_animation") == animation then
        return
    end
    player:set_animation(BOW_BONE_ANIMATIONS[animation], speed or 1, 0, loop ~= false)
    meta:set_string("wf_bone_animation", animation)

    local overlay = bow_bone_overlays[player:get_player_name()]
    if overlay and overlay:get_pos() then
        overlay:set_animation(BOW_BONE_ANIMATIONS[animation], speed or 1, 0, loop ~= false)
    end
end

local function bone_animation_for_charge(charge)
    local stage = charge_stage(charge)
    if stage == 3 then
        return "full"
    end
    if stage == 2 then
        return "mid"
    end
    return "light"
end

local function update_bow_bone_animation(player)
    local meta = player:get_meta()
    local now = minetest.get_us_time() / 1000000
    if meta:get_float("wf_bow_release_anim_until") > now then
        return
    end

    local weapon = meta:get_string("wf_charging_weapon")
    if weapon == "bow" then
        local charge = math.min(CHARGE_MAX_SECONDS, now - meta:get_float("wf_charge_started"))
        get_bow_bone_overlay(player)
        set_player_bone_animation(player, bone_animation_for_charge(charge), 1, true)
        return
    end

    if weapon == "spear" then
        local charge = math.min(CHARGE_MAX_SECONDS, now - meta:get_float("wf_charge_started"))
        set_player_bone_animation(player, "spear_" .. bone_animation_for_charge(charge), 1, true)
        return
    end

    remove_bow_bone_overlay(player)
    set_player_bone_animation(player, "idle", 1, true)
end

local function play_bow_release_bone_animation(player)
    local meta = player:get_meta()
    meta:set_string("wf_bone_animation", "")
    get_bow_bone_overlay(player)
    set_player_bone_animation(player, "release", 24, false)
    meta:set_float("wf_bow_release_anim_until", minetest.get_us_time() / 1000000 + 0.35)
    minetest.after(0.35, function()
        if player and player:is_player() then
            remove_bow_bone_overlay(player)
            update_bow_bone_animation(player)
        end
    end)
end

local function play_spear_release_bone_animation(player)
    local meta = player:get_meta()
    meta:set_string("wf_bone_animation", "")
    set_player_bone_animation(player, "spear_release", 28, false)
    meta:set_float("wf_bow_release_anim_until", minetest.get_us_time() / 1000000 + 0.35)
    minetest.after(0.35, function()
        if player and player:is_player() then
            update_bow_bone_animation(player)
        end
    end)
end

local direction_to_rotation
local projectile_rotation

local function launch_projectile(user, projectile_name, speed, damage, gravity)
    local pos = user:get_pos()
    local dir = user:get_look_dir()
    local props = user:get_properties() or {}
    local eye_height = props.eye_height or 1.47
    local start_pos = vector.add(pos, {x = 0, y = eye_height, z = 0})
    start_pos = vector.add(start_pos, vector.multiply(dir, 0.35))
    local object = minetest.add_entity(start_pos, modname .. ":" .. projectile_name)
    if not object then
        return
    end
    object:set_velocity(vector.multiply(dir, speed))
    object:set_acceleration({x = 0, y = -(gravity or 9.8), z = 0})
    local entity = object:get_luaentity()
    if direction_to_rotation then
        local rotation_offset = entity and entity.rotation_offset or nil
        object:set_rotation(projectile_rotation(dir, rotation_offset))
    else
        object:set_yaw(math.atan2(dir.z, dir.x) - math.pi / 2)
    end
    if entity then
        entity.owner = user:get_player_name()
        entity.damage = damage
        entity.spawn_grace = 0.16
    end
end

local DAMAGE_RULES = {
    hand = 1,
    falling_brick_debris = 3,
    tools = {
        rust_axe = TOOL_DEFS.rust_axe.damage,
        stone_pick = TOOL_DEFS.stone_pick.damage,
        field_shovel = TOOL_DEFS.field_shovel.damage,
        scrap_bow = TOOL_DEFS.scrap_bow.damage,
        throwing_spear = TOOL_DEFS.throwing_spear.damage,
    },
    projectiles = {
        bow_light = CHARGE_TIERS.light.bow_damage,
        bow_mid = CHARGE_TIERS.mid.bow_damage,
        bow_full = CHARGE_TIERS.full.bow_damage,
        spear_light = CHARGE_TIERS.light.spear_damage,
        spear_mid = CHARGE_TIERS.mid.spear_damage,
        spear_full = CHARGE_TIERS.full.spear_damage,
    },
}

local function damage_from_wielded_tool(puncher, fallback_damage)
    if not puncher or not puncher:is_player() then
        return fallback_damage and fallback_damage > 0 and fallback_damage or DAMAGE_RULES.hand
    end
    local stack = puncher:get_wielded_item()
    local item_name = stack:get_name()
    local key = item_name:gsub("^" .. modname .. ":", "")
    if DAMAGE_RULES.tools[key] then
        return DAMAGE_RULES.tools[key]
    end
    if key:find("^scrap_bow_pulling_") then
        return DAMAGE_RULES.tools.scrap_bow
    end
    return fallback_damage and fallback_damage > 0 and fallback_damage or DAMAGE_RULES.hand
end

local function health_bar_text(hp, max_hp)
    local total = 8
    local safe_max = math.max(1, max_hp or hp or 1)
    local safe_hp = math.max(0, math.min(safe_max, hp or safe_max))
    local filled = math.floor((safe_hp / safe_max) * total + 0.5)
    return safe_hp .. "/" .. safe_max .. "  |" .. string.rep("=", filled) .. string.rep(".", total - filled) .. "|"
end

_wf_player_close_to_entity = function(entity, distance)
    local pos = entity.object and entity.object:get_pos()
    if not pos then
        return false
    end
    local max_distance = distance or 8
    for _, player in ipairs(minetest.get_connected_players()) do
        local player_pos = player:get_pos()
        if player_pos and vector.distance(pos, player_pos) <= max_distance then
            return true
        end
    end
    return false
end

_wf_hide_entity_healthbar = function(entity)
    if entity and entity.object and entity.healthbar_visible ~= false then
        entity.object:set_nametag_attributes({text = ""})
        entity.healthbar_visible = false
        entity.healthbar_last_text = ""
    end
end

local function update_entity_healthbar(entity, force)
    if not entity or not entity.object then
        return
    end
    if entity.hide_healthbar or not _wf_player_close_to_entity(entity, entity.healthbar_distance) then
        _wf_hide_entity_healthbar(entity)
        return
    end
    local hp = entity.healthbar_hp or entity.object:get_hp()
    if not hp or hp <= 0 then
        _wf_hide_entity_healthbar(entity)
        return
    end
    local max_hp = entity.max_hp or hp
    local name = entity.health_name or "Creature"
    local text = name .. "\n" .. health_bar_text(hp, max_hp)
    if not force and entity.healthbar_visible and entity.healthbar_last_text == text then
        return
    end
    entity.object:set_nametag_attributes({
        text = text,
        color = entity.health_color or "#eeeeee",
        bgcolor = entity.health_bgcolor or "#201611c8",
    })
    entity.healthbar_visible = true
    entity.healthbar_last_text = text
end

local function setup_entity_health(entity, description, max_hp, color, options)
    options = options or {}
    entity.max_hp = max_hp
    entity.health_name = description
    entity.health_color = color or "#eeeeee"
    entity.health_bgcolor = options.bgcolor or "#201611c8"
    entity.healthbar_distance = options.distance or 8
    entity.hide_healthbar = options.hide_healthbar == true
    entity.healthbar_hp = max_hp
    entity.object:set_hp(max_hp)
    entity.object:set_armor_groups({immortal = 1})
    update_entity_healthbar(entity)
end

local function player_from_damage_source(source)
    if type(source) == "string" then
        return minetest.get_player_by_name(source)
    end
    if source and source.is_player and source:is_player() then
        return source
    end
    return nil
end

local function random_drop_count(drop)
    if drop.count then
        return drop.count
    end
    local min_count = drop.min or 1
    local max_count = drop.max or min_count
    return math.random(min_count, max_count)
end

local function drop_entity_loot(pos, drops)
    if not pos or not drops then
        return
    end
    for _, drop in ipairs(drops) do
        if type(drop) == "string" then
            minetest.add_item(pos, drop)
        elseif math.random() <= (drop.chance or 1) then
            local count = random_drop_count(drop)
            if count > 0 then
                minetest.add_item(pos, drop.item .. " " .. count)
            end
        end
    end
end

_wf_spawn_pickup_item = function(pos, item_name)
    if not pos or not item_name then
        return nil
    end
    local object = minetest.add_item(pos, item_name)
    if object then
        object:set_velocity({x = 0, y = 1.5, z = 0})
    end
    return object
end

local function handle_entity_death(entity, pos, source)
    if not entity or entity.death_handled then
        return
    end
    entity.death_handled = true
    drop_entity_loot(pos, entity and entity.drops)
    local player = player_from_damage_source(source)
    if not player and entity.last_damage_player then
        player = minetest.get_player_by_name(entity.last_damage_player)
    end
    if player and entity and record_player_event then
        local kill_key = entity.kill_event or (entity.name and entity.name:gsub("^" .. modname .. ":", ""))
        if kill_key and kill_key ~= "" and not entity.kill_event_recorded then
            entity.kill_event_recorded = true
            record_player_event(player, "kill_" .. kill_key, 1)
            if kill_key == "bear" then
                minetest.chat_send_player(player:get_player_name(), "Bear defeated. Kill counted.")
            end
        end
    end
end

local function damage_object(object, damage, source)
    local amount = math.max(0, damage or 0)
    if amount <= 0 then
        return
    end
    if object:is_player() then
        object:set_hp(math.max(0, object:get_hp() - amount))
        return
    end
    local entity = object:get_luaentity()
    if entity and object:get_hp() then
        local source_player = player_from_damage_source(source)
        if source_player then
            entity.last_damage_player = source_player:get_player_name()
        end
        local current_hp = entity.healthbar_hp or object:get_hp() or entity.max_hp or amount
        if entity.max_hp then
            current_hp = math.min(current_hp, entity.max_hp)
        end
        local new_hp = math.max(0, current_hp - amount)
        entity.healthbar_hp = new_hp
        object:set_hp(new_hp)
        update_entity_healthbar(entity, true)
        if source_player and entity.health_name and entity.max_hp then
            minetest.chat_send_player(
                source_player:get_player_name(),
                "Hit " .. entity.health_name .. " for " .. amount .. ". HP " .. new_hp .. "/" .. entity.max_hp
            )
        end
        if new_hp <= 0 then
            entity.dead = true
            entity.healthbar_hp = 0
            _wf_hide_entity_healthbar(entity)
            object:set_properties({
                physical = false,
                collide_with_objects = false,
                pointable = false,
                visual_size = {x = 0, y = 0, z = 0},
            })
            object:set_velocity({x = 0, y = 0, z = 0})
            handle_entity_death(entity, object:get_pos(), source)
            object:remove()
        end
    end
end

local function projectile_can_hit_object(projectile, object)
    if object == projectile.object then
        return false
    end
    if object:is_player() then
        return object:get_player_name() ~= projectile.owner and (projectile.spawn_grace or 0) <= 0
    end
    local entity = object:get_luaentity()
    if not entity then
        return false
    end
    if entity.dead then
        return false
    end
    if entity.name == "__builtin:item"
        or entity.name == modname .. ":bow_bone_overlay"
        or entity.name == modname .. ":arrow_projectile"
        or entity.name == modname .. ":spear_projectile"
        or entity.name == modname .. ":falling_brick_debris" then
        return false
    end
    if (projectile.spawn_grace or 0) > 0 then
        return false
    end
    return object:get_hp() ~= nil
end

local function velocity_length(velocity)
    return math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z)
end

local function normalized_velocity(velocity)
    local length = velocity_length(velocity)
    if length < 0.05 then
        return nil
    end
    return {x = velocity.x / length, y = velocity.y / length, z = velocity.z / length}
end

direction_to_rotation = function(direction)
    local horizontal = math.sqrt(direction.x * direction.x + direction.z * direction.z)
    return {
        x = -math.atan2(direction.y, horizontal),
        y = math.atan2(direction.x, direction.z),
        z = 0,
    }
end

local ARROW_AXIS_OFFSETS = {
    [0] = {x = 0, y = 0, z = 0},
    [1] = {x = 0, y = math.pi / 2, z = 0},
    [2] = {x = 0, y = -math.pi / 2, z = 0},
    [3] = {x = 0, y = math.pi, z = 0},
    [4] = {x = math.pi / 2, y = 0, z = 0},
    [5] = {x = -math.pi / 2, y = 0, z = 0},
}

local function arrow_axis_offset()
    local mode = storage:get_int("wf_arrow_axis_mode")
    return ARROW_AXIS_OFFSETS[mode] or ARROW_AXIS_OFFSETS[0]
end

projectile_rotation = function(direction, rotation_offset)
    local rotation = direction_to_rotation(direction)
    if rotation_offset then
        if rotation_offset == "arrow_axis" then
            rotation_offset = arrow_axis_offset()
        end
        rotation.x = rotation.x + (rotation_offset.x or 0)
        rotation.y = rotation.y + (rotation_offset.y or 0)
        rotation.z = rotation.z + (rotation_offset.z or 0)
    end
    return rotation
end

local function projectile_surface_hit_pos(previous_pos, pos)
    if previous_pos then
        local ray = minetest.raycast(previous_pos, pos, false, false)
        if ray then
            for pointed in ray do
                if pointed.type == "node" and pointed.intersection_point then
                    return pointed.intersection_point
                end
            end
        end
    end
    return pos
end

local function register_projectile(name, description, texture_name, pickup_item, default_damage, visual_size, options)
    options = options or {}
    local textures = options.textures or {texture(texture_name)}
    minetest.register_entity(modname .. ":" .. name, {
        initial_properties = {
            physical = false,
            collide_with_objects = true,
            pointable = false,
            collisionbox = {-0.08, -0.08, -0.08, 0.08, 0.08, 0.08},
            visual = options.visual or "sprite",
            mesh = options.mesh,
            visual_size = visual_size or {x = 0.75, y = 0.75},
            textures = textures,
            static_save = false,
            glow = 1,
        },
        owner = "",
        timer = 0,
        stuck = false,
        stuck_timer = 0,
        stuck_life = options.stuck_life or 4.0,
        last_direction = nil,
        previous_pos = nil,
        stuck_rotation = nil,
        damage = default_damage,
        rotation_offset = options.rotation_offset,
        remove_projectile = function(self)
            self.object:remove()
        end,
        on_activate = function(self)
            self.last_direction = {x = 0, y = 0, z = 1}
            self.previous_pos = nil
        end,
        stick = function(self, pos)
            if not options.sticky then
                return false
            end
            local direction = self.last_direction or normalized_velocity(self.object:get_velocity()) or {x = 0, y = 0, z = 1}
            local stuck_pos = vector.subtract(pos, vector.multiply(direction, options.stick_offset or 0.60))
            self.stuck = true
            self.stuck_timer = 0
            self.stuck_rotation = projectile_rotation(direction, options.rotation_offset)
            self.object:set_velocity({x = 0, y = 0, z = 0})
            self.object:set_acceleration({x = 0, y = 0, z = 0})
            self.object:set_pos(stuck_pos)
            self.object:set_rotation(self.stuck_rotation)
            if pickup_item and options.pickup_when_stuck then
                self.object:set_properties({pointable = true})
            end
            return true
        end,
        on_rightclick = function(self, clicker)
            if not self.stuck or not pickup_item or not options.pickup_when_stuck then
                return
            end
            if clicker and clicker:is_player() then
                clicker:get_inventory():add_item("main", pickup_item)
                self:remove_projectile()
            end
        end,
        on_step = function(self, dtime)
            self.timer = self.timer + dtime
            self.spawn_grace = math.max(0, (self.spawn_grace or 0) - dtime)
            local pos = self.object:get_pos()
            local previous_pos = self.previous_pos
            self.previous_pos = pos

            if self.stuck then
                self.stuck_timer = self.stuck_timer + dtime
                local wobble = math.sin(self.stuck_timer * 42) * 0.018 + (math.random() - 0.5) * 0.006
                self.object:set_rotation({
                    x = self.stuck_rotation.x + wobble * 0.45,
                    y = self.stuck_rotation.y + wobble,
                    z = self.stuck_rotation.z + wobble * 0.7,
                })
                if self.stuck_timer > self.stuck_life then
                    if options.drop_when_stuck_expires and pickup_item then
                        minetest.add_item(self.object:get_pos(), pickup_item)
                    end
                    self:remove_projectile()
                end
                return
            end

            local direction = nil
            if previous_pos and dtime > 0 then
                direction = normalized_velocity(vector.subtract(pos, previous_pos))
            end
            if not direction then
                direction = normalized_velocity(self.object:get_velocity())
            end
            if direction then
                self.last_direction = direction
                self.object:set_rotation(projectile_rotation(direction, options.rotation_offset))
            end

            if self.timer > 8 then
                if pickup_item then
                    minetest.add_item(pos, pickup_item)
                end
                self:remove_projectile()
                return
            end

            local node_hit_pos = nil
            if previous_pos then
                local ray = minetest.raycast(previous_pos, pos, true, false)
                if ray then
                    for pointed in ray do
                        if pointed.type == "object" and pointed.ref and projectile_can_hit_object(self, pointed.ref) then
                            damage_object(pointed.ref, self.damage, self.owner)
                            self:remove_projectile()
                            return
                        end
                        if pointed.type == "node" and pointed.intersection_point then
                            node_hit_pos = pointed.intersection_point
                            break
                        end
                    end
                end
            else
                local node = minetest.get_node_or_nil(pos)
                if node and node.name ~= "air" and node.name ~= "ignore" then
                    node_hit_pos = pos
                end
            end
            if node_hit_pos then
                if self:stick(node_hit_pos) then
                    return
                end
                if pickup_item then
                    minetest.add_item(pos, pickup_item)
                end
                self:remove_projectile()
                return
            end

            for _, object in ipairs(minetest.get_objects_inside_radius(pos, options.hit_radius or 0.55)) do
                if projectile_can_hit_object(self, object) then
                    damage_object(object, self.damage, self.owner)
                    self:remove_projectile()
                    return
                end
            end
        end,
    })
end

register_projectile("arrow_projectile", "Arrow Projectile", "arrow_projectile", modname .. ":arrow", 3, {x = 2.4, y = 2.4, z = 2.4}, {
    visual = "mesh",
    mesh = "wasteland_arrow_projectile.obj",
    textures = {
        texture("arrow_projectile"),
        texture("arrow_projectile"),
        texture("arrow_projectile"),
        texture("arrow_projectile"),
        texture("arrow_projectile"),
        texture("arrow_projectile"),
    },
    sticky = true,
    pickup_when_stuck = true,
    stick_offset = 0.72,
    stuck_life = 8.0,
    hit_radius = 0.65,
    rotation_offset = "arrow_axis",
})
register_projectile("spear_projectile", "Spear Projectile", "spear_projectile", modname .. ":throwing_spear", 6, {x = 1.15, y = 1.15, z = 1.15}, {
    visual = "mesh",
    mesh = "wasteland_spear_projectile.b3d",
    textures = {texture("spear_projectile")},
    sticky = true,
    stick_offset = 0.58,
    stuck_life = 10.0,
    hit_radius = 0.75,
    drop_when_stuck_expires = true,
})

minetest.register_entity(modname .. ":falling_brick_debris", {
    initial_properties = {
        physical = false,
        collide_with_objects = false,
        collisionbox = {-0.22, -0.22, -0.22, 0.22, 0.22, 0.22},
        visual = "cube",
        visual_size = {x = 0.45, y = 0.45, z = 0.45},
        textures = {
            texture("rubble"), texture("rubble"), texture("rubble"),
            texture("rubble"), texture("rubble"), texture("rubble"),
        },
        static_save = false,
    },
    timer = 0,
    on_activate = function(self)
        self.object:set_velocity({x = 0, y = -5.5, z = 0})
        self.object:set_acceleration({x = 0, y = -9.8, z = 0})
    end,
    on_step = function(self, dtime)
        self.timer = self.timer + dtime
        local pos = self.object:get_pos()
        for _, object in ipairs(minetest.get_objects_inside_radius(pos, 0.8)) do
            if object:is_player() then
                damage_object(object, 3)
                self.object:remove()
                return
            end
        end
        local node = minetest.get_node_or_nil(pos)
        local def = node and minetest.registered_nodes[node.name]
        if self.timer > 4 or (def and def.walkable) then
            self.object:remove()
        end
    end,
})

local function bow_stage_item(stage)
    return modname .. ":scrap_bow_pulling_" .. stage
end

local function is_bow_stack(stack)
    local name = stack:get_name()
    return name == modname .. ":scrap_bow"
        or name == bow_stage_item(1)
        or name == bow_stage_item(2)
        or name == bow_stage_item(3)
end

local function stack_charge_weapon_type(stack)
    if is_bow_stack(stack) then
        return "bow"
    end
    return nil
end

local function replace_wielded_bow(user, item_name)
    local stack = user:get_wielded_item()
    local wear = stack:get_wear()
    local new_stack = ItemStack(item_name)
    new_stack:set_wear(wear)
    user:set_wielded_item(new_stack)
    return new_stack
end

local function restore_normal_bow(user)
    local stack = user:get_wielded_item()
    if is_bow_stack(stack) then
        return replace_wielded_bow(user, modname .. ":scrap_bow")
    end
    return stack
end

local function update_bow_draw_stage(user)
    local meta = user:get_meta()
    if meta:get_string("wf_charging_weapon") ~= "bow" then
        return
    end
    local stack = user:get_wielded_item()
    if not is_bow_stack(stack) then
        return
    end
    local charge = math.min(CHARGE_MAX_SECONDS, minetest.get_us_time() / 1000000 - meta:get_float("wf_charge_started"))
    local stage = charge_stage(charge)
    if stack:get_name() ~= bow_stage_item(stage) then
        replace_wielded_bow(user, bow_stage_item(stage))
    end
end

local function release_charged_weapon(user)
    local meta = user:get_meta()
    local now = minetest.get_us_time() / 1000000
    local weapon_type = meta:get_string("wf_charging_weapon")
    local charge_started = meta:get_float("wf_charge_started")

    if weapon_type == "" or charge_started <= 0 then
        return
    end

    local stack = user:get_wielded_item()
    local stack_name = stack:get_name()
    if weapon_type == "bow" and not is_bow_stack(stack) then
        clear_charge_state(meta)
        restore_normal_bow(user)
        return
    end
    if weapon_type == "spear" and stack_name ~= modname .. ":throwing_spear" then
        clear_charge_state(meta)
        return
    end

    local charge = math.min(CHARGE_MAX_SECONDS, now - charge_started)
    local tier = charge_tier(charge)
    clear_charge_state(meta)

    if weapon_type == "bow" then
        stack = restore_normal_bow(user)
        local inv = user:get_inventory()
        if not inv:contains_item("main", modname .. ":arrow") then
            minetest.chat_send_player(user:get_player_name(), "No arrows.")
            return
        end
        inv:remove_item("main", modname .. ":arrow 1")
        launch_projectile(user, "arrow_projectile", tier.bow_speed, tier.bow_damage, tier.bow_gravity)
        play_bow_release_bone_animation(user)
        stack:add_wear(math.floor(600 + tier.bow_damage * 120))
        user:set_wielded_item(stack)
        return
    end

    stack:take_item(1)
    play_spear_release_bone_animation(user)
    launch_projectile(user, "spear_projectile", tier.spear_speed, tier.spear_damage, tier.spear_gravity)
    user:set_wielded_item(stack)
end

handle_charge_weapon = function(itemstack, user, weapon_type, button)
    local meta = user:get_meta()
    local now = minetest.get_us_time() / 1000000
    local charging_weapon = meta:get_string("wf_charging_weapon")
    local charge_started = meta:get_float("wf_charge_started")

    if charging_weapon == weapon_type and charge_started > 0 then
        return itemstack
    end

    if charging_weapon ~= "" then
        clear_charge_state(meta)
    end

    meta:set_string("wf_charging_weapon", weapon_type)
    meta:set_float("wf_charge_started", now)
    if weapon_type == "bow" then
        itemstack = replace_wielded_bow(user, bow_stage_item(1))
    end
    meta:set_string("wf_charge_button", button or "dig")
    meta:set_string("wf_charge_dig_was_down", "true")
    return itemstack
end

local WORKBENCH_RECIPES = {
    rust_axe = {
        label = "Rust Axe",
        output = modname .. ":rust_axe 1",
        cost = {
            {item = modname .. ":scrap_metal", count = 3, label = "Scrap Metal"},
            {item = modname .. ":rotted_wood", count = 2, label = "Rotted Wood"},
        },
    },
    stone_pick = {
        label = "Stone Pickaxe",
        output = modname .. ":stone_pick 1",
        cost = {
            {item = modname .. ":rubble", count = 3, label = "Rubble"},
            {item = modname .. ":rotted_wood", count = 2, label = "Rotted Wood"},
        },
    },
    field_shovel = {
        label = "Field Shovel",
        output = modname .. ":field_shovel 1",
        cost = {
            {item = modname .. ":scrap_metal", count = 1, label = "Scrap Metal"},
            {item = modname .. ":rotted_wood", count = 2, label = "Rotted Wood"},
        },
    },
    scrap_bow = {
        label = "Scrap Bow",
        output = modname .. ":scrap_bow 1",
        cost = {
            {item = modname .. ":rotted_wood", count = 3, label = "Rotted Wood"},
            {item = modname .. ":scrap_metal", count = 3, label = "Scrap Metal"},
        },
    },
    arrow = {
        label = "Arrow x8",
        output = modname .. ":arrow 8",
        cost = {
            {item = modname .. ":scrap_metal", count = 1, label = "Scrap Metal"},
            {item = modname .. ":rotted_wood", count = 1, label = "Rotted Wood"},
            {item = modname .. ":dry_grass", count = 1, label = "Dry Grass"},
        },
    },
    throwing_spear = {
        label = "Throwing Spear",
        output = modname .. ":throwing_spear 1",
        cost = {
            {item = modname .. ":scrap_metal", count = 1, label = "Scrap Metal"},
            {item = modname .. ":rotted_wood", count = 2, label = "Rotted Wood"},
        },
    },
    bandage = {
        label = "Bandage x2",
        output = modname .. ":bandage 2",
        cost = {
            {item = modname .. ":dry_grass", count = 3, label = "Dry Grass"},
            {item = modname .. ":hide", count = 1, label = "Hide"},
        },
    },
    shelter_kit = {
        label = "Shelter Kit",
        output = modname .. ":shelter_kit 1",
        cost = {
            {item = modname .. ":rotted_wood", count = 8, label = "Rotted Wood"},
            {item = modname .. ":rubble", count = 6, label = "Rubble"},
            {item = modname .. ":scrap_metal", count = 3, label = "Scrap Metal"},
        },
    },
    salvage_cart_kit = {
        label = "Salvage Cart Kit",
        output = modname .. ":salvage_cart_kit 1",
        cost = {
            {item = modname .. ":scrap_metal", count = 10, label = "Scrap Metal"},
            {item = modname .. ":machine_parts", count = 3, label = "Machine Parts"},
            {item = modname .. ":fuel_can", count = 1, label = "Fuel Can"},
        },
    },
    handheld_map = {
        label = "Handheld Map",
        output = modname .. ":handheld_map 1",
        cost = {
            {item = modname .. ":dry_grass", count = 2, label = "Dry Grass"},
            {item = modname .. ":rotted_wood", count = 1, label = "Rotted Wood"},
        },
    },
    torch = {
        label = "Storm Torch x4",
        output = modname .. ":torch 4",
        cost = {
            {item = modname .. ":dry_grass", count = 1, label = "Dry Grass"},
            {item = modname .. ":rotted_wood", count = 1, label = "Rotted Wood"},
        },
    },
}

local WORKBENCH_ORDER = {
    "rust_axe",
    "stone_pick",
    "field_shovel",
    "scrap_bow",
    "arrow",
    "throwing_spear",
    "bandage",
    "shelter_kit",
    "salvage_cart_kit",
    "handheld_map",
    "torch",
}

local function recipe_cost_text(recipe)
    local parts = {}
    for _, cost in ipairs(recipe.cost) do
        table.insert(parts, cost.label .. " x" .. cost.count)
    end
    return table.concat(parts, ", ")
end

local function can_craft(inv, recipe)
    for _, cost in ipairs(recipe.cost) do
        if not inv:contains_item("main", cost.item .. " " .. cost.count) then
            return false
        end
    end
    return true
end

local function craft_workbench_recipe(player, recipe_id)
    local recipe = WORKBENCH_RECIPES[recipe_id]
    if not recipe then
        return false, "Unknown recipe."
    end
    local inv = player:get_inventory()
    if not can_craft(inv, recipe) then
        return false, "Not enough materials."
    end
    local output = ItemStack(recipe.output)
    if not inv:room_for_item("main", output) then
        return false, "Inventory is full."
    end
    for _, cost in ipairs(recipe.cost) do
        inv:remove_item("main", cost.item .. " " .. cost.count)
    end
    inv:add_item("main", output)
    return true, "Crafted " .. recipe.label .. "."
end

local function workbench_formspec()
    local formspec = {
        "formspec_version[6]",
        "size[14,11]",
        "bgcolor[#10161ddd;true]",
        "label[0.45,0.45;Workbench]",
        "box[0.4,0.85;6.35,8.8;#1b242dcc]",
        "label[0.65,1.1;Recipes]",
    }
    for index, recipe_id in ipairs(WORKBENCH_ORDER) do
        local recipe = WORKBENCH_RECIPES[recipe_id]
        local col = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        local x = 0.65 + col * 3.05
        local y = 1.45 + row * 1.55
        table.insert(formspec, "button[" .. x .. "," .. y .. ";1.05,0.55;craft_" .. recipe_id .. ";Craft]")
        table.insert(formspec, "label[" .. (x + 1.2) .. "," .. (y + 0.02) .. ";" .. recipe.label .. "]")
        table.insert(formspec, "textarea[" .. x .. "," .. (y + 0.55) .. ";2.8,0.52;cost_" .. recipe_id .. ";;" .. minetest.formspec_escape(recipe_cost_text(recipe)) .. "]")
    end
    table.insert(formspec, "box[6.9,0.85;6.45,8.8;#1b242dcc]")
    table.insert(formspec, "label[7.15,1.1;Inventory]")
    table.insert(formspec, "list[current_player;main;7.15,1.5;6,5;]")
    table.insert(formspec, "label[7.15,7.2;Hotbar]")
    table.insert(formspec, "list[current_player;main;7.15,7.55;6,1;]")
    table.insert(formspec, "textarea[0.65,9.85;11.5,0.55;hint;;Use the workbench to craft tools and ranged weapons from wasteland materials.]")
    table.insert(formspec, "button_exit[11.55,10.15;1.6,0.55;close;Close]")
    table.insert(formspec, "listring[current_player;main]")
    return table.concat(formspec)
end

local function show_workbench(player)
    minetest.show_formspec(player:get_player_name(), modname .. ":workbench", workbench_formspec())
end

minetest.register_node(modname .. ":workbench", {
    description = "Workbench",
    tiles = {texture("workbench")},
    groups = {wf_rotted_wood = 1, oddly_breakable_by_hand = 2},
    drop = "",
    on_rightclick = function(pos, node, clicker)
        if clicker and clicker:is_player() then
            show_workbench(clicker)
        end
    end,
    after_dig_node = function(pos, oldnode)
        minetest.add_item(vector.add(pos, {x = 0.5, y = 0.25, z = 0.5}), oldnode.name)
    end,
})

minetest.register_craftitem(modname .. ":canned_food", {
    description = "Canned Food",
    inventory_image = texture("loot_crate_residential"),
    on_use = function(itemstack, user)
        if user and user:is_player() then
            user:set_hp(math.min(20, user:get_hp() + 4))
            itemstack:take_item()
        end
        return itemstack
    end,
})

minetest.register_craftitem(modname .. ":weapon_parts", {
    description = "Weapon Parts",
    inventory_image = texture("scrap_metal"),
})

minetest.register_craftitem(modname .. ":machine_parts", {
    description = "Machine Parts",
    inventory_image = texture("scrap_metal"),
})

minetest.register_craftitem(modname .. ":fuel_can", {
    description = "Fuel Can",
    inventory_image = texture("dirty_water"),
})

minetest.register_craftitem(modname .. ":raincoat", {
    description = "Raincoat",
    inventory_image = texture("raincoat"),
    on_use = function(itemstack, user)
        if user and user:is_player() then
            local meta = user:get_meta()
            local wearing = meta:get_string("wf_wearing_raincoat") == "true"
            meta:set_string("wf_wearing_raincoat", wearing and "" or "true")
            minetest.chat_send_player(user:get_player_name(), wearing and "Raincoat removed." or "Raincoat equipped. Rain damage blocked.")
        end
        return itemstack
    end,
})

local function consume_and_heal(user, itemstack, amount, message)
    if user and user:is_player() then
        user:set_hp(math.min(20, user:get_hp() + amount))
        if message then
            minetest.chat_send_player(user:get_player_name(), message)
        end
        itemstack:take_item()
    end
    return itemstack
end

local function show_player_map(player)
    if not player or not player:is_player() then
        return
    end
    minetest.show_formspec(player:get_player_name(), modname .. ":map", minimap_formspec(player))
end

minetest.register_craftitem(modname .. ":raw_meat", {
    description = "Raw Meat",
    inventory_image = texture("tool") .. "^[colorize:#b56c59:140",
    on_use = function(itemstack, user)
        return consume_and_heal(user, itemstack, 2, "Raw meat used.")
    end,
})

minetest.register_craftitem(modname .. ":hide", {
    description = "Hide",
    inventory_image = texture("tool") .. "^[colorize:#8e6b4f:150",
})

minetest.register_craftitem(modname .. ":bear_pelt", {
    description = "Bear Pelt",
    inventory_image = texture("tool") .. "^[colorize:#5d4a36:170",
})

minetest.register_craftitem(modname .. ":bandage", {
    description = "Bandage",
    inventory_image = texture("tool") .. "^[colorize:#d8c7bb:190",
    on_use = function(itemstack, user)
        return consume_and_heal(user, itemstack, 4, "Bandage applied.")
    end,
})

minetest.register_craftitem(modname .. ":shelter_kit", {
    description = "Shelter Kit",
    inventory_image = texture("workbench") .. "^[colorize:#7ba77d:120",
    on_place = function(itemstack, user, pointed_thing)
        if not user or not user:is_player() then
            return itemstack
        end
        if place_player_shelter and place_player_shelter(user, pointed_thing) then
            itemstack:take_item()
            return itemstack
        end
        minetest.chat_send_player(user:get_player_name(), "Shelter kit needs a clear patch of ground.")
        return itemstack
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        return minetest.registered_craftitems[modname .. ":shelter_kit"].on_place(itemstack, user, pointed_thing)
    end,
})

minetest.register_craftitem(modname .. ":salvage_cart_kit", {
    description = "Salvage Cart Kit",
    inventory_image = texture("scrap_metal") .. "^[colorize:#7cb2d8:125",
    on_place = function(itemstack, user, pointed_thing)
        if not user or not user:is_player() then
            return itemstack
        end
        if place_vehicle_entity and place_vehicle_entity(user, pointed_thing) then
            itemstack:take_item()
            return itemstack
        end
        minetest.chat_send_player(user:get_player_name(), "Cart needs level ground and open space.")
        return itemstack
    end,
    on_secondary_use = function(itemstack, user, pointed_thing)
        return minetest.registered_craftitems[modname .. ":salvage_cart_kit"].on_place(itemstack, user, pointed_thing)
    end,
})

minetest.register_craftitem(modname .. ":handheld_map", {
    description = "Handheld Map",
    inventory_image = texture("plain") .. "^[colorize:#e0d8a0:130",
    on_use = function(itemstack, user)
        if user and user:is_player() then
            show_player_map(user)
        end
        return itemstack
    end,
    on_secondary_use = function(itemstack, user)
        if user and user:is_player() then
            show_player_map(user)
        end
        return itemstack
    end,
})

minetest.register_node(modname .. ":hand_lamp", {
    description = "Hand Lamp",
    drawtype = "nodebox",
    tiles = {
        texture("plain") .. "^[colorize:#ffd85a:210",
        texture("scrap_metal") .. "^[colorize:#2b2b2b:120",
        texture("plain") .. "^[colorize:#ffd85a:190",
    },
    inventory_image = texture("plain") .. "^[colorize:#ffd85a:210",
    wield_image = texture("plain") .. "^[colorize:#ffd85a:210",
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    light_source = 11,
    groups = {oddly_breakable_by_hand = 2},
    node_box = {
        type = "fixed",
        fixed = {-0.24, -0.50, -0.16, 0.24, -0.18, 0.16},
    },
    selection_box = {
        type = "fixed",
        fixed = {-0.28, -0.50, -0.20, 0.28, -0.14, 0.20},
    },
    stack_max = 8,
})

local LOOT_TABLES = {
    cbd = {
        modname .. ":canned_food 2",
        modname .. ":weapon_parts 2",
        modname .. ":arrow 8",
        modname .. ":scrap_metal 6",
        modname .. ":torch 4",
        modname .. ":hand_lamp 1",
        modname .. ":rust_axe",
        modname .. ":stone_pick",
    },
    residential = {
        modname .. ":canned_food 2",
        modname .. ":rotted_wood 6",
        modname .. ":arrow 4",
        modname .. ":torch 3",
        modname .. ":hand_lamp 1",
        modname .. ":field_shovel",
    },
    factory = {
        modname .. ":machine_parts 2",
        modname .. ":fuel_can 1",
        modname .. ":scrap_metal 8",
        modname .. ":weapon_parts 3",
        modname .. ":throwing_spear",
    },
}

local GUARANTEED_LOOT = {
    factory = {
        modname .. ":machine_parts 3",
        modname .. ":fuel_can 1",
    },
}

local SHELF_SUPPLY_TABLES = {
    food = {
        modname .. ":canned_food 1",
        modname .. ":canned_food 2",
        modname .. ":rotted_wood 4",
        modname .. ":arrow 4",
    },
    parts = {
        modname .. ":scrap_metal 4",
        modname .. ":rubble 6",
        modname .. ":weapon_parts 1",
        modname .. ":arrow 6",
    },
    industrial = {
        modname .. ":scrap_metal 6",
        modname .. ":machine_parts 2",
        modname .. ":fuel_can 1",
        modname .. ":weapon_parts 2",
    },
}

local function register_loot_crate(zone, description)
    minetest.register_node(modname .. ":loot_crate_" .. zone, {
        description = description,
        tiles = {texture("loot_crate_" .. zone)},
        groups = {oddly_breakable_by_hand = 2},
        drop = "",
        on_rightclick = function(pos, node, clicker)
            if not clicker or not clicker:is_player() then
                return
            end
            local found = {}
            for _, loot in ipairs(GUARANTEED_LOOT[zone] or {}) do
                clicker:get_inventory():add_item("main", loot)
                table.insert(found, loot)
            end
            local bonus = LOOT_TABLES[zone][math.random(#LOOT_TABLES[zone])]
            clicker:get_inventory():add_item("main", bonus)
            table.insert(found, bonus)
            minetest.chat_send_player(clicker:get_player_name(), "Loot found: " .. table.concat(found, ", "))
            if record_player_event then
                record_player_event(clicker, "open_supply", 1)
            end
            minetest.set_node(pos, {name = "air"})
        end,
    })
end

local function register_shelf_supply(kind, description, tint)
    minetest.register_node(modname .. ":shelf_supply_" .. kind, {
        description = description,
        tiles = {"wasteland_plain.png^[colorize:" .. tint .. ":185"},
        groups = {oddly_breakable_by_hand = 2},
        drop = "",
        on_rightclick = function(pos, node, clicker)
            if not clicker or not clicker:is_player() then
                return
            end
            local loot_table = SHELF_SUPPLY_TABLES[kind]
            local loot = loot_table[math.random(#loot_table)]
            clicker:get_inventory():add_item("main", loot)
            minetest.chat_send_player(clicker:get_player_name(), "Shelf supplies collected: " .. loot)
            if record_player_event then
                record_player_event(clicker, "open_supply", 1)
            end
            minetest.set_node(pos, {name = "air"})
        end,
    })
end

register_loot_crate("cbd", "CBD Loot Crate")
register_loot_crate("residential", "Residential Loot Crate")
register_loot_crate("factory", "Factory Loot Crate")

register_shelf_supply("food", "Food Shelf Supplies", "#c89d44")
register_shelf_supply("parts", "Parts Shelf Supplies", "#8fa2a6")
register_shelf_supply("industrial", "Industrial Shelf Supplies", "#9f6b45")

minetest.register_node(modname .. ":scenic_marker", {
    description = "Scenic Marker",
    tiles = {"wasteland_plain.png^[colorize:#d8b36a:190"},
    groups = {},
    drop = "",
    on_rightclick = function(pos, node, clicker)
        if clicker and clicker:is_player() then
            minetest.chat_send_player(clicker:get_player_name(), "Scenic scene: fixed landmark, no loot, no interaction.")
        end
    end,
})

minetest.register_node(modname .. ":shelter_hint", {
    description = "Shelter Hint",
    tiles = {"wasteland_plain.png^[colorize:#9fc48d:190"},
    groups = {},
    drop = "",
    on_rightclick = function(pos, node, clicker)
        if clicker and clicker:is_player() then
            minetest.chat_send_player(clicker:get_player_name(), "Shelter: roof blocks rain. Use the workbench, wear the raincoat, then explore the city. Use /new_start to begin a fresh run.")
        end
    end,
})

minetest.register_node(modname .. ":task_board", {
    description = "Task Notice Board",
    drawtype = "nodebox",
    tiles = {"wasteland_rotted_wood.png^[colorize:#b88d45:110"},
    inventory_image = "wasteland_plain.png^[colorize:#f0d080:200",
    wield_image = "wasteland_plain.png^[colorize:#f0d080:200",
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    light_source = 8,
    groups = {oddly_breakable_by_hand = 2, choppy = 1},
    drop = modname .. ":rotted_wood",
    selection_box = {
        type = "fixed",
        fixed = {-0.58, -0.5, -0.10, 0.58, 0.74, 0.10},
    },
    node_box = {
        type = "fixed",
        fixed = {
            {-0.08, -0.50, -0.05, 0.08, 0.22, 0.05},
            {-0.56, 0.02, -0.08, 0.56, 0.64, 0.08},
            {-0.48, 0.14, -0.10, 0.48, 0.19, 0.10},
            {-0.48, 0.33, -0.10, 0.48, 0.38, 0.10},
        },
    },
    on_rightclick = function(pos, node, clicker)
        if clicker and clicker:is_player() and _wf_show_task_board then
            _wf_show_task_board(clicker)
        end
    end,
})

minetest.register_node(modname .. ":story_sign", {
    description = "Glowing Story Sign",
    drawtype = "nodebox",
    tiles = {"wasteland_rotted_wood.png^[colorize:#d6aa55:80"},
    inventory_image = "wasteland_plain.png^[colorize:#ffd36a:210",
    wield_image = "wasteland_plain.png^[colorize:#ffd36a:210",
    paramtype = "light",
    sunlight_propagates = true,
    walkable = false,
    light_source = 9,
    groups = {},
    drop = "",
    diggable = false,
    selection_box = {
        type = "fixed",
        fixed = {-0.52, -0.5, -0.12, 0.52, 0.64, 0.12},
    },
    node_box = {
        type = "fixed",
        fixed = {
            {-0.07, -0.5, -0.06, 0.07, 0.16, 0.06},
            {-0.48, -0.02, -0.08, 0.48, 0.50, 0.08},
            {-0.52, 0.50, -0.09, 0.52, 0.62, 0.09},
            {-0.40, 0.08, -0.10, 0.40, 0.13, 0.10},
        },
    },
    on_rightclick = function(pos, node, clicker)
        if not clicker or not clicker:is_player() then
            return
        end
        local meta = minetest.get_meta(pos)
        local title = meta:get_string("title")
        local text = meta:get_string("text")
        local next_hint = meta:get_string("next")
        if title == "" then
            title = "Glowing Sign"
        end
        if text == "" then
            text = "The old rescue boards point south through the rainforest."
        end
        if next_hint ~= "" then
            text = text .. "\n" .. next_hint
        end
        minetest.show_formspec(clicker:get_player_name(), modname .. ":story_sign",
            "formspec_version[6]" ..
            "size[8,5.5]" ..
            "bgcolor[#10161fee;true]" ..
            "label[0.5,0.35;" .. minetest.formspec_escape(title) .. "]" ..
            "textarea[0.5,0.85;7,3.8;story;;" .. minetest.formspec_escape(text) .. "]" ..
            "button_exit[5.95,4.75;1.5,0.5;close;Close]")
        if record_player_event then
            record_player_event(clicker, "read_story_sign", 1)
        end
    end,
})

minetest.register_node(modname .. ":scene_terminal", {
    description = "Scene Terminal",
    tiles = {"wasteland_plain.png^[colorize:#4aa3a8:180"},
    groups = {oddly_breakable_by_hand = 2},
    drop = "",
    on_rightclick = function(pos, node, clicker)
        if not clicker or not clicker:is_player() then
            return
        end
        local meta = minetest.get_meta(pos)
        if meta:get_string("used") == "true" then
            if _wf_ensure_story_escape_route then
                _wf_ensure_story_escape_route()
            end
            minetest.chat_send_player(clicker:get_player_name(), "Terminal already used.")
            return
        end
        meta:set_string("used", "true")
        minetest.chat_send_player(clicker:get_player_name(), "Interactive scene triggered: shutter opened, supplies unlocked.")
        fill_area({x = pos.x - 1, y = pos.y, z = pos.z - 4}, {x = pos.x + 1, y = pos.y + 1, z = pos.z - 4}, "air")
        minetest.set_node({x = pos.x, y = pos.y, z = pos.z - 2}, {name = modname .. ":loot_crate_cbd"})
        minetest.set_node({x = pos.x + 1, y = pos.y, z = pos.z - 2}, {name = modname .. ":loot_crate_factory"})
        if record_player_event then
            record_player_event(clicker, "terminal_used", 1)
        end
        if _wf_ensure_story_escape_route then
            _wf_ensure_story_escape_route(true)
        end
    end,
})

local STARTER_CRATE_LOOT = {
    modname .. ":rust_axe 1",
    modname .. ":canned_food 1",
    modname .. ":bandage 1",
    modname .. ":raincoat 1",
    modname .. ":handheld_map 1",
    modname .. ":torch 3",
}

minetest.register_node(modname .. ":starter_crate", {
    description = "Starter Crate",
    tiles = {"wasteland_loot_crate_residential.png^[colorize:#f0d080:80"},
    groups = {oddly_breakable_by_hand = 2},
    drop = "",
    on_rightclick = function(pos, node, clicker)
        if not clicker or not clicker:is_player() then
            return
        end
        local meta = minetest.get_meta(pos)
        if meta:get_string("opened") == "true" then
            minetest.chat_send_player(clicker:get_player_name(), "Starter crate is empty.")
            return
        end
        meta:set_string("opened", "true")
        for _, item in ipairs(STARTER_CRATE_LOOT) do
            clicker:get_inventory():add_item("main", item)
        end
        minetest.chat_send_player(clicker:get_player_name(), "Starter supplies collected.")
        if record_player_event then
            record_player_event(clicker, "open_supply", 1)
        end
    end,
})

local function grant_starter_items(player)
    local inv = player:get_inventory()
    local starter_items = {
        modname .. ":rust_axe 1",
        modname .. ":stone_pick 1",
        modname .. ":field_shovel 1",
        modname .. ":scrap_bow 1",
        modname .. ":arrow 16",
        modname .. ":throwing_spear 1",
        modname .. ":raincoat 1",
        modname .. ":handheld_map 1",
        modname .. ":bandage 2",
        modname .. ":torch 6",
        modname .. ":canned_food 2",
        modname .. ":rotted_wood 8",
        modname .. ":rubble 8",
        modname .. ":scrap_metal 6",
    }
    for _, item in ipairs(starter_items) do
        if not inv:contains_item("main", item) then
            inv:add_item("main", item)
        end
    end
end

local function item_display_name(item_name)
    local item_def = minetest.registered_items[item_name]
    if item_def and item_def.description and item_def.description ~= "" then
        return item_def.description
    end
    return item_name:gsub("^" .. modname .. ":", "")
end

local function inventory_summary(player)
    local inv = player:get_inventory()
    local seen = {}
    local lines = {}
    for _, stack in ipairs(inv:get_list("main") or {}) do
        if not stack:is_empty() then
            local item_name = stack:get_name()
            seen[item_name] = (seen[item_name] or 0) + stack:get_count()
        end
    end
    for item_name, count in pairs(seen) do
        table.insert(lines, item_display_name(item_name) .. " x" .. count)
    end
    table.sort(lines)
    if #lines == 0 then
        return "Empty"
    end
    return table.concat(lines, ",")
end

local function inventory_formspec(player)
    return table.concat({
        "formspec_version[6]",
        "size[17,12]",
        "bgcolor[#10161ddd;true]",
        "label[0.55,0.45;Wasteland Pack]",
        "box[0.45,0.85;9.45,5.55;#1b242dcc]",
        "label[0.65,1.05;Inventory]",
        "list[current_player;main;0.65,1.45;8,4;0]",
        "box[0.45,6.75;9.45,1.55;#1b242dcc]",
        "label[0.65,6.95;Hotbar]",
        "list[current_player;main;0.65,7.3;8,1;0]",
        "box[10.35,0.85;5.95,5.55;#1b242dcc]",
        "label[10.65,1.05;Item Names]",
        "textarea[10.6,1.45;5.25,4.45;items;;" .. minetest.formspec_escape(inventory_summary(player)) .. "]",
        "box[10.35,6.75;5.95,3.75;#1b242dcc]",
        "label[10.65,6.95;Tools]",
        "item_image_button[10.65,7.35;1.1,1.1;" .. modname .. ":rust_axe;tool_axe;]",
        "textarea[11.95,7.28;3.75,0.75;axe_text;;Rust Axe\\nFast on wood]",
        "item_image_button[10.65,8.55;1.1,1.1;" .. modname .. ":stone_pick;tool_pick;]",
        "textarea[11.95,8.48;3.75,0.75;pick_text;;Stone Pickaxe\\nFast on stone/scrap]",
        "item_image_button[10.65,9.75;1.1,1.1;" .. modname .. ":field_shovel;tool_shovel;]",
        "textarea[11.95,9.68;3.75,0.75;shovel_text;;Field Shovel\\nFast on grass/water]",
        "box[0.45,8.85;9.45,1.7;#1b242dcc]",
        "textarea[0.65,9.15;8.75,0.95;help_text;;Counts are shown on item stacks. Names are listed on the right, shown on hover, and shown on the selected-item HUD.]",
        "button_exit[14.35,10.95;1.85,0.6;close;Close]",
        "listring[current_player;main]",
    })
end

local function show_inventory(player)
    minetest.show_formspec(player:get_player_name(), modname .. ":inventory", inventory_formspec(player))
end

local function selected_stack(player)
    local wield_index = player:get_wield_index()
    local inv = player:get_inventory()
    local stack = inv:get_stack("main", wield_index)
    if stack:is_empty() then
        return nil
    end
    return stack
end

local function selected_item_label(player)
    local stack = selected_stack(player)
    if not stack then
        return "Empty"
    end
    return item_display_name(stack:get_name()) .. " x" .. stack:get_count()
end

local function sync_empty_wield_visual(player)
    local meta = player:get_meta()
    local stack = player:get_wielded_item()
    if stack:is_empty() then
        if meta:get_string("wf_empty_wield_synced") ~= "true" then
            player:set_wielded_item(ItemStack(""))
            meta:set_string("wf_empty_wield_synced", "true")
        end
    else
        meta:set_string("wf_empty_wield_synced", "")
    end
end

local function short_item_name(item_name)
    local display_name = item_display_name(item_name)
    display_name = display_name:gsub("Stone Pickaxe", "Pickaxe")
    display_name = display_name:gsub("Field Shovel", "Shovel")
    display_name = display_name:gsub("Rust Axe", "Axe")
    display_name = display_name:gsub("Rotted Wood", "Wood")
    display_name = display_name:gsub("Scrap Metal", "Scrap")
    display_name = display_name:gsub("Scrap Bow", "Bow")
    display_name = display_name:gsub("Throwing Spear", "Spear")
    return display_name
end

local function hotbar_label(player)
    local inv = player:get_inventory()
    local labels = {}
    for index = 1, 8 do
        local stack = inv:get_stack("main", index)
        if stack:is_empty() then
            table.insert(labels, index .. ": Empty")
        else
            table.insert(labels, index .. ": " .. short_item_name(stack:get_name()) .. " x" .. stack:get_count())
        end
    end
    return table.concat(labels, "   ")
end

local function is_quest_text_hud(def)
    if not def or (def.type ~= "text" and def.hud_elem_type ~= "text") then
        return false
    end
    local text = def.text or ""
    return text:find("Task Tree", 1, true) ~= nil
        or text:find("Gather Wood", 1, true) ~= nil
end

local function is_quest_box_hud(def)
    if not def or (def.type ~= "image" and def.hud_elem_type ~= "image") then
        return false
    end
    local texture_name = def.text or ""
    return texture_name:find("quest_box", 1, true) ~= nil
end

local function clear_quest_huds(player, keep_text_id, keep_box_id)
    if not player.hud_get_all then
        return
    end
    for id, def in pairs(player:hud_get_all() or {}) do
        local hud_id = tonumber(id) or id
        local remove_text = hud_id ~= keep_text_id and is_quest_text_hud(def)
        local remove_box = hud_id ~= keep_box_id and is_quest_box_hud(def)
        if remove_text or remove_box then
            player:hud_remove(hud_id)
        end
    end
end

local function reset_custom_hud_meta(player)
    local meta = player:get_meta()
    clear_quest_huds(player)
    for _, key in ipairs({
        "wf_selected_hud",
        "wf_hotbar_name_hud",
        "wf_charge_hud",
        "wf_charge_bar_hud",
        "wf_player_hp_hud",
        "wf_region_hud",
        "wf_coords_hud",
        "wf_quest_hud",
        "wf_quest_box_hud",
    }) do
        meta:set_int(key, 0)
        meta:set_string(key .. "_type", "")
    end
end

local function hud_id_for_type(player, key, expected_type)
    local meta = player:get_meta()
    if meta:get_string(key .. "_type") ~= expected_type then
        meta:set_int(key, 0)
        meta:set_string(key .. "_type", expected_type)
        return 0
    end
    return meta:get_int(key)
end

function _wf_line_count(text)
    return select(2, text:gsub("\n", "")) + 1
end

local function remember_hud_id(player, key, hud_id, hud_type)
    local meta = player:get_meta()
    meta:set_int(key, hud_id)
    meta:set_string(key .. "_type", hud_type)
end

local function update_selected_item_hud(player)
    local meta = player:get_meta()
    local hud_id = hud_id_for_type(player, "wf_selected_hud", "text")
    local current_slot = player:get_wield_index()
    local current_label = selected_item_label(player)
    local previous_slot = meta:get_int("wf_previous_wield_slot")
    local previous_label = meta:get_string("wf_previous_wield_label")
    local changed = previous_slot ~= current_slot or previous_label ~= current_label
    local now = minetest.get_us_time() / 1000000

    if changed then
        meta:set_int("wf_previous_wield_slot", current_slot)
        meta:set_string("wf_previous_wield_label", current_label)
        meta:set_float("wf_selected_hud_until", now + 2.0)
    end

    local text = ""
    if (meta:get_float("wf_selected_hud_until") or 0) > now then
        text = current_slot .. "  " .. current_label
    end

    if hud_id and hud_id > 0 then
        player:hud_change(hud_id, "text", text)
        return
    end
    hud_id = player:hud_add({
        type = "text",
        position = {x = 0.5, y = 0.74},
        offset = {x = 0, y = 0},
        text = text,
        alignment = {x = 0, y = 0},
        scale = {x = 130, y = 130},
        number = 0xE7E2C8,
    })
    remember_hud_id(player, "wf_selected_hud", hud_id, "text")
end

local function update_hotbar_name_hud(player)
    local meta = player:get_meta()
    local hud_id = hud_id_for_type(player, "wf_hotbar_name_hud", "text")
    local text = hotbar_label(player)
    if hud_id and hud_id > 0 then
        player:hud_change(hud_id, "text", text)
        return
    end
    hud_id = player:hud_add({
        type = "text",
        position = {x = 0.5, y = 0.82},
        offset = {x = 0, y = 0},
        text = text,
        alignment = {x = 0, y = 0},
        scale = {x = 75, y = 75},
        number = 0xD7D4C6,
    })
    remember_hud_id(player, "wf_hotbar_name_hud", hud_id, "text")
end

local function charge_bar_texture(charge)
    local index = math.floor(charge / CHARGE_MAX_SECONDS * 10 + 0.5)
    index = math.max(0, math.min(10, index))
    return texture("charge_bar_" .. index)
end

local function update_charge_hud(player)
    local meta = player:get_meta()
    local hud_id = hud_id_for_type(player, "wf_charge_hud", "text")
    local bar_hud_id = hud_id_for_type(player, "wf_charge_bar_hud", "image")
    local weapon = meta:get_string("wf_charging_weapon")
    local text = ""
    local bar_texture = ""
    if weapon ~= "" then
        if weapon == "bow" then
            update_bow_draw_stage(player)
        end
        local now = minetest.get_us_time() / 1000000
        local charge = math.min(CHARGE_MAX_SECONDS, now - meta:get_float("wf_charge_started"))
        text = (weapon == "bow" and "Bow Charge" or "Spear Charge") .. " - " .. charge_tier(charge).label
        bar_texture = charge_bar_texture(charge)
    else
        local stack = player:get_wielded_item()
        local name = stack:get_name()
        if name == bow_stage_item(1) or name == bow_stage_item(2) or name == bow_stage_item(3) then
            restore_normal_bow(player)
        end
        if bar_hud_id and bar_hud_id > 0 then
            player:hud_remove(bar_hud_id)
            remember_hud_id(player, "wf_charge_bar_hud", 0, "image")
        end
    end

    if bar_texture ~= "" then
        if bar_hud_id and bar_hud_id > 0 then
            player:hud_change(bar_hud_id, "text", bar_texture)
        else
            bar_hud_id = player:hud_add({
                type = "image",
                position = {x = 0.5, y = 0.63},
                offset = {x = 0, y = 0},
                text = bar_texture,
                alignment = {x = 0, y = 0},
                scale = {x = 1.35, y = 1.35},
                z_index = 90,
            })
            remember_hud_id(player, "wf_charge_bar_hud", bar_hud_id, "image")
        end
    end

    if hud_id and hud_id > 0 then
        player:hud_change(hud_id, "text", text)
        return
    end
    hud_id = player:hud_add({
        type = "text",
        position = {x = 0.5, y = 0.59},
        offset = {x = 0, y = 0},
        text = text,
        alignment = {x = 0, y = 0},
        scale = {x = 110, y = 110},
        number = 0xB7E1A1,
    })
    remember_hud_id(player, "wf_charge_hud", hud_id, "text")
end

local function update_player_hp_hud(player)
    local hud_id = hud_id_for_type(player, "wf_player_hp_hud", "text")
    if hud_id and hud_id > 0 then
        player:hud_remove(hud_id)
        player:get_meta():set_int("wf_player_hp_hud", 0)
    end
    local wielded_name = player:get_wielded_item():get_name()
    if wielded_name == modname .. ":hand_lamp" then
        player:set_lighting({
            saturation = 1.05,
            exposure = {
                luminance_min = -2.0,
                luminance_max = 0.7,
                exposure_correction = 0.7,
            },
            bloom = {
                intensity = 0.12,
                strength_factor = 1.2,
                radius = 1.4,
            },
        })
    elseif player:get_meta():get_string("wf_hand_lamp_lit") == "true" then
        player:set_lighting(nil)
    end
    player:get_meta():set_string("wf_hand_lamp_lit", wielded_name == modname .. ":hand_lamp" and "true" or "")
end

WF_REGION_POIS = {
    {name = "Starter Shelter", x = WF_STARTER_SHELTER_ORIGIN.x + 4, z = WF_STARTER_SHELTER_ORIGIN.z, radius = 11},
    {name = "West Depot", x = -54, z = 48, radius = 11},
    {name = "Mara's Camp", x = -54, z = 58, radius = 11},
    {name = "Supply Market", x = 56, z = -8, radius = 11},
    {name = "Western Factory", x = -51, z = -21, radius = 18},
    {name = "Eastern Factory", x = 61, z = 40, radius = 18},
    {name = "Scenic Landmark", x = 0, z = -56, radius = 10},
    {name = "Edge Farm", x = -64, z = 0, radius = 10},
    {name = "Eastern Ruins", x = 62, z = -52, radius = 10},
}

function _wf_region_name_at(pos)
    local x = pos.x
    local z = pos.z
    local span = math.max(math.abs(x), math.abs(z))
    for _, area in ipairs(WF_REGION_POIS) do
        if math.max(math.abs(x - area.x), math.abs(z - area.z)) <= area.radius then
            return area.name
        end
    end

    if span <= 24 then
        return "Central District"
    elseif span <= 42 then
        return "Residential District"
    elseif span <= CITY_RADIUS then
        return "City Outskirts"
    elseif span <= 240 then
        return "Outer Rainforest"
    elseif span <= 520 then
        return "Deep Rainforest"
    elseif span <= FOREST_RADIUS then
        return "Cloud Forest"
    elseif span <= ESCAPE_RADIUS then
        return "Forest Edge"
    end
    return "Open Sky"
end

function _wf_update_region_hud(player)
    local meta = player:get_meta()
    local region = _wf_region_name_at(player:get_pos())
    local now = minetest.get_us_time() / 1000000
    local hud_id = hud_id_for_type(player, "wf_region_hud", "text")
    if meta:get_string("wf_current_region") ~= region then
        meta:set_string("wf_current_region", region)
        meta:set_float("wf_region_notice_until", now + 3.2)
    end

    local text = ""
    if meta:get_float("wf_region_notice_until") > now then
        text = region
    end
    if hud_id and hud_id > 0 then
        player:hud_change(hud_id, "text", text)
        return
    end
    hud_id = player:hud_add({
        type = "text",
        position = {x = 0.5, y = 0.13},
        offset = {x = 0, y = 0},
        text = text,
        alignment = {x = 0, y = 0},
        scale = {x = 120, y = 120},
        number = 0xF0E6B8,
        z_index = 60,
    })
    remember_hud_id(player, "wf_region_hud", hud_id, "text")
end

function _wf_round_coord(value)
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

function _wf_update_coords_hud(player)
    local meta = player:get_meta()
    local hud_id = hud_id_for_type(player, "wf_coords_hud", "text")
    if meta:get_string("wf_coords_hud") == "off" then
        if hud_id and hud_id > 0 then
            player:hud_remove(hud_id)
            remember_hud_id(player, "wf_coords_hud", 0, "text")
        end
        return
    end

    local pos = player:get_pos()
    local x = _wf_round_coord(pos.x)
    local y = _wf_round_coord(pos.y)
    local z = _wf_round_coord(pos.z)
    local span = world_span_distance and world_span_distance(x, z) or math.max(math.abs(x), math.abs(z))
    local remaining = math.max(0, ESCAPE_RADIUS - span)
    local text = "X " .. x .. "  Y " .. y .. "  Z " .. z .. "\nEscape " .. remaining .. " to line"
    if hud_id and hud_id > 0 then
        player:hud_change(hud_id, "text", text)
        return
    end
    hud_id = player:hud_add({
        type = "text",
        position = {x = 0.98, y = 0.08},
        offset = {x = -18, y = 0},
        text = text,
        alignment = {x = -1, y = 0},
        scale = {x = 85, y = 85},
        number = 0xDCE9F2,
        z_index = 65,
    })
    remember_hud_id(player, "wf_coords_hud", hud_id, "text")
end

local MAP_POINTS = {
    {label = "Spawn", x = WF_PLAYER_SPAWN_POS.x, z = WF_PLAYER_SPAWN_POS.z, color = "#dfe7a2"},
    {label = "Starter shelter", x = WF_STARTER_SHELTER_ORIGIN.x, z = WF_STARTER_SHELTER_ORIGIN.z, color = "#9fc48d"},
    {label = "Builder", x = -54, z = 58, color = "#b7f2b0"},
    {label = "Market", x = 56, z = -8, color = "#d8b36a"},
    {label = "Depot", x = -58, z = 44, color = "#4aa3a8"},
    {label = "Factory W", x = -56, z = -18, color = "#d7b08a"},
    {label = "Factory E", x = 56, z = 42, color = "#d7b08a"},
    {label = "Bear - West Factory", x = WF_BEAR_SPAWN_POINTS.west_factory.x, z = WF_BEAR_SPAWN_POINTS.west_factory.z, color = "#d98282"},
    {label = "Bear - East Factory", x = WF_BEAR_SPAWN_POINTS.east_factory.x, z = WF_BEAR_SPAWN_POINTS.east_factory.z, color = "#d98282"},
    {label = "Edge bear", x = WF_BEAR_SPAWN_POINTS.edge_ruins.x, z = WF_BEAR_SPAWN_POINTS.edge_ruins.z, color = "#d98282"},
    {label = "Forest edge N", x = 0, z = -FOREST_RADIUS, color = "#6fa86f"},
    {label = "Forest edge S", x = 0, z = FOREST_RADIUS, color = "#6fa86f"},
    {label = "Guide signs S", x = 0, z = 404, color = "#ffd36a"},
    {label = "Last guide sign", x = 0, z = 804, color = "#ffd36a"},
    {label = "Forest edge W", x = -FOREST_RADIUS, z = 0, color = "#6fa86f"},
    {label = "Forest edge E", x = FOREST_RADIUS, z = 0, color = "#6fa86f"},
    {label = "Escape line", x = ESCAPE_RADIUS, z = ESCAPE_RADIUS, color = "#ffffff"},
}

local MAP_RADIUS = ESCAPE_RADIUS

local function map_coord(value)
    return 3.1 + ((value + MAP_RADIUS) / (MAP_RADIUS * 2)) * 5.6
end

minimap_formspec = function(player)
    local pos = player:get_pos()
    local formspec = {
        "formspec_version[6]",
        "size[10,8]",
        "bgcolor[#10161ddd;true]",
        "label[0.45,0.35;City Map]",
        "box[0.65,0.85;2.0,5.9;#1b242dcc]",
        "label[0.85,1.1;Legend]",
        "textarea[0.85,1.45;1.55,4.9;legend;;City core at center\\nForest radius x10 city\\nFollow south guide signs\\nLeave forest/cloud to win]",
        "box[3.1,0.85;5.6,5.6;#202a31dd]",
        "box[5.85,0.85;0.12,5.6;#6d6d6dff]",
        "box[3.1,3.56;5.6,0.12;#6d6d6dff]",
    }
    for _, point in ipairs(MAP_POINTS) do
        table.insert(formspec, "box[" .. map_coord(point.x) .. "," .. map_coord(point.z) .. ";0.16,0.16;" .. point.color .. "ff]")
        table.insert(formspec, "tooltip[" .. map_coord(point.x) .. "," .. map_coord(point.z) .. ";0.16,0.16;" .. minetest.formspec_escape(point.label) .. "]")
    end
    table.insert(formspec, "box[" .. map_coord(math.floor(pos.x + 0.5)) .. "," .. map_coord(math.floor(pos.z + 0.5)) .. ";0.22,0.22;#ffffff]")
    table.insert(formspec, "label[3.1,6.75;You: " .. math.floor(pos.x + 0.5) .. ", " .. math.floor(pos.z + 0.5) .. "]")
    table.insert(formspec, "button_exit[8.0,7.05;1.4,0.55;close;Close]")
    return table.concat(formspec)
end

local QUESTS = {
    main_001_gather_wood = {
        title = "Awakening",
        name = "Gather Wood",
        description = "Collect 12 Rotted Wood from ruins or trees.",
        item = modname .. ":rotted_wood",
        required = 12,
        next = "Use wood and scrap to make tools at the shelter workbench.",
    },
    main_003_open_crates = {
        title = "Supply Run",
        name = "Open Crates",
        description = "Open 2 supply crates or shelf caches.",
        event = "open_supply",
        required = 2,
        next = "Craft a shelter kit or a salvage cart kit.",
    },
    main_004_make_shelter = {
        title = "Supply Run",
        name = "Raise a Shelter",
        description = "Build or place a shelter kit.",
        event = "shelter_built",
        required = 1,
        next = "Track the factory bears and recover an engine core.",
    },
    main_005_defeat_bear = {
        title = "Factory Trail",
        name = "Stop a Bear",
        description = "Defeat 1 bear. Any final hit counts.",
        event = "kill_bear",
        required = 1,
        next = "Craft and deploy a salvage cart to cross the city faster.",
    },
    main_006_deploy_cart = {
        title = "Factory Trail",
        name = "Deploy Cart",
        description = "Place a Salvage Cart Kit.",
        event = "vehicle_deployed",
        required = 1,
        next = "Reach the west depot terminal and unlock its supplies.",
    },
    main_007_terminal = {
        title = "Signal",
        name = "Open the Depot",
        description = "Activate the west interactive depot terminal.",
        event = "terminal_used",
        required = 1,
        next = "The city route is open. Keep gathering, crafting, and exploring.",
    },
}

local QUEST_ORDER = {
    "main_001_gather_wood",
    "main_003_open_crates",
    "main_004_make_shelter",
    "main_005_defeat_bear",
    "main_006_deploy_cart",
    "main_007_terminal",
}

local function item_quest_progress(player, quest)
    local inv = player:get_inventory()
    local count = 0
    for _, stack in ipairs(inv:get_list("main") or {}) do
        if stack:get_name() == quest.item then
            count = count + stack:get_count()
        end
    end
    return math.min(count, quest.required), count >= quest.required
end

local function event_quest_progress(player, quest)
    local count = player:get_meta():get_int("wf_event_" .. quest.event)
    return math.min(count, quest.required), count >= quest.required
end

local function quest_progress(player, quest_id)
    local quest = QUESTS[quest_id]
    if quest.item then
        return item_quest_progress(player, quest)
    end
    if quest.event then
        return event_quest_progress(player, quest)
    end
    return 0, false
end

local function quest_index(quest_id)
    for index, id in ipairs(QUEST_ORDER) do
        if id == quest_id then
            return index
        end
    end
    return 1
end

local function current_quest_id(player)
    local meta = player:get_meta()
    local stored = meta:get_string("wf_current_quest")
    if stored ~= "" and QUESTS[stored] then
        return stored
    end
    for _, id in ipairs(QUEST_ORDER) do
        local _, complete = quest_progress(player, id)
        if meta:get_string("wf_completed_" .. id) ~= "true" and not complete then
            meta:set_string("wf_current_quest", id)
            return id
        end
    end
    meta:set_string("wf_current_quest", QUEST_ORDER[#QUEST_ORDER])
    return QUEST_ORDER[#QUEST_ORDER]
end

advance_quests = function(player)
    if not player or not player:is_player() then
        return
    end
    local meta = player:get_meta()
    local quest_id = current_quest_id(player)
    local _, complete = quest_progress(player, quest_id)
    while complete do
        if meta:get_string("wf_completed_" .. quest_id) ~= "true" then
            meta:set_string("wf_completed_" .. quest_id, "true")
            minetest.chat_send_player(player:get_player_name(), "Quest complete: " .. QUESTS[quest_id].name)
        end
        local next_id = QUEST_ORDER[quest_index(quest_id) + 1]
        if not next_id then
            meta:set_string("wf_current_quest", quest_id)
            meta:set_string("wf_main_story_done", "true")
            return
        end
        quest_id = next_id
        meta:set_string("wf_current_quest", quest_id)
        _, complete = quest_progress(player, quest_id)
    end
end

record_player_event = function(player, key, amount)
    if not player or not player:is_player() then
        return
    end
    amount = amount or 1
    local meta = player:get_meta()
    meta:set_int("wf_event_" .. key, meta:get_int("wf_event_" .. key) + amount)
    advance_quests(player)
end

local function quest_hud_text(player)
    advance_quests(player)
    local quest_id = current_quest_id(player)
    local done = player:get_meta():get_string("wf_main_story_done") == "true"
    if done then
        if player:get_meta():get_string("wf_escape_won") == "true" then
            return "Task Tree\n[x] Escape the cloud forest\nVictory reached"
        end
        return "Task Tree\n[x] Restore the city route\n[>] Follow glowing signs south\n[ ] Leave the cloud forest"
    end
    local lines = {"Task Tree"}
    for _, id in ipairs(QUEST_ORDER) do
        local quest = QUESTS[id]
        local count, complete = quest_progress(player, id)
        local marker = "[ ]"
        local suffix = ""
        if player:get_meta():get_string("wf_completed_" .. id) == "true" or complete then
            marker = "[x]"
            suffix = " done"
        elseif id == quest_id then
            marker = "[>]"
            suffix = " " .. count .. "/" .. quest.required
        else
            suffix = " locked"
        end
        table.insert(lines, marker .. " " .. quest.name .. suffix)
    end
    return table.concat(lines, "\n")
end

_wf_task_board_formspec = function(player)
    advance_quests(player)
    local current_id = current_quest_id(player)
    local text = {"TASK NOTICE BOARD", ""}
    for _, id in ipairs(QUEST_ORDER) do
        local quest = QUESTS[id]
        local count, complete = quest_progress(player, id)
        local state = "LOCKED"
        if player:get_meta():get_string("wf_completed_" .. id) == "true" or complete then
            state = "DONE"
        elseif id == current_id then
            state = "ACTIVE " .. count .. "/" .. quest.required
        end
        table.insert(text, "[" .. state .. "] " .. quest.title .. " - " .. quest.name)
        table.insert(text, quest.description)
        if id == current_id and quest.next then
            table.insert(text, "Hint: " .. quest.next)
        end
        table.insert(text, "")
    end
    if player:get_meta():get_string("wf_main_story_done") == "true" then
        table.insert(text, "[ACTIVE] Escape Route")
        table.insert(text, "Follow the glowing wooden signs south and leave the cloud forest.")
    end
    if player:get_meta():get_string("wf_escape_won") == "true" then
        table.insert(text, "[DONE] Open Sky")
        table.insert(text, "You escaped the cloud forest.")
    end
    table.insert(text, "")
    table.insert(text, "Fresh run: use /new_start to rebuild the starter area and reset your progress.")
    return table.concat({
        "formspec_version[6]",
        "size[9.2,8.4]",
        "bgcolor[#10161ddd;true]",
        "label[0.45,0.35;Task Notice Board]",
        "textarea[0.55,0.85;8.1,6.75;task_text;;" .. minetest.formspec_escape(table.concat(text, "\n")) .. "]",
        "button_exit[7.25,7.65;1.35,0.55;close;Close]",
    })
end

_wf_show_task_board = function(player)
    update_quest_hud(player)
    minetest.show_formspec(player:get_player_name(), modname .. ":task_board", _wf_task_board_formspec(player))
end

local function check_escape_victory(player)
    if not player or not player:is_player() then
        return
    end
    local meta = player:get_meta()
    if meta:get_string("wf_escape_won") == "true" then
        return
    end
    local pos = player:get_pos()
    if world_span_distance(pos.x, pos.z) >= ESCAPE_RADIUS and pos.y >= 1 then
        advance_quests(player)
        if meta:get_string("wf_main_story_done") ~= "true" then
            local now = minetest.get_us_time() / 1000000
            if now - meta:get_float("wf_escape_locked_notice_at") >= 4 then
                meta:set_float("wf_escape_locked_notice_at", now)
                minetest.chat_send_player(player:get_player_name(), "The escape route is not ready. Finish the main tasks before leaving the cloud forest.")
                update_quest_hud(player)
            end
            return
        end
        meta:set_string("wf_escape_won", "true")
        minetest.chat_send_player(player:get_player_name(), "You escaped the cloud forest. You win.")
        update_quest_hud(player)
    end
end

update_quest_hud = function(player)
    local meta = player:get_meta()
    local hud_id = hud_id_for_type(player, "wf_quest_hud", "text")
    local box_hud_id = hud_id_for_type(player, "wf_quest_box_hud", "image")
    clear_quest_huds(player, hud_id, box_hud_id)
    local text = quest_hud_text(player)
    local quest_box_scale = {
        x = 1,
        y = math.max(1.25, 0.86 + _wf_line_count(text) * 0.22),
    }
    if box_hud_id == 0 then
        box_hud_id = player:hud_add({
            type = "image",
            position = {x = 0.02, y = 0.16},
            offset = {x = 0, y = 0},
            text = texture("quest_box"),
            alignment = {x = 1, y = 0},
            scale = quest_box_scale,
            z_index = 40,
        })
        remember_hud_id(player, "wf_quest_box_hud", box_hud_id, "image")
    else
        player:hud_change(box_hud_id, "scale", quest_box_scale)
    end
    if hud_id and hud_id > 0 then
        player:hud_change(hud_id, "text", text)
        return
    end
    hud_id = player:hud_add({
        type = "text",
        position = {x = 0.02, y = 0.16},
        offset = {x = 18, y = 12},
        text = text,
        alignment = {x = 1, y = 0},
        scale = {x = 100, y = 100},
        number = 0xF0E6B8,
        z_index = 41,
    })
    remember_hud_id(player, "wf_quest_hud", hud_id, "text")
end

minetest.register_on_newplayer(function(player)
    player:set_pos(WF_PLAYER_SPAWN_POS)
end)

local ensure_creatures_near_spawn
local ensure_villager_hut_near_spawn

minetest.register_on_joinplayer(function(player)
    set_player_archer_visual(player)
    set_player_bone_animation(player, "idle", 1, true)
    player:set_inventory_formspec(inventory_formspec(player))
    minetest.set_timeofday(0.5)
    reset_custom_hud_meta(player)
    player:get_meta():set_string("wf_current_region", "")
    update_selected_item_hud(player)
    update_hotbar_name_hud(player)
    update_player_hp_hud(player)
    update_charge_hud(player)
    update_quest_hud(player)
    minetest.after(0.5, function()
        if player and player:is_player() then
            if ensure_creatures_near_spawn then
                ensure_creatures_near_spawn()
            end
            if ensure_villager_hut_near_spawn then
                ensure_villager_hut_near_spawn()
            end
            if player:get_meta():get_string("wf_main_story_done") == "true" and _wf_ensure_story_escape_route then
                _wf_ensure_story_escape_route()
            end
            player:set_pos(WF_PLAYER_SPAWN_POS)
            set_player_archer_visual(player)
            update_selected_item_hud(player)
            update_hotbar_name_hud(player)
            update_player_hp_hud(player)
            update_charge_hud(player)
            update_quest_hud(player)
        end
    end)
end)

minetest.register_on_respawnplayer(function(player)
    minetest.after(0, function()
        if player and player:is_player() then
            if ensure_villager_hut_near_spawn then
                ensure_villager_hut_near_spawn()
            end
            player:set_pos(WF_PLAYER_SPAWN_POS)
            update_selected_item_hud(player)
            update_hotbar_name_hud(player)
            update_player_hp_hud(player)
            update_charge_hud(player)
            update_quest_hud(player)
        end
    end)
    return true
end)

minetest.register_on_leaveplayer(function(player)
    remove_bow_bone_overlay(player)
    if player and player.set_detach then
        player:set_detach()
    end
    local name = player and player:get_player_name() or ""
    local pos = player and player:get_pos() or {x = 0, y = 0, z = 0}
    for _, object in ipairs(minetest.get_objects_inside_radius(pos, 24)) do
        local entity = object:get_luaentity()
        if entity and entity.name == modname .. ":salvage_cart" and entity.driver_name == name then
            entity.driver_name = nil
            object:set_nametag_attributes({text = "Salvage Cart", color = "#a7d8ff"})
        end
    end
end)

hud_timer = 0
daylight_timer = 0
city_hazard_timer = 0
escape_path_timer = 0
update_glow_fungus_growth = nil
WF_CITY_HAZARD_INTERVAL = 1.0
WF_INTERIOR_DEBRIS_CHANCE = 0.03
WF_FLOOR_CRUMBLE_CHANCE = 0.01

local function update_charge_release(player)
    local meta = player:get_meta()
    local weapon = meta:get_string("wf_charging_weapon")
    local controls = player:get_player_control()
    local dig_down = controls.dig == true
    local place_down = controls.place == true
    local any_charge_button_down = dig_down or place_down
    local was_down = meta:get_string("wf_charge_dig_was_down") == "true"

    if weapon == "" and any_charge_button_down then
        local stack = player:get_wielded_item()
        local weapon_type = stack_charge_weapon_type(stack)
        if weapon_type then
            handle_charge_weapon(stack, player, weapon_type, dig_down and "dig" or "place")
            update_charge_hud(player)
            update_bow_bone_animation(player)
            return
        end
    end

    local charge_button = meta:get_string("wf_charge_button")
    local charge_button_down = charge_button == "place" and place_down or dig_down
    if weapon ~= "" and was_down and not charge_button_down then
        meta:set_string("wf_charge_dig_was_down", "")
        release_charged_weapon(player)
        update_charge_hud(player)
        update_bow_bone_animation(player)
        return
    end

    meta:set_string("wf_charge_dig_was_down", charge_button_down and "true" or "")
    if weapon == "bow" then
        update_bow_draw_stage(player)
    end
    if weapon ~= "" then
        update_charge_hud(player)
    end
    update_bow_bone_animation(player)
end

local function cover_y_above(pos, max_distance)
    local x = math.floor(pos.x + 0.5)
    local z = math.floor(pos.z + 0.5)
    for y = math.floor(pos.y + 2), math.floor(pos.y + max_distance) do
        local node = minetest.get_node_or_nil({x = x, y = y, z = z})
        local def = node and minetest.registered_nodes[node.name]
        if def and def.walkable then
            return y
        end
    end
    return nil
end

local function player_under_cover(player)
    return cover_y_above(player:get_pos(), 24) ~= nil
end

local function update_city_hazards(player)
    local pos = player:get_pos()
    local meta = player:get_meta()
    local cover_y = cover_y_above(pos, 24)
    local now = minetest.get_us_time() / 1000000

    if not cover_y then
        minetest.add_particlespawner({
            amount = 24,
            time = 1,
            minpos = {x = pos.x - 7, y = pos.y + 7, z = pos.z - 7},
            maxpos = {x = pos.x + 7, y = pos.y + 10, z = pos.z + 7},
            minvel = {x = -0.5, y = -11, z = -0.5},
            maxvel = {x = 0.5, y = -13, z = 0.5},
            minexptime = 0.6,
            maxexptime = 1.0,
            minsize = 0.8,
            maxsize = 1.4,
            texture = texture("dirty_water"),
        })
        if meta:get_string("wf_wearing_raincoat") == "true" then
            meta:set_float("wf_rain_damage_at", now)
        elseif now - meta:get_float("wf_rain_damage_at") >= 3 then
            damage_object(player, 1)
            meta:set_float("wf_rain_damage_at", now)
        end
        return
    end

    if math.random() < WF_INTERIOR_DEBRIS_CHANCE then
        local debris_pos = {x = pos.x, y = math.max(pos.y + 2.5, cover_y - 1), z = pos.z}
        minetest.add_entity(debris_pos, modname .. ":falling_brick_debris")
    end

    if math.random() < WF_FLOOR_CRUMBLE_CHANCE then
        local below = {x = math.floor(pos.x + 0.5), y = math.floor(pos.y - 0.1), z = math.floor(pos.z + 0.5)}
        local node = minetest.get_node_or_nil(below)
        if node
            and node.name ~= "air"
            and node.name ~= "ignore"
            and node.name ~= modname .. ":bedrock"
        then
            minetest.set_node(below, {name = "air"})
        end
    end
end

minetest.register_globalstep(function(dtime)
    hud_timer = hud_timer + dtime
    daylight_timer = daylight_timer + dtime
    city_hazard_timer = city_hazard_timer + dtime
    escape_path_timer = escape_path_timer + dtime
    for _, player in ipairs(minetest.get_connected_players()) do
        update_charge_release(player)
    end
    if daylight_timer >= 5 then
        daylight_timer = 0
        minetest.set_timeofday(0.5)
    end
    if hud_timer < 0.25 then
        return
    end
    hud_timer = 0
    for _, player in ipairs(minetest.get_connected_players()) do
        if city_hazard_timer >= WF_CITY_HAZARD_INTERVAL then
            update_city_hazards(player)
            if update_glow_fungus_growth then
                update_glow_fungus_growth(player)
            end
            if _wf_update_loose_lamp_spawns then
                _wf_update_loose_lamp_spawns(player)
            end
        end
        update_selected_item_hud(player)
        sync_empty_wield_visual(player)
        update_hotbar_name_hud(player)
        update_player_hp_hud(player)
        _wf_update_region_hud(player)
        _wf_update_coords_hud(player)
        advance_quests(player)
        update_charge_hud(player)
        update_bow_bone_animation(player)
        update_quest_hud(player)
        check_escape_victory(player)
    end
    if city_hazard_timer >= WF_CITY_HAZARD_INTERVAL then
        city_hazard_timer = 0
    end
    if escape_path_timer >= 1 then
        escape_path_timer = 0
    end
end)

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname == modname .. ":inventory" then
        player:set_inventory_formspec(inventory_formspec(player))
        return
    end
    if formname == modname .. ":workbench" then
        for recipe_id in pairs(WORKBENCH_RECIPES) do
            local field_name = "craft_" .. recipe_id
            if fields[field_name] then
                local ok, message = craft_workbench_recipe(player, recipe_id)
                minetest.chat_send_player(player:get_player_name(), message)
                if ok then
                    show_workbench(player)
                end
                return
            end
        end
    end
end)

minetest.register_chatcommand("bag", {
    description = "Open the Wasteland Pack inventory.",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            show_inventory(player)
        end
        return true
    end,
})

minetest.register_chatcommand("i", {
    description = "Open the Wasteland Pack inventory.",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            show_inventory(player)
        end
        return true
    end,
})

minetest.register_chatcommand("starter", {
    description = "Restore starter tools and blocks.",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            grant_starter_items(player)
            minetest.chat_send_player(name, "Starter items restored.")
        end
        return true
    end,
})

minetest.register_chatcommand("arrows", {
    description = "Add arrows to your inventory.",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            player:get_inventory():add_item("main", modname .. ":arrow 64")
            minetest.chat_send_player(name, "Added 64 arrows.")
        end
        return true
    end,
})

minetest.register_chatcommand("wf_tools", {
    description = "Show the mining difficulty and tool durability rules.",
    func = function(name)
        minetest.chat_send_player(name, "Mining rules: every block has difficulty. Harder blocks take longer and consume more durability.")
        minetest.chat_send_player(name, "Best matches: pickaxe -> asphalt/rubble/scrap, axe -> wood, shovel -> grass/water.")
        minetest.chat_send_player(name, "Wrong tools still work, but mine about 75% slower and lose durability much faster.")
        return true
    end,
})

minetest.register_chatcommand("wf_damage", {
    description = "Show creature HP and weapon damage rules.",
    func = function(name)
        minetest.chat_send_player(name, "Creature HP: Rabbit 6, Dog 12, Bear 30.")
        minetest.chat_send_player(name, "Melee damage: hand 1, axe 4, pickaxe 3, shovel 2, bow 1, spear 5.")
        minetest.chat_send_player(name, "Projectile damage: bow light/mid/full 3/4/6, spear light/mid/full 5/7/9.")
        minetest.chat_send_player(name, "World damage: rain 1 per tick, bear attack 4, falling brick debris 3.")
        minetest.chat_send_player(name, "Drops: rabbits/dogs give meat and hide; bears give meat, pelt, and sometimes factory parts.")
        return true
    end,
})

minetest.register_chatcommand("wf_arrow_axis", {
    description = "Set arrow axis test mode 0-5.",
    func = function(name, param)
        local mode = tonumber(param) or 0
        mode = math.max(0, math.min(5, math.floor(mode)))
        storage:set_int("wf_arrow_axis_mode", mode)
        minetest.chat_send_player(name, "Arrow axis mode set to " .. mode)
        return true
    end,
})

minetest.register_chatcommand("wf_scenegraph", {
    description = "Show the generated world scenegraph summary.",
    func = function(name)
        minetest.chat_send_player(name, "Scenegraph: " .. WORLD_SCENEGRAPH.id)
        for _, child in ipairs(WORLD_SCENEGRAPH.children or {}) do
            minetest.chat_send_player(name, "- " .. child.id .. " [" .. child.type .. "]")
            if child.id == "sample_city" then
                for _, zone in ipairs(child.children or {}) do
                    minetest.chat_send_player(name, "  zone: " .. zone.id .. " radius=" .. zone.radius)
                end
            end
        end
        return true
    end,
})

minetest.register_chatcommand("quest", {
    description = "Show current RPG quest progress.",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            update_quest_hud(player)
            minetest.chat_send_player(name, quest_hud_text(player))
        end
        return true
    end,
})

minetest.register_chatcommand("coords", {
    description = "Toggle the Wasteland coordinate HUD.",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found."
        end
        local meta = player:get_meta()
        if meta:get_string("wf_coords_hud") == "off" then
            meta:set_string("wf_coords_hud", "on")
            _wf_update_coords_hud(player)
            return true, "Coordinates shown."
        end
        meta:set_string("wf_coords_hud", "off")
        _wf_update_coords_hud(player)
        return true, "Coordinates hidden."
    end,
})

minetest.register_chatcommand("map", {
    description = "Open the Wasteland city map.",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            minetest.show_formspec(name, modname .. ":map", minimap_formspec(player))
        end
        return true
    end,
})

minetest.register_chatcommand("quests", {
    description = "Show current RPG quest progress.",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            update_quest_hud(player)
            minetest.chat_send_player(name, quest_hud_text(player))
        end
        return true
    end,
})

local function make_box_entity(name, description, textures, size, behavior)
    minetest.register_entity(modname .. ":" .. name, {
        initial_properties = {
            physical = true,
            collide_with_objects = true,
            collisionbox = {-size.x / 2, 0, -size.z / 2, size.x / 2, size.y, size.z / 2},
            visual = "cube",
            visual_size = size,
            textures = textures,
            static_save = true,
        },
        parts = {},
        timer = 0,
        target = nil,
        on_activate = function(self)
            self.object:set_armor_groups({immortal = 1})
            self.object:set_nametag_attributes({text = description, color = "#eeeeee"})
        end,
        on_step = behavior,
    })
end

local function flat_dir(from_pos, to_pos)
    local dir = vector.subtract(to_pos, from_pos)
    dir.y = 0
    if vector.length(dir) < 0.001 then
        return nil
    end
    return vector.normalize(dir)
end

local function move_entity(self, dir, speed)
    local velocity = vector.multiply(dir, speed)
    velocity.y = self.object:get_velocity().y
    self.object:set_velocity(velocity)
    self.object:set_yaw(math.atan2(dir.z, dir.x) - math.pi / 2)
end

local function nearest_entity(pos, name, radius)
    local search_pos = {
        x = pos.x,
        y = pos.y or 3,
        z = pos.z,
    }
    local nearest = nil
    local nearest_distance = radius
    for _, object in ipairs(minetest.get_objects_inside_radius(search_pos, radius)) do
        local entity = object:get_luaentity()
        if entity and entity.name == modname .. ":" .. name then
            local dist = vector.distance(search_pos, object:get_pos())
            if dist < nearest_distance then
                nearest = object
                nearest_distance = dist
            end
        end
    end
    return nearest
end

local ANIMAL_ANIMATIONS = {
    idle = {range = {x = 1, y = 20}, speed = 8},
    walk = {range = {x = 21, y = 40}, speed = 18},
}

local function is_walkable_node(pos)
    local node = minetest.get_node_or_nil(pos)
    if not node then
        return false
    end
    local def = minetest.registered_nodes[node.name]
    return def and def.walkable
end

local function find_ground_y(pos)
    local x = math.floor(pos.x + 0.5)
    local z = math.floor(pos.z + 0.5)
    local start_y = math.floor(pos.y + 2)
    for y = start_y, start_y - 10, -1 do
        if is_walkable_node({x = x, y = y, z = z}) then
            return y + 1
        end
    end
    return nil
end

local function animal_can_stand(pos, height)
    local visual_sink = pos.visual_sink or 0
    local x = math.floor(pos.x + 0.5)
    local z = math.floor(pos.z + 0.5)
    local foot_y = pos.y + visual_sink
    local ground_y = math.floor(foot_y - 0.05)
    if not is_walkable_node({x = x, y = ground_y, z = z}) then
        return false
    end
    local foot_node = minetest.get_node_or_nil({x = x, y = math.floor(foot_y + 0.15), z = z})
    local head_node = minetest.get_node_or_nil({x = x, y = math.floor(foot_y + height - 0.05), z = z})
    local foot_def = foot_node and minetest.registered_nodes[foot_node.name]
    local head_def = head_node and minetest.registered_nodes[head_node.name]
    return (not foot_def or not foot_def.walkable) and (not head_def or not head_def.walkable)
end

local function find_animal_open_position(pos, height)
    local offsets = {
        {x = 0, z = 0},
        {x = 2, z = 0},
        {x = -2, z = 0},
        {x = 0, z = 2},
        {x = 0, z = -2},
        {x = 3, z = 3},
        {x = -3, z = 3},
        {x = 3, z = -3},
        {x = -3, z = -3},
        {x = 5, z = 0},
        {x = -5, z = 0},
    }
    for _, offset in ipairs(offsets) do
        local candidate = {
            x = pos.x + offset.x,
            y = pos.y,
            z = pos.z + offset.z,
            visual_sink = pos.visual_sink or 0,
        }
        local ground_y = find_ground_y(candidate)
        if ground_y then
            candidate.y = ground_y - candidate.visual_sink
            if animal_can_stand(candidate, height) then
                return candidate
            end
        end
    end
    return nil
end

local function snap_animal_to_ground(self)
    local pos = self.object:get_pos()
    local ground_y = find_ground_y(pos)
    local visual_sink = self.visual_sink or 0
    if ground_y then
        local target_y = ground_y - visual_sink
        if math.abs(pos.y - target_y) > 0.02 then
            pos.y = target_y
            self.object:set_pos(pos)
        end
        local velocity = self.object:get_velocity()
        if math.abs(velocity.y) > 0.001 then
            self.object:set_velocity({x = velocity.x, y = 0, z = velocity.z})
        end
    end
    return self.object:get_pos()
end

local function set_animal_animation(self, animation)
    if self.current_animation == animation then
        return
    end
    local def = ANIMAL_ANIMATIONS[animation]
    self.object:set_animation(def.range, def.speed, 0, true)
    self.current_animation = animation
end

local function random_flat_direction()
    local angle = math.random() * math.pi * 2
    return {x = math.cos(angle), y = 0, z = math.sin(angle)}
end

local function set_animal_state(self, state, duration, dir)
    self.state = state
    self.state_timer = duration
    self.walk_dir = dir
    set_animal_animation(self, state == "idle" and "idle" or "walk")
end

local function stop_animal(self)
    self.object:set_velocity({x = 0, y = 0, z = 0})
    set_animal_state(self, "idle", 1.0 + math.random() * 2.0, nil)
end

local function move_ground_animal(self, dir, speed, height, dtime)
    local pos = self.object:get_pos()
    local next_pos = vector.add(pos, vector.multiply(dir, speed * math.max(dtime, 0.05)))
    local travel_dir = dir
    local ground_y = find_ground_y(next_pos)
    if not ground_y then
        stop_animal(self)
        return false
    end
    next_pos.visual_sink = self.visual_sink or 0
    next_pos.y = ground_y - next_pos.visual_sink
    if not animal_can_stand(next_pos, height) then
        local open_pos = find_animal_open_position(next_pos, height)
        if not open_pos then
            stop_animal(self)
            return false
        end
        travel_dir = flat_dir(pos, open_pos) or dir
        self.object:set_pos(open_pos)
        next_pos = open_pos
    end
    self.object:set_yaw(math.atan2(travel_dir.z, travel_dir.x) + math.pi / 2)
    self.object:set_velocity({x = travel_dir.x * speed, y = 0, z = travel_dir.z * speed})
    return true
end

local function nearest_player(pos, radius)
    local nearest = nil
    local nearest_distance = radius
    for _, player in ipairs(minetest.get_connected_players()) do
        local dist = vector.distance(pos, player:get_pos())
        if dist < nearest_distance then
            nearest = player
            nearest_distance = dist
        end
    end
    return nearest
end

local function detach_vehicle_driver(self)
    if not self.driver_name then
        return
    end
    local player = minetest.get_player_by_name(self.driver_name)
    if player then
        player:set_detach()
        player:set_eye_offset({x = 0, y = 0, z = 0}, {x = 0, y = 0, z = 0})
        minetest.chat_send_player(self.driver_name, "You step off the salvage cart.")
    end
    self.driver_name = nil
    self.object:set_nametag_attributes({text = "Salvage Cart", color = "#a7d8ff"})
end

place_vehicle_entity = function(user, pointed_thing)
    local base_pos
    if pointed_thing and pointed_thing.type == "node" then
        base_pos = pointed_thing.above
    else
        local look = user:get_look_dir()
        base_pos = vector.add(user:get_pos(), vector.multiply(look, 2.4))
    end

    local ground_y = find_ground_y({x = base_pos.x, y = base_pos.y + 3, z = base_pos.z})
    if not ground_y then
        return false
    end
    local pos = {x = math.floor(base_pos.x + 0.5), y = ground_y + 0.15, z = math.floor(base_pos.z + 0.5)}
    for y = math.floor(ground_y), math.floor(ground_y + 2) do
        local node = minetest.get_node_or_nil({x = pos.x, y = y, z = pos.z})
        local def = node and minetest.registered_nodes[node.name]
        if y > ground_y and def and def.walkable then
            return false
        end
    end
    local object = minetest.add_entity(pos, modname .. ":salvage_cart")
    if not object then
        return false
    end
    local look = user:get_look_dir()
    local yaw = math.atan2(look.x, look.z)
    object:set_yaw(yaw)
    if record_player_event then
        record_player_event(user, "vehicle_deployed", 1)
    end
    minetest.chat_send_player(user:get_player_name(), "Salvage cart deployed. Right-click to drive.")
    return true
end

minetest.register_entity(modname .. ":salvage_cart", {
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        collisionbox = {-0.8, 0, -1.05, 0.8, 0.95, 1.05},
        visual = "cube",
        visual_size = {x = 1.55, y = 0.65, z = 2.1},
        textures = {
            texture("scrap_metal"),
            texture("scrap_metal"),
            texture("cracked_asphalt"),
            texture("cracked_asphalt"),
            texture("scrap_metal"),
            texture("scrap_metal"),
        },
        static_save = true,
    },
    driver_name = nil,
    speed = 0,
    on_activate = function(self)
        self.driver_name = nil
        self.speed = 0
        self.object:set_armor_groups({immortal = 1})
        self.object:set_acceleration({x = 0, y = 0, z = 0})
        self.object:set_nametag_attributes({text = "Salvage Cart", color = "#a7d8ff"})
    end,
    on_rightclick = function(self, clicker)
        if not clicker or not clicker:is_player() then
            return
        end
        local name = clicker:get_player_name()
        if self.driver_name == name then
            detach_vehicle_driver(self)
            return
        end
        if self.driver_name then
            minetest.chat_send_player(name, "Someone is already driving this cart.")
            return
        end
        self.driver_name = name
        clicker:set_attach(self.object, "", {x = 0, y = 6, z = 2}, {x = 0, y = 0, z = 0})
        clicker:set_eye_offset({x = 0, y = 2, z = 0}, {x = 0, y = 0, z = 0})
        self.object:set_nametag_attributes({text = "Salvage Cart - " .. name, color = "#a7d8ff"})
        minetest.chat_send_player(name, "Driving salvage cart. W/S move, A/D turn, sneak to dismount.")
    end,
    on_punch = function(self, puncher)
        if self.driver_name then
            return
        end
        if puncher and puncher:is_player() then
            puncher:get_inventory():add_item("main", modname .. ":salvage_cart_kit")
        else
            minetest.add_item(self.object:get_pos(), modname .. ":salvage_cart_kit")
        end
        self.object:remove()
    end,
    on_step = function(self, dtime)
        local pos = self.object:get_pos()
        local ground_y = find_ground_y({x = pos.x, y = pos.y + 2, z = pos.z})
        if ground_y then
            pos.y = ground_y + 0.15
            self.object:set_pos(pos)
        end

        local player = self.driver_name and minetest.get_player_by_name(self.driver_name) or nil
        if not player then
            self.driver_name = nil
            self.speed = (self.speed or 0) * 0.85
        else
            local controls = player:get_player_control()
            if controls.sneak then
                detach_vehicle_driver(self)
                self.speed = 0
            else
                local yaw = self.object:get_yaw()
                if controls.left then
                    yaw = yaw + dtime * 1.8
                end
                if controls.right then
                    yaw = yaw - dtime * 1.8
                end
                self.object:set_yaw(yaw)
                local target_speed = 0
                if controls.up then
                    target_speed = 5.4
                elseif controls.down then
                    target_speed = -2.1
                end
                self.speed = (self.speed or 0) + (target_speed - (self.speed or 0)) * math.min(1, dtime * 4)
            end
        end

        local yaw = self.object:get_yaw()
        local dir = {x = math.sin(yaw), y = 0, z = math.cos(yaw)}
        self.object:set_velocity({x = dir.x * (self.speed or 0), y = 0, z = dir.z * (self.speed or 0)})
    end,
})

local function animal_collisionbox(def)
    local sink = def.visual_sink or 0
    return {-def.size.x / 2, sink, -def.size.z / 2, def.size.x / 2, def.size.y + sink, def.size.z / 2}
end

local function make_ground_animal(name, description, def)
    minetest.register_entity(modname .. ":" .. name, {
        initial_properties = {
            physical = true,
            collide_with_objects = true,
            collisionbox = animal_collisionbox(def),
            visual = "mesh",
            mesh = def.mesh,
            visual_size = def.visual_size or {x = 1, y = 1, z = 1},
            textures = {def.texture},
            static_save = true,
        },
        state = "idle",
        state_timer = 0,
        walk_dir = nil,
        flee_player = nil,
        flee_timer = 0,
        drops = def.drops,
        kill_event = name,
        current_animation = nil,
        on_activate = function(self)
            self.dead = false
            self.death_handled = false
            self.properties_refreshed = true
            self.visual_sink = def.visual_sink or 0
            self.object:set_properties({
                collisionbox = animal_collisionbox(def),
                visual = "mesh",
                mesh = def.mesh,
                visual_size = def.visual_size or {x = 1, y = 1, z = 1},
                textures = {def.texture},
            })
            self.object:set_acceleration({x = 0, y = 0, z = 0})
            setup_entity_health(self, description, def.hp or 10, "#eeeeee", {
                hide_healthbar = def.hide_healthbar,
            })
            snap_animal_to_ground(self)
            stop_animal(self)
        end,
        on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
            if self.dead then
                return
            end
            local source = puncher
            if puncher and puncher:is_player() then
                source = puncher:get_player_name()
            end
            damage_object(self.object, damage_from_wielded_tool(puncher, damage), source)
            if not self.object or not self.object:get_pos() or self.object:get_hp() <= 0 then
                return
            end
            if puncher and puncher:is_player() then
                self.flee_player = puncher:get_player_name()
                self.flee_timer = 4.0
                local dir = flat_dir(puncher:get_pos(), self.object:get_pos()) or random_flat_direction()
                set_animal_state(self, "flee", self.flee_timer, dir)
            end
        end,
        on_step = function(self, dtime)
            if self.dead or not self.object:get_pos() then
                return
            end
            if not self.properties_refreshed then
                self.properties_refreshed = true
                self.visual_sink = def.visual_sink or 0
                self.object:set_properties({
                    collisionbox = animal_collisionbox(def),
                    visual = "mesh",
                    mesh = def.mesh,
                    visual_size = def.visual_size or {x = 1, y = 1, z = 1},
                    textures = {def.texture},
                })
            end
            update_entity_healthbar(self)
            local pos = snap_animal_to_ground(self)
            self.state_timer = math.max(0, (self.state_timer or 0) - dtime)

            if self.state == "flee" then
                self.flee_timer = math.max(0, (self.flee_timer or 0) - dtime)
                local player = self.flee_player and minetest.get_player_by_name(self.flee_player) or nearest_player(pos, 8)
                local dir = player and flat_dir(player:get_pos(), pos) or self.walk_dir
                if self.flee_timer <= 0 or not dir then
                    stop_animal(self)
                    return
                end
                self.walk_dir = dir
                move_ground_animal(self, dir, def.flee_speed, def.size.y, dtime)
                return
            end

            if self.state_timer <= 0 then
                if math.random() < 0.55 then
                    set_animal_state(self, "walk", 1.2 + math.random() * 2.2, random_flat_direction())
                else
                    stop_animal(self)
                end
            end

            if self.state == "walk" and self.walk_dir then
                move_ground_animal(self, self.walk_dir, def.walk_speed, def.size.y, dtime)
            else
                local yaw = self.object:get_yaw()
                self.object:set_yaw(yaw + math.sin(minetest.get_us_time() / 350000) * 0.003)
                self.object:set_velocity({x = 0, y = 0, z = 0})
                set_animal_animation(self, "idle")
            end
        end,
    })
end

local function make_hostile_ground_animal(name, description, def)
    minetest.register_entity(modname .. ":" .. name, {
        initial_properties = {
            physical = true,
            collide_with_objects = true,
            collisionbox = def.collisionbox or {-def.size.x / 2, 0, -def.size.z / 2, def.size.x / 2, def.size.y, def.size.z / 2},
            stepheight = def.stepheight or 0.6,
            visual = "mesh",
            mesh = def.mesh,
            visual_size = def.visual_size or {x = 1, y = 1, z = 1},
            textures = {def.texture},
            static_save = true,
        },
        attack_cooldown = 0,
        wander_timer = 0,
        wander_dir = nil,
        drops = def.drops,
        kill_event = name,
        current_animation = nil,
        on_activate = function(self)
            self.dead = false
            self.death_handled = false
            self.wander_timer = 0.5 + math.random() * 1.5
            self.wander_dir = random_flat_direction()
            self.object:set_properties({
                collisionbox = def.collisionbox or {-def.size.x / 2, 0, -def.size.z / 2, def.size.x / 2, def.size.y, def.size.z / 2},
                stepheight = def.stepheight or 0.6,
                visual = "mesh",
                mesh = def.mesh,
                visual_size = def.visual_size or {x = 1, y = 1, z = 1},
                textures = {def.texture},
            })
            self.object:set_acceleration({x = 0, y = 0, z = 0})
            setup_entity_health(self, description, def.hp or 20, "#f5c07a", {
                bgcolor = "#27150ed8",
                distance = def.healthbar_distance or 8,
            })
            local open_pos = find_animal_open_position(self.object:get_pos(), def.size.y)
            if open_pos then
                self.object:set_pos(open_pos)
            end
            snap_animal_to_ground(self)
            set_animal_animation(self, "idle")
        end,
        on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir, damage)
            if self.dead then
                return
            end
            local source = puncher
            if puncher and puncher:is_player() then
                source = puncher:get_player_name()
            end
            damage_object(self.object, damage_from_wielded_tool(puncher, damage), source)
        end,
        on_step = function(self, dtime)
            if self.dead or not self.object:get_pos() then
                return
            end
            update_entity_healthbar(self)
            local pos = snap_animal_to_ground(self)
            self.attack_cooldown = math.max(0, (self.attack_cooldown or 0) - dtime)
            self.wander_timer = math.max(0, (self.wander_timer or 0) - dtime)
            local player = nearest_player(pos, def.detect_radius or 14)
            if player then
                local player_pos = player:get_pos()
                local distance = vector.distance(pos, player_pos)
                local dir = flat_dir(pos, player_pos)
                if distance <= (def.attack_radius or 1.6) then
                    self.object:set_velocity({x = 0, y = 0, z = 0})
                    set_animal_animation(self, "idle")
                    if self.attack_cooldown <= 0 then
                        damage_object(player, def.damage or 3)
                        self.attack_cooldown = def.attack_interval or 1.2
                    end
                elseif dir then
                    set_animal_animation(self, "walk")
                    if not move_ground_animal(self, dir, def.walk_speed, def.size.y, dtime) then
                        local sidestep = {x = -dir.z, y = 0, z = dir.x}
                        local reverse_side = {x = dir.z, y = 0, z = -dir.x}
                        if math.random() < 0.5 then
                            sidestep, reverse_side = reverse_side, sidestep
                        end
                        if not move_ground_animal(self, sidestep, def.walk_speed * 0.8, def.size.y, dtime) then
                            move_ground_animal(self, reverse_side, def.walk_speed * 0.8, def.size.y, dtime)
                        end
                    end
                end
                return
            end
            if self.wander_timer <= 0 or not self.wander_dir then
                self.wander_timer = 1.2 + math.random() * 2.4
                self.wander_dir = random_flat_direction()
            end
            set_animal_animation(self, "walk")
            if not move_ground_animal(self, self.wander_dir, def.walk_speed * 0.45, def.size.y, dtime) then
                self.wander_timer = 0
                self.wander_dir = nil
            end
        end,
    })
end

make_ground_animal("rabbit", "Rabbit", {
    mesh = "wasteland_rabbit.b3d",
    texture = "wasteland_rabbit.png",
    visual_size = {x = 1.3, y = 1.3, z = 1.3},
    size = {x = 0.48, y = 0.78, z = 0.92},
    visual_sink = 0.18,
    walk_speed = 1.25,
    flee_speed = 3.2,
    hp = 6,
    hide_healthbar = true,
    drops = {
        {item = modname .. ":raw_meat", min = 1, max = 2, chance = 0.9},
        {item = modname .. ":hide", count = 1, chance = 0.45},
    },
})

make_ground_animal("dog", "Dog", {
    mesh = "wasteland_dog.b3d",
    texture = "wasteland_dog.png",
    visual_size = {x = 2, y = 2, z = 2},
    size = {x = 0.72, y = 0.96, z = 1.45},
    visual_sink = 0.55,
    walk_speed = 1.45,
    flee_speed = 3.0,
    hp = 12,
    hide_healthbar = true,
    drops = {
        {item = modname .. ":raw_meat", min = 1, max = 2, chance = 0.75},
        {item = modname .. ":hide", min = 1, max = 2, chance = 0.8},
    },
})

make_hostile_ground_animal("bear", "Bear", {
    mesh = "wasteland_bear.b3d",
    texture = "wasteland_bear.png",
    visual_size = {x = 2.2, y = 2.2, z = 2.2},
    size = {x = 2.1, y = 1.7, z = 2.8},
    collisionbox = {-1.15, 0, -1.35, 1.15, 2.05, 1.35},
    stepheight = 1.1,
    walk_speed = 2.6,
    detect_radius = 24,
    attack_radius = 2.4,
    attack_interval = 1.1,
    damage = 4,
    hp = 30,
    drops = {
        {item = modname .. ":raw_meat", min = 3, max = 5, chance = 1.0},
        {item = modname .. ":bear_pelt", count = 1, chance = 1.0},
        {item = modname .. ":machine_parts", min = 1, max = 2, chance = 0.45},
        {item = modname .. ":fuel_can", count = 1, chance = 0.35},
    },
})

local function is_tree_trunk_base(x, y, z)
    local ground_name = minetest.get_node({x = x, y = y - 1, z = z}).name
    if ground_name ~= modname .. ":dry_grass" and ground_name ~= modname .. ":bedrock" then
        return false
    end
    if minetest.get_node({x = x, y = y, z = z}).name ~= modname .. ":rotted_wood"
        or minetest.get_node({x = x, y = y + 1, z = z}).name ~= modname .. ":rotted_wood" then
        return false
    end
    for lx = x - 3, x + 3 do
        for ly = y + 2, y + 8 do
            for lz = z - 3, z + 3 do
                if minetest.get_node({x = lx, y = ly, z = lz}).name == modname .. ":dead_leaves" then
                    return true
                end
            end
        end
    end
    return false
end

local function find_nearest_tree_trunk(pos, radius)
    local center = {
        x = math.floor(pos.x + 0.5),
        y = math.floor(pos.y + 0.5),
        z = math.floor(pos.z + 0.5),
    }
    local nearest = nil
    local nearest_distance = radius
    for x = center.x - radius, center.x + radius do
        for z = center.z - radius, center.z + radius do
            for y = 1, 12 do
                local node = minetest.get_node({x = x, y = y, z = z})
                if node.name == modname .. ":rotted_wood" and is_tree_trunk_base(x, y, z) then
                    local dist = vector.distance(pos, {x = x, y = y, z = z})
                    if dist < nearest_distance then
                        nearest = {x = x, y = y, z = z}
                        nearest_distance = dist
                    end
                    break
                end
            end
        end
    end
    return nearest
end

local function chop_tree_at(trunk_pos)
    local wood_count = 0
    local min_y = math.max(1, trunk_pos.y - 1)
    local max_y = trunk_pos.y + 9
    for y = min_y, max_y do
        local pos = {x = trunk_pos.x, y = y, z = trunk_pos.z}
        if minetest.get_node(pos).name == modname .. ":rotted_wood" then
            minetest.set_node(pos, {name = "air"})
            wood_count = wood_count + 1
        end
    end

    for x = trunk_pos.x - 3, trunk_pos.x + 3 do
        for y = min_y, max_y + 2 do
            for z = trunk_pos.z - 3, trunk_pos.z + 3 do
                local pos = {x = x, y = y, z = z}
                if minetest.get_node(pos).name == modname .. ":dead_leaves" then
                    minetest.set_node(pos, {name = "air"})
                end
            end
        end
    end

    return wood_count
end

local function area_clear_for_villager_shelter(ox, oz, floor_y)
    for x = ox - 1, ox + 6 do
        for z = oz - 1, oz + 5 do
            if minetest.get_node({x = x, y = floor_y, z = z}).name ~= modname .. ":dry_grass" then
                return false
            end
            for y = floor_y + 1, floor_y + 6 do
                local node_name = minetest.get_node({x = x, y = y, z = z}).name
                if node_name ~= "air"
                    and node_name ~= modname .. ":dead_leaves"
                    and node_name ~= modname .. ":rotted_wood" then
                    return false
                end
            end
        end
    end
    return true
end

local function build_villager_shelter(ox, oz, floor_y)
    local wood = modname .. ":rotted_wood"
    local floor = modname .. ":dry_grass"
    fill_area({x = ox - 1, y = floor_y + 1, z = oz - 1}, {x = ox + 6, y = floor_y + 6, z = oz + 5}, "air")
    fill_area({x = ox, y = floor_y, z = oz}, {x = ox + 5, y = floor_y, z = oz + 4}, floor)
    for y = floor_y + 1, floor_y + 3 do
        fill_area({x = ox, y = y, z = oz}, {x = ox + 5, y = y, z = oz}, wood)
        fill_area({x = ox, y = y, z = oz + 4}, {x = ox + 5, y = y, z = oz + 4}, wood)
        fill_area({x = ox, y = y, z = oz}, {x = ox, y = y, z = oz + 4}, wood)
        fill_area({x = ox + 5, y = y, z = oz}, {x = ox + 5, y = y, z = oz + 4}, wood)
    end
    fill_area({x = ox + 1, y = floor_y + 1, z = oz + 1}, {x = ox + 4, y = floor_y + 2, z = oz + 3}, "air")
    fill_area({x = ox + 2, y = floor_y + 1, z = oz}, {x = ox + 3, y = floor_y + 2, z = oz}, "air")
    fill_area({x = ox - 1, y = floor_y + 4, z = oz - 1}, {x = ox + 6, y = floor_y + 4, z = oz + 5}, wood)
    minetest.set_node({x = ox + 1, y = floor_y + 1, z = oz + 3}, {name = modname .. ":workbench"})
    minetest.set_node({x = ox + 4, y = floor_y + 1, z = oz + 3}, {name = modname .. ":shelter_hint"})
end

place_player_shelter = function(user, pointed_thing)
    local base_pos
    if pointed_thing and pointed_thing.type == "node" then
        base_pos = pointed_thing.above
    else
        local look = user:get_look_dir()
        base_pos = vector.add(user:get_pos(), vector.multiply(look, 3.4))
    end

    local ground_y = find_ground_y({x = base_pos.x, y = base_pos.y + 4, z = base_pos.z})
    if not ground_y then
        return false
    end
    local ox = math.floor(base_pos.x + 0.5) - 2
    local oz = math.floor(base_pos.z + 0.5) - 2
    local floor_y = ground_y - 1
    if not area_clear_for_villager_shelter(ox, oz, floor_y) then
        return false
    end
    build_villager_shelter(ox, oz, floor_y)
    if record_player_event then
        record_player_event(user, "shelter_built", 1)
    end
    minetest.chat_send_player(user:get_player_name(), "Shelter built. Its roof blocks rain and the workbench is ready.")
    return true
end

local function find_villager_shelter_site(pos)
    local base_x = math.floor(pos.x + 0.5)
    local base_z = math.floor(pos.z + 0.5)
    local offsets = {
        {x = 4, z = 4},
        {x = -9, z = 4},
        {x = 4, z = -8},
        {x = -9, z = -8},
        {x = 8, z = 0},
        {x = -13, z = 0},
    }
    for _, offset in ipairs(offsets) do
        local ox = base_x + offset.x
        local oz = base_z + offset.z
        local ground_y = find_ground_y({x = ox + 2, y = pos.y, z = oz + 2})
        local floor_y = ground_y and ground_y - 1
        if floor_y and area_clear_for_villager_shelter(ox, oz, floor_y) then
            return ox, oz, floor_y
        end
    end
    return nil, nil, nil
end

local function set_villager_state(self, state, duration)
    self.state = state
    self.state_timer = duration or 0
end

minetest.register_entity(modname .. ":builder_villager", {
    initial_properties = {
        physical = true,
        collide_with_objects = false,
        pointable = true,
        collisionbox = {-0.45, 0, -0.45, 0.45, 2.2, 0.45},
        selectionbox = {-0.75, 0, -0.75, 0.75, 2.6, 0.75},
        visual = "mesh",
        mesh = "wasteland_mc_archer.b3d",
        visual_size = {x = 7, y = 7, z = 7},
        textures = {"wasteland_mc_archer.png^[colorize:#6fa86f:70"},
        static_save = true,
    },
    state = "search_tree",
    state_timer = 0,
    search_timer = 0,
    visual_sink = 0.18,
    wood_count = 0,
    target_tree = nil,
    shelter_built = false,
    player_seen = true,
    on_activate = function(self)
        self.object:set_properties({
            collide_with_objects = false,
            pointable = true,
            collisionbox = {-0.45, 0, -0.45, 0.45, 2.2, 0.45},
            selectionbox = {-0.75, 0, -0.75, 0.75, 2.6, 0.75},
            visual = "mesh",
            mesh = "wasteland_mc_archer.b3d",
            visual_size = {x = 7, y = 7, z = 7},
            textures = {"wasteland_mc_archer.png^[colorize:#6fa86f:70"},
        })
        self.object:set_armor_groups({immortal = 1})
        self.object:set_acceleration({x = 0, y = 0, z = 0})
        self.object:set_nametag_attributes({text = "Builder Villager", color = "#b7f2b0"})
        self.object:set_animation(BOW_BONE_ANIMATIONS.idle, 8, 0, true)
        self.player_seen = true
        self.state = "search_tree"
        self.state_timer = 0
        self.search_timer = 0
        self.visual_sink = 0.18
        self.target_tree = nil
        snap_animal_to_ground(self)
    end,
    on_rightclick = function(self, clicker)
        if clicker and clicker:is_player() then
            local name = clicker:get_player_name()
            if self.shelter_built then
                minetest.chat_send_player(name, "Builder Mara: The shelter is up. Roads lead to food, factories lead to parts, and the depot terminal can wake the old city grid.")
            elseif self.wood_count >= 8 then
                minetest.chat_send_player(name, "Builder Mara: I have enough timber. Give me a clear patch and I can raise a roof.")
            else
                minetest.chat_send_player(name, "Builder Mara: I lost my crew when the rain turned wrong. Bring wood, keep a roof nearby, and do not fight bears without a charged shot.")
            end
            minetest.chat_send_player(name, quest_hud_text(clicker))
        end
    end,
    on_step = function(self, dtime)
        local pos = snap_animal_to_ground(self)
        self.state_timer = math.max(0, (self.state_timer or 0) - dtime)
        self.search_timer = math.max(0, (self.search_timer or 0) - dtime)

        if self.shelter_built then
            self.object:set_velocity({x = 0, y = 0, z = 0})
            self.object:set_animation(BOW_BONE_ANIMATIONS.idle, 8, 0, true)
            return
        end

        if self.wood_count >= 8 then
            if self.state ~= "build_shelter" then
                set_villager_state(self, "build_shelter", 1.5)
                self.object:set_velocity({x = 0, y = 0, z = 0})
                self.object:set_animation(BOW_BONE_ANIMATIONS.mid, 8, 0, true)
            elseif self.state_timer <= 0 then
                local ox, oz, floor_y = find_villager_shelter_site(pos)
                if ox then
                    build_villager_shelter(ox, oz, floor_y)
                    self.shelter_built = true
                    self.object:set_nametag_attributes({text = "Builder Villager - Shelter Ready", color = "#d7ffc8"})
                else
                    self.wood_count = 0
                    set_villager_state(self, "search_tree", 0.5)
                end
            end
            return
        end

        if self.state == "search_tree" or not self.target_tree then
            if self.search_timer > 0 then
                self.object:set_velocity({x = 0, y = 0, z = 0})
                return
            end
            self.search_timer = 2
            self.target_tree = find_nearest_tree_trunk(pos, 24)
            if self.target_tree then
                set_villager_state(self, "walk_to_tree", 0)
                self.object:set_animation(BOW_BONE_ANIMATIONS.light, 10, 0, true)
            else
                self.object:set_velocity({x = 0, y = 0, z = 0})
                self.object:set_animation(BOW_BONE_ANIMATIONS.idle, 8, 0, true)
            end
            return
        end

        if self.state == "walk_to_tree" then
            local target = {x = self.target_tree.x, y = pos.y, z = self.target_tree.z}
            local dist = vector.distance(pos, target)
            if dist <= 1.6 then
                self.object:set_velocity({x = 0, y = 0, z = 0})
                set_villager_state(self, "chop_tree", 1.2)
                self.object:set_animation(BOW_BONE_ANIMATIONS.spear_mid, 9, 0, true)
                return
            end
            local dir = flat_dir(pos, target)
            if dir then
                move_ground_animal(self, dir, 1.15, 2.2, dtime)
            end
            return
        end

        if self.state == "chop_tree" then
            self.object:set_velocity({x = 0, y = 0, z = 0})
            if self.state_timer <= 0 then
                self.wood_count = self.wood_count + chop_tree_at(self.target_tree)
                self.target_tree = nil
                set_villager_state(self, "search_tree", 0.4)
                self.object:set_animation(BOW_BONE_ANIMATIONS.idle, 8, 0, true)
            end
        end
    end,
})

fill_area = function(minp, maxp, node)
    for x = minp.x, maxp.x do
        for y = minp.y, maxp.y do
            for z = minp.z, maxp.z do
                minetest.set_node({x = x, y = y, z = z}, {name = node})
            end
        end
    end
end

local function place_ground_glow_fungus(x, y, z)
    local pos = {x = x, y = y, z = z}
    if minetest.get_node(pos).name ~= "air" then
        return false
    end
    local below_name = minetest.get_node({x = x, y = y - 1, z = z}).name
    if below_name ~= modname .. ":dry_grass"
        and below_name ~= modname .. ":dead_leaves"
        and below_name ~= modname .. ":rotted_wood"
    then
        return false
    end
    minetest.set_node(pos, {name = modname .. ":glow_fungus"})
    return true
end

local function place_wall_glow_fungus(pos, support)
    if minetest.get_node(pos).name ~= "air" then
        return false
    end
    local support_name = minetest.get_node(support).name
    if support_name == "air" or support_name == modname .. ":wall_glow_fungus" then
        return false
    end
    local param2 = minetest.dir_to_wallmounted(vector.subtract(support, pos), true)
    minetest.set_node(pos, {name = modname .. ":wall_glow_fungus", param2 = param2})
    return true
end

local function scatter_wall_glow_fungus_on_building(ox, oz, length, width, height, density)
    local attempts = math.max(4, math.floor((length + width + height) * density))
    local x_min = ox + 1
    local x_max = math.max(x_min, ox + length - 2)
    local z_min = oz + 1
    local z_max = math.max(z_min, oz + width - 2)
    local y_max = math.max(3, height)

    for _ = 1, attempts do
        local side = math.random(1, 4)
        local y = math.random(3, y_max)
        if side == 1 then
            local x = math.random(x_min, x_max)
            place_wall_glow_fungus({x = x, y = y, z = oz - 1}, {x = x, y = y, z = oz})
        elseif side == 2 then
            local x = math.random(x_min, x_max)
            place_wall_glow_fungus({x = x, y = y, z = oz + width}, {x = x, y = y, z = oz + width - 1})
        elseif side == 3 then
            local z = math.random(z_min, z_max)
            place_wall_glow_fungus({x = ox - 1, y = y, z = z}, {x = ox, y = y, z = z})
        else
            local z = math.random(z_min, z_max)
            place_wall_glow_fungus({x = ox + length, y = y, z = z}, {x = ox + length - 1, y = y, z = z})
        end
    end
end

local function scatter_forest_glow_fungus(minx, maxx, minz, maxz)
    local area = (maxx - minx + 1) * (maxz - minz + 1)
    local attempts = math.max(1, math.floor(area / 1600))
    for _ = 1, attempts do
        if math.random() < 0.45 then
            local x = math.random(minx, maxx)
            local z = math.random(minz, maxz)
            local dist = world_span_distance(x, z)
            if dist > CITY_RADIUS + 12 and dist <= FOREST_RADIUS then
                place_ground_glow_fungus(x, 2, z)
            end
        end
    end
end

_wf_scatter_loose_hand_lamps = function(minx, maxx, minz, maxz, attempts, chance)
    for _ = 1, attempts do
        if math.random() < chance then
            local x = math.random(minx, maxx)
            local z = math.random(minz, maxz)
            local dist = world_span_distance(x, z)
            if dist <= FOREST_RADIUS and minetest.get_node({x = x, y = 2, z = z}).name == "air" then
                local ground = minetest.get_node({x = x, y = 1, z = z}).name
                if ground == modname .. ":dry_grass"
                    or ground == modname .. ":cracked_asphalt"
                    or ground == modname .. ":rubble"
                then
                    _wf_spawn_pickup_item({x = x + 0.5, y = 2.1, z = z + 0.5}, modname .. ":hand_lamp")
                end
            end
        end
    end
end

local GLOW_FUNGUS_SUPPORT = {
    [modname .. ":bedrock"] = true,
    [modname .. ":rubble"] = true,
    [modname .. ":rotted_wood"] = true,
    [modname .. ":scrap_metal"] = true,
    [modname .. ":cracked_asphalt"] = true,
}

local function try_grow_city_wall_glow(center)
    local base_x = math.floor(center.x + 0.5)
    local base_z = math.floor(center.z + 0.5)
    local dirs = {
        {x = 1, z = 0},
        {x = -1, z = 0},
        {x = 0, z = 1},
        {x = 0, z = -1},
    }

    for _ = 1, 24 do
        local support = {
            x = base_x + math.random(-18, 18),
            y = math.random(3, 18),
            z = base_z + math.random(-18, 18),
        }
        if world_span_distance(support.x, support.z) <= CITY_RADIUS then
            local support_name = minetest.get_node(support).name
            if GLOW_FUNGUS_SUPPORT[support_name] then
                local dir = dirs[math.random(1, #dirs)]
                local pos = {x = support.x + dir.x, y = support.y, z = support.z + dir.z}
                if place_wall_glow_fungus(pos, support) then
                    return true
                end
            end
        end
    end
    return false
end

local function try_grow_forest_glow(center)
    local base_x = math.floor(center.x + 0.5)
    local base_z = math.floor(center.z + 0.5)
    for _ = 1, 10 do
        local x = base_x + math.random(-22, 22)
        local z = base_z + math.random(-22, 22)
        local dist = world_span_distance(x, z)
        if dist > CITY_RADIUS + 12 and dist <= FOREST_RADIUS and place_ground_glow_fungus(x, 2, z) then
            return true
        end
    end
    return false
end

update_glow_fungus_growth = function(player)
    local pos = player:get_pos()
    local dist = world_span_distance(pos.x, pos.z)
    if dist <= CITY_RADIUS then
        if math.random() < 0.65 then
            try_grow_city_wall_glow(pos)
        end
    elseif dist <= FOREST_RADIUS then
        if math.random() < 0.16 then
            try_grow_forest_glow(pos)
        end
    end
end

_wf_update_loose_lamp_spawns = function(player)
    local pos = player:get_pos()
    local dist = world_span_distance(pos.x, pos.z)
    if dist > FOREST_RADIUS then
        return
    end
    local chance = dist <= CITY_RADIUS and 0.045 or 0.018
    if math.random() >= chance then
        return
    end
    local x = math.floor(pos.x + 0.5) + math.random(-18, 18)
    local z = math.floor(pos.z + 0.5) + math.random(-18, 18)
    if world_span_distance(x, z) > FOREST_RADIUS or minetest.get_node({x = x, y = 2, z = z}).name ~= "air" then
        return
    end
    local ground = minetest.get_node({x = x, y = 1, z = z}).name
    if ground == modname .. ":dry_grass"
        or ground == modname .. ":cracked_asphalt"
        or ground == modname .. ":rubble"
    then
        _wf_spawn_pickup_item({x = x + 0.5, y = 2.1, z = z + 0.5}, modname .. ":hand_lamp")
    end
end

local function scatter_debris(center, radius, count)
    for _ = 1, count do
        local pos = {
            x = center.x + math.random(-radius, radius),
            y = 2,
            z = center.z + math.random(-radius, radius),
        }
        local node = math.random() < 0.45 and modname .. ":scrap_metal" or modname .. ":rubble"
        minetest.set_node(pos, {name = node})
    end
end

local function create_lamp_post(x, z)
    fill_area({x = x, y = 2, z = z}, {x = x, y = 5, z = z}, modname .. ":scrap_metal")
    fill_area({x = x, y = 5, z = z}, {x = x + 1, y = 5, z = z}, modname .. ":scrap_metal")
end

local function can_place_tree(x, z, ground_y, trunk_height, leaf_positions, allowed_ground)
    local ground_name = minetest.get_node({x = x, y = ground_y, z = z}).name
    if allowed_ground then
        if not allowed_ground[ground_name] then
            return false
        end
    elseif ground_name ~= modname .. ":dry_grass" then
        return false
    end

    for y = ground_y + 1, ground_y + trunk_height do
        if minetest.get_node({x = x, y = y, z = z}).name ~= "air" then
            return false
        end
    end

    for _, pos in ipairs(leaf_positions) do
        if minetest.get_node({x = x + pos.dx, y = ground_y + pos.dy, z = z + pos.dz}).name ~= "air" then
            return false
        end
    end
    return true
end

local function create_wasteland_tree(x, z, dense_leaves, ground_y, allowed_ground, node_names)
    ground_y = ground_y or 1
    local trunk_height = math.random(3, 5) + math.random(2, 3)
    local leaf_positions
    if dense_leaves then
        leaf_positions = {
            {dx = -1, dy = 3, dz = 0},
            {dx = 1, dy = 3, dz = 0},
            {dx = 0, dy = 3, dz = -1},
            {dx = 0, dy = 3, dz = 1},
            {dx = -2, dy = 3, dz = 0},
            {dx = 2, dy = 3, dz = 0},
            {dx = 0, dy = 3, dz = -2},
            {dx = 0, dy = 3, dz = 2},
            {dx = -1, dy = 3, dz = -1},
            {dx = -1, dy = 3, dz = 1},
            {dx = 1, dy = 3, dz = -1},
            {dx = 1, dy = 3, dz = 1},
            {dx = -1, dy = 4, dz = 0},
            {dx = 1, dy = 4, dz = 0},
            {dx = 0, dy = 4, dz = -1},
            {dx = 0, dy = 4, dz = 1},
            {dx = -2, dy = 4, dz = 0},
            {dx = 2, dy = 4, dz = 0},
            {dx = 0, dy = 4, dz = -2},
            {dx = 0, dy = 4, dz = 2},
            {dx = -1, dy = 4, dz = -1},
            {dx = -1, dy = 4, dz = 1},
            {dx = 1, dy = 4, dz = -1},
            {dx = 1, dy = 4, dz = 1},
            {dx = 0, dy = trunk_height + 1, dz = 0},
            {dx = -1, dy = trunk_height + 1, dz = 0},
            {dx = 1, dy = trunk_height + 1, dz = 0},
            {dx = 0, dy = trunk_height + 1, dz = -1},
            {dx = 0, dy = trunk_height + 1, dz = 1},
            {dx = -1, dy = trunk_height + 1, dz = -1},
            {dx = -1, dy = trunk_height + 1, dz = 1},
            {dx = 1, dy = trunk_height + 1, dz = -1},
            {dx = 1, dy = trunk_height + 1, dz = 1},
            {dx = 0, dy = trunk_height + 2, dz = 0},
            {dx = -1, dy = trunk_height + 2, dz = 0},
            {dx = 1, dy = trunk_height + 2, dz = 0},
            {dx = 0, dy = trunk_height + 2, dz = -1},
            {dx = 0, dy = trunk_height + 2, dz = 1},
        }
    else
        leaf_positions = {
            {dx = 0, dy = trunk_height + 1, dz = 0},
            {dx = -1, dy = trunk_height + 1, dz = 0},
            {dx = 1, dy = trunk_height + 1, dz = 0},
            {dx = 0, dy = trunk_height + 1, dz = -1},
            {dx = 0, dy = trunk_height + 1, dz = 1},
        }
        if math.random() < 0.45 then
            table.insert(leaf_positions, {dx = 0, dy = trunk_height + 2, dz = 0})
        end
    end

    local unique_positions = {}
    local seen_positions = {}
    for _, pos in ipairs(leaf_positions) do
        local key = pos.dx .. ":" .. pos.dy .. ":" .. pos.dz
        if not seen_positions[key] then
            table.insert(unique_positions, pos)
            seen_positions[key] = true
        end
    end
    leaf_positions = unique_positions

    if not can_place_tree(x, z, ground_y, trunk_height, leaf_positions, allowed_ground) then
        return false
    end

    local trunk = node_names and node_names.trunk or modname .. ":rotted_wood"
    local leaf = node_names and node_names.leaf or modname .. ":dead_leaves"
    fill_area({x = x, y = ground_y + 1, z = z}, {x = x, y = ground_y + trunk_height, z = z}, trunk)

    for _, pos in ipairs(leaf_positions) do
        minetest.set_node({x = x + pos.dx, y = ground_y + pos.dy, z = z + pos.dz}, {name = leaf})
    end
    return true
end

local function scatter_trees_in_area(minx, maxx, minz, maxz, attempts, chance, dense_leaves, ground_y, allowed_ground)
    for _ = 1, attempts do
        if math.random() < chance then
            create_wasteland_tree(math.random(minx, maxx), math.random(minz, maxz), dense_leaves, ground_y, allowed_ground)
        end
    end
end

local function scatter_trees_on_scenic_hill(ox, oz)
    local bedrock_ground = {
        [modname .. ":bedrock"] = true,
    }
    local spots = {
        {dx = -4, dz = -4, ground_y = 2},
        {dx = 4, dz = -4, ground_y = 2},
        {dx = -4, dz = 4, ground_y = 2},
        {dx = 4, dz = 4, ground_y = 2},
        {dx = -3, dz = -2, ground_y = 4},
        {dx = 3, dz = -2, ground_y = 4},
        {dx = -2, dz = 3, ground_y = 4},
        {dx = 2, dz = 3, ground_y = 4},
    }

    for _, spot in ipairs(spots) do
        if math.random() < 0.8 then
            create_wasteland_tree(ox + spot.dx, oz + spot.dz, true, spot.ground_y, bedrock_ground)
        end
    end
end

local function scatter_dirty_water_puddles(minx, maxx, minz, maxz, attempts, chance)
    for _ = 1, attempts do
        if math.random() < chance then
            local x = math.random(minx, maxx)
            local z = math.random(minz, maxz)
            if minetest.get_node({x = x, y = 1, z = z}).name == modname .. ":dry_grass"
                and minetest.get_node({x = x, y = 2, z = z}).name == "air" then
                minetest.set_node({x = x, y = 1, z = z}, {name = modname .. ":dirty_water"})
            end
        end
    end
end

world_span_distance = function(x, z)
    return math.max(math.abs(x), math.abs(z))
end

local function paint_cloud_layer(minx, maxx, minz, maxz, y, step, chance)
    local cloud = modname .. ":storm_cloud"
    for x = minx, maxx, step do
        for z = minz, maxz, step do
            local center_x = math.min(x + math.floor(step / 2), maxx)
            local center_z = math.min(z + math.floor(step / 2), maxz)
            if world_span_distance(center_x, center_z) <= CLOUD_RADIUS and math.random() < chance then
                fill_area(
                    {x = x, y = y, z = z},
                    {x = math.min(x + step - 1, maxx), y = y, z = math.min(z + step - 1, maxz)},
                    cloud
                )
            end
        end
    end
end

local function create_city_canopy()
    paint_cloud_layer(-CITY_RADIUS, CITY_RADIUS, -CITY_RADIUS, CITY_RADIUS, CLOUD_Y, 4, 0.88)
    paint_cloud_layer(-CITY_RADIUS, CITY_RADIUS, -CITY_RADIUS, CITY_RADIUS, CLOUD_Y + 1, 4, 0.72)
end

local function create_cloud_chunk(minx, maxx, minz, maxz)
    paint_cloud_layer(minx, maxx, minz, maxz, CLOUD_Y, 5, 0.58)
    paint_cloud_layer(minx, maxx, minz, maxz, CLOUD_Y + 1, 5, 0.36)
end

_wf_story_sign_route = {
    {
        x = 0,
        z = 24,
        title = "Awakening Board",
        text = "The city woke under storm cloud. Gather what still glows, then follow the south road.",
        next = "Next sign: south shelter road.",
    },
    {
        x = 0,
        z = 72,
        title = "South Road",
        text = "The road dies at the trees. The rescue trail continues where the wooden signs shine.",
        next = "Next sign: forest gate.",
    },
    {
        x = 0,
        z = 112,
        title = "Forest Gate",
        text = "Rainforest ahead. Keep a torch or hand lamp ready. The boards lead south under the clouds.",
        next = "Next sign: 220 south.",
    },
    {
        x = 0,
        z = 220,
        title = "Root Mile",
        text = "The roots twist, but the old survey line is straight. Stay close to the glowing path.",
        next = "Next sign: 360 south.",
    },
    {
        x = 0,
        z = 360,
        title = "Broken Relay",
        text = "The clouds thicken here. The fungus marks shelter walls; the brighter wooden boards mark escape.",
        next = "Next sign: 520 south.",
    },
    {
        x = 0,
        z = 520,
        title = "Quiet Rain",
        text = "Do not turn back toward the city lights. Every board after this points beyond the canopy.",
        next = "Next sign: 680 south.",
    },
    {
        x = 0,
        z = 680,
        title = "Last Canopy",
        text = "The storm is thinning. Keep south until the sky opens and the forest line breaks.",
        next = "Next sign: forest edge.",
    },
    {
        x = 0,
        z = 792,
        title = "Forest Edge",
        text = "This is the edge of the deep trees. Past the next marker, the cloud cover ends.",
        next = "Next sign: final board at the escape line.",
    },
    {
        x = 0,
        z = 808,
        title = "Open Sky",
        text = "Step beyond the cloud forest. When the sky clears, the route is complete.",
        next = "Goal: walk past the forest and cloud line to win.",
    },
}

STORY_PATH_HALF_WIDTH = 4
STORY_PATH_CLEAR_TOP_Y = CLOUD_Y - 1
STORY_PATH_TREE_MIN_X = 7
STORY_PATH_TREE_MAX_X = 22
STORY_PATH_TREE_CLEAR_TOP_Y = 14
STORY_PATH_START_Z = 0
STORY_PATH_END_Z = ESCAPE_RADIUS + 8
STORY_PATH_BUILD_TOKEN = "permanent_south_escape_route_2026_10_14_a"

function _wf_story_path_marker_node(name)
    return name == modname .. ":story_sign"
        or name == modname .. ":escape_route_torch"
        or name == modname .. ":escape_route_glow_fungus"
end

function _wf_story_tree_node(name)
    return name == modname .. ":rotted_wood"
        or name == modname .. ":dead_leaves"
        or name == modname .. ":escape_tree_wood"
        or name == modname .. ":escape_tree_leaves"
end

function _wf_load_story_route_area(minp, maxp)
    if minetest.load_area then
        minetest.load_area(
            {x = minp.x, y = -4, z = minp.z},
            {x = maxp.x, y = 32, z = maxp.z}
        )
    end
end

function _wf_clear_story_path_air_column(x, z, top_y)
    for y = 2, top_y do
        local clear_pos = {x = x, y = y, z = z}
        local node = minetest.get_node_or_nil(clear_pos)
        if node and node.name ~= modname .. ":storm_cloud" and not _wf_story_path_marker_node(node.name) then
            minetest.set_node(clear_pos, {name = "air"})
        end
    end
end

function _wf_story_path_tree_chance(z)
    local dist = world_span_distance(0, z)
    if dist <= CITY_RADIUS + 12 or dist > FOREST_RADIUS then
        return 0
    end
    if dist >= FOREST_RADIUS - 40 then
        return 0.28
    elseif dist >= FOREST_RADIUS - 120 then
        return 0.48
    elseif dist <= CITY_RADIUS + 120 then
        return 0.86
    end
    return 0.72
end

function _wf_story_tree_exists_near(x, z)
    for tx = x - 2, x + 2 do
        for tz = z - 2, z + 2 do
            for y = 2, STORY_PATH_TREE_CLEAR_TOP_Y do
                local name = minetest.get_node({x = tx, y = y, z = tz}).name
                if _wf_story_tree_node(name) then
                    return true
                end
            end
        end
    end
    return false
end

function _wf_prepare_story_path_tree_site(x, z)
    if math.abs(x) <= STORY_PATH_HALF_WIDTH + 1 or world_span_distance(x, z) > FOREST_RADIUS then
        return false
    end
    if _wf_story_tree_exists_near(x, z) then
        return false
    end

    for tx = x - 2, x + 2 do
        for tz = z - 2, z + 2 do
            if math.abs(tx) > STORY_PATH_HALF_WIDTH + 1 then
                minetest.set_node({x = tx, y = 1, z = tz}, {name = modname .. ":escape_path_grass"})
                _wf_clear_story_path_air_column(tx, tz, STORY_PATH_TREE_CLEAR_TOP_Y)
            end
        end
    end

    return create_wasteland_tree(x, z, true, 1, {
        [modname .. ":dry_grass"] = true,
        [modname .. ":escape_path_grass"] = true,
    }, {
        trunk = modname .. ":escape_tree_wood",
        leaf = modname .. ":escape_tree_leaves",
    })
end

function _wf_scatter_story_path_trees(minp, maxp)
    if maxp.z < CITY_RADIUS + 12
        or minp.z > FOREST_RADIUS
        or maxp.x < -STORY_PATH_TREE_MAX_X
        or minp.x > STORY_PATH_TREE_MAX_X then
        return
    end

    local start_z = math.max(CITY_RADIUS + 18, minp.z)
    local end_z = math.min(FOREST_RADIUS - 4, maxp.z)
    if start_z > end_z then
        return
    end

    for z = start_z, end_z, 8 do
        local tree_z = math.max(start_z, math.min(end_z, z + math.random(-2, 2)))
        local chance = _wf_story_path_tree_chance(tree_z)
        for _, side in ipairs({-1, 1}) do
            if math.random() < chance then
                local tree_x = side * math.random(STORY_PATH_TREE_MIN_X, STORY_PATH_TREE_MAX_X)
                if tree_x >= minp.x and tree_x <= maxp.x then
                    _wf_prepare_story_path_tree_site(tree_x, tree_z)
                end
            end
            if math.random() < chance * 0.42 then
                local tree_x = side * math.random(STORY_PATH_TREE_MAX_X + 1, STORY_PATH_TREE_MAX_X + 10)
                if tree_x >= minp.x and tree_x <= maxp.x then
                    local far_tree_z = math.max(start_z, math.min(end_z, tree_z + math.random(-3, 3)))
                    _wf_prepare_story_path_tree_site(tree_x, far_tree_z)
                end
            end
        end
    end
end

function _wf_clear_story_path_bounds(minp, maxp)
    local start_z = STORY_PATH_START_Z
    local end_z = STORY_PATH_END_Z
    local start_x = -STORY_PATH_HALF_WIDTH
    local end_x = STORY_PATH_HALF_WIDTH
    if minp and maxp then
        start_z = math.max(start_z, minp.z, STORY_PATH_START_Z)
        end_z = math.min(end_z, maxp.z, STORY_PATH_END_Z)
        start_x = math.max(start_x, minp.x)
        end_x = math.min(end_x, maxp.x)
    end
    if start_z > end_z or start_x > end_x then
        return
    end
    for x = start_x, end_x do
        for path_z = start_z, end_z do
            if world_span_distance(x, path_z) <= ESCAPE_RADIUS then
                local ground_name = modname .. ":escape_path_grass"
                if world_span_distance(x, path_z) <= CITY_RADIUS or math.abs(x) <= 1 then
                    ground_name = modname .. ":escape_path_asphalt"
                end
                minetest.set_node({x = x, y = 0, z = path_z}, {name = modname .. ":dry_grass"})
                minetest.set_node({x = x, y = 1, z = path_z}, {name = ground_name})
                _wf_clear_story_path_air_column(x, path_z, STORY_PATH_CLEAR_TOP_Y)
            end
        end
    end
end

_wf_clear_story_path_segment = function(z, minp, maxp)
    if minp and maxp then
        _wf_clear_story_path_bounds(minp, maxp)
        return
    end
    _wf_clear_story_path_bounds({
        x = -STORY_PATH_HALF_WIDTH,
        z = z - 72,
    }, {
        x = STORY_PATH_HALF_WIDTH,
        z = z + 72,
    })
end

_wf_place_story_sign = function(sign, minp, maxp)
    minetest.set_node({x = sign.x, y = 1, z = sign.z}, {name = modname .. ":escape_path_asphalt"})
    minetest.set_node({x = sign.x, y = 2, z = sign.z}, {name = modname .. ":story_sign"})
    minetest.set_node({x = sign.x - 1, y = 2, z = sign.z}, {name = modname .. ":escape_route_torch"})
    minetest.set_node({x = sign.x + 1, y = 2, z = sign.z}, {name = modname .. ":escape_route_glow_fungus"})
    local sign_pos = {x = sign.x, y = 2, z = sign.z}
    if not minetest.get_node_or_nil(sign_pos) then
        return
    end
    local meta = minetest.get_meta(sign_pos)
    meta:set_string("title", sign.title)
    meta:set_string("text", sign.text)
    meta:set_string("next", sign.next)
    meta:set_string("infotext", sign.title .. " - right click to read")
end

_wf_place_story_signs_in_chunk = function(minp, maxp)
    if maxp.z >= STORY_PATH_START_Z
        and minp.z <= STORY_PATH_END_Z
        and minp.x <= STORY_PATH_HALF_WIDTH
        and maxp.x >= -STORY_PATH_HALF_WIDTH then
        _wf_clear_story_path_bounds(minp, maxp)
    end
    _wf_scatter_story_path_trees(minp, maxp)
    for _, sign in ipairs(_wf_story_sign_route) do
        if sign.x >= minp.x and sign.x <= maxp.x and sign.z >= minp.z and sign.z <= maxp.z then
            _wf_place_story_sign(sign, minp, maxp)
        end
    end
end

function _wf_ensure_story_escape_route(force)
    if not force and storage:get_string("story_escape_route_token") == STORY_PATH_BUILD_TOKEN then
        return
    end

    local route_min_x = -STORY_PATH_TREE_MAX_X - 10
    local route_max_x = STORY_PATH_TREE_MAX_X + 10
    local segment = 80
    local z = STORY_PATH_START_Z
    while z <= STORY_PATH_END_Z do
        local minp = {x = route_min_x, y = 0, z = z}
        local maxp = {
            x = route_max_x,
            y = STORY_PATH_CLEAR_TOP_Y,
            z = math.min(z + segment - 1, STORY_PATH_END_Z),
        }
        _wf_load_story_route_area(minp, maxp)
        _wf_place_story_signs_in_chunk(minp, maxp)
        z = z + segment
    end

    storage:set_string("story_escape_route_token", STORY_PATH_BUILD_TOKEN)
end

_wf_maintain_escape_path_for_player = function(player)
    return
end


local function create_forest_chunk(minx, maxx, minz, maxz)
    local grass = modname .. ":dry_grass"
    local allowed_ground = {[grass] = true}

    local step = 6
    for x = minx, maxx, step do
        for z = minz, maxz, step do
            local px = math.min(x + math.random(0, math.min(step - 1, maxx - x)), maxx)
            local pz = math.min(z + math.random(0, math.min(step - 1, maxz - z)), maxz)
            local dist = world_span_distance(px, pz)
            if dist > CITY_RADIUS + 6 and dist <= FOREST_RADIUS then
                minetest.set_node({x = px, y = 1, z = pz}, {name = grass})
                local density
                if dist < CITY_RADIUS + 120 then
                    density = 0.92
                elseif dist < CITY_RADIUS + 320 then
                    density = 0.8
                else
                    density = 0.66
                end
                if math.random() < density then
                    create_wasteland_tree(px, pz, true, 1, allowed_ground)
                end
            end
        end
    end
end

local function create_rainforest_band()
    local grass = modname .. ":dry_grass"
    fill_area({x = -80, y = 1, z = -80}, {x = -50, y = 1, z = 80}, grass)
    fill_area({x = 50, y = 1, z = -80}, {x = 80, y = 1, z = 80}, grass)
    fill_area({x = -49, y = 1, z = -80}, {x = 49, y = 1, z = -52}, grass)
    fill_area({x = -49, y = 1, z = 52}, {x = 49, y = 1, z = 80}, grass)

    scatter_trees_in_area(-78, -51, -78, 78, 340, 0.88, true)
    scatter_trees_in_area(51, 78, -78, 78, 340, 0.88, true)
    scatter_trees_in_area(-48, 48, -78, -53, 260, 0.84, true)
    scatter_trees_in_area(-48, 48, 53, 78, 260, 0.84, true)

    scatter_dirty_water_puddles(-78, -51, -78, 78, 10, 0.06)
    scatter_dirty_water_puddles(51, 78, -78, 78, 10, 0.06)
    scatter_dirty_water_puddles(-48, 48, -78, -53, 8, 0.05)
    scatter_dirty_water_puddles(-48, 48, 53, 78, 8, 0.05)
end

local function create_villager_hut(ox, oz)
    local wood = modname .. ":rotted_wood"
    local stone = modname .. ":rubble"
    local metal = modname .. ":scrap_metal"
    local workbench = modname .. ":workbench"

    fill_area({x = ox - 2, y = 1, z = oz - 2}, {x = ox + 8, y = 8, z = oz + 7}, "air")
    fill_area({x = ox - 1, y = 0, z = oz - 1}, {x = ox + 7, y = 0, z = oz + 6}, modname .. ":dry_grass")

    fill_area({x = ox, y = 1, z = oz}, {x = ox + 6, y = 1, z = oz + 5}, stone)

    for y = 2, 4 do
        for x = ox, ox + 6 do
            minetest.set_node({x = x, y = y, z = oz}, {name = wood})
            minetest.set_node({x = x, y = y, z = oz + 5}, {name = wood})
        end
        for z = oz, oz + 5 do
            minetest.set_node({x = ox, y = y, z = z}, {name = wood})
            minetest.set_node({x = ox + 6, y = y, z = z}, {name = wood})
        end
    end

    fill_area({x = ox + 1, y = 2, z = oz + 1}, {x = ox + 5, y = 4, z = oz + 4}, "air")
    fill_area({x = ox + 3, y = 2, z = oz}, {x = ox + 3, y = 3, z = oz}, "air")
    minetest.set_node({x = ox + 2, y = 3, z = oz}, {name = "air"})
    minetest.set_node({x = ox + 4, y = 3, z = oz}, {name = "air"})
    minetest.set_node({x = ox, y = 3, z = oz + 2}, {name = "air"})
    minetest.set_node({x = ox + 6, y = 3, z = oz + 3}, {name = "air"})

    fill_area({x = ox - 1, y = 5, z = oz - 1}, {x = ox + 7, y = 5, z = oz + 6}, wood)
    fill_area({x = ox, y = 6, z = oz}, {x = ox + 6, y = 6, z = oz + 5}, wood)
    fill_area({x = ox + 1, y = 7, z = oz + 1}, {x = ox + 5, y = 7, z = oz + 4}, wood)

    fill_area({x = ox + 2, y = 2, z = oz - 1}, {x = ox + 4, y = 2, z = oz - 1}, stone)
    minetest.set_node({x = ox + 1, y = 2, z = oz + 4}, {name = workbench})
    minetest.set_node({x = ox + 5, y = 2, z = oz + 1}, {name = stone})
    minetest.set_node({x = ox + 5, y = 3, z = oz + 1}, {name = metal})
end

local function create_starter_shelter(ox, oz)
    ox = ox or -4
    oz = oz or 5
    local wood = modname .. ":rotted_wood"
    local stone = modname .. ":rubble"
    local metal = modname .. ":scrap_metal"
    local floor = modname .. ":cracked_asphalt"

    fill_area({x = ox - 1, y = 1, z = oz - 1}, {x = ox + 9, y = 7, z = oz + 8}, "air")
    fill_area({x = ox, y = 1, z = oz}, {x = ox + 8, y = 1, z = oz + 6}, floor)

    for y = 2, 4 do
        fill_area({x = ox, y = y, z = oz}, {x = ox + 8, y = y, z = oz}, wood)
        fill_area({x = ox, y = y, z = oz + 6}, {x = ox + 8, y = y, z = oz + 6}, wood)
        fill_area({x = ox, y = y, z = oz}, {x = ox, y = y, z = oz + 6}, stone)
        fill_area({x = ox + 8, y = y, z = oz}, {x = ox + 8, y = y, z = oz + 6}, stone)
    end

    fill_area({x = ox + 1, y = 2, z = oz + 1}, {x = ox + 7, y = 4, z = oz + 5}, "air")
    fill_area({x = ox + 3, y = 2, z = oz}, {x = ox + 5, y = 3, z = oz}, "air")
    minetest.set_node({x = ox + 1, y = 3, z = oz}, {name = "air"})
    minetest.set_node({x = ox + 7, y = 3, z = oz + 6}, {name = "air"})
    minetest.set_node({x = ox, y = 3, z = oz + 3}, {name = "air"})
    minetest.set_node({x = ox + 8, y = 3, z = oz + 3}, {name = "air"})

    fill_area({x = ox - 1, y = 5, z = oz - 1}, {x = ox + 9, y = 5, z = oz + 7}, metal)
    fill_area({x = ox, y = 6, z = oz}, {x = ox + 8, y = 6, z = oz + 6}, wood)

    fill_area({x = ox + 3, y = 1, z = oz - 2}, {x = ox + 5, y = 1, z = oz - 1}, floor)
    minetest.set_node({x = ox + 1, y = 2, z = oz + 1}, {name = modname .. ":workbench"})
    minetest.set_node({x = ox + 6, y = 2, z = oz + 1}, {name = modname .. ":starter_crate"})
    minetest.set_node({x = ox + 1, y = 2, z = oz + 5}, {name = modname .. ":shelter_hint"})
    minetest.set_node({x = ox + 7, y = 2, z = oz + 5}, {name = modname .. ":starter_crate"})
    minetest.set_node({x = ox + 4, y = 2, z = oz - 2}, {name = modname .. ":task_board"})
end

local function create_template_building(ox, oz, sx, sz, sy)
    local wall = modname .. ":bedrock"
    local trim = modname .. ":bedrock"
    local floor = modname .. ":bedrock"
    local shelf = modname .. ":rotted_wood"
    local goods = modname .. ":shelf_supply_parts"
    local base_length = 7
    local base_width = 6
    local base_height = 3
    local length = base_length * sx
    local width = base_width * sz
    local height = base_height * sy

    fill_area({x = ox - 1, y = 1, z = oz - 1}, {x = ox + length, y = height + 3, z = oz + width}, "air")
    fill_area({x = ox, y = 1, z = oz}, {x = ox + length - 1, y = 1, z = oz + width - 1}, floor)

    for y = 2, height + 1 do
        for x = ox, ox + length - 1 do
            minetest.set_node({x = x, y = y, z = oz}, {name = wall})
            minetest.set_node({x = x, y = y, z = oz + width - 1}, {name = wall})
        end
        for z = oz, oz + width - 1 do
            minetest.set_node({x = ox, y = y, z = z}, {name = wall})
            minetest.set_node({x = ox + length - 1, y = y, z = z}, {name = wall})
        end
    end

    for y = 4, height, 3 do
        for x = ox + 2, ox + length - 3, 3 do
            minetest.set_node({x = x, y = y, z = oz}, {name = "air"})
            minetest.set_node({x = x, y = y, z = oz + width - 1}, {name = "air"})
        end
        for z = oz + 2, oz + width - 3, 3 do
            minetest.set_node({x = ox, y = y, z = z}, {name = "air"})
            minetest.set_node({x = ox + length - 1, y = y, z = z}, {name = "air"})
        end
    end

    for y = 5, height - 1, 3 do
        fill_area({x = ox + 1, y = y, z = oz + 1}, {x = ox + length - 2, y = y, z = oz + width - 2}, floor)
    end

    local shop_depth = math.min(7, width - 2)
    local first_wall_x = ox + math.floor(length / 3)
    local second_wall_x = ox + math.floor(length * 2 / 3)
    if length >= 8 then
        fill_area({x = first_wall_x, y = 2, z = oz + 1}, {x = first_wall_x, y = 4, z = oz + shop_depth}, wall)
        fill_area({x = second_wall_x, y = 2, z = oz + 1}, {x = second_wall_x, y = 4, z = oz + shop_depth}, wall)
        minetest.set_node({x = first_wall_x, y = 2, z = oz + 2}, {name = "air"})
        minetest.set_node({x = first_wall_x, y = 3, z = oz + 2}, {name = "air"})
        minetest.set_node({x = second_wall_x, y = 2, z = oz + 2}, {name = "air"})
        minetest.set_node({x = second_wall_x, y = 3, z = oz + 2}, {name = "air"})
    end

    local function add_shelf(x1, z1, x2, z2)
        fill_area({x = x1, y = 2, z = z1}, {x = x2, y = 2, z = z2}, shelf)
        fill_area({x = x1, y = 3, z = z1}, {x = x2, y = 3, z = z2}, goods)
        fill_area({x = x1, y = 4, z = z1}, {x = x2, y = 4, z = z2}, shelf)
    end

    add_shelf(ox + 2, oz + 3, math.min(ox + 4, ox + length - 3), oz + 3)
    add_shelf(math.max(ox + 2, first_wall_x + 2), oz + 4, math.min(second_wall_x - 2, ox + length - 3), oz + 4)
    add_shelf(math.max(ox + 2, second_wall_x + 2), oz + 3, ox + length - 3, oz + 3)

    local door_center = ox + math.floor(length / 2)
    fill_area({x = door_center - 1, y = 2, z = oz}, {x = door_center + 1, y = 3, z = oz}, "air")
    fill_area({x = door_center - 1, y = 2, z = oz + 1}, {x = door_center + 1, y = 3, z = oz + 2}, "air")
    minetest.set_node({x = door_center - 2, y = 2, z = oz}, {name = trim})
    minetest.set_node({x = door_center + 2, y = 2, z = oz}, {name = trim})
    minetest.set_node({x = door_center - 2, y = 3, z = oz}, {name = trim})
    minetest.set_node({x = door_center + 2, y = 3, z = oz}, {name = trim})
    fill_area({x = door_center - 2, y = 4, z = oz}, {x = door_center + 2, y = 4, z = oz}, trim)
    fill_area({x = door_center - 1, y = 1, z = oz - 2}, {x = door_center + 1, y = 1, z = oz - 1}, floor)

    fill_area({x = ox, y = height + 2, z = oz}, {x = ox + length - 1, y = height + 2, z = oz + width - 1}, trim)
    fill_area({x = ox, y = 2, z = oz}, {x = ox, y = height + 1, z = oz}, trim)
    fill_area({x = ox + length - 1, y = 2, z = oz}, {x = ox + length - 1, y = height + 1, z = oz}, trim)
    fill_area({x = ox, y = 2, z = oz + width - 1}, {x = ox, y = height + 1, z = oz + width - 1}, trim)
    fill_area({x = ox + length - 1, y = 2, z = oz + width - 1}, {x = ox + length - 1, y = height + 1, z = oz + width - 1}, trim)
    scatter_wall_glow_fungus_on_building(ox, oz, length, width, height, 0.7)
end

local PLAN_UNIT_X = 7
local PLAN_UNIT_Z = 6
local PLAN_ROAD_HALF_X = PLAN_UNIT_X
local PLAN_ROAD_HALF_Z = PLAN_UNIT_Z
local PLAN_DISTRICT_COLS = 5
local PLAN_DISTRICT_ROWS = 7
local PLAN_WEST_X = -PLAN_ROAD_HALF_X - PLAN_DISTRICT_COLS * PLAN_UNIT_X - 1
local PLAN_EAST_X = PLAN_ROAD_HALF_X + 1
local PLAN_NORTH_Z = -PLAN_ROAD_HALF_Z - PLAN_DISTRICT_ROWS * PLAN_UNIT_Z - 1
local PLAN_SOUTH_Z = PLAN_ROAD_HALF_Z + 1

local function plan_cell_origin(district, col, row)
    return {
        x = district.x + col * PLAN_UNIT_X,
        z = district.z + row * PLAN_UNIT_Z,
    }
end

local function create_plan_roads()
    local road = modname .. ":cracked_asphalt"
    fill_area({x = -PLAN_ROAD_HALF_X, y = 1, z = -76}, {x = PLAN_ROAD_HALF_X - 1, y = 1, z = 76}, road)
    fill_area({x = -76, y = 1, z = -PLAN_ROAD_HALF_Z}, {x = 76, y = 1, z = PLAN_ROAD_HALF_Z - 1}, road)
    fill_area({x = -42, y = 1, z = -42}, {x = 42, y = 1, z = -38}, road)
    fill_area({x = -42, y = 1, z = 38}, {x = 42, y = 1, z = 42}, road)
    fill_area({x = -42, y = 1, z = -42}, {x = -38, y = 1, z = 42}, road)
    fill_area({x = 38, y = 1, z = -42}, {x = 42, y = 1, z = 42}, road)
end

local function create_plan_template_buildings()
    local districts = {
        {
            id = "nw",
            x = PLAN_WEST_X,
            z = PLAN_NORTH_Z,
            buildings = {
                {col = 0, row = 0, sx = 2, sz = 3, sy = 8},
                {col = 3, row = 0, sx = 1, sz = 3, sy = 6},
                {col = 0, row = 3, sx = 1, sz = 3, sy = 6},
                {col = 2, row = 3, sx = 1, sz = 1, sy = 3},
                {col = 4, row = 4, sx = 1, sz = 1, sy = 3},
                {col = 2, row = 6, sx = 1, sz = 1, sy = 3},
            },
        },
        {
            id = "ne",
            x = PLAN_EAST_X,
            z = PLAN_NORTH_Z,
            buildings = {
                {col = 3, row = 0, sx = 2, sz = 3, sy = 8},
                {col = 0, row = 1, sx = 1, sz = 3, sy = 6},
                {col = 1, row = 4, sx = 1, sz = 3, sy = 6},
                {col = 2, row = 3, sx = 1, sz = 1, sy = 3},
                {col = 4, row = 4, sx = 1, sz = 1, sy = 3},
                {col = 0, row = 6, sx = 1, sz = 1, sy = 3},
            },
        },
        {
            id = "sw",
            x = PLAN_WEST_X,
            z = PLAN_SOUTH_Z,
            buildings = {
                {col = 3, row = 4, sx = 2, sz = 3, sy = 8},
                {col = 0, row = 0, sx = 1, sz = 3, sy = 6},
                {col = 2, row = 1, sx = 1, sz = 3, sy = 6},
                {col = 4, row = 0, sx = 1, sz = 1, sy = 3},
                {col = 1, row = 4, sx = 1, sz = 1, sy = 3},
                {col = 0, row = 6, sx = 1, sz = 1, sy = 3},
            },
        },
        {
            id = "se",
            x = PLAN_EAST_X,
            z = PLAN_SOUTH_Z,
            buildings = {
                {col = 0, row = 1, sx = 2, sz = 3, sy = 8},
                {col = 3, row = 0, sx = 1, sz = 3, sy = 6},
                {col = 4, row = 3, sx = 1, sz = 3, sy = 6},
                {col = 0, row = 0, sx = 1, sz = 1, sy = 3},
                {col = 2, row = 5, sx = 1, sz = 1, sy = 3},
                {col = 3, row = 6, sx = 1, sz = 1, sy = 3},
            },
        },
    }

    for _, district in ipairs(districts) do
        fill_area(
            {x = district.x, y = 1, z = district.z},
            {
                x = district.x + PLAN_DISTRICT_COLS * PLAN_UNIT_X - 1,
                y = 1,
                z = district.z + PLAN_DISTRICT_ROWS * PLAN_UNIT_Z - 1,
            },
            modname .. ":dry_grass"
        )
        for _, building in ipairs(district.buildings) do
            local origin = plan_cell_origin(district, building.col, building.row)
            create_template_building(origin.x, origin.z, building.sx, building.sz, building.sy)
        end
        for col = 0, PLAN_DISTRICT_COLS - 1 do
            for row = 0, PLAN_DISTRICT_ROWS - 1 do
                if math.random() < 0.08 then
                    create_wasteland_tree(
                        district.x + col * PLAN_UNIT_X + math.floor(PLAN_UNIT_X / 2),
                        district.z + row * PLAN_UNIT_Z + math.floor(PLAN_UNIT_Z / 2)
                    )
                end
            end
        end
    end
end

local function create_simple_building(ox, oz, length, width, height, material, crate_zone, dangerous)
    fill_area({x = ox - 1, y = 1, z = oz - 1}, {x = ox + length, y = height + 3, z = oz + width}, "air")
    fill_area({x = ox, y = 1, z = oz}, {x = ox + length - 1, y = 1, z = oz + width - 1}, dangerous and modname .. ":rubble" or modname .. ":cracked_asphalt")
    for y = 2, height + 1 do
        for x = ox, ox + length - 1 do
            minetest.set_node({x = x, y = y, z = oz}, {name = material})
            minetest.set_node({x = x, y = y, z = oz + width - 1}, {name = material})
        end
        for z = oz, oz + width - 1 do
            minetest.set_node({x = ox, y = y, z = z}, {name = material})
            minetest.set_node({x = ox + length - 1, y = y, z = z}, {name = material})
        end
    end
    fill_area({x = ox + 1, y = 2, z = oz + 1}, {x = ox + length - 2, y = height, z = oz + width - 2}, "air")
    fill_area({x = ox, y = height + 1, z = oz}, {x = ox + length - 1, y = height + 1, z = oz + width - 1}, material)
    local door_x = ox + math.floor(length / 2)
    fill_area({x = door_x - 1, y = 2, z = oz}, {x = door_x + 1, y = 3, z = oz}, "air")
    for y = 3, height, 3 do
        minetest.set_node({x = ox + 2, y = y, z = oz}, {name = "air"})
        minetest.set_node({x = ox + length - 3, y = y, z = oz + width - 1}, {name = "air"})
    end
    if crate_zone then
        minetest.set_node({x = ox + 2, y = 2, z = oz + width - 3}, {name = modname .. ":loot_crate_" .. crate_zone})
    end
    scatter_wall_glow_fungus_on_building(ox, oz, length, width, height, 0.45)
end

local function create_factory_complex(ox, oz)
    local metal = modname .. ":scrap_metal"
    create_simple_building(ox, oz, 16, 10, 7, metal, "factory", true)
    create_simple_building(ox + 20, oz + 4, 12, 8, 6, modname .. ":rubble", "factory", true)
    fill_area({x = ox - 2, y = 2, z = oz - 2}, {x = ox + 34, y = 3, z = oz - 2}, metal)
    fill_area({x = ox - 2, y = 2, z = oz + 14}, {x = ox + 34, y = 3, z = oz + 14}, metal)
    fill_area({x = ox - 2, y = 2, z = oz - 2}, {x = ox - 2, y = 3, z = oz + 14}, metal)
    fill_area({x = ox + 34, y = 2, z = oz - 2}, {x = ox + 34, y = 3, z = oz + 14}, metal)
    fill_area({x = ox + 4, y = 2, z = oz + 12}, {x = ox + 6, y = 15, z = oz + 14}, modname .. ":rubble")
end

local function create_city_edge_features()
    create_rainforest_band()
    fill_area({x = -72, y = 1, z = -8}, {x = -56, y = 1, z = 8}, modname .. ":dry_grass")
    for x = -72, -56, 4 do
        fill_area({x = x, y = 1, z = -8}, {x = x, y = 1, z = 8}, modname .. ":rotted_wood")
    end
    create_simple_building(58, -56, 8, 7, 4, modname .. ":rubble", nil, true)
    create_simple_building(-70, 48, 7, 6, 3, modname .. ":rotted_wood", "residential", false)
end

local function create_scenic_landmark(ox, oz)
    local stone = modname .. ":bedrock"
    fill_area({x = ox - 4, y = 1, z = oz - 4}, {x = ox + 4, y = 1, z = oz + 4}, modname .. ":cracked_asphalt")
    for level = 0, 5 do
        local y = 2 + level * 2
        local radius = math.max(1, 4 - level)
        fill_area({x = ox - radius, y = y, z = oz - radius}, {x = ox + radius, y = y, z = oz + radius}, stone)
    end
    fill_area({x = ox - 1, y = 2, z = oz - 1}, {x = ox + 1, y = 13, z = oz + 1}, "air")
    fill_area({x = ox, y = 2, z = oz}, {x = ox, y = 14, z = oz}, modname .. ":scrap_metal")
    scatter_trees_on_scenic_hill(ox, oz)
    minetest.set_node({x = ox, y = 2, z = oz - 5}, {name = modname .. ":scenic_marker"})
end

local function create_resource_market(ox, oz)
    local shelf = modname .. ":rotted_wood"
    local floor = modname .. ":cracked_asphalt"
    fill_area({x = ox - 4, y = 1, z = oz - 3}, {x = ox + 4, y = 1, z = oz + 3}, floor)
    fill_area({x = ox - 4, y = 2, z = oz - 3}, {x = ox + 4, y = 2, z = oz - 3}, shelf)
    fill_area({x = ox - 4, y = 2, z = oz + 3}, {x = ox + 4, y = 2, z = oz + 3}, shelf)
    for x = ox - 4, ox + 4, 2 do
        minetest.set_node({x = x, y = 3, z = oz - 3}, {name = modname .. ":shelf_supply_food"})
        minetest.set_node({x = x, y = 3, z = oz + 3}, {name = modname .. ":shelf_supply_parts"})
    end
    minetest.set_node({x = ox - 3, y = 3, z = oz - 3}, {name = modname .. ":shelf_supply_food"})
    minetest.set_node({x = ox + 3, y = 3, z = oz + 3}, {name = modname .. ":shelf_supply_industrial"})
    minetest.set_node({x = ox - 2, y = 2, z = oz}, {name = modname .. ":loot_crate_residential"})
    minetest.set_node({x = ox, y = 2, z = oz}, {name = modname .. ":loot_crate_cbd"})
    minetest.set_node({x = ox + 2, y = 2, z = oz}, {name = modname .. ":loot_crate_factory"})
end

local function create_interactive_depot(ox, oz)
    local wall = modname .. ":scrap_metal"
    local floor = modname .. ":rubble"
    fill_area({x = ox - 1, y = 1, z = oz - 1}, {x = ox + 9, y = 7, z = oz + 8}, "air")
    fill_area({x = ox, y = 1, z = oz}, {x = ox + 8, y = 1, z = oz + 7}, floor)
    for y = 2, 5 do
        fill_area({x = ox, y = y, z = oz}, {x = ox + 8, y = y, z = oz}, wall)
        fill_area({x = ox, y = y, z = oz + 7}, {x = ox + 8, y = y, z = oz + 7}, wall)
        fill_area({x = ox, y = y, z = oz}, {x = ox, y = y, z = oz + 7}, wall)
        fill_area({x = ox + 8, y = y, z = oz}, {x = ox + 8, y = y, z = oz + 7}, wall)
    end
    fill_area({x = ox, y = 6, z = oz}, {x = ox + 8, y = 6, z = oz + 7}, wall)
    fill_area({x = ox + 3, y = 2, z = oz}, {x = ox + 5, y = 3, z = oz}, wall)
    minetest.set_node({x = ox + 4, y = 2, z = oz + 3}, {name = modname .. ":scene_terminal"})
    minetest.set_node({x = ox + 2, y = 2, z = oz + 5}, {name = modname .. ":workbench"})
end

local function create_scene_type_samples()
    create_scenic_landmark(0, -56)
    create_resource_market(56, -8)
    create_interactive_depot(-58, 44)
end

local function create_sample_city()
    create_plan_roads()
    create_plan_template_buildings()
    create_city_edge_features()
    create_city_canopy()
    create_starter_shelter(WF_STARTER_SHELTER_ORIGIN.x, WF_STARTER_SHELTER_ORIGIN.z)
    create_villager_hut(28, 52)

    create_villager_hut(50, -32)
    create_villager_hut(-62, 18)
    create_simple_building(50, 12, 10, 8, 5, modname .. ":rotted_wood", "residential", true)
    create_simple_building(-66, -52, 9, 7, 4, modname .. ":rotted_wood", "residential", true)

    create_factory_complex(-68, -28)
    create_factory_complex(44, 34)
    create_scene_type_samples()
end

local CITY_REBUILD_TOKEN = "spawn_near_shelter_2026_10_13_a"

local function rebuild_sample_city_area()
    for _, object in ipairs(minetest.get_objects_inside_radius({x = 0, y = 3, z = 0}, 140)) do
        local entity = object:get_luaentity()
        if entity and (
            entity.name == modname .. ":dog"
            or entity.name == modname .. ":rabbit"
            or entity.name == modname .. ":bear"
            or entity.name == modname .. ":builder_villager"
        ) then
            object:remove()
        end
    end

    fill_area({x = -80, y = 0, z = -80}, {x = 80, y = 36, z = 80}, "air")
    for x = -80, 80 do
        for z = -80, 80 do
            minetest.set_node({x = x, y = 0, z = z}, {name = modname .. ":dry_grass"})
        end
    end
    create_sample_city()
    scatter_debris({x = 0, y = 2, z = 0}, 18, 25)
    _wf_scatter_loose_hand_lamps(-76, 76, -76, 76, 24, 0.38)
    create_lamp_post(-8, -16)
    create_lamp_post(8, -2)
    create_lamp_post(-8, 13)
    create_lamp_post(8, 21)
    minetest.set_node({x = 0, y = 2, z = 12}, {name = modname .. ":task_board"})
    _wf_place_story_signs_in_chunk({x = -80, y = 0, z = -80}, {x = 80, y = 36, z = 80})
end

local spawn_creature_on_ground

local function load_creature_spawn_area(x, z, radius)
    if not minetest.load_area then
        return
    end
    radius = radius or 8
    minetest.load_area(
        {x = x - radius, y = -4, z = z - radius},
        {x = x + radius, y = 32, z = z + radius}
    )
end

function _wf_bear_spawn_positions()
    return {
        WF_BEAR_SPAWN_POINTS.west_factory,
        WF_BEAR_SPAWN_POINTS.east_factory,
        WF_BEAR_SPAWN_POINTS.edge_ruins,
    }
end

function _wf_prune_bears_near_spawn(spawn_pos, radius)
    load_creature_spawn_area(spawn_pos.x, spawn_pos.z, radius or 18)
    local search_pos = {x = spawn_pos.x, y = 3, z = spawn_pos.z}
    local bears = {}
    for _, object in ipairs(minetest.get_objects_inside_radius(search_pos, radius or 18)) do
        local entity = object:get_luaentity()
        if entity and entity.name == modname .. ":bear" then
            if entity.dead or (object:get_hp() and object:get_hp() <= 0) then
                object:remove()
            else
                table.insert(bears, {
                    object = object,
                    distance = vector.distance(search_pos, object:get_pos()),
                })
            end
        end
    end
    table.sort(bears, function(a, b)
        return a.distance < b.distance
    end)
    for index = 2, #bears do
        bears[index].object:remove()
    end
    return bears[1] and bears[1].object or nil
end

function _wf_ensure_single_bear_at_spawn(spawn_pos)
    if not spawn_creature_on_ground then
        return nil
    end
    local bear = _wf_prune_bears_near_spawn(spawn_pos, 36)
    if bear then
        local entity = bear:get_luaentity()
        if entity and not entity.dead then
            entity.healthbar_hp = entity.healthbar_hp or entity.max_hp or 30
            bear:set_hp(entity.healthbar_hp)
        end
        return bear
    end
    local spawned = spawn_creature_on_ground(spawn_pos.x, spawn_pos.z, "bear")
    if spawned then
        return spawned
    end
    return _wf_prune_bears_near_spawn(spawn_pos, 36)
end

ensure_villager_hut_near_spawn = function()
    if storage:get_string("city_rebuild_token") ~= CITY_REBUILD_TOKEN then
        rebuild_sample_city_area()
        storage:set_string("city_rebuild_token", CITY_REBUILD_TOKEN)
    end
    if spawn_creature_on_ground and not nearest_entity({x = 0, y = 3, z = 0}, "dog", 12) then
        spawn_creature_on_ground(2, 2, "dog")
    end
    if spawn_creature_on_ground and not nearest_entity({x = 0, y = 3, z = 0}, "rabbit", 12) then
        spawn_creature_on_ground(-2, 2, "rabbit")
        spawn_creature_on_ground(5, 1, "rabbit")
    end
    if spawn_creature_on_ground then
        for _, bear_pos in ipairs(_wf_bear_spawn_positions()) do
            local bear = _wf_ensure_single_bear_at_spawn(bear_pos)
            if bear then
                local bear_entity = bear:get_luaentity()
                local safe_pos = find_animal_open_position(bear:get_pos(), 1.7)
                if safe_pos and bear_entity then
                    bear:set_pos(safe_pos)
                end
            end
        end
    end
    if spawn_creature_on_ground and not nearest_entity({x = -54, y = 3, z = 58}, "builder_villager", 30) then
        spawn_creature_on_ground(-54, 58, "builder_villager")
    end
end

spawn_creature_on_ground = function(x, z, entity_name)
    load_creature_spawn_area(x, z, 12)
    local ground_y = find_ground_y({x = x, y = 8, z = z}) or 2
    local spawn_pos = {x = x, y = ground_y, z = z}
    local object = minetest.add_entity(spawn_pos, modname .. ":" .. entity_name)
    if object then
        return object
    end

    minetest.log("warning", "[wasteland_core] Deferred " .. entity_name .. " spawn at " .. minetest.pos_to_string(spawn_pos))
    minetest.after(0.2, function()
        load_creature_spawn_area(x, z, 12)
        local retry_ground_y = find_ground_y({x = x, y = 8, z = z}) or ground_y
        minetest.add_entity({x = x, y = retry_ground_y, z = z}, modname .. ":" .. entity_name)
    end)
    return nil
end

local function has_creature_near_spawn(entity_name)
    for _, object in ipairs(minetest.get_objects_inside_radius({x = 0, y = 3, z = 0}, 4)) do
        local entity = object:get_luaentity()
        if entity and entity.name == modname .. ":" .. entity_name then
            return true
        end
    end
    return false
end

ensure_creatures_near_spawn = function()
    if not has_creature_near_spawn("dog") then
        spawn_creature_on_ground(2, 2, "dog")
    end
    if not has_creature_near_spawn("rabbit") then
        spawn_creature_on_ground(-2, 2, "rabbit")
    end
end

local function spawn_default_creatures()
    spawn_creature_on_ground(2, 2, "dog")
    spawn_creature_on_ground(-2, 2, "rabbit")
    spawn_creature_on_ground(-2, -7, "rabbit")
    spawn_creature_on_ground(5, 1, "rabbit")
    spawn_creature_on_ground(-54, 58, "builder_villager")
    if math.random() < 0.65 then
        _wf_ensure_single_bear_at_spawn(WF_BEAR_SPAWN_POINTS.west_factory)
    end
    if math.random() < 0.65 then
        _wf_ensure_single_bear_at_spawn(WF_BEAR_SPAWN_POINTS.east_factory)
    end
    _wf_ensure_single_bear_at_spawn(WF_BEAR_SPAWN_POINTS.edge_ruins)
end

local function remove_default_creatures()
    for _, object in ipairs(minetest.get_objects_inside_radius({x = 0, y = 3, z = 0}, 130)) do
        local entity = object:get_luaentity()
        if entity and (
            entity.name == modname .. ":dog"
            or entity.name == modname .. ":rabbit"
            or entity.name == modname .. ":bear"
            or entity.name == modname .. ":builder_villager"
        ) then
            object:remove()
        end
    end
end

local function reset_center_area()
    rebuild_sample_city_area()
end

minetest.register_on_generated(function(minp, maxp)
    if maxp.y < 0 or minp.y > 24 then
        return
    end
    local chunk_has_forest = false
    local chunk_has_cloud = false
    for x = minp.x, maxp.x do
        for z = minp.z, maxp.z do
            minetest.set_node({x = x, y = 0, z = z}, {name = modname .. ":dry_grass"})
            local dist = world_span_distance(x, z)
            if dist <= CITY_RADIUS then
                if math.abs(x) <= 5 then
                    minetest.set_node({x = x, y = 1, z = z}, {name = modname .. ":cracked_asphalt"})
                end
            elseif dist <= FOREST_RADIUS then
                chunk_has_forest = true
                minetest.set_node({x = x, y = 1, z = z}, {name = modname .. ":dry_grass"})
            end
            if dist <= CLOUD_RADIUS then
                chunk_has_cloud = true
            end
            if dist > FOREST_RADIUS and dist <= ESCAPE_RADIUS then
                minetest.set_node({x = x, y = 1, z = z}, {name = modname .. ":cracked_asphalt"})
            end
        end
    end
    if storage:get_string("center_area_ready") ~= "true" and minp.x <= 0 and maxp.x >= 0 and minp.z <= 0 and maxp.z >= 0 then
        storage:set_string("center_area_ready", "true")
        reset_center_area()
    end

    if chunk_has_forest then
        create_forest_chunk(minp.x, maxp.x, minp.z, maxp.z)
        scatter_forest_glow_fungus(minp.x, maxp.x, minp.z, maxp.z)
        _wf_scatter_loose_hand_lamps(minp.x, maxp.x, minp.z, maxp.z, 3, 0.12)
    end

    if chunk_has_cloud then
        create_cloud_chunk(minp.x, maxp.x, minp.z, maxp.z)
    end
    _wf_place_story_signs_in_chunk(minp, maxp)

    if storage:get_string("spawned_creatures") ~= "true" and minp.x <= 0 and maxp.x >= 0 and minp.z <= 0 and maxp.z >= 0 then
        storage:set_string("spawned_creatures", "true")
        minetest.after(1, spawn_default_creatures)
    end
end)

minetest.register_chatcommand("wf_reset", {
    description = "Reset the central wasteland district and respawn creatures.",
    privs = {server = true},
    func = function(name)
        remove_default_creatures()
        reset_center_area()
        spawn_default_creatures()
        storage:set_string("center_area_ready", "true")
        storage:set_string("spawned_creatures", "true")
        minetest.chat_send_player(name, "Wasteland center area reset.")
        return true
    end,
})

minetest.register_chatcommand("wf_creatures", {
    description = "Respawn dog, rabbits, bear, and builder villager near the central street.",
    privs = {server = true},
    func = function(name)
        remove_default_creatures()
        spawn_default_creatures()
        storage:set_string("spawned_creatures", "true")
        minetest.chat_send_player(name, "Wasteland creatures respawned.")
        return true
    end,
})

minetest.register_chatcommand("wf_bears", {
    description = "Ensure bear spawn points and report current bear positions.",
    func = function(name)
        local sites = {
            {label = "West Factory", pos = WF_BEAR_SPAWN_POINTS.west_factory},
            {label = "East Factory", pos = WF_BEAR_SPAWN_POINTS.east_factory},
            {label = "Edge Ruins", pos = WF_BEAR_SPAWN_POINTS.edge_ruins},
        }
        for _, site in ipairs(sites) do
            local bear = _wf_ensure_single_bear_at_spawn(site.pos)
            local bear_pos = bear and bear:get_pos()
            if bear_pos then
                minetest.chat_send_player(name, site.label .. " bear ready at X " .. math.floor(bear_pos.x + 0.5) .. " Y " .. math.floor(bear_pos.y + 0.5) .. " Z " .. math.floor(bear_pos.z + 0.5) .. ".")
            else
                minetest.chat_send_player(name, site.label .. " bear spawn queued near X " .. site.pos.x .. " Z " .. site.pos.z .. ".")
            end
        end
        return true
    end,
})

minetest.register_chatcommand("wf_escape_route", {
    description = "Repair the permanent south escape route and guide signs.",
    func = function(name)
        if _wf_ensure_story_escape_route then
            _wf_ensure_story_escape_route(true)
            minetest.chat_send_player(name, "South escape route repaired.")
        end
        return true
    end,
})

minetest.register_chatcommand("wf_new_start", {
    description = "Clear your inventory, reset quest progress, and rebuild the starter area.",
    privs = {server = true},
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if not player then
            return false, "Player not found."
        end

        local inv = player:get_inventory()
        for index = 1, inv:get_size("main") do
            inv:set_stack("main", index, ItemStack(""))
        end

        local meta = player:get_meta()
        meta:set_string("wf_current_quest", "")
        meta:set_string("wf_main_story_done", "")
        meta:set_string("wf_escape_won", "")
        meta:set_string("wf_wearing_raincoat", "")
        meta:set_string("wf_charging_weapon", "")
        meta:set_float("wf_charge_started", 0)
        meta:set_float("wf_escape_locked_notice_at", 0)
        for _, quest_id in ipairs(QUEST_ORDER) do
            local quest = QUESTS[quest_id]
            meta:set_string("wf_completed_" .. quest_id, "")
            if quest.event then
                meta:set_int("wf_event_" .. quest.event, 0)
            end
        end

        remove_default_creatures()
        reset_center_area()
        spawn_default_creatures()
        storage:set_string("center_area_ready", "true")
        storage:set_string("spawned_creatures", "true")
        storage:set_string("city_rebuild_token", CITY_REBUILD_TOKEN)

        player:set_hp(20)
        player:set_pos(WF_PLAYER_SPAWN_POS)
        update_selected_item_hud(player)
        update_hotbar_name_hud(player)
        update_player_hp_hud(player)
        update_charge_hud(player)
        update_quest_hud(player)
        minetest.chat_send_player(name, "New start ready. Find the shelter, open the starter crate, and follow the task board.")
        return true
    end,
})

minetest.register_chatcommand("new_start", {
    description = "Start a fresh run by rebuilding the starter area and resetting your progress.",
    func = function(name)
        local command = minetest.registered_chatcommands["wf_new_start"]
        if command and command.func then
            return command.func(name)
        end
        return false, "New start command is unavailable."
    end,
})
