# Midivana Mac Key Setup

Midivana sends MIDI CC messages from its Mac key pads. The preferred receiver is the Qwerty Fretboard app, which now creates a MIDI destination named `qwerty-fretboard control` and lets you map incoming CCs to QWERTY commands in Settings.

Default Midivana key row:

- CC 80: Left arrow
- CC 81: Right arrow
- CC 83: Down arrow
- CC 82: Up arrow
- CC 84: I key

Qwerty Fretboard setup:

1. Connect the iPad to the Mac and enable the iPad/CoreMIDI connection in Audio MIDI Setup if needed.
2. Open Qwerty Fretboard and leave `Receive MIDI CC from Midivana` enabled in Settings.
3. In Midivana, choose `qwerty-fretboard control` as the MIDI output destination.
4. Turn on `Show Mac key pads` in Midivana Performance settings.
5. Edit the key pads in Midivana's Keys settings, or edit the receiving CC mappings in Qwerty Fretboard Settings.

Optional Hammerspoon fallback:

1. In Midivana, choose the Mac or iPad/CoreMIDI connection as the MIDI output destination.
2. Put this script in `~/.hammerspoon/init.lua`.
3. Reload Hammerspoon.

```lua
local ccToKey = {
  [80] = { key = "left", label = "Left" },
  [81] = { key = "right", label = "Right" },
  [83] = { key = "down", label = "Down" },
  [82] = { key = "up", label = "Up" },
  [84] = { key = "i", label = "I" },
}

local threshold = 64
local releaseBelow = 16
local showAlerts = false
local listenToVirtualSources = false
local midiInputs = {}
local armed = {}

local function stateKey(deviceName, channel, cc)
  return tostring(deviceName or "?") .. ":" .. tostring(channel or "*") .. ":" .. tostring(cc)
end

local function triggerKey(mapping)
  hs.eventtap.keyStroke(mapping.mods or {}, mapping.key, 0)
  if showAlerts then
    hs.alert.show("Midivana " .. (mapping.label or mapping.key), 0.25)
  end
end

local function handleCC(deviceName, metadata)
  if not metadata then return end
  local cc = tonumber(metadata.controllerNumber)
  local value = tonumber(metadata.controllerValue)
  local channel = tonumber(metadata.channel)
  if not cc or not value then return end

  local mapping = ccToKey[cc]
  if not mapping then return end

  local key = stateKey(deviceName, channel, cc)
  if armed[key] == nil then armed[key] = true end

  if value >= threshold and armed[key] then
    armed[key] = false
    triggerKey(mapping)
  elseif value <= releaseBelow then
    armed[key] = true
  end
end

local function attachMidi(name, isVirtual)
  local id = (isVirtual and "virtual:" or "device:") .. tostring(name)
  if midiInputs[id] then return end

  local ok, input = pcall(function()
    return isVirtual and hs.midi.newVirtualSource(name) or hs.midi.new(name)
  end)
  if not ok or not input then return end

  local callbackOK = pcall(function()
    input:callback(function(_, deviceName, commandType, _, metadata)
      if commandType == "controlChange" then
        pcall(handleCC, deviceName, metadata)
      end
    end)
  end)
  if not callbackOK then return end

  midiInputs[id] = input
end

local function stopMidi()
  for _, input in pairs(midiInputs) do
    pcall(function() input:callback(nil) end)
  end
  midiInputs = {}
  armed = {}
end

local function connectMidi()
  stopMidi()

  for _, name in ipairs(hs.midi.devices() or {}) do
    attachMidi(name, false)
  end
  if listenToVirtualSources then
    for _, name in ipairs(hs.midi.virtualSources() or {}) do
      attachMidi(name, true)
    end
  end

  local count = 0
  for _ in pairs(midiInputs) do count = count + 1 end
  hs.alert.show("Midivana MIDI key listener: " .. count .. " inputs", 1.0)
end

connectMidi()
```

To add another key, add another CC line:

```lua
ccToKey[85] = { key = "space", label = "Space" }
ccToKey[86] = { key = "return", label = "Return" }
ccToKey[87] = { mods = {"cmd"}, key = "s", label = "Save" }
```

Then assign that CC number to a Midivana key pad.
