----------------------------------------
--   Brightness Particle System 1.4   --
--                                    --
-- Created by Brightlord and Lizzard  --
--   with generous input from         --
--   Chrono Vortex, Arc, Julk,        --
--   Gabriel Cooper, Choosechee, and  --
--   Pepson                           --
----------------------------------------

mods.brightness = {}

mods.brightness.particleList = {}
local particleList = mods.brightness.particleList
mods.brightness.primitiveList = {}
local primitiveList = mods.brightness.primitiveList

local Brightness = mods.brightness

---------------------------------------------------------------------------------------------
-- The following functions can be called in your Lua scripts to use Brightness' particles. --
-- Be sure to write the following line at the top of your relevant Lua file:               --
--                                                                                         --
-- "local Brightness = mods.brightness"                                                    --
--                                                                                         --
-- You can then call any non-local function here                                           --
-- e.g. "local myParticle = Brightness.create_particle()"                                  --
---------------------------------------------------------------------------------------------

--------------------------------
--  Supported render layers:  --
-- MAIN_MENU_PRE              --
-- MAIN_MENU                  --
-- GUI_CONTAINER_PRE          --
-- GUI_CONTAINER              --
-- LAYER_BACKGROUND_PRE       --
-- LAYER_BACKGROUND           --
-- LAYER_FOREGROUND_PRE       --
-- LAYER_FOREGROUND           --
-- LAYER_ASTEROIDS_PRE        --
-- LAYER_ASTEROIDS            --
-- LAYER_PLAYER_PRE           --
-- LAYER_PLAYER               --
-- SHIP_PRE                   --
-- SHIP                       --
-- SHIP_MANAGER_PRE           --
-- SHIP_MANAGER               --
-- SHIP_JUMP_PRE              --
-- SHIP_JUMP                  --
-- SHIP_HULL_PRE              --
-- SHIP_HULL                  --
-- SHIP_ENGINES_PRE           --
-- SHIP_ENGINES               --
-- SHIP_FLOOR_PRE             --
-- SHIP_FLOOR                 --
-- SHIP_BREACHES_PRE          --
-- SHIP_BREACHES              --
-- SHIP_SPARKS_PRE            --
-- SHIP_SPARKS                --
-- LAYER_FRONT_PRE            --
-- LAYER_FRONT                --
-- SPACE_STATUS_PRE           --
-- SPACE_STATUS               --
-- MOUSE_CONTROL_PRE          --
-- MOUSE_CONTROL              --
--------------------------------

