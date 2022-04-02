--TO DO:
--1)uid SYSTEM -- ill rethink this
--2)legit aa on use -- done
--3)killsay --ez to do/done
--4)watermark+binds(maybe) -- kinda done
--5)rage shit(inair hc and  ns hc) -- no.
--6)keybindos -- DONEEE
--7) custom scoper - dONEEEEEE
local ffi = require("ffi")
-----josn lib
local json = { _version = "0.1.2" }
local function error(shit)
    print(tostring(shit))
end
-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escape_char_map = {
  [ "\\" ] = "\\",
  [ "\"" ] = "\"",
  [ "\b" ] = "b",
  [ "\f" ] = "f",
  [ "\n" ] = "n",
  [ "\r" ] = "r",
  [ "\t" ] = "t",
}

local escape_char_map_inv = { [ "/" ] = "/" }
for k, v in pairs(escape_char_map) do
  escape_char_map_inv[v] = k
end


local function escape_char(c)
  return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end


local function encode_nil(val)
  return "null"
end


local function encode_table(val, stack)
  local res = {}
  stack = stack or {}

  -- Circular reference?
  if stack[val] then error("circular reference") end

  stack[val] = true

  if rawget(val, 1) ~= nil or next(val) == nil then
    -- Treat as array -- check keys are valid and it is not sparse
    local n = 0
    for k in pairs(val) do
      if type(k) ~= "number" then
        error("invalid table: mixed or invalid key types")
      end
      n = n + 1
    end
    if n ~= #val then
      error("invalid table: sparse array")
    end
    -- Encode
    for i, v in ipairs(val) do
      table.insert(res, encode(v, stack))
    end
    stack[val] = nil
    return "[" .. table.concat(res, ",") .. "]"

  else
    -- Treat as an object
    for k, v in pairs(val) do
      if type(k) ~= "string" then
        error("invalid table: mixed or invalid key types")
      end
      table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
    end
    stack[val] = nil
    return "{" .. table.concat(res, ",") .. "}"
  end
end


local function encode_string(val)
  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end


local function encode_number(val)
  -- Check for NaN, -inf and inf
  if val ~= val or val <= -math.huge or val >= math.huge then
    error("unexpected number value '" .. tostring(val) .. "'")
  end
  return string.format("%.14g", val)
end


local type_func_map = {
  [ "nil"     ] = encode_nil,
  [ "table"   ] = encode_table,
  [ "string"  ] = encode_string,
  [ "number"  ] = encode_number,
  [ "boolean" ] = tostring,
}


encode = function(val, stack)
  local t = type(val)
  local f = type_func_map[t]
  if f then
    return f(val, stack)
  end
  error("unexpected type '" .. t .. "'")
end


function json.encode(val)
  return ( encode(val) )
end


-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local function create_set(...)
  local res = {}
  for i = 1, select("#", ...) do
    res[ select(i, ...) ] = true
  end
  return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals      = create_set("true", "false", "null")

local literal_map = {
  [ "true"  ] = true,
  [ "false" ] = false,
  [ "null"  ] = nil,
}


local function next_char(str, idx, set, negate)
  for i = idx, #str do
    if set[str:sub(i, i)] ~= negate then
      return i
    end
  end
  return #str + 1
end


local function decode_error(str, idx, msg)
  local line_count = 1
  local col_count = 1
  for i = 1, idx - 1 do
    col_count = col_count + 1
    if str:sub(i, i) == "\n" then
      line_count = line_count + 1
      col_count = 1
    end
  end
  error( string.format("%s at line %d col %d", msg, line_count, col_count) )
end


local function codepoint_to_utf8(n)
  -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
  local f = math.floor
  if n <= 0x7f then
    return string.char(n)
  elseif n <= 0x7ff then
    return string.char(f(n / 64) + 192, n % 64 + 128)
  elseif n <= 0xffff then
    return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
  elseif n <= 0x10ffff then
    return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                       f(n % 4096 / 64) + 128, n % 64 + 128)
  end
  error( string.format("invalid unicode codepoint '%x'", n) )
end


local function parse_unicode_escape(s)
  local n1 = tonumber( s:sub(1, 4),  16 )
  local n2 = tonumber( s:sub(7, 10), 16 )
   -- Surrogate pair?
  if n2 then
    return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
  else
    return codepoint_to_utf8(n1)
  end
end


local function parse_string(str, i)
  local res = ""
  local j = i + 1
  local k = j

  while j <= #str do
    local x = str:byte(j)

    if x < 32 then
      decode_error(str, j, "control character in string")

    elseif x == 92 then -- `\`: Escape
      res = res .. str:sub(k, j - 1)
      j = j + 1
      local c = str:sub(j, j)
      if c == "u" then
        local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                 or str:match("^%x%x%x%x", j + 1)
                 or decode_error(str, j - 1, "invalid unicode escape in string")
        res = res .. parse_unicode_escape(hex)
        j = j + #hex
      else
        if not escape_chars[c] then
          decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
        end
        res = res .. escape_char_map_inv[c]
      end
      k = j + 1

    elseif x == 34 then -- `"`: End of string
      res = res .. str:sub(k, j - 1)
      return res, j + 1
    end

    j = j + 1
  end

  decode_error(str, i, "expected closing quote for string")
end


local function parse_number(str, i)
  local x = next_char(str, i, delim_chars)
  local s = str:sub(i, x - 1)
  local n = tonumber(s)
  if not n then
    decode_error(str, i, "invalid number '" .. s .. "'")
  end
  return n, x
end


local function parse_literal(str, i)
  local x = next_char(str, i, delim_chars)
  local word = str:sub(i, x - 1)
  if not literals[word] then
    decode_error(str, i, "invalid literal '" .. word .. "'")
  end
  return literal_map[word], x
end


local function parse_array(str, i)
  local res = {}
  local n = 1
  i = i + 1
  while 1 do
    local x
    i = next_char(str, i, space_chars, true)
    -- Empty / end of array?
    if str:sub(i, i) == "]" then
      i = i + 1
      break
    end
    -- Read token
    x, i = parse(str, i)
    res[n] = x
    n = n + 1
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "]" then break end
    if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
  end
  return res, i
end


local function parse_object(str, i)
  local res = {}
  i = i + 1
  while 1 do
    local key, val
    i = next_char(str, i, space_chars, true)
    -- Empty / end of object?
    if str:sub(i, i) == "}" then
      i = i + 1
      break
    end
    -- Read key
    if str:sub(i, i) ~= '"' then
      decode_error(str, i, "expected string for key")
    end
    key, i = parse(str, i)
    -- Read ':' delimiter
    i = next_char(str, i, space_chars, true)
    if str:sub(i, i) ~= ":" then
      decode_error(str, i, "expected ':' after key")
    end
    i = next_char(str, i + 1, space_chars, true)
    -- Read value
    val, i = parse(str, i)
    -- Set
    res[key] = val
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "}" then break end
    if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
  end
  return res, i
end


local char_func_map = {
  [ '"' ] = parse_string,
  [ "0" ] = parse_number,
  [ "1" ] = parse_number,
  [ "2" ] = parse_number,
  [ "3" ] = parse_number,
  [ "4" ] = parse_number,
  [ "5" ] = parse_number,
  [ "6" ] = parse_number,
  [ "7" ] = parse_number,
  [ "8" ] = parse_number,
  [ "9" ] = parse_number,
  [ "-" ] = parse_number,
  [ "t" ] = parse_literal,
  [ "f" ] = parse_literal,
  [ "n" ] = parse_literal,
  [ "[" ] = parse_array,
  [ "{" ] = parse_object,
}


parse = function(str, idx)
  local chr = str:sub(idx, idx)
  local f = char_func_map[chr]
  if f then
    return f(str, idx)
  end
  decode_error(str, idx, "unexpected character '" .. chr .. "'")
end


function json.decode(str)
  if type(str) ~= "string" then
    error("expected argument of type string, got " .. type(str))
  end
  local res, idx = parse(str, next_char(str, 1, space_chars, true))
  idx = next_char(str, idx, space_chars, true)
  if idx <= #str then
    decode_error(str, idx, "trailing garbage")
  end
  return res
end
--end json lib



--kiwi ghetto asf bitiwse cpp func please wworkey
ffi.cdef[[
    void kiwifunc(int cur_buttons)
    {
        int buttons = cur_buttons;
        buttons &= ~(1 << 5)
        cur_buttons = buttons
        return cur_buttons
    }
]]


local load_pres = false
local link_custom = false
local cinq_pres
--lean aa
Menu.Text("Info", "Welcome to LeanYaw! Enjoy your stay! :)")
local main =
{
    aa_sw = Menu.Switch('Lean Anti-Aim', 'Lean Anti-Aim', "Custom Antiaim", false),
    pres_link = Menu.TextBox('Lean Anti-Aim', 'Lean Anti-Aim', 'Preset Link', 9999, "https://github.com/kiwihvh/leanyaw/blob/main/presets.json", "Put the link to your preset here (RAW PASTE DATA ONLY!!!!) for example go to https://raw.githubusercontent.com/kiwihvh/leanyaw/main/presets.json"),
    presets = Menu.Combo('Lean Anti-Aim', 'Lean Anti-Aim', "PRESETS", {"CUSTOM", "KIWI MAIN", "EDGE", "DESYNC ONLY - NO LEAN", "TANK AA"--[[, "FROM WEB LINK"]]}, 0, "Tooltip", function(val)
        if val == 5 then
            if not Http.Get(pres_link:GetString()) then return end
            load_pres = Http.Get(pres_link:GetString())
            cinq_pres = json.decode(load_pres)
            --cinq_pres.condition = cinq_pres.standing
            link_custom = true
            --local ax = true
        end
    end),
    aa_cond = Menu.Combo('Lean Anti-Aim', 'Lean Anti-Aim', "Conditions", {"Standing", "Moving", "Airborne", "Slowwalk"}, 0)
    --presets = nil --= Menu.Combo('Lean Anti-Aim', 'Lean Anti-Aim', "PRESETS", {"CUSTOM", "KIWI MAIN", "EDGE", "DESYNC ONLY - NO LEAN", "TANK AA", "FROM WEB LINK"}, 0)
}






    --[[Menu.Combo("Neverlose", "Combo", {"Element 1", "Element 2", "Element 3"}, 0, "Tooltip", function(val)
        print(val)
    end)]]

--cloud presets
local presets = Http.Get('https://raw.githubusercontent.com/kiwihvh/leanyaw/main/presets.lua')


