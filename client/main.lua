local currentPropEntity = nil
local currentActiveItem = nil
local currentItemCount = 0
local currentPlaceAmount = 1
local isPlacing = false 
local isStashing = false
local isProcessing = false
local isPlacingWeapon = false
local reqSnapGround = false
local reqResetAngle = false
local reqFlipProp = false
local reqZUp = false
local reqZDown = false
local WEAPON_UNARMED = `WEAPON_UNARMED`

local Keys = {
    Attack = 24, Aim = 25, ScrollUp = 14, ScrollDown = 15,
    NextWeapon = 261, PrevWeapon = 262,
    Enter = 191, Backspace = 194, Shift = 21,
    ArrowUp = 172, ArrowDown = 173, ArrowLeft = 174, ArrowRight = 175,
    G = 47, X = 73, Y = 246, Z = 20, EnterText = 18, Interact = 38
}

local isEditing = false
local editPos = vec3(0.0, 0.0, 0.0)
local editRot = vec3(0.0, 0.0, 0.0)
local editMode = 'pos' 
local editAxis = 'x'

local isDebugMode = false

local visualClusterProps = {}
local cachedWeapons = {}

local attachedPropsList = {}
local vehPreviousHealth = {}

local trackedProps = {}

local currentPropMetadata = nil
local currentPropSlot = nil

-- Helper: ดึงข้อมูลไอเทมจาก Config.Items หรือคืนค่า DefaultFallback ถ้าไม่เจอ
local function GetItemData(itemName)
    if not itemName then return nil end
    if GetItemData(itemName) then return GetItemData(itemName) end
    
    -- ถ้าเป็นอาวุธ จะไม่ใช้ Fallback
    if string.find(string.upper(itemName), "WEAPON_") then return nil end 
    
    return Config.DefaultFallback
end

