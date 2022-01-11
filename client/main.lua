local QBCore = exports['qb-core']:GetCoreObject()
local currHouse = nil
local closestPlantId = 0
local housePlants = {}
local houseProps = {}
local minProximity = 0.8

DrawText3Ds = function(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Citizen.Wait(100)
    end
end

-- Helper functions
local function insideHouse()
    return (currHouse ~= nil)
end

local function renderPlant(id)
    if (insideHouse() and housePlants[id] ~= nil and houseProps[id] == nil) then
        Citizen.CreateThread(function()
            local plant = housePlants[id]
            local coords = json.decode(plant.coords)
            local hash = GetHashKey(QBWeed.Plants[plant.sort]["stages"][plant.stage])
            local propOffset = QBWeed.PropOffsets[plant.stage]
            local prop = CreateObject(hash, coords.x, coords.y, coords.z - propOffset, false, false, false)
            while not prop do Wait(0) end
            FreezeEntityPosition(prop, true)
            SetEntityAsMissionEntity(prop, false, false)
            houseProps[id] = prop
        end)
    end
end
local function unrenderPlant(id)
    if (houseProps[id] ~= nil) then
        DeleteObject(houseProps[id])
        houseProps[id] = nil
    end
end

local function renderPlants()
    for id, _ in pairs(housePlants) do
        renderPlant(id)
    end
end
local function unrenderPlants()
    for id, _ in pairs(housePlants) do
        unrenderPlant(id)
    end
end

local function populateHousePlants(plants)
    for _, plant in pairs(plants) do
        housePlants[plant.id] = plant
    end
end
local function updateHousePlant(id)
    if insideHouse() then
        QBCore.Functions.TriggerCallback('qb-weed:server:getHousePlant', function(plant)
            populateHousePlants(plant)
            renderPlant(id)
        end, currHouse, id)
    end
end
local function updateHousePlants()
    if insideHouse() then
        QBCore.Functions.TriggerCallback('qb-weed:server:getHousePlants', function(plants)
            populateHousePlants(plants)
            renderPlants()
        end, currHouse)
    end
end

-- Actions
local function placeAction(ped, house, coords, sort, slot)
    QBCore.Functions.Progressbar("plant_weed_plant", "Planting", 8000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = "amb@world_human_gardener_plant@male@base",
        anim = "base",
        flags = 16,
    }, {}, {}, function() -- Done
        ClearPedTasks(ped)
        TriggerServerEvent('qb-weed:server:placePlant', house, coords, sort, slot)
    end, function() -- Cancel
        ClearPedTasks(ped)
        QBCore.Functions.Notify("Process cancelled", "error")
    end)
end
local function fertilizeAction(ped, house, plant)
    QBCore.Functions.Progressbar("plant_weed_plant", "Feeding Plant", math.random(4000, 8000), false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = "timetable@gardener@filling_can",
        anim = "gar_ig_5_filling_can",
        flags = 16,
    }, {}, {}, function() -- Done
        ClearPedTasks(ped)
        TriggerServerEvent('qb-weed:server:fertilizePlant', house, plant)
    end, function() -- Cancel
        ClearPedTasks(ped)
        QBCore.Functions.Notify("Process cancelled", "error")
    end)
end
local function harvestAction(ped, house, plant)
    QBCore.Functions.Progressbar("remove_weed_plant", "Harvesting Plant", 8000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = "amb@world_human_gardener_plant@male@base",
        anim = "base",
        flags = 16,
    }, {}, {}, function() -- Done
        ClearPedTasks(ped)
        TriggerServerEvent('qb-weed:server:harvestPlant', house, plant)
    end, function() -- Cancel
        ClearPedTasks(ped)
        QBCore.Functions.Notify("Process cancelled", "error")
    end)
end
local function deathAction(ped, house, plant)
    QBCore.Functions.Progressbar("remove_weed_plant", "Removing The Plant", 8000, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = "amb@world_human_gardener_plant@male@base",
        anim = "base",
        flags = 16,
    }, {}, {}, function() -- Done
        ClearPedTasks(ped)
        TriggerServerEvent('qb-weed:server:removeDeadPlant', house, plant)
    end, function() -- Cancel
        ClearPedTasks(ped)
        QBCore.Functions.Notify("Process cancelled", "error")
    end)
end

-- Event triggered upon entrance to a house
-- Should really be named enterHouse
RegisterNetEvent('qb-weed:client:getHousePlants', function(house)
    if not insideHouse() then
        currHouse = house
        updateHousePlants()
    end
end)
-- Event triggered upon exiting a house
RegisterNetEvent('qb-weed:client:leaveHouse', function()
    if insideHouse() then
        unrenderPlants()
        currHouse = nil
        housePlants = {}
    end
end)

