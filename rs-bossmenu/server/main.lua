local ESX = exports['es_extended']:getSharedObject()
local RESOURCE = GetCurrentResourceName()

local function debugLog(...)
    if not Config.Debug then return end
    print(('[%s] [DEBUG]'):format(RESOURCE), ...)
end

local function getPlayer(src)
    return ESX.GetPlayerFromId(src)
end

local function getIdentifier(src)
    local xPlayer = getPlayer(src)
    if xPlayer and xPlayer.identifier then return xPlayer.identifier end
    return GetPlayerIdentifier(src, 0)
end

local function sendWebhook(title, description, color)
    if not Config.Webhook or Config.Webhook == '' then return end

    PerformHttpRequest(
        Config.Webhook,
        function(status)
            if status < 200 or status >= 300 then
                print(('[%s] [WARN] webhook status %s'):format(RESOURCE, status))
            end
        end,
        'POST',
        json.encode({
            username = Config.WebhookName or 'RS Bossmenu',
            embeds = {{
                title = title,
                description = description,
                color = color or 3447003,
                footer = { text = os.date('!%Y-%m-%d %H:%M:%S UTC') }
            }}
        }),
        { ['Content-Type'] = 'application/json' }
    )
end

local function ensureAccount(jobName)
    MySQL.insert.await(
        [[
            INSERT INTO rs_company_accounts (job_name, balance)
            VALUES (?, 0)
            ON DUPLICATE KEY UPDATE job_name = VALUES(job_name)
        ]],
        { jobName }
    )
end

local function getBalance(jobName)
    ensureAccount(jobName)

    return tonumber(MySQL.scalar.await(
        'SELECT balance FROM rs_company_accounts WHERE job_name = ? LIMIT 1',
        { jobName }
    )) or 0
end

local function isBoss(src, requestedJob)
    local xPlayer = getPlayer(src)
    if not xPlayer or not xPlayer.job then
        return false, nil
    end

    local job = xPlayer.job
    if requestedJob and requestedJob ~= '' and job.name ~= requestedJob then
        return false, xPlayer
    end

    if Config.RequireBossName then
        return tostring(job.grade_name or ''):lower() == 'boss', xPlayer
    end

    local highest = tonumber(MySQL.scalar.await(
        'SELECT MAX(grade) FROM job_grades WHERE job_name = ?',
        { job.name }
    )) or -1

    return tonumber(job.grade) == highest, xPlayer
end

local function logAction(src, jobName, action, targetIdentifier, details)
    local actor = getIdentifier(src)
    local payload = details or {}

    MySQL.insert(
        [[
            INSERT INTO rs_bossmenu_logs
            (job_name, identifier, actor_identifier, action, details)
            VALUES (?, ?, ?, ?, ?)
        ]],
        {
            jobName,
            targetIdentifier,
            actor,
            action,
            json.encode(payload)
        }
    )

    sendWebhook(
        'Bossmenu actie',
        ('**Actie:** %s\n**Job:** %s\n**Uitvoerder:** %s\n**Target:** %s'):format(
            action,
            jobName,
            GetPlayerName(src) or actor or 'Onbekend',
            targetIdentifier or '-'
        ),
        3447003
    )
end

local function buildState(src, requestedJob)
    local allowed, xPlayer = isBoss(src, requestedJob)
    if not allowed or not xPlayer then
        return nil, 'Je hebt geen toegang tot het baasmenu.'
    end

    local jobName = xPlayer.job.name
    ensureAccount(jobName)

    local employees = MySQL.query.await(
        [[
            SELECT
                u.identifier,
                COALESCE(u.firstname, '') AS firstname,
                COALESCE(u.lastname, '') AS lastname,
                u.job,
                u.job_grade,
                COALESCE(g.name, '') AS grade_name,
                COALESCE(g.label, '') AS grade_label
            FROM users u
            LEFT JOIN job_grades g
                ON g.job_name = u.job
               AND g.grade = u.job_grade
            WHERE u.job = ?
            ORDER BY u.job_grade DESC, u.identifier ASC
        ]],
        { jobName }
    ) or {}

    local grades = MySQL.query.await(
        [[
            SELECT grade, name, label, salary
            FROM job_grades
            WHERE job_name = ?
            ORDER BY grade ASC
        ]],
        { jobName }
    ) or {}

    local logs = MySQL.query.await(
        [[
            SELECT action, identifier, actor_identifier, details, created_at
            FROM rs_bossmenu_logs
            WHERE job_name = ?
            ORDER BY id DESC
            LIMIT 50
        ]],
        { jobName }
    ) or {}

    return {
        job = {
            name = jobName,
            label = xPlayer.job.label or jobName,
            grade = xPlayer.job.grade,
            grade_label = xPlayer.job.grade_label or xPlayer.job.grade_name
        },
        balance = getBalance(jobName),
        employees = employees,
        grades = grades,
        logs = logs
    }
