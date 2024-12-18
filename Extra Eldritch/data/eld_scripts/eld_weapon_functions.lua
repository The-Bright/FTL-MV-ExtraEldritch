mods.eld = {}

--Geisel beam fake thickness credit: Choosechee
local beamDamageMods = mods.multiverse.beamDamageMods
beamDamageMods["BEAM_MADNESS_BIG"] = {iDamage = 0}

mods.eld.riftWeapons = {}
local riftWeapons = mods.eld.riftWeapons
mods.eld.riftProjectileDelay = {}
local riftProjectileDelay = mods.eld.riftProjectileDelay
mods.eld.riftProjectileDistance = {}
local riftProjectileDistance = mods.eld.riftProjectileDistance
mods.eld.riftProjectileIon = {}
local riftProjectileIon= mods.eld.riftProjectileIon

local Brightness = mods.brightness

riftWeapons["BOMB_RIFT"] = 8
--riftWeapons actually refers to the number of teleports afflicted crew will do

riftWeapons["MISSILES_RIFT"] = 3
riftProjectileDelay["MISSILES_RIFT"] = 0.33
riftProjectileDistance["MISSILES_RIFT"] = 120

-- Find ID of a room at the given location
local function get_room_at_location(shipManager, location, includeWalls)
    return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end

local function vter(cvec)
    local i = -1
    local n = cvec:size()
    return function()
        i = i + 1
        if i < n then return cvec[i] end
    end
end

-- Modified from Arc's get_ship_crew_room(). Determines the crew of either team in a room.
local function get_crew_room(shipManager, roomId)
    local crewList = {}
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.iRoomId == roomId then
            table.insert(crewList, crewmem)
        end
    end
    return crewList
end

local function userdata_table(userdata, tableName)
    if not userdata.table[tableName] then userdata.table[tableName] = {} end
    return userdata.table[tableName]
end

local function get_distance(point1, point2)
    return math.sqrt((point2.x - point1.x)^2+(point2.y - point1.y)^2)
end

local function game_is_paused()
    local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
    if commandGui.bPaused or commandGui.bAutoPaused or commandGui.event_pause or commandGui.menu_pause then
        return true
    else
        return false
    end
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

local function create_rift_particle_trail(point1, point2, space)
    local i = 0
    while i < get_distance(point1, point2) do
        local spriteSheetIndex = 0
        if math.random(10) ~= 1 then --rift_trail_0 is relatively large, so this makes it less common on the trail
            spriteSheetIndex = math.random(2)
        end
        local offsetX = math.random(-5,5)
        local offsetY = math.random(-5,5) --offsets the particle in a random direction
        local p = Brightness.create_particle(
            "particles/rift_trail_" .. tostring(spriteSheetIndex),
            9,
            0.4,
            get_point_local_offset(Hyperspace.Pointf(point1.x + offsetX, point1.y + offsetY), Hyperspace.Pointf(point2.x + offsetX, point2.y + offsetY), i, 0),
            math.random(360),
            space,
            "SHIP"
        )
        p.imageSpin = math.random(-270,270)
        i = i + math.random(5,10) --can be adjusted to change the spacing between particles
    end
end

local function start_rift_crew_teleports(crewmem, riftJumps)
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(crewmem.currentShipId)
    local randomRoom = get_room_at_location(shipManager, shipManager:GetRandomRoomCenter(), false)
    crewmem.extend:InitiateTeleport(shipManager.iShipId, randomRoom, 0)
    local teleTable = userdata_table(crewmem, "mods.eld.tptime")
    teleTable.initTpTime = 1
    teleTable.tpTime = 1
    teleTable.tpNum = riftJumps - 1
    teleTable.riftTrailQueued = true
    teleTable.previousRiftPosition = Hyperspace.Pointf(crewmem.x, crewmem.y)
end

--[[
Allows non-beam rift weapons to force affected crew to teleport randomly
]]

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    --Initial Rift crew teleportation (room hit)
    pcall(function() riftJumps = riftWeapons[projectile.extend.name] end)
    if riftJumps then
        local targetRoom = get_room_at_location(shipManager, location, true)
        for i, crewmem in ipairs(get_crew_room(shipManager, targetRoom)) do
            start_rift_crew_teleports(crewmem, riftJumps)
        end
        riftJumps = nil
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION_PRE, function(shipManager, projectile, damage, collisionResponse)
    --Initial Rift crew teleportation (ion to shield hit)
    pcall(function() riftJumps = riftWeapons[projectile.extend.name] end)
    pcall(function() isIon = riftProjectileIon[projectile.extend.name] end)
    if riftJumps and isIon then
        for i, crewmem in ipairs(get_crew_room(shipManager, shipManager:GetSystemRoom(0))) do
            start_rift_crew_teleports(crewmem, riftJumps)
        end
        riftJumps = nil
    end
