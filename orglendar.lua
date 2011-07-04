-- Calendar with Emacs org-mode agenda for Awesome WM
-- Inspired by and contributed from the org-awesome module, copyright of Damien Leone
-- Licensed under GPLv2
-- @author Alexander Yakushev <yakushev.alex@gmail.com>

orglendar = {}

local function parse_agenda(today)
   local result = {}
   local dates = {}
   local maxlen = 20
   local task_name
   for _, file in pairs(orglendar.files) do
      local fd = io.open(file, "r")
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
               if (len > maxlen) and (task_date >= today) then
                  maxlen = len
               end
               table.insert(result, { name = task_name, 
                                      tags = task_tags,
                                      date = task_date})
               if string.sub(d,1,1) == "0" then
                  d = string.sub(d,2,2)
               end
               table.insert(dates,{ y, m, d})
            end
         end
         _, _, task_name = string.find(line, "%*+%s+(.+)")
      end
   end
   table.sort(result, function (a, b) return a.date < b.date end)
   return result, maxlen, dates
end

function create_string(today,date_cl,font)
   date_cl = date_cl or "#AA0000"
   font = font or "monospace"
   local todos, ml, dates = parse_agenda(today)
   local result = ""
   local prev_date
   for _, task in ipairs(todos) do
      if prev_date ~= task.date then
         result = result .. '<span weight = "bold" foreground = "'..date_cl..'">' .. 
            pop_spaces("",task.date,ml+3) .. '</span>' .. "\n"
      end
      result = result .. pop_spaces(task.name,task.tags,ml+3) .. "\n"
      prev_date = task.date
   end
   return '<span font="'..font..'">' .. string.sub(result,1,string.len(result)-1) .. '</span>', dates, ml+3
end

function pop_spaces(s1,s2,maxsize)
   local sps = ""
   for i = 1, maxsize-string.len(s1)-string.len(s2) do
      sps = sps .. " "
   end
   return s1 .. sps .. s2
end

local calendar = nil
local offset = 0

local function remove_calendar()
   if calendar ~= nil then
      naughty.destroy(calendar)
      naughty.destroy(todo)
      calendar = nil
      offset = 0
   end
end

function generate_calendar(offset,today_cl,event_cl,font)
   today_cl = today_cl or "#00FF00"
   event_cl = event_cl or "#AA0000"
   font = font or "monospace"

   local query = os.date("%Y-%m-%d")
   local _, _, cur_year, cur_month, cur_day = string.find(query,"(%d%d%d%d)%-(%d%d)%-(%d%d)")
   cur_month = tonumber(cur_month) + offset
   if cur_month > 12 then
      cur_month = (cur_month % 12) .. "f"
      cur_year = cur_year + 1
   elseif cur_month < 1 then
      cur_month = (cur_month + 12) .. "p"
      cur_year = cur_year - 1
   end
   local cal = awful.util.pread("cal -m " .. cur_month)
   cal = string.gsub(cal, "^%s*(.-)%s*$", "%1")
   local _, _, head, cal = string.find(cal,"(.+%d%d%d%d)\n(.+)")

   local todotext, datearr, leng = create_string(query,event_cl,font)
   for ii = 1, table.getn(datearr) do
      if cur_year == datearr[ii][1] and cur_month == tonumber(datearr[ii][2]) then
	 cal = string.gsub(cal, "(" .. datearr[ii][3] .."[^f])", 
                           '<span weight="bold" foreground = "'..event_cl..'">%1</span>', 1)
      end
   end

   if string.sub(cur_day,1,1) == "0" then
      cur_day = string.sub(cur_day,2)
   end 
   if offset == 0 then
      cal = string.gsub(cal, "(" .. cur_day .."[%s/])", 
                        '<span weight="bold" foreground = "'..today_cl..'">%1</span>', 1)
   end

   cal = head .. "\n" .. cal
   cal = string.format('<span font = "%s">%s</span>', font, cal)
   return { calendar = cal, todo = todotext, length = leng }
end

local function add_calendar(inc_offset)
   local save_offset = offset
   remove_calendar()
   offset = save_offset + inc_offset
   local data = generate_calendar(offset)
   calendar = naughty.notify({ title = os.date("%a, %d %B %Y"),
				text = data.calendar,
				timeout = 0, hover_timeout = 0.5,
				width = 160,
			     })
   todo = naughty.notify({ title = "TO-DO list",
			   text = data.todo,
			   timeout = 0, hover_timeout = 0.5,
			   width = data.length * 7,
			})
end

function orglendar.register(widget)
   widget:add_signal("mouse::enter", function()
                                            add_calendar(0)
                                         end)
   widget:add_signal("mouse::leave", remove_calendar)
   
   widget:buttons(awful.util.table.join( awful.button({ }, 4, function()
                                                                     add_calendar(-1)
                                                                  end),
                                             awful.button({ }, 5, function()
                                                                     add_calendar(1)
                                                                  end)))
end