end

ESX.RegisterServerCallback('rs_bossmenu:getState', function(src, cb, requestedJob)
    local state, err = buildState(src, requestedJob)
    cb({
        success = state ~= nil,
        message = err or '',
        data = state
    })
end)

ESX.RegisterServerCallback('rs_bossmenu:hire', function(src, cb, data)
    local allowed, boss = isBoss(src, data and data.jobName)
    if not allowed or not boss then
        return cb({ success = false, message = 'Geen toestemming.' })
    end

    local targetId = tonumber(data and data.serverId)
    if not targetId or targetId <= 0 or targetId == src then
        return cb({ success = false, message = 'Ongeldig server ID.' })
    end

    local target = getPlayer(targetId)
    if not target then
        return cb({ success = false, message = 'Speler is niet online.' })
    end

    local bossPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)

    if bossPed <= 0 or targetPed <= 0 then
        return cb({ success = false, message = 'Kon afstand niet controleren.' })
    end

    local a = GetEntityCoords(bossPed)
    local b = GetEntityCoords(targetPed)
    local distance = #(a - b)

    if distance > (tonumber(Config.HireDistance) or 5.0) then
        return cb({ success = false, message = 'Speler staat te ver weg.' })
    end

    target.setJob(boss.job.name, 0)

    logAction(src, boss.job.name, 'hire', target.identifier, {
        serverId = targetId,
        distance = distance
    })

    cb({ success = true, message = 'Medewerker aangenomen.' })
end)

ESX.RegisterServerCallback('rs_bossmenu:setGrade', function(src, cb, data)
    local allowed, boss = isBoss(src, data and data.jobName)
    if not allowed or not boss then
        return cb({ success = false, message = 'Geen toestemming.' })
    end

    local identifier = tostring(data and data.identifier or '')
    local grade = tonumber(data and data.grade)

    if identifier == '' or grade == nil then
        return cb({ success = false, message = 'Ongeldige medewerker/rang.' })
    end

    local gradeRow = MySQL.single.await(
        'SELECT grade, name FROM job_grades WHERE job_name = ? AND grade = ? LIMIT 1',
        { boss.job.name, grade }
    )

    if not gradeRow then
        return cb({ success = false, message = 'Rang bestaat niet.' })
    end

    -- Bescherm tegen een tweede boss als de server dat niet wil:
    if tostring(gradeRow.name or ''):lower() == 'boss'
        and identifier ~= boss.identifier then
        return cb({
            success = false,
            message = 'De boss-rang kan alleen handmatig via beheer worden toegewezen.'
        })
    end

    local targetOnline = nil
    for _, playerId in ipairs(ESX.GetPlayers()) do
        local xTarget = getPlayer(playerId)
        if xTarget and xTarget.identifier == identifier then
            targetOnline = xTarget
            break
        end
    end

    if targetOnline then
        if not targetOnline.job or targetOnline.job.name ~= boss.job.name then
            return cb({ success = false, message = 'Speler hoort niet meer bij deze job.' })
        end

        targetOnline.setJob(boss.job.name, grade)
    else
        local changed = MySQL.update.await(
            'UPDATE users SET job_grade = ? WHERE identifier = ? AND job = ?',
            { grade, identifier, boss.job.name }
        )

        if not changed or changed < 1 then
            return cb({ success = false, message = 'Medewerker niet gevonden.' })
        end
    end

    logAction(src, boss.job.name, 'set_grade', identifier, { grade = grade })

    cb({ success = true, message = 'Rang gewijzigd.' })
end)

