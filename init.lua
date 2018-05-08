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

--- Battery Status Enum -- {{{
local BatteryState = { Discharging = 1, Charging = 2, Unknown = 3 }
-- }}}

--- Constructor -- {{{
local bat = setmetatable({}, { __call = function(_, ...) return new(...) end })
bat.__index = bat

local function new(args)
   -- Create the widget and add methods to the metatable
   local obj             = wibox.widget.base.empty_widget()
   gtable.crush(obj, bat, true)
   
   -- Initialize members
   local args       = args or {}
   obj._batname     = args.batname or "BAT"
   obj._batPropPath = args.batPropPath or "/sys/class/power_supply/" ..
                                               obj._batname .. "/uevent"
   obj._timeout     = args.timeout or 15
   obj._timer       = capi.timer({timeout=obj._timeout})
   obj._props       = {}
   obj._pl          = pango.Layout.new(pangocairo.font_map_get_default():create_context())
   obj._initialized = false
   obj._fontFamily  = args.fontFamily or "Verdana"
   obj._fontWeight  = args.fontWeight or pango.Weight.ULTRABOLD

   -- Setup the widget's font
   local font       = pango.FontDescription()
   font:set_family(obj._fontFamily)
   font:set_weight(obj._fontWeight)
   obj._pl:set_font_description(font)

   -- Calculate text width
   obj._pl.text     = " 000%"
   obj._textWidth   = pl:get_pixel_extents().width
   
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

--- bat:isInitialized -- {{{
-- Check that the power supply properties table exists and that the
-- fields we are interested exist in the property table
function bat:isInitialized ()
   return obj._props and
          obj._props.POWER_SUPPLY_STATUS and
          obj._props.POWER_SUPPLY_CHARGE_NOW and      
          obj._props.POWER_SUPPLY_CHARGE_FULL and
          true
end
-- }}}

--- bat:getStatus -- {{{
-- Return the current status of the battery as a value from the
-- BatteryState enum table.
function bat:getStatus ()
   local retval = BatteryState.Unknown

   if not bat:isInitialized() then
      return retval
   end
   
   if self._props.POWER_SUPPLY_STATUS == "Discharging" then
      retval = BatteryState.Discharging
   elseif self._prop.POWER_SUPPLY_STATUS == "Charging" then
      retval = BatteryState.Charging      
   end

   return retval
end
-- }}}

--- bat:getChargeAsPerc -- {{{
-- 
function bat:getChargeAsPerc ()
   local retval = 0

   -- Make sure that the properties table has been filled in and that
   --  we don't accidentally divide by 0
   if bat:isInitialized() and self._prop.POWER_SUPPLY_CHARGE_FULL ~= 0 then
      retval = self._prop.POWER_SUPPLY_CHARGE_NOW /
               self._prop.POWER_SUPPLY_CHARgE_FULL
   end

   -- finally check that the charge percentage isn't greater than 100
   -- if it is return 100
   return retval > 100 and 100 or retval
end
-- }}}

--- update -- {{{
-- Update battery information
function bat:update ()
   awful.spawn.easy_async("cat " .. self._batPropPath,
     function (stdout, stderr, exitreason, exitcode)
        self._props = {}

        for _,v in ipairs(lines(stdout)) do
           gtable.merge(self._props, split(v,'='))
        end

        self._initialized = true
        self:emit_signal("widget::updated")
   end)
end
-- }}}

function bat:fit(ctx, width, height)
   return (width > (height * 2) and (height * 2) or width) + self._textWidth, height
end

--- draw -- {{{
-- 
function bat:draw (w, cr, width, height)
   cr:save()   

   if self:getStatus() == BatteryState.Discharging then
      bat:drawBattery(w, cr, width, height)
   else
      bat:drawPlug(w, cr, width, height)
   end


   bat:drawText(w, cr, width, height)
   
   cr:restore()
end
-- }}}

--- bat:drawText -- {{{
-- 
function bat:drawText (w, cr, width, height)
   self.pl.text = " " .. self.getChargeAsPerc() .. "%"
   cr:translate(width - self.textWidth, 0)
   cr:show_layout(pl)
end
-- }}}

--- bat:drawBattery -- {{{
-- 
function bat:drawBattery (w, cr, width, height)

end
-- }}}

--- bat:drawPlug -- {{{
-- 
function bat:drawPlug (w, cr, width, height)

end
-- }}}

return bat
-- }}}
