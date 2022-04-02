--script hazos
local exploit_amt = Menu.SliderInt("KiwiSploit$", "kiwisploit$$$$ value", 0, 0, 32, "idk 17(maxusr +1)")
local exploit_fake_pitch = Menu.SliderInt("KiwiSploit$", "kiwisploit$$$$ fake pitch", 0, -90, 90, "idk")
local exploit_real_pitch = Menu.SliderInt("KiwiSploit$", "kiwisploit$$$$ real pitch", 0, -90, 90, "idk")
local exploit_yaw_l = Menu.SliderInt("KiwiSploit$", "kiwisploit$$$$ fake yaw_l", 0, -180, 180, "115")
local exploit_yaw_r = Menu.SliderInt("KiwiSploit$", "kiwisploit$$$$ fake yaw_r", 0, -180, 180, "-115")
local exploit_real_yaw_l = Menu.SliderInt("KiwiSploit$", "kiwisploit$$$$ real yaw_l", 0, -180, 180, "-14 ")
local exploit_real_yaw_r = Menu.SliderInt("KiwiSploit$", "kiwisploit$$$$ real yaw_r", 0, -180, 180, "58 ")
local exploit = Menu.Switch("KiwiSploit$", "kiwisploit$$$$", false)
local show_fake = Menu.Switch("KiwiSploit$", "showfake shit idk", false)
local random = Menu.Switch("KiwiSploit$", "RANDOM", false)
function kiwisploit2()
    if not random:GetBool() then 
        real_y_l = exploit_real_yaw_l:GetInt()
        real_y_r = exploit_real_yaw_r:GetInt()
        fake_y_l = exploit_yaw_l:GetInt()
        fake_y_r = exploit_yaw_r:GetInt()
        real_p = exploit_real_pitch:GetInt()
        fake_p = exploit_fake_pitch:GetInt()
    else
        real_y_l = math.random(-180, 180)
        real_y_r = -real_y_l
        fake_y_l = math.random(-180, 180)
        fake_y_r = -fake_y_l
        real_p = math.random(-90, 90)
        fake_p = -real_p
    end
    if exploit:GetBool() then
        FakeLag.ForceSend()

        local ticks = CVar.FindVar("sv_maxusrcmdprocessticks")
        ticks:SetInt(exploit_amt:GetInt())

        Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Add"):Set(AntiAim.GetInverterState() and real_y_l or real_y_r )

        if ClientState.m_choked_commands > 1 and ClientState.m_choked_commands < ticks:GetInt()  then
            AntiAim.OverrideYawOffset( AntiAim.GetInverterState() and fake_y_l or fake_y_r)
            AntiAim.OverridePitch(fake_p)
        else
            AntiAim.OverridePitch(real_p)
        end
    else
        local ticks = CVar.FindVar("sv_maxusrcmdprocessticks")
        ticks:SetInt(16)
        Menu.FindVar("Aimbot", "Anti Aim", "Main", "Yaw Add"):Set(0)
    end
    EntityList.GetLocalPlayer():SetProp("m_bClientSideAnimation", show_fake:GetBool())
end

Cheat.RegisterCallback("prediction", kiwisploit2)