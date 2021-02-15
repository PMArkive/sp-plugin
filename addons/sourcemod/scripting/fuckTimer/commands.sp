#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ripext>
#include <fuckTimer_stocks>

GlobalForward g_fwOnClientRestart = null;

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "Commands",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_fwOnClientRestart = new GlobalForward("fuckTimer_OnClientRestart", ET_Ignore, Param_Cell);

    RegPluginLibrary("fuckTimer_commands");

    return APLRes_Success;
}

public void OnPluginStart()
{
    RegConsoleCmd("sm_r", Command_Restart);
    RegConsoleCmd("sm_restart", Command_Restart);
}

public Action Command_Restart(int client, int args)
{
    if (!client)
    {
        return Plugin_Handled;
    }

    Call_StartForward(g_fwOnClientRestart);
    Call_PushCell(client);
    Call_Finish();

    return Plugin_Handled;
}