ESX.RegisterServerCallback('rs_bossmenu:fire', function(src, cb, data)
    local allowed, boss = isBoss(src, data and data.jobName)
    if not allowed or not boss then
        return cb({ success = false, message = 'Geen toestemming.' })
    end

    local identifier = tostring(data and data.identifier or '')
    if identifier == '' or identifier == boss.identifier then
        return cb({ success = false, message = 'Deze medewerker kan niet worden ontslagen.' })
    end

    local targetOnline = nil
    for _, playerId in ipairs(ESX.GetPlayers()) do
        local xTarget = getPlayer(playerId)
        if xTarget and xTarget.identifier == identifier then
            targetOnline = xTarget
            break
        end
    end

    if targetOnline then
        if not targetOnline.job or targetOnline.job.name ~= boss.job.name then
            return cb({ success = false, message = 'Speler hoort niet meer bij deze job.' })
        end
        targetOnline.setJob('unemployed', 0)
    else
        local changed = MySQL.update.await(
            [[
                UPDATE users
                SET job = 'unemployed', job_grade = 0
                WHERE identifier = ? AND job = ?
            ]],
            { identifier, boss.job.name }
        )

        if not changed or changed < 1 then
            return cb({ success = false, message = 'Medewerker niet gevonden.' })
        end
    end

    logAction(src, boss.job.name, 'fire', identifier, {})

    cb({ success = true, message = 'Medewerker ontslagen.' })
end)

ESX.RegisterServerCallback('rs_bossmenu:deposit', function(src, cb, data)
    local allowed, boss = isBoss(src, data and data.jobName)
    if not allowed or not boss then
        return cb({ success = false, message = 'Geen toestemming.' })
    end

    local amount = math.floor(tonumber(data and data.amount) or 0)
    local maxAmount = tonumber(Config.MaxTransaction) or 1000000

    if amount < 1 or amount > maxAmount then
        return cb({ success = false, message = 'Ongeldig bedrag.' })
    end

    local bank = boss.getAccount('bank')
    if not bank or bank.money < amount then
        return cb({ success = false, message = 'Onvoldoende bankgeld.' })
    end

    boss.removeAccountMoney('bank', amount)

    MySQL.update.await(
        'UPDATE rs_company_accounts SET balance = balance + ? WHERE job_name = ?',
        { amount, boss.job.name }
    )

    logAction(src, boss.job.name, 'deposit', boss.identifier, { amount = amount })

    cb({ success = true, message = ('€%s gestort.'):format(amount) })
end)

ESX.RegisterServerCallback('rs_bossmenu:withdraw', function(src, cb, data)
    local allowed, boss = isBoss(src, data and data.jobName)
    if not allowed or not boss then
        return cb({ success = false, message = 'Geen toestemming.' })
    end

    local amount = math.floor(tonumber(data and data.amount) or 0)
    local maxAmount = tonumber(Config.MaxTransaction) or 1000000

    if amount < 1 or amount > maxAmount then
        return cb({ success = false, message = 'Ongeldig bedrag.' })
    end

    local balance = getBalance(boss.job.name)
    if balance < amount then
        return cb({ success = false, message = 'Onvoldoende bedrijfsbalans.' })
    end

    local changed = MySQL.update.await(
        [[
            UPDATE rs_company_accounts
            SET balance = balance - ?
            WHERE job_name = ? AND balance >= ?
        ]],
        { amount, boss.job.name, amount }
    )

    if not changed or changed < 1 then
        return cb({ success = false, message = 'Transactie kon niet worden uitgevoerd.' })
    end

    boss.addAccountMoney('bank', amount)

    logAction(src, boss.job.name, 'withdraw', boss.identifier, { amount = amount })

    cb({ success = true, message = ('€%s opgenomen.'):format(amount) })
end)

print(('[%s] [OK] RS Bossmenu gestart.'):format(RESOURCE))
