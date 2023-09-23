local future = {
    callbacks = {}
}
local ffi = require("ffi")
local bit = require("bit")
local cast = ffi.cast
local unpack = table.unpack
local bor = bit.bor

ffi.cdef[[
    typedef void(__thiscall* get_text_size_t)(void*, unsigned long, const wchar_t*, int&, int&);  
    typedef unsigned int(__thiscall* get_cursor_pos_t)(void*, int*, int*);
    typedef unsigned int(__thiscall* set_cursor_pos_t)(void*, int, int);
    typedef unsigned int(__thiscall* lock_cursor_t)(void*);  
    typedef unsigned int(__thiscall* unlock_cursor_t)(void*);
    typedef unsigned char wchar_t;
    typedef int(__thiscall* ConvertAnsiToUnicode_t)(void*, const char*, wchar_t*, int);
    typedef int(__thiscall* ConvertUnicodeToAnsi_t)(void*, const wchar_t*, char*, int);
    typedef wchar_t*(__thiscall* FindSafe_t)(void*, const char*);
    typedef void(__thiscall* draw_set_color_t)(void*, int, int, int, int); 
    typedef void(__thiscall* draw_filled_rect_t)(void*, int, int, int, int); 
    typedef void(__thiscall* draw_outlined_rect_t)(void*, int, int, int, int); 
    typedef void(__thiscall* draw_line_t)(void*, int, int, int, int); 
    typedef void(__thiscall* draw_poly_line_t)(void*, int*, int*, int);
    typedef void(__thiscall* draw_outlined_circle_t)(void*, int, int, int, int); 
    typedef void(__thiscall* draw_filled_rect_fade_t)(void*, int, int, int, int, unsigned int, unsigned int, bool);
    typedef void(__thiscall* draw_set_text_font_t)(void*, unsigned long); 
    typedef void(__thiscall* draw_set_text_color_t)(void*, int, int, int, int); 
    typedef void(__thiscall* draw_set_text_pos_t)(void*, int, int);  
    typedef void(__thiscall* draw_print_text_t)(void*, const wchar_t*, int, int);  
    typedef void(__thiscall* set_font_glyph_t)(void*, unsigned long, const char*, int, int, int, int, unsigned long, int, int);
    typedef unsigned int(__thiscall* create_font_t)(void*); 
]]

local function uuid(len)
    local res, len = "", len or 32
    for i=1, len do
        res = res .. string.char(client.random_int(97, 122))
    end
    return res
end

local interface_mt = {}

function interface_mt.get_function(self, index, ret, args)
    local ct = uuid() .. "_t"

    args = args or {}
    if type(args) == "table" then
        table.insert(args, 1, "void*")
    else
        return error("args has to be of type table", 2)
    end
    local success, res = pcall(ffi.cdef, "typedef " .. ret .. " (__thiscall* " .. ct .. ")(" .. table.concat(args, ", ") .. ");")
    if not success then
        error("invalid typedef: " .. res, 2)
    end

    local interface = self[1]
    local success, func = pcall(ffi.cast, ct, interface[0][index])
    if not success then
        return error("failed to cast: " .. func, 2)
    end

    return function(...)
        local success, res = pcall(func, interface, ...)

        if not success then
            return error("call: " .. res, 2)
        end

        if ret == "const char*" then
            return res ~= nil and ffi.string(res) or nil
        end
        return res
    end
end

local function create_interface(dll, interface_name)
    local interface = (type(dll) == "string" and type(interface_name) == "string") and client.create_interface(dll, interface_name) or dll
    return setmetatable({ffi.cast(ffi.typeof("void***"), interface)}, {__index = interface_mt})
end



local localize = create_interface("localize.dll", "Localize_001")
local convert_ansi_to_unicode = localize:get_function(15, "int", {"const char*", "wchar_t*", "int"})
local convert_unicode_to_ansi = localize:get_function(16, "int", {"const wchar_t*", "char*", "int"})
local find_safe = localize:get_function(12, "wchar_t*", {"const char*"})

local isurface = create_interface("vguimatsurface.dll", "VGUI_Surface031")

