#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckZones>
#include <fuckTimer_stocks>
#include <fuckTimer_api>
#include <fuckTimer_hud>
#include <fuckTimer_maps>
#include <fuckTimer_timer>
#include <fuckTimer_zones>
#include <fuckTimer_styles>
#include <fuckTimer_players>

enum struct PlayerData
{
    int LastZone;
    char Zone[MAX_ZONE_NAME_LENGTH];

    int LeftSide[MAX_HUD_LINES];
    int RightSide[MAX_HUD_LINES];

    void Reset(bool resetHud)
    {
        this.LastZone = -1;
        this.Zone[0] = '\0';

        if (!resetHud)
        {
            return;
        }

        for (int i = 0; i < MAX_HUD_LINES; i++)
        {
            this.LeftSide[i] = HKNone;
            this.RightSide[i] = HKNone;
        }
    }
}
PlayerData Player[MAXPLAYERS + 1];

enum struct PluginData
{
    HTTPClient HTTPClient;

    ConVar cvTitle;

    char Title[32];
}
PluginData Core;

#include "api/hud.sp"

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "HUD",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("fuckTimer_SetClientHUDLayout", Native_SetClientHUDLayout);
    CreateNative("fuckTimer_MoveClientHUDKey", Native_MoveClientHUDKey);

    RegPluginLibrary("fuckTimer_hud");

    return APLRes_Success;
}

public void OnPluginStart()
{
    GetHTTPClient();

    fuckTimer_StartConfig("hud");
    Core.cvTitle = AutoExecConfig_CreateConVar("hud_title", "fuckTimer.com", "Choose your hud title, this can't changed by players.");
    Core.cvTitle.AddChangeHook(OnCvarChange);
    fuckTimer_EndConfig();

    HookEvent("player_activate", Event_PlayerActivate);
}

public void OnMapStart()
{
    char sBuffer[MAX_SETTING_VALUE_LENGTH];

    IntToString(view_as<int>(true), sBuffer, sizeof(sBuffer));
    fuckTimer_RegisterSetting("HUD", sBuffer);

    IntToString(view_as<int>(HUD_DEFAULT_SEPARATOR), sBuffer, sizeof(sBuffer));
    fuckTimer_RegisterSetting("HUDSeparator", sBuffer);

    fuckTimer_RegisterSetting("HUDScale", HUD_DEFAULT_FONTSIZE);

    IntToString(HUD_DEFAULT_STRING_LENGTH, sBuffer, sizeof(sBuffer));
    fuckTimer_RegisterSetting("HUDLength", sBuffer);

    IntToString(view_as<int>(false), sBuffer, sizeof(sBuffer));
    fuckTimer_RegisterSetting("HUDShowSpeedUnit", sBuffer);

    IntToString(view_as<int>(HSXY), sBuffer, sizeof(sBuffer));
    fuckTimer_RegisterSetting("HUDSpeed", sBuffer);

    IntToString(view_as<int>(HTMinimal), sBuffer, sizeof(sBuffer));
    fuckTimer_RegisterSetting("HUDTime", sBuffer);

    IntToString(view_as<int>(false), sBuffer, sizeof(sBuffer));
    fuckTimer_RegisterSetting("HUDShowTime0Hours", sBuffer);
}

public void fuckTimer_OnAPIReady()
{
    GetHTTPClient();
}

public void OnCvarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == Core.cvTitle)
    {
        strcopy(Core.Title, sizeof(PluginData::Title), newValue);
    }
}

public Action Event_PlayerActivate(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    LoadPlayer(client);
}