end)

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
    --Persisting Rift crew teleportation
    local teleTable = userdata_table(crewmem, "mods.eld.tptime")
    if teleTable.riftTrailQueued and (teleTable.previousRiftPosition.x ~= crewmem.x or teleTable.previousRiftPosition.y ~= crewmem.y) then
        create_rift_particle_trail(Hyperspace.Pointf(crewmem.x, crewmem.y), teleTable.previousRiftPosition, crewmem.currentShipId)
        teleTable.riftTrailQueued = false
    end
    if teleTable.tpNum and teleTable.initTpTime and teleTable.tpTime > 0 then
        local shipManager = Hyperspace.Global.GetInstance():GetShipManager(crewmem.currentShipId)
        if not game_is_paused() then
            teleTable.tpTime = math.max(teleTable.tpTime - Hyperspace.FPS.SpeedFactor/16, 0)
            if teleTable.tpTime == 0 then
                local randomRoom = get_room_at_location(shipManager, shipManager:GetRandomRoomCenter(), false)
                crewmem.extend:InitiateTeleport(shipManager.iShipId, randomRoom, 0)
                teleTable.riftTrailQueued = true
                teleTable.previousRiftPosition = Hyperspace.Pointf(crewmem.x, crewmem.y)
                --Hyperspace.Global.GetInstance():GetSoundControl():PlaySoundMix("rift_sound_1", -1, false)
                teleTable.tpNum = teleTable.tpNum - 1
                if teleTable.tpNum > 0 then
                    teleTable.tpTime = teleTable.initTpTime
                else
                    teleTable.initTpTime = 0
                end
            end
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_UPDATE_PRE, function(projectile)
    if projectile.ownerId == 0 and Hyperspace.Global.GetInstance():GetShipManager(1) and not(Hyperspace.Global.GetInstance():GetShipManager(1)._targetable.hostile) then return end --checks if combat has stopped
    --Rift projectile teleportation loop code
    local rDelay = nil
    pcall(function() rDelay = riftProjectileDelay[projectile.extend.name] end)
    local rDistance = nil
    pcall(function() rDistance = riftProjectileDistance[projectile.extend.name] end)
    if rDelay and rDistance then
        local projectileTable = userdata_table(projectile, "mods.eld.riftProjectile")
        if projectileTable.spaceLastTick and projectile.currentSpace ~= projectileTable.spaceLastTick then
            projectileTable.spaceEntryPoint = Hyperspace.Pointf(projectile.position.x, projectile.position.y)
            if rDistance <= 0 then
                projectileTable.delay = math.abs(rDistance) / (math.sqrt(projectile.speed.x^2 + projectile.speed.y^2) * 16)
            end
        elseif projectileTable.delay then
            projectileTable.delay = math.max(projectileTable.delay - Hyperspace.FPS.SpeedFactor/16, 0)
            if projectileTable.delay == 0 then
                projectileTable.delay = rDelay
                --checks if the projectile would teleport past its target
                if get_distance(projectile.position, projectile.target) <= math.abs(rDistance) then return end
                --checks if the projectile has passed its target due to a miss
                if projectileTable.spaceEntryPoint and get_distance(projectileTable.spaceEntryPoint, projectile.target) < get_distance(projectileTable.spaceEntryPoint, projectile.position) then return end
                --Hyperspace.Sounds:PlaySoundMix("projectile_teleport", -1, true)
                oldPosition = Hyperspace.Pointf(projectile.position.x, projectile.position.y)
                if projectile.currentSpace == 1 then
                    projectile.position = get_point_local_offset(projectile.position, projectile.target, rDistance, 0)
                else
                    projectile.position = Hyperspace.Pointf(projectile.position.x + rDistance, projectile.position.y)
                end
                if projectileTable.spaceLastTick and projectile.currentSpace == projectileTable.spaceLastTick then
                    create_rift_particle_trail(projectile.position, oldPosition, projectile.currentSpace)
                end
            end
        else
            projectileTable.delay = rDelay
        end
        projectileTable.spaceLastTick = projectile.currentSpace
    end