local fn_draw_set_color            = isurface:get_function(15, "void", {"int", "int", "int", "int"})
local fn_draw_filled_rect          = isurface:get_function(16, "void", {"int", "int", "int", "int"})
local fn_draw_outlined_rect        = isurface:get_function(18, "void", {"int", "int", "int", "int"})
local fn_draw_line                 = isurface:get_function(19, "void", {"int", "int", "int", "int"})
local fn_draw_poly_line            = isurface:get_function(20, "void", {"int*", "int*", "int",})
local fn_draw_set_text_font        = isurface:get_function(23, "void", {"unsigned long"})
local fn_draw_set_text_color       = isurface:get_function(25, "void", {"int", "int", "int", "int"})
local fn_draw_set_text_pos         = isurface:get_function(26, "void", {"int", "int"})
local fn_draw_print_text           = isurface:get_function(28, "void", {"const wchar_t*", "int", "int" })

local fn_draw_get_texture_id       = isurface:get_function(34, "int",  {"const char*"}) -- new
local fn_draw_get_texture_file     = isurface:get_function(35, "bool", {"int", "char*", "int"}) -- new
local fn_draw_set_texture_file     = isurface:get_function(36, "void", {"int", "const char*", "int", "bool"}) -- new
local fn_draw_set_texture_rgba     = isurface:get_function(37, "void", {"int", "const unsigned char*", "int", "int"}) -- new
local fn_draw_set_texture          = isurface:get_function(38, "void", {"int"}) -- new
local fn_delete_texture_by_id      = isurface:get_function(39, "void", {"int"}) -- new
local fn_draw_get_texture_size     = isurface:get_function(40, "void", {"int", "int&", "int&"}) -- new
local fn_draw_textured_rect        = isurface:get_function(41, "void", {"int", "int", "int", "int"})
local fn_is_texture_id_valid       = isurface:get_function(42, "bool", {"int"}) -- new
local fn_create_new_texture_id     = isurface:get_function(43, "int",  {"bool"}) -- new

local fn_unlock_cursor             = isurface:get_function(66, "void")
local fn_lock_cursor               = isurface:get_function(67, "void")
local fn_create_font               = isurface:get_function(71, "unsigned int")
local fn_set_font_glyph            = isurface:get_function(72, "void", {"unsigned long", "const char*", "int", "int", "int", "int", "unsigned long", "int", "int"})
local fn_get_text_size             = isurface:get_function(79, "void", {"unsigned long", "const wchar_t*", "int&", "int&"})
local fn_get_cursor_pos            = isurface:get_function(100, "unsigned int", {"int*", "int*"})
local fn_set_cursor_pos            = isurface:get_function(101, "unsigned int", {"int", "int"})
local fn_draw_outlined_circle      = isurface:get_function(103, "void", {"int", "int", "int", "int"})
local fn_draw_filled_rect_fade     = isurface:get_function(123, "void", {"int", "int", "int", "int", "unsigned int", "unsigned int", "bool"})
function future:draw_set_color(r, g, b, a) 
    self.fn_draw_set_color(r, g, b, a)
end
function future:draw_filled_rect(x0, y0, x1, y1) 
    self.fn_draw_filled_rect(x0, y0, x1, y1)
end
function future:draw_outlined_rect(x0, y0, x1, y1) 
    self.fn_draw_outlined_rect(x0, y0, x1, y1)
end
function future:draw_line(x0, y0, x1, y1) 
    self.fn_draw_line(x0, y0, x1, y1)
end
function future:draw_poly_line(x, y, count) 
    local int_ptr = ffi.typeof("int[1]") 
    local x1 = ffi.new(int_ptr, x)
    local y1 = ffi.new(int_ptr, y)
    self.fn_draw_poly_line(x1, y1, count)
end
function future:draw_outlined_circle(x, y, radius, segments) 
    self.fn_draw_outlined_circle(x, y, radius, segments)
end
function future:draw_filled_rect_fade(x0, y0, x1, y1, alpha0, alpha1, horizontal) 
    self.fn_draw_filled_rect_fade(x0, y0, x1, y1, alpha0, alpha1, horizontal)
end
function future:draw_set_text_font(font) 
    self.fn_draw_set_text_font(font)