public void OnGameFrame()
{
    IntMap imBuffer;
    char sBuffer[MAX_HUD_KEY_LENGTH], sRightBuffer[MAX_HUD_KEY_LENGTH], sSetting[MAX_SETTING_VALUE_LENGTH];

    float fTime = 0.0;
    int iMaxBonus = fuckTimer_GetAmountOfBonus();

    IntMap imCheckpoints = new IntMap();
    IntMap imStages = new IntMap();

    for (int i = 0; i <= iMaxBonus; i++)
    {
        imStages.SetValue(i, fuckTimer_GetAmountOfStages(i));
        imCheckpoints.SetValue(i, fuckTimer_GetAmountOfCheckpoints(i));
    }

    fuckTimer_LoopClients(client, false, false)
    {
        bool success = fuckTimer_GetClientSetting(client, "HUD", sSetting);

        if (!success || !IsPlayerAlive(client) || !view_as<bool>(StringToInt(sSetting)))
        {
            continue;
        }

        imBuffer = new IntMap();

        FormatEx(sBuffer, sizeof(sBuffer), "Tier: %d", fuckTimer_GetCurrentMapTier());
        imBuffer.SetString(HKTier, sBuffer);

        GetCurrentMap(sBuffer, sizeof(sBuffer));
        imBuffer.SetString(HKMap, sBuffer);
        
        fuckTimer_GetClientSetting(client, "HUDShowSpeedUnit", sSetting);
        FormatEx(sBuffer, sizeof(sBuffer), "Speed: %.0f%s", GetClientSpeed(client), (view_as<bool>(StringToInt(sSetting)) ? " u/s" : ""));
        imBuffer.SetString(HKSpeed, sBuffer);

        FormatEx(sBuffer, sizeof(sBuffer), "PR: None");
        imBuffer.SetString(HKPersonalRecord, sBuffer);

        FormatEx(sBuffer, sizeof(sBuffer), "SR: None");
        imBuffer.SetString(HKServerRecord, sBuffer);
        
        fuckTimer_GetClientSetting(client, "Style", sSetting);
        Styles style = view_as<Styles>(StringToInt(sSetting));
        fuckTimer_GetStyleName(style, sBuffer, sizeof(sBuffer));
        
        Format(sBuffer, sizeof(sBuffer), "Style: %s", sBuffer);
        imBuffer.SetString(HKStyle, sBuffer);

        fTime = fuckTimer_GetClientTime(client, TimeMain);

        if (fTime  == 0.0)
        {
            fTime = fuckTimer_GetClientTime(client, TimeBonus, fuckTimer_GetClientBonus(client));
        }

        GetTimeBySeconds(client, fTime, sBuffer, sizeof(sBuffer));
        Format(sBuffer, sizeof(sBuffer), "%s", sBuffer);
        imBuffer.SetString(HKTime, sBuffer);

        if (strlen(Player[client].Zone) > 1)
        {
            FormatEx(sBuffer, sizeof(sBuffer), "Zone: %s", Player[client].Zone);
            imBuffer.SetString(HKZone, sBuffer);
        }

        int iBonus = fuckTimer_GetClientBonus(client);
        bool bReplaceBonus = true;

        int iCheckpoint = fuckTimer_GetClientCheckpoint(client);
        int iStage = fuckTimer_GetClientStage(client);
        float fCPStageTime = 0.0;

        int iValidator, iTemp;

        if (Player[client].LastZone > 0)
        {
            fuckTimer_IsCheckerZone(Player[client].LastZone, iTemp, iValidator);
        }

        if (imStages.GetInt(iBonus) > 0)
        {
            fCPStageTime = fuckTimer_GetClientTime(client, TimeStage, iStage);

            if (strlen(Player[client].Zone) < 1)
            {
                GetTimeBySeconds(client, fCPStageTime, sBuffer, sizeof(sBuffer));
                Format(sBuffer, sizeof(sBuffer), "%s", sBuffer);
                imBuffer.SetString(HKStageTime, sBuffer);
            }
            else
            {
                FormatEx(sBuffer, sizeof(sBuffer), "0.000");
                imBuffer.SetString(HKStageTime, sBuffer);
            }

            FormatEx(sBuffer, sizeof(sBuffer), "%sStage: %d/%d", iBonus > 0 ? "B-" : "", iStage, imStages.GetInt(iBonus));
            imBuffer.SetString(HKCurrentStage, sBuffer);
            imBuffer.SetString(HKMapType, sBuffer);
        }
        else if (imCheckpoints.GetInt(iBonus) > 0)
        {
            fCPStageTime = fuckTimer_GetClientTime(client, TimeCheckpoint, iCheckpoint);
            GetTimeBySeconds(client, fCPStageTime, sBuffer, sizeof(sBuffer));
            Format(sBuffer, sizeof(sBuffer), "%s", sBuffer);
            imBuffer.SetString(HKStageTime, sBuffer);
            PrintToChat(client, "Test 3");

            FormatEx(sBuffer, sizeof(sBuffer), "%sCP: %d/%d", iBonus > 0 ? "B-" : "", iCheckpoint, imCheckpoints.GetInt(iBonus));
            imBuffer.SetString(HKCurrentStage, sBuffer);

            FormatEx(sBuffer, sizeof(sBuffer), "Linear %s", iBonus > 0 ? "Bonus" : "Map");
            imBuffer.SetString(HKMapType, sBuffer);
        }
        else
        {
            FormatEx(sBuffer, sizeof(sBuffer), "Linear %s", iBonus > 0 ? "Bonus" : "Map");
            imBuffer.SetString(HKMapType, sBuffer);
            imBuffer.SetString(HKCurrentStage, sBuffer);

            if (iBonus > 0)
            {
                bReplaceBonus = true;
            }
        }
        
        int iStartMatches = StrContains(Player[client].Zone, "start", false);
        bool bStartZone = fuckZones_IsClientInZoneIndex(client, fuckTimer_GetStartZone(fuckTimer_GetClientBonus(client)));
        int iEndMatches = StrContains(Player[client].Zone, "end", false);
        bool bEndZone = fuckZones_IsClientInZoneIndex(client, fuckTimer_GetEndZone(fuckTimer_GetClientBonus(client)));

        if (iStartMatches != -1 || bStartZone)
        {
            FormatEx(sBuffer, sizeof(sBuffer), "Map Start");
            imBuffer.SetString(HKMapType, sBuffer);
        }
        else if (iEndMatches != -1 || bEndZone)
        {
            FormatEx(sBuffer, sizeof(sBuffer), "Map End");
            imBuffer.SetString(HKMapType, sBuffer);
        }

        if (bReplaceBonus && iMaxBonus > 0 && iBonus > 0)
        {
            FormatEx(sBuffer, sizeof(sBuffer), "Bonus: %d/%d", iBonus, iMaxBonus);
            imBuffer.SetString(HKCurrentStage, sBuffer);
            sBuffer[0] = '\0';

            if (iStartMatches != -1)
            {
                FormatEx(sBuffer, sizeof(sBuffer), " Start");
            }
            else if (iEndMatches != -1)
            {
                FormatEx(sBuffer, sizeof(sBuffer), " End");
            }
            else
            {
                FormatEx(sBuffer, sizeof(sBuffer), " %d", iBonus);
            }

            Format(sBuffer, sizeof(sBuffer), "Bonus%s", sBuffer);
            imBuffer.SetString(HKMapType, sBuffer);
        }

        if (iValidator > 0)
        {
            FormatEx(sBuffer, sizeof(sBuffer), "Validator: %d/%d", fuckTimer_GetClientValidator(client), iValidator);
            imBuffer.SetString(HKValidator, sBuffer);
        }

        char sHUD[6*128+32], sHUDBuffer[128], sScale[8];
        fuckTimer_GetClientSetting(client, "HUDScale", sScale);

        fuckTimer_GetClientSetting(client, "HUDSeparator", sSetting);
        eHUDSeparator iSeparator = view_as<eHUDSeparator>(StringToInt(sSetting));

        FormatEx(sHUD, sizeof(sHUD), "<pre><font class='fontSize-%s'>", sScale);

        fuckTimer_GetClientSetting(client, "HUDLength", sSetting);
        int iLength = StringToInt(sSetting);

        for (int i = 0; i < MAX_HUD_LINES; i++)
        {
            if (Player[client].LeftSide[i] > 0)
            {
                imBuffer.GetString(Player[client].LeftSide[i], sBuffer, sizeof(sBuffer));
            }
            
            if (Player[client].RightSide[i] > 0)
            {
                imBuffer.GetString(Player[client].RightSide[i], sRightBuffer, sizeof(sRightBuffer));
            }

            if (strlen(sBuffer) < 1 && strlen(sRightBuffer) < 1)
            {
                continue;
            }

            if (iSeparator == HSTabs)
            {
                if (strlen(sBuffer) < iLength)
                {
                    for (int j = strlen(sBuffer); j < iLength; j++)
                    {
                        Format(sBuffer, sizeof(sBuffer), "%s ", sBuffer);
                    }
                }

                Format(sHUDBuffer, sizeof(sHUDBuffer), "%s%s\t%s\n", sHUDBuffer, sBuffer, sRightBuffer);
            }
            else if (iSeparator == HSBar)
            {
                Format(sHUDBuffer, sizeof(sHUDBuffer), "%s%s%s%s\n", sHUDBuffer, sBuffer, (strlen(sBuffer) > 0 && strlen(sRightBuffer) > 0) ? " | " : "", sRightBuffer);
            }

            sBuffer[0] = '\0';
            sRightBuffer[0] = '\0';
        }

        delete imBuffer;

        Format(sHUD, sizeof(sHUD), "%s%s</font></pre>", sHUD, sHUDBuffer);
        PrintCSGOHUDText(client, sHUD);
    }

    delete imCheckpoints;
    delete imStages;
}

