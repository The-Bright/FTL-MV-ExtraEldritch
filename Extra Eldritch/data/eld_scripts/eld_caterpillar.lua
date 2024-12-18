mods.eld.caterpillarSequence = {}
local sequence = mods.eld.caterpillarSequence
mods.eld.caterpillarLength = 0
local length = mods.eld.caterpillarLength

local Brightness = mods.brightness

local function userdata_table(userdata, tableName)
    if not userdata.table[tableName] then userdata.table[tableName] = {} end
    return userdata.table[tableName]
end

local function get_distance(point1, point2)
    return math.sqrt((point2.x - point1.x)^2+(point2.y - point1.y)^2)
end

--given a crew's previous X and Y, determines if it is now standing/walking in a different room slot
--crewmem's current and previous positions must be on the same ship
local function crew_at_new_slot(crewmem, previousX, previousY)
    --if two x or y values are on the same column/row of slots, the f_of() function will return the same value for both numbers.
    --"offset" is the x or y distance between a slot corner and the next lowest multiple of 35
    local function f_of(u, offset)
        return math.floor(u - (u - offset + 17.5) % 35)
    end
    local x_offset = (crewmem.x_destination - 17.5) % 35
    local y_offset = (crewmem.y_destination - 17.5) % 35
    if previousX and previousY and 
        (f_of(crewmem.x, x_offset) ~= f_of(previousX, x_offset) or
        f_of(crewmem.y, y_offset) ~= f_of(previousY, y_offset)) then
        return true
    end
    return false
end

--calculates a point on a given 3-point Bezier curve for a value of t. Returns the point and its derivative
local function bezier_table_at_t(ctrlPoint1, ctrlPoint2, ctrlPointCenter, t)
    local a = Hyperspace.Pointf(
        ctrlPointCenter.x + (1 - t)*(ctrlPoint1.x - ctrlPointCenter.x),
        ctrlPointCenter.y + (1 - t)*(ctrlPoint1.y - ctrlPointCenter.y)
    )
    local b = Hyperspace.Pointf(
        ctrlPointCenter.x + t*(ctrlPoint2.x - ctrlPointCenter.x),
        ctrlPointCenter.y + t*(ctrlPoint2.y - ctrlPointCenter.y)
    )
    return {
        point = Hyperspace.Pointf(a.x + t*(b.x - a.x), a.y + t*(b.y - a.y)),
        derivative = (a.y - b.y)/(a.x - b.x)
    }
end