end
function future:draw_set_text_color(r, g, b, a) 
    self.fn_draw_set_text_color(r, g, b, a)
end
function future:draw_set_text_pos(x, y) 
    self.fn_draw_set_text_pos(x, y)
end
function future:draw_print_text(text, localized) 
    if localized then 
        local char_buffer = ffi.new('char[1024]')  
        convert_unicode_to_ansi(text, char_buffer, 1024)
        local test = ffi.string(char_buffer)
        self.fn_draw_print_text(text, test:len(), 0)
    else
        local wide_buffer = ffi.new('wchar_t[1024]')    
        convert_ansi_to_unicode(text, wide_buffer, 1024)
        self.fn_draw_print_text(wide_buffer, text:len(), 0)
    end
end
function future:draw_get_texture_id(filename)
    return(self.fn_draw_get_texture_id(filename))
end
function future:draw_get_texture_file(id, filename, maxlen)
    return(self.fn_draw_get_texture_file(id, filename, maxlen))
end
function future:draw_set_texture_file(id, filename, hardwarefilter, forcereload)
    self.fn_draw_set_texture_file(id, filename, hardwarefilter, forcereload)
end
function future:draw_set_texture_rgba(id, rgba, wide, tall)
    self.fn_draw_set_texture_rgba(id, rgba, wide, tall)
end
function future:draw_set_texture(id)
    self.fn_draw_set_texture(id)
end
function future:delete_texture_by_id(id)
    self.fn_delete_texture_by_id(id)
end
function future:draw_get_texture_size(id)
    local int_ptr = ffi.typeof("int[1]") 
    local wide_ptr = int_ptr() local tall_ptr = int_ptr()
    self.fn_draw_get_texture_size(id, wide_ptr, tall_ptr)
    local wide = tonumber(ffi.cast("int", wide_ptr[0]))
    local tall = tonumber(ffi.cast("int", tall_ptr[0]))
    return wide, tall
end
function future:draw_textured_rect(x0, y0, x1, y1)
    self.fn_draw_textured_rect(x0, y0, x1, y1)
end
function future:is_texture_id_valid(id)
    return(self.fn_is_texture_id_valid(id))
end
function future:create_new_texture_id(id)
    return(self.fn_create_new_texture_id(id))
end
function future:create_font() 
    return(self.fn_create_font())
end
function future:set_font_glyph(font, font_name, tall, weight, flags) 
    local x = 0
    if type(flags) == "number" then
        x = flags
    elseif type(flags) == "table" then
        for i=1, #flags do
            x = x + flags[i]
        end
    end
    self.fn_set_font_glyph(font, font_name, tall, weight, 0, 0, bit.bor(x), 0, 0)
end

function future:get_text_size(font, text) 
    local wide_buffer = ffi.new('wchar_t[1024]') 
    local int_ptr = ffi.typeof("int[1]") 
    local wide_ptr = int_ptr() local tall_ptr = int_ptr()

    convert_ansi_to_unicode(text, wide_buffer, 1024)
    self.fn_get_text_size(font, wide_buffer, wide_ptr, tall_ptr)
    local wide = tonumber(ffi.cast("int", wide_ptr[0]))
    local tall = tonumber(ffi.cast("int", tall_ptr[0]))
    return wide, tall
end
function future:get_cursor_pos() 
   local int_ptr = ffi.typeof("int[1]") 
   local x_ptr = int_ptr() local y_ptr = int_ptr()
   self.fn_get_cursor_pos(x_ptr, y_ptr)
   local x = tonumber(ffi.cast("int", x_ptr[0]))
   local y = tonumber(ffi.cast("int", y_ptr[0]))
   return x, y
end
function future:set_cursor_pos(x, y) 
    self.fn_set_cursor_pos(x, y)
end
function future:unlock_cursor() 
    self.fn_unlock_cursor()
end
function future:lock_cursor() 
    self.fn_lock_cursor()
end


function future:register_callback(call, func)
    if not future.callbacks[call] then
        future.callbacks[call] = {}
    end
    table.insert(future.callbacks[call], func)
    client.set_event_callback(future.callbacks[call], function(e)
        for i = 1, #future.callbacks[call] do
            future.callbacks[call][i]()
        end
    end)
end

return future