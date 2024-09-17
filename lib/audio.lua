--[[
A Lua module for playing 3D audio using FMOD
by Evaisa
Comments added using ChatGPT because I am a lazy bitch, comments not guaranteed to make sense :3
]]

-- Load the Foreign Function Interface (FFI) library for calling C functions
local ffi = require("ffi")
-- Load the bit operations library
local bit = require("bit")

-- Define C types and functions using FFI
ffi.cdef[[
typedef int FMOD_RESULT;
typedef struct FMOD_SYSTEM FMOD_SYSTEM;
typedef struct FMOD_SOUND FMOD_SOUND;
typedef struct FMOD_CHANNEL FMOD_CHANNEL;
typedef struct FMOD_CHANNELGROUP FMOD_CHANNELGROUP;

// Define a vector structure for 3D coordinates
typedef struct FMOD_VECTOR {
    float x;
    float y;
    float z;
} FMOD_VECTOR;

// Define a structure for sound creation with extended information
typedef struct FMOD_CREATESOUNDEXINFO {
    int cbsize;
    unsigned int length;
} FMOD_CREATESOUNDEXINFO;

// Define FMOD result code for success
static const int FMOD_OK = 0;

// Define FMOD mode flags
static const unsigned int FMOD_DEFAULT      = 0x00000000;
static const unsigned int FMOD_LOOP_OFF     = 0x00000001;
static const unsigned int FMOD_LOOP_NORMAL  = 0x00000002;
static const unsigned int FMOD_3D           = 0x00000010;
static const unsigned int FMOD_CREATESTREAM = 0x00000080;
static const unsigned int FMOD_OPENMEMORY   = 0x00000800;

// Define FMOD initialization flag
static const unsigned int FMOD_INIT_NORMAL = 0x00000000;

// Declare FMOD system functions
FMOD_RESULT FMOD_System_Create(FMOD_SYSTEM **system);
FMOD_RESULT FMOD_System_Init(FMOD_SYSTEM *system, int maxchannels, unsigned int flags, void *extradriverdata);
FMOD_RESULT FMOD_System_CreateSound(FMOD_SYSTEM *system, const char *name_or_data, unsigned int mode, FMOD_CREATESOUNDEXINFO *exinfo, FMOD_SOUND **sound);
FMOD_RESULT FMOD_System_PlaySound(FMOD_SYSTEM *system, FMOD_SOUND *sound, FMOD_CHANNELGROUP *channelgroup, int paused, FMOD_CHANNEL **channel);
FMOD_RESULT FMOD_System_Set3DListenerAttributes(FMOD_SYSTEM *system, int listener, const FMOD_VECTOR *pos, const FMOD_VECTOR *vel, const FMOD_VECTOR *forward, const FMOD_VECTOR *up);
FMOD_RESULT FMOD_System_Update(FMOD_SYSTEM *system);
FMOD_RESULT FMOD_System_Close(FMOD_SYSTEM *system);
FMOD_RESULT FMOD_System_Release(FMOD_SYSTEM *system);

// Declare FMOD sound functions
FMOD_RESULT FMOD_Sound_Release(FMOD_SOUND *sound);

// Declare FMOD channel functions
FMOD_RESULT FMOD_Channel_Set3DAttributes(FMOD_CHANNEL *channel, const FMOD_VECTOR *pos, const FMOD_VECTOR *vel);
FMOD_RESULT FMOD_Channel_SetPaused(FMOD_CHANNEL *channel, int paused);
FMOD_RESULT FMOD_Channel_Stop(FMOD_CHANNEL *channel);
FMOD_RESULT FMOD_Channel_Set3DMinMaxDistance(FMOD_CHANNEL *channel, float min, float max);
]]

-- Determine the FMOD library name based on the operating system
local libname
if ffi.os == "Windows" then
    libname = "fmod"
end
-- Load the FMOD dynamic library
local fmod = ffi.load(libname)

-- Function to check FMOD function results and raise errors
local function check_error(result, message)
    if result ~= fmod.FMOD_OK then
        error(string.format("%s (FMOD error code: %d)", message, result))
    end
end

-- Module table to be returned
local M = {}

-- Create a pointer for the FMOD system
local system_ptr = ffi.new("FMOD_SYSTEM*[1]")
-- Create the FMOD system
local result = fmod.FMOD_System_Create(system_ptr)
check_error(result, "FMOD_System_Create failed")
local system = system_ptr[0]

-- Initialize the FMOD system with 512 channels
result = fmod.FMOD_System_Init(system, 512, fmod.FMOD_INIT_NORMAL, nil)
check_error(result, "FMOD_System_Init failed")

-- Define listener attributes for 3D sound positioning
local listener_pos = ffi.new("FMOD_VECTOR", { x = 0, y = 0, z = 0 })
local listener_vel = ffi.new("FMOD_VECTOR", { x = 0, y = 0, z = 0 })
local listener_forward = ffi.new("FMOD_VECTOR", { x = 0, y = 0, z = 1 })
local listener_up = ffi.new("FMOD_VECTOR", { x = 0, y = 1, z = 0 })

