ffi.cdef[[



    typedef struct {
        float x;
        float y;
        float z;
    } vec3_struct;
    
    typedef struct {
        uint8_t r;
        uint8_t g;
        uint8_t b;
        uint8_t a;
    } color_struct_t;

    typedef void (__cdecl* console_color_print)(void*,const color_struct_t&, const char*, ...);

    typedef float*(__thiscall* bound)(void*);

    typedef void*(__thiscall* c_entity_list_get_client_entity_t)(void*, int);
    typedef void*(__thiscall* c_entity_list_get_client_entity_from_handle_t)(void*, uintptr_t);

    bool PlaySound(const char *pszSound, void *hmod, uint32_t fdwSound);
]]


--ctg from docs cba to self this shit   
local _set_clantag = ffi.cast('int(__fastcall*)(const char*, const char*)', Utils.PatternScan('engine.dll', '53 56 57 8B DA 8B F9 FF 15'))
local _last_clantag = nil
local set_clantag = function(v)
  if v == _last_clantag then return end
  _set_clantag(v, '\nl\ne\na\nn\n.\ny\na\nw\n')
  _last_clantag = v
end

local MENUTEXT = Menu.Text("Anti Aim", "<lean.yaw> Masters", "WARNING: LUA IS NOT FULLY FINNISHED, MANY FEATURES DONT WORK")
local menu={
    leg_move = Menu.FindVar("Aimbot", "Anti Aim", "Misc", "Leg Movement"),
    yaw_base = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Base"),
    yaw_add = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Add"),
    yaw_mod = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Modifier"),
    yaw_mod_deg = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Modifier Degree"),
    pitch = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Pitch"),
    slowwalk = Menu.FindVar("Aimbot", "Anti Aim", "Misc", "Slow Walk"),
    limit_left = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Left Limit"),
    limit_right = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Right Limit"),
    fake_opt = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Fake Options"),
    lby_mode = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "LBY Mode"),
    freestand_desync = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Freestanding Desync"),
    onshot_desync = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Desync On Shot"),
    anti_aim_enable = Menu.FindVar("Aimbot", "Anti Aim", "Main", "Enable Anti Aim"),
    inverter = Menu.FindVar("Aimbot", "Anti Aim", "Fake Angle", "Inverter")
}

