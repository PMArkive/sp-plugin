#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <intmap>
#include <ripext>
#include <fuckTimer_stocks>
#include <fuckTimer_core>
#include <fuckTimer_styles>

HTTPClient g_httpClient = null;

IntMap g_imStyles = null;

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "Styles",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("fuckTimer_styles");

    return APLRes_Success;
}

public void fuckTimer_OnAPIReady()
{
    g_httpClient = fuckTimer_GetHTTPClient();

    LoadStyles();
}

void LoadStyles()
{
    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Style");

    g_httpClient.Get(sEndpoint, GetAllStyles);
}

public void GetAllStyles(HTTPResponse response, any value, const char[] error)
{
    if (response.Status != HTTPStatus_OK)
    {
        SetFailState("[Styles.GetAllStyles] Something went wrong. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    JSONArray jsonArray = view_as<JSONArray>(response.Data);

    if (jsonArray.Length < 1)
    {
        SetFailState("[Styles.GetAllStyles] We didn't found any styles...");
        return;
    }

    g_imStyles = new IntMap();

    JSONObject jsonObject = null;
    Style style;

    for (int i = 0; i < jsonArray.Length; i++)
    {
        jsonObject = view_as<JSONObject>(jsonArray.Get(i));

        style.Id = jsonObject.GetInt("Id");
        jsonObject.GetString("Name", style.Name, sizeof(Style::Name));
        style.IsActive = jsonObject.GetBool("IsActive");

        LogMessage("[Styles.GetAllStyles] Style: %s (Id: %d, IsActive: %d)", style.Name, style.Id, style.IsActive);

        g_imStyles.SetArray(style.Id, style, sizeof(style));

        delete jsonObject;
    }
    
    delete jsonArray;
}