end)

--Entropy beams
--These beams have a damage stat that they can deal more than once per tile depending on RNG. 
mods.eld.entropyWeapons = {}
local entropyWeapons = mods.eld.entropyWeapons
entropyWeapons["BEAM_ENTROPY_FIRE"] = {gimmick = "FIRE", percentChance = 25, damage = 1}
entropyWeapons["BEAM_ENTROPY_HULL"] = {gimmick = "HULL", percentChance = 25, damage = 1}

local farPoint = Hyperspace.Pointf(-2147483648, -2147483648)
script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    --Credit to the TRC devs for laying the groundwork for tile-damage beams
    if Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, false) > -1 then
        local tileDamage = nil
        pcall(function() tileDamage = entropyWeapons[Hyperspace.Get_Projectile_Extend(projectile).name] end)
        if tileDamage and beamHitType ~= Defines.BeamHit.SAME_TILE then
            local rolls = 0
            local damageHS = Hyperspace.Damage()
            local ownerShip = Hyperspace.Global.GetInstance():GetShipManager(projectile.ownerId)
            if tileDamage.gimmick == "FIRE" then
                local totalFires = 0
                for room in vter(ownerShip.ship.vRoomList) do
                    totalFires = totalFires + ownerShip:GetFireCount(room.iRoomId)
                end
                rolls = math.ceil(totalFires / 4) + 1
            elseif tileDamage.gimmick == "HULL" then
                rolls = (ownerShip.ship.hullIntegrity.second - ownerShip.ship.hullIntegrity.first) / 4
            end
            local i = 0
            while i < rolls do
                if math.random(100) <= tileDamage.percentChance then
                    damageHS.iDamage = damageHS.iDamage + tileDamage.damage
                end
                i = i + 1
            end
            local weaponName = Hyperspace.Get_Projectile_Extend(projectile).name
            Hyperspace.Get_Projectile_Extend(projectile).name = ""
            shipManager:DamageBeam(location, farPoint, damageHS)
            Hyperspace.Get_Projectile_Extend(projectile).name = weaponName
        end
    end
    return Defines.Chain.CONTINUE, beamHitType
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, projectileFactory)
    pcall(function() entropyBeam = entropyWeapons[projectile.extend.name] end)
    if entropyBeam then
        local ownerShip = Hyperspace.Global.GetInstance():GetShipManager(projectile.ownerId)
        if entropyBeam.gimmick == "FIRE" then
            --[[ Couldn't get this to work; was supposed to extinguish some of the fires
            local FireManager = ownerShip.fireSpreader
            FireManager.count = 0
            for fire_vector in vter(FireManager.grid) do
                fire_vector:clear()
            end
            --]]
            for room in vter(ownerShip.ship.vRoomList) do
                if ownerShip:GetFireCount(room.iRoomId) > 0 then
                    local startPoint = ownerShip:GetRoomCenter(room.iRoomId)
                    local targetPoint = Brightness.point_on_weapon_sprite(projectileFactory, 29, 44)
                    local i = 0
                    while i < get_distance(startPoint, targetPoint) + 20 do
                        local p = Brightness.create_particle(
                            "particles/fire_trail_0",
                            9,
                            0.5,
                            Brightness.random_offset_in_radius(get_point_local_offset(startPoint, targetPoint, i, 0), 15),
                            0,
                            projectile.ownerId,
                            "SHIP"
                        )
                        p.scale = 1 + math.random(-30,30)/100
                        p.countdown = i / 400
                        p.heading = math.random(-25,25)
                        p.movementSpeed = 30
                        i = i + 8
                    end
                end
            end
        elseif entropyBeam.gimmick == "HULL" then
            local i = 0
            while i < (ownerShip.ship.hullIntegrity.second - ownerShip.ship.hullIntegrity.first) do
                local entropyParticle = Brightness.create_particle(
                    "particles/entropy_particle_0",
                    8,
                    math.random(85,115)/100,
                    Brightness.random_offset_in_radius(ownerShip:GetRandomRoomCenter(), 50),
                    0,
                    projectile.ownerId,
                    "SHIP"
                )
                entropyParticle.countdown = math.random(85,115)/100
                entropyParticle.movementSpeed = 15
                i = i + 1
            end
        end
    end
end)