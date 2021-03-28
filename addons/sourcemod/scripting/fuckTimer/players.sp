#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <fuckZones>
#include <fuckTimer_stocks>
#include <fuckTimer_api>
#include <fuckTimer_timer>
#include <fuckTimer_zones>
#include <fuckTimer_players>
#include <fuckTimer_styles>
#include <fuckTimer_commands>

#define MAX_DOT -0.75
#define LOW_GRAV 0.5
#define SLOW_MOTION 0.5
#define SETTING_STYLE "Style"
#define SETTING_INVALIDKEYPREF "InvalidKeyPref"

enum struct PlayerData
{
    bool IsActive;
    bool InStage;

    Styles Style;

    eInvalidKeyPref InvalidKeyPref;

    void Reset()
    {
        this.IsActive = false;
        this.InStage = false;

        this.Style = view_as<Styles>(0);

        this.InvalidKeyPref = view_as<eInvalidKeyPref>(0);
    }
}
PlayerData Player[MAXPLAYERS + 1];

enum struct PluginData
{
    HTTPClient HTTPClient;
}
PluginData Core;

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
    CreateNative("fuckTimer_GetClientStyle", Native_GetClientStyle);
    CreateNative("fuckTimer_SetClientStyle", Native_SetClientStyle);

    CreateNative("fuckTimer_GetClientInvalidKeyPref", Native_GetClientInvalidKeyPref);
    CreateNative("fuckTimer_SetClientInvalidKeyPref", Native_SetClientInvalidKeyPref);

    RegPluginLibrary("fuckTimer_players");

    return APLRes_Success;
}

public void OnPluginStart()
{
    HookEvent("player_spawn", Event_PlayerSpawn);

    bool bSkip = true;

    if (fuckTimer_GetHTTPClient() != null)
    {
        Core.HTTPClient = fuckTimer_GetHTTPClient();
        bSkip = false;
    }

    if (!bSkip)
    {
        fuckTimer_LoopClients(client, true, true)
        {
            OnClientPutInServer(client);
        }
    }
}

public void fuckTimer_OnAPIReady()
{
    Core.HTTPClient = fuckTimer_GetHTTPClient();

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            OnClientPutInServer(i);
        }
    }
}

public void fuckTimer_OnClientRestart(int client)
{
    int iZone = fuckTimer_GetStartZone();

    if (iZone > 0)
    {
        fuckZones_TeleportClientToZoneIndex(client, iZone);
    }
}

public void OnClientPutInServer(int client)
{
    if (!IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client))
    {
        return;
    }

    Player[client].Reset();

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Player/%d", GetSteamAccountID(client));

    if (Core.HTTPClient == null)
    {
        Core.HTTPClient = fuckTimer_GetHTTPClient();
    }

    Core.HTTPClient.Get(sEndpoint, GetPlayerData, GetClientUserId(client));
}

