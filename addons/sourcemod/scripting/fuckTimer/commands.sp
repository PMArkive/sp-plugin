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
    GlobalForward OnClientCommand;

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
    Core.OnClientCommand = new GlobalForward("fuckTimer_OnClientCommand", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);

    CreateNative("fuckTimer_RestartClient", Native_RestartClient);

    RegPluginLibrary("fuckTimer_commands");

    return APLRes_Success;
}

public void OnPluginStart()
{
    // sm_settings

    // Player commands
    RegConsoleCmd("sm_invalidkey", Command_InvalidKeyPref, "Choose your prefered option on invalid key input");

    // Timer Commands
    RegConsoleCmd("sm_main", Command_Main, "Teleports you to the main path");
    RegConsoleCmd("sm_start", Command_Start, "Teleports you to the start zone of the current path");
    RegConsoleCmd("sm_stop", Command_Stop, "Stops the timer");
    RegConsoleCmd("sm_end", Command_End, "Teleports you to the end zone of the current path, timer will be stopped(!)");
    RegConsoleCmd("sm_r", Command_Restart, "Same as sm_start, teleports you back to the start zone");
    RegConsoleCmd("sm_restart", Command_Restart, "Same as sm_start, teleports you back to the start zone");
    RegConsoleCmd("sm_goback", Command_GoBack, "Teleports you back to the previous stage/bonus or to the start zone");
    RegConsoleCmd("sm_rs", Command_RestartStage, "Teleports you back to the stage (start) zone");
    RegConsoleCmd("sm_back", Command_RestartStage, "Teleports you back to the stage (start) zone");
    RegConsoleCmd("sm_restartstage", Command_RestartStage, "Teleports you back to the stage (start) zone");
    RegConsoleCmd("sm_b", Command_Bonus, "Teleports you to the bonus start zone.");
    RegConsoleCmd("sm_bonus", Command_Bonus, "Teleports you to the bonus start zone.");
    RegConsoleCmd("sm_s", Command_Stage, "Teleports you to the stage zone.");
    RegConsoleCmd("sm_stage", Command_Stage, "Teleports you to the stage zone.");

    // Style(s) commands
    RegConsoleCmd("sm_style", Command_Styles, "Lists you all available styles, which you can switch to.");
    RegConsoleCmd("sm_styles", Command_Styles, "Lists you all available styles, which you can switch to.");

    // Map commands
    RegConsoleCmd("sm_tier", Command_Tier, "Prints list of all maps into your chat with tier.");

    // HUD commands
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
    RegConsoleCmd("sm_huddeadhud", Command_HUDDeadHud, "Shows as spectator the players hud in 1st- and 3rd person");
    RegConsoleCmd("sm_hudcomparelocation", Command_HUDCompareLocation, "Enable/Disable HUD Time/Speed comparison with position option");
    RegConsoleCmd("sm_hudcompareagainst", Command_HUDCompareAgainst, "Compare your time/speed against PR, SR or both (requires chat as location)");
    RegConsoleCmd("sm_hudcomparemode", Command_HUDCompareMode, "Show full time/speed or the difference of the record");
    RegConsoleCmd("sm_hudcomparetime", Command_HUDCompareTime, "How long the comparison should be shown in HUD");
    RegConsoleCmd("sm_hudcenterspeedposition", Command_HUDCenterSpeedPosition, "Specify the position of the X- and Y-Axis for the speed (center) hud");
    RegConsoleCmd("sm_hudcenterspeedcolor", Command_HUDCenterSpeedColor, "Specify the color of the X- and Y-Axis for the speed (center) hud");
}

public void OnConfigsExecuted()
{
    ConVar cChatMessage = FindConVar("misc_chat_prefix");

    char sPrefix[48];
    cChatMessage.GetString(sPrefix, sizeof(sPrefix));
    CSetPrefix(sPrefix);

    cChatMessage.AddChangeHook(OnCVarChange);
}

public void OnCVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    CSetPrefix(newValue);
}

public Action Command_Main(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    fuckTimer_ResetClientTimer(client);

    int iZone = fuckTimer_GetStartZone(0);

    if (iZone > 0)
    {
        CallOnClientCommand(client, 0, true);
        fuckTimer_TeleportEntityToZone(client, iZone);
    }

    return Plugin_Handled;
}

