-------------------------------------------------------------------------------
-- init.lua for awesome-battery                                              --
-- Copyright (c) 2018 Tom Hartman (thomas.lees.hartman@gmail.com)            --
--                                                                           --
-- This program is free software; you can redistribute it and/or             --
-- modify it under the terms of the GNU General Public License               --
-- as published by the Free Software Foundation; either version 2            --
-- of the License, or the License, or (at your option) any later             --
-- version.                                                                  --
--                                                                           --
-- This program is distributed in the hope that it will be useful,           --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of            --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             --
-- GNU General Public License for more details.                              --
-------------------------------------------------------------------------------

--- Commentary -- {{{
-- A battery widget for awesome
-- }}}

--- awesome-battery -- {{{

--- Libraries -- {{{
local setmetatable = setmetatable
local wibox        = require('wibox'       )
local timer        = require('gears.timer' )
local gtable       = require('gears.table' )
local awful        = require('awful'       )
local cairo        = require('lgi'         )
local pango        = require('lgi'         ).Pango
local pangocairo   = require('lgi'         ).Pango.Cairo
local capi         = {timer = timer}
-- }}}

--- String Helper Functions -- {{{

--- lines -- {{{
-- Split multi-line string `str' into a set of strings by newline
function lines (str)
   if str == nil then return {} end
   
   local t = {}
   local function helper(line) table.insert(t, line) return "" end
   helper((str:gsub("(.-)\r?\n", helper)))
   return t
end
-- }}}

--- split -- {{{
-- Split a string `str' by delimiter `delim'
function split (str, delim)
   if str == nil then return {} end

   local t = {}
   local function helper(line) table.insert(t, part) return "" end
   helper((str:gsub("(.-)" .. delim, helper)))

   return t   
end
-- }}}

-- }}}

--- Table Helper Functions -- {{{

--- map -- {{{
-- Apply function `fn' to all members of table `t' and return as a new table
function map (fn,t)
   local retval = {}

   for k,v in pairs(t) do
      retval[k] = fn(v)
   end

   return retval
end
-- }}}


-- }}}

--- Constructor -- {{{
local bat = setmetatable({}, { __call = function(_, ...) return new(...) end })
bat.__index = bat

local function new(args)
   -- Create the widget and add methods to the metatable
   local obj             = wibox.widget.base.empty_widget()
   gtable.crush(obj, bat, true)
   
   -- Initialize members
   local args            = args or {}
   obj._batname          = args.batname or "BAT"
   obj._batPropPath      = args.batPropPath or "/sys/class/power_supply/" ..
                                               obj._batname .. "/uevent"
   obj._timeout          = args.timeout or 15
   obj._props            = {}
   obj._timer            = capi.timer({timeout=obj._timeout})
   
   -- Setup the update timer
   obj._timer.connect_signal("timeout", function() obj:update() end)
   obj._timer:start()

   -- Initialize the properties
   obj:update()
   
   return obj
end

function bat.mt.__call(_, ...)
   return new(...)
end
--- }}}

--- update -- {{{
-- Update battery information
function bat:update ()
   awful.spawn.easy_async("cat " .. self._batPropPath,
     function (stdout, stderr, exitreason, exitcode)
        self._props = {}

        for _,v in ipairs(lines(stdout)) do
           gtable.merge(self._props, split(v,'='))
        end
        
        self:emit_signal("widget::updated")
   end)
end
-- }}}

--- draw -- {{{
-- 
function bat:draw (w, cr, width, height)
   cr:save()   
   
   
   cr:restore()
end
-- }}}

return bat
-- }}}