public void GetPlayerData(HTTPResponse response, int userid, const char[] error)
{
    int client = GetClientOfUserId(userid);

    if (client < 1)
    {
        LogError("[Players.GetPlayerData] Client is no longer valid.");
        return;
    }

    if (response.Status != HTTPStatus_OK)
    {
        if (response.Status == HTTPStatus_NotFound)
        {
            LogMessage("[Players.GetPlayerData] 404 Player Not Found, we'll add this player.");
            PreparePlayerPostData(client);
            return;
        }

        LogError("[Players.GetPlayerData] Something went wrong. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    JSONObject jPlayer = view_as<JSONObject>(response.Data);

    char sName[MAX_NAME_LENGTH];
    jPlayer.GetString("Name", sName, sizeof(sName));

    Player[client].IsActive = jPlayer.GetBool("IsActive");

    LogMessage("[Players.GetPlayerData] Player Found. Name: %s, Active: %d", sName, Player[client].IsActive);

    LoadPlayerSetting(client, "Style");
    LoadPlayerSetting(client, "InvalidKeyPref");
}

void PreparePlayerPostData(int client)
{
    char sName[MAX_NAME_LENGTH];
    GetClientName(client, sName, sizeof(sName));

    JSONObject jPlayer = new JSONObject();
    jPlayer.SetInt("Id", GetSteamAccountID(client));
    jPlayer.SetString("Name", sName);
    jPlayer.SetBool("IsActive", true);

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Player");

    Core.HTTPClient.Post(sEndpoint, jPlayer, PostPlayerData, GetClientUserId(client));
    delete jPlayer;
}

public void PostPlayerData(HTTPResponse response, int userid, const char[] error)
{
    int client = GetClientOfUserId(userid);

    if (client < 1)
    {
        LogError("[Players.PostPlayerData] Client is no longer valid.");
        return;
    }

    if (response.Status != HTTPStatus_Created)
    {
        LogError("[Players.PostPlayerData] Can't post player data. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    LogMessage("[Players.PostPlayerData] Success. Status Code: %d", response.Status);

    OnClientPutInServer(client);
}

void LoadPlayerSetting(int client, const char[] setting)
{
    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "PlayerSettings/PlayerId/%d/Setting/%s", GetSteamAccountID(client), setting);

    PrintToServer(sEndpoint);

    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    pack.WriteString(setting);

    Core.HTTPClient.Get(sEndpoint, GetPlayerSetting, pack);
}

public void GetPlayerSetting(HTTPResponse response, DataPack pack, const char[] error)
{
    pack.Reset();

    int client = GetClientOfUserId(pack.ReadCell());

    char sSetting[MAX_SETTING_LENGTH];
    pack.ReadString(sSetting, sizeof(sSetting));

    delete pack;

    if (client < 1)
    {
        LogError("[Players.GetPlayerSetting] Client is no longer valid.");
        return;
    }

    if (response.Status != HTTPStatus_OK)
    {
        if (response.Status == HTTPStatus_NotFound)
        {
            LogMessage("[Players.GetPlayerSetting] 404 Setting \"%s\" Not Found, we'll add it.", sSetting);
            PreparePlayerPostSetting(client, sSetting);
            return;
        }

        LogError("[Players.GetPlayerSetting] Something went wrong. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    JSONObject jSetting = view_as<JSONObject>(response.Data);

    char sValue[MAX_SETTING_VALUE_LENGTH];
    jSetting.GetString("Value", sValue, sizeof(sValue));

    delete jSetting;
    
    if (StrEqual(sSetting, "Style", false))
    {
        Player[client].Style = view_as<Styles>(StringToInt(sValue));
    }
    else if (StrEqual(sSetting, "InvalidKeyPref", false))
    {
        Player[client].InvalidKeyPref = view_as<eInvalidKeyPref>(StringToInt(sValue));
    }
}

void PreparePlayerPostSetting(int client, const char[] setting)
{
    JSONObject jSetting = new JSONObject();
    jSetting.SetInt("PlayerId", GetSteamAccountID(client));
    jSetting.SetString("Setting", setting);

    char sBuffer[MAX_SETTING_VALUE_LENGTH];

    if (StrEqual(setting, "Style", false))
    {
        IntToString(view_as<int>(StyleNormal), sBuffer, sizeof(sBuffer));
        jSetting.SetString("Value", sBuffer);
    }
    else if (StrEqual(setting, "InvalidKeyPref", false))
    {
        IntToString(view_as<int>(IKStop), sBuffer, sizeof(sBuffer));
        jSetting.SetString("Value", sBuffer);
    }

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "PlayerSettings");

    Core.HTTPClient.Post(sEndpoint, jSetting, PostPlayerSetting, GetClientUserId(client));

    delete jSetting;
}

public void PostPlayerSetting(HTTPResponse response, int userid, const char[] error)
{
    int client = GetClientOfUserId(userid);

    if (client < 1)
    {
        LogError("[Players.PostPlayerSetting] Client is no longer valid.");
        return;
    }

    if (response.Status != HTTPStatus_Created)
    {
        LogError("[Players.PostPlayerSetting] Can't post player setting. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    JSONObject jSetting = view_as<JSONObject>(response.Data);

    char sSetting[MAX_SETTING_LENGTH], sValue[MAX_SETTING_VALUE_LENGTH];
    jSetting.GetString("Setting", sSetting, sizeof(sSetting));
    jSetting.GetString("Value", sValue, sizeof(sValue));

    delete jSetting;
    
    if (StrEqual(sSetting, "Style", false))
    {
        Player[client].Style = view_as<Styles>(StringToInt(sValue));
    }
    else if (StrEqual(sSetting, "InvalidKeyPref", false))
    {
        Player[client].InvalidKeyPref = view_as<eInvalidKeyPref>(StringToInt(sValue));
    }

    LogMessage("[Players.PostPlayerSetting] Success for setting \"%s\". Status Code: %d", sSetting, response.Status);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    RequestFrame(Frame_PlayerSpawn, event.GetInt("userid"));
}

public void Frame_PlayerSpawn(int userid)
{
    int client = GetClientOfUserId(userid);

    if (fuckTimer_IsClientValid(client, true, false))
    {
        if (GetClientStyle(client) < StyleNormal)
        {
            SetClientStyle(client, StyleNormal);
        }

        int iZone = fuckTimer_GetStartZone();

        if (iZone > 0)
        {
            fuckZones_TeleportClientToZoneIndex(client, iZone);
        }
    }
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    if (IsPlayerAlive(client) && fuckTimer_IsClientTimeRunning(client) && !Player[client].InStage)
    {
        if (Player[client].Style == StyleSideways && (buttons & IN_MOVERIGHT || buttons & IN_MOVELEFT))
        {
            return OnInvalidKeyPressure(client, vel, buttons);
        }
        else if (Player[client].Style == StyleHSW && (!(buttons & IN_FORWARD) && !(buttons & IN_BACK) && (buttons & IN_MOVERIGHT || buttons & IN_MOVELEFT)))
        {
            return OnInvalidKeyPressure(client, vel, buttons);
        }
        else if (Player[client].Style == StyleBackwards)
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
        else if (Player[client].Style == StyleLowGravity)
        {
            if (GetEntityGravity(client) != LOW_GRAV)
            {
                SetEntityGravity(client, LOW_GRAV);
            }
        }
        else if (Player[client].Style == StyleSlowMotion)
        {
            if (GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue") != SLOW_MOTION)
            {
                SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", SLOW_MOTION);
            }
        }
    }

    return Plugin_Continue;
}

public void fuckTimer_OnTouchZone(int client, int zone, const char[] name, bool start, bool misc, bool end, int stage, int checkpoint, int bonus)
{
    if (!misc && stage > 0)
    {
        Player[client].InStage = true;
    }
}

public void fuckTimer_OnLeavingZone(int client, int zone, const char[] name, bool start, bool misc, bool end, int stage, int checkpoint, int bonus)
{
    if (!misc && stage > 0)
    {
        Player[client].InStage = false;
    }
}

Styles GetClientStyle(int client)
{
    return Player[client].Style;
}

Styles SetClientStyle(int client, Styles style)
{
    Player[client].Style = style;

    if (style != StyleLowGravity)
    {
        SetEntityGravity(client, 1.0);
    }
    
    if (style != StyleSlowMotion)
    {
        SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
    }

    char sBuffer[12];
    IntToString(view_as<int>(style), sBuffer, sizeof(sBuffer));
    // #warning Add RESTapi call
}

eInvalidKeyPref GetClientInvalidKeyPref(int client)
{
    return Player[client].InvalidKeyPref;
}

eInvalidKeyPref SetClientInvalidKeyPref(int client, eInvalidKeyPref preference)
{
    Player[client].InvalidKeyPref = preference;

    char sBuffer[12];
    IntToString(view_as<int>(eInvalidKeyPref), sBuffer, sizeof(sBuffer));
    // #warning Add RESTapi call
}

Action OnInvalidKeyPressure(int client, float vel[3], int buttons)
{
    eInvalidKeyPref preference = GetClientInvalidKeyPref(client);

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
        SetClientStyle(client, StyleNormal);
        return Plugin_Continue;
    }
    
    if (Player[client].Style == StyleSideways || Player[client].Style == StyleHSW)
    {
        buttons &= ~IN_MOVERIGHT;
        buttons &= ~IN_MOVELEFT;
        
        vel[1] = 0.0;
    }
    else if (Player[client].Style == StyleBackwards)
    {
        vel[0] = 0.0;
        vel[1] = 0.0;
        vel[2] = 0.0;
    }

    return Plugin_Changed;
}

public any Native_GetClientStyle(Handle plugin, int numParams)
{
    return GetClientStyle(GetNativeCell(1));

}
public any Native_SetClientStyle(Handle plugin, int numParams)
{
    SetClientStyle(GetNativeCell(1), view_as<Styles>(GetNativeCell(2)));
}

public any Native_GetClientInvalidKeyPref(Handle plugin, int numParams)
{
    return GetClientInvalidKeyPref(GetNativeCell(1));

}
public any Native_SetClientInvalidKeyPref(Handle plugin, int numParams)
{
    SetClientInvalidKeyPref(GetNativeCell(1), view_as<eInvalidKeyPref>(GetNativeCell(2)));
}