public Action Command_Start(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    fuckTimer_ResetClientTimer(client);

    int iBonus = fuckTimer_GetClientBonus(client);
    int iZone = fuckTimer_GetStartZone(iBonus);

    CReplyToCommand(client, "Bonus: %d", iBonus);

    if (iZone > 0)
    {
        CallOnClientCommand(client, 0, true);
        fuckTimer_TeleportEntityToZone(client, iZone);
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

    int iBonus = fuckTimer_GetClientBonus(client);
    int iZone = fuckTimer_GetEndZone(iBonus);

    fuckTimer_ResetClientTimer(client);

    CReplyToCommand(client, "Bonus: %d", iBonus);

    if (iZone > 0)
    {
        CallOnClientCommand(client, 0, false);
        fuckTimer_TeleportEntityToZone(client, iZone);
    }

    return Plugin_Handled;
}

public Action Command_Restart(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    CallOnClientCommand(client, 0, true);
    ClientRestart(client);

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

    if (iBonus > 0)
    {
        iBonus--;

        if (iBonus == 0)
        {
            iBonus = 1;
        }
    }

    int iLevel = -1;

    if (iStage > 1)
    {
        iStage--;

        iZone = fuckTimer_GetStageZone(iBonus, iStage);
        iLevel = iStage;
    }
    else
    {
        iZone = fuckTimer_GetStartZone(iBonus);
        iLevel = 0;
    }

    if (iZone > 0)
    {
        CallOnClientCommand(client, iLevel, true);
        fuckTimer_TeleportEntityToZone(client, iZone);
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
    int iLevel = 0;

    fuckTimer_ResetClientTimer(client);

    if (iStage > 1)
    {
        iZone = fuckTimer_GetStageZone(iBonus, iStage);
        iLevel = iStage;
    }
    else if (iBonus > 0)
    {
        iZone = fuckTimer_GetStartZone(iBonus);
        iLevel = 0;
    }

    if (iZone > 0)
    {
        CallOnClientCommand(client, iLevel, true);
        fuckTimer_TeleportEntityToZone(client, iZone);
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
    int iLevel = 0;

    fuckTimer_ResetClientTimer(client);

    if (args == 0)
    {
        if (iBonus > 0)
        {
            iZone = fuckTimer_GetStartZone(iBonus);
            iLevel = iBonus;
        }
        else
        {
            iZone = fuckTimer_GetStartZone(1);

            if (iZone < 1)
            {
                CReplyToCommand(client, "(1) No bonus found.");
                return Plugin_Handled;
            }

            iLevel = iBonus;
        }
    }
    else
    {
        char sBuffer[12];
        GetCmdArg(1, sBuffer, sizeof(sBuffer));

        int iTemp = 0;
        
        if (IsStringNumeric(sBuffer))
        {
            iTemp = StringToInt(sBuffer);
        }
        else
        {
            CReplyToCommand(client, "String (%s) is not numeric.", sBuffer);
            return Plugin_Handled;
        }

        if (iTemp > 0)
        {
            iZone = fuckTimer_GetStartZone(iTemp);
            iLevel = iTemp;
        }
        else
        {
            CReplyToCommand(client, "(2) No bonus found for %d.", iTemp);
            return Plugin_Handled;
        }
        
        if (iZone < 1)
        {
            CReplyToCommand(client, "No bonus found try to get bonus 1 zone");
        }
    }

    if (iZone > 0)
    {
        CallOnClientCommand(client, iLevel, true);
        fuckTimer_TeleportEntityToZone(client, iZone);
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

        int iBonus = fuckTimer_GetClientBonus(client);

        fuckTimer_ResetClientTimer(client);

        char sStage[12];
        GetCmdArg(1, sStage, sizeof(sStage));

        int iStage = 0;

        if (IsStringNumeric(sStage))
        {
            iStage = StringToInt(sStage);
        }

        iZone = fuckTimer_GetStageZone(iBonus, iStage);

        if (iZone > 0)
        {
            CallOnClientCommand(client, iStage, true);
            fuckTimer_TeleportEntityToZone(client, iZone);
        }
        else
        {
            CReplyToCommand(client, "Stage %d not exist.", iStage);
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
        CReplyToCommand(client, "No styles found.");
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

            fuckTimer_SetClientSetting(client, "Style", sParam);
            ClientRestart(client);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
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
            fuckTimer_SetClientSetting(client, "InvalidKeyPref", sParam);
            
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
    
    return 0;
}

public Action Command_Tier(int client, int args)
{
    char sBuffer[MAX_NAME_LENGTH];
    GetCmdArgString(sBuffer, sizeof(sBuffer));

    if (strlen(sBuffer) < 2)
    {
        fuckTimer_GetCurrentWorkshopMap(sBuffer, sizeof(sBuffer));
    }

    fuckTimer_GetMapTiers(client, sBuffer, OnMapTiers);
    
    return Plugin_Continue;
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
        PrintToConsole(client, "Found %d Maps", snap.Length);
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
            PrintToConsole(client, "Map: %s, Tier: %d", sName, iTier);
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
            char sPhrase[64];
            FormatEx(sPhrase, sizeof(sPhrase), "Chat - Command Usage - %s", sParam);

            if (!TranslationPhraseExists(sPhrase))
            {
                CPrintToChat(client, "For this command it doesn't exist any usage informations.");
            }
            else
            {
                CPrintToChat(client, "%T", sPhrase, client);
            }

            ClientCommand(client, sParam);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    
    return 0;
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

    IntToString(HKCSTime, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "StageTime");
    menu.AddItem(sNumber, sDisplay);

    IntToString(HKTimeInZone, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "TimeInZone");
    menu.AddItem(sNumber, sDisplay);

    IntToString(HKAttempts, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "Attempts");
    menu.AddItem(sNumber, sDisplay);

    IntToString(HKSync, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "Sync");
    menu.AddItem(sNumber, sDisplay);

    IntToString(HKAVGSpeed, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "AVG-Speed");
    menu.AddItem(sNumber, sDisplay);

    IntToString(HKJumps, sNumber, sizeof(sNumber));
    FormatEx(sDisplay, sizeof(sDisplay), "Jumps");
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
    
    return 0;
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
    
    return 0;
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
    
    return 0;
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
    
    return 0;
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

    CReplyToCommand(client, "HUD %s", status ? "enabled" : "disabled");

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

    char sBuffer[32], sHUDStyle[12];
    Format(sBuffer, sizeof(sBuffer), "Default");
    IntToString(HUD_Default, sHUDStyle, sizeof(sHUDStyle));
    menu.AddItem(sHUDStyle, sBuffer);

    Format(sBuffer, sizeof(sBuffer), "KSF Style");
    IntToString(HUD_KSF, sHUDStyle, sizeof(sHUDStyle));
    menu.AddItem(sHUDStyle, sBuffer);

    Format(sBuffer, sizeof(sBuffer), "SurfHeaven Style");
    IntToString(HUD_SH, sHUDStyle, sizeof(sHUDStyle));
    menu.AddItem(sHUDStyle, sBuffer);

    Format(sBuffer, sizeof(sBuffer), "Horizon Servers Style");
    IntToString(HUD_HORIZON, sHUDStyle, sizeof(sHUDStyle));
    menu.AddItem(sHUDStyle, sBuffer);

    Format(sBuffer, sizeof(sBuffer), "GoFree Style");
    IntToString(HUD_GOFREE, sHUDStyle, sizeof(sHUDStyle));
    menu.AddItem(sHUDStyle, sBuffer);

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
            eHUDStyle eHStyle = view_as<eHUDStyle>(StringToInt(sParam));
            if (eHStyle == HUD_Default)
            {
                char sBuffer[MAX_SETTING_VALUE_LENGTH];
                IntToString(view_as<int>(HUD_DEFAULT_SEPARATOR), sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDSeparator", sBuffer);

                fuckTimer_SetClientSetting(client, "HUDScale", HUD_DEFAULT_FONTSIZE);

                IntToString(HUD_DEFAULT_STRING_LENGTH, sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDLength", sBuffer);
            }
            else if (eHStyle == HUD_KSF)
            {
                char sBuffer[MAX_SETTING_VALUE_LENGTH];
                IntToString(view_as<int>(HUD_KSF_SEPARATOR), sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDSeparator", sBuffer);

                fuckTimer_SetClientSetting(client, "HUDScale", HUD_KSF_FONTSIZE);

                IntToString(HUD_KSF_STRING_LENGTH, sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDLength", sBuffer);
            }
            else if (eHStyle == HUD_SH)
            {
                char sBuffer[MAX_SETTING_VALUE_LENGTH];
                IntToString(view_as<int>(HUD_SH_SEPARATOR), sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDSeparator", sBuffer);

                fuckTimer_SetClientSetting(client, "HUDScale", HUD_SH_FONTSIZE);

                IntToString(HUD_SH_STRING_LENGTH, sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDLength", sBuffer);
            }
            else if (eHStyle == HUD_HORIZON)
            {
                char sBuffer[MAX_SETTING_VALUE_LENGTH];
                IntToString(view_as<int>(HUD_HORIZON_SEPARATOR), sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDSeparator", sBuffer);

                fuckTimer_SetClientSetting(client, "HUDScale", HUD_HORIZON_FONTSIZE);

                IntToString(HUD_HORIZON_STRING_LENGTH, sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDLength", sBuffer);
            }
            else if (eHStyle == HUD_GOFREE)
            {
                char sBuffer[MAX_SETTING_VALUE_LENGTH];
                IntToString(view_as<int>(HUD_GOFREE_SEPARATOR), sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDSeparator", sBuffer);

                fuckTimer_SetClientSetting(client, "HUDScale", HUD_GOFREE_FONTSIZE);

                IntToString(HUD_GOFREE_STRING_LENGTH, sBuffer, sizeof(sBuffer));
                fuckTimer_SetClientSetting(client, "HUDLength", sBuffer);
            }
            fuckTimer_SetClientHUDLayout(client, eHStyle);

            Command_HUDPreset(client, 0);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    
    return 0;
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
    
    return 0;
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

        CReplyToCommand(client, "Usage: sm_hudlength <Number>");
        CReplyToCommand(client, "Current value '%s' with hud scale '%s'", sLength, sScale);
        CReplyToCommand(client, "Recommended values:");
        CReplyToCommand(client, "13 for HUD Scale SM");
        CReplyToCommand(client, "17 for HUD Scale M");

        return Plugin_Handled;
    }

    char sBuffer[8];
    GetCmdArg(1, sBuffer, sizeof(sBuffer));
    int iLength = StringToInt(sBuffer);

    if (iLength < 1 || iLength > 32)
    {
        CReplyToCommand(client, "Invalid hud length. It must be between 1 and 32.");

        return Plugin_Handled;
    }

    fuckTimer_SetClientSetting(client, "HUDLength", sBuffer);
    CReplyToCommand(client, "Set HUD Length to %d", iLength);

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
    
    return 0;
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

    CReplyToCommand(client, "Speed unit (u/s) %s", status ? "enabled" : "disabled");

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
    
    return 0;
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

    CReplyToCommand(client, "Time will shown %s", format ? "full" : "minimal");

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

    CReplyToCommand(client, "0 Hours %s", format ? "enabled" : "disabled");

    return Plugin_Handled;
}

public Action Command_HUDDeadHud(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    char sSetting[MAX_SETTING_VALUE_LENGTH];
    fuckTimer_GetClientSetting(client, "HUDDeadHud", sSetting);

    bool format = view_as<bool>(StringToInt(sSetting));
    format = !format;

    IntToString(view_as<int>(format), sSetting, sizeof(sSetting));
    fuckTimer_SetClientSetting(client, "HUDDeadHud", sSetting);

    CReplyToCommand(client, "Dead HUD %s", format ? "enabled" : "disabled");

    return Plugin_Handled;
}

public Action Command_HUDCompareLocation(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    // TODO: Add translations
    Menu menu = new Menu(Menu_HUDCompareLocation);
    menu.SetTitle("Select where the comparison should shown (or not):");

    char sSetting[MAX_SETTING_VALUE_LENGTH];
    fuckTimer_GetClientSetting(client, "HUDCompareLocation", sSetting);
    int iLocation = StringToInt(sSetting);

    char sBuffer[32];
    Format(sBuffer, sizeof(sBuffer), "[%s] Off", iLocation == 0 ? "X" : " ");
    menu.AddItem("0", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "[%s] HUD", iLocation == 1 ? "X" : " ");
    menu.AddItem("1", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "[%s] Chat", iLocation == 2 ? "X" : " ");
    menu.AddItem("2", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "[%s] HUD & Chat (Default)", iLocation == 3 ? "X" : " ");
    menu.AddItem("3", sBuffer);

    menu.ExitBackButton = false;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public int Menu_HUDCompareLocation(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[12];
        if (menu.GetItem(param, sParam, sizeof(sParam)))
        {
            fuckTimer_SetClientSetting(client, "HUDCompareLocation", sParam);
            Command_HUDCompareLocation(client, 0);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    
    return 0;
}

public Action Command_HUDCompareAgainst(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    // TODO: Add translations
    Menu menu = new Menu(Menu_HUDCompareAgainst);
    menu.SetTitle("Select against which record:");

    char sSetting[MAX_SETTING_VALUE_LENGTH];
    fuckTimer_GetClientSetting(client, "HUDCompareAgainst", sSetting);
    int iAgainst = StringToInt(sSetting);

    char sBuffer[32];
    Format(sBuffer, sizeof(sBuffer), "[%s] Personal Record", iAgainst == 0 ? "X" : " ");
    menu.AddItem("0", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "[%s] Server Record", iAgainst == 1 ? "X" : " ");
    menu.AddItem("1", sBuffer);

    Format(sBuffer, sizeof(sBuffer), "[%s] Both (Default, only for chat comparison)", iAgainst == 2 ? "X" : " ");
    menu.AddItem("2", sBuffer);

    menu.ExitBackButton = false;
    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public int Menu_HUDCompareAgainst(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sParam[12];
        if (menu.GetItem(param, sParam, sizeof(sParam)))
        {
            fuckTimer_SetClientSetting(client, "HUDCompareAgainst", sParam);
            Command_HUDCompareAgainst(client, 0);
        }
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }
    
    return 0;
}

public Action Command_HUDCompareMode(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    char sSetting[MAX_SETTING_VALUE_LENGTH];
    fuckTimer_GetClientSetting(client, "HUDCompareMode", sSetting);

    bool bMode = view_as<bool>(StringToInt(sSetting));
    bMode = !bMode;

    IntToString(view_as<int>(bMode), sSetting, sizeof(sSetting));
    fuckTimer_SetClientSetting(client, "HUDCompareMode", sSetting);

    CReplyToCommand(client, "Compare Mode: %s", bMode ? "difference" : "full");

    return Plugin_Handled;
}

public Action Command_HUDCompareTime(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    if (args != 1)
    {
        char sTime[12];
        fuckTimer_GetClientSetting(client, "HUDCompareTime", sTime);

        CReplyToCommand(client, "Usage: sm_hudcomparetime <Number>");
        CReplyToCommand(client, "Current value '%s'", sTime);

        return Plugin_Handled;
    }

    char sBuffer[8];
    GetCmdArg(1, sBuffer, sizeof(sBuffer));
    int iTime = StringToInt(sBuffer);

    if (iTime < 1 || iTime > 6)
    {
        CReplyToCommand(client, "Invalid hud length. It must be between 1 and 6.");

        return Plugin_Handled;
    }

    fuckTimer_SetClientSetting(client, "HUDCompareTime", sBuffer);
    CReplyToCommand(client, "Set HUD Compare Time to %d", iTime);

    return Plugin_Handled;
}

public Action Command_HUDCenterSpeedPosition(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    char sBuffer[12];
    fuckTimer_GetClientSetting(client, "HUDCenterSpeedPosition", sBuffer);

    char sPrevPositions[2][4];
    ExplodeString(sBuffer, ";", sPrevPositions, sizeof(sPrevPositions), sizeof(sPrevPositions[]));

    if (args != 2)
    {
        CReplyToCommand(client, "Usage: sm_hudcenterspeedposition <x or y> <Value from 0 to 1, or -1.0 for axis centering");
        CReplyToCommand(client, "Current value for x position: %s", sPrevPositions[0]);
        CReplyToCommand(client, "Current value for y position: %s", sPrevPositions[1]);

        return Plugin_Handled;
    }

    char sAxis[4];
    GetCmdArg(1, sAxis, sizeof(sAxis));
    sAxis[0] = CharToLower(sAxis[0]);
    sAxis[1] = '\0';

    if (sAxis[0] != 'x' && sAxis[0] != 'y')
    {
        CReplyToCommand(client, "Invalid Axis (%s). Valid axis are \"x\" and \"y\"", sAxis);
        return Plugin_Handled;
    }

    char sPosition[8];
    GetCmdArg(2, sPosition, sizeof(sPosition));
    float fPosition = StringToFloat(sPosition);

    if (fPosition < 0.0 || fPosition > 1.0)
    {
        if (fPosition != -1.0)
        {
            CReplyToCommand(client, "Invalid position (%.3f). Valid position is from 0.0 to 1.0, or -1.0 for centering>", fPosition);
            return Plugin_Handled;
        }
    }

    if (sAxis[0] == 'x')
    {
        FormatEx(sBuffer, sizeof(sBuffer), "%s;%s", sPosition, sPrevPositions[1]);
    }
    else
    {
        FormatEx(sBuffer, sizeof(sBuffer), "%s;%s", sPrevPositions[0], sPosition);
    }

    fuckTimer_SetClientSetting(client, "HUDCenterSpeedPosition", sBuffer);

    return Plugin_Handled;
}

public Action Command_HUDCenterSpeedColor(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }
    
    char sPositive[16];
    fuckTimer_GetClientSetting(client, "HUDCenterSpeedSpeedColor", sPositive);
    
    char sNegative[16];
    fuckTimer_GetClientSetting(client, "HUDCenterSpeedNegativeSpeedColor", sNegative);

    if (args != 3)
    {
        CReplyToCommand(client, "Usage: sm_hudcenterspeedcolor <p(ositive) or n(egative)> <r(ed), g(reen) or b(lue)>, <Value from 0 to 255>");
        CReplyToCommand(client, "Current color for positive speed: %s", sPositive);
        CReplyToCommand(client, "Current color for negative speed: %s", sNegative);

        return Plugin_Handled;
    }

    char sType[4];
    GetCmdArg(1, sType, sizeof(sType));
    sType[0] = CharToLower(sType[0]);
    sType[1] = '\0';

    if (sType[0] != 'p' && sType[0] != 'n')
    {
        CReplyToCommand(client, "Invalid type (%s). Valid types are \"p\"(ositive) and \"n\"(egative)", sType);
        return Plugin_Handled;
    }

    char sColor[4];
    GetCmdArg(2, sColor, sizeof(sColor));
    sColor[0] = CharToLower(sColor[0]);
    sColor[1] = '\0';

    if (sColor[0] != 'r' && sColor[0] != 'g' && sColor[0] != 'b')
    {
        CReplyToCommand(client, "Invalid color (%s). Valid colors are \"r\"(ed), \"g\"(reen) and \"b\"(lue)", sColor);
        return Plugin_Handled;
    }

    char sValue[8];
    GetCmdArg(3, sValue, sizeof(sValue));
    int iValue = StringToInt(sValue);

    if (!IsStringNumeric(sValue) || iValue < 0 || iValue > 255)
    {
        CReplyToCommand(client, "Invalid color value (%d/%s). Valid color value is from 0 to 255", iValue, sValue);
        return Plugin_Handled;
    }

    if (sType[0] == 'p')
    {
        char sColors[3][4];
        ExplodeString(sPositive, ";", sColors, sizeof(sColors), sizeof(sColors[]));

        CopyColor(sColor, sColors, sValue);
        FormatEx(sPositive, sizeof(sPositive), "%s;%s;%s", sColors[0], sColors[1], sColors[2]);

        fuckTimer_SetClientSetting(client, "HUDCenterSpeedSpeedColor", sPositive);
    }
    else
    {
        char sColors[3][4];
        ExplodeString(sNegative, ";", sColors, sizeof(sColors), sizeof(sColors[]));

        CopyColor(sColor, sColors, sValue);
        FormatEx(sNegative, sizeof(sNegative), "%s;%s;%s", sColors[0], sColors[1], sColors[2]);

        fuckTimer_SetClientSetting(client, "HUDCenterSpeedNegativeSpeedColor", sNegative);
    }

    return Plugin_Handled;
}

public int Native_RestartClient(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    ClientRestart(client);
    
    return 0;
}

void ClientRestart(int client)
{
    Call_StartForward(Core.OnClientRestart);
    Call_PushCell(client);
    Call_Finish();
}

void CallOnClientCommand(int client, int level, bool start)
{
    Call_StartForward(Core.OnClientCommand);
    Call_PushCell(client);
    Call_PushCell(level);
    Call_PushCell(view_as<int>(start));
    Call_Finish();
}

void CopyColor(char[] color, char colors[3][4], char[] value)
{
    if (color[0] == 'r')
    {
        strcopy(colors[0], sizeof(colors[]), value);
    }
    else if (color[0] == 'g')
    {
        strcopy(colors[1], sizeof(colors[]), value);
    }
    else
    {
        strcopy(colors[2], sizeof(colors[]), value);
    }
}
