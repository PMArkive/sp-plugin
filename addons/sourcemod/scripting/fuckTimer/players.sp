#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <fuckZones>
#include <fuckTimer_stocks>
#include <fuckTimer_api>
#include <fuckTimer_maps>
#include <fuckTimer_timer>
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
    int LastMessage;
    PlayerStatus Status;
    bool InStage;
    StringMap Settings;

    void Reset()
    {
        this.LastMessage = -1;
        this.Status = psInactive;
        this.InStage = false;
        delete this.Settings;
    }
}
PlayerData Player[MAXPLAYERS + 1];

enum struct PluginData
{
    StringMap Settings;
    ConVar MessageInterval;

    GlobalForward OnPlayerLoaded;
    GlobalForward OnSharedLocationsLoaded;
}
PluginData Core;

#include "players/locations.sp"
#include "api/players.sp"
#include "api/locations.sp"

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
    Core.OnSharedLocationsLoaded = new GlobalForward("fuckTimer_OnSharedLocationsLoaded", ET_Ignore);
    
    CreateNative("fuckTimer_RegisterSetting", Native_RegisterSetting);

    CreateNative("fuckTimer_GetClientSetting", Native_GetClientSetting);
    CreateNative("fuckTimer_SetClientSetting", Native_SetClientSetting);

    CreateNative("fuckTimer_GetClientStatus", Native_GetClientStatus);
    CreateNative("fuckTimer_GetClientStyle", Native_GetClientStyle);

    RegPluginLibrary("fuckTimer_players");

    return APLRes_Success;
}

public void OnPluginStart()
{
    fuckTimer_StartConfig("players");
    Core.MessageInterval = AutoExecConfig_CreateConVar("players_messge_interval", "3", "Send invalid key pressure message every X seconds. (0 or lower for disabling this feature)");
    fuckTimer_EndConfig();

    delete Core.Settings;
    Core.Settings = new StringMap();

    char sValue[MAX_SETTING_VALUE_LENGTH];
    IntToString(view_as<int>(StyleNormal), sValue, sizeof(sValue));
    Core.Settings.SetString(SETTING_STYLE, sValue);
    
    IntToString(view_as<int>(IKBlock), sValue, sizeof(sValue));
    Core.Settings.SetString(SETTING_INVALIDKEYPREF, sValue);

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_death", Event_PlayerDeath);

    fuckTimer_LoopClients(client, false, false)
    {
        SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
    }

    Locations_RegisterCommands();
    Locations_RegisterSettings();
}

public void OnMapStart()
{
    Locations_OnMapStart();
}

public void fuckTimer_OnStylesLoaded()
{
    LoadSharedLocations();
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);

    LoadPlayer(client);
    Locations_OnClientPutInServer(client);
}

public void fuckTimer_OnClientRestart(int client)
{
    int iZone = fuckTimer_GetStartZone(fuckTimer_GetClientBonus(client));

    if (iZone > 0)
    {
        fuckTimer_TeleportEntityToZone(client, iZone);
    }
}

public void OnClientDisconnect(int client)
{
    UpdatePlayer(client, true);
    Locations_OnClientDisconnect(client);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    RequestFrame(Frame_PlayerSpawn, event.GetInt("userid"));
    
    return Plugin_Continue;
}

