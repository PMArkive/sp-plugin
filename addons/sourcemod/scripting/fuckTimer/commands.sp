#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ripext>
#include <fuckZones>
#include <fuckTimer_stocks>
#include <fuckTimer_timer>
#include <fuckTimer_zones>

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

    CreateNative("fuckTimer_RestartClient", Native_RestartClient);

    RegPluginLibrary("fuckTimer_commands");

    return APLRes_Success;
}

public void OnPluginStart()
{
    RegConsoleCmd("sm_stop", Command_Stop);

    RegConsoleCmd("sm_r", Command_Restart);
    RegConsoleCmd("sm_restart", Command_Restart);

    RegConsoleCmd("sm_end", Command_End);

    RegConsoleCmd("sm_teleport", Command_Teleport);

    RegConsoleCmd("sm_b", Command_Bonus);
    RegConsoleCmd("sm_bonus", Command_Bonus);
}

public Action Command_Stop(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    fuckTimer_ResetClientTimer(client);

    return Plugin_Handled;
}

public Action Command_Restart(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    ClientRestart(client);

    return Plugin_Handled;
}

public Action Command_End(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    fuckTimer_ResetClientTimer(client);

    int iZone = fuckTimer_GetEndZone();

    if (iZone > 0)
    {
        fuckZones_TeleportClientToZoneIndex(client, iZone);
    }

    return Plugin_Handled;
}

public Action Command_Teleport(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    fuckTimer_ResetClientTimer(client);

    int iZone = 0;

    int iStage = fuckTimer_GetClientStage(client);
    int iBonus = fuckTimer_GetClientBonus(client);

    if (iStage > 1)
    {
        iZone = fuckTimer_GetStageZone(iStage);
    }
    else if (iBonus > 0)
    {
        iZone = fuckTimer_GetBonusZone(iBonus);
    }
    else
    {
        iZone = fuckTimer_GetStartZone();
    }

    if (iZone > 0)
    {
        fuckZones_TeleportClientToZoneIndex(client, iZone);
    }

    return Plugin_Handled;
}

public Action Command_Bonus(int client, int args)
{
    if (fuckTimer_GetAmountOfBonus() < 1)
    {
        return Plugin_Handled;
    }

    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    fuckTimer_ResetClientTimer(client);

    int iZone = 0;
    int iBonus = fuckTimer_GetClientBonus(client);

    if (args == 0)
    {
        if (iBonus < 2)
        {
            iZone = fuckTimer_GetBonusZone(1);
        }
        else
        {
            iZone = fuckTimer_GetBonusZone(iBonus);
        }
    }
    else
    {
        char sBuffer[12];
        GetCmdArg(1, sBuffer, sizeof(sBuffer));

        int iTemp = IsStringNumeric(sBuffer);

        if (iTemp)
        {
            iZone = fuckTimer_GetBonusZone(iTemp);
        }
        
        if (iZone  < 1)
        {
            iZone = fuckTimer_GetBonusZone(1);
        }
    }

    if (iZone > 0)
    {
        fuckZones_TeleportClientToZoneIndex(client, iZone);
    }

    return Plugin_Handled;
}

public int Native_RestartClient(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    ClientRestart(client);
}

void ClientRestart(int client)
{
    Call_StartForward(g_fwOnClientRestart);
    Call_PushCell(client);
    Call_Finish();
}