local AMPLITUDE = 60
local SPACING_FACTOR = 14.75
local MAX_ARCH_PARTICLES = 15
--uses a three-point Bezier curve to position particles in an arch between segments
local function update_arch(index)
    local pointA = Hyperspace.Pointf(sequence[index - 1].crewInstance.x, sequence[index - 1].crewInstance.y)
    local pointB = Hyperspace.Pointf(sequence[index].crewInstance.x, sequence[index].crewInstance.y)
    local controlPoint = Hyperspace.Pointf(
        (pointA.x + pointB.x)/2,
        (pointA.y + pointB.y)/2 + AMPLITUDE/((3/AMPLITUDE)*math.abs(pointA.x - pointB.x) + 1) - AMPLITUDE
    )
    local endpointOffset = 0
    if index == 2 then endpointOffset = 0.6 end

    --initialize outlineParticles and colorParticles
    if not(sequence[index].outlineParticles and sequence[index].colorParticles) then
        --An arch actually consists of two rows of particles: the color and the outline below it. This creates
        --a uniform black outline around the entire arch.

        --The antennaeParticle is rendered above every outlineParticle and above the single closest colorParticle.
        if index > 1 and sequence[index - 1].id and sequence[index - 1].id == "HEAD" then
            Brightness.send_to_back(sequence[index - 1].antennaeParticle)
        end

        sequence[index].colorParticles = {}
        local i = 1
        while i <= MAX_ARCH_PARTICLES do
            sequence[index].colorParticles[i] = Brightness.create_particle("particles/caterpillar_body_"..math.random(4), 1, 1, Hyperspace.Pointf(0,0), 0, 0, "SHIP")
            sequence[index].colorParticles[i].paused = true
            sequence[index].colorParticles[i].visible = false
            sequence[index].colorParticles[i].hideOnJump = true
            i = i + 1
        end
        Brightness.send_to_back(sequence[index].colorParticles[1])

        sequence[index].outlineParticles = {}
        i = 1
        while i <= MAX_ARCH_PARTICLES do
            sequence[index].outlineParticles[i] = Brightness.create_particle("particles/caterpillar_body_outline", 1, 1, Hyperspace.Pointf(0,0), 0, 0, "SHIP")
            sequence[index].outlineParticles[i].paused = true
            sequence[index].outlineParticles[i].visible = false
            sequence[index].outlineParticles[i].hideOnJump = true
            Brightness.send_to_back(sequence[index].outlineParticles[i])
            i = i + 1
        end
    end

    --credit to Jay Clegg for this method of arc length parameterization
    --https://www.planetclegg.com/projects/WarpingTextToSplines.html
    local arcLengths = {}
    local totalArcLength = 0
    local counter = 1
    local previousPoint = pointA
    local currentPoint = nil
    local POINTS = 10 --higher values distribute particles more precisely at the cost of memory
    while counter <= POINTS do
        currentPoint = bezier_table_at_t(pointA, pointB, controlPoint, counter/POINTS).point
        totalArcLength = totalArcLength + get_distance(previousPoint, currentPoint)
        arcLengths[counter] = totalArcLength
        previousPoint = currentPoint
        counter = counter + 1
    end

    local RENDERED_PARTICLES = math.ceil((get_distance(pointA, controlPoint) + get_distance(pointB, controlPoint))/SPACING_FACTOR)
    local i = 1
    while i <= math.min(RENDERED_PARTICLES, MAX_ARCH_PARTICLES) do --reposition and render the correct amount of particles

        --u is not directly used to increment t. This is because u does not move along the curve at a stable rate.
        local u = i/(math.min(RENDERED_PARTICLES, MAX_ARCH_PARTICLES) + endpointOffset)
        local targetArcLength = u * totalArcLength

        --find arcIndex, the closest arcLengths element that is <= u * totalArcLength
        local arcIndex = 1
        while arcLengths[arcIndex + 1] < targetArcLength do
            arcIndex = arcIndex + 1
        end

        --approximate t in relation to u. Interpolate between the arcLengths elements bounding it
        local lengthBefore = arcLengths[arcIndex]
        local lengthAfter = arcLengths[arcIndex + 1]
        local segmentLength = lengthAfter - lengthBefore
        local segmentFraction = (targetArcLength - lengthBefore)/segmentLength
        local t = (arcIndex + segmentFraction)/POINTS
        
        --finally, with a more-accurate value of t, we can plot a point on the curve and update the set of particles
        local bezier_table = bezier_table_at_t(pointA, pointB, controlPoint, t)
        sequence[index].outlineParticles[i].position = bezier_table.point
        sequence[index].outlineParticles[i].rotation = math.deg(math.atan(bezier_table.derivative))
        sequence[index].outlineParticles[i].space    = sequence[index].crewInstance.currentShipId
        sequence[index].outlineParticles[i].visible  = true
        sequence[index].colorParticles[i].position   = bezier_table.point
        sequence[index].colorParticles[i].rotation   = math.deg(math.atan(bezier_table.derivative))
        sequence[index].colorParticles[i].space      = sequence[index].crewInstance.currentShipId
        sequence[index].colorParticles[i].visible    = true

        i = i + 1
    end
    while i <= MAX_ARCH_PARTICLES do --hide and ignore left-over particles
        sequence[index].outlineParticles[i].visible = false
        sequence[index].colorParticles[i].visible = false
        i = i + 1
    end
end

