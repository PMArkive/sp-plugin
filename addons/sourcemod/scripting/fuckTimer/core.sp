#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckTimer_stocks>
#include <fuckTimer_core>

ConVar g_cBaseURL = null;
ConVar g_cAPIKey = null;

HTTPClient g_httpClient = null;

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "Core",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("fuckTimer_GetHTTPClient", Native_GetHTTPClient);
    RegPluginLibrary("fuckTimer_core");

    return APLRes_Success;
}

public void OnPluginStart()
{
    fuckTimer_StartConfig("core");
    g_cBaseURL = AutoExecConfig_CreateConVar("core_base_url", "", "Base URL to the REST API. (example: https://api.domain.tld or https://domain.tld/api - Without ending (back)slash!)");
    g_cAPIKey = AutoExecConfig_CreateConVar("core_api_key", "", "Your API Key to get access to the REST API. Key must be at least 12 chars length.");
    fuckTimer_EndConfig();
}

public void OnConfigsExecuted()
{
    if (g_httpClient == null)
    {
        char sBase[MAX_URL_LENGTH];

        g_cBaseURL.GetString(sBase, sizeof(sBase));

        if (strlen(sBase) < 2)
        {
            SetFailState("[Core.OnConfigsExecuted] Can't receive base url.");
            return;
        }

        g_httpClient = new HTTPClient(sBase);

        char sKey[MAX_URL_LENGTH];
        g_cAPIKey.GetString(sKey, sizeof(sKey));

        if (strlen(sKey) < 2)
        {
            SetFailState("[Core.OnConfigsExecuted] Can't receive api key.");
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
}

public any Native_GetHTTPClient(Handle plugin, int numParams)
{
    return g_httpClient;
}
