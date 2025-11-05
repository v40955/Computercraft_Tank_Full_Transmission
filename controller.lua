--------------------------------channels----------------------------------------------------------
local channel = 1500
local controllerId = 1550
local tracksId = 1560
local turretId = 1570
--------------------------------------------------------------------------------------------------


local modem = peripheral.find("modem")
modem.open(channel)
local pressed_keys = {}
local displayData = {trackGear = 1, turretGear = 1, speed = 0}

local function recive_data()
    while true do
        local _, _, reciveChannel, _, data, _ = os.pullEvent("modem_message")
        if reciveChannel == channel and data.id == tracksId then
			local recivedData = data.gears
            displayData.trackGear = recivedData.trackGear
			displayData.speed = recivedData.speed
		elseif reciveChannel == channel and data.id == turretId then
			local recivedData = data.gears
			displayData.turretGear = recivedData.turretGear
		end
    end
end
local function input_read()
	while true do
		local event, key = os.pullEvent()
		if event == "key" then
			pressed_keys[keys.getName(key)] = true
		elseif event == "key_up" then
			pressed_keys[keys.getName(key)] = false
		end
		modem.transmit(channel, channel, {id=controllerId, pressedKeys=pressed_keys})
	end
end
local function update_display()
	while true do
		term.clear()
    	term.setCursorPos(1, 1)
    	term.write("Movement Gear: " .. displayData.trackGear)
    	term.setCursorPos(1, 2)
    	term.write("Turret Gear: " .. displayData.turretGear)
    	term.setCursorPos(1, 3)
    	term.write("Speed: " .. displayData.speed .. " blocks/second")
    	sleep(0.05)
	end
end

print("starting")
sleep(0.5)
parallel.waitForAny(input_read, recive_data, update_display)