local standing ={
     random_desync = Menu.Switch('Lean Anti-Aim', 'STANDING', "Random Desync", false),
     fake_l= Menu.SliderInt('Lean Anti-Aim', 'STANDING', "Override Limit Left", 0, 0, 58),
     lby_l = Menu.SliderInt('Lean Anti-Aim', 'STANDING', "Override LBY Left", 0, 0, 58),
     fake_r= Menu.SliderInt('Lean Anti-Aim', 'STANDING', "Override Limit Right", 0, 0, 58),
     lby_r = Menu.SliderInt('Lean Anti-Aim', 'STANDING', "Override LBY Right", 0, 0, 58),
     yaw_opt = Menu.Combo('Lean Anti-Aim', 'STANDING', "Yaw Base", {"Forward", "Backward", "Right", "Left", "At Target", "Freestanding"}, 4),
     yaw_add = Menu.SliderInt('Lean Anti-Aim', 'STANDING', "Yaw Add", 0, -180, 180),
     yaw_mod_opt = Menu.Combo('Lean Anti-Aim', 'STANDING', "Yaw Modifier", {"Disabled", "Center", "Offset", "Random", "Spin"}, 0),
     yaw_mod_add = Menu.SliderInt('Lean Anti-Aim', 'STANDING', "Modifie Degree", 0, -180, 180),
     fake_opt = Menu.MultiCombo('Lean Anti-Aim', 'STANDING', "Fake options", {"Avoit Overlap", "Jitter", "Randomize jitter", "Anti Bruteforce"}, 0),
    --lean
     roll = Menu.Switch('Lean Anti-Aim', 'STANDING', "Lean Enable", false),
     max_velo_int = Menu.SliderInt('Lean Anti-Aim', 'STANDING', 'Max Velocity', 100, 0, 600, "Using high values here will break neverlose's movement fix"),
     random_lean = Menu.Switch('Lean Anti-Aim', 'STANDING', "Random Lean", false),
     rollint_l = Menu.SliderInt('Lean Anti-Aim', 'STANDING', "Lean Amount Left", 0, -180, 180),
     rollint_r = Menu.SliderInt('Lean Anti-Aim', 'STANDING', "Lean Amount Right", 0, -180, 180),
    --fake pip
     fake_flick = Menu.Switch('Lean Anti-Aim',  'STANDING', "Fake Flick", false),
     ticks_to_flick = Menu.SliderInt('Lean Anti-Aim', 'STANDING', "Ticks to Flick on", 0, 0, 64),
     fake_flick_angle = Menu.SliderInt('Lean Anti-Aim', 'STANDING', "Fake Flick Angle", 0, -180, 180)

}



local moving ={
    random_desync = Menu.Switch('Lean Anti-Aim', 'MOVING', "Random Desync ", false),
    fake_l= Menu.SliderInt('Lean Anti-Aim', 'MOVING', "Override Limit Left ", 0, 0, 58),
    lby_l = Menu.SliderInt('Lean Anti-Aim', 'MOVING', "Override LBY Left ", 0, 0, 58),
    fake_r= Menu.SliderInt('Lean Anti-Aim', 'MOVING', "Override Limit Right ", 0, 0, 58),
    lby_r = Menu.SliderInt('Lean Anti-Aim', 'MOVING', "Override LBY Right ", 0, 0, 58),
    yaw_opt = Menu.Combo('Lean Anti-Aim', 'MOVING', "Yaw Base ", {"Forward", "Backward", "Right", "Left", "At Target", "Freestanding"}, 4),
    yaw_add = Menu.SliderInt('Lean Anti-Aim', 'MOVING', "Yaw Add ", 0, -180, 180),
    yaw_mod_opt = Menu.Combo('Lean Anti-Aim', 'MOVING', "Yaw Modifier ", {"Disabled", "Center", "Offset", "Random", "Spin"}, 0),
    yaw_mod_add = Menu.SliderInt('Lean Anti-Aim', 'MOVING', "Modifie Degree ", 0, -180, 180),
    fake_opt = Menu.MultiCombo('Lean Anti-Aim', 'MOVING', "Fake options ", {"Avoit Overlap", "Jitter", "Randomize jitter", "Anti Bruteforce"}, 0),
   --lean
    roll = Menu.Switch('Lean Anti-Aim', 'MOVING', "Lean Enable ", false),
    max_velo_int = Menu.SliderInt('Lean Anti-Aim', 'MOVING', 'Max Velocity ', 100, 0, 600, "Using high values here will break neverlose's movement fix"),
    random_lean = Menu.Switch('Lean Anti-Aim', 'MOVING', "Random Lean ", false),
    rollint_l = Menu.SliderInt('Lean Anti-Aim', 'MOVING', "Lean Amount Left ", 0, -180, 180),
    rollint_r = Menu.SliderInt('Lean Anti-Aim', 'MOVING', "Lean Amount Right ", 0, -180, 180),
   --fake pip
    fake_flick = Menu.Switch('Lean Anti-Aim', 'MOVING', "Fake Flick ", false),
    ticks_to_flick = Menu.SliderInt('Lean Anti-Aim', 'MOVING', "Ticks to Flick on ", 0, 0, 64),
    fake_flick_angle = Menu.SliderInt('Lean Anti-Aim', 'MOVING', "Fake Flick Angle ", 0, -180, 180)

}


local air ={
    random_desync = Menu.Switch('Lean Anti-Aim', 'AIRBORNE', "Random Desync  ", false),
    fake_l= Menu.SliderInt('Lean Anti-Aim', 'AIRBORNE', "Override Limit Left  ", 0, 0, 58),
    lby_l = Menu.SliderInt('Lean Anti-Aim', 'AIRBORNE', "Override LBY Left  ", 0, 0, 58),
    fake_r= Menu.SliderInt('Lean Anti-Aim', 'AIRBORNE', "Override Limit Right  ", 0, 0, 58),
    lby_r = Menu.SliderInt('Lean Anti-Aim', 'AIRBORNE', "Override LBY Right  ", 0, 0, 58),
    yaw_opt = Menu.Combo('Lean Anti-Aim', 'AIRBORNE', "Yaw Base  ", {"Forward", "Backward", "Right", "Left", "At Target", "Freestanding"}, 4),
    yaw_add = Menu.SliderInt('Lean Anti-Aim', 'AIRBORNE', "Yaw Add  ", 0, -180, 180),
    yaw_mod_opt = Menu.Combo('Lean Anti-Aim', 'AIRBORNE', "Yaw Modifier  ", {"Disabled", "Center", "Offset", "Random", "Spin"}, 0),
    yaw_mod_add = Menu.SliderInt('Lean Anti-Aim', 'AIRBORNE', "Modifie Degree  ", 0, -180, 180),
    fake_opt = Menu.MultiCombo('Lean Anti-Aim', 'AIRBORNE', "Fake options  ", {"Avoit Overlap", "Jitter", "Randomize jitter", "Anti Bruteforce"}, 0),
   --lean
    roll = Menu.Switch('Lean Anti-Aim', 'AIRBORNE', "Lean Enable  ", false),
    max_velo_int = Menu.SliderInt('Lean Anti-Aim', 'AIRBORNE', 'Max Velocity  ', 100, 0, 600, "Using high values here will break neverlose's movement fix"),
    random_lean = Menu.Switch('Lean Anti-Aim', 'AIRBORNE', "Random Lean  ", false),
    rollint_l = Menu.SliderInt('Lean Anti-Aim', 'AIRBORNE', "Lean Amount Left  ", 0, -180, 180),
    rollint_r = Menu.SliderInt('Lean Anti-Aim', 'AIRBORNE', "Lean Amount Right  ", 0, -180, 180),
   --fake pip
    fake_flick = Menu.Switch('Lean Anti-Aim', 'AIRBORNE', "Fake Flick  ", false),
    ticks_to_flick = Menu.SliderInt('Lean Anti-Aim', 'AIRBORNE', "Ticks to Flick on  ", 0, 0, 64),
    fake_flick_angle = Menu.SliderInt('Lean Anti-Aim', 'AIRBORNE', "Fake Flick Angle  ", 0, -180, 180)

}



local slowwalk ={
    random_desync = Menu.Switch('Lean Anti-Aim', 'SLOWWALK', "Random Desync   ", false),
    fake_l= Menu.SliderInt('Lean Anti-Aim', 'SLOWWALK', "Override Limit Left   ", 0, 0, 58),
    lby_l = Menu.SliderInt('Lean Anti-Aim', 'SLOWWALK', "Override LBY Left   ", 0, 0, 58),
    fake_r= Menu.SliderInt('Lean Anti-Aim', 'SLOWWALK', "Override Limit Right   ", 0, 0, 58),
    lby_r = Menu.SliderInt('Lean Anti-Aim', 'SLOWWALK', "Override LBY Right   ", 0, 0, 58),
    yaw_opt = Menu.Combo('Lean Anti-Aim', 'SLOWWALK', "Yaw Base   ", {"Forward", "Backward", "Right", "Left", "At Target", "Freestanding"}, 4),
    yaw_add = Menu.SliderInt('Lean Anti-Aim', 'SLOWWALK', "Yaw Add   ", 0, -180, 180),
    yaw_mod_opt = Menu.Combo('Lean Anti-Aim', 'SLOWWALK', "Yaw Modifier   ", {"Disabled", "Center", "Offset", "Random", "Spin"}, 0),
    yaw_mod_add = Menu.SliderInt('Lean Anti-Aim', 'SLOWWALK', "Modifie Degree   ", 0, -180, 180),
    fake_opt = Menu.MultiCombo('Lean Anti-Aim', 'SLOWWALK', "Fake options   ", {"Avoit Overlap", "Jitter", "Randomize jitter", "Anti Bruteforce"}, 0),
   --lean
    roll = Menu.Switch('Lean Anti-Aim', 'SLOWWALK', "Lean Enable   ", false),
    max_velo_int = Menu.SliderInt('Lean Anti-Aim', 'SLOWWALK', 'Max Velocity   ', 100, 0, 600, "Using high values here will break neverlose's movement fix"),
    random_lean = Menu.Switch('Lean Anti-Aim', 'SLOWWALK', "Random Lean   ", false),
    rollint_l = Menu.SliderInt('Lean Anti-Aim', 'SLOWWALK', "Lean Amount Left   ", 0, -180, 180),
    rollint_r = Menu.SliderInt('Lean Anti-Aim', 'SLOWWALK', "Lean Amount Right   ", 0, -180, 180),
   --fake pip
    fake_flick = Menu.Switch('Lean Anti-Aim', 'SLOWWALK', "Fake Flick   ", false),
    ticks_to_flick = Menu.SliderInt('Lean Anti-Aim', 'SLOWWALK', "Ticks to Flick on   ", 0, 0, 64),
    fake_flick_angle = Menu.SliderInt('Lean Anti-Aim', 'SLOWWALK', "Fake Flick Angle   ", 0, -180, 180)

}
local legit_aa ={
    key = 69,
    enable = Menu.Switch("Lean Anti-Aim", "Lean Anti-Aim", "Legit AA on use key", false, "Legit AA")--,
    --hotkey = Menu.Hotkey("Lean Anti-Aim", "Lean Anti-Aim", "Legit AA Bind", 0x45, "LegitAA key(can be e)", function(val) key = val end),
    --should = false
}
local rage={

}
--misc
local legmovement = Menu.FindVar("Aimbot", "Anti Aim", "Misc", "Leg Movement")
local switch_lb = Menu.Switch("Misc", "Misc", "Static legs", false, "Make your legs always backward.")
--dt speed
local dt_enable = Menu.Switch("Misc", "Misc", "Custom DT", false, "Change your DT speed")
local dt_cor = Menu.Switch("Misc", "Misc", "Disable DT correction", false, "Disable the dt corection (shoot dt faster but less accurate)")
local dt_speed = Menu.SliderInt("Misc", "Misc", "DT Shift", 13, 0, 62, "Higher shift = faster DT(anything over 20 only works on special servers)")
local pred_sw = Menu.Switch("Misc", "Misc", "Fix prediction", false, "FIX THE PREDICITON")
--clantag
local clantag_sw = Menu.Switch("Misc", "Misc", "Clantag", false)
local ctg_speed = Menu.SliderInt("Misc", "Misc", "Clantag Speed", 48, 0, 64)
--fakelag
local fl_sw = Menu.Switch("Misc", "Misc", "Better Fake Lag", false)
--local aquire = Render.InitFont("Aquire Bold", 10)
local pixel = Render.InitFont("Smallest Pixel-7", 10)
local indicator_wm = Menu.Switch("Lean Visuals", "Lean Visuals", "Main Indicators", false)
local colorz1 = Menu.ColorEdit("Lean Visuals", "Lean Visuals", "Primary color", Color.new(1.0, 1.0, 1.0, 1.0))
local colorz2 = Menu.ColorEdit("Lean Visuals", "Lean Visuals", "Secondary color", Color.new(1.0, 1.0, 1.0, 1.0))
--pasted $$$

