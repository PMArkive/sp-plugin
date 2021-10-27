#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckTimer_stocks>
#include <fuckTimer_api>

enum struct PluginData
{
    ConVar APIUrl;
    ConVar APIKey;
    ConVar MetaModVersion;
    ConVar SourceModVersion;
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
    CreateNative("fuckTimer_GetAPIUrl", Native_GetAPIUrl);
    CreateNative("fuckTimer_NewHTTPRequest", Native_NewHTTPRequest);

    RegPluginLibrary("fuckTimer_api");

    return APLRes_Success;
}

public void OnPluginStart()
{
    fuckTimer_StartConfig("api");
    Core.APIUrl = AutoExecConfig_CreateConVar("api_url", "", "API URL to the REST API. (example: https://api.domain.tld or https://domain.tld/api - Without ending (back)slash!)", FCVAR_PROTECTED);
    Core.APIKey = AutoExecConfig_CreateConVar("api_key", "", "Your API Key to get access to the REST API. Key must be at least 12 chars length.", FCVAR_PROTECTED);
    fuckTimer_EndConfig();
}

public void OnConfigsExecuted()
{
    Core.MetaModVersion = FindConVar("metamod_version");
    Core.SourceModVersion = FindConVar("sourcemod_version");
}

public int Native_GetAPIUrl(Handle plugin, int numParams)
{
    char sUrl[MAX_URL_LENGTH];
    Core.APIUrl.GetString(sUrl, sizeof(sUrl));
    return SetNativeString(1, sUrl, sizeof(sUrl));
}

public any Native_NewHTTPRequest(Handle plugin, int numParams)
{
    char[] sUrl = new char[GetNativeCell(2)];
    GetNativeString(1, sUrl, GetNativeCell(2));

    HTTPRequest request = new HTTPRequest(sUrl);

    char sKey[MAX_URL_LENGTH];
    Core.APIKey.GetString(sKey, sizeof(sKey));

    if (strlen(sKey) < 2)
    {
        SetFailState("[API.Native_NewHTTPRequest] Can not receive API Key.");
        return 0;
    }

    char sBuffer[128];
    FormatEx(sBuffer, sizeof(sBuffer), "Bearer %s", sKey);
    request.SetHeader("Authorization", sBuffer);

    char sMetaMod[12];
    Core.MetaModVersion.GetString(sMetaMod, sizeof(sMetaMod));

    char sSourceMod[24];
    Core.SourceModVersion.GetString(sSourceMod, sizeof(sSourceMod));

    char sUserAgent[128];
    FormatEx(sUserAgent, sizeof(sUserAgent), "MetaMod/%s SourceMod/%s RIPExt/FeelsBadMan fuckTimer/%s", sMetaMod, sSourceMod, FUCKTIMER_PLUGIN_VERSION);
    request.SetHeader("User-Agent", sUserAgent);

    return request;
}