public void Frame_PlayerSpawn(int userid)
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
    if (!IsPlayerAlive(client))
    {
        return Plugin_Continue;
    }

    if (Player[client].Settings != null && fuckTimer_IsClientTimeRunning(client) && !Player[client].InStage)
    {
        char sBuffer[12];
        Player[client].Settings.GetString(SETTING_STYLE, sBuffer, sizeof(sBuffer));
        Styles style = view_as<Styles>(StringToInt(sBuffer));

        switch (style)
        {
            case StyleSideways:
            {
                if (buttons & IN_MOVERIGHT || buttons & IN_MOVELEFT)
                {
                    return OnInvalidKeyPressure(client, vel, buttons);
                }
            }
            case StyleHSW:
            {
                if (!(buttons & IN_FORWARD) | !(buttons & IN_BACK) | (buttons & IN_MOVERIGHT || buttons & IN_MOVELEFT))
                {
                    return OnInvalidKeyPressure(client, vel, buttons);
                }
            }
            case StyleBackwards:
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
            case StyleLowGravity:
            {
                if (GetEntityGravity(client) != LOW_GRAV)
                {
                    SetEntityGravity(client, LOW_GRAV);
                }
            }
            case StyleSlowMotion:
            {
                if (GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue") != SLOW_MOTION)
                {
                    SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", SLOW_MOTION);
                }
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
    
    return Plugin_Continue;
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
    char sBuffer[MAX_SETTING_VALUE_LENGTH];
    Player[client].Settings.GetString(SETTING_INVALIDKEYPREF, sBuffer, sizeof(sBuffer));
    eInvalidKeyPref ePref = view_as<eInvalidKeyPref>(StringToInt(sBuffer));

    Player[client].Settings.GetString(SETTING_STYLE, sBuffer, sizeof(sBuffer));
    Styles sStyle = view_as<Styles>(StringToInt(sBuffer));

    char sMessage[128];

    switch (ePref)
    {
        case IKStop:
        {
            fuckTimer_ResetClientTimer(client);
            FormatEx(sMessage, sizeof(sMessage), "Invalid key pressure detected, Timer has been stopped.");

            return Plugin_Continue;
        }
        case IKRestart:
        {
            fuckTimer_RestartClient(client);
            FormatEx(sMessage, sizeof(sMessage), "Invalid key pressure detected, Timer has been restarted.");

            return Plugin_Continue;
        }
        case IKNormal:
        {
            IntToString(view_as<int>(StyleNormal), sBuffer, sizeof(sBuffer));
            SetPlayerSetting(client, SETTING_STYLE, sBuffer);
            FormatEx(sMessage, sizeof(sMessage), "Invalid key pressure detected, Style has been set to normal.");

            return Plugin_Continue;
        }
    }
    
    switch (sStyle)
    {
        case StyleSideways, StyleHSW:
        {
            buttons &= ~IN_MOVERIGHT;
            buttons &= ~IN_MOVELEFT;

            // Workaround
            if (buttons) {}
            
            vel[1] = 0.0;

            FormatEx(sMessage, sizeof(sMessage), "Invalid key pressure detected, Y-Velocity has been set to 0.");
        }
        case StyleBackwards:
        {
            vel[0] = 0.0;
            vel[1] = 0.0;
            vel[2] = 0.0;

            FormatEx(sMessage, sizeof(sMessage), "Invalid key pressure detected, Velocity has been reset.");
        }
    }

    if (Core.MessageInterval.IntValue > 0 && (Player[client].LastMessage < 1 || GetTime() > Player[client].LastMessage + Core.MessageInterval.IntValue))
    {
        PrintToChat(client, sMessage);
        Player[client].LastMessage = GetTime();
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
    
    return 0;
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

    if (sSetting[0] == 'S' && sSetting[2] == 'y')
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
    SetPlayerSetting(client, sSetting, sValue);
    
    return 0;
}

public any Native_GetClientStatus(Handle plugin, int numParams)
{
    return Player[GetNativeCell(1)].Status;
}

public any Native_GetClientStyle(Handle plugin, int numParams)
{
    char sBuffer[12];
    Player[GetNativeCell(1)].Settings.GetString(SETTING_STYLE, sBuffer, sizeof(sBuffer));
    return view_as<Styles>(StringToInt(sBuffer));
}

void LoadPlayer(int client)
{
    if (!client || !IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client))
    {
        return;
    }

    Player[client].Reset();

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Player/Id/%d", GetSteamAccountID(client));
    fuckTimer_NewAPIHTTPRequest(sEndpoint).Get(GetPlayerData, GetClientUserId(client));
}

void UpdatePlayer(int client, bool reset = false)
{
    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Player/Id/%d", GetSteamAccountID(client));

    JSONObject jPlayer = new JSONObject();
    
    char sBuffer[MAX_NAME_LENGTH];
    GetClientName(client, sBuffer, sizeof(sBuffer));
    jPlayer.SetString("Name", sBuffer);

    GetClientIP(client, sBuffer, sizeof(sBuffer));
    jPlayer.SetString("LastIP", sBuffer);

    jPlayer.SetInt("Status", view_as<int>(Player[client].Status));
    
    LogStackTrace("Status set to %d (%d)", Player[client].Status, jPlayer.GetInt("Status"));

    fuckTimer_NewAPIHTTPRequest(sEndpoint).Put(jPlayer, UpdatePlayerData);

    if (reset)
    {
        Player[client].Reset();
    }
}