--not pasted$$
local custom_hits = Menu.Switch("Lean Visuals", "Lean Visuals", "Custom Hitsound", false)
local InputText = Menu.TextBox("Lean Visuals", "Lean Visuals", "Hitsound Path", 200, "buttons\\arena_switch_press_02", "Plays hitsound from the csgo\\sound folder")
local lean_scope = {}

lean_scope.var = Menu.FindVar("Visuals", "View", "Camera", "Remove Scope")
lean_scope.screen = EngineClient:GetScreenSize()
lean_scope.ref = lean_scope.var:GetInt()

lean_scope.menu = {}
lean_scope.menu.switch = Menu.Switch("Lean Visuals", "Lean Scope", "Enable Custom Scope", false)
lean_scope.menu.offset = Menu.SliderInt("Lean Visuals", "Lean Scope", "Offset", 10, 0, 500)
lean_scope.menu.length = Menu.SliderInt("Lean Visuals", "Lean Scope", "Length", 60, 0, 1000)
lean_scope.menu.anim_speed = Menu.SliderInt("Lean Visuals", "Lean Scope", "Anim Speed", 15, 1, 30)
lean_scope.menu.col_1 = Menu.ColorEdit("Lean Visuals", "Lean Scope", "Primary Color", Color.RGBA(255, 255, 255))
lean_scope.menu.col_2 = Menu.ColorEdit("Lean Visuals", "Lean Scope", "Secondary Color", Color.RGBA(255, 255, 255, 0))

lean_scope.anim_num = 0

lean_scope.lerp = function(a, b, t)
    return a + (b - a) * t
end






--slowwalk(from my other script=))
local slowwalk_norm = Menu.Switch("Misc", "Misc", "Custom slowwalk", false, "Customizable speed slowwalk")
local break_slowwalk = Menu.Switch("Misc", "Misc", "Break Prediction slowwalk", false, "Break the cheats prediction with this slowwalk")
local slowwalk_speed = Menu.SliderInt("Misc", "Misc", "Slowwalk speed", 50, 0, 250, "Speed for normal and break pred slowwalk")
local sw_time = Menu.SliderInt("Misc", "Misc", "Switch Time", 14, 0, 64, "Time before breaking prediction")
local thirdperson = Menu.Switch("Misc", "Misc", 'Disable thirdperson anim', false, 'Disable the animation when enabling thirdperson')

local condition = standing

local image_size2 = Vector2.new(746 / 5, 1070 / 5)
local url2 = 'https://cdn.discordapp.com/attachments/932309424540893265/932326186762268762/lean_is_kinda_sus_doe.png'
local bytes2 = Http.Get(url2)
local fortnite2 = Render.LoadImage(bytes2, image_size2)


local function disable_tp()
    if (thirdperson:GetBool()) then
        Cheat.SetThirdPersonAnim(false)
    else
        Cheat.SetThirdPersonAnim(true)
    end
end





--clantag
local can_cmd = 0
-- @region: engine stuff
local _set_clantag = ffi.cast('int(__fastcall*)(const char*, const char*)', Utils.PatternScan('engine.dll', '53 56 57 8B DA 8B F9 FF 15'))
local _last_clantag = nil
local set_clantag = function(v)
  if v == _last_clantag then return end
  _set_clantag(v, '\nl\ne\na\nn\n.\ny\na\nw\n')
  _last_clantag = v
end


local build_tag = function(tag)
  local ret = { ' ' }
  for i = 1, #tag do
    table.insert(ret, tag:sub(1, i))
  end
  for i = #ret - 1, 1, -1 do
    table.insert(ret, ret[i]..' \n')
  end
  return ret
end

local tag = build_tag('lean.yaw $')
local desync3
lean_scope.on_draw = function()
    if lean_scope.menu.switch:GetBool() then
        lean_scope.var:SetInt(2)

        local_player = EntityList.GetLocalPlayer()
        lean_scope.anim_speed = lean_scope.menu.anim_speed:Get()

        if not local_player or not local_player:IsAlive() or not local_player:GetProp("m_bIsScoped") then 
            lean_scope.anim_num = lean_scope.lerp(lean_scope.anim_num, 0, lean_scope.anim_speed * GlobalVars.frametime)
        else
            lean_scope.anim_num = lean_scope.lerp(lean_scope.anim_num, 1, lean_scope.anim_speed * GlobalVars.frametime)
        end

        lean_scope.offset = lean_scope.menu.offset:Get() * lean_scope.anim_num
        lean_scope.length = lean_scope.menu.length:Get() * lean_scope.anim_num
        lean_scope.col_1 = lean_scope.menu.col_1:Get()
        lean_scope.col_2 = lean_scope.menu.col_2:Get()
        lean_scope.width = 1

        lean_scope.col_1.a = lean_scope.col_1.a * lean_scope.anim_num
        lean_scope.col_2.a = lean_scope.col_2.a * lean_scope.anim_num
        
        lean_scope.start_x = lean_scope.screen.x / 2
        lean_scope.start_y = lean_scope.screen.y / 2

        --Left
        Render.GradientBoxFilled(Vector2.new(lean_scope.start_x - lean_scope.offset, lean_scope.start_y), Vector2.new(lean_scope.start_x - lean_scope.offset - lean_scope.length, lean_scope.start_y + lean_scope.width), lean_scope.col_1, lean_scope.col_2, lean_scope.col_1, lean_scope.col_2)

        --Right
        Render.GradientBoxFilled(Vector2.new(lean_scope.start_x + lean_scope.offset, lean_scope.start_y), Vector2.new(lean_scope.start_x + lean_scope.offset + lean_scope.length, lean_scope.start_y + lean_scope.width), lean_scope.col_1, lean_scope.col_2, lean_scope.col_1, lean_scope.col_2)

        --Up
        Render.GradientBoxFilled(Vector2.new(lean_scope.start_x, lean_scope.start_y + lean_scope.offset), Vector2.new(lean_scope.start_x + lean_scope.width, lean_scope.start_y + lean_scope.offset + lean_scope.length), lean_scope.col_1, lean_scope.col_1, lean_scope.col_2, lean_scope.col_2)

        --Down
        Render.GradientBoxFilled(Vector2.new(lean_scope.start_x, lean_scope.start_y - lean_scope.offset), Vector2.new(lean_scope.start_x + lean_scope.width, lean_scope.start_y - lean_scope.offset - lean_scope.length), lean_scope.col_1, lean_scope.col_1, lean_scope.col_2, lean_scope.col_2)
    end
end
lean_scope.on_destroy = function()
    lean_scope.var:SetInt(lean_scope.ref)
end
function switcher(i)
    return setmetatable({ i }, {
      __call = function (cE, cEE)
        local nomorenaming = #cE == 0 and nulmen or cE[1]
        return (cEE[nomorenaming] or cEE[wutman] or nulmen)(nomorenaming)
      end
    })
end
local bit = require "bit"

