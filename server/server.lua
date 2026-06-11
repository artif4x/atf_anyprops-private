local qbx = exports.qbx_core
local WebhookURL = Config.System.WebhookURL
local activePickups = {} -- ตารางป้องกันปั๊มของ
local serverPropsMetadata = {} -- ตารางเก็บข้อมูลอาวุธ

-- Discord Logs (Queue System ป้องกัน Rate Limit)
local webhookQueue = {}
local isWebhookProcessing = false

local function processWebhookQueue()
    if isWebhookProcessing or #webhookQueue == 0 then return end
    isWebhookProcessing = true
    CreateThread(function()
        while #webhookQueue > 0 do
            local payload = table.remove(webhookQueue, 1)
            local currentWebhook = Config.System.WebhookURL
            if currentWebhook and currentWebhook ~= "" and currentWebhook ~= "ใส่_LINK_WEBHOOK_ของคุณที่นี่" then
                PerformHttpRequest(currentWebhook, function(err, text, headers) end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
            end
            Wait(1200) 
        end
        isWebhookProcessing = false
    end)
end

-- Discord Log
local function sendDiscordLog(src, title, actionMessage, color)
    local currentWebhook = Config.System.WebhookURL
    if currentWebhook == "" or currentWebhook == "ใส่_LINK_WEBHOOK_ของคุณที่นี่" then return end

    -- ข้อมูลพื้นฐาน OOC
    local playerName = GetPlayerName(src) or "ไม่ทราบชื่อ"
    
    -- ข้อมูลตัวละคร IC (ดึงจาก Qbox / QBCore)
    local charName = "ไม่พบข้อมูลตัวละคร"
    local citizenId = "N/A"
    local Player = exports.qbx_core:GetPlayer(src)
    if Player then
        charName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
        citizenId = Player.PlayerData.citizenid
    end

    -- คัดแยก Identifiers (Steam, Discord, License, IP)
    local ids = { steam = "N/A", discord = "N/A", license = "N/A", license2 = "N/A", ip = "N/A" }
    for _, v in ipairs(GetPlayerIdentifiers(src)) do
        if string.sub(v, 1, 6) == "steam:" then ids.steam = v
        elseif string.sub(v, 1, 8) == "discord:" then ids.discord = string.sub(v, 9)
        elseif string.sub(v, 1, 8) == "license:" then ids.license = v
        elseif string.sub(v, 1, 9) == "license2:" then ids.license2 = v
        elseif string.sub(v, 1, 3) == "ip:" then ids.ip = string.sub(v, 4)
        end
    end

    -- แปลง Steam Hex เป็น Steam Decimal เพื่อสร้าง URL
    local steamURL = "N/A"
    if ids.steam ~= "N/A" then
        local hex = string.gsub(ids.steam, "steam:", "")
        local dec = tostring(tonumber(hex, 16))
        steamURL = "[คลิกเพื่อดูโปรไฟล์](https://steamcommunity.com/profiles/" .. dec .. ")"
    end

    -- สร้าง Tag ให้กด Mention หา Discord
    local discordTag = ids.discord ~= "N/A" and ("<@" .. ids.discord .. ">") or "N/A"

    -- Discord Embed 
    local embed = {
        {
            ["title"] = title,
            ["description"] = "**รายละเอียดการกระทำ:**\n" .. actionMessage .. "\n",
            ["color"] = color,
            ["fields"] = {
                { ["name"] = "ตัวละคร (IC)", ["value"] = "ชื่อ: **" .. charName .. "**\nCitizen ID: **" .. citizenId .. "**", ["inline"] = true },
                { ["name"] = "ผู้เล่น (OOC)", ["value"] = "ชื่อสตรีม: **" .. playerName .. "**\nID ในเกม: **" .. src .. "**", ["inline"] = true },
                { ["name"] = "Discord", ["value"] = discordTag .. "\n(" .. ids.discord .. ")", ["inline"] = true },
                
                { ["name"] = "Steam ID", ["value"] = ids.steam, ["inline"] = true },
                { ["name"] = "Steam Link", ["value"] = steamURL, ["inline"] = true },
                { ["name"] = "IP Address", ["value"] = "||" .. ids.ip .. "||", ["inline"] = true }, 
                
                { ["name"] = "License", ["value"] = ids.license, ["inline"] = false },
                { ["name"] = "License 2", ["value"] = ids.license2, ["inline"] = false }
            },
            ["footer"] = { 
                ["text"] = "ATF Anyprops",
            },
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ") 
        }
    }

    table.insert(webhookQueue, {username = "Props Log", embeds = embed})
    processWebhookQueue()
end

-- Initialization
for itemName, _ in pairs(Config.Items) do
    qbx:CreateUseableItem(itemName, function(source, item)
        TriggerClientEvent('atf_anyprops:client:toggleProp', source, itemName, item.metadata, item.slot)
    end)
end

-- Core Net Event
RegisterNetEvent('atf_anyprops:server:placeProp', function(itemName, coords, rot, attachData, isUnattachedDrop, metadata, slot, amount)
    if type(coords) ~= 'vector3' or type(rot) ~= 'vector3' then return end

    local src = source

    amount = math.floor(tonumber(amount) or 1)
    if amount < 1 then 
        DropPlayer(src, "ระบบตรวจพบการส่งค่าจำนวนไอเทมผิดปกติ (Payload Injection)")
        return 
    end
    
    -- Security ตรวจสอบระยะการวางไอเทม
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local distance = #(playerCoords - coords)
    
    local safeBuffer = Config.Distance.Placement + 2.0  -- เกินนิดหน่อย จะขึ้นแจ้งเตือน
    local exploitBuffer = Config.Distance.Placement + 30.0 -- ไกลเกิน ต้องสงสัยว่าโปรจะแจ้ง Log แล้วเตะก่อน ไม่แบน

    if distance > exploitBuffer then 
        sendDiscordLog(src, "⚠️ ตรวจพบการวางของผิดปกติ (Placement Exploit)", "พยายามวางไอเทม: **" .. itemName .. "**\nระยะห่าง: **" .. math.floor(distance) .. "** เมตร (เกินกำหนดจากที่ตั้งไว้)", 16711680)
        DropPlayer(src, "ระบบตรวจพบการพยายามวางไอเทมนอกระยะที่กำหนด (Exploit)")
        return 
    elseif distance > safeBuffer then
        TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'ตำแหน่งวางของอยู่ไกลเกินไป'})
        return
    end

    if attachData and attachData.vehNetId then
        local vehEntity = NetworkGetEntityFromNetworkId(attachData.vehNetId)
        if DoesEntityExist(vehEntity) and GetEntityType(vehEntity) == 2 then
            local vehCoords = GetEntityCoords(vehEntity)
            local vehDist = #(playerCoords - vehCoords)
            if vehDist > exploitBuffer then
                sendDiscordLog(src, "⚠️ ตรวจพบการพยายามแปะของติดรถข้ามแมพ (Vehicle Attach Exploit)", "พยายามแปะไอเทม: **" .. itemName .. "**\nระยะห่างจากรถ: **" .. math.floor(vehDist) .. "** เมตร", 16711680)
                DropPlayer(src, "ระบบตรวจพบการพยายามแปะไอเทมติดรถนอกระยะที่กำหนด (Exploit)")
                return
            end
        else
            -- ถ้ารถไม่มีอยู่จริงบนเซิร์ฟเวอร์ ให้ยกเลิกการติดรถ ป้องกันบัค
            attachData = nil 
        end
    end

    amount = amount or 1
    local itemData = Config.Items[itemName]
    
    local modelToSpawn = itemData and joaat(itemData.prop)
    if not modelToSpawn and attachData and attachData.customModelHash then
        modelToSpawn = attachData.customModelHash
    end
    
    if not modelToSpawn then return end

    local targetSlot = slot
    if amount > 1 then targetSlot = nil end

    local actualMetadata = metadata
    if targetSlot then
        local slotData = exports.ox_inventory:GetSlot(src, targetSlot)
        if slotData and slotData.name == itemName then
            actualMetadata = slotData.metadata or {}
        end
    end
    
    local success = exports.ox_inventory:RemoveItem(src, itemName, amount, actualMetadata, targetSlot)
    
    if success then
        local entity = CreateObjectNoOffset(modelToSpawn, coords.x, coords.y, coords.z, true, true, false)
        if not entity or entity == 0 then
            exports.ox_inventory:AddItem(src, itemName, amount, actualMetadata, targetSlot)
            TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'ไม่สามารถสร้างโมเดลนี้ได้ (คืนไอเทมแล้ว)'})
            return
        end 
        
        Entity(entity).state.isAtfProp = true
        Entity(entity).state.placedItemName = itemName
        -- เก็บตัวเต็มไว้ใน Server Memory
        local netId = NetworkGetNetworkIdFromEntity(entity)
        serverPropsMetadata[netId] = actualMetadata

        -- ส่งไปให้ Client เฉพาะข้อมูลที่จำเป็นต้องใช้โหลดโมเดลของแต่งปืน
        if actualMetadata and (actualMetadata.components or actualMetadata.tint) then
            Entity(entity).state.renderData = { components = actualMetadata.components, tint = actualMetadata.tint }
        end
        Entity(entity).state.itemAmount = amount
        Entity(entity).state.collision = (itemData and itemData.collision ~= false) or true
        
        -- บังคับให้การวางของบนพื้นติด Freeze เสมอ
        local shouldFreeze = true 
        if itemData and itemData.freeze ~= nil then
            shouldFreeze = itemData.freeze
        end
        if isUnattachedDrop then shouldFreeze = false end
        Entity(entity).state.freeze = shouldFreeze

        if attachData and attachData.vehNetId then
            Entity(entity).state:set('attachData', attachData, true)
        else
            SetEntityCoords(entity, coords.x, coords.y, coords.z, false, false, false, false)
            SetEntityRotation(entity, rot.x, rot.y, rot.z, 2, true)
            FreezeEntityPosition(entity, shouldFreeze)
        end
        
        sendDiscordLog(src, "📦 ผู้เล่นวางไอเทม", "ไอเทม: **" .. itemName .. "**\nจำนวน: **" .. amount .. "** ชิ้น\nพิกัด (X, Y, Z): `" .. string.format("%.2f, %.2f, %.2f", coords.x, coords.y, coords.z) .. "`", 3066993) -- สีเขียว
        TriggerClientEvent('ox_lib:notify', src, {title = 'ระบบ', description = 'วางของเรียบร้อย', type = 'success'})
    else
        TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'ไม่สามารถลบไอเทมออกจากกระเป๋าได้ (อาจเป็นบัคของคลังอาวุธ)'})
    end
