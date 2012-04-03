--[[

Copyright 2012 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]

local Timer = require('uv').Timer
local os = require('os')
local table = require('table')

local TIMEOUT_MAX = 2147483647

local lists = {}

function init(list)
  list._idleNext = list
  list._idlePrev = list
end

function peek(list)
  if list._idlePrev == list then
    return nil
  end
  return list._idlePrev
end

function remove(item)
  if item._idleNext then
    item._idleNext._idlePrev = item._idlePrev
  end

  if item._idlePrev then
    item._idlePrev._idleNext = item._idleNext
  end

  item._idleNext = nil
  item._idlePrev = nil
end

function shift(list)
  local elem = list._idlePrev
  remove(elem)
  return elem
end

function append(list, item)
  remove(item)
  item._idleNext = list._idleNext
  list._idleNext._idlePrev = item
  item._idlePrev = list
  list._idleNext = item
end

function isEmpty(list)
  return list._idleNext == list
end

local expiration
expiration = function(timer, msecs)
  return function()
    local now = Timer.now()
    -- pull out the element from back to front, so we can remove elements safely
    while peek(timer) do
      local elem = peek(timer)
      local diff = now - elem._idleStart;
      if ((diff + 1) < msecs) == true then
        p('restart ' .. msecs - diff)
        timer:start(msecs - diff, 0, expiration(timer, msecs))
        return
      else
        remove(elem)
        if elem._onTimeout then
          elem._onTimeout()
        end
      end
    end
    timer:stop()
    timer:close()
    lists[msecs] = nil
  end
end


function _insert(item, msecs)
  item._idleStart = Timer.now()
  item._idleTimeout = msecs

  if msecs < 0 then return end

  local list

  if lists[msecs] then
    list = lists[msecs]
  else
    list = Timer:new()
    init(list)
    list:start(msecs, 0, expiration(list, msecs))
    lists[msecs] = list
  end

  append(list, item)
end

function unenroll(item)
  local list = lists[item._idleTimeout]
  if list and #list.items == 0 then
    -- empty list
    lists[item._idleTimeout] = nil
  end
  item._idleTimeout = -1
end

-- does not start the timer, just initializes the item
function enroll(item, msecs)
  if item._idleNext then
    unenroll(item)
  end
  item._idleTimeout = msecs
  init(item)
end

-- call this whenever the item is active (not idle)
function active(item)
  local msecs = item._idleTimeout
  if msecs and msecs >= 0 then
    local list = lists[msecs]
    if not list or isEmpty(list) then
      _insert(item, msecs)
    else
      item._idleStart = Timer.now()
      append(lists[msecs], item)
    end
  end
end

function setTimeout(duration, callback, ...)
  local args = {...}

  if duration < 1 or duration > TIMEOUT_MAX then
    duration = 1
  end

  local timer = {}
  timer._idleTimeout = duration
  timer._idleNext = timer
  timer._idlePrev = timer
  timer._onTimeout = function()
    callback(unpack(args))
  end
  active(timer)
  return timer
end

function setInterval(period, callback, ...)
  local args = {...}
  local timer = Timer:new()
  timer:start(period, period, function (status)
    callback(unpack(args))
  end)
  return timer
end

function clearTimer(timer)
  timer._onTimeout = nil
  timer:close()
end

local exports = {}
exports.setTimeout = setTimeout
exports.setInterval = setInterval
exports.clearTimer = clearTimer
exports.unenroll = unenroll
exports.enroll = enroll
exports.active = active
return exports
