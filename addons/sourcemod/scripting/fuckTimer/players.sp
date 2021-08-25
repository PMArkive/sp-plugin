#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <fuckZones>
#include <fuckTimer_stocks>
#include <fuckTimer_api>
#include <fuckTimer_zones>
#include <fuckTimer_players>
#include <fuckTimer_commands>

#define MAX_DOT -0.75
#define LOW_GRAV 0.5
#define SLOW_MOTION 0.5
#define SETTING_STYLE "Style"
#define SETTING_INVALIDKEYPREF "InvalidKeyPref"

enum struct PlayerData
{
    PlayerStatus Status;
    bool InStage;
    
    StringMap Settings;

    void Reset()
    {
        this.Status = psInactive;
        this.InStage = false;

        delete this.Settings;
    }
}
PlayerData Player[MAXPLAYERS + 1];

enum struct PluginData
{
    StringMap Settings;

    GlobalForward OnPlayerLoaded;
}
PluginData Core;

#include "api/players.sp"

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "Players",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    Core.OnPlayerLoaded = new GlobalForward("fuckTimer_OnPlayerLoaded", ET_Ignore, Param_Cell);
    
    CreateNative("fuckTimer_RegisterSetting", Native_RegisterSetting);

    CreateNative("fuckTimer_GetClientSetting", Native_GetClientSetting);
    CreateNative("fuckTimer_SetClientSetting", Native_SetClientSetting);

    CreateNative("fuckTimer_GetClientStatus", Native_GetClientStatus);

    RegPluginLibrary("fuckTimer_players");

    return APLRes_Success;
}

public void OnPluginStart()
{
    delete Core.Settings;
    Core.Settings = new StringMap();

    char sValue[MAX_SETTING_VALUE_LENGTH];
    IntToString(view_as<int>(StyleNormal), sValue, sizeof(sValue));
    Core.Settings.SetString(SETTING_STYLE, sValue);
    
    IntToString(view_as<int>(IKStop), sValue, sizeof(sValue));
    Core.Settings.SetString(SETTING_INVALIDKEYPREF, sValue);

    HookEvent("player_activate", Event_PlayerActivate);
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);

    fuckTimer_LoopClients(client, false, false)
    {
        SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
    }
}

public void fuckTimer_OnClientRestart(int client)
{
    int iZone = fuckTimer_GetStartZone(fuckTimer_GetClientBonus(client));

    if (iZone > 0)
    {
        fuckTimer_TeleportEntityToZone(client, iZone);
    }
}

public Action Event_PlayerActivate(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    LoadPlayer(client);
}

public void OnClientDisconnect(int client)
{
    PrintToServer("OnClientDisconnect: %N", client);

    Player[client].Reset();
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    RequestFrame(Frame_PlayerSpawn, event.GetInt("userid"));
}