end)

RegisterNetEvent('atf_anyprops:server:placeWeaponProp', function(itemName, netId, coords, rot, attachData, isUnattachedDrop, clientMetadata, slot, amount)
    if type(coords) ~= 'vector3' or type(rot) ~= 'vector3' then return end

    local src = source

    amount = math.floor(tonumber(amount) or 1)
    if amount < 1 then 
        DropPlayer(src, "ระบบตรวจพบการส่งค่าจำนวนไอเทมผิดปกติ (Payload Injection)")
        return 
    end
    
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local distance = #(playerCoords - coords)
    
    local safeBuffer = Config.Distance.Placement + 2.0
    local exploitBuffer = Config.Distance.Placement + 30.0

    if distance > exploitBuffer then 
        sendDiscordLog(src, "⚠️ ตรวจพบการวางอาวุธผิดปกติ (Weapon Exploit)", "พยายามวางอาวุธ: **" .. itemName .. "**\nระยะห่าง: **" .. math.floor(distance) .. "** เมตร (เกินกำหนดจากที่ตั้งไว้)", 16711680)
        DropPlayer(src, "ระบบตรวจพบการพยายามวางอาวุธนอกระยะที่กำหนด (Exploit)")
        return 
    elseif distance > safeBuffer then
        TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'ตำแหน่งวางอาวุธอยู่ไกลเกินไป'})
        return
    end

    if attachData and attachData.vehNetId then
        local vehEntity = NetworkGetEntityFromNetworkId(attachData.vehNetId)
        if DoesEntityExist(vehEntity) and GetEntityType(vehEntity) == 2 then
            local vehCoords = GetEntityCoords(vehEntity)
            local vehDist = #(playerCoords - vehCoords)
            if vehDist > exploitBuffer then
                sendDiscordLog(src, "⚠️ ตรวจพบการพยายามแปะอาวุธติดรถข้ามแมพ (Vehicle Attach Exploit)", "พยายามแปะอาวุธ: **" .. itemName .. "**\nระยะห่างจากรถ: **" .. math.floor(vehDist) .. "** เมตร", 16711680)
                DropPlayer(src, "ระบบตรวจพบการพยายามแปะอาวุธติดรถนอกระยะที่กำหนด (Exploit)")
                return
            end
        else
            attachData = nil 
        end
    end

    amount = amount or 1
    local targetSlot = slot
    
    local actualMetadata = clientMetadata
    if targetSlot then
        local slotData = exports.ox_inventory:GetSlot(src, targetSlot)
        if slotData and slotData.name == itemName then
            actualMetadata = slotData.metadata or {}
        end
    end

    local success = exports.ox_inventory:RemoveItem(src, itemName, amount, actualMetadata, targetSlot)
    
    if success then
        local entity = NetworkGetEntityFromNetworkId(netId)
        local timeout = 0
        while not DoesEntityExist(entity) and timeout < 20 do
            Wait(100)
            entity = NetworkGetEntityFromNetworkId(netId)
            timeout = timeout + 1
        end

        if DoesEntityExist(entity) then
            
            if GetEntityType(entity) ~= 3 then
                sendDiscordLog(src, "⚠️ ตรวจพบ NetID Spoofing (Entity Type)", "พยายามส่ง NetID ของสิ่งที่ไม่ได้เป็น Prop มาเป็นอาวุธ", 16711680)
                DropPlayer(src, "ระบบตรวจพบการส่งข้อมูล Entity ผิดปกติ (Exploit)")
                return
            end

            if NetworkGetEntityOwner(entity) ~= src then
                if Entity(entity).state.isAtfProp then
                    sendDiscordLog(src, "⚠️ ตรวจพบการพยายามลบของคนอื่น (Weaponized Deletion)", "พยายามส่ง NetID ของไอเทมที่วางอยู่แล้วมาเพื่อลบทิ้ง/สวมรอย", 16711680)
                    DropPlayer(src, "ระบบตรวจพบการพยายามสวมรอย Entity (Exploit)")
                    return
                end

                exports.ox_inventory:AddItem(src, itemName, amount, actualMetadata, targetSlot)
                TriggerClientEvent('atf_anyprops:client:deleteFailedProp', src, netId)
                TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'เซิร์ฟเวอร์ซิงค์ข้อมูลไม่ทัน กรุณาเก็บแล้ววางใหม่อีกครั้ง'})
                sendDiscordLog(src, "⚠️ Entity Owner Mismatch", "พบการส่ง NetID ที่ตัวเองไม่ได้เป็นเจ้าของ\n(คืนไอเทมและสั่งลบโมเดลผีทิ้งแล้ว)", 16711680)
                return
            end

            Entity(entity).state.isAtfProp = true
            Entity(entity).state.placedItemName = itemName
            local finalNetId = NetworkGetNetworkIdFromEntity(entity)
            serverPropsMetadata[finalNetId] = actualMetadata

            if actualMetadata and (actualMetadata.components or actualMetadata.tint) then
                Entity(entity).state.renderData = { components = actualMetadata.components, tint = actualMetadata.tint }
            end
            Entity(entity).state.itemAmount = amount
            Entity(entity).state.collision = true
            
            local shouldFreeze = true 
            if isUnattachedDrop then shouldFreeze = false end
            Entity(entity).state.freeze = shouldFreeze

            if attachData and attachData.vehNetId then
                Entity(entity).state:set('attachData', attachData, true)
            else
                SetEntityCoords(entity, coords.x, coords.y, coords.z, false, false, false, false)
                SetEntityRotation(entity, rot.x, rot.y, rot.z, 2, true)
                FreezeEntityPosition(entity, shouldFreeze)
            end

            sendDiscordLog(src, "🔫 ผู้เล่นวางอาวุธ", "อาวุธ: **" .. itemName .. "**\nพิกัด (X, Y, Z): `" .. string.format("%.2f, %.2f, %.2f", coords.x, coords.y, coords.z) .. "`", 15105570)
            TriggerClientEvent('ox_lib:notify', src, {title = 'ระบบ', description = 'วางอาวุธเรียบร้อย', type = 'success'})
        else
            -- 🟢 ถ้าโหลดโมเดลไม่ทันจริงๆ จะลบ Prop ผีฝั่ง Client ทิ้ง และคืนของเข้าตัว
            exports.ox_inventory:AddItem(src, itemName, amount, actualMetadata, targetSlot)
            TriggerClientEvent('atf_anyprops:client:deleteFailedProp', src, netId)
            TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'เซิร์ฟเวอร์โหลดโมเดลไม่ทัน (คืนไอเทมแล้ว)'})
        end
    else
        TriggerClientEvent('atf_anyprops:client:deleteFailedProp', src, netId)
        TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'ไม่สามารถลบไอเทมออกจากกระเป๋าได้'})
    end
