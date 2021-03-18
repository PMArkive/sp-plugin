#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <fuckZones>
#include <fuckTimer_stocks>
#include <fuckTimer_core>
#include <fuckTimer_timer>
#include <fuckTimer_zones>
#include <fuckTimer_styles>
#include <fuckTimer_commands>

#define MAX_DOT -0.75
#define LOW_GRAV 0.5

enum struct PlayerData
{
    bool IsActive;
    bool InStage;

    Styles Style;

    void Reset()
    {
        this.IsActive = false;
        this.InStage = false;

        this.Style = view_as<Styles>(0);
    }
}
PlayerData Player[MAXPLAYERS + 1];

enum struct PluginData
{
    Cookie PlayerStyle;
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

    RegPluginLibrary("fuckTimer_players");

    return APLRes_Success;
}

public void OnPluginStart()
{
    Core.PlayerStyle = new Cookie("fuckTimer_player_style", "Cookie for the current/last used player style", CookieAccess_Private);

    HookEvent("player_spawn", Event_PlayerSpawn);

    fuckTimer_LoopClients(client, true, true)
    {
        if (!AreClientCookiesCached(client))
        {
            continue;
        }

        OnClientCookiesCached(client);
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

void OnClientCookiesCached(int client)
{
    char sBuffer[12];
    Core.PlayerStyle.Get(client, sBuffer, sizeof(sBuffer));

    Player[client].Style = view_as<Styles>(StringToInt(sBuffer));

    if (Player[client].Style < StyleNormal)
    {
        SetClientStyle(client, StyleNormal);
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

    if (AreClientCookiesCached(client))
    {
        OnClientCookiesCached(client);
    }

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

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    RequestFrame(Frame_PlayerSpawn, event.GetInt("userid"));
}

public void Frame_PlayerSpawn(int userid)
{
    int client = GetClientOfUserId(userid);

    if (fuckTimer_IsClientValid(client, true, false))
    {
        if (AreClientCookiesCached(client) && GetClientStyle(client) < StyleNormal)
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
        if (Player[client].Style == StyleSideways)
        {
            if (buttons & IN_MOVERIGHT || buttons & IN_MOVELEFT)
            {
                buttons &= ~IN_MOVERIGHT;
                buttons &= ~IN_MOVELEFT;

                vel[1] = 0.0;

                return Plugin_Changed;
            }
        }
        else if (Player[client].Style == StyleHSW)
        {
            if (!(buttons & IN_FORWARD) && !(buttons & IN_BACK) && (buttons & IN_MOVERIGHT || buttons & IN_MOVELEFT))
            {
                buttons &= ~IN_MOVERIGHT;
                buttons &= ~IN_MOVELEFT;

                vel[1] = 0.0;
                
                return Plugin_Changed;
            }
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
                vel[0] = 0.0;
                vel[1] = 0.0;
                vel[2] = 0.0;
                
                return Plugin_Changed;
            }
        }
        else if (Player[client].Style == StyleLowGravity)
        {
            if (GetEntityGravity(client) != LOW_GRAV)
            {
                SetEntityGravity(client, LOW_GRAV);
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

    char sBuffer[12];
    IntToString(view_as<int>(style), sBuffer, sizeof(sBuffer));
    Core.PlayerStyle.Set(client, sBuffer);
}

public any Native_GetClientStyle(Handle plugin, int numParams)
{
    return GetClientStyle(GetNativeCell(1));

}
public any Native_SetClientStyle(Handle plugin, int numParams)
{
    SetClientStyle(GetNativeCell(1), view_as<Styles>(GetNativeCell(2)));
}