-- Utilities Function
local function RotationToDirection(rotation)
    local adjustedRotation = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    local direction = {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
    return direction
end

local function RayCastCamera(distance)
    local cameraRotation = GetGameplayCamRot(0)
    local cameraCoord = GetGameplayCamCoord()
    local direction = RotationToDirection(cameraRotation)
    local destination = {
        x = cameraCoord.x + direction.x * distance,
        y = cameraCoord.y + direction.y * distance,
        z = cameraCoord.z + direction.z * distance
    }
    local rayHandle = StartShapeTestRay(cameraCoord.x, cameraCoord.y, cameraCoord.z, destination.x, destination.y, destination.z, -1, cache.ped, 0)
    local _, hit, endCoords, _, entityHit = GetShapeTestResult(rayHandle)
    return hit, endCoords, entityHit
end

local function DrawTextOnScreen(lines, startX, startY)
    for i, line in ipairs(lines) do
        SetTextFont(4)
        SetTextProportional(1)
        SetTextScale(0.40, 0.40)
        SetTextColour(255, 255, 255, 255)
        SetTextDropShadow(0, 0, 0, 0, 255)
        SetTextEdge(1, 0, 0, 0, 255)
        SetTextDropShadow()
        SetTextOutline()
        BeginTextCommandDisplayText("STRING")
        AddTextComponentSubstringPlayerName(line)
        EndTextCommandDisplayText(startX, startY + ((i - 1) * 0.035))
    end
end

local function GetDynamicKey(commandName)
    local hash = joaat(commandName)
    local button = GetControlInstructionalButton(2, hash | 0x80000000, true)
    if button and button:sub(1, 2) == "t_" then
        return string.upper(button:sub(3))
    end
    return "E" -- Default Key
end

-- Core Function
local function removeProp(isWeaponSwap)
    if currentPropEntity then
        DeleteEntity(currentPropEntity)
        
        if currentActiveItem and GetItemData(currentActiveItem) then
            local itemData = GetItemData(currentActiveItem)
            if itemData.animDict and itemData.animName then
                StopAnimTask(cache.ped, itemData.animDict, itemData.animName, 1.0)
            end
        end
        
        if not isWeaponSwap then
            ClearPedTasks(cache.ped)
        end
        
        currentPropEntity = nil
        currentActiveItem = nil
        currentItemCount = 0
        currentPlaceAmount = 1
        isPlacing = false
        isPlacingWeapon = false
        currentPropMetadata = nil
        currentPropSlot = nil
        lib.hideTextUI()
    end
end

local function stashPropAndRemove(isWeaponSwap)
    if not currentPropEntity then return end
    isStashing = true
    local ped = cache.ped
    
    if IsPedDeadOrDying(ped, true) or IsPedRagdoll(ped) then
        removeProp(isWeaponSwap)
        isStashing = false
        return
    end
    
    lib.requestAnimDict("pickup_object", 1000)
    TaskPlayAnim(ped, "pickup_object", "putdown_low", 8.0, -8.0, 800, 48, 0, false, false, false)
    Wait(600)
    removeProp(isWeaponSwap)
    isStashing = false
end

local function forceDropProp()
    if not currentPropEntity then return end
    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    local dropCoords = vec3(coords.x + (math.random(-5, 5) / 10.0), coords.y + (math.random(-5, 5) / 10.0), coords.z - 0.9)
    local dropRot = vec3(0.0, 0.0, heading)
    TriggerServerEvent('atf_anyprops:server:placeProp', currentActiveItem, dropCoords, dropRot, nil, true, currentPropMetadata, currentPropSlot, currentPlaceAmount)
    removeProp(false)
end

-- Helper สำหรับจัดการปุ่มกด
local function handlePlacementControls(isShift, stepRot, stepZ, state)
    local function checkKey(control)
        return isShift and (IsControlPressed(0, control) or IsDisabledControlPressed(0, control))
            or (IsControlJustPressed(0, control) or IsDisabledControlJustPressed(0, control))
    end

    if checkKey(Keys.ScrollUp) then state.propHeading = state.propHeading - stepRot end
    if checkKey(Keys.ScrollDown) then state.propHeading = state.propHeading + stepRot end
    if checkKey(Keys.ArrowUp) then state.pitch = state.pitch + stepRot end
    if checkKey(Keys.ArrowDown) then state.pitch = state.pitch - stepRot end
    if checkKey(Keys.ArrowLeft) then state.roll = state.roll + stepRot end
    if checkKey(Keys.ArrowRight) then state.roll = state.roll - stepRot end

    local zUpAction = isShift and reqZUp or (reqZUp and not state.wasZUp)
    local zDownAction = isShift and reqZDown or (reqZDown and not state.wasZDown)
    state.wasZUp = reqZUp
    state.wasZDown = reqZDown

    if zUpAction then state.zOffset = state.zOffset + stepZ end
    if zDownAction then state.zOffset = state.zOffset - stepZ end

    if reqFlipProp then
        state.pitch = (state.pitch == 0.0) and 90.0 or 0.0
        reqFlipProp = false
    end
    if reqSnapGround then
        state.zOffset = 0.0
        reqSnapGround = false
    end
    if reqResetAngle then
        state.pitch = isPlacingWeapon and 90.0 or 0.0
        state.roll = 0.0
        state.zOffset = 0.0
        reqResetAngle = false
    end
end

-- ฟังก์ชันการยกเลิกวางของ
local function cancelPlacement()
    isPlacing = false
    if isPlacingWeapon then
        if DoesEntityExist(currentPropEntity) then DeleteEntity(currentPropEntity) end
        if currentActiveItem then SetCurrentPedWeapon(cache.ped, joaat(currentActiveItem), true) end
        currentPropEntity = nil
        currentActiveItem = nil
        currentPropMetadata = nil
        currentPropSlot = nil
        isPlacingWeapon = false
        lib.hideTextUI()
    else
        local itemData = GetItemData(currentActiveItem)
        local hasCollision = itemData.collision ~= false
        SetEntityCollision(currentPropEntity, hasCollision, hasCollision)
        SetEntityAlpha(currentPropEntity, 255, false)
        local boneIndex = GetPedBoneIndex(cache.ped, itemData.bone)
        AttachEntityToEntity(currentPropEntity, cache.ped, boneIndex, itemData.pos.x, itemData.pos.y, itemData.pos.z, itemData.rot.x, itemData.rot.y, itemData.rot.z, true, true, false, true, 1, true)
        lib.hideTextUI()
        lib.showTextUI('[E] วางของ', {position = 'right-center'})
    end
end

-- ฟังก์ชันการกดยืนยันวางของ
local function confirmPlacement(finalCoords, state, entityHit, isVehicle)
    isPlacing = false
    local attachDataSend = nil
    if isPlacingWeapon then attachDataSend = { customModelHash = GetEntityModel(currentPropEntity) } end

    if isVehicle and state.isAttachMode then
        attachDataSend = attachDataSend or {}
        attachDataSend.vehNetId = NetworkGetNetworkIdFromEntity(entityHit)
        attachDataSend.offset = GetOffsetFromEntityGivenWorldCoords(entityHit, finalCoords.x, finalCoords.y, finalCoords.z)
        attachDataSend.relHeading = state.propHeading - GetEntityHeading(entityHit)
        attachDataSend.pitch = state.pitch - GetEntityPitch(entityHit)
        attachDataSend.roll = state.roll - GetEntityRoll(entityHit)
    end

    local itemLabel = currentActiveItem
    local itemInfo = exports.ox_inventory:Items(currentActiveItem)
    if itemInfo and itemInfo.label then itemLabel = itemInfo.label end

    if currentPlaceAmount > 1 then Config.PerformAction('ได้วาง ' .. itemLabel .. ' ลง ' .. currentPlaceAmount .. ' ชิ้น')
    else Config.PerformAction('ได้วาง ' .. itemLabel .. ' ลง') end

    if isPlacingWeapon then
        SetEntityAlpha(currentPropEntity, 255, false)
        SetEntityCollision(currentPropEntity, true, true)
        NetworkRegisterEntityAsNetworked(currentPropEntity)
        local netId = ObjToNet(currentPropEntity)
        SetNetworkIdExistsOnAllMachines(netId, true)
        SetNetworkIdCanMigrate(netId, true)
        TriggerServerEvent('atf_anyprops:server:placeWeaponProp', currentActiveItem, netId, finalCoords, vec3(state.pitch, state.roll, state.propHeading), attachDataSend, isVehicle and not state.isAttachMode, currentPropMetadata, currentPropSlot, currentPlaceAmount)
        currentPropEntity = nil currentActiveItem = nil currentPropMetadata = nil currentPropSlot = nil isPlacingWeapon = false lib.hideTextUI()
    else
        TriggerServerEvent('atf_anyprops:server:placeProp', currentActiveItem, finalCoords, vec3(state.pitch, state.roll, state.propHeading), attachDataSend, isVehicle and not state.isAttachMode, currentPropMetadata, currentPropSlot, currentPlaceAmount)
        Wait(200) removeProp(false)
    end
end

local function startPlacementMode()
    if isPlacing then return end
    isPlacing = true

    reqSnapGround, reqResetAngle, reqFlipProp, reqZUp, reqZDown = false, false, false, false, false

    if isPlacingWeapon then
        currentPlaceAmount = 1
    else
        currentItemCount = exports.ox_inventory:Search('count', currentActiveItem) or 0
        if currentItemCount < 1 then isPlacing = false return end

        local itemData = GetItemData(currentActiveItem)
        if itemData and itemData.singlePlace then
            currentPlaceAmount = 1
            lib.hideTextUI()
        else
            lib.hideTextUI()
            local input = lib.inputDialog('ระบุจำนวนที่ต้องการวาง', {
                { type = 'number', label = 'จำนวนชิ้น', description = 'คุณมีไอเทมนี้ทั้งหมด '..currentItemCount..' ชิ้น', min = 1, max = currentItemCount, default = 1, required = true }
            })
            if not input or not input[1] then isPlacing = false lib.showTextUI('[E] โหมดวางของ', {position = 'right-center'}) return end
            currentPlaceAmount = input[1]
        end
    end

    local state = {
        propHeading = isPlacingWeapon and (GetEntityHeading(cache.ped) + 180.0) % 360.0 or GetEntityHeading(cache.ped),
        pitch = isPlacingWeapon and 90.0 or 0.0,
        roll = 0.0,
        zOffset = 0.0,
        isAttachMode = true,
        wasZUp = false,
        wasZDown = false
    }

    local function updateUI()
        local attachText = state.isAttachMode and 'เปิด' or 'ปิด'
        local uiText = string.format(
            "**[Enter]** วาง | **[Backspace]** ยกเลิก  \n**[Arrows/Scroll]** หมุน | **%s** และ **%s** ขึ้น-ลง  \n**[%s]** นอน-ตั้ง | **[ %s ]** ติดกับพื้น | **[ %s ]** รีเซ็ต  \n**[G]** ล็อคกับรถ: %s  \n*(Shift ค้างพร้อมปุ่มอื่นเพื่อปรับละเอียด)*",
            GetDynamicKey('+atf_z_up'), GetDynamicKey('+atf_z_down'), GetDynamicKey('+atf_flip_prop'), GetDynamicKey('+atf_snap_ground'), GetDynamicKey('+atf_reset_angle'), attachText
        )
        lib.showTextUI(uiText, {position = 'right-center'})
    end

    updateUI()
    DetachEntity(currentPropEntity, true, true)
    SetEntityCollision(currentPropEntity, false, false)
    SetEntityAlpha(currentPropEntity, 150, false)

    CreateThread(function()
        local disabledKeys = { Keys.Attack, Keys.Aim, Keys.ScrollUp, Keys.ScrollDown, Keys.NextWeapon, Keys.PrevWeapon }
        
        while isPlacing and currentPropEntity do
            Wait(0)
            
            local ped = cache.ped
            if IsPedDeadOrDying(ped, true) or IsPedFatallyInjured(ped) or IsPedRagdoll(ped) or IsPedCuffed(ped) then
                cancelPlacement()
                lib.notify({type = 'error', description = 'การวางของถูกยกเลิกเนื่องจากร่างกายหมดสภาพ'})
                break
            end

            for _, ctrl in ipairs(disabledKeys) do DisableControlAction(0, ctrl, true) end
            DisablePlayerFiring(cache.ped, true)

            if IsControlJustPressed(0, Keys.G) then state.isAttachMode = not state.isAttachMode updateUI() end

            local isShift = IsControlPressed(0, Keys.Shift)
            local stepRot = isShift and Config.Controls.StepRotFine or Config.Controls.StepRot
            local stepZ = isShift and Config.Controls.StepZFine or Config.Controls.StepZ

            handlePlacementControls(isShift, stepRot, stepZ, state)

            local hit, coords, entityHit = RayCastCamera(Config.Distance.Placement)
            if hit ~= 0 then
                local pedCoords = GetEntityCoords(cache.ped)
                local isVehicle = entityHit ~= 0 and IsEntityAVehicle(entityHit)

                if isVehicle and state.isAttachMode then DrawLine(pedCoords.x, pedCoords.y, pedCoords.z, coords.x, coords.y, coords.z, 0, 150, 255, 150)
                else DrawLine(pedCoords.x, pedCoords.y, pedCoords.z, coords.x, coords.y, coords.z, 0, 255, 0, 150) end

                local finalCoords = vec3(coords.x, coords.y, coords.z + state.zOffset)
                SetEntityCoords(currentPropEntity, finalCoords.x, finalCoords.y, finalCoords.z, false, false, false, false)
                SetEntityRotation(currentPropEntity, state.pitch, state.roll, state.propHeading, 2, true)

                if IsControlJustPressed(0, Keys.Enter) or IsDisabledControlJustPressed(0, Keys.Enter) then
                    -- เช็ค Line of Sight จากตัวละคร
                    local pedCoordsLos = GetEntityCoords(cache.ped)
                    local rayHandle = StartShapeTestRay(pedCoordsLos.x, pedCoordsLos.y, pedCoordsLos.z, finalCoords.x, finalCoords.y, finalCoords.z, 1, cache.ped, 0)
                    local _, hitLos, hitCoordsLos = GetShapeTestResult(rayHandle)

                    if hitLos ~= 0 and #(hitCoordsLos - finalCoords) > 0.2 then
                        lib.notify({type = 'error', description = 'ไม่สามารถวางของทะลุกำแพงได้'})
                    else
                        confirmPlacement(finalCoords, state, entityHit, isVehicle)
                        break
                    end
                end

                if IsControlJustPressed(0, Keys.Backspace) or IsDisabledControlJustPressed(0, Keys.Backspace) then
                    cancelPlacement()
                    break
                end
            end
        end
    end)
end

local function startKeybindThread()
    CreateThread(function()
        while currentPropEntity do
            Wait(0)
            if not isPlacing and IsControlJustPressed(0, 38) then
                startPlacementMode()
            end
        end
    end)
end

local function startPropThread()
    CreateThread(function()
        Wait(1000)
        while currentPropEntity do
            Wait(500)
            local ped = cache.ped
            
            local isDead = LocalPlayer.state.isDead == true or LocalPlayer.state.isDowned == true or LocalPlayer.state.inLaststand == true
            local isIncapacitated = isDead or IsPedDeadOrDying(ped, true) or IsPedFatallyInjured(ped) or IsPedRagdoll(ped) or IsPedCuffed(ped)

            if isIncapacitated then 
                if isPlacing then cancelPlacement() else removeProp(false) end
                break 
            end
            if IsPedInAnyVehicle(ped, false) then 
                if isPlacing then cancelPlacement() else removeProp(false) end
                break 
            end

            if not isPlacing then
                if exports.ox_lib:progressActive() then removeProp(false) break end
                
                if IsEntityPlayingAnim(ped, 'cellphone@', 'cellphone_text_in', 3) or
                   IsEntityPlayingAnim(ped, 'cellphone@', 'cellphone_text_read_base', 3) or
                   IsEntityPlayingAnim(ped, 'cellphone@', 'cellphone_call_listen_base', 3) then removeProp(false) break end

                local weaponHash = GetSelectedPedWeapon(ped)
                if weaponHash ~= `WEAPON_UNARMED` and weaponHash ~= 0 then 
                    stashPropAndRemove(true) 
                    break 
                end

                if IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped) then forceDropProp() break end
                if IsPedInMeleeCombat(ped) then
                    forceDropProp()
                    lib.notify({title = 'ระบบ', description = 'ของหลุดมือจากการต่อสู้', type = 'warning'})
                    break
                end

                local currentCount = exports.ox_inventory:Search('count', currentActiveItem) or 0
                if currentCount < 1 then removeProp(false) break end
                
                local itemData = GetItemData(currentActiveItem)
                if itemData and itemData.animDict then
                    if not IsEntityPlayingAnim(ped, itemData.animDict, itemData.animName, 3) then
                        TaskPlayAnim(ped, itemData.animDict, itemData.animName, 8.0, -8.0, -1, itemData.animFlag or 49, 0, false, false, false)
                    end
                end
            end
        end
    end)
    
    CreateThread(function()
        while currentPropEntity do
            Wait(0)
            local itemData = GetItemData(currentActiveItem)
            if itemData and itemData.heavy then
                DisableControlAction(0, 21, true) 
                DisableControlAction(0, 22, true) 
            end
        end
    end)
