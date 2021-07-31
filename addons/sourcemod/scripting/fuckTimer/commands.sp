#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckZones>
#include <fuckTimer_stocks>
#include <fuckTimer_maps>
#include <fuckTimer_zones>
#include <fuckTimer_players>

enum struct PlayerData
{
    bool Side;
    int Line;
    eHUDKeys Key;

    void Reset()
    {
        this.Side = false;
        this.Line = -1;
        this.Key = HKNone;
    }
}
PlayerData Player[MAXPLAYERS + 1];

enum struct PluginData
{
    GlobalForward OnClientRestart;
    GlobalForward OnClientTeleport;

    Handle Plugin;
}
PluginData Core;

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
    Core.Plugin = myself;
    
    Core.OnClientRestart = new GlobalForward("fuckTimer_OnClientRestart", ET_Ignore, Param_Cell);
    Core.OnClientTeleport = new GlobalForward("fuckTimer_OnClientTeleport", ET_Ignore, Param_Cell, Param_Cell);

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
    RegConsoleCmd("sm_back", Command_RestartStage);
    RegConsoleCmd("sm_restartstage", Command_RestartStage);

    RegConsoleCmd("sm_teleport", Command_RestartStage); // Checkpoints?

    RegConsoleCmd("sm_b", Command_Bonus);
    RegConsoleCmd("sm_bonus", Command_Bonus);

    RegConsoleCmd("sm_s", Command_Stage);
    RegConsoleCmd("sm_stage", Command_Stage);

    RegConsoleCmd("sm_style", Command_Styles);
    RegConsoleCmd("sm_styles", Command_Styles);

    RegConsoleCmd("sm_invalidkey", Command_InvalidKeyPref);

    RegConsoleCmd("sm_tier", Command_Tier);

    RegConsoleCmd("sm_hud", Command_HUD, "List all HUD related commands as menu");
    RegConsoleCmd("sm_hudmove", Command_HUDMove, "Move/Swap keys to another positions");
    RegConsoleCmd("sm_hudenable", Command_HUDEnable, "Enable/Disable the HUD entirely");
    RegConsoleCmd("sm_hudpreset", Command_HUDPreset, "Replace HUD with a predefined preset");
    RegConsoleCmd("sm_hudseparator", Command_HUDSeparator, "Replace tabs against vertical bars or vice versa");
    RegConsoleCmd("sm_hudscale", Command_HUDScale, "Change the HUD font size");
    RegConsoleCmd("sm_hudlength", Command_HUDLength, "Adjust the HUD with incorrect formatting");
    RegConsoleCmd("sm_hudspeedunit", Command_HUDShowSpeedUnit, "Show 'u/s' behind speed or not");
    RegConsoleCmd("sm_hudspeed", Command_HUDSpeed, "Change the hud speed calculation based of different axis");
    RegConsoleCmd("sm_hudtime", Command_HUDTime, "Show times in different formats");
    RegConsoleCmd("sm_hud0hours", Command_HUDShow0Hours, "Shows the leading 0(0): in time or not");
}