-- Function to set the listener's position in the 3D space
local function set_listener_position(x, y, z)
    listener_pos.x = x
    listener_pos.y = y
    listener_pos.z = z

    local result = fmod.FMOD_System_Set3DListenerAttributes(system, 0, listener_pos, listener_vel, listener_forward, listener_up)
    check_error(result, "FMOD_System_Set3DListenerAttributes failed")
end

-- Expose the listener position function
M.set_listener_position = set_listener_position

-- Function to update the FMOD system (should be called every frame)
local function update()
    local result = fmod.FMOD_System_Update(system)
    check_error(result, "FMOD_System_Update failed")
end

-- Expose the update function
M.update = update

-- Define the AudioSource class
local AudioSource = {}
AudioSource.__index = AudioSource

-- Method to play the audio source
function AudioSource:play()
    local result = fmod.FMOD_Channel_SetPaused(self.channel, 0)
    check_error(result, "FMOD_Channel_SetPaused failed")
end

-- Method to set the position of the audio source in 3D space
function AudioSource:set_position(x, y, z)
    self.position.x = x
    self.position.y = y
    self.position.z = z

    local result = fmod.FMOD_Channel_Set3DAttributes(self.channel, self.position, self.velocity)
    check_error(result, "FMOD_Channel_Set3DAttributes failed")
end

-- Method to set the proximity range for 3D sound attenuation
function AudioSource:set_proximity_range(min_distance, max_distance)
    local result = fmod.FMOD_Channel_Set3DMinMaxDistance(self.channel, min_distance, max_distance)
    check_error(result, "FMOD_Channel_Set3DMinMaxDistance failed")
end

-- Method to stop the audio source
function AudioSource:stop()
    local result = fmod.FMOD_Channel_Stop(self.channel)
    check_error(result, "FMOD_Channel_Stop failed")
end

-- Method to release the audio source resources
function AudioSource:release()
    self:stop()
    local result = fmod.FMOD_Sound_Release(self.sound)
    check_error(result, "FMOD_Sound_Release failed")
end

-- Function to create a new audio source
local function create_audio_source(params)
    local self = setmetatable({}, AudioSource)

    local sound_ptr = ffi.new("FMOD_SOUND*[1]")

    if params.from_memory then
        -- Load audio data from memory
        local data_length = #params.data
        local c_audio_data = ffi.new("uint8_t[?]", data_length)
        ffi.copy(c_audio_data, params.data, data_length)

        local exinfo = ffi.new("FMOD_CREATESOUNDEXINFO")
        exinfo.cbsize = ffi.sizeof("FMOD_CREATESOUNDEXINFO")
        exinfo.length = data_length

        -- Set mode flags for opening memory with 3D and looping
        local mode = bit.bor(fmod.FMOD_OPENMEMORY, fmod.FMOD_3D, fmod.FMOD_LOOP_NORMAL)
        result = fmod.FMOD_System_CreateSound(system, c_audio_data, mode, exinfo, sound_ptr)
    else
        -- Load audio data from a file
        local mode = bit.bor(fmod.FMOD_DEFAULT, fmod.FMOD_3D)
        if params.loop then
            mode = bit.bor(mode, fmod.FMOD_LOOP_NORMAL)
        else
            mode = bit.bor(mode, fmod.FMOD_LOOP_OFF)
        end
        result = fmod.FMOD_System_CreateSound(system, params.filename, mode, nil, sound_ptr)
    end

    check_error(result, "FMOD_System_CreateSound failed")
    self.sound = sound_ptr[0]

    -- Play the sound in paused state
    local channel_ptr = ffi.new("FMOD_CHANNEL*[1]")
    result = fmod.FMOD_System_PlaySound(system, self.sound, nil, 1, channel_ptr)
    check_error(result, "FMOD_System_PlaySound failed")
    self.channel = channel_ptr[0]

    -- Set initial position and velocity
    self.position = ffi.new("FMOD_VECTOR", { x = params.x or 0, y = params.y or 0, z = params.z or 0 })
    self.velocity = ffi.new("FMOD_VECTOR", { x = 0, y = 0, z = 0 })

    -- Set 3D attributes for the channel
    result = fmod.FMOD_Channel_Set3DAttributes(self.channel, self.position, self.velocity)
    check_error(result, "FMOD_Channel_Set3DAttributes failed")

    -- Set the proximity range if provided, else use default values
    if params.min_distance and params.max_distance then
        self:set_proximity_range(params.min_distance, params.max_distance)
    else
        self:set_proximity_range(1.0, 5000.0)
    end

    return self
end

-- Expose the create_audio_source function
M.create_audio_source = create_audio_source

-- Function to clean up the FMOD system resources
local function cleanup()
    local result = fmod.FMOD_System_Close(system)
    check_error(result, "FMOD_System_Close failed")

    result = fmod.FMOD_System_Release(system)
    check_error(result, "FMOD_System_Release failed")
end

-- Expose the cleanup function
M.cleanup = cleanup

-- Return the module table
return M