end)

RegisterNetEvent('atf_anyprops:server:detachProp', function(netId)
    local src = source
    local entity = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(entity) and Entity(entity).state.isAtfProp then
        
        -- ตรวจสอบระยะห่าง ป้องกันโปร
        local playerPed = GetPlayerPed(src)
        local playerCoords = GetEntityCoords(playerPed)
        local propCoords = GetEntityCoords(entity)
        if #(playerCoords - propCoords) > 20.0 then 
            return -- ไกลเกินไป ยกเลิกการทำงาน
        end
        
        Entity(entity).state:set('attachData', nil, true)
        Entity(entity).state:set('freeze', false, true) 
        FreezeEntityPosition(entity, false) 
    end
end)

local function processPickupLogic(src, netId, reqAmount, isMassPickup)
    if activePickups[netId] then return false end 
    activePickups[netId] = true 

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) or not Entity(entity).state.isAtfProp then 
        activePickups[netId] = nil
        return false 
    end
    
    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)
    local propCoords = GetEntityCoords(entity)
    
    local isStaff = exports.qbx_core:HasPermission(src, 'admin') or exports.qbx_core:HasPermission(src, 'mod')
    
    -- ถ้าไม่ใช่แอดมินสั่งเก็บของ ให้เช็คระยะกันโปร
    if not isMassPickup and not isStaff and #(playerCoords - propCoords) > Config.Distance.ServerCheck then 
        activePickups[netId] = nil
        return false 
    end

    local itemName = Entity(entity).state.placedItemName
    local metadata = serverPropsMetadata[netId]
    local actualAmountOnGround = Entity(entity).state.itemAmount or 1
    
    reqAmount = math.floor(tonumber(reqAmount) or actualAmountOnGround)
    if reqAmount > actualAmountOnGround then reqAmount = actualAmountOnGround end
    if reqAmount <= 0 then 
        activePickups[netId] = nil
        return false 
    end
    
    if itemName then
        local canCarryAmount = 0
        for i = reqAmount, 1, -1 do
            if exports.ox_inventory:CanCarryItem(src, itemName, i, metadata) then
                canCarryAmount = i
                break
            end
        end

        if canCarryAmount > 0 then
            if canCarryAmount == actualAmountOnGround then 
                DeleteEntity(entity)
                serverPropsMetadata[netId] = nil
            else 
                Entity(entity).state.itemAmount = actualAmountOnGround - canCarryAmount 
            end
            
            exports.ox_inventory:AddItem(src, itemName, canCarryAmount, metadata)
            TriggerClientEvent('atf_anyprops:client:pickupMeCommand', src, itemName, canCarryAmount)
            
            if canCarryAmount < reqAmount then
                sendDiscordLog(src, "🖐️ เก็บไอเทม/อาวุธ (กระเป๋าเต็ม เก็บไม่หมด)", "ไอเทม: **" .. itemName .. "**\nจำนวนที่เก็บเข้ากระเป๋า: **" .. canCarryAmount .. "** ชิ้น\nพิกัด (X, Y, Z): `" .. string.format("%.2f, %.2f, %.2f", propCoords.x, propCoords.y, propCoords.z) .. "`", 3447003) 
                if not isMassPickup then TriggerClientEvent('ox_lib:notify', src, {type = 'warning', description = 'เก็บได้แค่ ' .. canCarryAmount .. ' ชิ้น (กระเป๋าเต็ม)'}) end
            else
                sendDiscordLog(src, "🖐️ เก็บไอเทม/อาวุธ สำเร็จ", "ไอเทม: **" .. itemName .. "**\nจำนวนที่เก็บเข้ากระเป๋า: **" .. canCarryAmount .. "** ชิ้น\nพิกัด (X, Y, Z): `" .. string.format("%.2f, %.2f, %.2f", propCoords.x, propCoords.y, propCoords.z) .. "`", 3447003) 
                if not isMassPickup then TriggerClientEvent('ox_lib:notify', src, {type = 'success', description = 'เก็บของขึ้นมา ' .. canCarryAmount .. ' ชิ้น'}) end
            end
            
            SetTimeout(500, function() activePickups[netId] = nil end)
            return true
        else
            if not isMassPickup then TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'ไม่สามารถเก็บได้เลย (กระเป๋าเต็ม)'}) end
        end
    end
    
    SetTimeout(500, function() activePickups[netId] = nil end)
    return false
