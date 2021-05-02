local ESX = nil
local PlayerData = {}
local onDuty = false
local inVeh = false
local lastSirenState = false

local longBlips = {}
local nearBlips = {}
local myBlip = {}

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Wait(0)
	end

    if Config.useRflxMulti then
        while exports['rflx_multichar']:getChar() == nil do
            Wait(100)
        end
    else
        while ESX.GetPlayerData().job == nil do
            Wait(100)
        end
    end

	PlayerData = ESX.GetPlayerData()
    if Config.useRflxMulti then
	    PlayerData.char = exports['rflx_multichar']:getChar()
    end
    
    if Config.blipGroup.renameGroup then
        AddTextEntryByHash(`BLIP_OTHPLYR`, Config.blipGroup.groupName..'~w~')
    end
    print('init done')
    checkJob()
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
	PlayerData = xPlayer
    checkJob()
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	PlayerData.job = job
    if onDuty then
        goOffDuty()
    end
    checkJob()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    if Config.bigmapTags then
        DisplayPlayerNameTagsOnBlips(false)
    end
    removeAllBlips()
end)

AddEventHandler("baseevents:enteredVehicle", function(veh, seat, vehiclelabel)
    inVeh = true
    if onDuty then
        inVehChecks(veh, seat, vehiclelabel)

        local cfg = Config.emergencyJobs[PlayerData.job.name].vehBlip and Config.emergencyJobs[PlayerData.job.name].vehBlip[GetEntityModel(veh)] or nil
        TriggerServerEvent('rflx_pdblips:enteredVeh', cfg)
    end
end)

AddEventHandler("baseevents:leftVehicle", function(veh, seat, vehiclelabel)
    inVeh = false
    if lastSirenState then
        lastSirenState = false
        TriggerServerEvent('rflx_pdblips:toggleSiren', false)
    end
    if onDuty then
        TriggerServerEvent('rflx_pdblips:leftVeh')
    end
end)

function inVehChecks(veh, seat, vehiclelabel)
    Citizen.CreateThread(function()
        while inVeh do
            if IsVehicleSirenOn(veh) and not lastSirenState then
                lastSirenState = true
                TriggerServerEvent('rflx_pdblips:toggleSiren', true)
            elseif not IsVehicleSirenOn(veh) and lastSirenState then
                lastSirenState = false
                TriggerServerEvent('rflx_pdblips:toggleSiren', false)
            end
            Citizen.Wait(500)
        end
    end)
end

function checkJob()
    if PlayerData and PlayerData.job and Config.emergencyJobs[PlayerData.job.name] and Config.emergencyJobs[PlayerData.job.name].ignoreDuty then
        goOnDuty()
    end
end

function goOnDuty()
    onDuty = true
    TriggerServerEvent('rflx_pdblips:setDuty', true)

    if Config.notifications.enable and Config.notifications.useMythic then
        exports['mythic_notify']:SendAlert('inform', Config.notifications.onDutyText)
    elseif Config.notifications.enable then
        ESX.ShowNotification(Config.notifications.onDutyText)
    end

    -- other sets
    if Config.bigmapTags then
        SetBigmapActive(true, false)
        DisplayPlayerNameTagsOnBlips(true)
    end
    if inVeh then
        TriggerServerEvent('rflx_pdblips:enteredVeh', Config.emergencyJobs[PlayerData.job.name].vehBlip[GetEntityModel(GetVehiclePedIsIn(PlayerPedId(), false))])
    end
end
AddEventHandler('rflx_pdblips:goOnDuty', goOnDuty)

function goOffDuty()
    onDuty = false
    TriggerServerEvent('rflx_pdblips:setDuty', false)

    if Config.notifications.enable and Config.notifications.useMythic then
        exports['mythic_notify']:SendAlert('inform', Config.notifications.offDutyText)
    elseif Config.notifications.enable then
        ESX.ShowNotification(Config.notifications.offDutyText)
    end

    -- other sets
    if Config.bigmapTags then
        DisplayPlayerNameTagsOnBlips(false)
    end
    removeAllBlips()
end
AddEventHandler('rflx_pdblips:goOffDuty', goOffDuty)

AddEventHandler('rflx_pdblips:toggleDuty', function(bool)
    if bool then
        goOnDuty()
    else
        goOffDuty()
    end
end)

function removeAllBlips()
    restoreBlip(myBlip.blip or GetMainPlayerBlipId())
    for k, v in pairs(nearBlips) do
        RemoveBlip(v.blip)
    end
    for k, v in pairs(longBlips) do
        RemoveBlip(v.blip)
    end
    nearBlips = {}
    longBlips = {}
    myBlip = {}
end