public void Frame_PlayerSpawn(any userid)
{
    int client = GetClientOfUserId(userid);

    if (fuckTimer_IsClientValid(client, true, false))
    {
        SetEntProp(client, Prop_Data, "m_CollisionGroup", 2); // No Block, 2 = COLLISION_GROUP_DEBRIS_TRIGGER
        SetEntProp(client, Prop_Send, "m_iHideHUD", 1<<12);   // Hide Radar

        int iZone = fuckTimer_GetStartZone(0);

        if (iZone > 0)
        {
            fuckTimer_TeleportEntityToZone(client, iZone);
        }
    }
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    if (Player[client].Settings != null && IsPlayerAlive(client) && fuckTimer_IsClientTimeRunning(client) && !Player[client].InStage)
    {
        Styles style;
        Player[client].Settings.GetValue(SETTING_STYLE, style);

        if (style == StyleSideways && (buttons & IN_MOVERIGHT || buttons & IN_MOVELEFT))
        {
            return OnInvalidKeyPressure(client, vel, buttons);
        }
        else if (style == StyleHSW && (!(buttons & IN_FORWARD) && !(buttons & IN_BACK) && (buttons & IN_MOVERIGHT || buttons & IN_MOVELEFT)))
        {
            return OnInvalidKeyPressure(client, vel, buttons);
        }
        else if (style == StyleBackwards)
        {
            // https://github.com/InfluxTimer/sm-timer/blob/28247c1d374402d529987f01281e5cb21849c495/addons/sourcemod/scripting/influx_style_backwards.sp#L69
            float fEyeAngle[3];
            GetClientEyeAngles(client, fEyeAngle);
            fEyeAngle[0] = Cosine(DegToRad(fEyeAngle[1]));
            fEyeAngle[1] = Sine(DegToRad(fEyeAngle[1]));
            fEyeAngle[2] = 0.0;

            float fVelocity[3];
            GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
            fVelocity[2] = 0.0;

            float fLen = SquareRoot(fVelocity[0] * fVelocity[0] + fVelocity[1] * fVelocity[1]);
            fVelocity[0] /= fLen;
            fVelocity[1] /= fLen;

            float fValue = GetVectorDotProduct(fEyeAngle, fVelocity);

            if (fValue > MAX_DOT)
            {
                return OnInvalidKeyPressure(client, vel, buttons);
            }
        }
        else if (style == StyleLowGravity)
        {
            if (GetEntityGravity(client) != LOW_GRAV)
            {
                SetEntityGravity(client, LOW_GRAV);
            }
        }
        else if (style == StyleSlowMotion)
        {
            if (GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue") != SLOW_MOTION)
            {
                SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", SLOW_MOTION);
            }
        }
    }

    return Plugin_Continue;
}

public Action OnTraceAttack(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& ammotype, int hitbox, int hitgroup)
{
    return Plugin_Handled;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (fuckTimer_IsClientValid(client, false, false))
    {
        fuckTimer_ResetClientTimer(client);
    }
}

public void fuckTimer_OnTouchZone(int client, int zone, const char[] name)
{
    int iBonus;
    int iStage = fuckTimer_GetStageByIndex(zone, iBonus);

    if (!fuckTimer_IsMiscZone(zone, iBonus) && iStage > 0)
    {
        Player[client].InStage = true;
    }
}

public void fuckTimer_OnLeavingZone(int client, int zone, const char[] name)
{
    int iBonus;
    int iStage = fuckTimer_GetStageByIndex(zone, iBonus);

    if (!fuckTimer_IsMiscZone(zone, iBonus) && iStage > 0)
    {
        Player[client].InStage = false;
    }
}

Action OnInvalidKeyPressure(int client, float vel[3], int buttons)
{
    eInvalidKeyPref preference;
    Player[client].Settings.GetValue(SETTING_INVALIDKEYPREF, preference);

    Styles style;
    Player[client].Settings.GetValue(SETTING_STYLE, style);

    if (preference == IKStop)
    {
        fuckTimer_ResetClientTimer(client);
        return Plugin_Continue;
    }
    else if (preference == IKRestart)
    {
        fuckTimer_RestartClient(client);
        return Plugin_Continue;
    }
    else if (preference == IKNormal)
    {
        char sBuffer[MAX_SETTING_VALUE_LENGTH];
        IntToString(view_as<int>(StyleNormal), sBuffer, sizeof(sBuffer));
        SetPlayerSetting(client, SETTING_STYLE, sBuffer);

        return Plugin_Continue;
    }
    
    if (style == StyleSideways || style == StyleHSW)
    {
        buttons &= ~IN_MOVERIGHT;
        buttons &= ~IN_MOVELEFT;
        
        vel[1] = 0.0;
    }
    else if (style == StyleBackwards)
    {
        vel[0] = 0.0;
        vel[1] = 0.0;
        vel[2] = 0.0;
    }

    return Plugin_Changed;
}

public any Native_RegisterSetting(Handle plugin, int numParams)
{
    if (Core.Settings == null)
    {
        Core.Settings = new StringMap();
    }

    char sSetting[MAX_SETTING_LENGTH];
    GetNativeString(1, sSetting, sizeof(sSetting));

    char sValue[MAX_SETTING_VALUE_LENGTH];
    GetNativeString(2, sValue, sizeof(sValue));

    Core.Settings.SetString(sSetting, sValue);
}

public any Native_GetClientSetting(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    char sSetting[MAX_SETTING_LENGTH];
    char sValue[MAX_SETTING_VALUE_LENGTH];

    GetNativeString(2, sSetting, sizeof(sSetting));

    if (Player[client].Settings == null)
    {
        return false;
    }

    bool status = Player[client].Settings.GetString(sSetting, sValue, sizeof(sValue));

    if (!status)
    {
        return false;
    }

    int success = SetNativeString(3, sValue, sizeof(sValue));

    if (success != SP_ERROR_NONE)
    {
        return false;
    }

    return true;

}
public any Native_SetClientSetting(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    
    char sSetting[MAX_SETTING_LENGTH];
    GetNativeString(2, sSetting, sizeof(sSetting));

    char sValue[MAX_SETTING_VALUE_LENGTH];
    GetNativeString(3, sValue, sizeof(sValue));

    if (StrEqual(sSetting, "Style"))
    {
        Styles style = view_as<Styles>(StringToInt(sValue));

        if (style != StyleLowGravity)
        {
            SetEntityGravity(client, 1.0);
        }
        
        if (style != StyleSlowMotion)
        {
            SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
        }
    }

    Player[client].Settings.SetString(sSetting, sValue);
    PrintToServer("[Players.Native_SetClientSetting] Adding setting %s with value of %s", sSetting, sValue);
    SetPlayerSetting(client, sSetting, sValue);
}

public any Native_GetClientStatus(Handle plugin, int numParams)
{
    return Player[GetNativeCell(1)].Status;
}

void LoadPlayer(int client)
{
    PrintToServer("[Players] LoadPlayer: %d", client);

    if (client < 1 || !IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client))
    {
        return;
    }

    PrintToServer("[Players] LoadPlayer: %N", client);

    Player[client].Reset();

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Player/Id/%d", GetSteamAccountID(client));
    fuckTimer_NewAPIHTTPRequest(sEndpoint).Get(GetPlayerData, GetClientUserId(client));
}
