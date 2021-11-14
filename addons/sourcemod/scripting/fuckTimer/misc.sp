#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <fuckTimer_stocks>

enum struct PluginData
{
    ConVar ChatPrefix;
    ConVar ItemCleanup;
    ConVar HideCommands;
}
PluginData Core;

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "Misc",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public void OnPluginStart()
{
    fuckTimer_StartConfig("misc");
    Core.ChatPrefix = AutoExecConfig_CreateConVar("misc_chat_prefix", "{orange}fuckTimer {lightblue}>", "Specify the chat prefix for each message in chat and console (Default: \"{orange}fuckTimer {lightblue}>\").");
    Core.ItemCleanup = AutoExecConfig_CreateConVar("misc_item_cleanup", "1", "Enable (1) or Disable (1) cleaning up of items and weapons?", _, true, 0.0, true, 1.0);
    Core.HideCommands = AutoExecConfig_CreateConVar("misc_hide_commands", "1", "Hide \"PublicChatTrigger\" (defined in \"configs/core.cfg\") commands?", _, true, 0.0, true, 1.0);
    fuckTimer_EndConfig();

    HookEvent("round_poststart", Event_RoundPostStart);
    HookEvent("player_death", Event_PlayerDeath);

    AddCommandListener(Command_Drop, "drop");
    AddCommandListener(Command_Say, "say");
    AddCommandListener(Command_Say, "say_team");
}

public void OnMapStart()
{
    // Workaround temporarily copied from SurfTimer
    // Maybe we find another more cleaner solution
    if (FileExists("cfg/" ... FUCKTIMER_CFG_FILENAME))
    {
        CreateTimer(1.0, Timer_Enforce);
    }
    else
    {
        SetFailState("\"cfg/" ... FUCKTIMER_CFG_FILENAME ... "\" not found.");
    }
}

public Action Timer_Enforce(Handle timer)
{
    ServerCommand("exec " ... FUCKTIMER_CFG_FILENAME);
    return Plugin_Continue;
}

public void Event_RoundPostStart(Event event, const char[] name, bool dontBroadcast)
{
    ItemCleanup();
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    ItemCleanup();
    RequestFrame(Frame_RespawnPlayer, event.GetInt("userid"));
}

public void Frame_RespawnPlayer(any userid)
{
    int client = GetClientOfUserId(userid);

    if (client)
    {
        CS_RespawnPlayer(client);
    }
}

void ItemCleanup()
{
    if (!Core.ItemCleanup.BoolValue)
    {
        return;
    }

    for (int iWeapon = MaxClients; iWeapon < MAX_ENTITIES; iWeapon++)
    {
        if (!sValidEntity(iWeapon))
        {
            continue;
        }

        char sClassname[32];
        GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));

        if (StrContains(sClassname, "weapon", false) != -1 || StrContains(sClassname, "item", false) != -1)
        {
            RemoveEntity(iWeapon);
        }
    }
}

public Action Command_Drop(int client, const char[] command, int args)
{
    if (!Core.ItemCleanup.BoolValue)
    {
        return Plugin_Continue;
    }

    if (client)
    {
        int iWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

        if (!sValidEntity(iWeapon))
        {
            continue;
        }

        char sClassname[32];
        GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));

        if (StrContains(sClassname, "weapon", false) != -1 || StrContains(sClassname, "item", false) != -1)
        {
            SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", -1);
            RemoveEntity(iWeapon);
        }
    }
    
    return Plugin_Continue;
}

public Action Command_Say(int client, const char[] command, int argc)
{
    if (!client)
    {
        return Plugin_Continue;
    }

    char sMessage[MAX_MESSAGE_LENGTH];
    GetCmdArgString(sMessage, sizeof(sMessage));

    TrimString(sMessage);
    StripQuotes(sMessage);

    if (sMessage[0] == '!')
    {
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

public Action CS_OnTerminateRound(float& delay, CSRoundEndReason& reason)
{
    int iTimeleft = GameRules_GetProp("m_iRoundTime");

    if (iTimeleft > 1)
    {
        return Plugin_Stop;
    }

    return Plugin_Continue;
}