end

local trackedProps = {}

-- Optimization Entity Tracker
AddStateBagChangeHandler('isAtfProp', nil, function(bagName, key, value, _reserved, replicated)
    if not value then return end
    local entity = GetEntityFromStateBagName(bagName)
    if entity and entity > 0 then
        trackedProps[entity] = true
    end
end)
-- ค้นหา Prop ที่เพิ่งสตรีมเข้ามารอบตัว ดึงเข้าบัญชีทุก 5 วินาที
CreateThread(function()
    while true do
        Wait(5000) 
        local objects = GetGamePool('CObject')
        for _, obj in ipairs(objects) do
            if not trackedProps[obj] and Entity(obj).state.isAtfProp then
                trackedProps[obj] = true
            end
        end
    end
end)

-- Threads / Loops
CreateThread(function()
    while true do
        Wait(1000)
        
        local pCoords = GetEntityCoords(cache.ped)
        local currentActiveMainEntities = {}
        local tempWeapons = {}
        
        for obj, _ in pairs(trackedProps) do
            if DoesEntityExist(obj) and Entity(obj).state.isAtfProp then
                local oCoords = GetEntityCoords(obj)
                local itemName = Entity(obj).state.placedItemName
                local amount = Entity(obj).state.itemAmount or 1
                
                -- วาดจุดแดง Debug Mode
                if isDebugMode and #(pCoords - oCoords) < Config.Distance.DebugMarker then
                    DrawMarker(28, oCoords.x, oCoords.y, oCoords.z + 0.5, 0, 0, 0, 0, 0, 0, 0.3, 0.3, 0.3, 255, 0, 0, 200, false, true, 2, false, nil, nil, false)
                end
                
                -- เก็บข้อมูลอาวุธ (เช็คว่าชื่อมีคำว่า WEAPON_ นำหน้า)
                if itemName and string.find(string.upper(itemName), "WEAPON_") then
                    if #(pCoords - oCoords) < 20.0 then 
                        table.insert(tempWeapons, obj)
                    end
                end
                
                -- แสดงผลกองไอเทม
                currentActiveMainEntities[obj] = true
                local targetExtraCount = 0
                if amount >= 10 then targetExtraCount = 4 
                elseif amount >= 5 then targetExtraCount = 2 end
                
                local currentCluster = visualClusterProps[obj]
                local currentExtraCount = currentCluster and #currentCluster or 0
                
                if currentExtraCount ~= targetExtraCount then
                    if currentCluster then
                        for _, extraObj in ipairs(currentCluster) do
                            if DoesEntityExist(extraObj) then DeleteEntity(extraObj) end
                        end
                        visualClusterProps[obj] = nil
                    end
                    
                    if targetExtraCount > 0 then
                        local model = GetEntityModel(obj)
                        lib.requestModel(model, 1000)
                        
                        local minDim, maxDim = GetModelDimensions(model)
                        local sizeX = math.abs(maxDim.x - minDim.x)
                        local sizeY = math.abs(maxDim.y - minDim.y)
                        
                        local spreadX = math.max(0.2, sizeX * 0.9)
                        local spreadY = math.max(0.2, sizeY * 0.9)
                        
                        local newCluster = {}
                        if targetExtraCount >= 2 then
                            local extra1 = CreateObjectNoOffset(model, oCoords.x, oCoords.y, oCoords.z, false, false, false)
                            local extra2 = CreateObjectNoOffset(model, oCoords.x, oCoords.y, oCoords.z, false, false, false)
                            SetEntityCollision(extra1, false, false) SetEntityCollision(extra2, false, false)
                            
                            AttachEntityToEntity(extra1, obj, -1, spreadX, math.random(-10, 10) / 100.0, 0.0, 0.0, 0.0, math.random(-20, 20) + 0.0, false, false, false, false, 2, true)
                            AttachEntityToEntity(extra2, obj, -1, -spreadX, math.random(-10, 10) / 100.0, 0.0, 0.0, 0.0, math.random(-20, 20) + 0.0, false, false, false, false, 2, true)
                            
                            table.insert(newCluster, extra1) table.insert(newCluster, extra2)
                        end
                        if targetExtraCount >= 4 then
                            local extra3 = CreateObjectNoOffset(model, oCoords.x, oCoords.y, oCoords.z, false, false, false)
                            local extra4 = CreateObjectNoOffset(model, oCoords.x, oCoords.y, oCoords.z, false, false, false)
                            SetEntityCollision(extra3, false, false) SetEntityCollision(extra4, false, false)
                            
                            AttachEntityToEntity(extra3, obj, -1, math.random(-10, 10) / 100.0, spreadY, 0.0, 0.0, 0.0, math.random(70, 110) + 0.0, false, false, false, false, 2, true)
                            AttachEntityToEntity(extra4, obj, -1, math.random(-10, 10) / 100.0, -spreadY, 0.0, 0.0, 0.0, math.random(70, 110) + 0.0, false, false, false, false, 2, true)
                            
                            table.insert(newCluster, extra3) table.insert(newCluster, extra4)
                        end
                        SetModelAsNoLongerNeeded(model)
                        visualClusterProps[obj] = newCluster
                    end
                end
            else
                trackedProps[obj] = nil
            end
        end
        
        cachedWeapons = tempWeapons
        
        for mainEnt, extraObjs in pairs(visualClusterProps) do
            if not currentActiveMainEntities[mainEnt] or not DoesEntityExist(mainEnt) then
                for _, extraObj in ipairs(extraObjs) do
                    if DoesEntityExist(extraObj) then DeleteEntity(extraObj) end
                end
                visualClusterProps[mainEnt] = nil
            end
        end
        
    end
end)