public Action Command_Start(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    fuckTimer_ResetClientTimer(client);

    int iZone = fuckTimer_GetStartZone(fuckTimer_GetClientBonus(client));

    if (iZone > 0)
    {
        ClientTeleport(client, 0);

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

    int iZone = fuckTimer_GetEndZone(fuckTimer_GetClientBonus(client));

    if (iZone > 0)
    {
        ClientTeleport(client, 0);

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

    ClientTeleport(client, 0);

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

    PrintToChat(client, "Before - Stage: %d, Bonus: %d", iStage, iBonus);

    if (iBonus > 0)
    {
        iBonus--;

        if (iBonus == 0)
        {
            iBonus = 1;
        }
    }

    PrintToChat(client, "After - Stage: %d, Bonus: %d", iStage, iBonus);

    if (iStage > 1)
    {
        iStage--;

        iZone = fuckTimer_GetStageZone(iBonus, iStage);

        ClientTeleport(client, iStage);
    }
    else
    {
        iZone = fuckTimer_GetStartZone(iBonus);

        ClientTeleport(client, 0);
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
        iZone = fuckTimer_GetStageZone(iBonus, iStage);

        ClientTeleport(client, iStage);
    }
    else if (iBonus > 0)
    {
        iZone = fuckTimer_GetStartZone(iBonus);

        ClientTeleport(client, 0);
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
            iZone = fuckTimer_GetStartZone(1);

            ClientTeleport(client, 1);
        }
        else
        {
            iZone = fuckTimer_GetStartZone(iBonus);

            ClientTeleport(client, iBonus);
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
            iZone = fuckTimer_GetStartZone(iTemp);

            ClientTeleport(client, iTemp);
        }
        
        if (iZone  < 1)
        {
            iZone = fuckTimer_GetStartZone(1);

            ClientTeleport(client, 1);
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

    if (args == 1)
    {
        int iZone = 0;

        fuckTimer_ResetClientTimer(client);

        char sStage[12];
        GetCmdArg(1, sStage, sizeof(sStage));

        int iBonus = fuckTimer_GetClientBonus(client);
        int iStage = 0;

        if (IsStringNumeric(sStage))
        {
            iStage = StringToInt(sStage);
        }

        iZone = fuckTimer_GetStageZone(iBonus, iStage);
        
        if (iZone == -1)
        {
            iZone = fuckTimer_GetStageZone(0, 1);

            ClientTeleport(client, 1);
        }

        if (iZone > 0)
        {
            fuckZones_TeleportClientToZoneIndex(client, iZone);
        }
    }

    return Plugin_Handled;
}

public Action Command_Styles(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    IntMap imStyles = fuckTimer_GetStyles();

    if (imStyles.Size < 2)
    {
        ReplyToCommand(client, "No styles found.");
        return Plugin_Handled;
    }

    // TODO: Add translations
    Menu menu = new Menu(Menu_Styles);
    menu.SetTitle("Select style:");

    Style style;
    char sBuffer[8];
    for (int i = 1; i <= imStyles.Size; i++)
    {
        imStyles.GetArray(i, style, sizeof(style));
        IntToString(style.Id, sBuffer, sizeof(sBuffer));
        menu.AddItem(sBuffer, style.Name);
    }

    menu.ExitBackButton = false;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public int Menu_Styles(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[12];
        if (menu.GetItem(param, sParam, sizeof(sParam)))
        {
            Styles style = view_as<Styles>(StringToInt(sParam));

            char sStyle[MAX_STYLE_NAME_LENGTH];
            fuckTimer_GetStyleName(style, sStyle, sizeof(sStyle));
            PrintToChat(client, "Set style to %s (Id: %d)", sStyle, style);

            fuckTimer_SetClientSetting(client, "Style", sParam);
            ClientRestart(client);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public Action Command_InvalidKeyPref(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    // TODO: Add translations
    Menu menu = new Menu(Menu_InvalidKeyPref);
    menu.SetTitle("Select invalid key preference:");

    char sSetting[MAX_SETTING_VALUE_LENGTH];
    fuckTimer_GetClientSetting(client, "InvalidKeyPref", sSetting);
    eInvalidKeyPref preference = view_as<eInvalidKeyPref>(StringToInt(sSetting));

    char sBuffer[32];
    Format(sBuffer, sizeof(sBuffer), "[%s] Block Keys", preference == IKBlock ? "X" : " ");
    menu.AddItem("0", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "[%s] Stop Timer", preference == IKStop ? "X" : " ");
    menu.AddItem("1", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "[%s] Teleport to Start Zone", preference == IKRestart ? "X" : " ");
    menu.AddItem("2", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "[%s] Set style to normal", preference == IKNormal ? "X" : " ");
    menu.AddItem("3", sBuffer);

    menu.ExitBackButton = false;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public int Menu_InvalidKeyPref(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[12];
        if (menu.GetItem(param, sParam, sizeof(sParam)))
        {
            fuckTimer_GetClientSetting(client, "InvalidKeyPref", sParam);
            
            if (fuckTimer_IsClientTimeRunning(client))
            {
                ClientRestart(client);
            }

            Command_InvalidKeyPref(client, 0);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public Action Command_Tier(int client, int args)
{
    char sBuffer[MAX_NAME_LENGTH];
    GetCmdArgString(sBuffer, sizeof(sBuffer));

    fuckTimer_GetMapTiers(client, sBuffer, OnMapTiers);
}

public void OnMapTiers(int client, StringMap tiers)
{
    StringMapSnapshot snap = tiers.Snapshot();

    if (client == 0)
    {
        PrintToServer("Found %d Maps.", snap.Length);
    }
    else
    {
        PrintToChat(client, "Found %d Maps", snap.Length);
    }

    char sName[MAX_NAME_LENGTH];
    int iTier = 0;

    for (int i = 0; i < snap.Length; i++)
    {
        snap.GetKey(i, sName, sizeof(sName));
        tiers.GetValue(sName, iTier);

        if (client == 0)
        {
            PrintToServer("Map: %s, Tier: %d", sName, iTier);
        }
        else
        {
            PrintToChat(client, "Map: %s, Tier: %d", sName, iTier);
        }

        sName[0] = '\0';
        iTier = 0;
    }

    delete snap;
    delete tiers;
}

public Action Command_HUD(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    Menu menu = new Menu(Menu_ListHUDCommands);
    menu.SetTitle("Select command to see how to use it:\n ");

    CommandIterator iterator = new CommandIterator();

    char sCommand[32], sDescription[64], sText[101];
    while (iterator.Next())
    {
        if (iterator.Plugin != Core.Plugin)
        {
            continue;
        }

        iterator.GetName(sCommand, sizeof(sCommand));

        if (StrContains(sCommand, "sm_hud", false) != -1)
        {
            iterator.GetDescription(sDescription, sizeof(sDescription));

            FormatEx(sText, sizeof(sText), "%s\n%s", sCommand, sDescription);
            menu.AddItem(sCommand, sText);
        }
    }

    delete iterator;

    menu.ExitBackButton = false;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public int Menu_ListHUDCommands(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[12];
        if (menu.GetItem(param, sParam, sizeof(sParam)))
        {
            PrintToChat(client, "Read commands.sp, I placed a TODO note here."); // TODO: Add usage text as translation (as example: "Chat - CommandUsage - sm_hud", so "Chat - CommandUsage - %s", sParam)
            ClientCommand(client, sParam);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public Action Command_HUDMove(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    Menu menu = new Menu(Menu_ListHUDKeys);
    menu.SetTitle("Select hud element, which you want to move/swap:");

    char sNumber[12], sDisplay[64];

    IntToString(HKSpeed, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "Speed");
    menu.AddItem(sNumber, sDisplay);

    IntToString(HKTime, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "Time");
    menu.AddItem(sNumber, sDisplay);

    IntToString(HKStageTime, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "StageTime");
    menu.AddItem(sNumber, sDisplay);

    IntToString(HKTimeInZone, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "TimeInZone");
    menu.AddItem(sNumber, sDisplay);

    IntToString(HKAttempts, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "Attempts");
    menu.AddItem(sNumber, sDisplay);

    IntToString(HKPersonalRecord, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "PersonalRecord");
    menu.AddItem(sNumber, sDisplay);

    IntToString(HKServerRecord, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "ServerRecord");
    menu.AddItem(sNumber, sDisplay);

    IntToString(HKTier, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "Tier");
    menu.AddItem(sNumber, sDisplay);

    IntToString(HKZone, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "Zone");
    menu.AddItem(sNumber, sDisplay);

    IntToString(HKMap, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "Map");
    menu.AddItem(sNumber, sDisplay);

    IntToString(HKMapType, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "MapType");
    menu.AddItem(sNumber, sDisplay);

    IntToString(HKStyle, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "Style");
    menu.AddItem(sNumber, sDisplay);

    IntToString(HKCurrentStage, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "CurrentStage");
    menu.AddItem(sNumber, sDisplay);

    IntToString(HKValidator, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "Validator");
    menu.AddItem(sNumber, sDisplay);

    menu.ExitBackButton = false;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public int Menu_ListHUDKeys(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[12];

        if (menu.GetItem(param, sParam, sizeof(sParam)))
        {
            Player[client].Key = view_as<eHUDKeys>(StringToInt(sParam));

            ListHUDSides(client);
        }
    }
    else if (action == MenuAction_Cancel)
    {
        if (param == MenuCancel_Exit)
        {
            Player[client].Reset();
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

void ListHUDSides(int client)
{
    Menu menu = new Menu(Menu_ListHUDSides);
    menu.SetTitle("Select on which side:");
    menu.AddItem("0", "Left");
    menu.AddItem("1", "Right");
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_ListHUDSides(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[4];
        if (menu.GetItem(param, sParam, sizeof(sParam)))
        {
            Player[client].Side = view_as<bool>(StringToInt(sParam));

            ListHUDLines(client);
        }
    }
    else if (action == MenuAction_Cancel)
    {
        if (param == MenuCancel_Exit)
        {
            Player[client].Reset();
        }
        else if (param == MenuCancel_ExitBack)
        {
            Player[client].Reset();
            Command_HUDMove(client, 0);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

void ListHUDLines(int client)
{
    Menu menu = new Menu(Menu_ListHUDLines);
    menu.SetTitle("Select to which line:");
    
    char sLine[4], sDisplay[12];
    for (int i = 0; i <= MAX_HUD_LINES; i++)
    {
        IntToString(i, sLine, sizeof(sLine));
        FormatEx(sDisplay, sizeof(sDisplay), "%d", i+1);
        menu.AddItem(sLine, sDisplay);
    }

    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_ListHUDLines(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[4];
        if (menu.GetItem(param, sParam, sizeof(sParam)))
        {
            Player[client].Line = StringToInt(sParam);

            HUDMoveOrSwap(client);
        }
    }
    else if (action == MenuAction_Cancel)
    {
        if (param == MenuCancel_Exit)
        {
            Player[client].Reset();
        }
        else if (param == MenuCancel_ExitBack)
        {
            Player[client].Side = false;

            ListHUDSides(client);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

void HUDMoveOrSwap(int client)
{
    Menu menu = new Menu(HUDMenu_MoveOrSwap);
    menu.SetTitle("Do you want to move or swap this element?");
    menu.AddItem("0", "Move\nThis will override your exist element.");
    menu.AddItem("1", "Swap\nThis will swap your exist element to the old position.");
    menu.ExitBackButton = true;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int HUDMenu_MoveOrSwap(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[4];
        if (menu.GetItem(param, sParam, sizeof(sParam)))
        {
            bool swapPosition = view_as<bool>(StringToInt(sParam));

            fuckTimer_MoveClientHUDKey(client, Player[client].Key, Player[client].Side, Player[client].Line, swapPosition);

            Player[client].Reset();
        }
    }
    else if (action == MenuAction_Cancel)
    {
        if (param == MenuCancel_Exit)
        {
            Player[client].Reset();
        }
        else if (param == MenuCancel_ExitBack)
        {
            Player[client].Line = -1;

            ListHUDSides(client);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public Action Command_HUDEnable(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    char sSetting[MAX_SETTING_VALUE_LENGTH];
    fuckTimer_GetClientSetting(client, "HUD", sSetting);
    bool status = view_as<bool>(StringToInt(sSetting));

    status = !status;

    IntToString(view_as<int>(status), sSetting, sizeof(sSetting));
    fuckTimer_SetClientSetting(client, "HUD", sSetting);

    ReplyToCommand(client, "HUD %s", status ? "enabled" : "disabled");

    return Plugin_Handled;
}

public Action Command_HUDPreset(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    // TODO: Add translations
    Menu menu = new Menu(Menu_HUDPreset);
    menu.SetTitle("Select HUD Preset:");

    char sBuffer[32];
    Format(sBuffer, sizeof(sBuffer), "Default");
    menu.AddItem("default", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "KSF Style");
    menu.AddItem("ksf", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "SurfHeaven Style");
    menu.AddItem("sh", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "Horizon Servers Style");
    menu.AddItem("horizon", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "GoFree Style");
    menu.AddItem("gofree", sBuffer);

    menu.ExitBackButton = false;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public int Menu_HUDPreset(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[12];
        if (menu.GetItem(param, sParam, sizeof(sParam)))
        {
            if (StrEqual(sParam, "default", false))
            {
                fuckTimer_SetClientHUDLayout(client, sParam);

                char sBuffer[MAX_SETTING_VALUE_LENGTH];
                IntToString(view_as<int>(HUD_DEFAULT_SEPARATOR), sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDSeparator", sBuffer);

                fuckTimer_SetClientSetting(client, "HUDScale", HUD_DEFAULT_FONTSIZE);

                IntToString(HUD_DEFAULT_STRING_LENGTH, sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDLength", sBuffer);
            }
            else if (StrEqual(sParam, "ksf", false))
            {
                fuckTimer_SetClientHUDLayout(client, sParam);

                char sBuffer[MAX_SETTING_VALUE_LENGTH];
                IntToString(view_as<int>(HUD_KSF_SEPARATOR), sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDSeparator", sBuffer);

                fuckTimer_SetClientSetting(client, "HUDScale", HUD_KSF_FONTSIZE);

                IntToString(HUD_KSF_STRING_LENGTH, sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDLength", sBuffer);
            }
            else if (StrEqual(sParam, "sh", false))
            {
                fuckTimer_SetClientHUDLayout(client, sParam);

                char sBuffer[MAX_SETTING_VALUE_LENGTH];
                IntToString(view_as<int>(HUD_SH_SEPARATOR), sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDSeparator", sBuffer);

                fuckTimer_SetClientSetting(client, "HUDScale", HUD_SH_FONTSIZE);

                IntToString(HUD_SH_STRING_LENGTH, sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDLength", sBuffer);
            }
            else if (StrEqual(sParam, "horizon", false))
            {
                fuckTimer_SetClientHUDLayout(client, sParam);

                char sBuffer[MAX_SETTING_VALUE_LENGTH];
                IntToString(view_as<int>(HUD_HORIZON_SEPARATOR), sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDSeparator", sBuffer);

                fuckTimer_SetClientSetting(client, "HUDScale", HUD_HORIZON_FONTSIZE);

                IntToString(HUD_HORIZON_STRING_LENGTH, sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDLength", sBuffer);
            }
            else if (StrEqual(sParam, "gofree", false))
            {
                fuckTimer_SetClientHUDLayout(client, sParam);

                char sBuffer[MAX_SETTING_VALUE_LENGTH];
                IntToString(view_as<int>(HUD_GOFREE_SEPARATOR), sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDSeparator", sBuffer);

                fuckTimer_SetClientSetting(client, "HUDScale", HUD_GOFREE_FONTSIZE);

                IntToString(HUD_GOFREE_STRING_LENGTH, sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDLength", sBuffer);
            }

            Command_HUDPreset(client, 0);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public Action Command_HUDSeparator(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    // TODO: Add translations
    Menu menu = new Menu(Menu_HUDSeparator);
    menu.SetTitle("Select HUD Separator:");

    char sSetting[MAX_SETTING_VALUE_LENGTH];
    fuckTimer_GetClientSetting(client, "HUDSeparator", sSetting);
    eHUDSeparator iSeparator = view_as<eHUDSeparator>(StringToInt(sSetting));

    char sBuffer[32];
    Format(sBuffer, sizeof(sBuffer), "[%s] Tabs", iSeparator == HSTabs ? "X" : " ");
    menu.AddItem("0", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "[%s] Vertical Bar", iSeparator == HSBar ? "X" : " ");
    menu.AddItem("1", sBuffer);

    menu.ExitBackButton = false;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public int Menu_HUDSeparator(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[12];
        if (menu.GetItem(param, sParam, sizeof(sParam)))
        {
            fuckTimer_SetClientSetting(client, "HUDSeparator", sParam);
            
            if (fuckTimer_IsClientTimeRunning(client))
            {
                ClientRestart(client);
            }

            Command_HUDSeparator(client, 0);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public Action Command_HUDLength(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    if (args != 1)
    {
        char sScale[8], sLength[MAX_SETTING_VALUE_LENGTH];
        fuckTimer_GetClientSetting(client, "HUDLength", sLength);
        fuckTimer_GetClientSetting(client, "HUDScale", sScale);

        ReplyToCommand(client, "Usage: sm_hudlength <Number>");
        ReplyToCommand(client, "Current value '%s' with hud scale '%s'", sLength, sScale);
        ReplyToCommand(client, "Recommended values:");
        ReplyToCommand(client, "13 for HUD Scale SM");
        ReplyToCommand(client, "17 for HUD Scale M");

        return Plugin_Handled;
    }

    char sBuffer[8];
    GetCmdArg(1, sBuffer, sizeof(sBuffer));
    int iLength = StringToInt(sBuffer);

    if (iLength < 1 || iLength > 32)
    {
        ReplyToCommand(client, "Invalid hud length. It must be between 1 and 32.");

        return Plugin_Handled;
    }

    fuckTimer_SetClientSetting(client, "HUDLength", sBuffer);
    ReplyToCommand(client, "Set HUD Length to %d", iLength);

    return Plugin_Handled;
}

public Action Command_HUDScale(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    // TODO: Add translations
    Menu menu = new Menu(Menu_HUDScale);
    menu.SetTitle("Select HUD Scale:");

    char sScale[8], sBuffer[32];
    fuckTimer_GetClientSetting(client, "HUDScale", sScale);

    // Source: https://forums.alliedmods.net/showpost.php?p=2604171&postcount=8
    Format(sBuffer, sizeof(sBuffer), "[%s] XS (8 Pixel)", StrEqual(sScale, "xs", false) ? "X" : " ");
    menu.AddItem("xs", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "[%s] S (12 Pixel)", StrEqual(sScale, "s", false) ? "X" : " ");
    menu.AddItem("s", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "[%s] SM (16 Pixel)", StrEqual(sScale, "sm", false) ? "X" : " ");
    menu.AddItem("sm", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "[%s] M (18 Pixel)", StrEqual(sScale, "m", false) ? "X" : " ");
    menu.AddItem("m", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "[%s] L (24 Pixel)", StrEqual(sScale, "l", false) ? "X" : " ");
    menu.AddItem("l", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "[%s] XL (32 Pixel)", StrEqual(sScale, "xl", false) ? "X" : " ");
    menu.AddItem("xl", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "[%s] XXL (40 Pixel)", StrEqual(sScale, "xxl", false) ? "X" : " ");
    menu.AddItem("xxl", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "[%s] XXXL (64 Pixel)", StrEqual(sScale, "xxxl", false) ? "X" : " ");
    menu.AddItem("xxxl", sBuffer);

    menu.ExitBackButton = false;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public int Menu_HUDScale(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[12];
        if (menu.GetItem(param, sParam, sizeof(sParam)))
        {
            fuckTimer_SetClientSetting(client, "HUDScale", sParam);

            Command_HUDScale(client, 0);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public Action Command_HUDShowSpeedUnit(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    char sSetting[MAX_SETTING_VALUE_LENGTH];
    fuckTimer_GetClientSetting(client, "HUDShowSpeedUnit", sSetting);
    bool status = view_as<bool>(StringToInt(sSetting));

    status = !status;

    IntToString(view_as<int>(status), sSetting, sizeof(sSetting));
    fuckTimer_SetClientSetting(client, "HUDShowSpeedUnit", sSetting);

    ReplyToCommand(client, "Speed unit (u/s) %s", status ? "enabled" : "disabled");

    return Plugin_Handled;
}

public Action Command_HUDSpeed(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    // TODO: Add translations
    Menu menu = new Menu(Menu_HUDSpeed);
    menu.SetTitle("Select axis for calculating the speed:");

    char sSetting[MAX_SETTING_VALUE_LENGTH];
    fuckTimer_GetClientSetting(client, "HUDSpeed", sSetting);
    eHUDSpeed iSpeed = view_as<eHUDSpeed>(StringToInt(sSetting));

    char sBuffer[32];
    Format(sBuffer, sizeof(sBuffer), "[%s] XY (Default)", iSpeed == HSXY ? "X" : " ");
    menu.AddItem("0", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "[%s] XYZ", iSpeed == HSXYZ ? "X" : " ");
    menu.AddItem("1", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "[%s] Z", iSpeed == HSZ ? "X" : " ");
    menu.AddItem("2", sBuffer);

    menu.ExitBackButton = false;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public Action Command_HUDTime(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    char sSetting[MAX_SETTING_VALUE_LENGTH];
    fuckTimer_GetClientSetting(client, "HUDTime", sSetting);

    // This will replaced by menu, if we've more than 3 options
    bool format = view_as<bool>(StringToInt(sSetting));
    format = !format;

    IntToString(view_as<int>(format), sSetting, sizeof(sSetting));
    fuckTimer_SetClientSetting(client, "HUDTime", sSetting);

    ReplyToCommand(client, "Time will shown %s", format ? "full" : "minimal");

    return Plugin_Handled;
}

public Action Command_HUDShow0Hours(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    char sSetting[MAX_SETTING_VALUE_LENGTH];
    fuckTimer_GetClientSetting(client, "HUDShowTime0Hours", sSetting);

    bool format = view_as<bool>(StringToInt(sSetting));
    format = !format;

    IntToString(view_as<int>(format), sSetting, sizeof(sSetting));
    fuckTimer_SetClientSetting(client, "HUDShowTime0Hours", sSetting);

    ReplyToCommand(client, "0 Hours %s", format ? "enabled" : "disabled");

    return Plugin_Handled;
}

public int Menu_HUDSpeed(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[12];
        if (menu.GetItem(param, sParam, sizeof(sParam)))
        {
            fuckTimer_SetClientSetting(client, "HUDSpeed", sParam);
            
            if (fuckTimer_IsClientTimeRunning(client))
            {
                ClientRestart(client);
            }

            Command_HUDSpeed(client, 0);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
}

public int Native_RestartClient(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    ClientRestart(client);
}

void ClientRestart(int client)
{
    Call_StartForward(Core.OnClientRestart);
    Call_PushCell(client);
    Call_Finish();
}

void ClientTeleport(int client, int level)
{
    Call_StartForward(Core.OnClientTeleport);
    Call_PushCell(client);
    Call_PushCell(level);
    Call_Finish();
}
