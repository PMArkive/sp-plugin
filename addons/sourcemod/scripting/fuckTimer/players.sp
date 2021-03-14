#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <fuckZones>
#include <fuckTimer_stocks>
#include <fuckTimer_core>
#include <fuckTimer_zones>
#include <fuckTimer_styles>
#include <fuckTimer_commands>

enum struct PlayerData
{
    bool IsActive;

    Styles Style;

    void Reset()
    {
        this.IsActive = false;
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
    CreateNative("fuckTimer_GetPlayerStyle", Native_GetPlayerStyle);
    CreateNative("fuckTimer_SetPlayerStyle", Native_SetPlayerStyle);

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
    Player[client].Style = GetPlayerStyle(client);

    if (Player[client].Style < StyleNormal)
    {
        SetPlayerStyle(client, StyleNormal);
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
        int iZone = fuckTimer_GetStartZone();

        if (iZone > 0)
        {
            fuckZones_TeleportClientToZoneIndex(client, iZone);
        }
    }
}

Styles GetPlayerStyle(int client)
{
    char sBuffer[12];
    Core.PlayerStyle.Get(client, sBuffer, sizeof(sBuffer));

    return view_as<Styles>(StringToInt(sBuffer));
}

Styles SetPlayerStyle(int client, Styles style)
{
    char sBuffer[6];
    Keyize(style, sBuffer);
    Core.PlayerStyle.Set(client, sBuffer);
}

void Keyize(any key, char buffer[6]) 
{
    buffer[0] = ((key >>> 28) & 0x7F) | 0x80; 
    buffer[1] = ((key >>> 21) & 0x7F) | 0x80; 
    buffer[2] = ((key >>> 14) & 0x7F) | 0x80; 
    buffer[3] = ((key >>> 7) & 0x7F) | 0x80;
    buffer[4] = (key & 0x7F) | 0x80;
    buffer[5] = 0x00;
}

public any Native_GetPlayerStyle(Handle plugin, int numParams)
{
    return GetPlayerStyle(GetNativeCell(1));

}
public any Native_SetPlayerStyle(Handle plugin, int numParams)
{
    SetPlayerStyle(GetNativeCell(1), view_as<Styles>(GetNativeCell(2)));
}
