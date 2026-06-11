Config = {}

-- Discord Webhook / Systems
Config.System = {
    WebhookURL = "ใส่_LINK_WEBHOOK_ของคุณที่นี่",
    AdminGroups = { 'group.admin', 'group.mod' } 
}

-- Roleplay Config
Config.Roleplay = {
    EnableActionCommand = true,  -- true = เปิดการใช้ /me หรือ /do ตอนทำอนิเมชั่น | false = ปิด
    CommandType = 'me'           -- /me = me, /do = do, /ame = ame
}

-- ระบบจับเวลาซ่อน UI วางอาวุธ
Config.UI = {
    WeaponHideTimer = 10000      -- ระยะเวลาแสดงปุ่มแนะนำการวางอาวุธ (มิลลิวินาที)
}

-- Action Wrapper ระบบ Roleplay
Config.PerformAction = function(text)
    if not Config.Roleplay.EnableActionCommand then return end 
    
    ExecuteCommand(Config.Roleplay.CommandType .. ' ' .. text)
end

-- ระบบของที่ล็อคจากรถ จะตกถ้าเอียงเกิน คว่ำเกิน หรือชนแรงเกิน
Config.VehicleCrash = {
    DamageDrop = 50.0, -- เลือดรถโดนดาเมจเท่านี้ในทีเดียว ของจะหลุดจากรถ
    MaxRoll = 55.0,    -- เอียงซ้าย/ขวาเกินกี่องศา ของจะหลุด
    MaxPitch = 55.0    -- ตีลังกาหน้า/หลังเกินกี่องศา ของจะหลุด
}

-- ระยะการใช้งาน
Config.Distance = {
    Placement = 10.0,    -- ระยะวางของรอบตัว (เมตร)
    TargetPickup = 3.5,  -- ระยะมองเห็นของ ox_target (เมตร)
    TargetGive = 2.0,    -- ระยะส่งของให้คนอื่น (เมตร)
    KeyPickup = 1.5,     -- ระยะที่กดปุ่มเก็บอาวุธได้ (เมตร)
    ServerCheck = 5.0,   -- ระยะป้องกันโปรดึงของไกลๆ
    DebugMarker = 20.0   -- ระยะมองเห็นจุดแดงโหมด Debug
}

-- การควบคุมโหมดวางของ
Config.Controls = {
    StepRot = 15.0,     -- หมุนปกติ (องศา)
    StepRotFine = 1.0,  -- หมุนละเอียด (Shift + ปุ่มอื่น)
    StepZ = 0.1,        -- ขึ้น-ลงปกติ (เมตร)
    StepZFine = 0.01    -- ยกขึ้นลงละเอียด (Shift + ปุ่มอื่น)
}