end

-- รับคำสั่งจากผู้เล่นปกติ
RegisterNetEvent('atf_anyprops:server:pickupProp', function(netId, reqAmount)
    processPickupLogic(source, netId, reqAmount, false)
end)

RegisterNetEvent('atf_anyprops:server:transferProp', function(targetSrc, itemName, clientMetadata, slot)
    local src = source
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetSrc)
    if #(GetEntityCoords(playerPed) - GetEntityCoords(targetPed)) > Config.Distance.ServerCheck then return end

    local actualMetadata = clientMetadata
    if slot then
        local slotData = exports.ox_inventory:GetSlot(src, slot)
        if slotData and slotData.name == itemName then
            actualMetadata = slotData.metadata or {}
        end
    end

    if exports.ox_inventory:RemoveItem(src, itemName, 1, actualMetadata, slot) then
        if exports.ox_inventory:AddItem(targetSrc, itemName, 1, actualMetadata) then
            TriggerClientEvent('atf_anyprops:client:toggleProp', targetSrc, itemName, actualMetadata, nil)
        else
            exports.ox_inventory:AddItem(src, itemName, 1, actualMetadata)
            TriggerClientEvent('ox_lib:notify', src, {type = 'error', description = 'กระเป๋าเป้าหมายเต็ม'})
        end
    end
