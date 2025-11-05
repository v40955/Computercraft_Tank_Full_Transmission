local modem = peripheral.find("modem") or error("No modem attached", 0)
local frequencyRecieve, frequencySend = 1500, 1500 -- ←←←←← frequency change here (a number from 0 to 65000) ←←←←← ←←←←← frequency change here (a number from 0 to 65000) ←←←←←


local function sender()
    while true do
        matrix = ship.getRotationMatrix()
        yaw = math.deg(math.atan2(matrix[1][3], matrix[3][3])) % 360
        modem.transmit(frequencySend, frequencyRecieve, {
            id = 1555998,
            turret_Yaw = yaw,
            matrix = matrix,
            omega = ship.getOmega(),
            shipYaw = ship.getYaw()
        })
        os.sleep()
    end
end

parallel.waitForAny(sender)