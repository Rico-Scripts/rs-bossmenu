local ESX = exports['es_extended']:getSharedObject()

local menuOpen = false
local currentJob = nil

local function notify(message, success)
    if lib and lib.notify then
        lib.notify({
            title = 'Baasmenu',
            description = tostring(message or ''),
            type = success == false and 'error' or 'success'
        })
        return
    end

    ESX.ShowNotification(tostring(message or ''))
end

local function requestState(jobName, cb)
    ESX.TriggerServerCallback(
        'rs_bossmenu:getState',
        function(response)
            cb(response or {
                success = false,
                message = 'Geen antwoord van de server.'
            })
        end,
        jobName
    )
end

local function openBossMenu(jobName)
    if menuOpen then return end

    requestState(jobName, function(response)
        if not response.success then
            return notify(response.message or 'Geen toegang.', false)
        end

        currentJob = response.data.job.name
        menuOpen = true

        SetNuiFocus(true, true)

        SendNUIMessage({
            action = 'open',
            data = response.data
        })
    end)
end

RegisterNetEvent('rs-bossmenu:client:open', function(jobName)
    openBossMenu(jobName)
end)

RegisterNUICallback('close', function(_, cb)
    menuOpen = false
    currentJob = nil
    SetNuiFocus(false, false)
    cb({ success = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    if not currentJob then
        return cb({ success = false, message = 'Geen job geopend.' })
    end

    requestState(currentJob, cb)
end)

local function proxy(name)
    RegisterNUICallback(name, function(data, cb)
        data = type(data) == 'table' and data or {}
        data.jobName = currentJob

        ESX.TriggerServerCallback(
            'rs_bossmenu:' .. name,
            function(response)
                cb(response or {
                    success = false,
                    message = 'Geen antwoord van de server.'
                })
            end,
            data
        )
    end)
end

proxy('hire')
proxy('setGrade')
proxy('fire')
proxy('deposit')
proxy('withdraw')

exports('OpenBossMenu', function(jobName)
    openBossMenu(jobName)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)