CreateThread(function()
    while true do
        Wait(200)
        
        local activeVehicles = {}
        local crashedVehicles = {}
        
        for propEntity, vehEntity in pairs(attachedPropsList) do
            if DoesEntityExist(propEntity) and DoesEntityExist(vehEntity) then
                activeVehicles[vehEntity] = true
            else
                attachedPropsList[propEntity] = nil
            end
        end

        for vehEntity, _ in pairs(activeVehicles) do
            if NetworkHasControlOfEntity(vehEntity) then
                local roll = GetEntityRoll(vehEntity)
                local pitch = GetEntityPitch(vehEntity)
                
                local currentHealth = GetVehicleBodyHealth(vehEntity)
                local prevHealth = vehPreviousHealth[vehEntity] or currentHealth
                local healthDrop = prevHealth - currentHealth
                
                vehPreviousHealth[vehEntity] = currentHealth
                
                local isHeavyCrash = healthDrop > Config.VehicleCrash.DamageDrop

                if math.abs(roll) > Config.VehicleCrash.MaxRoll or math.abs(pitch) > Config.VehicleCrash.MaxPitch or isHeavyCrash then
                    crashedVehicles[vehEntity] = true
                end
            end
        end

        for propEntity, vehEntity in pairs(attachedPropsList) do
            if crashedVehicles[vehEntity] then
                TriggerServerEvent('atf_anyprops:server:detachProp', NetworkGetNetworkIdFromEntity(propEntity))
                attachedPropsList[propEntity] = nil
            end
        end

        for vehEntity, _ in pairs(vehPreviousHealth) do
            if not activeVehicles[vehEntity] then
                vehPreviousHealth[vehEntity] = nil
            end
        end
    end
end)

