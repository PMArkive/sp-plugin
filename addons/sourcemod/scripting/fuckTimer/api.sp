#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckTimer_stocks>
#include <fuckTimer_api>

ConVar g_cUrl = null;
ConVar g_cKey = null;

HTTPClient g_httpClient = null;

GlobalForward g_fwOnAPIReady = null;

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "API",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_fwOnAPIReady = new GlobalForward("fuckTimer_OnAPIReady", ET_Ignore);

    CreateNative("fuckTimer_GetHTTPClient", Native_GetHTTPClient);

    RegPluginLibrary("fuckTimer_api");

    return APLRes_Success;
}

public void OnPluginStart()
{
    fuckTimer_StartConfig("api");
    g_cUrl = AutoExecConfig_CreateConVar("api_url", "", "API URL to the REST API. (example: https://api.domain.tld or https://domain.tld/api - Without ending (back)slash!)");
    g_cKey = AutoExecConfig_CreateConVar("api_key", "", "Your API Key to get access to the REST API. Key must be at least 12 chars length.");
    fuckTimer_EndConfig();
}

public void OnConfigsExecuted()
{
    if (g_httpClient == null)
    {
        char sAPI[MAX_URL_LENGTH];

        g_cUrl.GetString(sAPI, sizeof(sAPI));

        if (strlen(sAPI) < 2)
        {
            SetFailState("[API.OnConfigsExecuted] Can't receive api url.");
            return;
        }

        g_httpClient = new HTTPClient(sAPI);

        char sKey[MAX_URL_LENGTH];
        g_cKey.GetString(sKey, sizeof(sKey));

        if (strlen(sKey) < 2)
        {
            SetFailState("[API.OnConfigsExecuted] Can't receive api key.");
            return;
        }

        char sBuffer[128];

        FormatEx(sBuffer, sizeof(sBuffer), "Bearer %s", sKey);
        g_httpClient.SetHeader("Authorization", sBuffer);

        char sMetaMod[12], sSourceMod[24];
        ConVar cBuffer = FindConVar("metamod_version");

        if (cBuffer != null)
        {
            cBuffer.GetString(sMetaMod, sizeof(sMetaMod));
        }

        cBuffer = FindConVar("sourcemod_version");

        if (cBuffer != null)
        {
            cBuffer.GetString(sSourceMod, sizeof(sSourceMod));
        }

        char sUserAgent[128];
        FormatEx(sUserAgent, sizeof(sUserAgent), "MetaMod/%s SourceMod/%s RIPExt/FeelsBadMan fuckTimer/%s", sMetaMod, sSourceMod, FUCKTIMER_PLUGIN_VERSION);
        g_httpClient.SetHeader("User-Agent", sUserAgent);
    }

    Call_StartForward(g_fwOnAPIReady);
    Call_Finish();
}

public any Native_GetHTTPClient(Handle plugin, int numParams)
{
    return g_httpClient;
}