local ui={
    
    masters={
        aa_enable = Menu.Switch("Anti Aim", "<lean.yaw> Masters", "Enable AntiAim", false),
        condition = Menu.Combo("Anti Aim", "<lean.yaw> Masters", "AA Condition", {"General", "Standing", "Moving", "In Air", "Slowwalk"}, 0),
        manual_base = Menu.Combo("Anti Aim", "<lean.yaw> Masters", "Manual Yaw Base",{"Disabled" ,"Forward", "Backward", "Right", "Left", "At Target", "Freestanding"}, 0)
    },
    general={
        override = Menu.Switch("Anti Aim", "<lean.yaw> General", "Enable AntiAim Override", false),
        yaw_base = Menu.Combo("Anti Aim", "<lean.yaw> General", "Yaw Base",{"Forward", "Backward", "Right", "Left", "At Target", "Freestanding"}, 4),
        yaw_add_left = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "Yaw Add Left", 0, -180, 180),
        yaw_add_right = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "Yaw Add Right", 0, -180, 180),
        yaw_mod = Menu.Combo("Anti Aim", "<lean.yaw> General", "Yaw Modifier", {"Disabled", "Center", "Offset", "Random", "Spin"}, 0),
        yaw_mod_deg = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "Modifier Degree", 0, -180, 180),
        limit_type = Menu.Combo("Anti Aim", "<lean.yaw> General", "Limit Type", {"Static", "Jitter", "Sway",  "Random"}, 0),
        limit_left = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "Left Limit", 0, 0, 60),
        limit_right = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "Right Limit", 0, 0, 60),
        jit1_limit_left = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "[1] Jitter Limit L", 0, 0, 60),
        jit2_limit_left = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "[2] Jitter Limit L", 0, 0, 60),
        jit1_limit_right = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "[1] Jitter Limit R", 0, 0, 60),
        jit2_limit_right = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "[2] Jitter Limit R", 0, 0, 60),
        sw_left_min = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "[L] Sway Limit Min", 0, 0, 60),
        sw_left_max = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "[L] Sway Limit Max", 0, 0, 60),
        sw_right_min = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "[R] Sway Limit Min", 0, 0, 60),
        sw_right_max = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "[R] Sway Limit Max", 0, 0, 60),
        sw_limit_ov = Menu.Switch("Anti Aim", "<lean.yaw> General", "Override Slowwalk Limit", false),
        sw_limit_val = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "Slowwalk Limit", 0, 0, 60),
        fake_opt = Menu.MultiCombo("Anti Aim", "<lean.yaw> General", "Fake Options", {"Avoid Overlap", "Jitter", "Randomize Jitter", "Anti Bruteforce"}, 0),
        lby_mode = Menu.Combo("Anti Aim", "<lean.yaw> General", "LBY Mode", {"Disabled", "Opposite", "Sway"}, 0),
        freestand_desync = Menu.Combo("Anti Aim", "<lean.yaw> General", "Freestanding Desync", {"Off", "Peek Fake", "Peek Real"}, 0),
        onshot_desync = Menu.Combo("Anti Aim", "<lean.yaw> General", "Desync On Shot", {"Disabled", "Opposite", "Freestanding", "Switch"}, 0),
        lean_mode = Menu.Combo("Anti Aim", "<lean.yaw> General", "Lean Type", {"Disabled", "Static", "Sway", "Random", "Spin"}, 0),
        lean_amount_left = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "Lean Amount Left", 0, -180, 180),
        lean_amount_right = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "Lean Amount Right", 0, -180, 180),
        lean_sway_min_r = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "[R] Sway Lean Min", 0, -180, 180),
        lean_sway_max_r = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "[R] Sway Lean Max", 0, -180, 180),
        lean_sway_min_l = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "[L] Sway Lean Min", 0, -180, 180),
        lean_sway_max_l = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "[L] Sway Lean Max", 0, -180, 180),
        lean_max_velo = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "Max Lean Velocity", 0, 0, 350),
        legit_aa_limit = Menu.SliderInt("Anti Aim", "<lean.yaw> General", "Legit AA Limit", 0, 0, 60)

    },
    standing={
        override = Menu.Switch("Anti Aim", "<lean.yaw> Standing", "Condition override", false),
        yaw_base = Menu.Combo("Anti Aim", "<lean.yaw> Standing", "Yaw Base",{"Forward", "Backward", "Right", "Left", "At Target", "Freestanding"}, 4),
        yaw_add_left = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "Yaw Add Left", 0, -180, 180),
        yaw_add_right = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "Yaw Add Right", 0, -180, 180),
        yaw_mod = Menu.Combo("Anti Aim", "<lean.yaw> Standing", "Yaw Modifier", {"Disabled", "Center", "Offset", "Random", "Spin"}, 0),
        yaw_mod_deg = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "Modifier Degree", 0, -180, 180),
        limit_type = Menu.Combo("Anti Aim", "<lean.yaw> Standing", "Limit Type", {"Static", "Jitter", "Sway",  "Random"}, 0),
        limit_left = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "Left Limit", 0, 0, 60),
        limit_right = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "Right Limit", 0, 0, 60),
        jit1_limit_left = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "[1] Jitter Limit L", 0, 0, 60),
        jit2_limit_left = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "[2] Jitter Limit L", 0, 0, 60),
        jit1_limit_right = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "[1] Jitter Limit R", 0, 0, 60),
        jit2_limit_right = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "[2] Jitter Limit R", 0, 0, 60),
        sw_left_min = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "[L] Sway Limit Min", 0, 0, 60),
        sw_left_max = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "[L] Sway Limit Max", 0, 0, 60),
        sw_right_min = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "[R] Sway Limit Min", 0, 0, 60),
        sw_right_max = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "[R] Sway Limit Max", 0, 0, 60),
        fake_opt = Menu.MultiCombo("Anti Aim", "<lean.yaw> Standing", "Fake Options", {"Avoid Overlap", "Jitter", "Randomize Jitter", "Anti Bruteforce"}, 0),
        lby_mode = Menu.Combo("Anti Aim", "<lean.yaw> Standing", "LBY Mode", {"Disabled", "Opposite", "Sway"}, 0),
        freestand_desync = Menu.Combo("Anti Aim", "<lean.yaw> Standing", "Freestanding Desync", {"Off", "Peek Fake", "Peek Real"}, 0),
        onshot_desync = Menu.Combo("Anti Aim", "<lean.yaw> Standing", "Desync On Shot", {"Disabled", "Opposite", "Freestanding", "Switch"}, 0),
        lean_mode = Menu.Combo("Anti Aim", "<lean.yaw> Standing", "Lean Type", {"Disabled", "Static", "Sway", "Random", "Spin"}, 0),
        lean_amount_left = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "Lean Amount Left", 0, -180, 180),
        lean_amount_right = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "Lean Amount Right", 0, -180, 180),
        lean_sway_min_r = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "[R] Sway Lean Min", 0, -180, 180),
        lean_sway_max_r = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "[R] Sway Lean Max", 0, -180, 180),
        lean_sway_min_l = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "[L] Sway Lean Min", 0, -180, 180),
        lean_sway_max_l = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "[L] Sway Lean Max", 0, -180, 180),
        lean_max_velo = Menu.SliderInt("Anti Aim", "<lean.yaw> Standing", "Max Lean Velocity", 0, 0, 350)
    },
    moving={
        override = Menu.Switch("Anti Aim", "<lean.yaw> Moving", "Condition override", false),
        yaw_base = Menu.Combo("Anti Aim", "<lean.yaw> Moving", "Yaw Base",{"Forward", "Backward", "Right", "Left", "At Target", "Freestanding"}, 4),
        yaw_add_left = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "Yaw Add Left", 0, -180, 180),
        yaw_add_right = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "Yaw Add Right", 0, -180, 180),
        yaw_mod = Menu.Combo("Anti Aim", "<lean.yaw> Moving", "Yaw Modifier", {"Disabled", "Center", "Offset", "Random", "Spin"}, 0),
        yaw_mod_deg = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "Modifier Degree", 0, -180, 180),
        limit_type = Menu.Combo("Anti Aim", "<lean.yaw> Moving", "Limit Type", {"Static", "Jitter", "Sway", "Random"}, 0),
        limit_left = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "Left Limit", 0, 0, 60),
        limit_right = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "Right Limit", 0, 0, 60),
        jit1_limit_left = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "[1] Jitter Limit L", 0, 0, 60),
        jit2_limit_left = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "[2] Jitter Limit L", 0, 0, 60),
        jit1_limit_right = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "[1] Jitter Limit R", 0, 0, 60),
        jit2_limit_right = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "[2] Jitter Limit R", 0, 0, 60),
        sw_left_min = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "[L] Sway Limit Min", 0, 0, 60),
        sw_left_max = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "[L] Sway Limit Max", 0, 0, 60),
        sw_right_min = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "[R] Sway Limit Min", 0, 0, 60),
        sw_right_max = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "[R] Sway Limit Max", 0, 0, 60),
        fake_opt = Menu.MultiCombo("Anti Aim", "<lean.yaw> Moving", "Fake Options", {"Avoid Overlap", "Jitter", "Randomize Jitter", "Anti Bruteforce"}, 0),
        lby_mode = Menu.Combo("Anti Aim", "<lean.yaw> Moving", "LBY Mode", {"Disabled", "Opposite", "Sway"}, 0),
        freestand_desync = Menu.Combo("Anti Aim", "<lean.yaw> Moving", "Freestanding Desync", {"Off", "Peek Fake", "Peek Real"}, 0),
        onshot_desync = Menu.Combo("Anti Aim", "<lean.yaw> Moving", "Desync On Shot", {"Disabled", "Opposite", "Freestanding", "Switch"}, 0),
        lean_mode = Menu.Combo("Anti Aim", "<lean.yaw> Moving", "Lean Type", {"Disabled", "Static", "Sway", "Random", "Spin"}, 0),
        lean_amount_left = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "Lean Amount Left", 0, -180, 180),
        lean_amount_right = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "Lean Amount Right", 0, -180, 180),
        lean_sway_min_r = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "[R] Sway Lean Min", 0, -180, 180),
        lean_sway_max_r = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "[R] Sway Lean Max", 0, -180, 180),
        lean_sway_min_l = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "[L] Sway Lean Min", 0, -180, 180),
        lean_sway_max_l = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "[L] Sway Lean Max", 0, -180, 180),
        lean_max_velo = Menu.SliderInt("Anti Aim", "<lean.yaw> Moving", "Max Lean Velocity", 0, 0, 350)
    },
    inair={
        override = Menu.Switch("Anti Aim", "<lean.yaw> In Air", "Condition override", false),
        yaw_base = Menu.Combo("Anti Aim", "<lean.yaw> In Air", "Yaw Base",{"Forward", "Backward", "Right", "Left", "At Target", "Freestanding"}, 4),
        yaw_add_left = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "Yaw Add Left", 0, -180, 180),
        yaw_add_right = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "Yaw Add Right", 0, -180, 180),
        yaw_mod = Menu.Combo("Anti Aim", "<lean.yaw> In Air", "Yaw Modifier", {"Disabled", "Center", "Offset", "Random", "Spin"}, 0),
        yaw_mod_deg = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "Modifier Degree", 0, -180, 180),
        limit_type = Menu.Combo("Anti Aim", "<lean.yaw> In Air", "Limit Type", {"Static", "Jitter", "Sway",  "Random"}, 0),
        limit_left = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "Left Limit", 0, 0, 60),
        limit_right = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "Right Limit", 0, 0, 60),
        jit1_limit_left = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "[1] Jitter Limit L", 0, 0, 60),
        jit2_limit_left = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "[2] Jitter Limit L", 0, 0, 60),
        jit1_limit_right = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "[1] Jitter Limit R", 0, 0, 60),
        jit2_limit_right = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "[2] Jitter Limit R", 0, 0, 60),
        sw_left_min = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "[L] Sway Limit Min", 0, 0, 60),
        sw_left_max = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "[L] Sway Limit Max", 0, 0, 60),
        sw_right_min = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "[R] Sway Limit Min", 0, 0, 60),
        sw_right_max = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "[R] Sway Limit Max", 0, 0, 60),
        fake_opt = Menu.MultiCombo("Anti Aim", "<lean.yaw> In Air", "Fake Options", {"Avoid Overlap", "Jitter", "Randomize Jitter", "Anti Bruteforce"}, 0),
        lby_mode = Menu.Combo("Anti Aim", "<lean.yaw> In Air", "LBY Mode", {"Disabled", "Opposite", "Sway"}, 0),
        freestand_desync = Menu.Combo("Anti Aim", "<lean.yaw> In Air", "Freestanding Desync", {"Off", "Peek Fake", "Peek Real"}, 0),
        onshot_desync = Menu.Combo("Anti Aim", "<lean.yaw> In Air", "Desync On Shot", {"Disabled", "Opposite", "Freestanding", "Switch"}, 0),
        lean_mode = Menu.Combo("Anti Aim", "<lean.yaw> In Air", "Lean Type", {"Disabled", "Static", "Sway", "Random", "Spin"}, 0),
        lean_amount_left = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "Lean Amount Left", 0, -180, 180),
        lean_amount_right = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "Lean Amount Right", 0, -180, 180),
        lean_sway_min_r = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "[R] Sway Lean Min", 0, -180, 180),
        lean_sway_max_r = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "[R] Sway Lean Max", 0, -180, 180),
        lean_sway_min_l = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "[L] Sway Lean Min", 0, -180, 180),
        lean_sway_max_l = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "[L] Sway Lean Max", 0, -180, 180),
        lean_max_velo = Menu.SliderInt("Anti Aim", "<lean.yaw> In Air", "Max Lean Velocity", 0, 0, 350)
    },
    slowwalk={
        override = Menu.Switch("Anti Aim", "<lean.yaw> Slowwalk", "Condition override", false),
        yaw_base = Menu.Combo("Anti Aim", "<lean.yaw> Slowwalk", "Yaw Base",{"Forward", "Backward", "Right", "Left", "At Target", "Freestanding"}, 4),
        yaw_add_left = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "Yaw Add Left", 0, -180, 180),
        yaw_add_right = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "Yaw Add Right", 0, -180, 180),
        yaw_mod = Menu.Combo("Anti Aim", "<lean.yaw> Slowwalk", "Yaw Modifier", {"Disabled", "Center", "Offset", "Random", "Spin"}, 0),
        yaw_mod_deg = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "Modifier Degree", 0, -180, 180),
        limit_type = Menu.Combo("Anti Aim", "<lean.yaw> Slowwalk", "Limit Type", {"Static", "Jitter", "Sway",  "Random"}, 0),
        limit_left = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "Left Limit", 0, 0, 60),
        limit_right = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "Right Limit", 0, 0, 60),
        jit1_limit_left = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "[1] Jitter Limit L", 0, 0, 60),
        jit2_limit_left = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "[2] Jitter Limit L", 0, 0, 60),
        jit1_limit_right = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "[1] Jitter Limit R", 0, 0, 60),
        jit2_limit_right = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "[2] Jitter Limit R", 0, 0, 60),
        sw_left_min = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "[L] Sway Limit Min", 0, 0, 60),
        sw_left_max = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "[L] Sway Limit Max", 0, 0, 60),
        sw_right_min = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "[R] Sway Limit Min", 0, 0, 60),
        sw_right_max = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "[R] Sway Limit Max", 0, 0, 60),
        fake_opt = Menu.MultiCombo("Anti Aim", "<lean.yaw> Slowwalk", "Fake Options", {"Avoid Overlap", "Jitter", "Randomize Jitter", "Anti Bruteforce"}, 0),
        lby_mode = Menu.Combo("Anti Aim", "<lean.yaw> Slowwalk", "LBY Mode", {"Disabled", "Opposite", "Sway"}, 0),
        freestand_desync = Menu.Combo("Anti Aim", "<lean.yaw> Slowwalk", "Freestanding Desync", {"Off", "Peek Fake", "Peek Real"}, 0),
        onshot_desync = Menu.Combo("Anti Aim", "<lean.yaw> Slowwalk", "Desync On Shot", {"Disabled", "Opposite", "Freestanding", "Switch"}, 0),
        lean_mode = Menu.Combo("Anti Aim", "<lean.yaw> Slowwalk", "Lean Type", {"Disabled", "Static", "Sway", "Random", "Spin"}, 0),
        lean_amount_left = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "Lean Amount Left", 0, -180, 180),
        lean_amount_right = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "Lean Amount Right", 0, -180, 180),
        lean_sway_min_r = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "[R] Sway Lean Min", 0, -180, 180),
        lean_sway_max_r = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "[R] Sway Lean Max", 0, -180, 180),
        lean_sway_min_l = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "[L] Sway Lean Min", 0, -180, 180),
        lean_sway_max_l = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "[L] Sway Lean Max", 0, -180, 180),
        lean_max_velo = Menu.SliderInt("Anti Aim", "<lean.yaw> Slowwalk", "Max Lean Velocity", 0, 0, 350)
    },
    scope={
        enable = Menu.Switch("Visuals", "<lean.yaw> Scope", "Enable Custom Scope", false),
        viewmod = Menu.Switch("Visuals", "<lean.yaw> Scope", "Viewmodel In Scope", false),
        height = Menu.SliderInt("Visuals", "<lean.yaw> Scope", "Scope Height", 13, 0, 450),
        length = Menu.SliderInt("Visuals", "<lean.yaw> Scope", "Scope Length", 13, 0, 450),
        width = Menu.SliderInt("Visuals", "<lean.yaw> Scope", "Scope Width", 1, 0, 100),
        offset = Menu.SliderInt("Visuals", "<lean.yaw> Scope", "Scope Offset", 1, 0, 100),
        col_1 = Menu.ColorEdit("Visuals","<lean.yaw> Scope", "Primary Color", Color.RGBA(255, 255, 255)),
        col_2 = Menu.ColorEdit("Visuals","<lean.yaw> Scope", "Secondary Color", Color.RGBA(255, 255, 255, 0))
    },
    interface={
        enable = Menu.MultiCombo("Visuals","<lean.yaw> Interface", "Windows", {"Watermark", "Bind List", "Spectator List", "HOLO Panel"}, 0, "Interface: keybinds, speclist, holo panel, state panel.")
    },
    misc={
        clantag = Menu.Combo("Misc","<lean.yaw> Misc","Clantag", {"No Override", "Disabled", "Lean.yaw animated",--[[ "State", "Custom"]]}, 0),
        ctg_pref = Menu.TextBox("Misc","<lean.yaw> Misc","Clantag Prefix", 3, "$ "),
        --static_leg = Menu.Switch("Misc","<lean.yaw> Misc","Static Legs", false),
        tpanim = Menu.Switch("Misc","<lean.yaw> Misc","Disable Thirdperson Animation", false, function(val) Cheat.SetThirdPersonAnim(val) end),
        slowwalk = Menu.Switch("Misc","<lean.yaw> Slowwalk","Custom SlowWalk", false),
        sw_speed = Menu.SliderInt("Misc", "<lean.yaw> Slowwalk", "SlowWalk Speed", 25, 0 , 250)
    }
}
key2s={

}
local key1s={
    "general",
    "standing",
    "moving",
    "inair", 
    "slowwalk"
}
local condo={
    ui.general
}
function setvals()
    for i in condo do
        condo
    end