-- ระบบ UI
CreateThread(function()
    local currentMode = nil
    local lastWeapon = nil
    local weaponHideTimer = 0
    local sleep = 1000
    
    while true do
        Wait(sleep) 
        sleep = 1000
        
        local ped = cache.ped
        
        local isDead = LocalPlayer.state.isDead or LocalPlayer.state.isDowned or LocalPlayer.state.inLaststand or false
        local isIncapacitated = isDead or IsPedDeadOrDying(ped, true) or IsPedFatallyInjured(ped) or IsPedRagdoll(ped) or IsPedCuffed(ped)
    
        if not isPlacing and not isStashing and not isProcessing and not isIncapacitated then
            local currentWeaponHash = GetSelectedPedWeapon(ped)
            
            if currentWeaponHash ~= WEAPON_UNARMED and not IsPedInAnyVehicle(ped, false) then
                sleep = 200
                
                if lastWeapon ~= currentWeaponHash then
                    lastWeapon = currentWeaponHash
                    weaponHideTimer = Config.UI.WeaponHideTimer or 10000
                    currentMode = 'place'
                    
                    local keyName = GetDynamicKey('atf_place_weapon')
                    lib.showTextUI('['..keyName..'] วางอาวุธ ('..math.ceil(weaponHideTimer / 1000)..'s)', {position = 'right-center'})
                
                elseif currentMode == 'place' then
                    if weaponHideTimer > 0 then
                        weaponHideTimer = weaponHideTimer - 200 
                        
                        if weaponHideTimer <= 0 then
                            lib.hideTextUI()
                            currentMode = 'hidden_place'
                        else
                            local keyName = GetDynamicKey('atf_place_weapon')
                            lib.showTextUI('['..keyName..'] วางอาวุธ ('..math.ceil(weaponHideTimer / 1000)..'s)', {position = 'right-center'})
                        end
                    end
                end
                   
            elseif currentWeaponHash == WEAPON_UNARMED then
                lastWeapon = nil
                weaponHideTimer = 0
                
                local pCoords = GetEntityCoords(ped)
                local closestObj = nil
                local closestDist = Config.Distance.KeyPickup or 1.5
                local hasNearbyWeapon = false
                
                if cachedWeapons then
                    for _, obj in ipairs(cachedWeapons) do
                        if DoesEntityExist(obj) then
                            local dist = #(pCoords - GetEntityCoords(obj))
                            
                            if dist < 10.0 then hasNearbyWeapon = true end
                            
                            if dist < closestDist then
                                closestDist = dist
                                closestObj = obj
                            end
                        end
                    end
                end
                
                if hasNearbyWeapon then sleep = 200 end
                
                if closestObj then
                    local itemName = Entity(closestObj).state.placedItemName
                    local itemLabel = 'อาวุธ'
                    if itemName then
                        local itemInfo = exports.ox_inventory:Items(itemName)
                        if itemInfo and itemInfo.label then itemLabel = itemInfo.label end
                    end
                    
                    local newMode = 'pickup_' .. tostring(closestObj)
                    if currentMode ~= newMode then
                        local keyName = GetDynamicKey('atf_pickup_weapon')
                        lib.showTextUI('['..keyName..'] เก็บ '..itemLabel, {position = 'right-center'})
                        currentMode = newMode
                    end
                else
                    if currentMode then lib.hideTextUI() currentMode = nil end
                end
            else
                if currentMode then lib.hideTextUI() currentMode = nil end
            end
        else
            if currentMode then lib.hideTextUI() currentMode = nil end
            lastWeapon = nil    
            weaponHideTimer = 0 
        end
    end
end)

-- ระบบเชื่อม ox_target
CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(100) end
    
    exports.ox_target:addGlobalObject({
        {
            name = 'pickup_atf_prop',
            icon = 'fas fa-hand-holding',
            label = 'เก็บของ',
            distance = Config.Distance.TargetPickup,
            canInteract = function(entity)
                local ped = cache.ped
                local isDead = LocalPlayer.state.isDead or LocalPlayer.state.isDowned or LocalPlayer.state.inLaststand or false
                if isDead or IsPedDeadOrDying(ped, true) or IsPedFatallyInjured(ped) or IsPedRagdoll(ped) or IsPedCuffed(ped) then 
                    return false 
                end
                return Entity(entity).state.isAtfProp == true
            end,
            onSelect = function(data)
                if isProcessing then return end 
                
                local netId = NetworkGetNetworkIdFromEntity(data.entity)
                if netId ~= 0 then
                    local currentAmount = Entity(data.entity).state.itemAmount or 1
                    local pickAmount = currentAmount
                    
                    local itemName = Entity(data.entity).state.placedItemName
                    local itemLabel = 'ไอเทม'
                    if itemName then
                        local itemInfo = exports.ox_inventory:Items(itemName)
                        if itemInfo and itemInfo.label then itemLabel = itemInfo.label end
                    end

                    if currentAmount > 1 then
                        local input = lib.inputDialog('เก็บ ' .. itemLabel, {
                            {
                                type = 'number', 
                                label = 'จำนวนที่ต้องการเก็บ', 
                                description = 'มี '..itemLabel..' วางอยู่ทั้งหมด '..currentAmount..' ชิ้น', 
                                min = 1, 
                                max = currentAmount, 
                                default = currentAmount,
                                required = true
                            }
                        })
                        if not input or not input[1] then return end
                        pickAmount = input[1]
                    end

                    isProcessing = true 
                    TaskPlayAnim(cache.ped, "pickup_object", "pickup_low", 8.0, -8.0, 1000, 48, 0, false, false, false)
                    Wait(500)
                    TriggerServerEvent('atf_anyprops:server:pickupProp', netId, pickAmount)
                    Wait(1000) 
                    isProcessing = false 
                end
            end
        }
    })

    -- ส่งของให้คนอื่น
    exports.ox_target:addGlobalPlayer({
        {
            name = 'give_atf_prop',
            icon = 'fas fa-hand-holding-hand',
            label = 'ส่งของในมือให้',
            distance = Config.Distance.TargetGive,
            canInteract = function(entity)
                local ped = cache.ped
                local isDead = LocalPlayer.state.isDead or LocalPlayer.state.isDowned or LocalPlayer.state.inLaststand or false
                if isDead or IsPedDeadOrDying(ped, true) or IsPedFatallyInjured(ped) or IsPedRagdoll(ped) or IsPedCuffed(ped) then 
                    return false 
                end
                return entity ~= cache.ped and currentActiveItem ~= nil and not isPlacingWeapon
            end,
            onSelect = function(data)
                if isProcessing then return end 
                isProcessing = true 
                
                local targetPlayer = NetworkGetPlayerIndexFromPed(data.entity)
                local targetServerId = GetPlayerServerId(targetPlayer)
                
                if targetServerId > 0 then
                    lib.requestAnimDict("mp_common", 1000)
                    TaskPlayAnim(cache.ped, "mp_common", "givetake2_a", 8.0, -8.0, 1000, 48, 0, false, false, false)
                    Wait(500)
                    
                    TriggerServerEvent('atf_anyprops:server:transferProp', targetServerId, currentActiveItem, currentPropMetadata, currentPropSlot)
                    removeProp(false)
                end
                
                Wait(1000)
                isProcessing = false
            end
        }
    })
end)

-- Events / Handlers
AddEventHandler('qbx_medical:client:playerDead', function() removeProp(false) end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        removeProp(false)
        if GetResourceState('ox_target') == 'started' then
            exports.ox_target:removeGlobalObject({'pickup_atf_prop'})
            exports.ox_target:removeGlobalPlayer({'give_atf_prop'})
        end
        
        if visualClusterProps then
            for _, extraObjs in pairs(visualClusterProps) do
                for _, obj in ipairs(extraObjs) do
                    if DoesEntityExist(obj) then DeleteEntity(obj) end
                end
            end
        end
    end
end)

AddStateBagChangeHandler('renderData', nil, function(bagName, key, value, _reserved, replicated)
    if not value or type(value) ~= 'table' then return end
    CreateThread(function()
        local entity = GetEntityFromStateBagName(bagName)
        local timeout = 0
        while (not entity or entity == 0) and timeout < 150 do Wait(100); entity = GetEntityFromStateBagName(bagName); timeout = timeout + 1 end
        
        if entity and entity > 0 then
            if value.components then
                for _, comp in ipairs(value.components) do
                    local compHash = type(comp) == 'string' and joaat(string.upper(comp)) or comp
                    local compModel = GetWeaponComponentTypeModel(compHash)
                    
                    if compModel and compModel ~= 0 then 
                        lib.requestModel(compModel, 1000) 
                    end
                    
                    GiveWeaponComponentToWeaponObject(entity, compHash)
                end
            end
            
            if value.tint then
                SetWeaponObjectTintIndex(entity, value.tint)
            end
        end
    end)
end)

