#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fT_stocks>

ConVar g_cBaseURL = null;
ConVar g_cAPIKey = null;

public Plugin myinfo =
{
    name = fT_PLUGIN_NAME ... "Core",
    author = fT_PLUGIN_AUTHOR,
    description = fT_PLUGIN_DESCRIPTION,
    version = fT_PLUGIN_VERSION,
    url = fT_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("fT_GetBaseURL", Native_GetBaseURL);
    CreateNative("fT_GetAPIKey", Native_GetAPIKey);
    
    RegPluginLibrary("fT_core");

    return APLRes_Success;
}

public void OnPluginStart()
{
    fT_StartConfig("core");
    g_cBaseURL = AutoExecConfig_CreateConVar("core_base_url", "", "Base URL to the REST API. (example: https://api.domain.tld or https://domain.tld/api - Without ending (back)slash!)");
    g_cAPIKey = AutoExecConfig_CreateConVar("core_api_key", "", "Your API Key to get access to the REST API. Key must be at least 12 chars length.");
    fT_EndConfig();
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