public void fuckTimer_OnEnteringZone(int client, int zone, const char[] name)
{
    Player[client].Reset(false);
    Player[client].LastZone = zone;

    int iBonus;
    bool bStart = fuckTimer_IsStartZone(zone, iBonus);
    bool bEnd = fuckTimer_IsEndZone(zone, iBonus);

    if (bStart)
    {
        FormatEx(Player[client].Zone, sizeof(PlayerData::Zone), "Start");
    }
    
    if (bEnd)
    {
        FormatEx(Player[client].Zone, sizeof(PlayerData::Zone), "End");
    }

    int iStage = fuckTimer_GetStageByIndex(zone, iBonus);
    
    if (iStage > 0)
    {
        FormatEx(Player[client].Zone, sizeof(PlayerData::Zone), "Stage %d%s%s", iStage, bStart ? " Start" : "", bEnd ? " End" : "");
    }
    
    if (iBonus > 0)
    {
        FormatEx(Player[client].Zone, sizeof(PlayerData::Zone), "Bonus %d%s%s", iBonus, bStart ? " Start" : "", bEnd ? " End" : "");
    }
}

public void fuckTimer_OnLeavingZone(int client, int zone, const char[] name)
{
    Player[client].Reset(false);
    Player[client].LastZone = zone;
}