RegisterNetEvent('rflx_pdblips:removeUser')
AddEventHandler('rflx_pdblips:removeUser', function(plyId)
    if nearBlips[plyId] then
        RemoveBlip(nearBlips[plyId].blip)
        nearBlips[plyId] = nil
    end
    if longBlips[plyId] then
        RemoveBlip(longBlips[plyId].blip)
        longBlips[plyId] = nil
    end
end)

RegisterNetEvent('rflx_pdblips:receiveData')
AddEventHandler('rflx_pdblips:receiveData', function(myId, data) -- ugly ass event
    for k, v in pairs(data) do
        local cId = GetPlayerFromServerId(v.playerId)
        --local canSee = v.canSee and includes(v.canSee, PlayerData.job.name)
        --local canSee = v.canSee and v.canSee[PlayerData.job.name]
        local canSee = Config.emergencyJobs[v.job].canSee and Config.emergencyJobs[v.job].canSee[PlayerData.job.name]

        if canSee then
            if myId ~= v.playerId then
                if cId ~= -1 then
                    if nearBlips[v.playerId] == nil then  -- switch/init blip from long to close proximity
                        if longBlips[v.playerId] then
                            RemoveBlip(longBlips[v.playerId].blip)
                            longBlips[v.playerId] = nil
                        end
                        nearBlips[v.playerId] = {}
                        nearBlips[v.playerId].blip = AddBlipForEntity(GetPlayerPed(cId))
                        setupBlip(nearBlips[v.playerId].blip, v)
                    end

                    if v.inVeh and not nearBlips[v.playerId].inVeh then -- entered veh blip setup
                        nearBlips[v.playerId].inVeh = true
                        vehBlipSetup(nearBlips[v.playerId].blip, v)
                    elseif not v.inVeh and nearBlips[v.playerId].inVeh then -- left veh blip
                        nearBlips[v.playerId].inVeh = false
                        vehBlipSetup(nearBlips[v.playerId].blip, v)
                    end

                    if v.siren and not nearBlips[v.playerId].siren then  -- turn on siren flash
                        nearBlips[v.playerId].siren = true
                        nearBlips[v.playerId].sirenState = 1
                    elseif not v.siren and nearBlips[v.playerId].siren then  -- turn on siren flash
                        nearBlips[v.playerId].siren = false
                        if v.inVeh then
                            vehBlipSetup(nearBlips[v.playerId].blip, v)
                        else
                            setupBlip(nearBlips[v.playerId].blip, v)
                        end
                    elseif nearBlips[v.playerId].siren then  -- blip color flash
                        nearBlips[v.playerId].sirenState = v.flashColors[nearBlips[v.playerId].sirenState + 1] and nearBlips[v.playerId].sirenState + 1 or 1
                        updateBlipFlash(nearBlips[v.playerId].blip, v.flashColors[nearBlips[v.playerId].sirenState])
                    end
                else
                    if longBlips[v.playerId] == nil then -- switch/init blip from close to long proximity
                        if nearBlips[v.playerId] then
                            RemoveBlip(nearBlips[v.playerId].blip)
                            nearBlips[v.playerId] = nil
                        end
                        longBlips[v.playerId] = {}
                        longBlips[v.playerId].blip = AddBlipForCoord(v.coords)
                        setupBlip(longBlips[v.playerId].blip, v)
                        if v.inVeh then
                            vehBlipSetup(longBlips[v.playerId].blip, v)
                        end
                    else
                        if longBlips[v.playerId] then
                            RemoveBlip(longBlips[v.playerId].blip)
                        end
                        longBlips[v.playerId].blip = AddBlipForCoord(v.coords)
                        setupBlip(longBlips[v.playerId].blip, v)
                        if v.inVeh then
                            vehBlipSetup(longBlips[v.playerId].blip, v)
                        end
                    end

                    if v.inVeh and not longBlips[v.playerId].inVeh then -- entered veh blip setup
                        longBlips[v.playerId].inVeh = true
                        vehBlipSetup(longBlips[v.playerId].blip, v)
                    elseif not v.inVeh and longBlips[v.playerId].inVeh then -- left veh blip
                        longBlips[v.playerId].inVeh = false
                        vehBlipSetup(longBlips[v.playerId].blip, v)
                    end

                    if v.siren and not longBlips[v.playerId].siren then -- turn on siren flash
                        longBlips[v.playerId].siren = true
                        longBlips[v.playerId].sirenState = 1
                    elseif not v.siren and longBlips[v.playerId].siren then  -- turn on siren flash
                        longBlips[v.playerId].siren = false
                        if v.inVeh then
                            vehBlipSetup(longBlips[v.playerId].blip, v)
                        else
                            setupBlip(longBlips[v.playerId].blip, v)
                        end
                    elseif longBlips[v.playerId].siren then -- blip color flash
                        longBlips[v.playerId].sirenState = v.flashColors[longBlips[v.playerId].sirenState + 1] and longBlips[v.playerId].sirenState + 1 or 1
                        updateBlipFlash(longBlips[v.playerId].blip, v.flashColors[longBlips[v.playerId].sirenState])
                    end
                end
            elseif Config.selfBlip then
                if myBlip.blip == nil then -- my blip setup
                    myBlip.blip = GetMainPlayerBlipId()

                    while myBlip.blip == nil do
                        Citizen.Wait(100)
                    end
                    setupBlip(myBlip.blip, v)
                end

                if v.inVeh and not myBlip.inVeh then -- casual veh stuff, like above
                    myBlip.inVeh = true
                    vehBlipSetup(myBlip.blip, v)
                elseif not v.inVeh and myBlip.inVeh then
                    myBlip.inVeh = false
                    vehBlipSetup(myBlip.blip, v)
                end

                if v.siren and not myBlip.siren then  -- turn on siren flash
                    myBlip.siren = true
                    myBlip.sirenState = 1
                elseif not v.siren and myBlip.siren then -- turn off siren flash
                    myBlip.siren = false
                    if v.inVeh then
                        vehBlipSetup(myBlip.blip, v)
                    else
                        setupBlip(myBlip.blip, v)
                    end
                elseif myBlip.siren then -- blip color flash
                    myBlip.sirenState = v.flashColors[myBlip.sirenState + 1] ~= nil and myBlip.sirenState + 1 or 1
                    updateBlipFlash(myBlip.blip, v.flashColors[myBlip.sirenState])
                end

                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(Config.usePrefix and v.prefix..' '..v.name or v.name)
                EndTextCommandSetBlipName(myBlip.blip)
            end
        end
    end
end)

