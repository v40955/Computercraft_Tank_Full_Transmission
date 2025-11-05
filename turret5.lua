 --------------------------------channels----------------------------------------------------------
local channel = 1500
local controllerId = 1550
local tracksId = 1560
local turretId = 1570
local gyroId = 1555998
--------------------------------settings----------------------------------------------------------
local yawGearsRpm, pitchGearsRpm = {1, 8, 16, 32, 96, 128, 256}, {1, 8, 16, 32, 64, 128, 256}
local maxTurretGear = 4
local yawDir, pitchDir = -1, -1
local stab_Switch = false
local turret_Yaw = 0
local matrix = nil  -- ← add this at the top, shared between stab_Pitch and recive_data
local manualPitchActive = false
local lastR = false
local reference_pitch_value = nil
local last_rpm = 0
local last_update_time = os.clock()
local cannon_pitch = 0
--------------------------------------------------------------------------------------------------


local yaw = peripheral.wrap("left")
local pitch = peripheral.wrap("back")
local fire = "top"
yaw.setTargetSpeed(0)
pitch.setTargetSpeed(0)
local modem = peripheral.find("modem")
modem.open(channel)
local pressedKeys = {}
local x, y, gears = 0, 0, {turretGear = 2}


local function recive_data()
    while true do
        local _, _, reciveChannel, _, data, _ = os.pullEvent("modem_message")
        if reciveChannel == channel and data.id==controllerId then

            for key, _ in pairs(pressedKeys) do
                if not data.pressedKeys[key] then
                    pressedKeys[key] = false
                end
            end
            for key, val in pairs(data.pressedKeys) do
                pressedKeys[key] = val
            end
        
            --pressedKeys = data.pressedKeys
            if pressedKeys.r and not lastR then
                stab_Switch = not stab_Switch
                last_rpm = 0
                cannon_pitch = 0 
                last_update_time = os.clock()
                print("stab toggled:", stab_switch)
                --reference_pitch_value = nil
                --target_pitch = nil  -- reset when toggling
            end
            lastR = pressedKeys.r
        elseif reciveChannel == channel and data.id == gyroId then
            if data.matrix then matrix = data.matrix end
            if data.turret_Yaw ~= nil then turret_Yaw = data.turret_Yaw --[[print(turret_Yaw)]] end
        end
    end
end
local function yaw_rsc() yaw.setTargetSpeed(yawGearsRpm[gears.turretGear] * yawDir * x) end
local function pitch_rsc() pitch.setTargetSpeed(pitchGearsRpm[gears.turretGear] * pitchDir * y) end

local function process_turret_input()
    while true do
        if pressedKeys.up ~= pressedKeys.down then
            y = (pressedKeys.down and 1 or -1)
            manualPitchActive = true
        else y = 0 manualPitchActive = false end
        if pressedKeys.right ~= pressedKeys.left then
            x = (pressedKeys.right and 1 or -1)
        else x = 0 end
        parallel.waitForAll(yaw_rsc, function()
            if manualPitchActive then pitch_rsc() end 
        end)
    end
end
local function process_gearbox_input()
    while true do
        if pressedKeys.v and not pressedKeys.c and gears.turretGear < maxTurretGear then
            gears.turretGear = gears.turretGear + 1
            sleep(0.4)
        elseif pressedKeys.c and not pressedKeys.v and gears.turretGear > 1 then
            gears.turretGear = gears.turretGear - 1
            sleep(0.4)
        end
        sleep() end
end
local function process_gun_input()
    while true do
        if pressedKeys.space then rs.setOutput(fire, true)
        else rs.setOutput(fire, false) end
        sleep()
    end
end

local function send_data()
    while true do
        modem.transmit(channel, channel, {id = turretId, gears=gears})
        sleep()
    end
end

local function process_Delta_Difference(delta_Angle)
    if delta_Angle > 180 then delta_Angle = delta_Angle - 360
    elseif delta_Angle < -180 then delta_Angle = delta_Angle + 360 end
    if math.abs(delta_Angle) < 0.5 then return 0 end
    return math.min(math.max(delta_Angle * 0.5, -40), 40)
end

local function stab_Turret() -- стабилизация башни по заданному углу наведения (desired_Yaw)
    local matrix, delta_Angle, desired_Yaw = {}, 0, 0
    while true do
        if not pressedKeys.left and not pressedKeys.right and stab_Switch then
            desired_Yaw = turret_Yaw
            while not pressedKeys.left and not pressedKeys.right and stab_Switch do
                delta_Angle = desired_Yaw - turret_Yaw
                yaw.setTargetSpeed(-(math.deg(ship.getOmega().y)/6) - process_Delta_Difference(delta_Angle) * -1)
                --print(delta_Angle, desired_Yaw, turret_Yaw)
                os.pullEvent()
            end
        end
        os.pullEvent()
    end
end




function stab_Pitch()
    local base_rpm = 64
    local max_angle_for_accuracy = 9
    local rpm_sign = -1
    local min_pitch, max_pitch = -100, 100
    local target_pitch = 0
    local cannon_pitch = 0
    local pitch_precision = (base_rpm * 2) / 32
    local stabilizerGear = 4  -- Force gear 4
    local max_rpm = pitchGearsRpm[stabilizerGear]

    local function clamp(min, val, max)
        return math.max(min, math.min(val, max))
    end

    local function round(val)
        if val > 0 then return math.floor(val) end
        if val < 0 then return math.ceil(val) end
        return 0
    end

    local function sign(val)
        return (val > 0 and 1) or (val < 0 and -1) or 0
    end

    print(string.format("Pitch precision: %.2f° at %d RPM", pitch_precision, base_rpm))

    while true do
        if stab_Switch and not manualPitchActive and matrix and matrix[2] and matrix[2][3] then
            -- Get turret pitch from matrix
            local pitch_actual = math.deg(math.asin(-clamp(-1, matrix[2][3], 1)))
            local diff = (pitch_actual - cannon_pitch) - target_pitch

            local speed = 2
            local step = pitch_precision
            if math.abs(diff) < max_angle_for_accuracy then
                step = pitch_precision / 2
                speed = 1
            end
            local next_pitch = clamp(min_pitch, cannon_pitch + round(diff / step) * step, max_pitch)
            

            local next_pitch = clamp(min_pitch, cannon_pitch + round(diff / step) * step, max_pitch)
            --local actual_diff = round((next_pitch - cannon_pitch) / (pitch_precision / 2)) * (pitch_precision / 2)
            local movement_gain = 2  -- increase this to 2.0 or more for faster correction
            local actual_diff = round((next_pitch - cannon_pitch) / (pitch_precision / 2)) * (pitch_precision / 2 * movement_gain)
            if actual_diff ~= 0 then
                cannon_pitch = cannon_pitch + actual_diff

                local rpm = speed * base_rpm * sign(actual_diff)
                rpm = clamp(-max_rpm, rpm, max_rpm)
                --rpm = clamp(-pitchGearsRpm[gears.turretGear], rpm, pitchGearsRpm[gears.turretGear])
                pitch.setTargetSpeed(rpm * pitchDir * rpm_sign)
            else
                pitch.setTargetSpeed(0)
            end
        else
            pitch.setTargetSpeed(0)
        end

        sleep(0.05)
    end
end
print("started")
parallel.waitForAny(stab_Turret, stab_Pitch, recive_data, process_turret_input, process_gearbox_input, process_gun_input, send_data)