end
function menustuff()

    ui.masters.aa_enable:SetVisible(true)

    ui.masters.condition:SetVisible(ui.masters.aa_enable:GetBool())
    general_en = ((ui.masters.aa_enable:GetBool() and ui.masters.condition:GetInt() == 0) and true or false)
    standing_en = ((ui.masters.aa_enable:GetBool() and ui.masters.condition:GetInt() == 1) and true or false)
    moving_en = ((ui.masters.aa_enable:GetBool() and ui.masters.condition:GetInt() == 2) and true or false)
    air_en = ((ui.masters.aa_enable:GetBool() and ui.masters.condition:GetInt() == 3) and true or false)
    slowwalk_en = ((ui.masters.aa_enable:GetBool() and ui.masters.condition:GetInt() == 4) and true or false)
    


    for key, val in pairs(ui) do
        for key2, val2 in pairs(val) do
            if key == "general" then
                condo = ui.general
                condo_en = general_en
                if key2 == "override" then
                    val2:SetVisible(condo_en)
                else 
                    if key2 =="lean_sway_min_r" or key2 =="lean_sway_max_r" or key2 =="lean_sway_max_l" or key2 =="lean_sway_min_l" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.lean_mode:GetInt()==2 and true or false))
                    elseif key2 =="lean_amount_left" or key2 =="lean_amount_right" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.lean_mode:GetInt()==1 and true or false))
                    elseif key2 =="limit_left" or key2 =="limit_right" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.limit_type:GetInt()==0 and true or false))
                    elseif key2 =="jit1_limit_left" or key2 =="jit2_limit_left" or key2 =="jit1_limit_right" or key2 =="jit2_limit_right" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.limit_type:GetInt()==1 and true or false))
                    elseif key2 =="sw_left_min" or key2 =="sw_left_max" or key2 =="sw_right_max" or key2 =="sw_right_min" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.limit_type:GetInt()==2 and true or false))
                    else
                        val2:SetVisible(condo_en and condo.override:GetBool())
                    end
                end
            end
            if key == "standing" then 
                condo = ui.standing
                condo_en = standing_en
                if key2 == "override" then
                    val2:SetVisible(condo_en)
                else 
                    if key2 =="lean_sway_min_r" or key2 =="lean_sway_max_r" or key2 =="lean_sway_max_l" or key2 =="lean_sway_min_l" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.lean_mode:GetInt()==2 and true or false))
                    elseif key2 =="lean_amount_left" or key2 =="lean_amount_right" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.lean_mode:GetInt()==1 and true or false))
                    elseif key2 =="limit_left" or key2 =="limit_right" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.limit_type:GetInt()==0 and true or false))
                    elseif key2 =="jit1_limit_left" or key2 =="jit2_limit_left" or key2 =="jit1_limit_right" or key2 =="jit2_limit_right" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.limit_type:GetInt()==1 and true or false))
                    elseif key2 =="sw_left_min" or key2 =="sw_left_max" or key2 =="sw_right_max" or key2 =="sw_right_min" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.limit_type:GetInt()==2 and true or false))
                    else
                        val2:SetVisible(condo_en and condo.override:GetBool())
                    end
                end
            end
            if key == "moving" then 
                condo = ui.moving
                condo_en = moving_en
                if key2 == "override" then
                    val2:SetVisible(condo_en)
                else 
                    if key2 =="lean_sway_min_r" or key2 =="lean_sway_max_r" or key2 =="lean_sway_max_l" or key2 =="lean_sway_min_l" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.lean_mode:GetInt()==2 and true or false))
                    elseif key2 =="lean_amount_left" or key2 =="lean_amount_right" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.lean_mode:GetInt()==1 and true or false))
                    elseif key2 =="limit_left" or key2 =="limit_right" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.limit_type:GetInt()==0 and true or false))
                    elseif key2 =="jit1_limit_left" or key2 =="jit2_limit_left" or key2 =="jit1_limit_right" or key2 =="jit2_limit_right" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.limit_type:GetInt()==1 and true or false))
                    elseif key2 =="sw_left_min" or key2 =="sw_left_max" or key2 =="sw_right_max" or key2 =="sw_right_min" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.limit_type:GetInt()==2 and true or false))
                    else
                        val2:SetVisible(condo_en and condo.override:GetBool())
                    end
                end
            end
            if key == "inair" then
                condo = ui.inair
                condo_en = air_en
                if key2 == "override" then
                    val2:SetVisible(condo_en)
                else 
                    if key2 =="lean_sway_min_r" or key2 =="lean_sway_max_r" or key2 =="lean_sway_max_l" or key2 =="lean_sway_min_l" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.lean_mode:GetInt()==2 and true or false))
                    elseif key2 =="lean_amount_left" or key2 =="lean_amount_right" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.lean_mode:GetInt()==1 and true or false))
                    elseif key2 =="limit_left" or key2 =="limit_right" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.limit_type:GetInt()==0 and true or false))
                    elseif key2 =="jit1_limit_left" or key2 =="jit2_limit_left" or key2 =="jit1_limit_right" or key2 =="jit2_limit_right" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.limit_type:GetInt()==1 and true or false))
                    elseif key2 =="sw_left_min" or key2 =="sw_left_max" or key2 =="sw_right_max" or key2 =="sw_right_min" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.limit_type:GetInt()==2 and true or false))
                    else
                        val2:SetVisible(condo_en and condo.override:GetBool())
                    end
                end
            end
            if key == "slowwalk" then
                condo = ui.slowwalk
                condo_en = slowwalk_en
                if key2 == "override" then
                    val2:SetVisible(condo_en)
                else 
                    if key2 =="lean_sway_min_r" or key2 =="lean_sway_max_r" or key2 =="lean_sway_max_l" or key2 =="lean_sway_min_l" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.lean_mode:GetInt()==2 and true or false))
                    elseif key2 =="lean_amount_left" or key2 =="lean_amount_right" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.lean_mode:GetInt()==1 and true or false))
                    elseif key2 =="limit_left" or key2 =="limit_right" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.limit_type:GetInt()==0 and true or false))
                    elseif key2 =="jit1_limit_left" or key2 =="jit2_limit_left" or key2 =="jit1_limit_right" or key2 =="jit2_limit_right" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.limit_type:GetInt()==1 and true or false))
                    elseif key2 =="sw_left_min" or key2 =="sw_left_max" or key2 =="sw_right_max" or key2 =="sw_right_min" then
                        val2:SetVisible(condo_en and condo.override:GetBool() and (condo.limit_type:GetInt()==2 and true or false))
                    else
                        val2:SetVisible(condo_en and condo.override:GetBool())
                    end
                end
            end
            if key == "misc" then
                if key2 == "ctg_pref" then
                    val2:SetVisible(ui.misc.clantag:GetInt() > 1 and true or false)
                end
            end
        end
    end