end)

-- DEV Commands
-- ไว้ปรับตำแหน่ง Props เอาค่าจาก F8 ใส่ Config
lib.addCommand('editprop', {
    help = 'เปิดโหมดปรับแต่งตำแหน่ง Prop (Admin / Mod)',
    restricted = { 'group.admin', 'group.mod' }
}, function(source, args, raw)
    TriggerClientEvent('atf_anyprops:client:toggleEditor', source)
end)

-- Stress Test ทดสอบ Spawn ของจำนวนมากในทีเดียว
RegisterCommand('prop_test_spawn', function(source, args)
    local player = exports.qbx_core:GetPlayer(source)
    if player and (exports.qbx_core:HasPermission(source, 'admin') or exports.qbx_core:HasPermission(source, 'mod')) then
        local count = tonumber(args[1]) or 50
        local ped = GetPlayerPed(source)
        local coords = GetEntityCoords(ped)
        
        for i = 1, count do
            local spawnX = coords.x + math.random(-10, 10)
            local spawnY = coords.y + math.random(-10, 10)
            local propName = 'prop_traffic_cone' 
            local itemData = Config.Items[propName]
            
            local entity = CreateObjectNoOffset(joaat(itemData.prop), spawnX, spawnY, coords.z, true, true, false)
            if entity and entity ~= 0 then 
                Entity(entity).state.isAtfProp = true
                Entity(entity).state.placedItemName = propName
                Entity(entity).state.itemAmount = 1 
                Entity(entity).state.collision = true
                Entity(entity).state.freeze = false
            end
        end
        print('^2[Stress Test] เสกของจำนวน ' .. count .. ' ชิ้นเสร็จสิ้น^7')
    else
        print('^1[Error] คุณไม่มีสิทธิ์ใช้งานคำสั่งนี้^7')
    end
end, false)