--update a crew member's trailingSlot. If they're dying, remove them from the sequence and shift all subsequent elements down
local function update_sequence_at(crewmem, index)
    --if the closest slot has changed since last tick, change the next segment's pathfinding target to slotLastTick
    if sequence[index].lastTickX and (sequence[index].lastTickX ~= crewmem.x or sequence[index].lastTickY ~= crewmem.y)
        and crew_at_new_slot(crewmem, sequence[index].lastTickX, sequence[index].lastTickY) then
        sequence[index].trailingSlot =
            Hyperspace.ShipGraph.GetShipInfo(crewmem.currentShipId):
            GetClosestSlot(Hyperspace.Point(math.floor(sequence[index].lastTickX),
            math.floor(sequence[index].lastTickY)), crewmem.currentShipId, crewmem.intruder)
    end
    sequence[index].lastTickX = crewmem.x
    sequence[index].lastTickY = crewmem.y
    if crewmem:IsDead() then
        print("sequence["..index.."] died :(")
        while sequence[index].outlineParticles[1] do --delete relevant particles
            Brightness.destroy_particle(sequence[index].outlineParticles[1])
            table.remove(sequence[index].outlineParticles, 1)
            Brightness.destroy_particle(sequence[index].colorParticles[1])
            table.remove(sequence[index].colorParticles, 1)
        end
        local i = index
        while sequence[i + 1] do --link the sequence back together
            sequence[i] = sequence[i + 1]
            sequence[i].indexNum = i
            i = i + 1
        end
        table.remove(sequence)
        length = length - 1
    end
end

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
    if crewmem:GetSpecies() == "caterpillar_head" then

        --if there is no registered sequence OR the sequence does not have a head, insert this head at the front of the sequence
        if length == 0 or sequence[1].id ~= "HEAD" then
            local i = 1
            while sequence[i] do
                sequence[i].indexNum = sequence[i].indexNum + 1
                i = i + 1
            end
            table.insert(sequence, 1, userdata_table(crewmem, "mods.eld.caterpillar"))
            length = length + 1
            sequence[1].indexNum = 1
            sequence[1].id = "HEAD"
            sequence[1].crewInstance = crewmem
            sequence[1].antennaeParticle = Brightness.create_particle("particles/caterpillar_antennae", 4, 1, Hyperspace.Pointf(0,0), 0, 0, "SHIP")
            sequence[1].antennaeParticle.paused = true
            sequence[1].antennaeParticle.hideOnJump = true

            print("Added a new "..sequence[1].id.." at index ["..sequence[1].indexNum.."]")
        end

        --update sequence[1]
        if sequence[1].crewInstance == crewmem then
            update_sequence_at(crewmem, 1)
            sequence[1].antennaeParticle.position = Hyperspace.Pointf(crewmem.x, crewmem.y + 5)
            sequence[1].antennaeParticle.space = crewmem.currentShipId
            if crewmem:Repairing() then
                sequence[1].antennaeParticle.currentFrame = 1
            else
                sequence[1].antennaeParticle.currentFrame = math.tointeger(crewmem.crewAnim.direction)
            end
        end

    elseif crewmem:GetSpecies() == "caterpillar_segment" and length > 0 then

        --if the segment is newly-created, append it to the sequence
        local segmentTable = userdata_table(crewmem, "mods.eld.caterpillar") --crewmem's userdata table
        if not segmentTable.indexNum then
            length = length + 1
            sequence[length] = segmentTable
            sequence[length].indexNum = length
            sequence[length].id = "SEGMENT"
            sequence[length].crewInstance = crewmem

            print("Added a new "..sequence[length].id.." at index ["..sequence[length].indexNum.."]")
        end
        local followingTable = sequence[segmentTable.indexNum - 1] --the userdata table of the segment that crewmem is following

        --if the crewmem is not at or pathfinding to trailingSlot, pathfind there
        if followingTable.trailingSlot and segmentTable.currentSlot ~= followingTable.trailingSlot then
            crewmem:MoveToRoom(followingTable.trailingSlot.roomId, followingTable.trailingSlot.slotId, false)
        end
        update_sequence_at(crewmem, segmentTable.indexNum)
        update_arch(segmentTable.indexNum) --FIX: this can be optimised, only call when either crew has changed position/shipID
    end
end)