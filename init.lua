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
local wibox        = require('wibox'            )
local timer        = require('gears.timer'      )
local gtable       = require('gears.table'      )
local color        = require('gears.color'      )
local fs           = require('gears.filesystem' )
local awful        = require('awful'            )
local cairo        = require('lgi'              )
local pango        = require('lgi'              ).Pango
local pangocairo   = require('lgi'              ).PangoCairo
local beautiful    = require('beautiful'        )
local math         = require('math'             )
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

--- Battery Status Enum -- {{{
local BatteryState = { Discharging = 1, Charging = 2, Missing = 3, Unknown = 4 }
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

--- bat:getChargeAsPerc -- {{{
-- 
function bat:getChargeAsPerc ()
   local retval = 0

   if self._state == BatteryState.Unknown then
      return 0
   end

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
      if #parts == 2 then
         self._props[parts[1]] = (tonumber(parts[2]) and tonumber(parts[2]) or parts[2])
      end
   end

   self:updateState(BatteryState[self._props.POWER_SUPPLY_STATUS]);
   self:emit_signal("widget::updated")
end
-- }}}

--- bat:update -- {{{
-- Update battery information
function bat:update ()
   if not fs.file_readable(self._batPropPath) then
      self:updateState(BatteryState.Missing)
   else
      awful.spawn.easy_async("cat " .. self._batPropPath,
                             function (stdout, stderr, exitreason, exitcode)
                                self:parseBatProps(stdout, stderr, exitreason, exitcode)
      end)
   end
end
-- }}}

--- bat:updateState -- {{{
----------------------------------------------------------------------
-- 
----------------------------------------------------------------------
function bat:updateState (state)
   if self._state ~= state then
      self._state = state
      self:emit_signal("widget::layout_changed")
   end
end
-- }}}

--- bat:fit -- {{{
function bat:fit(ctx, width, height)   
   return self._textWidth * 2, height
end
-- }}}

--- bat:draw -- {{{
-- 
function bat:draw (w, cr, width, height)
   cr:save()

   self._drawAction[self._state](w, cr, width, height)

   cr:restore()
end
-- }}}

--- bat:drawText -- {{{
-- 
function bat:drawText (w, cr, width, height)
   local perc = self:getChargeAsPerc()
   cr:set_source(color(self._color or beautiful.fg_normal))
   self._pl.text = (perc == 100 and " " or perc >= 10 and "  " or "   ") ..
      self:getChargeAsPerc() .. "%"

   local pad = 5
   cr:translate(width - (self._textWidth + pad), (height/4))
   -- cr:move(width - (self._textWidth + pad), (height / 4))
   cr:show_layout(self._pl)
end
-- }}}

--- bat:drawBattery -- {{{
-- 
function bat:drawBattery (w, cr, width, height)
   cr:set_source(color(self._color or beautiful.fg_urgent))
   cr.line_width = 1

   self:drawEmptyBattery(w, cr, width, height)
   self:fillBattery(w, cr, width, height)
end
-- }}}

--- bat:drawEmptyBattery -- {{{
----------------------------------------------------------------------
-- 
----------------------------------------------------------------------
function bat:drawEmptyBattery (w, cr, width, height)
   cr:set_source(color(self._color or beautiful.fg_urgent))

   cr.line_width = 1

   local bat_height = height * .5
   local bat_width = bat_height * 2
   local bat_x = width * .1
   local bat_y = (height - bat_height) / 2 + height * .05
   
   -- battery body
   cr:rectangle(bat_x, bat_y, bat_width, bat_height)
   cr:stroke()

   -- terminal
   local term_width = bat_width * .1
   local term_height = bat_height * .5
   local term_x = bat_x + bat_width
   local term_y = bat_y + ((bat_height - term_height) / 2)
   
   cr:rectangle(term_x, term_y, term_width, term_height)
   cr:fill()
end
-- }}}

--- bat:fillBattery -- {{{
----------------------------------------------------------------------
-- 
----------------------------------------------------------------------
function bat:fillBattery (w, cr, width, height)
   cr:set_source(color(self._color or beautiful.fg_urgent))
   cr.line_width = 1

   local bat_height = height * .5
   local bat_width = bat_height * 2
   local bat_x = width * .1
   local bat_y = (height - bat_height) / 2 + height * .05
   local fill_x = bat_x + 1
   local fill_y = bat_y + 1
   local fill_width = (bat_width - 2) * (self:getChargeAsPerc() / 100)
   local fill_height = bat_height - 2
   
   cr:rectangle(fill_x, fill_y, fill_width, fill_height)
   cr:fill()
end
-- }}}
   

--- bat:drawPlug -- {{{
-- 
function bat:drawPlug (w, cr, width, height)
   
   cr:set_source(color(self._color or beautiful.fg_normal))

   -- Draw cable
   
   cr.line_width = 1
   cr:move_to(width * .1, height * .8)
   cr:line_to(width * .1, height * .4)
   cr:curve_to(width * .1, height * .3, width * .15, height * .3, width * .15, height * .4)
   cr:line_to(width * .15, height * .7)
   cr:curve_to(width * .15, height * .8, width * .2, height * .8, width * .2, height * .7)
   cr:line_to(width * .2, height * .4)
   cr:curve_to(width * .2, height * .3, width * .25, height * .3, width * .25, height * .4)
   cr:line_to(width * .25, height * .5)
   cr:curve_to(width * .25, height * .6, width * .25, height * .6, width * .3, height * .6)

   -- now the plug

   cr:move_to(width * .4, height * .4)
   cr:curve_to(width * .25, height * .4, width * .25, height * .8, width * .4, height * .8)
   cr:line_to(width * .4, height * .4)
   cr:move_to(width * .4, height * .525)
   cr:line_to(width * .475, height * .525)
   cr:move_to(width * .4, height * .675)
   cr:line_to(width * .475, height * .675)
   
   cr:stroke()   
end
-- }}}

--- bat:drawNoBat -- {{{
----------------------------------------------------------------------
-- 
----------------------------------------------------------------------
function bat:drawNoBat (w, cr, width, height)
   self:drawEmptyBattery(w, cr, width, height)
   
   local bat_height = height * .5
   local bat_width = bat_height * 2
   local bat_x = width * .1
   local bat_y = (height - bat_height) / 2 + height * .05

   cr:move_to(bat_x, bat_y)
   cr:line_to(bat_x + bat_width, bat_y + bat_height)
   cr:move_to(bat_x, bat_y + bat_height)
   cr:line_to(bat_x + bat_width, bat_y)
   
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
   obj._batPropPath = args.batPropPath or "/sys/class/power_supply/" .. obj._batname .. "/uevent"

   obj._timeout     = args.timeout or 15
   obj._timer       = capi.timer({timeout=obj._timeout})
   obj._props       = {}
   obj._pl          = pango.Layout.new(pangocairo.font_map_get_default():create_context())
   obj._initialized = false
   
   -- Setup the widget's font
   local font       = beautiful.get_font()
   --font:set_weight(obj._fontWeight)
   obj._pl:set_font_description(font)
   obj._pl:set_font_description(beautiful.get_font(beautiful and beautiful.font))
   
   -- Calculate text width
   obj._pl.text     = " 000% "
   obj._textHeight  = obj._pl:get_pixel_extents().height
   obj._textWidth   = obj._pl:get_pixel_extents().width
   obj._textHeight  = obj._pl:get_pixel_extents().height

   print(obj._textHeight)
   
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