public any Native_SetClientHUDLayout(Handle plugin, int numParams)
{
    char sLayout[24];
    GetNativeString(2, sLayout, sizeof(sLayout));

    PreparePlayerPostHudSettings(GetNativeCell(1), sLayout);
}

public any Native_MoveClientHUDKey(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    eHUDKeys iKey = view_as<eHUDKeys>(GetNativeCell(2));
    int iSide = view_as<bool>(GetNativeCell(3));
    int iLine = GetNativeCell(4);

    HUDEntry hEntry[2];
    hEntry[0].Side = iSide;
    hEntry[0].Line = iLine;
    hEntry[0].Key = iKey;

    bool swapPositions = view_as<bool>(GetNativeCell(5));

    bool success = GetOldPosition(client, iKey, hEntry);

    if (success)
    {
        if (iSide == HUD_SIDE_LEFT)
        {
            hEntry[1].Key = Player[client].LeftSide[iLine];
        }
        else
        {
            hEntry[1].Key = Player[client].RightSide[iLine];
        }
    }
    else
    {
        hEntry[1].Line = -1;
    }

    if (!swapPositions)
    {
        hEntry[1].Key = 0;
    }

    for (int i = 0; i <= 1; i++)
    {
        if (hEntry[i].Line == -1)
        {
            continue;
        }
        
        if (hEntry[i].Side == HUD_SIDE_LEFT)
        {
            Player[client].LeftSide[hEntry[i].Line] = hEntry[i].Key;
        }
        else
        {
            Player[client].RightSide[hEntry[i].Line] = hEntry[i].Key;
        }
    }

    PatchPlayerHUDKeys(client, hEntry);
}

bool GetOldPosition(int client, int key, HUDEntry hEntry[2])
{
    for (int side = HUD_SIDE_LEFT; side <= HUD_SIDE_RIGHT; side++)
    {
        for (int line = 0; line < MAX_HUD_LINES; line++)
        {
            if (side == HUD_SIDE_LEFT)
            {
                if (Player[client].LeftSide[line] == key)
                {
                    hEntry[1].Side = side;
                    hEntry[1].Line = line;

                    return true;
                }
            }
            else
            {
                if (Player[client].RightSide[line] == key)
                {
                    hEntry[1].Side = side;
                    hEntry[1].Line = line;

                    return true;
                }
            }
        }
    }

    return false;
}