-- ค้นหา Bone ID https://wiki.rage.mp/index.php?title=Bones
Config.Items = {
    -- --------------------------------------
    -- ของใช้ทั่วไป ไว้เทส ทดสอบ
    -- --------------------------------------
    ['prop_coffee'] = {
        prop = 'p_amb_coffeecup_01',
        bone = 28422,
        pos = vec3(0.0, 0.0, 0.0),
        rot = vec3(0.0, 0.0, 0.0),
        animDict = 'amb@world_human_drinking@coffee@male@idle_a', 
        animName = 'idle_c',
        animFlag = 49
    },

    ['prop_umbrella'] = {
        prop = 'p_amb_brolly_01',
        bone = 28422,
        pos = vec3(0.000, 0.030, -0.030),
        rot = vec3(0.000, 0.000, 0.000),
        animDict = 'amb@world_human_drinking@coffee@male@base',
        animName = 'base',
        animFlag = 49,
        singlePlace = true, -- วางได้ทีละชิ้นเท่านั้น
    },
    
    -- --------------------------------------
    -- ร้าน Mighty Bush
    -- --------------------------------------
    ['infinite_love_bouquet'] = {
        prop = 'prop_snow_flower_02',
        bone = 28422,
        pos = vec3(0.120, -0.090, -0.060),
        rot = vec3(3.000, 66.000, 3.000),
        animDict = 'impexp_int-0',
        animName = 'mp_m_waremech_01_dual-0',
        animFlag = 49,
    },

    ['ivory_honor_bouquet'] = {
        prop = 'prop_snow_flower_02',
        bone = 28422,
        pos = vec3(0.120, -0.090, -0.060),
        rot = vec3(3.000, 66.000, 3.000),
        animDict = 'impexp_int-0',
        animName = 'mp_m_waremech_01_dual-0',
        animFlag = 49,
    },

    ['soft_sunrise_bouquet'] = {
        prop = 'prop_snow_flower_02',
        bone = 28422,
        pos = vec3(0.120, -0.090, -0.060),
        rot = vec3(3.000, 66.000, 3.000),
        animDict = 'impexp_int-0',
        animName = 'mp_m_waremech_01_dual-0',
        animFlag = 49,
    },

    ['velvet_peony_bouquet'] = {
        prop = 'prop_snow_flower_02',
        bone = 28422,
        pos = vec3(0.120, -0.090, -0.060),
        rot = vec3(3.000, 66.000, 3.000),
        animDict = 'impexp_int-0',
        animName = 'mp_m_waremech_01_dual-0',
        animFlag = 49,
    },

    -- --------------------------------------
    -- Government / Police
    -- --------------------------------------
    -- กรวยจราจร (ชนแล้วกระเด็น)
    ['prop_traffic_cone'] = {
        prop = 'prop_roadcone02a',
        bone = 28422,
        pos = vec3(-0.000, -0.060, -0.195), -- ปรับให้เข้ามืออีกที
        rot = vec3(15.000, 0.000, 0.000),
        animDict = 'anim@heists@box_carry@',
        animName = 'idle',
        animFlag = 49,
        collision = true, -- ชนได้
        freeze = false,    -- ไม่แช่แข็ง (รถชนแล้วปลิว)
    },

    -- แผงกั้นจราจร (ชนแล้วไม่กระเด็น)
    ['prop_police_barrier'] = {
        prop = 'prop_barrier_work05',
        bone = 28422,
        pos = vec3(0.030, -0.135, -1.020), -- ปรับให้เข้ามืออีกที
        rot = vec3(0.0, 0.0, 0.0),
        animDict = 'anim@heists@box_carry@',
        animName = 'idle',
        animFlag = 49,
        heavy = true,     -- ของหนัก บังคับเดิน
        collision = true, -- ชนได้
        freeze = true,     -- แช่แข็ง (รถชนแล้วรถพัง แผงไม่ปลิว)
        singlePlace = true, -- วางได้ทีละชิ้นเท่านั้น
    },
    
    ['prop_handcuffs'] = {
        prop = 'p_cs_cuffs_02_s',
        bone = 28422,
        pos = vec3(-0.010, 0.005, -0.020),
        rot = vec3(89.000, -91.000, 0.000),
        animDict = 'amb@world_human_drinking@coffee@male@base', 
        animName = 'base',
        animFlag = 49,
        collision = true,
        freeze = false,
    },

    -- --------------------------------------
    -- Business / Civilian
    -- --------------------------------------
    -- กระเป๋าเอกสาร / กระเป๋าใส่เงิน (ถือห้อยข้างลำตัว แกว่งแขนตามธรรมชาติ)
    ['prop_briefcase'] = {
        prop = 'bkr_prop_biker_case_shut',
        bone = 28422, -- มือขวา
        pos = vec3(0.080, -0.005, -0.025),
        rot = vec3(-96.000, -80.000, 47.000),
        -- ไม่ใส่ animDict เพื่อให้เดินถือแกว่งแขนได้แบบปกติ
        collision = true,
        freeze = false
    },

    -- ถุงเงินใบใหญ่ (บังคับถือสองมือ)
    ['prop_money_bag'] = {
        prop = 'prop_money_bag_01',
        bone = 28422,
        pos = vec3(0.000, 0.000, -0.150),
        rot = vec3(0.000, 0.000, 0.000),
        animDict = 'anim@heists@box_carry@',
        animName = 'idle',
        animFlag = 49,
        heavy = true, -- ของหนัก บังคับเดิน
        collision = true,
        freeze = false
    },

    -- กล่องกระดาษลัง (บังคับถือสองมือ)
    ['prop_cardboard_box'] = {
        prop = 'xm3_prop_xm3_product_box_01',
        bone = 28422,
        pos = vec3(-0.000, -0.065, -0.010),
        rot = vec3(0.000, 0.000, 0.000),
        animDict = 'anim@heists@box_carry@',
        animName = 'idle',
        animFlag = 49,
        heavy = true,
        collision = true,
        freeze = false
    },

    -- ถาดเสิร์ฟอาหาร (ถือระดับอก)
    ['prop_serving_tray'] = {
        prop = 'v_res_tt_tray',
        bone = 28422,
        pos = vec3(0.000, 0.150, -0.100),
        rot = vec3(0.000, 0.000, 0.000),
        animDict = 'anim@heists@box_carry@',
        animName = 'idle',
        animFlag = 49,
        collision = true,
        freeze = false
    },

    -- --------------------------------------
    -- Illegal / Gang
    -- --------------------------------------
    -- กัญชาอัดแท่ง
    ['prop_weed_brick'] = {
        prop = 'bkr_prop_weed_brick_01a',
        bone = 28422,
        pos = vec3(0.050, 0.020, -0.040),
        rot = vec3(0.000, 0.000, 0.000),
        animDict = 'impexp_int-0',
        animName = 'mp_m_waremech_01_dual-0',
        animFlag = 49,
        collision = true,
        freeze = false
    },

    -- โคเคนอัดแท่ง
    ['prop_coke_brick'] = {
        prop = 'bkr_prop_coke_brick_01a',
        bone = 28422,
        pos = vec3(0.050, 0.020, -0.040),
        rot = vec3(0.000, 0.000, 0.000),
        animDict = 'impexp_int-0',
        animName = 'mp_m_waremech_01_dual-0',
        animFlag = 49,
        collision = true,
        freeze = false
    },

    -- ถุงใส่ meth
    ['prop_meth_bag'] = {
        prop = 'tr_prop_meth_smallbag_01a',
        bone = 28422,
        pos = vec3(0.050, 0.020, -0.040),
        rot = vec3(0.000, 0.000, 0.000),
        -- ไม่ใส่ animDict เพื่อให้เดินถือแกว่งแขนได้แบบปกติ
        animFlag = 49,
        collision = true,
        freeze = false
    },

    -- ถุงใส่ cocaine
    ['prop_cocaine_bag'] = {
        prop = 'prop_meth_bag_01',
        bone = 28422,
        pos = vec3(0.050, 0.020, -0.040),
        rot = vec3(0.000, 0.000, 0.000),
        -- ไม่ใส่ animDict เพื่อให้เดินถือแกว่งแขนได้แบบปกติ
        animFlag = 49,
        collision = true,
        freeze = false
    },

    -- ถุงใส่ weed
    ['prop_weed_bag'] = {
        prop = 'sf_prop_sf_bag_weed_01a',
        bone = 28422,
        pos = vec3(0.050, 0.020, -0.040),
        rot = vec3(0.000, 0.000, 0.000),
        -- ไม่ใส่ animDict เพื่อให้เดินถือแกว่งแขนได้แบบปกติ
        animFlag = 49,
        collision = true,
        freeze = false
    },
}