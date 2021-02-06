#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ripext>
#include <fuckTimer_stocks>
#include <fuckTimer_core>

char g_sBase[MAX_URL_LENGTH];
char g_sKey[MAX_URL_LENGTH];

HTTPClient g_hClient = null;

enum struct PlayerData
{
    bool IsActive;

    void Reset()
    {
        this.IsActive = false;
    }
}

PlayerData Player[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "Players",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public void OnPluginStart()
{
    if (!fuckTimer_GetBaseURL(g_sBase, sizeof(g_sBase)))
    {
        SetFailState("[Players.OnPluginStart] Can't receive base url.");
        return;
    }

    if (!fuckTimer_GetAPIKey(g_sKey, sizeof(g_sKey)))
    {
        SetFailState("[Players.OnPluginStart] Can't receive api key.");
        return;
    }

    g_hClient = new HTTPClient(g_sBase);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            OnClientPutInServer(i);
        }
    }
}

public void OnMapStart()
{
    if (!fuckTimer_GetBaseURL(g_sBase, sizeof(g_sBase)))
    {
        SetFailState("[Players.OnMapStart] Can't receive base url.");
        return;
    }

    if (!fuckTimer_GetAPIKey(g_sKey, sizeof(g_sKey)))
    {
        SetFailState("[Players.OnMapStart] Can't receive api key.");
        return;
    }
}

public void OnClientPutInServer(int client)
{
    if (!IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client))
    {
        return;
    }

    Player[client].Reset();

    LogMessage("%N - SteamAccountID: %d", client, GetSteamAccountID(client));

    CheckHTTPClient();

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Player/%d", GetSteamAccountID(client));
    
    g_hClient.Get(sEndpoint, GetPlayerData, GetClientUserId(client));
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

        LogError("[Players.GetPlayerData] Something went wrong. Status Code: %d, Error: %d", response.Status, error);
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
    CheckHTTPClient();

    char sName[MAX_NAME_LENGTH];
    GetClientName(client, sName, sizeof(sName));

    JSONObject jPlayer = new JSONObject();
    jPlayer.SetInt("Id", GetSteamAccountID(client));
    jPlayer.SetString("Name", sName);
    jPlayer.SetBool("IsActive", true);

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Player");

    g_hClient.Post(sEndpoint, jPlayer, PostPlayerData, GetClientUserId(client));
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

void CheckHTTPClient()
{
    if (g_hClient == null)
    {
        g_hClient = new HTTPClient(g_sBase);

        char sBuffer[128];
        FormatEx(sBuffer, sizeof(sBuffer), "Bearer %s", g_sKey);

        g_hClient.SetHeader("Authorization", sBuffer);
    }
}
