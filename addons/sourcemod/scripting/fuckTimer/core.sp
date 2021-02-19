#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckTimer_stocks>

ConVar g_cBaseURL = null;
ConVar g_cAPIKey = null;

char g_sUserAgent[128];

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
    CreateNative("fuckTimer_GetBaseURL", Native_GetBaseURL);
    CreateNative("fuckTimer_GetAPIKey", Native_GetAPIKey);
    CreateNative("fuckTimer_GetUserAgent", Native_GetUserAgent);
    
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

    FormatEx(g_sUserAgent, sizeof(g_sUserAgent), "MetaMod/%s SourceMod/%s RIPExt/FeelsBadMan fuckTimer/%s", sMetaMod, sSourceMod, FUCKTIMER_PLUGIN_VERSION);
}

public int Native_GetBaseURL(Handle plugin, int numParams)
{
    int iLength = GetNativeCell(2);
    char[] sURL = new char[iLength];

    g_cBaseURL.GetString(sURL, iLength);

    if (strlen(sURL) > MIN_BASE_URL_LENGTH)
    {
        int iCode = SetNativeString(1, sURL, iLength);

        return (iCode == SP_ERROR_NONE);
    }
    return false;
}

public int Native_GetAPIKey(Handle plugin, int numParams)
{
    int iLength = GetNativeCell(2);
    char[] sKey = new char[iLength];

    g_cAPIKey.GetString(sKey, iLength);

    if (strlen(sKey) > MIN_API_KEY_LENGTH)
    {
        int iCode = SetNativeString(1, sKey, iLength);

        return (iCode == SP_ERROR_NONE);
    }
    return false;
}

public int Native_GetUserAgent(Handle plugin, int numParams)
{
    int iLength = GetNativeCell(2);
    char[] sUserAgent = new char[iLength];

    strcopy(sUserAgent, iLength, g_sUserAgent);

    if (strlen(sUserAgent) > 1)
    {
        int iCode = SetNativeString(1, sUserAgent, iLength);

        return (iCode == SP_ERROR_NONE);
    }
    return false;
}
