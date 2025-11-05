--------------------------------channels----------------------------------------------------------
local channel = 1500
local controllerId = 1550
local tracksId = 1560
local turretId = 1570
--------------------------------settings----------------------------------------------------------
local trackGearsRpm = {32, 64, 128, 256}
local maxTrackGear = 4
local rTrackDir, lTrackDir = -1, -1
--------------------------------------------------------------------------------------------------


local rightTrack = peripheral.wrap("front")
local leftTrack = peripheral.wrap("back")
leftTrack.setTargetSpeed(0)
rightTrack.setTargetSpeed(0)
local modem = peripheral.find("modem")
modem.open(channel)
local pressedKeys = {}
local x, y, gears, velocity = 0, 0, {trackGear = 3, speed = 0}, 0
local smoke = "top"
local ess = "bottom"

local function recive_data()
    while true do
        local _, _, reciveChannel, _, data, _ = os.pullEvent("modem_message")
        if reciveChannel == channel and data.id==controllerId then
            pressedKeys = data.pressedKeys
        end
    end
end
local function right_track_rsc() rightTrack.setTargetSpeed(trackGearsRpm[gears.trackGear] * (y - x) * rTrackDir) end
local function left_track_rsc() leftTrack.setTargetSpeed(trackGearsRpm[gears.trackGear] * (y + x) * lTrackDir) end
local function process_track_input()
    while true do
        if pressedKeys.w ~= pressedKeys.s then
            y = (pressedKeys.s and 1 or -1)
        else y = 0 end
        if pressedKeys.a ~= pressedKeys.d then
            x = (pressedKeys.a and 1 or -1)
        else x = 0 end
        parallel.waitForAll(right_track_rsc, left_track_rsc)
    end
end
local function process_gearbox_input()
    while true do
        if pressedKeys.leftShift and not pressedKeys.x and gears.trackGear < maxTrackGear then
            gears.trackGear = gears.trackGear + 1
            sleep(0.4)
        elseif pressedKeys.x and not pressedKeys.leftShift and gears.trackGear > 1 then
            gears.trackGear = gears.trackGear - 1
            sleep(0.4)
        end
        sleep() end
end
local function process_smoke_input()
    while true do
        if pressedKeys.n then rs.setOutput(smoke, true)
        else rs.setOutput(smoke, false) end
        sleep()
    end
end
local function process_ess_input()
    while true do
        if pressedKeys.m then rs.setOutput(ess, true)
        else rs.setOutput(ess, false) end
        sleep()
    end
end

local function collect_data()
    while true do
        velocity = ship.getVelocity()
        gears.speed = math.floor(math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2))
        sleep(0.1)
    end
end
local function send_data()
	while true do
		modem.transmit(channel, channel, {id = tracksId, gears=gears})
		sleep()
	end
end
print("started")
parallel.waitForAny(recive_data, process_smoke_input, process_track_input,process_gearbox_input, collect_data, send_data)