AddStateBagChangeHandler('attachData', nil, function(bagName, key, value, _reserved, replicated)
    CreateThread(function()
        local entity = GetEntityFromStateBagName(bagName)
        local timeout = 0
        while (not entity or entity == 0) and timeout < 150 do Wait(100); entity = GetEntityFromStateBagName(bagName); timeout = timeout + 1 end
        if entity and entity > 0 then
            NetworkRequestControlOfEntity(entity)
            
            local controlTimeout = 0
            while not NetworkHasControlOfEntity(entity) and controlTimeout < 20 do
                Wait(50)
                controlTimeout = controlTimeout + 1
            end

            if value then
                local veh = NetworkGetEntityFromNetworkId(value.vehNetId)
                if veh and veh > 0 then
                    AttachEntityToEntity(entity, veh, -1, value.offset.x, value.offset.y, value.offset.z, value.pitch or 0.0, value.roll or 0.0, value.yaw or value.relHeading, false, false, true, false, 2, true)
                    attachedPropsList[entity] = veh
                end
            else
                local veh = attachedPropsList[entity]
                
                DetachEntity(entity, true, true)
                FreezeEntityPosition(entity, false)
                SetEntityCollision(entity, false, false) 
                
                SetEntityDynamic(entity, true) 
                SetEntityHasGravity(entity, true)
                Wait(300) 
                
                local placedItemName = Entity(entity).state.placedItemName
                local hasCollision = true
                if placedItemName and GetItemData(placedItemName) and GetItemData(placedItemName).collision ~= nil then
                    hasCollision = GetItemData(placedItemName).collision
                end
                SetEntityCollision(entity, hasCollision, hasCollision)
                
                SetEntityVelocity(entity, 0.0, 0.0, -0.1)
                
                if veh and DoesEntityExist(veh) then
                    local vehVel = GetEntityVelocity(veh)
                    SetEntityVelocity(entity, vehVel.x * 0.5, vehVel.y * 0.5, vehVel.z - 0.1)
                end
                
                attachedPropsList[entity] = nil
            end
        end
    end)
end)

AddStateBagChangeHandler('freeze', nil, function(bagName, key, value, _reserved, replicated)
    CreateThread(function()
        local entity = GetEntityFromStateBagName(bagName)
        local timeout = 0
        while (not entity or entity == 0) and timeout < 150 do
            Wait(100)
            entity = GetEntityFromStateBagName(bagName)
            timeout = timeout + 1
        end

        if entity and entity > 0 then
            if value ~= nil then
                FreezeEntityPosition(entity, value)
                if not value then
                    SetEntityDynamic(entity, true)
                end
            end
        
            local hasCollision = Entity(entity).state.collision
            if hasCollision ~= nil then
                SetEntityCollision(entity, hasCollision, hasCollision)
            end
        end
    end)
end)

RegisterNetEvent('atf_anyprops:client:toggleProp', function(itemName, metadata, slot)
    if isStashing then return end

    local itemData = GetItemData(itemName)
    if not itemData then return end
    
    local ped = cache.ped
    local isDead = LocalPlayer.state.isDead == true or LocalPlayer.state.isDowned == true or LocalPlayer.state.inLaststand == true
    if isDead or IsPedDeadOrDying(ped, true) or IsPedFatallyInjured(ped) then return end
    if IsPedInAnyVehicle(ped, false) then return end
    
    if currentPropEntity then 
        stashPropAndRemove(false) 
        local timeout = 0
        while isStashing and timeout < 20 do Wait(100) timeout = timeout + 1 end
        if currentActiveItem == itemName then return end
    end
    
    currentPropMetadata = metadata
    currentPropSlot = slot
    
    lib.requestModel(itemData.prop, 1000)
    local coords = GetEntityCoords(ped)
    currentPropEntity = CreateObject(joaat(itemData.prop), coords.x, coords.y, coords.z, true, true, true)
    local boneIndex = GetPedBoneIndex(ped, itemData.bone)
    AttachEntityToEntity(currentPropEntity, ped, boneIndex, itemData.pos.x, itemData.pos.y, itemData.pos.z, itemData.rot.x, itemData.rot.y, itemData.rot.z, true, true, false, true, 1, true)
    
    if itemData.animDict and itemData.animName then
        lib.requestAnimDict(itemData.animDict, 1000)
        TaskPlayAnim(ped, itemData.animDict, itemData.animName, 8.0, -8.0, -1, itemData.animFlag or 49, 0, false, false, false)
    end
    
    currentActiveItem = itemName
    currentItemCount = exports.ox_inventory:Search('count', itemName) or 0
    currentPlaceAmount = 1 
    SetModelAsNoLongerNeeded(itemData.prop)
    lib.showTextUI('[E] วางของ', {position = 'right-center'})
    startPropThread()
    startKeybindThread()
end)