end

local cond = nil
local air = false
local stand = false
local move = false
local swalk = false
function slow(cmd, speed)
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
end
function slowwalk(cmd)
    if ui.misc.slowwalk:GetBool() then
        slow(cmd, ui.misc.sw_speed:GetInt())
    end
end
function getspeed(ent)
    
    speed_x = ent:GetProp("DT_BasePlayer", "m_vecVelocity[0]")
    speed_y = ent:GetProp("DT_BasePlayer", "m_vecVelocity[1]")
    speed_z = ent:GetProp("DT_BasePlayer", "m_vecVelocity[2]")
    speed = math.sqrt(speed_y * speed_y + speed_x * speed_x);
    return speed
end
local pos = true
local var = 0
function sway(min, max)
    if pos then
        var = var+1
    else
        var = var-1
    end
    --[[if cond == ui.standing then
        if var == 10 and not pos then
            var = -10
        end
        if var == -10 and pos then
            var = 10
        end
    end]]

    if var>max then pos = false end
    if var<min then pos = true end
    --return var
    return var
end
function is_inair(entiti)
    speed_z = entiti:GetProp("DT_BasePlayer", "m_vecVelocity[2]")
    if speed_z == 0 then return false
    else return true
    end
end
function condition(cmd)
    --cond = ui.general
    local_player = EntityList.GetLocalPlayer()
    velocity = getspeed(local_player)
    if velocity < 1.5 then stand = true else stand = false end
    --if not cmd.upmove == 0 then air = true else air = false end
    air = is_inair(local_player)
    if ui.misc.slowwalk:GetBool() or menu.slowwalk:GetBool() then swalk = true else swalk = false end
    --print(speed_z = entiti:GetProp("DT_BasePlayer", "m_vecVelocity[2]"))
    if velocity > 2 then move = true else move = false end
    --print(tostring(velocity))
    --print(tostring(cmd.upmove))
    if not air and not swalk and not move and not stand then 
        if ui.general.override:GetBool() then
            cond = ui.general
        else
            cond = nil
        end 
    elseif swalk then
        if ui.slowwalk.override:GetBool() then 
            cond = ui.slowwalk
        else
            cond = ui.general
        end
    elseif stand and not air then
        if ui.standing.override:GetBool() then 
            cond = ui.standing
        else
            cond = ui.general
        end
    elseif air then
        if ui.inair.override:GetBool() then 
            cond = ui.inair
        else
            cond = ui.general
        end
    elseif move then
        if ui.moving.override:GetBool() then
            cond = ui.moving
        else
            cond = ui.general
        end
    end