function setupBlip(blip, data)
	SetBlipSprite(blip, Config.emergencyJobs[data.job].blip.sprite)
	SetBlipDisplay(blip, 2)
	SetBlipScale(blip, Config.emergencyJobs[data.job].blip.scale or 1.0)
	SetBlipColour(blip, Config.emergencyJobs[data.job].blip.color)
    SetBlipFlashes(blip, false)
    SetBlipShowCone(blip, Config.blipCone)
    SetBlipCategory(blip, 7)
	BeginTextCommandSetBlipName("STRING")
    if Config.font.useCustom then
        AddTextComponentString("<font face='"..Config.font.name.."'>"..data.prefix.." "..data.name.."</font>")
    else
        AddTextComponentString(Config.usePrefix and data.prefix..' '..data.name or data.name)
    end
	EndTextCommandSetBlipName(blip)
end

function vehBlipSetup(blip, data)
    if data.inVeh then
        SetBlipSprite(blip, data.vehSprite)
        SetBlipDisplay(blip, 2)
        SetBlipScale(blip, Config.emergencyJobs[data.job].blip.scale or 1.0)
        SetBlipColour(blip, data.vehColor)
        SetBlipShowCone(blip, Config.blipCone)
        BeginTextCommandSetBlipName("STRING")
        if Config.font.useCustom then
            AddTextComponentString("<font face='"..Config.font.name.."'>"..data.prefix.." "..data.name.."</font>")
        else
            AddTextComponentString(Config.usePrefix and data.prefix..' '..data.name or data.name)
        end
        EndTextCommandSetBlipName(blip)
        SetBlipCategory(blip, 7)
    else
        SetBlipSprite(blip, Config.emergencyJobs[data.job].blip.sprite)
        SetBlipDisplay(blip, 2)
        SetBlipScale(blip, Config.emergencyJobs[data.job].blip.scale or 1.0)
        SetBlipColour(blip, Config.emergencyJobs[data.job].blip.color)
        SetBlipShowCone(blip, Config.blipCone)
        BeginTextCommandSetBlipName("STRING")
        if Config.font.useCustom then
            AddTextComponentString("<font face='"..Config.font.name.."'>"..data.prefix.." "..data.name.."</font>")
        else
            AddTextComponentString(Config.usePrefix and data.prefix..' '..data.name or data.name)
        end
        EndTextCommandSetBlipName(blip)
        SetBlipCategory(blip, 7)
    end
end

function updateBlipFlash(blip, color)
    SetBlipColour(blip, color)
end

function restoreBlip(blip) -- idk better way, pls don't kill me bruh
    SetBlipSprite(blip, 6)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.7)
    SetBlipColour(blip, 0)
    SetBlipShowCone(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(GetPlayerName(PlayerId()))
    EndTextCommandSetBlipName(blip)
    SetBlipCategory(blip, 1)
end

-- there used to be "includes" function, F