void PrintCSGOHUDText(int client, const char[] format, any ...)
{
    char sMessage[225];
    VFormat(sMessage, sizeof(sMessage), format, 3);
    Format(sMessage, sizeof(sMessage), "</font> %s%s ", Core.Title, sMessage);

    for(int i = strlen(sMessage); i < sizeof(sMessage); i++)
    {
        sMessage[i] = '\n';
    }

    Protobuf pbBuf = view_as<Protobuf>(StartMessageOne("TextMsg", client, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS));
    pbBuf.SetInt("msg_dst", 4);
    pbBuf.AddString("params", "#SFUI_ContractKillStart");
    pbBuf.AddString("params", sMessage);
    pbBuf.AddString("params", NULL_STRING);
    pbBuf.AddString("params", NULL_STRING);
    pbBuf.AddString("params", NULL_STRING);
    pbBuf.AddString("params", NULL_STRING);
    
    EndMessage();
}

float GetClientSpeed(int client)
{
    float fVelocity[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);

    float fSpeed = 0.0;

    char sSpeed[MAX_SETTING_VALUE_LENGTH];
    fuckTimer_GetClientSetting(client, "HUDSpeed", sSpeed);

    eHUDSpeed eSpeed = view_as<eHUDSpeed>(StringToInt(sSpeed));

    if (eSpeed == HSXYZ)
    {
        fSpeed = SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0) + Pow(fVelocity[2], 2.0));
    }
    else if (eSpeed == HSZ)
    {
        fSpeed = fVelocity[2];
    }
    else
    {
        fSpeed = SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0));
    }

    return fSpeed;
}

stock void GetTimeBySeconds(int client = 0, float seconds, char[] time, int length, eHUDTime format = HTMinimal, bool show0Hours = false)
{
    if (client > 0)
    {
        char sSetting[MAX_SETTING_VALUE_LENGTH];

        fuckTimer_GetClientSetting(client, "HUDTime", sSetting);
        format = view_as<eHUDTime>(StringToInt(sSetting));

        fuckTimer_GetClientSetting(client, "HUDShowTime0Hours", sSetting);
        show0Hours = view_as<bool>(StringToInt(sSetting));
    }

    int iBuffer = RoundToFloor(seconds);
    float fSeconds = (iBuffer % 60) + seconds - iBuffer;
    int iMinutes = (iBuffer / 60) % 60;
    int iHours = RoundToFloor(iBuffer / 3600.0);

    if (format == HTMinimal)
    {
        FormatEx(time, length, "%.3f", fSeconds);
        
        if (seconds > 59.999)
        {
            Format(time, length, "%d:%s", iMinutes, time);
        }

        if (seconds > 3599.999)
        {
            Format(time, length, "%d:%s", iHours, time);
        }
    }
    else if (format == HTFull)
    {
        if (seconds < 60.0)
        { 
            FormatEx(time, length, "%s00:%s%.3f", show0Hours ? "00:" : "", seconds < 10 ? "0" : "", fSeconds);
        }
        else if (seconds < 3600.0)
        {
            Format(time, length, "%s%s%d:%s%.3f", show0Hours ? "00:" : "", iMinutes < 10 ? "0" : "", iMinutes, fSeconds < 10.0 ? "0" : "", fSeconds);
        }   
        else
        {
            Format(time, length, "%s%d:%s%d:%s%.3f", (iHours < 10 && show0Hours) ? "0" : "", iHours, iMinutes < 10 ? "0" : "", iMinutes, fSeconds < 10.0 ? "0" : "", fSeconds);
        }
    }
}

void LoadPlayer(int client)
{
    PrintToServer("[HUD] LoadPlayer1: %d", client);

    Player[client].Reset(true);

    if (!IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client))
    {
        return;
    }

    PrintToServer("[HUD] LoadPlayer2: %N", client);

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "PlayerHud/PlayerId/%d", GetSteamAccountID(client));

    if (Core.HTTPClient == null)
    {
        Core.HTTPClient = fuckTimer_GetHTTPClient();
    }

    Core.HTTPClient.Get(sEndpoint, GetPlayerHudSettings, GetClientUserId(client));
}