-- Stress Test ทดสอบเก็บของพร้อมกันในรัศมีที่กำหนด
RegisterCommand('prop_mass_pickup', function(source, args)
    local src = source
    if exports.qbx_core:HasPermission(src, 'admin') or exports.qbx_core:HasPermission(src, 'mod') then
        local radius = tonumber(args[1]) or 5.0 
        local playerPed = GetPlayerPed(src)
        local playerCoords = GetEntityCoords(playerPed)
        local count = 0
        local loopIndex = 0 -- ตัวนับจำนวนรอบลูปทั้งหมด
        
        local objects = GetAllObjects()
        for _, obj in ipairs(objects) do
            loopIndex = loopIndex + 1
            
            if loopIndex % 100 == 0 then Wait(0) end
            
            if Entity(obj).state.isAtfProp then
                local propCoords = GetEntityCoords(obj)
                if #(playerCoords - propCoords) <= radius then
                    local netId = NetworkGetNetworkIdFromEntity(obj)
                    if netId ~= 0 then
                        local amount = Entity(obj).state.itemAmount or 1
                        
                        if processPickupLogic(src, netId, amount, true) then
                            count = count + 1
                            if count % 10 == 0 then Wait(10) end 
                        end
                    end
                end
            end
        end
        
        if count > 0 then
            TriggerClientEvent('ox_lib:notify', src, {type = 'success', description = 'กวาดเก็บไอเทมสำเร็จ '..count..' ชิ้น (รัศมี '..radius..'ม.)'})
        else
            TriggerClientEvent('ox_lib:notify', src, {type = 'warning', description = 'ไม่พบไอเทมในรัศมี '..radius..' เมตร'})
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'คุณไม่มีสิทธิ์ใช้งานคำสั่งนี้', type = 'error'})
    end
