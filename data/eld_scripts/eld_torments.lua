local userdata_table = mods.multiverse.userdata_table
local vter = mods.multiverse.vter
local Brightness = mods.brightness

mods.eld.tormentProjectors = {}
local projectors = mods.eld.tormentProjectors
projectors["TORMENT_FROST"] = true

mods.eld.tormentList = {}
local tormentList = mods.eld.tormentList

mods.eld.tormentBlueprints = {}
local tormentBlueprints = mods.eld.tormentBlueprints

--tormentBlueprints["TORMENT_<NAME>"] = {
--    speed          = 0,                               --pixels per second
--    shots          = 4,                               --shots per attack
--    spawnThreshold = 0,                               --how much the projector needs to charge before it spawns (scale 0-1)
--    mainAnim       = {duration = 0, frames = 0},      --main animation
--    spawnAnim      = {duration = 0, frames = 0},      --spawning animation
--    dissipateAnim  = {duration = 0, frames = 0},      --de-power animation
--    detonateAnim   = {duration = 0, frames = 0},      --detonate animation
--    explosion      = {sysDamage = 0, hullDamage = 0}, --detonation stats
--    hasEye         = false                            --indicates whether to include an eye particle
--}

tormentBlueprints["TORMENT_FROST"] = { --accessed with torment.bp
    speed          = 70,
    spawnThreshold = 0.3, --0.16,
    mainAnim       = {duration = 1, frames = 8},
    spawnAnim      = {duration = 0.8, frames = 8},
    dissipateAnim  = {duration = 2, frames = 9},
    detonateAnim   = {duration = 2, frames = 9},
    explosion      = {sysDamage = 3, hullDamage = 0, ionDamage = 0},
    weaponPointX   = 27,
    weaponPointY   = 5,
    hasEye         = false
}

local function game_is_paused()
    local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
    if commandGui.bPaused or commandGui.bAutoPaused or commandGui.event_pause or commandGui.menu_pause then
        return true
    else
        return false
    end
end

local function random_room_offset(shipManager)
    return Brightness.random_offset_in_radius(shipManager:GetRandomRoomCenter(), 50)
end

local function calculate_heading(pointA, target)
    local heading = math.deg(math.atan((pointA.y - target.y),
        (pointA.x - target.x))) - 90
    if heading < 0 then
        heading = 360 + heading
    end
    if heading > 360 then
        heading = heading % 360
    end
    return heading
end

local function get_distance(point1, point2)
    return math.sqrt((point2.x - point1.x)^2+(point2.y - point1.y)^2)
end

local function closest_room(point, iShipId)
    local closest = -1
    local shipGraph = Hyperspace.ShipGraph.GetShipInfo(iShipId)
    for room in vter(Hyperspace.ships(iShipId).ship.vRoomList) do
        if closest == -1 or get_distance(shipGraph:GetRoomCenter(room.iRoomId), point) < get_distance(shipGraph:GetRoomCenter(closest), point) then
            closest = room.iRoomId
        end
    end
    return closest
end

--Credit: Arc
local function get_point_local_offset(original, target, offsetForwards, offsetRight)
    local alpha = math.atan((original.y-target.y), (original.x-target.x))
    --print(alpha)
    local newX = original.x - (offsetForwards * math.cos(alpha)) - (offsetRight * math.cos(alpha+math.rad(90)))
    --print(newX)
    local newY = original.y - (offsetForwards * math.sin(alpha)) - (offsetRight * math.sin(alpha+math.rad(90)))
    --print(newY)
    return Hyperspace.Pointf(newX, newY)
end

local function random_roomId(shipManager)
    local randomRoomCenter = shipManager:GetRandomRoomCenter()
    return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(randomRoomCenter.x, randomRoomCenter.y, true)
end

--                                   Stolen from TRC :3
-- Returns a table where the indices are the IDs of all rooms adjacent to the given room
-- and the values are the rooms' coordinates
local function get_adjacent_rooms(shipId, roomId, diagonals)
    local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipId)
    local roomShape = shipGraph:GetRoomShape(roomId)
    local adjacentRooms = {}
    local currentRoom = nil
    local function check_for_room(x, y)
        currentRoom = shipGraph:GetSelectedRoom(x, y, false)
        if currentRoom > -1 and not adjacentRooms[currentRoom] then
            adjacentRooms[currentRoom] = Hyperspace.Pointf(x, y)
        end
    end
    for offset = 0, roomShape.w - 35, 35 do
        check_for_room(roomShape.x + offset + 17, roomShape.y - 17)
        check_for_room(roomShape.x + offset + 17, roomShape.y + roomShape.h + 17)
    end
    for offset = 0, roomShape.h - 35, 35 do
        check_for_room(roomShape.x - 17,               roomShape.y + offset + 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + offset + 17)
    end
    if diagonals then
        check_for_room(roomShape.x - 17,               roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + roomShape.h + 17)
        check_for_room(roomShape.x - 17,               roomShape.y + roomShape.h + 17)
    end
    return adjacentRooms