local function desync(cmd) 
    
    local gaming
    if bit.band(cmd.buttons, bit.lshift(1, 5)) == 32 then
        --print("false")
        --print(bit.band(cmd.buttons, bit.lshift(1, 5)))
        gaming = true
    else
        --print("true")
        gaming = false
    end
    local flfl = Menu.FindVar("Aimbot", "Anti Aim", "Fake Lag", "Enable Fake Lag")
    local view_angles = cmd.viewangles
    if gaming then
        flfl:SetBool(false)
    else
        flfl:SetBool(true)
    end
    if cmd.tick_count % 3 == 0 then 
        if gaming then
            cmd.viewangles.pitch = cmd.viewangles.pitch--+89
            cmd.viewangles.yaw = cmd.viewangles.yaw
            --FakeLag.SetState(false)
        end
        --UserCMD.SetViewAngles([view_angles[0] + 89, view_angles[1] + 180, 0]
    end
    if cmd.tick_count % 3 == 1 then
        if gaming then 
            cmd.viewangles.pitch = cmd.viewangles.pitch--+89
            cmd.viewangles.yaw = cmd.viewangles.yaw+75
            FakeLag.SetState(false)
        end 
        --UserCMD.SetViewAngles([view_angles[0] + 89, view_angles[1] - 75, 0]
    end
    if cmd.tick_count % 3 == 2 then 
        if gaming then
            cmd.viewangles.pitch = cmd.viewangles.pitch--+89
            cmd.viewangles.yaw = cmd.viewangles.yaw-60
            FakeLag.ForceSend()--SetState(false)
        end
        --UserCMD.SetViewAngles([view_angles[0] + 89, view_angles[1] + 60, 0]
    end
end
local function legitaa(cmd)
    if legit_aa.enable:GetBool() then
        --if Cheat.IsKeyDown(legit_aa.key) then
            --if gaming then
                desync(cmd)
            --end
            --cmd.buttons = bit.band(cmd.buttons, 3)
            --cmd.buttons = ffi.C.kiwifunc(cmd)
        --end
    end
end

-- Typical call:  if hasbit(x, bit(3)) then ...
local function hasbit(x, p)
    return x % (p + p) >= p       
end

local function setbit(x, p)
    return hasbit(x, p) and x or x + p
end

local function clearbit(x, p)
    return hasbit(x, p) and x - p or x
end

local normalize_yaw = function(yaw)
    while yaw > 180 do yaw = yaw - 360 end
    while yaw < -180 do yaw = yaw + 360 end
    return yaw
end


    --local delta = math.abs(normalize_yaw(AntiAim.GetCurrentRealRotation() % 360 - AntiAim.GetFakeRotation() % 360)) / 2

Cheat.RegisterCallback("destroy", lean_scope.on_destroy)
Cheat.RegisterCallback('draw', function()
    lean_scope.on_draw()

    --my watermarker(lean cool shoit)
    local localplayer = EntityList.GetClientEntity(EngineClient.GetLocalPlayer()) 
    if localplayer then 
        local wm_enable = indicator_wm:GetBool()
        local color1 = colorz1:GetColor()
        local color2 = colorz2:GetColor()
        if localplayer:GetProp("DT_BasePlayer", "m_iHealth") > 0 and wm_enable then
            --img

            local screen_size = EngineClient.GetScreenSize()    
            local size, cn, modifier = 10, 20, 9
        
            local alpha = math.min(math.floor(math.sin((GlobalVars.realtime % 3) * 4) * 125 + 200), 255)
            local real_rotation = AntiAim.GetCurrentRealRotation()
            local desync_rotation = AntiAim.GetFakeRotation()
            local max_desync_delta = AntiAim.GetMaxDesyncDelta()
            local min_desync_delta = AntiAim.GetMinDesyncDelta()
            local delta3 = math.abs(normalize_yaw(AntiAim.GetCurrentRealRotation() % 360 - AntiAim.GetFakeRotation() % 360)) / 2
            local desync = math.min(math.abs(AntiAim.GetCurrentRealRotation() - AntiAim.GetFakeRotation()), AntiAim.GetMaxDesyncDelta())
            --[[local desync2 = math.min(AntiAim.GetCurrentRealRotation() - AntiAim.GetFakeRotation(), AntiAim.GetMaxDesyncDelta())
            local des1 = math.max(AntiAim.GetCurrentRealRotation() - AntiAim.GetFakeRotation(), -AntiAim.GetMaxDesyncDelta())
            if desync2>0 and des1<0 then
                desync3 = math.max(AntiAim.GetCurrentRealRotation() - AntiAim.GetFakeRotation(), -AntiAim.GetMaxDesyncDelta())
            else
                desync3 = math.min(AntiAim.GetCurrentRealRotation() - AntiAim.GetFakeRotation(), AntiAim.GetMaxDesyncDelta())
            end]]
            local desync2 = normalize_yaw( AntiAim.GetFakeRotation( ) - AntiAim.GetCurrentRealRotation( ) )
            local desync3 = normalize_yaw(AntiAim.GetCurrentRealRotation() % 360 - AntiAim.GetFakeRotation() % 360) / 2
            local desync4 = math.abs(0.5*AntiAim.GetCurrentRealRotation() - 0.5*AntiAim.GetFakeRotation())
            local delta, indic_txt = string.format("%.1f", desync2), "lean.yaw"

            local delta_length, indic_txt_length = Render.CalcTextSize(delta, size, pixel), Render.CalcTextSize(indic_txt, size, pixel)

            -- delta calculationes
            Render.Text(delta, Vector2.new(screen_size.x / 2 - delta_length.x / 2 + 1, screen_size.y / 2 + cn), Color.new(255 / 255, 255 / 255, 255 / 255, 255 / 255), size, pixel, true); cn = cn + modifier

            
            Render.GradientBoxFilled(Vector2.new(screen_size.x / 2 + 1, screen_size.y / 2 + cn + modifier - 1), Vector2.new(screen_size.x / 2 + 5 - desync3, screen_size.y / 2 + cn + modifier / 2 + 1), color1, color2, color1, color2)
            Render.GradientBoxFilled(Vector2.new(screen_size.x / 2 + 1, screen_size.y / 2 + cn + modifier - 1), Vector2.new(screen_size.x / 2 + 5 - desync3, screen_size.y / 2 + cn + modifier / 2 + 1), color1, color2, color1, color2); cn = cn + modifier

            -- indic_txt
            Render.Text(indic_txt, Vector2.new(screen_size.x / 2 - indic_txt_length.x / 2 + 1, screen_size.y / 2 + cn), Color.new(color1.r , color1.g, color1.b, alpha / 255), size, pixel, true); cn = cn + modifier
        end
    end
    --lean cup wattermark

    size2 = Vector2.new(100, 100)
    sc2 = EngineClient.GetScreenSize()
    pos22 = Vector2.new(sc2.x / 2 +885, sc2.y/2 -555)
    if bytes2 then
        Render.Image(fortnite2, pos22, size2)
    end
    

    --my watermarker cool lean end
    --menu stuff(setvisible)
    --aa stuffff

    main.aa_sw:SetVisible(true)
    if main.presets:GetInt() == 5 then
        main.pres_link:SetVisible(main.aa_sw:GetBool())
    else
        main.pres_link:SetVisible(false)
    end

    main.presets:SetVisible(main.aa_sw:GetBool())
    local standing_en = ((main.aa_sw:GetBool() and main.aa_cond:GetInt() == 0 and main.presets:GetInt() == 0) and true or false)
    local moving_en = ((main.aa_sw:GetBool() and main.aa_cond:GetInt() == 1 and main.presets:GetInt() == 0) and true or false)
    local air_en = ((main.aa_sw:GetBool() and main.aa_cond:GetInt() == 2 and main.presets:GetInt() == 0) and true or false)
    local slowwalk_en = ((main.aa_sw:GetBool() and main.aa_cond:GetInt() == 3 and main.presets:GetInt() == 0) and true or false)
    --subtabs
        main.aa_cond:SetVisible((main.aa_sw:GetBool() and main.presets:GetInt() == 0) and true or false)
        --standing
            standing.roll:SetVisible(standing_en)
            standing.max_velo_int:SetVisible(standing.roll:GetBool() and standing_en)
            standing.random_lean:SetVisible(standing.roll:GetBool() and standing_en)
            standing.rollint_l:SetVisible(standing.roll:GetBool() and standing_en)
            standing.rollint_r:SetVisible(standing.roll:GetBool() and standing_en)
            standing.random_desync:SetVisible(standing_en)
            standing.fake_l:SetVisible(standing_en)
            standing.lby_l:SetVisible(standing_en)
            standing.fake_r:SetVisible(standing_en)
            standing.lby_r:SetVisible(standing_en)
            standing.yaw_opt:SetVisible(standing_en)
            standing.yaw_add:SetVisible(standing_en)
            standing.yaw_mod_opt:SetVisible(standing_en)
            standing.yaw_mod_add:SetVisible((standing_en and standing.yaw_mod_opt:GetInt() > 0) and true or false)
            standing.fake_opt:SetVisible(standing_en)
            standing.fake_flick:SetVisible(standing_en)
            standing.ticks_to_flick:SetVisible(standing.fake_flick:GetBool() and standing_en)
            standing.fake_flick_angle:SetVisible(standing.fake_flick:GetBool() and standing_en)
        --moving
            moving.roll:SetVisible(moving_en)
            moving.max_velo_int:SetVisible(moving.roll:GetBool() and moving_en)
            moving.random_lean:SetVisible(moving.roll:GetBool() and moving_en)
            moving.rollint_l:SetVisible(moving.roll:GetBool() and moving_en)
            moving.rollint_r:SetVisible(moving.roll:GetBool() and moving_en)
            moving.random_desync:SetVisible(moving_en)
            moving.fake_l:SetVisible(moving_en)
            moving.lby_l:SetVisible(moving_en)
            moving.fake_r:SetVisible(moving_en)
            moving.lby_r:SetVisible(moving_en)
            moving.yaw_opt:SetVisible(moving_en)
            moving.yaw_add:SetVisible(moving_en)
            moving.yaw_mod_opt:SetVisible(moving_en)
            moving.yaw_mod_add:SetVisible((moving_en and moving.yaw_mod_opt:GetInt() > 0) and true or false)
            moving.fake_opt:SetVisible(moving_en)
            moving.fake_flick:SetVisible(moving_en)
            moving.ticks_to_flick:SetVisible(moving.fake_flick:GetBool() and moving_en)
            moving.fake_flick_angle:SetVisible(moving.fake_flick:GetBool() and moving_en)
        --air
            air.roll:SetVisible(air_en)
            air.max_velo_int:SetVisible(air.roll:GetBool() and air_en)
            air.random_lean:SetVisible(air.roll:GetBool() and air_en)
            air.rollint_l:SetVisible(air.roll:GetBool() and air_en)
            air.rollint_r:SetVisible(air.roll:GetBool() and air_en)
            air.random_desync:SetVisible(air_en)
            air.fake_l:SetVisible(air_en)
            air.lby_l:SetVisible(air_en)
            air.fake_r:SetVisible(air_en)
            air.lby_r:SetVisible(air_en)
            air.yaw_opt:SetVisible(air_en)
            air.yaw_add:SetVisible(air_en)
            air.yaw_mod_opt:SetVisible(air_en)
            air.yaw_mod_add:SetVisible((air_en and air.yaw_mod_opt:GetInt() > 0) and true or false)
            air.fake_opt:SetVisible(air_en)
            air.fake_flick:SetVisible(air_en)
            air.ticks_to_flick:SetVisible(air.fake_flick:GetBool() and air_en)
            air.fake_flick_angle:SetVisible(air.fake_flick:GetBool() and air_en)
        --slowwalk
            slowwalk.roll:SetVisible(slowwalk_en)
            slowwalk.max_velo_int:SetVisible(slowwalk.roll:GetBool() and slowwalk_en)
            slowwalk.random_lean:SetVisible(slowwalk.roll:GetBool() and slowwalk_en)
            slowwalk.rollint_l:SetVisible(slowwalk.roll:GetBool() and slowwalk_en)
            slowwalk.rollint_r:SetVisible(slowwalk.roll:GetBool() and slowwalk_en)
            slowwalk.random_desync:SetVisible(slowwalk_en)
            slowwalk.fake_l:SetVisible(slowwalk_en)
            slowwalk.lby_l:SetVisible(slowwalk_en)
            slowwalk.fake_r:SetVisible(slowwalk_en)
            slowwalk.lby_r:SetVisible(slowwalk_en)
            slowwalk.yaw_opt:SetVisible(slowwalk_en)
            slowwalk.yaw_add:SetVisible(slowwalk_en)
            slowwalk.yaw_mod_opt:SetVisible(slowwalk_en)
            slowwalk.yaw_mod_add:SetVisible((slowwalk_en and slowwalk.yaw_mod_opt:GetInt() > 0) and true or false)
            slowwalk.fake_opt:SetVisible(slowwalk_en)
            slowwalk.fake_flick:SetVisible(slowwalk_en)
            slowwalk.ticks_to_flick:SetVisible(slowwalk.fake_flick:GetBool() and slowwalk_en)
            slowwalk.fake_flick_angle:SetVisible(slowwalk.fake_flick:GetBool() and slowwalk_en)
        --legit aa gmaing
            legit_aa.enable:SetVisible(true)
            --legit_aa.hotkey:SetVisible(legit_aa.enable:GetBool())
        --misc
            dt_enable:SetVisible(true)
            dt_cor:SetVisible(dt_enable:GetBool())
            dt_speed:SetVisible(dt_enable:GetBool())
            clantag_sw:SetVisible(true)
            ctg_speed:SetVisible(clantag_sw:GetBool())
            fl_sw:SetVisible(true)
            slowwalk_norm:SetVisible(true)
            break_slowwalk:SetVisible(true)
            slowwalk_speed:SetVisible((slowwalk_norm:GetBool() or break_slowwalk:GetBool())and true or false)
            sw_time:SetVisible(break_slowwalk:GetBool())
        --visuales
            indicator_wm:SetVisible(true)
            colorz1:SetVisible(indicator_wm:GetBool())  
            colorz2:SetVisible(indicator_wm:GetBool())
            custom_hits:SetVisible(true)
            InputText:SetVisible(custom_hits:GetBool())
        --custom scopere
        lean_scope.menu.switch:SetVisible(true)
        lean_scope.menu.offset:SetVisible(lean_scope.menu.switch:GetBool())
        lean_scope.menu.length:SetVisible(lean_scope.menu.switch:GetBool())
        lean_scope.menu.anim_speed:SetVisible(lean_scope.menu.switch:GetBool())
        lean_scope.menu.col_1:SetVisible(lean_scope.menu.switch:GetBool())
        lean_scope.menu.col_2:SetVisible(lean_scope.menu.switch:GetBool())
    --clantag

    if clantag_sw:GetBool() then
        if not EngineClient.IsConnected() then return end

        local netchann_info = EngineClient.GetNetChannelInfo()
        if netchann_info == nil then return end

        local latency = netchann_info:GetLatency(0) / GlobalVars.interval_per_tick
        local tickcount_pred = GlobalVars.tickcount + latency
        local iter = math.floor(math.fmod(tickcount_pred / (64-ctg_speed:GetInt()), #tag + 1) + 1)

        set_clantag(tag[iter])
    else
        set_clantag("\n")
    end

end)
local test_now = '{"moving":{"yaw_mod_opt":1,"fake_flick":false,"yaw_opt":4,"roll":false,"rollint_r":0,"fake_l":58,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":35,"max_velo_int":100,"rollint_l":0,"random_desync":false,"yaw_add":0,"lby_r":58,"fake_opt":8},"slowwalk":{"yaw_mod_opt":0,"fake_flick":false,"yaw_opt":4,"roll":true,"rollint_r":90,"fake_l":56,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":0,"max_velo_int":101,"rollint_l":90,"random_desync":false,"yaw_add":44,"lby_r":58,"fake_opt":0},"air":{"yaw_mod_opt":1,"fake_flick":false,"yaw_opt":4,"roll":false,"rollint_r":0,"fake_l":58,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":64,"max_velo_int":100,"rollint_l":0,"random_desync":false,"yaw_add":0,"lby_r":58,"fake_opt":2},"standing":{"yaw_mod_opt":0,"fake_flick":false,"yaw_opt":4,"roll":true,"rollint_r":90,"fake_l":58,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":0,"max_velo_int":100,"rollint_l":90,"random_desync":false,"yaw_add":23,"lby_r":58,"fake_opt":0}}'
local un_pres = json.decode(test_now)
local dos_pres = json.decode(test_now)
local tres_pres = json.decode(test_now)
local quat_pres = json.decode(test_now)
local inair
local load_pres1 = Http.Get('https://raw.githubusercontent.com/kiwihvh/leanyaw/main/presets1.json')
--local un_pres = json.decode(load_pres1)
un_pres.condition = un_pres.standing
local load_pres2 = Http.Get('https://raw.githubusercontent.com/kiwihvh/leanyaw/main/presets2.json')
--local dos_pres = json.decode(load_pres2)
dos_pres.condition = dos_pres.standing
local load_pres3 = Http.Get('https://raw.githubusercontent.com/kiwihvh/leanyaw/main/presets3.json')
--local tres_pres = json.decode(load_pres3)
tres_pres.condition = tres_pres.standing
local load_pres4 = Http.Get('https://raw.githubusercontent.com/kiwihvh/leanyaw/main/presets4.json')
--local quat_pres = json.decode(load_pres4)
quat_pres.condition = quat_pres.standing
local loaded_pres1 = 0
local loaded_pres2 = 0
local loaded_pres3 = 0
local loaded_pres4 = 0
local function custom_slowwalk(cmd)

    --if wifi no wworkey we get local presets(ppl shit wifi icry)
    --aka wifi fixi plis

    if not load_pres1 then
        if not loaded_pres1 then
            load_pres1 = '{"moving":{"yaw_mod_opt":1,"fake_flick":false,"yaw_opt":4,"roll":false,"rollint_r":0,"fake_l":58,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":35,"max_velo_int":100,"rollint_l":0,"random_desync":false,"yaw_add":0,"lby_r":58,"fake_opt":8},"slowwalk":{"yaw_mod_opt":0,"fake_flick":false,"yaw_opt":4,"roll":true,"rollint_r":90,"fake_l":56,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":0,"max_velo_int":101,"rollint_l":90,"random_desync":false,"yaw_add":44,"lby_r":58,"fake_opt":0},"air":{"yaw_mod_opt":1,"fake_flick":false,"yaw_opt":4,"roll":false,"rollint_r":0,"fake_l":58,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":64,"max_velo_int":100,"rollint_l":0,"random_desync":false,"yaw_add":0,"lby_r":58,"fake_opt":2},"standing":{"yaw_mod_opt":0,"fake_flick":false,"yaw_opt":4,"roll":true,"rollint_r":90,"fake_l":58,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":0,"max_velo_int":100,"rollint_l":90,"random_desync":false,"yaw_add":23,"lby_r":58,"fake_opt":0}}'
            un_pres = json.decode(load_pres1)
            loaded_pres1 = 1
        end
    else
        if not loaded_pres1 then
            un_pres = json.decode(load_pres1)
            loaded_pres1 = 1
        end
    end

    if not load_pres2 then
        if not loaded_pres2 then
            load_pres2 = '{"moving":{"yaw_mod_opt":1,"fake_flick":false,"yaw_opt":4,"roll":false,"rollint_r":0,"fake_l":58,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":35,"max_velo_int":100,"rollint_l":0,"random_desync":false,"yaw_add":0,"lby_r":58,"fake_opt":8},"slowwalk":{"yaw_mod_opt":0,"fake_flick":false,"yaw_opt":4,"roll":true,"rollint_r":90,"fake_l":56,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":0,"max_velo_int":101,"rollint_l":90,"random_desync":false,"yaw_add":44,"lby_r":58,"fake_opt":0},"air":{"yaw_mod_opt":1,"fake_flick":false,"yaw_opt":4,"roll":false,"rollint_r":0,"fake_l":58,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":64,"max_velo_int":100,"rollint_l":0,"random_desync":false,"yaw_add":0,"lby_r":58,"fake_opt":2},"standing":{"yaw_mod_opt":0,"fake_flick":false,"yaw_opt":4,"roll":true,"rollint_r":90,"fake_l":58,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":0,"max_velo_int":100,"rollint_l":90,"random_desync":false,"yaw_add":23,"lby_r":58,"fake_opt":0}}'
            dos_pres = json.decode(load_pres2)
            loaded_pres2 = 1
        end
    else
        if not loaded_pres2 then
            dos_pres = json.decode(load_pres2)
            loaded_pres2 = 1
        end
    end

    if not load_pres3 then
        if not loaded_pres3 then
            load_pres3 = '{"moving":{"yaw_mod_opt":1,"fake_flick":false,"yaw_opt":4,"roll":false,"rollint_r":0,"fake_l":58,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":35,"max_velo_int":100,"rollint_l":0,"random_desync":false,"yaw_add":0,"lby_r":58,"fake_opt":8},"slowwalk":{"yaw_mod_opt":0,"fake_flick":false,"yaw_opt":4,"roll":true,"rollint_r":90,"fake_l":56,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":0,"max_velo_int":101,"rollint_l":90,"random_desync":false,"yaw_add":44,"lby_r":58,"fake_opt":0},"air":{"yaw_mod_opt":1,"fake_flick":false,"yaw_opt":4,"roll":false,"rollint_r":0,"fake_l":58,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":64,"max_velo_int":100,"rollint_l":0,"random_desync":false,"yaw_add":0,"lby_r":58,"fake_opt":2},"standing":{"yaw_mod_opt":0,"fake_flick":false,"yaw_opt":4,"roll":true,"rollint_r":90,"fake_l":58,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":0,"max_velo_int":100,"rollint_l":90,"random_desync":false,"yaw_add":23,"lby_r":58,"fake_opt":0}}'
            tres_pres = json.decode(load_pres3)
            loaded_pres3 = 1
        end
    else
        if not loaded_pres3 then
            tres_pres = json.decode(load_pres3)
            loaded_pres3 = 1
        end
    end

    if not load_pres4 then
        if not loaded_pres4 then
            load_pres4 = '{"moving":{"yaw_mod_opt":1,"fake_flick":false,"yaw_opt":4,"roll":false,"rollint_r":0,"fake_l":58,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":35,"max_velo_int":100,"rollint_l":0,"random_desync":false,"yaw_add":0,"lby_r":58,"fake_opt":8},"slowwalk":{"yaw_mod_opt":0,"fake_flick":false,"yaw_opt":4,"roll":true,"rollint_r":90,"fake_l":56,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":0,"max_velo_int":101,"rollint_l":90,"random_desync":false,"yaw_add":44,"lby_r":58,"fake_opt":0},"air":{"yaw_mod_opt":1,"fake_flick":false,"yaw_opt":4,"roll":false,"rollint_r":0,"fake_l":58,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":64,"max_velo_int":100,"rollint_l":0,"random_desync":false,"yaw_add":0,"lby_r":58,"fake_opt":2},"standing":{"yaw_mod_opt":0,"fake_flick":false,"yaw_opt":4,"roll":true,"rollint_r":90,"fake_l":58,"random_lean":false,"lby_l":58,"fake_flick_angle":0,"fake_r":58,"ticks_to_flick":0,"yaw_mod_add":0,"max_velo_int":100,"rollint_l":90,"random_desync":false,"yaw_add":23,"lby_r":58,"fake_opt":0}}'
            quat_pres = json.decode(load_pres4)
            loaded_pres4 = 1
        end
    else
        if not loaded_pres4 then
            quat_pres = json.decode(load_pres4)
            loaded_pres4 = 1
        end
    end

    --ghetto wifi fix out

    --eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee
    local local_player = EntityList.GetLocalPlayer()
    local speed_x = local_player:GetProp("DT_BasePlayer", "m_vecVelocity[0]")
    local speed_y = local_player:GetProp("DT_BasePlayer", "m_vecVelocity[1]")
    local speed_z = local_player:GetProp("DT_BasePlayer", "m_vecVelocity[2]")
    local speed = math.sqrt(speed_y * speed_y + speed_x * speed_x);
    local airspeed = math.sqrt(speed_z*speed_z)
    --local airspeed = cmd.upmove

    local player_flags = local_player:GetProp("m_fFlags")
    if (bit.band(player_flags, 1) == 1) then
        inair = 0
        --print("not in air")
    else
        inair = 1
        --print("in air")
    end
        
    --print(tostring(airspeed))
    --if airspeed == 0 then print("ddos") end

    if inair == 1 then
        --print("in air")
        condition = air
        un_pres.condition = un_pres.air
        dos_pres.condition = dos_pres.air
        tres_pres.condition = tres_pres.air
        quat_pres.condition = quat_pres.air
        if link_custom then
            cinq_pres.condition = cinq_pres.air
        end
    elseif Menu.FindVar("Aimbot", "Anti Aim", "Misc", "Slow Walk"):GetBool() then
        condition = slowwalk
        un_pres.condition = un_pres.slowwalk
        dos_pres.condition = dos_pres.slowwalk
        tres_pres.condition = tres_pres.slowwalk
        quat_pres.condition = quat_pres.slowwalk
        if link_custom then
            cinq_pres.condition = cinq_pres.slowwalk
        end
        --print("slowwalk")
    elseif slowwalk_norm:GetBool() then
        condition = slowwalk
        un_pres.condition = un_pres.slowwalk
        dos_pres.condition = dos_pres.slowwalk
        tres_pres.condition = tres_pres.slowwalk
        quat_pres.condition = quat_pres.slowwalk
        if link_custom then
            cinq_pres.condition = cinq_pres.slowwalk
        end
        --print("slowwalk")
    elseif break_slowwalk:GetBool() then
        condition = slowwalk
        un_pres.condition = un_pres.slowwalk
        dos_pres.condition = dos_pres.slowwalk
        tres_pres.condition = tres_pres.slowwalk
        quat_pres.condition = quat_pres.slowwalk
        if link_custom then
            cinq_pres.condition = cinq_pres.slowwalk
        end
        --print("slowwalk")
    elseif speed < 10 then
        condition = standing
        un_pres.condition = un_pres.standing
        dos_pres.condition = dos_pres.standing
        tres_pres.condition = tres_pres.standing
        quat_pres.condition = quat_pres.standing
        if link_custom then
            cinq_pres.condition = cinq_pres.standing
        end
        --print("santdng")
    elseif speed>11 then
        condition = moving
        un_pres.condition = un_pres.moving
        dos_pres.condition = dos_pres.moving
        tres_pres.condition = tres_pres.moving
        quat_pres.condition = quat_pres.moving
        if link_custom then
            cinq_pres.condition = cinq_pres.moving
        end
        --print("moveing")
    end

    --slowwalk customand shit
    if slowwalk_norm:GetBool() then 
        if cmd.forwardmove >= slowwalk_speed:GetInt() then
            cmd.forwardmove = slowwalk_speed:GetInt()
        end 
        if cmd.sidemove >= slowwalk_speed:GetInt() then
            cmd.sidemove = slowwalk_speed:GetInt()
        end 
        if cmd.forwardmove < 0 and -cmd.forwardmove >=slowwalk_speed:GetInt() then
            cmd.forwardmove = -slowwalk_speed:GetInt()
        end
        if cmd.sidemove < 0 and -cmd.sidemove >=slowwalk_speed:GetInt() then
            cmd.sidemove = -slowwalk_speed:GetInt()  
        end
    end
    if break_slowwalk:GetBool() then
        if (GlobalVars.tickcount % sw_time:GetInt())*2 < sw_time:GetInt()  then 
            cmd.forwardmove = 0
            cmd.sidemove = 0
        else
            if cmd.forwardmove >= slowwalk_speed:GetInt() then
                cmd.forwardmove = slowwalk_speed:GetInt()
            end 
            if cmd.sidemove >= slowwalk_speed:GetInt() then
                cmd.sidemove = slowwalk_speed:GetInt()
            end 
            if cmd.forwardmove < 0 and -cmd.forwardmove >=slowwalk_speed:GetInt() then
                cmd.forwardmove = -slowwalk_speed:GetInt()
            end
            if cmd.sidemove < 0 and -cmd.sidemove >=slowwalk_speed:GetInt() then
                cmd.sidemove = -slowwalk_speed:GetInt()
            end
        end
    end
    --if we exec cmd too fast we get kickerinoo and we dont want that
    if GlobalVars.tickcount % 5 then
        can_cmd = true
    else
        can_cmd = false
    end
    --condition determination
    if main.aa_sw:GetBool() then
        --print(main.presets:GetInt())
        if main.presets:GetInt() == 0 then
            local menu_cond = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Fake Options")
            menu_cond:SetInt(condition.fake_opt:GetInt())
            local menu_yaw_base = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Base")
            menu_yaw_base:SetInt(condition.yaw_opt:GetInt())
            local menu_yaw_add = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Add")
            menu_yaw_add:SetInt(condition.yaw_add:GetInt()*(AntiAim.GetInverterState()and-1 or 1))
            --print(condition.yaw_add:GetInt())
            local menu_yaw_mod_opt = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Modifier")
            menu_yaw_mod_opt:SetInt(condition.yaw_mod_opt:GetInt())
            local menu_yaw_mod_add = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Modifier Degree")
            menu_yaw_mod_add:SetInt(condition.yaw_mod_add:GetInt())
        elseif main.presets:GetInt() == 1 then
            local menu_cond = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Fake Options")
            menu_cond:SetInt(un_pres.condition.fake_opt)
            local menu_yaw_base = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Base")
            menu_yaw_base:SetInt(un_pres.condition.yaw_opt)
            local menu_yaw_add = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Add")
            menu_yaw_add:SetInt(un_pres.condition.yaw_add*(AntiAim.GetInverterState()and-1 or 1))
            local menu_yaw_mod_opt = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Modifier")
            menu_yaw_mod_opt:SetInt(un_pres.condition.yaw_mod_opt)
            local menu_yaw_mod_add = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Modifier Degree")
            menu_yaw_mod_add:SetInt(un_pres.condition.yaw_mod_add)
        elseif main.presets:GetInt() == 2 then
            local menu_cond = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Fake Options")
            menu_cond:SetInt(dos_pres.condition.fake_opt)
            local menu_yaw_base = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Base")
            menu_yaw_base:SetInt(dos_pres.condition.yaw_opt)
            local menu_yaw_add = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Add")
            menu_yaw_add:SetInt(dos_pres.condition.yaw_add*(AntiAim.GetInverterState()and-1 or 1))
            local menu_yaw_mod_opt = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Modifier")
            menu_yaw_mod_opt:SetInt(dos_pres.condition.yaw_mod_opt)
            local menu_yaw_mod_add = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Modifier Degree")
            menu_yaw_mod_add:SetInt(dos_pres.condition.yaw_mod_add)
        elseif main.presets:GetInt() == 3 then
            local menu_cond = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Fake Options")
            menu_cond:SetInt(tres_pres.condition.fake_opt)
            local menu_yaw_base = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Base")
            menu_yaw_base:SetInt(tres_pres.condition.yaw_opt)
            local menu_yaw_add = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Add")
            menu_yaw_add:SetInt(tres_pres.condition.yaw_add*(AntiAim.GetInverterState()and-1 or 1))
            local menu_yaw_mod_opt = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Modifier")
            menu_yaw_mod_opt:SetInt(tres_pres.condition.yaw_mod_opt)
            local menu_yaw_mod_add = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Modifier Degree")
            menu_yaw_mod_add:SetInt(tres_pres.condition.yaw_mod_add)
        elseif main.presets:GetInt() == 4 then
            local menu_cond = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Fake Options")
            menu_cond:SetInt(quat_pres.condition.fake_opt)
            local menu_yaw_base = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Base")
            menu_yaw_base:SetInt(quat_pres.condition.yaw_opt)
            local menu_yaw_add = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Add")
            menu_yaw_add:SetInt(quat_pres.condition.yaw_add*(AntiAim.GetInverterState()and-1 or 1))
            local menu_yaw_mod_opt = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Modifier")
            menu_yaw_mod_opt:SetInt(quat_pres.condition.yaw_mod_opt)
            local menu_yaw_mod_add = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Modifier Degree")
            menu_yaw_mod_add:SetInt(quat_pres.condition.yaw_mod_add)
        elseif main.presets:GetInt() == 5 then
            if link_custom then
                local menu_cond = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Fake Options")
                menu_cond:SetInt(cinq_pres.condition.fake_opt)
                local menu_yaw_base = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Base")
                menu_yaw_base:SetInt(cinq_pres.condition.yaw_opt)
                local menu_yaw_add = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Add")
                menu_yaw_add:SetInt(cinq_pres.condition.yaw_add*(AntiAim.GetInverterState()and-1 or 1))
                local menu_yaw_mod_opt = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Modifier")
                menu_yaw_mod_opt:SetInt(cinq_pres.condition.yaw_mod_opt)
                local menu_yaw_mod_add = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Modifier Degree")
                menu_yaw_mod_add:SetInt(cinq_pres.condition.yaw_mod_add)
            end
        end
    end
    --print(tostring(airspeed))
    disable_tp()
    --local load_pres = Http.Get('https://raw.githubusercontent.com/kiwihvh/leanyaw/main/presets.json')
    --local un_pres = json.decode(load_pres)
    --print(tostring(un_pres.standing.random_desync:GetBool()))
end
Cheat.RegisterCallback('createmove', custom_slowwalk)

--[[local function slowdown(speed, cmd)
    if cmd.forwardmove >= speed then
        cmd.forwardmove = speed
    end 
    if cmd.sidemove >= speed then
        cmd.sidemove = speed
    end 
    if cmd.forwardmove < 0 and -cmd.forwardmove >=speed then
        cmd.forwardmove = -speed
    end
    if cmd.sidemove < 0 and -cmd.sidemove >=speed then
        cmd.sidemove = -speed
    end
end]]






                 







--used for debbuging imager post (boo$$)
--local sliderintx = Menu.SliderInt("Neverlose", "Sliderx", 100, -1920, 1920, "Tooltip")
--local sliderinty = Menu.SliderInt("Neverlose", "Slidery", 100, -1920, 1920, "Tooltip")



Cheat.RegisterCallback("events", function(e)
    local event_name = e:GetName()
    if event_name == "player_hurt" then
        local attacker = EntityList.GetPlayerForUserID(e:GetInt("attacker", 0))
        if attacker:GetName() == EntityList.GetLocalPlayer():GetName() then
            --print("should play sound??")
            if custom_hits:GetBool() and can_cmd then
                EngineClient.ExecuteClientCmd('playvol '.. InputText:GetString() .. ' 1')
            end
		end
    end
    if e:GetName() == "round_start" then
		oldticks = 0
	end
	if e:GetName() == "round_end" then
		oldticks = 0
	end
end)

--[[cheat.RegisterCallback("draw", function()
if clantag_sw then 
    Menu.textB
)--]]


		 -- Set the menu item change callback on our checkbox
--  Now the callback will be ran whenever the item changes its value
--header




--here i was doing fl but idk its not useful
--here i am doing fr and its useful

local oldticks = 0
local function fakelager(cmd)
    local chrg = Exploits.GetCharge()
    local t_choke_max = CVar.FindVar("sv_maxusrcmdprocessticks"):GetInt()
    local local_player = EntityList.GetLocalPlayer()
    local spe2ed_x = local_player:GetProp("DT_BasePlayer", "m_vecVelocity[0]")
    local spe2ed_y = local_player:GetProp("DT_BasePlayer", "m_vecVelocity[1]")
    local spe2ed = math.sqrt(spe2ed_y * spe2ed_y + spe2ed_x * spe2ed_x);

    --print("ddos fl")
    --print(tostring(chrg))
    if Menu.FindVar("Aimbot", "Anti Aim", "Misc", "Fake Duck"):GetBool() == false then
        --print("NOT FAKEUKING")
        --if spe2ed < 100 then
        
            if fl_sw:GetBool() then--fl_sw:GetBool() then
                --print("ddos fl")
                if chrg == 0 then
                    if GlobalVars.tickcount % 14 then--t_choke_max - 2 then
                        FakeLag.SetState(false)
                    end
                         
                end
            end
        --end
    end
    --doubletap
    local cl_clock_correction = CVar.FindVar("cl_clock_correction") --clock correction OOPS: I think soufiw already manages with this but whatever...
    local sv_maxusrcmdprocessticks = CVar.FindVar("sv_maxusrcmdprocessticks") --sv_maxusrcmdprocessticks
    local maxticks  = CVar.FindVar("sv_maxusrcmdprocessticks")
    --- os.execute

        ---
    if dt_enable:GetBool() then
        if dt_cor then
            CVar.FindVar("cl_clock_correction"):SetInt(0)
            CVar.FindVar("cl_clock_correction_adjustment_max_amount"):SetInt(450)
        else
            CVar.FindVar("cl_clock_correction"):SetInt(1)
            CVar.FindVar("cl_clock_correction_adjustment_max_amount"):SetInt(200)
        end
        Exploits.OverrideDoubleTapSpeed(dt_speed:GetInt())
        maxticks:SetInt(dt_speed:GetInt())
    end

    --end
    --aa shit
    if main.aa_sw:GetBool() then
        
        if main.presets:GetInt() == 0 then
            if condition.random_desync:GetBool() then 
                local desyncint = math.random( 0, 60 )
                AntiAim.OverrideLimit(desyncint)
                AntiAim.OverrideLBYOffset(desyncint)
            else
                if AntiAim.GetInverterState() then 
                    AntiAim.OverrideLimit(condition.fake_l:GetInt())
                    AntiAim.OverrideLBYOffset(-condition.lby_l:GetInt())
                else
                    AntiAim.OverrideLimit(condition.fake_r:GetInt())
                    AntiAim.OverrideLBYOffset(condition.lby_r:GetInt())
                end
            end
        elseif main.presets:GetInt() == 1 then
            if un_pres.condition.random_desync then 
                local desyncint = math.random( 0, 60 )
                AntiAim.OverrideLimit(desyncint)
                AntiAim.OverrideLBYOffset(desyncint)
            else
                if AntiAim.GetInverterState() then 
                    AntiAim.OverrideLimit(un_pres.condition.fake_l)
                    AntiAim.OverrideLBYOffset(-un_pres.condition.lby_l)
                else
                    AntiAim.OverrideLimit(un_pres.condition.fake_r)
                    AntiAim.OverrideLBYOffset(un_pres.condition.lby_r)
                end
            end
        elseif main.presets:GetInt() == 2 then
            if dos_pres.condition.random_desync then 
                local desyncint = math.random( 0, 60 )
                AntiAim.OverrideLimit(desyncint)
                AntiAim.OverrideLBYOffset(desyncint)
            else
                if AntiAim.GetInverterState() then 
                    AntiAim.OverrideLimit(dos_pres.condition.fake_l)
                    AntiAim.OverrideLBYOffset(-dos_pres.condition.lby_l)
                else
                    AntiAim.OverrideLimit(dos_pres.condition.fake_r)
                    AntiAim.OverrideLBYOffset(dos_pres.condition.lby_r)
                end
            end
        elseif main.presets:GetInt() == 3 then
            if tres_pres.condition.random_desync then 
                local desyncint = math.random( 0, 60 )
                AntiAim.OverrideLimit(desyncint)
                AntiAim.OverrideLBYOffset(desyncint)
            else
                if AntiAim.GetInverterState() then 
                    AntiAim.OverrideLimit(tres_pres.condition.fake_l)
                    AntiAim.OverrideLBYOffset(-tres_pres.condition.lby_l)
                else
                    AntiAim.OverrideLimit(tres_pres.condition.fake_r)
                    AntiAim.OverrideLBYOffset(tres_pres.condition.lby_r)
                end
            end
        end
    elseif main.presets:GetInt() == 4 then
        if quat_pres.condition.random_desync then 
            local desyncint = math.random( 0, 60 )
            AntiAim.OverrideLimit(desyncint)
            AntiAim.OverrideLBYOffset(desyncint)
        else
            if AntiAim.GetInverterState() then 
                AntiAim.OverrideLimit(quat_pres.condition.fake_l)
                AntiAim.OverrideLBYOffset(-quat_pres.condition.lby_l)
            else
                AntiAim.OverrideLimit(quat_pres.condition.fake_r)
                AntiAim.OverrideLBYOffset(quat_pres.condition.lby_r)
            end
        end
    elseif main.presets:GetInt() == 5 then
        if link_custom then
            if cinq_pres.condition.random_desync then 
                local desyncint = math.random( 0, 60 )
                AntiAim.OverrideLimit(desyncint)
                AntiAim.OverrideLBYOffset(desyncint)
            else
                if AntiAim.GetInverterState() then 
                    AntiAim.OverrideLimit(cinq_pres.condition.fake_l)
                    AntiAim.OverrideLBYOffset(-cinq_pres.condition.lby_l)
                else
                    AntiAim.OverrideLimit(cinq_pres.condition.fake_r)
                    AntiAim.OverrideLBYOffset(cinq_pres.condition.lby_r)
                end
            end
        end
    end
end
Cheat.RegisterCallback("prediction", fakelager)



Cheat.RegisterCallback("pre_prediction", function(cmd)
    legitaa(cmd)
    if not EntityList.GetLocalPlayer() then 
        return 
    end;
    if main.presets:GetInt() == 0 then
        if condition.fake_flick:GetBool() then
            if GlobalVars.tickcount % condition.ticks_to_flick:GetInt() == 1 then 
                FakeLag.ForceSend()
            end 
            if GlobalVars.tickcount % condition.ticks_to_flick:GetInt() == 0 then 
                AntiAim.OverrideYawOffset(condition.fake_flick_angle:GetInt()*(AntiAim.GetInverterState()and-1 or 1))
                --AntiAim.OverrideInverter(not AntiAim.GetInverterState())
            end 
        end
    elseif main.presets:GetInt() == 1 then
        if un_pres.condition.fake_flick then
            if GlobalVars.tickcount % un_pres.condition.ticks_to_flick == 1 then 
                FakeLag.ForceSend()
            end 
            if GlobalVars.tickcount % un_pres.condition.ticks_to_flick == 0 then 
                AntiAim.OverrideYawOffset(un_pres.condition.fake_flick_angle*(AntiAim.GetInverterState()and-1 or 1))
                --AntiAim.OverrideInverter(not AntiAim.GetInverterState())
            end 
        end
    elseif main.presets:GetInt() == 2 then
        if dos_pres.condition.fake_flick then
            if GlobalVars.tickcount % dos_pres.condition.ticks_to_flick == 1 then 
                FakeLag.ForceSend()
            end 
            if GlobalVars.tickcount % dos_pres.condition.ticks_to_flick == 0 then 
                AntiAim.OverrideYawOffset(dos_pres.condition.fake_flick_angle*(AntiAim.GetInverterState()and-1 or 1))
                --AntiAim.OverrideInverter(not AntiAim.GetInverterState())
            end 
        end
    elseif main.presets:GetInt() == 3 then
        if tres_pres.condition.fake_flick then
            if GlobalVars.tickcount % tres_pres.condition.ticks_to_flick == 1 then 
                FakeLag.ForceSend()
            end 
            if GlobalVars.tickcount % tres_pres.condition.ticks_to_flick == 0 then 
                AntiAim.OverrideYawOffset(tres_pres.condition.fake_flick_angle*(AntiAim.GetInverterState()and-1 or 1))
                --AntiAim.OverrideInverter(not AntiAim.GetInverterState())
            end 
        end
    elseif main.presets:GetInt() == 4 then
        if quat_pres.condition.fake_flick then
            if GlobalVars.tickcount % quat_pres.condition.ticks_to_flick == 1 then 
                FakeLag.ForceSend()
            end 
            if GlobalVars.tickcount % quat_pres.condition.ticks_to_flick == 0 then 
                AntiAim.OverrideYawOffset(quat_pres.condition.fake_flick_angle*(AntiAim.GetInverterState()and-1 or 1))
                --AntiAim.OverrideInverter(not AntiAim.GetInverterState())
            end 
        end
    elseif main.presets:GetInt() == 5 then
        if link_custom then
            if cinq_pres.condition.fake_flick then
                if GlobalVars.tickcount % cinq_pres.condition.ticks_to_flick == 1 then 
                    FakeLag.ForceSend()
                end 
                if GlobalVars.tickcount % cinq_pres.condition.ticks_to_flick == 0 then 
                    AntiAim.OverrideYawOffset(cinq_pres.condition.fake_flick_angle*(AntiAim.GetInverterState()and-1 or 1))
                    --AntiAim.OverrideInverter(not AntiAim.GetInverterState())
                end 
            end
        end
    end

        --local function desyncaa(cmd)
    --lean aa stuff here lulz
    local local_player = EntityList.GetLocalPlayer()
    local speed_x = local_player:GetProp("DT_BasePlayer", "m_vecVelocity[0]")
    local speed_y = local_player:GetProp("DT_BasePlayer", "m_vecVelocity[1]")
    local speed = math.sqrt(speed_y * speed_y + speed_x * speed_x);
    local curtime = GlobalVars.curtime
    local tick = cmd.tick_count
    local chokced = ClientState.m_choked_commands
    local view_angles = EngineClient.GetViewAngles()
    local oldangles = view_angles.roll
    if main.presets:GetInt() == 0 then
        if speed < condition.max_velo_int:GetInt() --[[and cmd.upmove == 0]] then
            if condition.roll:Get() then
                --cmd.viewangles.yaw = cmd.viewangles.yaw+90
                if condition.random_lean:GetBool() then 
                    cmd.viewangles.roll = math.random( -180, 180 )
                else
                    if AntiAim.GetInverterState() == true then
                        cmd.viewangles.roll = condition.rollint_l:GetInt()
                    else 
                        cmd.viewangles.roll = condition.rollint_r:GetInt()
                    end
                end
            end  
        end
    elseif main.presets:GetInt() == 1 then
        if speed < un_pres.condition.max_velo_int --[[and cmd.upmove == 0]] then
            if un_pres.condition.roll then
                --cmd.viewangles.yaw = cmd.viewangles.yaw+90
                if un_pres.condition.random_lean then 
                    cmd.viewangles.roll = math.random( -180, 180 )
                else
                    if AntiAim.GetInverterState() == true then
                        cmd.viewangles.roll = un_pres.condition.rollint_l
                    else 
                        cmd.viewangles.roll = un_pres.condition.rollint_r
                    end
                end
            end  
        end
    elseif main.presets:GetInt() == 2 then
        if speed < dos_pres.condition.max_velo_int --[[and cmd.upmove == 0]] then
            if dos_pres.condition.roll then
                --cmd.viewangles.yaw = cmd.viewangles.yaw+90
                if dos_pres.condition.random_lean then 
                    cmd.viewangles.roll = math.random( -180, 180 )
                else
                    if AntiAim.GetInverterState() == true then
                        cmd.viewangles.roll = dos_pres.condition.rollint_l
                    else 
                        cmd.viewangles.roll = dos_pres.condition.rollint_r
                    end
                end
            end  
        end
    elseif main.presets:GetInt() == 3 then
        if speed < tres_pres.condition.max_velo_int --[[and cmd.upmove == 0]] then
            if tres_pres.condition.roll then
                --cmd.viewangles.yaw = cmd.viewangles.yaw+90
                if tres_pres.condition.random_lean then 
                    cmd.viewangles.roll = math.random( -180, 180 )
                else
                    if AntiAim.GetInverterState() == true then
                        cmd.viewangles.roll = tres_pres.condition.rollint_l
                    else 
                        cmd.viewangles.roll = tres_pres.condition.rollint_r
                    end
                end
            end  
        end
    elseif main.presets:GetInt() == 4 then
        if speed < quat_pres.condition.max_velo_int --[[and cmd.upmove == 0]] then
            if quat_pres.condition.roll then
                --cmd.viewangles.yaw = cmd.viewangles.yaw+90
                if quat_pres.condition.random_lean then 
                    cmd.viewangles.roll = math.random( -180, 180 )
                else
                    if AntiAim.GetInverterState() == true then
                        cmd.viewangles.roll = quat_pres.condition.rollint_l
                    else 
                        cmd.viewangles.roll = quat_pres.condition.rollint_r
                    end
                end
            end  
        end
    elseif main.presets:GetInt() == 5 then
      if link_custom then
        if speed < cinq_pres.condition.max_velo_int --[[and cmd.upmove == 0]] then
            if cinq_pres.condition.roll then
                --cmd.viewangles.yaw = cmd.viewangles.yaw+90
                if cinq_pres.condition.random_lean then 
                    cmd.viewangles.roll = math.random( -180, 180 )
                else
                    if AntiAim.GetInverterState() == true then
                        cmd.viewangles.roll = cinq_pres.condition.rollint_l
                    else 
                        cmd.viewangles.roll = cinq_pres.condition.rollint_r
                    end
                end
            end  
        end
      end
    end

    if switch_lb:GetBool() then
        legmovement:Set(cmd.command_number % 3 == 0 and 0 or 1)
        --[[if legmovement:GetInt() == 2 then
            legmovement:SetInt(1)
        else
            legmovement:SetInt(2)
        end]]
    end
end)




local pres_exp = Menu.Button("Main", "Export Current settings to console","eeeee", function()
    local curr_settings={
        standing={
            random_desync= standing.random_desync:GetBool(),
            fake_l= standing.fake_l:GetInt(),
            lby_l= standing.lby_l:GetInt(),
            fake_r= standing.fake_r:GetInt(),
            lby_r= standing.lby_r:GetInt(),
            yaw_opt= standing.yaw_opt:GetInt(),
            yaw_add= standing.yaw_add:GetInt(),
            yaw_mod_opt= standing.yaw_mod_opt:GetInt(),
            yaw_mod_add= standing.yaw_mod_add:GetInt(),
            fake_opt= standing.fake_opt:GetInt(),
            roll= standing.roll:GetBool(),
            max_velo_int= standing.max_velo_int:GetInt(),
            random_lean= standing.random_lean:GetBool(),
            rollint_l= standing.rollint_l:GetInt(),
            rollint_r= standing.rollint_r:GetInt(),
            fake_flick= standing.fake_flick:GetBool(),
            ticks_to_flick= standing.ticks_to_flick:GetInt(),
            fake_flick_angle= standing.fake_flick_angle:GetInt()
        },
        moving={
            random_desync= moving.random_desync:GetBool(),
            fake_l= moving.fake_l:GetInt(),
            lby_l= moving.lby_l:GetInt(),
            fake_r= moving.fake_r:GetInt(),
            lby_r= moving.lby_r:GetInt(),
            yaw_opt= moving.yaw_opt:GetInt(),
            yaw_add= moving.yaw_add:GetInt(),
            yaw_mod_opt= moving.yaw_mod_opt:GetInt(),
            yaw_mod_add= moving.yaw_mod_add:GetInt(),
            fake_opt= moving.fake_opt:GetInt(),
            roll= moving.roll:GetBool(),
            max_velo_int= moving.max_velo_int:GetInt(),
            random_lean= moving.random_lean:GetBool(),
            rollint_l= moving.rollint_l:GetInt(),
            rollint_r= moving.rollint_r:GetInt(),
            fake_flick= moving.fake_flick:GetBool(),
            ticks_to_flick= moving.ticks_to_flick:GetInt(),
            fake_flick_angle= moving.fake_flick_angle:GetInt()
        },
        air={
            random_desync= air.random_desync:GetBool(),
            fake_l= air.fake_l:GetInt(),
            lby_l= air.lby_l:GetInt(),
            fake_r= air.fake_r:GetInt(),
            lby_r= air.lby_r:GetInt(),
            yaw_opt= air.yaw_opt:GetInt(),
            yaw_add= air.yaw_add:GetInt(),
            yaw_mod_opt= air.yaw_mod_opt:GetInt(),
            yaw_mod_add= air.yaw_mod_add:GetInt(),
            fake_opt= air.fake_opt:GetInt(),
            roll= air.roll:GetBool(),
            max_velo_int= air.max_velo_int:GetInt(),
            random_lean= air.random_lean:GetBool(),
            rollint_l= air.rollint_l:GetInt(),
            rollint_r= air.rollint_r:GetInt(),
            fake_flick= air.fake_flick:GetBool(),
            ticks_to_flick= air.ticks_to_flick:GetInt(),
            fake_flick_angle= air.fake_flick_angle:GetInt()
        },
        slowwalk={
            random_desync= slowwalk.random_desync:GetBool(),
            fake_l= slowwalk.fake_l:GetInt(),
            lby_l= slowwalk.lby_l:GetInt(),
            fake_r= slowwalk.fake_r:GetInt(),
            lby_r= slowwalk.lby_r:GetInt(),
            yaw_opt= slowwalk.yaw_opt:GetInt(),
            yaw_add= slowwalk.yaw_add:GetInt(),
            yaw_mod_opt= slowwalk.yaw_mod_opt:GetInt(),
            yaw_mod_add= slowwalk.yaw_mod_add:GetInt(),
            fake_opt= slowwalk.fake_opt:GetInt(),
            roll= slowwalk.roll:GetBool(),
            max_velo_int= slowwalk.max_velo_int:GetInt(),
            random_lean= slowwalk.random_lean:GetBool(),
            rollint_l= slowwalk.rollint_l:GetInt(),
            rollint_r= slowwalk.rollint_r:GetInt(),
            fake_flick= slowwalk.fake_flick:GetBool(),
            ticks_to_flick= slowwalk.ticks_to_flick:GetInt(),
            fake_flick_angle= slowwalk.fake_flick_angle:GetInt()
        }

        --condition = "standing"
    }
    print("CURRENT SETTINGS=")
        for key, table in pairs(curr_settings) do
            for key2, value in pairs(table) do
                print(key, key2, value)
            end
        end
        local settings_encoded = json.encode(curr_settings)
        print(settings_encoded)
        --[[local settings_decoded = json.decode(settingsj)
        print(tostring(settings_decoded))]]
end)
--[[function normalize_yaw( yaw )
    if not isfinite( yaw ) then
        return 0.0
    end

    if ( yaw >= -180 and yaw <= 180 ) then
        return yaw
    end

    local rot = math.ceil( math.abs( yaw / 360.0 ) );
    local angle = ( yaw < 0 ) and yaw + ( 360.0 * rot ) or yaw - ( 360.0 * rot );

    return angle;
end

-- Typical call:  if hasbit(x, bit(3)) then ...
function hasbit(x, p)
    return x % (p + p) >= p       
end

function setbit(x, p)
    return hasbit(x, p) and x or x + p
end

function clearbit(x, p)
    return hasbit(x, p) and x - p or x
end


is_desync_right_sided = normalize_yaw( AntiAim.GetFakeRotation( ) - AntiAim.GetCurrentRealRotation( ) ) > 0.0

]]