end
local limit_left
local limit_right
function antiaim(cmd)
    aa_inverter = AntiAim.GetInverterState()
    if cond == nil then return end
    if ui.masters.manual_base:GetInt() == 0 then
        menu.yaw_base:SetInt(cond.yaw_base:GetInt());
    else
        menu.yaw_base:SetInt(ui.masters.manual_base:GetInt()-1);
    end
    if cond == ui.general and not swalk == true and cond.sw_limit_ov:GetBool() then
        limit_left = cond.sw_limit_val:GetInt()
        limit_right = cond.sw_limit_val:GetInt()
    elseif cond.limit_type:GetInt() == 0 then
        limit_left = cond.limit_left:GetInt()
        limit_right = cond.limit_right:GetInt()
    elseif cond.limit_type:GetInt() == 1 then
        limit_left = GlobalVars.tickcount % 2 == 0 and cond.jit1_limit_left:GetInt() or cond.jit2_limit_left:GetInt()
        limit_right = GlobalVars.tickcount % 2 == 0 and cond.jit1_limit_right:GetInt() or cond.jit2_limit_right:GetInt()
    elseif cond.limit_type:GetInt() == 2 then
        limit_left = sway(cond.sw_left_min:GetInt(), cond.sw_left_max:GetInt())
        limit_right = sway(cond.sw_right_min:GetInt(), cond.sw_right_max:GetInt())
    else
        limit_left = math.random(0, 60)
        limit_right = math.random(0, 60)
    end
    menu.lby_mode:SetInt(cond.lby_mode:GetInt());menu.yaw_mod:SetInt(cond.yaw_mod:GetInt());menu.yaw_mod_deg:SetInt(cond.yaw_mod_deg:GetInt()); menu.fake_opt:SetInt(cond.fake_opt:GetInt()); menu.freestand_desync:SetInt(cond.freestand_desync:GetInt()); menu.onshot_desync:SetInt(cond.onshot_desync:GetInt());
    if aa_inverter then menu.yaw_add:SetInt(cond.yaw_add_left:GetInt()); menu.limit_left:SetInt(limit_left)
    else menu.yaw_add:SetInt(cond.yaw_add_right:GetInt()); menu.limit_right:SetInt(limit_right) end
