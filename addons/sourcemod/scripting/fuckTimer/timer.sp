#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ripext>
#include <fuckTimer_stocks>
#include <fuckTimer_zones>

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "Timer",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public void fuckTimer_OnEnteringZone(int client, int zone, const char[] name, bool start, bool end, int stage, int checkpoint)
{
    PrintToChat(client, "fuckTimer_OnEnteringZone, Zone: %s (%d), Start: %d, End: %d, Stage: %d, Checkpoint: %d", name, zone, start, end, stage, checkpoint);
}

public void fuckTimer_OnLeavingZone(int client, int zone, const char[] name, bool start, bool end, int stage, int checkpoint)
{
    PrintToChat(client, "fuckTimer_OnLeavingZone, Zone: %s (%d), Start: %d, End: %d, Stage: %d, Checkpoint: %d", name, zone, start, end, stage, checkpoint);
}
