#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckTimer_stocks>
#include <fuckTimer_api>

enum struct PluginData
{
    IntMap Styles;

    GlobalForward OnStylesLoaded;
}
PluginData Core;

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
    Core.OnStylesLoaded = new GlobalForward("fuckTimer_OnStylesLoaded", ET_Ignore);

    CreateNative("fuckTimer_GetStyles", Native_GetStyles);

    CreateNative("fuckTimer_GetStyleName", Native_GetStyleName);
    CreateNative("fuckTimer_GetStyleStatus", Native_GetStyleStatus);

    RegPluginLibrary("fuckTimer_styles");

    return APLRes_Success;
}

public void OnConfigsExecuted()
{
    LoadStyles();
}

void LoadStyles()
{
    fuckTimer_NewAPIHTTPRequest("Style").Get(GetAllStyles);
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

    delete Core.Styles;
    Core.Styles = new IntMap();

    JSONObject jsonObject = null;
    Style style;

    for (int i = 0; i < jsonArray.Length; i++)
    {
        jsonObject = view_as<JSONObject>(jsonArray.Get(i));

        style.Id = jsonObject.GetInt("Id");
        jsonObject.GetString("Name", style.Name, sizeof(Style::Name));
        style.Status = view_as<StyleStatus>(jsonObject.GetBool("Status"));

        Core.Styles.SetArray(style.Id, style, sizeof(style));

        delete jsonObject;
    }

    Call_StartForward(Core.OnStylesLoaded);
    Call_Finish();
}

public any Native_GetStyles(Handle plugin, int numParams)
{
    return Core.Styles;
}


public int Native_GetStyleName(Handle plugin, int numParams)
{
    int iStyle = GetNativeCell(1);
    int iLength = GetNativeCell(3);

    Style style;
    bool success = Core.Styles.GetArray(iStyle, style, sizeof(style));

    if (success && SetNativeString(2, style.Name, iLength) == SP_ERROR_NONE)
    {
        return true;
    }

    return false;
}

public any Native_GetStyleStatus(Handle plugin, int numParams)
{
    int iStyle = GetNativeCell(1);

    Style style;
    bool success = Core.Styles.GetArray(iStyle, style, sizeof(style));

    if (success)
    {
        return style.Status;
    }

    return ssInactive;
}
