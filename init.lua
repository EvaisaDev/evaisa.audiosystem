package.path = package.path .. ";./mods/evaisa.audiosystem/lib/?.lua"
package.path = package.path .. ";./mods/evaisa.audiosystem/lib/?/init.lua"
package.cpath = package.cpath .. ";./mods/evaisa.audiosystem/bin/?.dll"
package.cpath = package.cpath .. ";./mods/evaisa.audiosystem/bin/?.exe"

local function load(modulename)
	local errmsg = ""
	for path in string.gmatch(package.path, "([^;]+)") do
		local filename = string.gsub(path, "%?", modulename)
		local file = io.open(filename, "rb")
		if file then
			-- Compile and return the module
			return assert(loadstring(assert(file:read("*a")), filename))
		end
		errmsg = errmsg .. "\n\tno file '" .. filename .. "' (checked with custom loader)"
	end
	return errmsg
end


-- main.lua
local audio = require("audio")

-- Set listener position
audio.set_listener_position(0, 0, 0)

-- Create an audio source from a file
local source = audio.create_audio_source({
    filename = "mods/evaisa.audiosystem/audio/wawa.wav", -- Replace with your audio file path
    x = 5, y = 0, z = 0,             -- Initial position
    loop = true,                     -- Loop the audio
    min_distance = 1.0,              -- Proximity range
    max_distance = 100.0
})

function OnWorldPreUpdate()
    -- Update the audio system
    audio.update()

    -- Move the audio source in a circular path
    local t = os.clock()
    local x = math.cos(t) * 5
    local z = math.sin(t) * 5
    source:set_position(x, 0, z)
end

function OnPlayerSpawned()
	source:play()
end