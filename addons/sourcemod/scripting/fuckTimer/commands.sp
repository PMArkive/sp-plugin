#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <ripext>
#include <fuckZones>
#include <fuckTimer_stocks>
#include <fuckTimer_timer>
#include <fuckTimer_zones>

GlobalForward g_fwOnClientRestart = null;
GlobalForward g_fwOnClientTeleport = null;

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
    g_fwOnClientTeleport = new GlobalForward("fuckTimer_OnClientTeleport", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);

    CreateNative("fuckTimer_RestartClient", Native_RestartClient);

    RegPluginLibrary("fuckTimer_commands");

    return APLRes_Success;
}

public void OnPluginStart()
{
    RegConsoleCmd("sm_start", Command_Start);

    RegConsoleCmd("sm_stop", Command_Stop);

    RegConsoleCmd("sm_end", Command_End);

    RegConsoleCmd("sm_r", Command_Restart);
    RegConsoleCmd("sm_restart", Command_Restart);

    RegConsoleCmd("sm_goback", Command_GoBack);

    RegConsoleCmd("sm_rs", Command_RestartStage);
    RegConsoleCmd("sm_restartstage", Command_RestartStage);
    RegConsoleCmd("sm_teleport", Command_RestartStage);

    RegConsoleCmd("sm_b", Command_Bonus);
    RegConsoleCmd("sm_bonus", Command_Bonus);

    RegConsoleCmd("sm_s", Command_Stage);
    RegConsoleCmd("sm_stage", Command_Stage);
}

public Action Command_Start(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    fuckTimer_ResetClientTimer(client);

    int iZone = fuckTimer_GetStartZone();

    if (iZone > 0)
    {
        ClientTeleport(client, ZoneStart, 0);

        fuckZones_TeleportClientToZoneIndex(client, iZone);
    }

    return Plugin_Handled;
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
        ClientTeleport(client, ZoneEnd, 0);

        fuckZones_TeleportClientToZoneIndex(client, iZone);
    }

    return Plugin_Handled;
}

public Action Command_Restart(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    ClientRestart(client);

    ClientTeleport(client, ZoneStart, 0);

    return Plugin_Handled;
}

public Action Command_GoBack(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    int iZone = 0;

    int iStage = fuckTimer_GetClientStage(client);
    int iBonus = fuckTimer_GetClientBonus(client);

    fuckTimer_ResetClientTimer(client);

    PrintToChat(client, "Stage: %d, Bonus: %d", iStage, iBonus);

    if (iStage > 1)
    {
        iStage--;

        iZone = fuckTimer_GetStageZone(iStage);

        ClientTeleport(client, ZoneStage, iStage);
    }
    else if (iBonus > 0)
    {
        iBonus--;

        if (iBonus == 0)
        {
            iBonus = 1;
        }

        iZone = fuckTimer_GetBonusZone(iBonus);

        ClientTeleport(client, ZoneBonus, iBonus);
    }
    else
    {
        iZone = fuckTimer_GetStartZone();

        ClientTeleport(client, ZoneStart, 0);
    }

    if (iZone > 0)
    {
        fuckZones_TeleportClientToZoneIndex(client, iZone);
    }

    return Plugin_Handled;
}

public Action Command_RestartStage(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    int iZone = 0;

    int iStage = fuckTimer_GetClientStage(client);
    int iBonus = fuckTimer_GetClientBonus(client);

    fuckTimer_ResetClientTimer(client);

    if (iStage > 1)
    {
        iZone = fuckTimer_GetStageZone(iStage);

        ClientTeleport(client, ZoneStage, iStage);
    }
    else if (iBonus > 0)
    {
        iZone = fuckTimer_GetBonusZone(iBonus);

        ClientTeleport(client, ZoneBonus, iBonus);
    }
    else
    {
        iZone = fuckTimer_GetStartZone();

        ClientTeleport(client, ZoneStart, 0);
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

    int iZone = 0;
    int iBonus = fuckTimer_GetClientBonus(client);

    fuckTimer_ResetClientTimer(client);

    if (args == 0)
    {
        if (iBonus < 2)
        {
            iZone = fuckTimer_GetBonusZone(1);

            ClientTeleport(client, ZoneBonus, 1);
        }
        else
        {
            iZone = fuckTimer_GetBonusZone(iBonus);

            ClientTeleport(client, ZoneStage, iBonus);
        }
    }
    else
    {
        char sBuffer[12];
        GetCmdArgString(sBuffer, sizeof(sBuffer));

        int iTemp = 0;
        
        if (IsStringNumeric(sBuffer))
        {
            iTemp = StringToInt(sBuffer);
        }

        if (iTemp)
        {
            iZone = fuckTimer_GetBonusZone(iTemp);

            ClientTeleport(client, ZoneBonus, iTemp);
        }
        
        if (iZone  < 1)
        {
            iZone = fuckTimer_GetBonusZone(1);

            ClientTeleport(client, ZoneBonus, 1);
        }
    }

    if (iZone > 0)
    {
        fuckZones_TeleportClientToZoneIndex(client, iZone);
    }

    return Plugin_Handled;
}

public Action Command_Stage(int client, int args)
{
    if (fuckTimer_GetAmountOfStages() < 1)
    {
        return Plugin_Handled;
    }

    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    int iZone = 0;
    int iStage = fuckTimer_GetClientStage(client);

    fuckTimer_ResetClientTimer(client);

    if (args == 0)
    {
        if (iStage < 2)
        {
            iZone = fuckTimer_GetStageZone(1);

            ClientTeleport(client, ZoneStage, 1);
        }
        else
        {
            iZone = fuckTimer_GetStageZone(iStage);

            ClientTeleport(client, ZoneStage, iStage);
        }
    }
    else
    {
        char sBuffer[12];
        GetCmdArgString(sBuffer, sizeof(sBuffer));

        int iTemp = 0;
        
        if (IsStringNumeric(sBuffer))
        {
            iTemp = StringToInt(sBuffer);
        }

        if (iTemp)
        {
            iZone = fuckTimer_GetStageZone(iTemp);

            ClientTeleport(client, ZoneStage, iTemp);
        }
        
        if (iZone  < 1)
        {
            iZone = fuckTimer_GetStageZone(1);

            ClientTeleport(client, ZoneStage, 1);
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

void ClientTeleport(int client, eZone type, int level)
{
    Call_StartForward(g_fwOnClientTeleport);
    Call_PushCell(client);
    Call_PushCell(type);
    Call_PushCell(level);
    Call_Finish();
}
