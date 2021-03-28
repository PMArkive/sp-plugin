#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckTimer_stocks>
#include <fuckTimer_api>

enum struct PluginData
{
    HTTPClient HTTPClient;

    GlobalForward OnAPIReady;

    ConVar APIUrl;
    ConVar APIKey;
}
PluginData Core;

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
    Core.OnAPIReady = new GlobalForward("fuckTimer_OnAPIReady", ET_Ignore);

    CreateNative("fuckTimer_GetHTTPClient", Native_GetHTTPClient);

    RegPluginLibrary("fuckTimer_api");

    return APLRes_Success;
}

public void OnPluginStart()
{
    fuckTimer_StartConfig("api");
    Core.APIUrl = AutoExecConfig_CreateConVar("api_url", "", "API URL to the REST API. (example: https://api.domain.tld or https://domain.tld/api - Without ending (back)slash!)");
    Core.APIKey = AutoExecConfig_CreateConVar("api_key", "", "Your API Key to get access to the REST API. Key must be at least 12 chars length.");
    fuckTimer_EndConfig();
}

public void OnConfigsExecuted()
{
    if (Core.HTTPClient == null)
    {
        char sAPI[MAX_URL_LENGTH];

        Core.APIUrl.GetString(sAPI, sizeof(sAPI));

        if (strlen(sAPI) < 2)
        {
            SetFailState("[API.OnConfigsExecuted] Can't receive api url.");
            return;
        }

        Core.HTTPClient = new HTTPClient(sAPI);

        char sKey[MAX_URL_LENGTH];
        Core.APIKey.GetString(sKey, sizeof(sKey));

        if (strlen(sKey) < 2)
        {
            SetFailState("[API.OnConfigsExecuted] Can't receive api key.");
            return;
        }

        char sBuffer[128];

        FormatEx(sBuffer, sizeof(sBuffer), "Bearer %s", sKey);
        Core.HTTPClient.SetHeader("Authorization", sBuffer);

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
        Core.HTTPClient.SetHeader("User-Agent", sUserAgent);
    }

    Call_StartForward(Core.OnAPIReady);
    Call_Finish();
}

public any Native_GetHTTPClient(Handle plugin, int numParams)
{
    return Core.HTTPClient;
}