end


function roll_that_shit(cmd)
    if not cond == nil and getspeed(EntityList.GetLocalPlayer()) > cond.lean_max_velo:GetInt() then return end
    inverter = AntiAim.GetInverterState()
    if cond == nil then return end
    lean_mode = cond.lean_mode:GetInt()
    sw_min_r = cond.lean_sway_min_r:GetInt()
    sw_max_r = cond.lean_sway_max_r:GetInt()
    sw_min_l = cond.lean_sway_min_l:GetInt()
    sw_max_l = cond.lean_sway_max_l:GetInt()
    if cond.lean_mode:GetInt() == 0 then 
        cmd.viewangles.roll = cmd.viewangles.roll
    end 
    if inverter == true and lean_mode == 1 then 
        cmd.viewangles.roll = cond.lean_amount_right:GetInt()
    elseif lean_mode == 1 then
        cmd.viewangles.roll = cond.lean_amount_left:GetInt()
    end
    if inverter == true and lean_mode == 2 then 
        cmd.viewangles.roll = sway(sw_min_r, sw_max_r)
    elseif lean_mode == 2 then
        cmd.viewangles.roll = sway(sw_min_l, sw_max_l)
    end
    if lean_mode == 3 then 
        cmd.viewangles.roll = math.random(-180, 180)
    end