-- Event triggered by the server when a single plant is fertilized
RegisterNetEvent('qb-weed:client:refreshPlantStats', function (id, food, health)
    if housePlants[id] == nil then
        updateHousePlant(id)
    else
        housePlants[id].food = food
        housePlants[id].health = health
    end
end)
-- Event triggered by the server to refresh model after stage update, manually maintains state of houseProps
RegisterNetEvent('qb-weed:client:refreshPlantProp', function(id, newStage)
    if insideHouse() then
        housePlants[id].stage = newStage
        housePlants[id].progress = 0
        unrenderPlant(id)
        renderPlant(id)
    end
end)

-- Event triggered by the server when client attempt to place a plant
RegisterNetEvent('qb-weed:client:placePlant', function(sort, item)
    if insideHouse() then
        local ped = PlayerPedId()
        local pedOffset = 0.75
        local coords = GetOffsetFromEntityInWorldCoords(ped, 0, pedOffset, 0)

        -- Check if any plants are too close in proximity to new position
        local closestPlant = 0
        for name, prop in pairs(QBWeed.Props) do
            if closestPlant == 0 then
                closestPlant = GetClosestObjectOfType(coords.x, coords.y, coords.z, minProximity, GetHashKey(prop), false, false, false)
            end
        end

        if closestPlant == 0 then
            placeAction(ped, currHouse, coords, sort, item.slot)
        else
            QBCore.Functions.Notify("Too close to another plant", 'error', 3500)
        end
    else
        QBCore.Functions.Notify("It's not safe here, try your house", 'error', 3500)
    end
end)

-- Event triggered by the server when client attempts to fertilize a plant
RegisterNetEvent('qb-weed:client:fertilizePlant', function(item)
    if (insideHouse() and closestPlantId ~= 0) then
        local ped = PlayerPedId()
        local plant = housePlants[closestPlantId]
        local coords = json.decode(plant.coords)
        local plyDistance = #(GetEntityCoords(ped) - vector3(coords.x, coords.y, coords.z))

        if plyDistance < minProximity + 0.2 then
            if plant.food < 100 then
                fertilizeAction(ped, currHouse, plant)
            else
                QBCore.Functions.Notify('Plant is already fertilized', 'error', 3500)
            end
        else
            QBCore.Functions.Notify("Must be near a weed plant", "error")
        end
    end
end)

-- Event triggered by the server when it has to remove a plant
RegisterNetEvent('qb-weed:client:removePlant', function(id)
    if insideHouse() then
        unrenderPlant(id)
        housePlants[id] = nil
    end
end)

-- Client harvest and inspect interactivity
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if insideHouse() then
            local ped = PlayerPedId()
            for id, plant in pairs(housePlants) do
                local gender = "M"
                if plant.gender == "woman" then gender = "F" end
                local coords = json.decode(plant.coords)
                local label = QBWeed.Plants[plant.sort]["label"]
                local plyDistance = #(GetEntityCoords(ped) - vector3(coords.x, coords.y, coords.z))

                if plant ~= nil and plyDistance < minProximity then
                    closestPlantId = id
                    -- Plant is alive
                    if plant.health > 0 then
                        DrawText3Ds(coords.x, coords.y, coords.z,
                            'Sort: ~g~'..label..'~w~ ['..gender..'] | Nutrition: ~b~'..plant.food..'% ~w~ | Health: ~b~'..plant.health..'%')
                        if plant.stage == QBWeed.Plants[plant.sort]["highestStage"] then
                            DrawText3Ds(coords.x, coords.y, coords.z + 0.2, "Press ~g~ E ~w~ to harvest plant.")
                            if IsControlJustPressed(0, 38) then
                                harvestAction(ped, currHouse, plant)
                            end
                        else
                            DrawText3Ds(coords.x, coords.y, coords.z + 0.2, "Trapped? Press ~g~ E ~w~ to remove plant.")
                            if IsControlJustPressed(0, 38) then
                                deathAction(ped, currHouse, plant)
                            end
                        end
                    -- Plant is dead
                    else
                        DrawText3Ds(coords.x, coords.y, coords.z, 'The plant has died. Press ~r~ E ~w~ to remove plant.')
                        if IsControlJustPressed(0, 38) then
                            deathAction(ped, currHouse, plant)
                        end
                    end
                end
            end
        end

        if not insideHouse() then
            Citizen.Wait(5000)
        end
    end
end)