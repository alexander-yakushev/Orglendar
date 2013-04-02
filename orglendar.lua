-- Calendar with Emacs org-mode agenda for Awesome WM
-- Inspired by and contributed from the org-awesome module, copyright of Damien Leone
-- Licensed under GPLv2
-- Version 1.0-awesome-git
-- @author Alexander Yakushev <yakushev.alex@gmail.com>

local pairs = pairs
local ipairs = ipairs
local io = io
local os = os
local tonumber = tonumber
local string = string
local table = table
local awful = require("awful")
local util = awful.util
local theme = require("beautiful")
local naughty = require("naughty")
local print = print

module("orglendar")

files = {}
char_width = nil
text_color = theme.fg_normal or "#FFFFFF"
today_color = theme.fg_focus or "#00FF00"
event_color = theme.fg_urgent or "#FF0000"
font = theme.font or 'monospace 8'
parse_on_show = true
calendar_width = 21
limit_todo_length = nil

local calendar = nil
local todo = nil
local offset = 0

local data = nil

local function pop_spaces(s1, s2, maxsize)
   local sps = ""
   for i = 1, maxsize - string.len(s1) - string.len(s2) do
      sps = sps .. " "
   end
   return s1 .. sps .. s2
end

function parse_agenda()
   local today = os.date("%Y-%m-%d")
   data = { tasks = {}, dates = {}, maxlen = 20 }

   local task_name
   for _, file in pairs(files) do
      local fd = io.open(file, "r")
      if not fd then
         print("W: orglendar: cannot find " .. file)
      else
         for line in fd:lines() do
            local scheduled = string.find(line, "SCHEDULED:")
            local closed    = string.find(line, "CLOSED:")
            local deadline  = string.find(line, "DEADLINE:")

            if (scheduled and not closed) or (deadline and not closed) then
               local _, _, y, m, d  = string.find(line, "(%d%d%d%d)%-(%d%d)%-(%d%d)")
               local task_date = y .. "-"  .. m .. "-" .. d

               if d and task_name and (task_date >= today) then
                  local find_begin, task_start = string.find(task_name, "[A-Z]+%s+")
                  if task_start and find_begin == 1 then
                     task_name = string.sub(task_name, task_start + 1)
                  end
                  local task_end, _, task_tags = string.find(task_name,"%s+(:.+):")
                  if task_tags then
                     task_name = string.sub(task_name, 1, task_end - 1)
                  else
                     task_tags = " "
                  end

                  local len = string.len(task_name) + string.len(task_tags)
                  if (len > data.maxlen) and (task_date >= today) then
                     data.maxlen = len
                  end
                  table.insert(data.tasks, { name = task_name,
                                             tags = task_tags,
                                             date = task_date})
                  data.dates[y .. tonumber(m) .. tonumber(d)] = true
               end
            end
            _, _, task_name = string.find(line, "%*+%s+(.+)")
         end
      end
   end
   table.sort(data.tasks, function (a, b) return a.date < b.date end)
end

local function create_calendar()
   offset = offset or 0

   local now = os.date("*t")
   local cal_month = now.month + offset
   local cal_year = now.year
   if cal_month > 12 then
      cal_month = (cal_month % 12)
      cal_year = cal_year + 1
   elseif cal_month < 1 then
      cal_month = (cal_month + 12)
      cal_year = cal_year - 1
   end

   local last_day = os.date("%d", os.time({ day = 1, year = cal_year,
                                            month = cal_month + 1}) - 86400)
   local first_day = os.time({ day = 1, month = cal_month, year = cal_year})
   local first_day_in_week =
      os.date("%w", first_day)
   local result = "Su Mo Tu We Th Fr Sa\n"
   for i = 1, first_day_in_week do
      result = result .. "   "
   end

   local this_month = false
   for day = 1, last_day do
      local last_in_week = (day + first_day_in_week) % 7 == 0
      local day_str = pop_spaces("", day, 2) .. (last_in_week and "" or " ")
      if cal_month == now.month and cal_year == now.year and day == now.day then
         this_month = true
         result = result ..
            string.format('<span weight="bold" foreground = "%s">%s</span>',
                          today_color, day_str)
      elseif data.dates[cal_year .. cal_month .. day] then
         result = result ..
            string.format('<span weight="bold" foreground = "%s">%s</span>',
                          event_color, day_str)
      else
         result = result .. day_str
      end
      if last_in_week and day ~= last_day then
         result = result .. "\n"
      end
   end

   local header
   if this_month then
      header = os.date("%a, %d %b %Y")
   else
      header = os.date("%B %Y", first_day)
   end
   return header, string.format('<span font="%s" foreground="%s">%s</span>',
                                font, text_color, result)
end

local function create_todo()
   local result = ""
   local maxlen = data.maxlen + 3
   if limit_todo_length and limit_todo_length < maxlen then
      maxlen = limit_todo_length
   end
   local prev_date, limit, tname
   for i, task in ipairs(data.tasks) do
      if prev_date ~= task.date then
         result = result ..
            string.format('<span weight = "bold" foreground = "%s">%s</span>\n',
                          event_color,
                          pop_spaces("", task.date, maxlen))
      end
      tname = task.name
      limit = maxlen - string.len(task.tags) - 3
      if limit < string.len(tname) then
         tname = string.sub(tname, 1, limit - 3) .. "..."
      end
      result = result .. pop_spaces(tname, task.tags, maxlen)

      if i ~= #data.tasks then -- is obsolete: table.getn(data.tasks) then
         result = result .. "\n"
      end
      prev_date = task.date
   end
   if result == "" then
      result = " "
   end
   return string.format('<span font="%s" foreground="%s">%s</span>',
                        font, text_color, result), data.maxlen + 3
end

function get_calendar_and_todo_text(_offset)
   if not data or parse_on_show then
      parse_agenda()
   end

   offset = _offset
   local header, cal = create_calendar()
   return string.format('<span font="%s" foreground="%s">%s</span>\n%s',
                        font, text_color, header, cal), create_todo()
end

local function calculate_char_width()
   return theme.get_font_height(font) * 0.555
end

function hide()
   if calendar ~= nil then
      naughty.destroy(calendar)
      naughty.destroy(todo)
      calendar = nil
      offset = 0
   end
end

function show(inc_offset)
   inc_offset = inc_offset or 0

   if not data or parse_on_show then
      parse_agenda()
   end

   local save_offset = offset
   hide()
   offset = save_offset + inc_offset

   local char_width = char_width or calculate_char_width()
   local header, cal_text = create_calendar()
   calendar = naughty.notify({ title = header,
                               text = cal_text,
                               timeout = 0, hover_timeout = 0.5,
                               width = calendar_width * char_width,
                            })
   todo = naughty.notify({ title = "TO-DO list",
                           text = create_todo(),
                           timeout = 0, hover_timeout = 0.5,
                           width = (data.maxlen + 3) * char_width,
                        })
end

function register(widget)
   widget:connect_signal("mouse::enter", function() show(0) end)
   widget:connect_signal("mouse::leave", hide)
   widget:buttons(util.table.join( awful.button({ }, 3, function()
                                                           parse_agenda()
                                                        end),
                                   awful.button({ }, 4, function()
                                                           show(-1)
                                                        end),
                                   awful.button({ }, 5, function()
                                                           show(1)
                                                        end)))
end