end

local function light_flash(torment, location, iShipId)
    local p = Brightness.create_particle(
        "particles/"..torment.type.."_SUMMON",
        7,
        0.8,
        location,
        0,
        iShipId,
        "SHIP"
    )
    p.imageSpin = 20
    Brightness.send_to_front(p)
    return p
end

local function spawn_torment(name, location, space, projectileFactory)
    local newTorment = {
        type      = name,
        bp        = tormentBlueprints[name],
        iShipId   = space,
        projector = projectileFactory,
        target    = random_room_offset(Hyperspace.ships(space)),
        indexNum  = #tormentList + 1,
        detonating = false,
        targetRoomId = random_roomId(Hyperspace.ships(space)),
        mover = Brightness.create_particle( --invisible, used to move the torment in a fairly linear manner
            " ",
            1,
            1,
            location,
            0,
            space,
            "SHIP"
        ),
        body = Brightness.create_particle( --bobs up and down on the mover particle as the wings flap. Makes movement more natural
            "particles/"..name.."_BODY",
            tormentBlueprints[name].mainAnim.frames,
            tormentBlueprints[name].mainAnim.duration,
            location,
            0,
            space,
            "SHIP"
        )
    }
    newTorment.mover.countdown = newTorment.bp.spawnAnim.duration / 2
    newTorment.body.countdown  = newTorment.bp.spawnAnim.duration / 2
    newTorment.mover.persists  = true
    newTorment.body.persists   = true
    newTorment.mover.heading   = calculate_heading(newTorment.mover.position, newTorment.target)
    newTorment.mover.movementSpeed = newTorment.bp.speed

    if newTorment.bp.hasEye then
        newTorment.eye = Brightness.create_particle( --"looks" toward the targetted room from the center of the body particle
            "particles/"..name.."_EYE",
            1,
            1,
            location,
            0,
            space,
            "SHIP"
        )
        newTorment.eye.countdown = newTorment.bp.spawnAnim.duration / 2
        newTorment.eye.persists  = true
    end

    light_flash(newTorment, location, space)

    newTorment.orb = light_flash(newTorment, Brightness.point_on_weapon_sprite(projectileFactory, newTorment.bp.weaponPointX, newTorment.bp.weaponPointY), 1 - space)
    newTorment.orb.pauseOnFrame = 4

    tormentList[#tormentList + 1] = newTorment
    userdata_table(projectileFactory, "mods.eld.torments").torment = newTorment
end

--for when the weapon de-powers
local function dissipate_torment(torment)
    if Hyperspace.ships.enemy then
        light_flash(torment, torment.body.position, torment.iShipId)
    end
    torment.orb.pauseOnFrame = nil
    torment.orb.paused = false
    Brightness.destroy_particle(torment.mover)
    Brightness.destroy_particle(torment.body)
    if torment.eye then Brightness.destroy_particle(torment.eye) end
    userdata_table(torment.projector, "mods.eld.torments").torment = nil
    table.remove(tormentList, torment.indexNum)
    local i = torment.indexNum
    while i <= #tormentList do
        tormentList[i].indexNum = tormentList[i].indexNum - 1
        i = i + 1
    end
end

local function detonate_torment(torment)
    local shipManager = Hyperspace.ships(torment.iShipId)
    local roomId = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(torment.mover.position.x, torment.mover.position.y, true)
    if roomId == -1 then
        roomId = closest_room(torment.mover.position, torment.iShipId)
    end

    local damage         = Hyperspace.Damage()
    damage.iDamage       = torment.bp.explosion.hullDamage
    damage.iSystemDamage = torment.bp.explosion.sysDamage
    damage.iIonDamage    = torment.bp.explosion.ionDamage
    shipManager:DamageArea(shipManager:GetRoomCenter(roomId), damage, false) --                              FIX: can currently miss -_-

    if torment.type == "TORMENT_FROST" then
        for i, _ in pairs(get_adjacent_rooms(torment.iShipId, roomId, false)) do
            shipManager.ship:LockdownRoom(i, torment.body.position)
        end

        --FIX: Include speed = 0 debuffs on all crew at the affected room
    end

    light_flash(torment, torment.body.position, torment.iShipId)

    Brightness.destroy_particle(torment.mover)
    Brightness.destroy_particle(torment.body)
    if torment.eye then Brightness.destroy_particle(torment.eye) end
    userdata_table(torment.projector, "mods.eld.torments").torment = nil
    table.remove(tormentList, torment.indexNum)
    local i = torment.indexNum
    while i <= #tormentList do
        tormentList[i].indexNum = tormentList[i].indexNum - 1
        i = i + 1
    end
end

--Check to spawn new torments, update current torments
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    --check to spawn new torments
    for weapon in vter(shipManager:GetWeaponList()) do
        if projectors[weapon.blueprint.name] then
            local weaponTable = userdata_table(weapon, "mods.eld.torments")
            
            --spawn a torment and create the weapon's indicator orb
            if not(weaponTable.torment) and weapon.powered and
            not(game_is_paused()) and Hyperspace.ships.enemy and Hyperspace.ships.enemy._targetable.hostile and
            weapon.cooldown.first/weapon.cooldown.second > tormentBlueprints[weapon.blueprint.name].spawnThreshold then
                --print("Created a Torment")
                spawn_torment(weapon.blueprint.name, random_room_offset(shipManager), 1-shipManager.iShipId, weapon)
                
            elseif weaponTable.torment then
                --dissipate (not detonate) torments if the weapon depowers or combat stops
                if (not(weapon.powered) or not(Hyperspace.ships.enemy and Hyperspace.ships.enemy._targetable.hostile)) then
                    --print("Dissipated a Torment")
                    dissipate_torment(weaponTable.torment)

                --if the projector is wielded by a player, update the orb's position in case they change weapon slots
                elseif shipManager.iShipId == 0 then
                    weaponTable.torment.orb.position =
                        Brightness.point_on_weapon_sprite(weapon, weaponTable.torment.bp.weaponPointX, weaponTable.torment.bp.weaponPointY)
                end

            end
        end
    end

    --update current torments
    local i = 1
    while i <= #tormentList do
        local torment = tormentList[i]
        local shipManager = Hyperspace.ships(torment.iShipId)

        --this rather weird calculation allows the body particle to bob up and down around the mover particle
        torment.body.position = Hyperspace.Pointf(torment.mover.position.x,
            torment.mover.position.y + 12 * math.cos(math.pi * 2 * (torment.body.remainingDuration / torment.body.lifetime)))

        --update torment eye position
        if torment.eye then torment.eye.position = get_point_local_offset(torment.body.position, shipManager:GetRoomCenter(torment.targetRoomId), 1.5, 0) end

        --rotate the orb. I handle this here as well since we still want to rotate it when it's paused
        if torment.orb and torment.orb.paused then
            torment.orb.rotation = (torment.orb.rotation + torment.orb.imageSpin * Hyperspace.FPS.SpeedFactor/16) % 360
        end

        --shoot or detonate if near enough to target point
        if get_distance(torment.mover.position, torment.target) < 5 then
            if torment.detonating then
                detonate_torment(torment)
            else
                --shot effects differ with each torment
                if torment.type == "TORMENT_FROST" then
                    shipManager.ship:LockdownRoom(torment.targetRoomId, torment.body.position)
                end
                torment.target = random_room_offset(shipManager)  --refers to the point it is flying toward
                torment.targetRoomId = random_roomId(shipManager) --refers to the room that it will shoot at upon arriving at target
            end

        --otherwise, update heading. Credit to Lizzard for help with this part
        else
            local idealHeading = calculate_heading(torment.mover.position, torment.target)
            torment.mover.heading = torment.mover.heading % 360
            idealHeading = idealHeading % 360
            local sad = idealHeading - torment.mover.heading
            if sad < -180 then
                sad = sad + 360
            elseif sad > 180 then
                sad = sad - 360
            end
            if math.abs(sad) < 2 then
                torment.mover.headingSpin = 0
                torment.mover.heading = idealHeading
            elseif sad < 0 then
                torment.mover.headingSpin = math.min(torment.mover.headingSpin - 80*Hyperspace.FPS.SpeedFactor/16, 0)
            else
                torment.mover.headingSpin = math.max(torment.mover.headingSpin + 80*Hyperspace.FPS.SpeedFactor/16, 0)
            end
        end
        i = i + 1
    end
end)

--Handle the firing of a torment projector
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, projectileFactory)
    local projector = nil
    pcall(function() projector = projectors[projectile.extend.name] end)
    if projector then
        local shipManager = Hyperspace.ships(projectile.destinationSpace)
        local TTarget = Hyperspace.Pointf(projectile.target.x, projectile.target.y)
        projectile:Kill()
        local wepTorment = userdata_table(projectileFactory, "mods.eld.torments").torment
        if wepTorment then
            wepTorment.target = TTarget
            wepTorment.detonating = true
            if wepTorment.orb then
                wepTorment.orb.pauseOnFrame = nil
                wepTorment.orb.paused = false
            end
        end
    end
end)