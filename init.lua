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
local color        = require('gears.color' )
local awful        = require('awful'       )
local cairo        = require('lgi'         )
local pango        = require('lgi'         ).Pango
local pangocairo   = require('lgi'         ).PangoCairo
local beautiful    = require('beautiful'   )
local math         = require('math'        )
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
function split(str, delim, noblanks)   
   local t = {}
   if str == nil then
      return t
   end
   
   local function helper(part) table.insert(t, part) return "" end
   helper((str:gsub("(.-)" .. delim, helper)))
   if noblanks then
      return remove_blanks(t)
   else
      return t
   end
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

local bat = {}

--- bat:isInitialized -- {{{
-- Check that the power supply properties table exists and that the
-- fields we are interested exist in the property table
function bat:isInitialized ()
   return self._props and
      self._props.POWER_SUPPLY_STATUS and
      self._props.POWER_SUPPLY_CHARGE_NOW and
      self._props.POWER_SUPPLY_CHARGE_FULL and
      true
end
-- }}}

--- bat:getStatus -- {{{
-- Return the current status of the battery as a value from the
-- BatteryState enum table.
function bat:getStatus ()
   local retval = BatteryState.Unknown

   if not self:isInitialized() then
      return retval
   end
   
   if self._props.POWER_SUPPLY_STATUS == "Discharging" then
      retval = BatteryState.Discharging
   elseif self._props.POWER_SUPPLY_STATUS == "Charging" then
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
   if self:isInitialized() and self._props.POWER_SUPPLY_CHARGE_FULL ~= 0 then
      retval = math.floor(self._props.POWER_SUPPLY_CHARGE_NOW /
                             self._props.POWER_SUPPLY_CHARGE_FULL * 100)
   end

   -- finally check that the charge percentage isn't greater than 100
   -- if it is return 100
   return retval > 100 and 100 or retval
end
-- }}}

--- bat:parseBatProps -- {{{
-- 
function bat:parseBatProps (stdout, stderr, exitreason, exitcode)
   self._props = {}

   for _,v in ipairs(lines(stdout)) do
      local parts = split(v, '=')
      if table.getn(parts) == 2 then
         self._props[parts[1]] = (tonumber(parts[2]) and tonumber(parts[2]) or parts[2])
      end
   end

   self:emit_signal("widget::updated")
end
-- }}}

--- bat:update -- {{{
-- Update battery information
function bat:update ()
   awful.spawn.easy_async("cat " .. self._batPropPath,
                          function (stdout, stderr, exitreason, exitcode)
                             self:parseBatProps(stdout, stderr, exitreason, exitcode)
   end)
end
-- }}}

--- bat:fit -- {{{
function bat:fit(ctx, width, height)
   print("In fit, width = " .. width .. " height = " .. height)
   return (width > (height * 2) and (height * 2) or width) + self._textWidth, height
end
-- }}}

--- bat:draw -- {{{
-- 
function bat:draw (w, cr, width, height)
   cr:save()   
   
   if self:getStatus() == BatteryState.Discharging then
      self:drawBattery(w, cr, width, height)
   else
      self:drawPlug(w, cr, width, height)
   end

   self:drawText(w, cr, width, height)

   cr:restore()
end
-- }}}

--- bat:drawText -- {{{
-- 
function bat:drawText (w, cr, width, height)
   local perc = self:getChargeAsPerc()
   self._pl.text = (perc == 100 and " " or perc >= 10 and "  " or "   ") ..
      self:getChargeAsPerc() .. "%"
   cr:translate(width - (self._textWidth + 2), height/4)
   cr:show_layout(self._pl)
end
-- }}}

--- bat:drawBattery -- {{{
-- 
function bat:drawBattery (w, cr, width, height)
   cr:set_source(color(self._color or beautiful.fg_normal))
   cr:set_antialias(0)

   local width = width - (self._textWidth or 0)

   local ratio = height / 7

   cr:set_line_width(ratio)
   cr:rectangle(0,0,width-1.5*ratio, height)
   cr:stroke()

   cr:rectangle(width-1.5*ratio, height/4, 1.5*ratio, height/2)
   
   cr:rectangle(ratio,ratio,(width-3*ratio)*(self:getChargeAsPerc()/100), height-2*ratio)
   cr:fill()
end
-- }}}

--- bat:drawPlug -- {{{
-- 
function bat:drawPlug (w, cr, width, height)
   
   cr:set_source(color(self._color or beautiful.fg_normal))

   cr.line_width = 1
   cr:move_to(width * .2, height * .8)
   cr:line_to(width * .2, height * .4)
   cr:curve_to(width * .2, height * .3, width * .25, height * .3, width * .25, height * .4)
   cr:line_to(width * .25, height * .7)
   cr:curve_to(width * .25, height * .8, width * .3, height * .8, width * .3, height * .7)
   cr:line_to(width * .3, height * .4)
   cr:curve_to(width * .3, height * .3, width * .35, height * .3, width * .35, height * .4)
   cr:line_to(width * .35, height * .5)
   cr:curve_to(width * .35, height * .6, width * .35, height * .6, width * .4, height * .6)

   
   -- cr:arc(height/2, height/2, height/3, 0, 2*math.pi)
   -- cr:rectangle(height/2,height/6,5,2*(height/3))
   -- cr:rectangle(0, height/2-1, height/6,2)
   -- cr:rectangle(height/2+5, height * .25, 3, 2)
   -- cr:rectangle(height/2+5, height * .66, 3, 2)

   cr:stroke()
end
-- }}}

--- Constructor -- {{{
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
   
   obj._font        = "proggytiny 8"
   obj._fontFamily  = args.fontFamily or "Verdana"
   obj._fontWeight  = args.fontWeight or pango.Weight.LIGHT

   -- Setup the widget's font
   --local font       = pango.FontDescription.from_string("proggytiny 8")
   --font:set_weight(obj._fontWeight)
   --obj._pl:set_font_description(font)
   obj._pl:set_font_description(beautiful.get_font(beautiful and beautiful.font))
   
   -- Calculate text width
   obj._pl.text     = " 000% "
   obj._textWidth   = obj._pl:get_pixel_extents().width
   
   -- Setup the update timer
   obj._timer:connect_signal("timeout", function() obj:update() end)
   obj._timer:start()

   -- Initialize the properties
   obj:update()
   
   return obj
end

--- }}}

return setmetatable(bat,{__call = function(_,...) return new(...) end})
-- }}}