end



--movefix shit translated from unknowncheats.me thread: https://www.unknowncheats.me/forum/counterstrike-global-offensive/265670-movement-fix.html
local orig_move = {0, 0, 0}

local sincos = function(ang)
    return Vector2.new(math.cos(ang), math.sin(ang))
end

local AngleToVector = function(angles)
    local fr, rt = Vector.new(0, 0, 0), Vector.new(0, 0, 0)

    local pitch = sincos(angles.pitch * 0.017453292519943)
    local yaw = sincos(angles.yaw * 0.017453292519943)
    local roll = sincos(angles.roll * 0.017453292519943)

    fr.x = pitch.x * yaw.x
    fr.y = pitch.x * yaw.y

    rt.x = -1 * roll.y * pitch.y * yaw.x + -1 * roll.x * -yaw.y
    rt.y = -1 * roll.y * pitch.y * yaw.y + -1 * roll.x * yaw.x

    return fr / #fr, rt / #rt
end

local function movefix(cmd)
    if cmd.viewangles.roll >= -45 and cmd.viewangles.roll <= 45 then
        local front_left, roght_lefthvh = AngleToVector(orig_move[3])
        local front_center, roght_centerhvh = AngleToVector(cmd.viewangles)

        local center = front_left * orig_move[1] + roght_lefthvh * orig_move[2]
        local div = roght_centerhvh.y * front_center.x - roght_centerhvh.x * front_center.y

        cmd.sidemove = (front_center.x * center.y - front_center.y * center.x) / div
        cmd.forwardmove = (roght_centerhvh.y * center.x - roght_centerhvh.x * center.y) / div
    end
