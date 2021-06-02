#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckTimer_stocks>
#include <fuckTimer_api>
#include <fuckTimer_timer>

enum struct PluginData
{
    HTTPClient HTTPClient;
}
PluginData Core;

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "Records",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public void fuckTimer_OnAPIReady()
{
    Core.HTTPClient = fuckTimer_GetHTTPClient();
}

public void fuckTimer_OnClientTimerEnd(int client, StringMap temp)
{
    StringMap record = view_as<StringMap>(CloneHandle(temp));

    any aDetails;
    IntMap imDetails;

    record.GetValue("Details", aDetails);

    if (aDetails != 0)
    {
        imDetails = view_as<IntMap>(CloneHandle(aDetails));
        delete imDetails;
    }

    delete record;
}