--This is how you create new particles (who knew?). The function will return the particle itself, so
--you can alter its attributes post-creation.
function mods.brightness.create_particle(folder, frameCount, seconds, location, degrees, spaceValue, layer)
    local newParticle = {

    -------------------------
    -- Function arguments: --
    -------------------------

        spriteSheet = folder, --String
            --The file location of the FOLDER itself, where you'll have your sequential
            --png files named "0, 1, 2, 3..."
            --The "img/" at the front is automatically written by CreateImagePrimitiveString()
            --and should not be part of this.
        totalFrames = frameCount, --Int
            --This will be the amount of png files in your sprite folder folder for the particle.
            --i.e. take the final sprite's name and add 1.
            --The framerate of a particle is its "totalFrames" divided by its "lifetime"
        lifetime = seconds, --Float
            --The duration of the particle's animation. By default, it will self-delete when this
            --timer runs out.
        position = location, --Ints
            --Should be a Pointf value of the particle's X and Y coordinates.
        rotation = degrees, --Int
            --Rotation of the displayed frame in degrees.
        space = spaceValue, --Int
            --0 if you want the particle to render on the player's plane, 1 for the enemy's.
            --Set to nil if you're not using a space-specific layer (i.e. MOUSE_CONTROL).
            --DO NOT set to anything else.
        renderEvent = layer, --String
            --The RenderEvents callback that will render the particle.
            --i.e. when rendering a particle with SHIP_SPARKS, pass this as "SHIP_SPARKS"
            --A list of supported render layers is commented above this function.

    ---------------------------------------------------------------
    -- The following aren't arguments of create_particle; if you --
    -- want to use them, they're attributes of each particle.    --
    ---------------------------------------------------------------

        scale = 1, --Float
            --How large/small the image will be in relation to the png's size. (i.e. a scale value
            --of 0.5 will make a 20x20 image display as 10x10). Scaling is centered on the particle's
            --"position" attribute.
        movementSpeed = 0, --Float
            --How fast your particle will move across the screen in pixels-per-second. The direction of
            --movement is determined by the "heading" attribute below.
        heading = 0, --Float
            --This is completely separate from the rotation attribute. It refers to the
            --direction that the particle will travel if given a positive movementSpeed value.
            --Note: Lua's trig math functions will all return radian values. I don't prefer
            --radians, so I made this system around degrees :3 To pass a value of radians
            --into this system, use math.deg(). For consistency with "rotation," a heading of 0 points
            --directly upward.
        imageSpin = 0, --Float
            --A nonzero value will cause your particle to rotate around its center at the given speed.
            --Measured in degrees per second.
        headingSpin = 0, --Float
            --Similar to "imageSpin," but for the "heading" attribute. Causes particles to turn as
            --they move. Measured in degrees per second.
        persists = false, --Bool
            --Setting this to true will cause the particle to loop back to the beginning of its
            --animation each time it ends. You'll have to destroy_particle() yourself eventually,
            --or it'll be stuck on your screen (and taking up memory even it it drifts out of sight).
            --As this is a general-use library, I'll leave it up to you to delete persisting particles
            --after creating them :)
        countdown = 0, --Float
            --If set to a positive value, this will prevent the particle from rendering or updating for
            --that many seconds, effectively adding a delay before it appears.
        paused = false, --Bool
            --Setting this to true will freeze the particle's animation and expiration timer. You'll have
            --to keep track of a paused particle and unpause/destroy it yourself.
            --Pausing a particle during its "countdown" phase will freeze the countdown. If you want it to
            --pause *after* its countdown, set pauseOnFrame to 0
        pauseOnFrame = nil, --Int
            --Causes the particle to set "paused" to true when it reaches a certain frame.
            --i.e. a value of 3 will allow the particle to reach frame 4, then pause it.
            --When the animation reaches the desired frame, this attribute resets to nil.
        loops = 1,
            --Specifies how many times the animation should play. "Lifetime" defines ONE loop duration.
            --i.e. loops = 3, lifetime = 5 will cause the animation to play thrice over 15 seconds.
            --Does not decrement if "persists" is set to true.
        visible = true, --Bool
            --If set to false, the particle will not be rendered onscreen. Other attributes will update each
            --tick as usual.
        deleteOnRestart = true, --Bool
            --Setting to false will cause the particle to still exist if the run is restarted.
        currentFrame = 0, --Int
            --Will be re-calculated each tick unless the particle is paused.
        hideOnJump = false, --Bool
            --Setting to true will prevent the particle from rendering during a jump. Applies to the ship
            --specified in the .space attribute

    -------------------------------------------------------------------
    -- Internal-use attributes. I don't recommend messing with them. --
    -------------------------------------------------------------------
    
        remainingDuration = seconds, --Float
    }
    
    if not particleList[layer] then
        particleList[layer] = {}
    end
    newParticle.indexNum = #particleList[layer] + 1 --Int. **Don't** tamper with this one
        --This should automatically hold the same value as the particle's index value in particleList[layer]
    particleList[layer][#particleList[layer] + 1] = newParticle
    return newParticle
end

--And as one might expect, this is how you destroy particles (important if their "persists" attribute is True).
--This isn't otherwise necessary to use, as non-persisting particles will automatically expire after their lifetime.
function mods.brightness.destroy_particle(particle)
    table.remove(particleList[particle.renderEvent], particle.indexNum)
    local i = particle.indexNum
    while i <= #particleList[particle.renderEvent] do
        particleList[particle.renderEvent][i].indexNum = particleList[particle.renderEvent][i].indexNum - 1
        i = i + 1
    end
end

--Sends a particle to the top of its layer, causing it to be rendered above others on its layer.
--Creating new particles can still cause it to render below them until this is repeated.
--Unneeded calls will be minimal on memory.
function mods.brightness.send_to_front(particle)
    if particle.indexNum < #particleList[particle.renderEvent] then
        local layer = particle.renderEvent
        local i = #particleList[layer]
        while i > particle.indexNum do
            particleList[layer][i].indexNum = particleList[layer][i].indexNum - 1
            i = i - 1
        end
        table.insert(particleList[layer], #particleList[particle.renderEvent] + 1, particle)
        table.remove(particleList[layer], particle.indexNum)
        particleList[layer][#particleList[layer]].indexNum = #particleList[layer]
    end
end

--Sends a particle to the bottom of its layer, causing it to be rendered below others on its layer.
--Unneeded calls will be minimal on memory.
function mods.brightness.send_to_back(particle)
    if particle.indexNum > 1 then
        local layer = particle.renderEvent
        local i = 1
        while i < particle.indexNum do
            particleList[layer][i].indexNum = particleList[layer][i].indexNum + 1
            i = i + 1
        end
        table.insert(particleList[layer], 1, particle)
        table.remove(particleList[layer], particle.indexNum + 1)
        particleList[layer][1].indexNum = 1
    end
end


--This is Chrono Vortex's code to return a point on a weapon for weapon particles.
--Enter the weapon, then enter the coordinates of the desired point on frame 0 of the spritesheet.
function mods.brightness.point_on_weapon_sprite(weapon, offsetX, offsetY)
    local emitPointX = 0
    local emitPointY = 0
    local rotate = false
    local mirror = false
    local vertMod = 1
    rotate = weapon.mount.rotate
    mirror = weapon.mount.mirror
    if mirror then vertMod = -1 end
    
    -- Calculate weapon coodinates
    local weaponAnim = weapon.weaponVisual
    local ship = Hyperspace.ships(weapon.iShipId).ship
    local shipGraph = Hyperspace.ShipGraph.GetShipInfo(weapon.iShipId)
    local slideOffset = weaponAnim:GetSlide()
    emitPointX = emitPointX + ship.shipImage.x + shipGraph.shipBox.x + weaponAnim.renderPoint.x + slideOffset.x
    emitPointY = emitPointY + ship.shipImage.y + shipGraph.shipBox.y + weaponAnim.renderPoint.y + slideOffset.y

    -- Add emitter and mount point offset
    if rotate then
        emitPointX = emitPointX - offsetY + weaponAnim.mountPoint.y
        emitPointY = emitPointY + (offsetX - weaponAnim.mountPoint.x)*vertMod
    else
        emitPointX = emitPointX + (offsetX - weaponAnim.mountPoint.x)*vertMod
        emitPointY = emitPointY + offsetY - weaponAnim.mountPoint.y
    end
    return Hyperspace.Pointf(emitPointX, emitPointY)
end

--Moves a point by "distance" (pixels) in the direction of "heading" (degrees)
--Credit: Lizzard
function mods.brightness.offset_point_in_direction(point, heading, distance) --radius is half the height of the picture
    return Hyperspace.Pointf(point.x - (distance * math.cos(math.rad(heading))), point.y - (distance * math.sin(math.rad(heading))))
end

--Returns a randomly-chosen point within "radius" pixels of "point"
function mods.brightness.random_offset_in_radius(point, radius)
    local offsetAngle = math.random(0,360)
    local offsetDistance = math.random(0,radius)
    return Hyperspace.Pointf(math.floor(point.x + offsetDistance * math.cos(math.rad(offsetAngle))), math.floor(point.y + offsetDistance * math.sin(math.rad(offsetAngle))))
end

--Returns a table of every slot center in a room at the given location.
--Written by Lizzard with some changes to function args for convenience.
function mods.brightness.get_slot_centers(location, shipManager)
    local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
    local roomId = shipGraph:GetSelectedRoom(location.x, location.y, true)
    if roomId == -1 then return nil end
    local shape = shipGraph:GetRoomShape(roomId)
    local roomCenter = shipManager:GetRoomCenter(roomId)

    local tile_centers = {}
    local tile_size = 35
    local tiles_x = math.floor(shape.w / tile_size)
    local tiles_y = math.floor(shape.h / tile_size)

    local half_width = (tiles_x * tile_size) / 2
    local half_height = (tiles_y * tile_size) / 2

    local start_x = roomCenter.x - half_width + tile_size / 2
    local start_y = roomCenter.y - half_height + tile_size / 2

    for i = 0, tiles_x - 1 do
        for j = 0, tiles_y - 1 do
            local tile_center_x = start_x + i * tile_size
            local tile_center_y = start_y + j * tile_size
            table.insert(tile_centers, {x = tile_center_x, y = tile_center_y})
        end
    end

    return tile_centers
end

-------------------------------------------------------------------------------------------
-- Local functions and particle updating/rendering scripts begin here.                   --
-- If you've read this far, you don't need to read or call anything beyond this point.   --
-- If you *really* want to, you can comment out render event scripts unused in your mod. --
-- Credit: Lizzard, Arc, and myself :)                                                   --
-------------------------------------------------------------------------------------------

--Pretty self-explanatory
local function game_is_paused()
    local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
    if commandGui.bPaused or commandGui.bAutoPaused or commandGui.event_pause or commandGui.menu_pause then
        return true
    else
        return false
    end
end

--Allows a render event to refer to an already-existing primitive of a png file if possible to avoid creating duplicates.
local function primitiveListManager(string)
    if not primitiveList[string] then
        local stringID = Hyperspace.Resources:GetImageId(string)
        primitiveList[string] = Hyperspace.Resources:CreateImagePrimitiveString(
            string,
            0 - stringID.width/2,
            0 - stringID.height/2,
            0,
            Graphics.GL_Color(1, 1, 1, 1),
            1.0,
            false
        )
    end
    return primitiveList[string]
end

local function cleanup_on_restart()
    for layer, _ in pairs(particleList) do
        local i = 1
        while i <= #particleList[layer] do
            if particleList[layer][i].deleteOnRestart then
                Brightness.destroy_particle(particleList[layer][i])
            else
                i = i + 1
            end
        end
    end
end

--Update's all of a particle's attributes. Increments the counter i if necessary and returns it
--                                         (Lua is a stupid language, so I can't pass i by reference)
local function update_particle(particle, i)
    if particle.countdown == 0 then
                
        --render current frame image
        if particle.visible and not(particle.space and particle.hideOnJump and Hyperspace.ships(particle.space).bJumping) then
            Graphics.CSurface.GL_PushMatrix()
            Graphics.CSurface.GL_Translate(particle.position.x, particle.position.y, 0)
            Graphics.CSurface.GL_Rotate(math.floor(particle.rotation), 0, 0, 1)
            Graphics.CSurface.GL_Scale(particle.scale, particle.scale, 1)
            Graphics.CSurface.GL_RenderPrimitive(primitiveListManager(particle.spriteSheet.."/"..tostring(particle.currentFrame)..".png"))
            Graphics.CSurface.GL_PopMatrix()
        end

        --update timer and position
        if not(game_is_paused() or particle.paused) then
            particle.remainingDuration = math.max(particle.remainingDuration - Hyperspace.FPS.SpeedFactor/16, 0)
            particle.currentFrame = math.floor(((particle.lifetime - particle.remainingDuration) * particle.totalFrames) / particle.lifetime)
            if particle.pauseOnFrame and particle.pauseOnFrame == particle.currentFrame then
                particle.paused = true
                particle.pauseOnFrame = nil
            else
                if particle.movementSpeed then
                    particle.position.x = particle.position.x + particle.movementSpeed*Hyperspace.FPS.SpeedFactor/16 * math.cos(math.rad(particle.heading + 270))
                    particle.position.y = particle.position.y + particle.movementSpeed*Hyperspace.FPS.SpeedFactor/16 * math.sin(math.rad(particle.heading + 270))
                end
                if particle.imageSpin then
                    particle.rotation = (particle.rotation + particle.imageSpin * Hyperspace.FPS.SpeedFactor/16) % 360
                end
                if particle.headingSpin then
                    particle.heading = (particle.heading + particle.headingSpin * Hyperspace.FPS.SpeedFactor/16) % 360
                end
            end
        end

        --handle particle timer ending
        if particle.remainingDuration == 0 then
            particle.remainingDuration = particle.lifetime
            particle.currentFrame = 0
            if not particle.persists then
                particle.loops = particle.loops - 1
            end
            if particle.loops <= 0 then
                Brightness.destroy_particle(particle)
                return i
            end
        end

    --update countdown
    elseif not(game_is_paused() or particle.paused) then
        particle.countdown = math.max(particle.countdown - Hyperspace.FPS.SpeedFactor/16, 0)
    end
    return i + 1
end

local function handle_particles(layer)
    local i = 1
    while particleList[layer] and i <= #particleList[layer] do
        i = update_particle(particleList[layer][i], i)
    end
end

local function handle_ship_particles(layer, ship)
    local i = 1
    while particleList[layer] and i <= #particleList[layer] do
        if ship.iShipId == particleList[layer][i].space then
            i = update_particle(particleList[layer][i], i)
        else
            i = i + 1
        end
    end
end

script.on_render_event(Defines.RenderEvents.MAIN_MENU, function(mainMenu)
    handle_particles("MAIN_MENU_PRE")
end, function(mainMenu)
    handle_particles("MAIN_MENU")
end)

script.on_render_event(Defines.RenderEvents.GUI_CONTAINER, function(commandGui)
    handle_particles("GUI_CONTAINER_PRE")
end, function(commandGui)
    handle_particles("GUI_CONTAINER")
end)

script.on_render_event(Defines.RenderEvents.LAYER_BACKGROUND, function(spaceManager)
    handle_particles("LAYER_BACKGROUND_PRE")
end, function(spaceManager)
    handle_particles("LAYER_BACKGROUND")
end)

script.on_render_event(Defines.RenderEvents.LAYER_FOREGROUND, function(spaceManager)
    handle_particles("LAYER_FOREGROUND_PRE")
end, function(spaceManager)
    handle_particles("LAYER_FOREGROUND")
end)

script.on_render_event(Defines.RenderEvents.LAYER_ASTEROIDS, function(spaceManager)
    handle_particles("LAYER_ASTEROIDS_PRE")
end, function(spaceManager)
    handle_particles("LAYER_ASTEROIDS")
end)

script.on_render_event(Defines.RenderEvents.LAYER_PLAYER, function(commandGui)
    handle_particles("LAYER_PLAYER_PRE")
end, function(commandGui)
    handle_particles("LAYER_PLAYER")
end)

script.on_render_event(Defines.RenderEvents.SHIP, function(ship)
    handle_ship_particles("SHIP_PRE", ship)
end, function(ship)
    handle_ship_particles("SHIP", ship)
end)

script.on_render_event(Defines.RenderEvents.SHIP_MANAGER, function(ship)
    handle_ship_particles("SHIP_MANAGER_PRE", ship)
end, function(ship)
    handle_ship_particles("SHIP_MANAGER", ship)
end)

script.on_render_event(Defines.RenderEvents.SHIP_JUMP, function(ship)
    handle_ship_particles("SHIP_JUMP_PRE", ship)
end, function(ship)
    handle_ship_particles("SHIP_JUMP", ship)
end)

script.on_render_event(Defines.RenderEvents.SHIP_HULL, function(ship)
    handle_ship_particles("SHIP_HULL_PRE", ship)
end, function(ship)
    handle_ship_particles("SHIP_HULL", ship)
end)

script.on_render_event(Defines.RenderEvents.SHIP_ENGINES, function(ship)
    handle_ship_particles("SHIP_ENGINES_PRE", ship)
end, function(ship)
    handle_ship_particles("SHIP_ENGINES", ship)
end)

script.on_render_event(Defines.RenderEvents.SHIP_FLOOR, function(ship)
    handle_ship_particles("SHIP_FLOOR_PRE", ship)
end, function(ship)
    handle_ship_particles("SHIP_FLOOR", ship)
end)

script.on_render_event(Defines.RenderEvents.SHIP_BREACHES, function(ship)
    handle_ship_particles("SHIP_BREACHES_PRE", ship)
end, function(ship)
    handle_ship_particles("SHIP_BREACHES", ship)
end)

script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function(ship)
    handle_ship_particles("SHIP_SPARKS_PRE", ship)
end, function(ship)
    handle_ship_particles("SHIP_SPARKS", ship)
end)

script.on_render_event(Defines.RenderEvents.LAYER_FRONT, function(spaceManager)
    handle_particles("LAYER_FRONT_PRE")
end, function(spaceManager)
    handle_particles("LAYER_FRONT")
end)

script.on_render_event(Defines.RenderEvents.SPACE_STATUS, function(spaceStatus)
    handle_particles("SPACE_STATUS_PRE")
end, function(spaceStatus)
    handle_particles("SPACE_STATUS")
end)

script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function(mouseControl)
    handle_particles("MOUSE_CONTROL_PRE")
end, function(mouseControl)
    handle_particles("MOUSE_CONTROL")
end)

script.on_game_event("DEATH", false, function()
    cleanup_on_restart()
end)

script.on_game_event("START_BEACON", false, function()
    cleanup_on_restart()
end)