end
local leanyaw_animate={
    "l",
    "le",
    "lea",
    "lean",
    "lean.",
    "lean.y",
    "lean.ya",
    "lean.yaw",
    "lean.yaw ",
    "^lean.yaw^",
    "#lean.yaw#",
    "$lean.yaw$",
    "%lean.yaw%",
    "&lean.yaw&",
    "*lean.yaw*",
    "^lean.yaw$",
    "%lean.yaw^",
    "^lean.yaw@",
    "l3an.yaw",
    "l3@n.yaw",
    "l3an.y@w",
    "l34n.y@w",
    "le@n.y4w",
    "13@n|Y4W",
    "lean.yaw",
    "lean.ya",
    "lean.y",
    "lean.",
    "lean",
    "lea",
    "le",
    "l",
    " ",
}
local animation = {
    "$ ", 			 
    "$ p", 			 
    "$ pv", 			 
    "$ pvs", 			 
    "$ pvst", 			 
    "$ pvste", 			 
    "$ pvster", 			 
    "$ pvster ", 			 
    "$ pvster $", 			 
    "$ pvster $y", 			 
    "$ pvster $yn", 			 
    "$ pvster $ync", 			 
    "$ pvster $ync", 			 
    "$ pvster $ync", 			 
    "$ pvster $ync", 			 
    "$ pvster $ync", 			 
    "$ pvster $ync", 			 
    "$ pvster $ync", 			 
    "$ pvster/ $ync/", 			 
    "$ pvste/- $yn/-", 			 
    "$ pvst/-- $yc/-", 			 
    "$ pvs/--- $y/--", 			 
    "$ pv/---- $y/--", 			 
    "$ p/----- $/---", 			 
    "$ /------ /-", 			 
    "$ /-----/", 			 
    "$ /----/", 			 
    "$ /---/", 			 
    "$ /--/", 			 
    "$ /-/", 			 
    "$ //", 			 
    "$", 			 
    "$", 			 
}
---end movefix shit
local do_clantag = true
local didonce = true
function clantag()
    --set_clantag("bos\n")
    ctg_int = ui.misc.clantag:GetInt()
    if not do_clantag then return end
    if ctg_int == 0 then return end
    if ctg_int == 1 and not didonce then set_clantag("") end
    if ctg_int == 2 then
        local curtime = math.floor(GlobalVars.curtime)
        if old_time ~= curtime then
            set_clantag(ui.misc.ctg_pref:GetString() .. leanyaw_animate[curtime % #leanyaw_animate+1] )
        end
        old_time = curtime
        didonce = false
    end
end



Cheat.RegisterCallback("override_view", function(view)

end)





Cheat.RegisterCallback("prediction", function(cmd)
    antiaim(cmd)
    roll_that_shit(cmd)
end)


function createmove(cmd)
    
    condition(cmd)
    roll_that_shit(cmd)
    orig_move = {cmd.forwardmove, cmd.sidemove, QAngle.new(0, cmd.viewangles.yaw, 0)}
    if cond == nil then return end
    if cond.lean_mode:GetInt() == 0 then return end
    movefix(cmd)
end

Cheat.RegisterCallback("createmove", function(cmd)
    createmove(cmd)
end)

function draw()
    menustuff()
    clantag()
end

Cheat.RegisterCallback("draw", function()
    draw()
end)


function events(e)
    local event_name = e:GetName()
    if event_name == "player_hurt" then
        local attacker = EntityList.GetPlayerForUserID(e:GetInt("attacker", 0))
        if attacker:GetName() == EntityList.GetLocalPlayer():GetName() then
            print("DEBUG: hurt some1")
		end
    end
    if e:GetName() == "round_start" then
		do_clantag = true
	end
	if e:GetName() == "round_end" then
		oldticks = 0
	end
    if e:GetName() == "start_halftime" then
		do_clantag = false
        if ui.misc.clantag:GetBool() then
            set_clantag('    lean.yaw     ', '\nl\ne\na\nn\n.\ny\na\nw\n')
        end
	end
end


Cheat.RegisterCallback("events", function(e)
    events(e)
end)