end, false)

-- Admin Command ลบ Prop จาก Script นี้รอบๆ ตัวในระยะที่กำหนด
RegisterCommand('prop_mass_delete', function(source, args)
    local src = source
    if exports.qbx_core:HasPermission(src, 'admin') or exports.qbx_core:HasPermission(src, 'mod') then
        local radius = tonumber(args[1]) or 5.0 
        local playerPed = GetPlayerPed(src)
        local playerCoords = GetEntityCoords(playerPed)
        local count = 0
        local loopIndex = 0
        
        local objects = GetAllObjects()
        for _, obj in ipairs(objects) do
            loopIndex = loopIndex + 1
            if loopIndex % 100 == 0 then Wait(0) end -- ป้องกันเซิร์ฟเวอร์กระตุก
            
            if Entity(obj).state.isAtfProp then
                local propCoords = GetEntityCoords(obj)
                if #(playerCoords - propCoords) <= radius then
                local netId = NetworkGetNetworkIdFromEntity(obj)
                    if netId and netId ~= 0 and serverPropsMetadata[netId] then
                        serverPropsMetadata[netId] = nil
                    end
                    
                    DeleteEntity(obj)
                    count = count + 1
                end
            end
        end
        
        if count > 0 then
            sendDiscordLog(src, "🧹 Admin เคลียร์พื้นที่", "ลบ Prop ทิ้งจำนวน: **" .. count .. "** ชิ้น\nรัศมี: **" .. radius .. "** เมตร", 16711680)
            TriggerClientEvent('ox_lib:notify', src, {type = 'success', description = 'ลบ Prop รอบๆ จาก atf_anyprops ทิ้ง '..count..' ชิ้น (รัศมี '..radius..'ม.)'})
        else
            TriggerClientEvent('ox_lib:notify', src, {type = 'warning', description = 'ไม่พบ Prop ในรัศมี '..radius..' เมตร'})
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {title = 'Error', description = 'คุณไม่มีสิทธิ์ใช้งานคำสั่งนี้', type = 'error'})
    end
end, false)

-- Debug แสดงจุดสีแดง
RegisterCommand('atf_debug', function(source, args)
    if exports.qbx_core:HasPermission(source, 'admin') or exports.qbx_core:HasPermission(source, 'mod') then
        TriggerClientEvent('atf_anyprops:client:toggleDebug', source)
    else
        TriggerClientEvent('ox_lib:notify', source, {title = 'Error', description = 'คุณไม่มีสิทธิ์ใช้งานคำสั่งนี้', type = 'error'})
    end
end, false)

-- เคลียร์ Memory อัตโนมัติเมื่อ Entity ถูกลบจากปัจจัยภายนอก
AddEventHandler('entityRemoved', function(entity)
    if DoesEntityExist(entity) then return end
    
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId and netId ~= 0 and serverPropsMetadata[netId] then
        serverPropsMetadata[netId] = nil
    end
end)