RegisterNetEvent('atf_anyprops:client:toggleEditor', function()
    if not currentPropEntity then
        lib.notify({title = 'Dev Tool', description = 'ต้องกดใช้งานไอเทมให้ถือ Prop ก่อนถึงจะแก้ไขได้', type = 'error'})
        return
    end
    isEditing = not isEditing
    
    if isEditing then
        local itemData = GetItemData(currentActiveItem)
        if itemData then
            editPos = vector3(itemData.pos.x, itemData.pos.y, itemData.pos.z)
            editRot = vector3(itemData.rot.x, itemData.rot.y, itemData.rot.z)
        else
            editPos = vec3(0.0, 0.0, 0.0)
            editRot = vec3(0.0, 0.0, 0.0)
        end
        lib.notify({title = 'Dev Tool', description = 'เปิดโหมด Gizmo Editor แล้ว', type = 'success'})
        
        CreateThread(function()
            while isEditing and currentPropEntity do
                Wait(0)
                local ped = cache.ped
                local changed = false
                
                DisableControlAction(0, 24, true) 
                DisableControlAction(0, 25, true) 
                DisableControlAction(0, 14, true) 
                DisableControlAction(0, 15, true) 
                DisableControlAction(0, 37, true) 
                DisableControlAction(0, 22, true) 

                local posSpeed = 0.005
                local rotSpeed = 1.0
                if IsControlPressed(0, 21) then
                    posSpeed = 0.02
                    rotSpeed = 5.0
                elseif IsControlPressed(0, 36) then
                    posSpeed = 0.001
                    rotSpeed = 0.2
                end

                if IsDisabledControlJustPressed(0, 37) then editMode = editMode == 'pos' and 'rot' or 'pos' end
                if IsControlJustPressed(0, 73) then editAxis = 'x' end
                if IsControlJustPressed(0, 246) then editAxis = 'y' end
                if IsControlJustPressed(0, 20) then editAxis = 'z' end

                local scrollUp = IsDisabledControlJustPressed(0, 14)
                local scrollDown = IsDisabledControlJustPressed(0, 15)

                if scrollUp or scrollDown then
                    local dir = scrollUp and 1.0 or -1.0
                    if editMode == 'pos' then
                        if editAxis == 'x' then editPos = editPos + vec3(posSpeed * dir, 0.0, 0.0) end
                        if editAxis == 'y' then editPos = editPos + vec3(0.0, posSpeed * dir, 0.0) end
                        if editAxis == 'z' then editPos = editPos + vec3(0.0, 0.0, posSpeed * dir) end
                    else
                        if editAxis == 'x' then editRot = editRot + vec3(rotSpeed * dir, 0.0, 0.0) end
                        if editAxis == 'y' then editRot = editRot + vec3(0.0, rotSpeed * dir, 0.0) end
                        if editAxis == 'z' then editRot = editRot + vec3(0.0, 0.0, rotSpeed * dir) end
                    end
                    changed = true
                end

                if IsDisabledControlJustPressed(0, 22) then
                    local input = lib.inputDialog('แก้ไขพิกัด Prop แบบละเอียด', {
                        {type = 'number', label = 'Position X', default = editPos.x, step = 0.001, precision = 3},
                        {type = 'number', label = 'Position Y', default = editPos.y, step = 0.001, precision = 3},
                        {type = 'number', label = 'Position Z', default = editPos.z, step = 0.001, precision = 3},
                        {type = 'number', label = 'Rotation X', default = editRot.x, step = 0.1, precision = 3},
                        {type = 'number', label = 'Rotation Y', default = editRot.y, step = 0.1, precision = 3},
                        {type = 'number', label = 'Rotation Z', default = editRot.z, step = 0.1, precision = 3},
                    })

                    if input then
                        editPos = vec3(input[1] or editPos.x, input[2] or editPos.y, input[3] or editPos.z)
                        editRot = vec3(input[4] or editRot.x, input[5] or editRot.y, input[6] or editRot.z)
                        changed = true
                    end
                end

                local boneIndex = GetPedBoneIndex(ped, (GetItemData(currentActiveItem) and GetItemData(currentActiveItem).bone) or 28422)
                
                AttachEntityToEntity(currentPropEntity, ped, boneIndex, editPos.x, editPos.y, editPos.z, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
                local right, forward, up = GetEntityMatrix(currentPropEntity)
                
                AttachEntityToEntity(currentPropEntity, ped, boneIndex, editPos.x, editPos.y, editPos.z, editRot.x, editRot.y, editRot.z, true, true, false, true, 1, true)

                local coords = GetEntityCoords(currentPropEntity)
                local length = 0.3

                local function DrawAxis(axisVec, r, g, b, isActive)
                    if isActive then r, g, b = 255, 255, 0 end
                    local endCoords = coords + (axisVec * length)
                    DrawLine(coords.x, coords.y, coords.z, endCoords.x, endCoords.y, endCoords.z, r, g, b, 255)
                    DrawMarker(28, endCoords.x, endCoords.y, endCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.04, 0.04, 0.04, r, g, b, 255, false, false, 2, false, nil, nil, false)
                end

                DrawAxis(right, 255, 0, 0, editAxis == 'x')   
                DrawAxis(forward, 0, 255, 0, editAxis == 'y') 
                DrawAxis(up, 0, 0, 255, editAxis == 'z')       

                local modeText = editMode == 'pos' and '~g~Position (เลื่อน)~s~' or '~b~Rotation (หมุน)~s~'
                local textLines = {
                    "~y~[Gizmo Prop Editor]~s~",
                    "Item: ~y~" .. currentActiveItem .. "~s~",
                    "",
                    "Mode: " .. modeText,
                    "Active Axis: ~r~[ " .. string.upper(editAxis) .. " ]~s~",
                    "",
                    string.format("~b~Pos:~s~ %.3f, %.3f, %.3f", editPos.x, editPos.y, editPos.z),
                    string.format("~g~Rot:~s~ %.3f, %.3f, %.3f", editRot.x, editRot.y, editRot.z),
                    "",
                    "~c~[TAB] ~s~Position / Rotation",
                    "~c~[X] [Y] [Z] ~s~Axis Lock",
                    "~c~[Scroll] ~s~Change Value",
                    "~c~[Spacebar] ~s~Self Input",
                    "~c~[Enter] ~s~Save to F8"
                }
                DrawTextOnScreen(textLines, 0.015, 0.35)

                if IsControlJustPressed(0, 18) then 
                    isEditing = false
                    print('^2===========================================^7')
                    print(string.format("^3['%s'] = {^7", currentActiveItem))
                    print(string.format("    pos = vec3(%.3f, %.3f, %.3f),", editPos.x, editPos.y, editPos.z))
                    print(string.format("    rot = vec3(%.3f, %.3f, %.3f),", editRot.x, editRot.y, editRot.z))
                    print('^3}^7')
                    print('^2===========================================^7')
                    lib.notify({title = 'Dev Tool', description = 'ส่งค่าไปที่ F8 แล้ว', type = 'success'})
                end
            end
            isEditing = false
        end)
    end
end)

RegisterNetEvent('atf_anyprops:client:toggleDebug', function()
    isDebugMode = not isDebugMode
    lib.notify({title = 'Debug', description = 'Debug Mode: ' .. (isDebugMode and 'ON' or 'OFF')})
end)

-- ระบบ /me
RegisterNetEvent('atf_anyprops:client:pickupMeCommand', function(itemName, amount)
    local itemInfo = exports.ox_inventory:Items(itemName)
    local itemLabel = itemName
    if itemInfo and itemInfo.label then
        itemLabel = itemInfo.label
    end

    if amount > 1 then
        Config.PerformAction('ได้เก็บ ' .. itemLabel .. ' ขึ้นมา ' .. amount .. ' ชิ้น')
    else
        Config.PerformAction('ได้เก็บ ' .. itemLabel .. ' ขึ้นมา')
    end
end)

RegisterNetEvent('atf_anyprops:client:deleteFailedProp', function(netId)
    local entity = NetToObj(netId)
    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end)

-- ระบบ Keybinding วางอาวุธ (เปลี่ยนปุ่มได้ใน Settings > Key Bindings > FiveM)
RegisterCommand('atf_place_weapon', function()
    if currentPropEntity or isPlacing or isStashing then return end
    
    local ped = cache.ped
    local currentWeaponHash = GetSelectedPedWeapon(ped)
    local isDead = LocalPlayer.state.isDead or LocalPlayer.state.isDowned or LocalPlayer.state.inLaststand or false
    if isDead or IsPedDeadOrDying(ped, true) or IsPedFatallyInjured(ped) or IsPedRagdoll(ped) or IsPedCuffed(ped) then return end
    
    -- ทำงานตอนถืออาวุธอยู่ และไม่ได้อยู่บนรถ
    if currentWeaponHash ~= WEAPON_UNARMED and not IsPedInAnyVehicle(ped, false) then
        local currentWeapon = exports.ox_inventory:getCurrentWeapon()
        if currentWeapon then
            isPlacingWeapon = true
            currentActiveItem = currentWeapon.name
            currentPropMetadata = currentWeapon.metadata
            currentPropSlot = currentWeapon.slot
            
            local coords = GetEntityCoords(ped)
            
            if not HasWeaponAssetLoaded(currentWeaponHash) then
                RequestWeaponAsset(currentWeaponHash, 31, 0)
                local timeout = 0
                while not HasWeaponAssetLoaded(currentWeaponHash) and timeout < 50 do
                    Wait(100)
                    timeout = timeout + 1
                end
            end
            
            currentPropEntity = CreateWeaponObject(currentWeaponHash, 0, coords.x, coords.y, coords.z, true, 1.0, 0)
            
            if not currentPropEntity or currentPropEntity == 0 then
                lib.notify({type = 'error', description = 'ไม่สามารถสร้างโมเดลอาวุธได้ (ไฟล์โมเดลปืนอาจมีปัญหา)'})
                currentPropEntity = nil
                isPlacingWeapon = false
                currentActiveItem = nil
                currentPropMetadata = nil
                currentPropSlot = nil
                return
            end
            
            if currentPropMetadata and currentPropMetadata.components then
                for _, comp in ipairs(currentPropMetadata.components) do
                    local compHash = type(comp) == 'string' and joaat(string.upper(comp)) or comp
                    local compModel = GetWeaponComponentTypeModel(compHash)
                    if compModel and compModel ~= 0 then lib.requestModel(compModel, 1000) end
                    GiveWeaponComponentToWeaponObject(currentPropEntity, compHash)
                end
            end
            
            if currentPropMetadata and currentPropMetadata.tint then
                SetWeaponObjectTintIndex(currentPropEntity, currentPropMetadata.tint)
            end
            
            -- ซ่อนปืนหลัก และเปิดโหมดวางของ
            SetCurrentPedWeapon(ped, WEAPON_UNARMED, true)
            lib.hideTextUI()
            startPlacementMode()
        end
    end
end, false)

-- ปุ่ม Default เป็น E
RegisterKeyMapping('atf_place_weapon', 'Place Weapon', 'keyboard', 'E')

-- ระบบ Keybinding เก็บอาวุธ (เปลี่ยนปุ่มได้ใน Settings > Key Bindings > FiveM)
RegisterCommand('atf_pickup_weapon', function()
    if isPlacing or isStashing or isProcessing then return end
    
    local ped = cache.ped
    local isDead = LocalPlayer.state.isDead or LocalPlayer.state.isDowned or LocalPlayer.state.inLaststand or false
    if isDead or IsPedDeadOrDying(ped, true) or IsPedFatallyInjured(ped) or IsPedRagdoll(ped) or IsPedCuffed(ped) then return end
    
    if GetSelectedPedWeapon(ped) ~= `WEAPON_UNARMED` then return end

    local pCoords = GetEntityCoords(ped)
    local closestWeapon = nil
    local closestDist = Config.Distance.KeyPickup 
    
    if cachedWeapons then
        for _, obj in ipairs(cachedWeapons) do
            if DoesEntityExist(obj) then
                local dist = #(pCoords - GetEntityCoords(obj))
                if dist < closestDist then
                    closestDist = dist
                    closestWeapon = obj
                end
            end
        end
    end

    if closestWeapon then
        isProcessing = true
        lib.hideTextUI()        
        local netId = NetworkGetNetworkIdFromEntity(closestWeapon)
        if netId ~= 0 then
            lib.requestAnimDict("pickup_object", 1000)
            TaskPlayAnim(ped, "pickup_object", "pickup_low", 8.0, -8.0, 1000, 48, 0, false, false, false)
            Wait(500)
            TriggerServerEvent('atf_anyprops:server:pickupProp', netId, 1)
            Wait(1000)
        end
        isProcessing = false
    end
end, false)

-- ผูกปุ่ม Default เป็น Z
RegisterKeyMapping('atf_pickup_weapon', 'Pickup Weapon', 'keyboard', 'Z')

-- ระบบ Keybinding ปุ่มพิเศษในโหมดวางของ (เปลี่ยนปุ่มได้ใน Settings > Key Bindings > FiveM)
RegisterCommand('+atf_snap_ground', function() 
    if isPlacing then reqSnapGround = true end 
end, false)
RegisterKeyMapping('+atf_snap_ground', 'Snap to Ground (Placement)', 'keyboard', 'SEMICOLON')

RegisterCommand('+atf_reset_angle', function() 
    if isPlacing then reqResetAngle = true end 
end, false)
RegisterKeyMapping('+atf_reset_angle', 'Reset (Placement)', 'keyboard', 'APOSTROPHE')

RegisterCommand('+atf_flip_prop', function() 
    if isPlacing then reqFlipProp = true end 
end, false)
RegisterKeyMapping('+atf_flip_prop', 'Swap 90 degree (Placement)', 'keyboard', 'L')

RegisterCommand('+atf_z_up', function() if isPlacing then reqZUp = true end end, false)
RegisterCommand('-atf_z_up', function() reqZUp = false end, false)
RegisterKeyMapping('+atf_z_up', 'Move Up (Placement)', 'keyboard', 'OEM_4') -- ปุ่ม [

RegisterCommand('+atf_z_down', function() if isPlacing then reqZDown = true end end, false)
RegisterCommand('-atf_z_down', function() reqZDown = false end, false)
RegisterKeyMapping('+atf_z_down', 'Move Down (Placement)', 'keyboard', 'OEM_6') -- ปุ่ม ]

-- ระบบเลือกไอเทมจากกระเป๋า (Context Menu) v2
RegisterCommand('atf_item_menu', function()
    if isPlacing or currentPropEntity then
        lib.notify({type = 'error', description = 'คุณกำลังถือหรือวางของอยู่'})
        return
    end

    local items = exports.ox_inventory:GetPlayerItems()
    if not items or #items == 0 then
        lib.notify({type = 'error', description = 'ไม่มีของในกระเป๋า'})
        return
    end

    local options = {}
    for _, item in pairs(items) do
        if item.count > 0 and not string.find(string.upper(item.name), "WEAPON_") then
            table.insert(options, {
                title = item.label,
                description = 'จำนวน: ' .. item.count .. ' ชิ้น',
                icon = 'hand-holding',
                onSelect = function()
                    TriggerEvent('atf_anyprops:client:toggleProp', item.name, item.metadata, item.slot)
                end
            })
        end
    end

    if #options == 0 then
        lib.notify({type = 'warning', description = 'ไม่มีไอเทมทั่วไปที่สามารถถือได้'})
        return
    end

    lib.registerContext({
        id = 'atf_inventory_menu',
        title = '📦 เลือกไอเทมที่จะถือ',
        options = options
    })

    lib.showContext('atf_inventory_menu')
end, false)

-- ผูกปุ่มลัด H (ผู้เล่นสามารถไปเปลี่ยนเองได้ใน Settings > Key Bindings > FiveM)
RegisterKeyMapping('atf_item_menu', 'Open Item Menu', 'keyboard', 'H')