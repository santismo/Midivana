-- Midivana CC to Mac keystrokes for Hammerspoon.
--
-- Install:
-- 1. Put this file at ~/.hammerspoon/midivana_keys.lua
-- 2. Add this to ~/.hammerspoon/init.lua:
--      midivanaKeys = require("midivana_keys").start()
-- 3. Hammerspoon menu bar icon > Reload Config.
--
-- In Midivana, make custom Key pads or CC controls that send these CC numbers.
-- A value >= threshold fires the key once; value <= releaseBelow arms it again.

local obj = {}

obj.deviceNameContains = nil -- Example: "Midivana", "iPad", or nil to listen to all MIDI devices.
obj.channel = nil -- 1-16 to filter, or nil for all channels.
obj.threshold = 64
obj.releaseBelow = 16
obj.showAlerts = false
obj.listenToVirtualSources = false

-- Change these CC numbers to whatever you assign in Midivana.
obj.mappings = {
  [80] = { key = "left", label = "Left" },
  [81] = { key = "right", label = "Right" },
  [82] = { key = "up", label = "Up" },
  [83] = { key = "down", label = "Down" },
  [84] = { key = "i", label = "I" },
}

obj.inputs = {}
obj.armed = {}

local function containsIgnoreCase(haystack, needle)
  if not needle or needle == "" then return true end
  return string.find(string.lower(haystack or ""), string.lower(needle), 1, true) ~= nil
end

function obj:_stateKey(channel, cc)
  return tostring(channel or "*") .. ":" .. tostring(cc)
end

function obj:_handleCC(deviceName, metadata)
  local cc = tonumber(metadata.controllerNumber)
  local value = tonumber(metadata.controllerValue)
  local channel = tonumber(metadata.channel)
  if not cc or not value then return end
  if self.channel and channel ~= self.channel then return end

  local mapping = self.mappings[cc]
  if not mapping then return end

  local stateKey = self:_stateKey(channel, cc)
  local threshold = mapping.threshold or self.threshold
  local releaseBelow = mapping.releaseBelow or self.releaseBelow
  if self.armed[stateKey] == nil then self.armed[stateKey] = true end

  if value >= threshold and self.armed[stateKey] then
    self.armed[stateKey] = false
    hs.eventtap.keyStroke(mapping.mods or {}, mapping.key, 0)
    if self.showAlerts then
      hs.alert.show("Midivana " .. (mapping.label or mapping.key), 0.25)
    end
  elseif value <= releaseBelow then
    self.armed[stateKey] = true
  end
end

function obj:_attach(name, isVirtual)
  if not containsIgnoreCase(name, self.deviceNameContains) then return end
  local id = (isVirtual and "virtual:" or "device:") .. tostring(name)
  if self.inputs[id] then return end

  local ok, input = pcall(function()
    return isVirtual and hs.midi.newVirtualSource(name) or hs.midi.new(name)
  end)
  if not ok or not input then return end

  local callbackOK = pcall(function()
    input:callback(function(_, deviceName, commandType, _, metadata)
      if commandType == "controlChange" then
        pcall(function() self:_handleCC(deviceName, metadata or {}) end)
      end
    end)
  end)
  if not callbackOK then return end

  self.inputs[id] = input
  if self.showAlerts then hs.alert.show("Midivana keys listening: " .. name, 1.0) end
end

function obj:connect()
  for _, name in ipairs(hs.midi.devices() or {}) do
    self:_attach(name, false)
  end
  if self.listenToVirtualSources then
    for _, name in ipairs(hs.midi.virtualSources() or {}) do
      self:_attach(name, true)
    end
  end
end

function obj:stop()
  for _, input in pairs(self.inputs) do
    pcall(function() input:callback(nil) end)
  end
  self.inputs = {}
  self.armed = {}
end

function obj:start()
  self:stop()
  self:connect()
  return self
end

return obj
