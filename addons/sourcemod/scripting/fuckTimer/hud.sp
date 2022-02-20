#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckZones>
#include <fuckTimer_api>
#include <fuckTimer_stocks>
#include <fuckTimer_hud>
#include <fuckTimer_timer>
#include <fuckTimer_maps>
#include <fuckTimer_zones>
#include <fuckTimer_records>
#include <fuckTimer_players>

enum struct PlayerData
{
    int LastZone;
    char Zone[MAX_ZONE_NAME_LENGTH];

    int LeftSide[MAX_HUD_LINES];
    int RightSide[MAX_HUD_LINES];

    int Speed;

    int CompareSpeed;
    float CompareSpeedValue;
    int CompareTime;
    float CompareTimeValue;
    int CompareCSTime;
    float CompareCSTimeValue;

    void Reset(bool resetHud, bool resetCompare)
    {
        this.LastZone = -1;
        this.Zone[0] = '\0';
        this.Speed = 0;

        if (resetCompare)
        {
            this.CompareSpeed = 0;
            this.CompareSpeedValue = 0.0;
            this.CompareTime = 0;
            this.CompareTimeValue = 0.0;
            this.CompareCSTime = 0;
            this.CompareCSTimeValue = 0.0;
        }

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

enum struct MapRecordDetails
{
    int Count;
    float AvgTime;
}

enum struct PluginData
{
    ConVar cvTitle;
    ConVar Factor;

    char Title[32];

    IntMap MapRecordDetails[MAX_STYLES + 1];
}
PluginData Core;

#include "api/hud.sp"
#include "natives/hud.sp"

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
    fuckTimer_StartConfig("hud");
    Core.cvTitle = AutoExecConfig_CreateConVar("hud_title", "fuckTimer.com", "Choose your hud title, this can't changed by players.");
    Core.Factor = AutoExecConfig_CreateConVar("hud_factor", "6", "Factor to increase/decrease amount of OnGameFrame calls. Reduce will results into better Performance");
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

    IntToString(view_as<int>(false), sBuffer, sizeof(sBuffer));
    fuckTimer_RegisterSetting("HUDDeadHUD", sBuffer);

    IntToString(view_as<int>(CLBoth), sBuffer, sizeof(sBuffer)); // 0 - Off, 1 - HUD, 2 - Chat, 3 - HUD & Chat
    fuckTimer_RegisterSetting("HUDCompareLocation", sBuffer);

    IntToString(view_as<int>(CASR), sBuffer, sizeof(sBuffer)); // 0 - PR (or SR if PR not exist), 1 - SR (if exist), 2 - Both (works only with HUDCompareLocation 1)
    fuckTimer_RegisterSetting("HUDCompareAgainst", sBuffer);

    IntToString(view_as<int>(CMFull), sBuffer, sizeof(sBuffer)); // 0 - Time/Speed, 1 - Difference
    fuckTimer_RegisterSetting("HUDCompareMode", sBuffer);

    IntToString(3, sBuffer, sizeof(sBuffer)); // Time in seconds how long the comparison should be shown (HUDCompareMode must be 1)
    fuckTimer_RegisterSetting("HUDCompareTime", sBuffer);

    IntToString(1, sBuffer, sizeof(sBuffer)); // 0 - Disable Center HUD Speed, 1 - Enable Center HUD Speed
    fuckTimer_RegisterSetting("HUDCenterSpeed", sBuffer);

    fuckTimer_RegisterSetting("HUDCenterSpeedPosition", "-1.0;0.6"); // From 0 to 1, or -1 for axis centering. Example/Default: -1.0;0.6
    fuckTimer_RegisterSetting("HUDCenterSpeedSpeedColor", "0;255;0"); // TODO. Example/Default: 0;255;0
    fuckTimer_RegisterSetting("HUDCenterSpeedNegativeSpeedColor", "255;0;0"); // TODO. Example/Default: 255;0;0
}

public void OnCvarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == Core.cvTitle)
    {
        strcopy(Core.Title, sizeof(PluginData::Title), newValue);
    }
}

public void fuckTimer_OnServerRecordsLoaded(int records)
{
    if (records < 1)
    {
        return;
    }

    LoadServerRecordCount();
}

public Action Event_PlayerActivate(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    LoadPlayer(client);

    return Plugin_Continue;
}

public void OnGameFrame()
{
    if (GetGameTickCount() % Core.Factor.IntValue != 0)
    {
        return;
    }

    IntMap imBuffer;
    char sBuffer[MAX_HUD_KEY_LENGTH], sRightBuffer[MAX_HUD_KEY_LENGTH], sSetting[MAX_SETTING_VALUE_LENGTH];

    float fTime = 0.0;
    int iMaxBonus = fuckTimer_GetAmountOfBonus();

    IntMap imCheckpoints = new IntMap();
    IntMap imStages = new IntMap();

    for (int i = 0; i <= iMaxBonus; i++)
    {
        imCheckpoints.SetValue(i, fuckTimer_GetAmountOfCheckpoints(i));
        imStages.SetValue(i, fuckTimer_GetAmountOfStages(i));
    }

    fuckTimer_LoopClients(client, false, false)
    {
        int target = -1;

        bool success = fuckTimer_GetClientSetting(client, "HUD", sSetting);

        if (!success || !StringToBool(sSetting) || fuckTimer_GetClientStatus(client) == psInactive)
        {
            continue;
        }

        if (!IsPlayerAlive(client))
        {
            success = fuckTimer_GetClientSetting(client, "HUDDeadHUD", sSetting);

            if (!success || !StringToBool(sSetting))
            {
                continue;
            }
            
            int iMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

            // 4 - 1st Person, 5 - 3rd Person
            if (iMode == 4 || iMode == 5)
            {
                target = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

                if (target < 1 || !IsPlayerAlive(target) || IsFakeClient(target))
                {
                    target = -1;
                }

            }
        }

        int iClient = client;
        
        if (target > 0)
        {
            client = target;
        }

        imBuffer = new IntMap();

        FormatEx(sBuffer, sizeof(sBuffer), "Tier: %d", fuckTimer_GetCurrentMapTier());
        imBuffer.SetString(HKTier, sBuffer);

        GetCurrentMap(sBuffer, sizeof(sBuffer));
        imBuffer.SetString(HKMap, sBuffer);

        char sSpeed[MAX_SETTING_VALUE_LENGTH];
        fuckTimer_GetClientSetting(iClient, "HUDSpeed", sSpeed);
        fuckTimer_GetClientSetting(iClient, "HUDShowSpeedUnit", sSetting);
        fuckTimer_GetClientSetting(iClient, "HUDCenterSpeed", sBuffer);
        bool bCenterSpeed = StringToBool(sBuffer);

        float fSpeed = 0.0;

        if (Player[client].CompareSpeed == 0 || Player[client].CompareSpeed <= GetTime())
        {
            fSpeed = GetClientSpeed(client, view_as<eHUDSpeed>(StringToInt(sSpeed)));
        }
        else
        {
            fSpeed = Player[client].CompareSpeedValue;
        }

        if (bCenterSpeed)
        {
            int iSpeed = RoundToNearest(GetClientSpeed(client, view_as<eHUDSpeed>(StringToInt(sSpeed))));
            
            fuckTimer_GetClientSetting(iClient, "HUDCenterSpeedPosition", sBuffer);

            char sAxis[2][12];
            ExplodeString(sBuffer, ";", sAxis, sizeof(sAxis), sizeof(sAxis[]));

            float fAxisX = StringToFloat(sAxis[0]);
            float fAxisY = StringToFloat(sAxis[1]);

            int iRed, iGreen, iBlue;
            char sColors[3][4];

            if (iSpeed >= Player[client].Speed)
            {
                fuckTimer_GetClientSetting(iClient, "HUDCenterSpeedSpeedColor", sBuffer);
                ExplodeString(sBuffer, ";", sColors, sizeof(sColors), sizeof(sColors[]));
            }
            else
            {
                fuckTimer_GetClientSetting(iClient, "HUDCenterSpeedNegativeSpeedColor", sBuffer);
                ExplodeString(sBuffer, ";", sColors, sizeof(sColors), sizeof(sColors[]));
            }

            iRed = StringToInt(sColors[0]);
            iGreen = StringToInt(sColors[1]);
            iBlue = StringToInt(sColors[2]);

            SetHudTextParams(fAxisX, fAxisY, 1.0, iRed, iGreen, iBlue, 255, 0, 0.25, 0.0, 0.0);

            IntToString(iSpeed, sBuffer, sizeof(sBuffer));
            ShowHudText(client, 2, sBuffer);

            Player[client].Speed = iSpeed;
        }

        FormatEx(sBuffer, sizeof(sBuffer), "Speed: %.0f%s", fSpeed, (StringToBool(sSetting) ? " u/s" : ""));
        imBuffer.SetString(HKSpeed, sBuffer);
        
        Styles style = fuckTimer_GetClientStyle(iClient);
        fuckTimer_GetStyleName(style, sBuffer, sizeof(sBuffer));
        
        Format(sBuffer, sizeof(sBuffer), "Style: %s", sBuffer);
        imBuffer.SetString(HKStyle, sBuffer);

        int iBonus = fuckTimer_GetClientBonus(client);

        fTime = fuckTimer_GetClientTime(client, TimeMain, iBonus);

        int iRank = 0;
        RecordData record;
        if (fuckTimer_GetPlayerRecord(client, style, iBonus, record))
        {
            GetTimeBySeconds(iClient, record.Time, sBuffer, sizeof(sBuffer));
            Format(sBuffer, sizeof(sBuffer), "PR: %s", sBuffer);
            iRank = record.Rank;
        }
        else
        {
            FormatEx(sBuffer, sizeof(sBuffer), "PR: None");
        }
        imBuffer.SetString(HKPersonalRecord, sBuffer);

        if (fuckTimer_GetServerRecord(style, iBonus, record))
        {
            GetTimeBySeconds(iClient, record.Time, sBuffer, sizeof(sBuffer));
            Format(sBuffer, sizeof(sBuffer), "SR: %s", sBuffer);
        }
        else
        {
            FormatEx(sBuffer, sizeof(sBuffer), "SR: None");
        }
        imBuffer.SetString(HKServerRecord, sBuffer);

        MapRecordDetails mrDetails;
        mrDetails.AvgTime = 0.0;
        
        if (Core.MapRecordDetails[style] != null)
        {
            Core.MapRecordDetails[style].GetArray(iBonus, mrDetails, sizeof(mrDetails));
        }

        if (mrDetails.Count < 1)
        {
            FormatEx(sBuffer, sizeof(sBuffer), "No records");
        }
        else if (iRank < 1)
        {
            FormatEx(sBuffer, sizeof(sBuffer), "No record");
        }
        else
        {
            FormatEx(sBuffer, sizeof(sBuffer), "Rank: %d/%d", iRank, mrDetails.Count);
        }

        imBuffer.SetString(HKMapRank, sBuffer);

        if (Player[client].CompareTime == 0 || Player[client].CompareTime <= GetTime())
        {
            GetTimeBySeconds(iClient, fTime, sBuffer, sizeof(sBuffer));
            Format(sBuffer, sizeof(sBuffer), "%s", sBuffer);
            imBuffer.SetString(HKTime, sBuffer);
        }
        else
        {
            GetTimeBySeconds(iClient, Player[client].CompareTimeValue, sBuffer, sizeof(sBuffer));
            Format(sBuffer, sizeof(sBuffer), "%s", sBuffer);
            imBuffer.SetString(HKTime, sBuffer);
        }

        if (strlen(Player[client].Zone) > 1)
        {
            FormatEx(sBuffer, sizeof(sBuffer), "Zone: %s", Player[client].Zone);
            imBuffer.SetString(HKZone, sBuffer);
        }

        bool bReplaceBonus = true;

        int iCheckpoint = fuckTimer_GetClientCheckpoint(client) - 1;

        if (iCheckpoint  < 0)
        {
            iCheckpoint = 0;
        }

        int iStage = fuckTimer_GetClientStage(client);
        float fCPStageTime = 0.0;

        int iValidator, iTemp;

        if (Player[client].LastZone > 0)
        {
            fuckTimer_IsCheckerZone(Player[client].LastZone, iTemp, iValidator);
        }

        if (imStages.GetInt(iBonus) > 1)
        {
            fCPStageTime = fuckTimer_GetClientTime(client, TimeStage, iStage);

            if (Player[client].CompareCSTime == 0 || Player[client].CompareCSTime <= GetTime())
            {
                if (strlen(Player[client].Zone) < 1)
                {
                    GetTimeBySeconds(iClient, fCPStageTime, sBuffer, sizeof(sBuffer));
                    Format(sBuffer, sizeof(sBuffer), "%s", sBuffer);
                    imBuffer.SetString(HKCSTime, sBuffer);
                }
                else
                {
                    FormatEx(sBuffer, sizeof(sBuffer), "0.000");
                    imBuffer.SetString(HKCSTime, sBuffer);
                }
            }
            else
            {
                GetTimeBySeconds(iClient, Player[client].CompareCSTimeValue, sBuffer, sizeof(sBuffer));
                Format(sBuffer, sizeof(sBuffer), "%s", sBuffer);
                imBuffer.SetString(HKCSTime, sBuffer);
            }
            

            FormatEx(sBuffer, sizeof(sBuffer), "%sStage: %d/%d", iBonus > 1 ? "B-" : "", iStage, imStages.GetInt(iBonus));
            imBuffer.SetString(HKCurrentStage, sBuffer);
            imBuffer.SetString(HKMapType, sBuffer);
        }
        else if (imCheckpoints.GetInt(iBonus) > 1)
        {
            fCPStageTime = fuckTimer_GetClientTime(client, TimeCheckpoint, iCheckpoint);

            if (Player[client].CompareCSTime == 0 || Player[client].CompareCSTime <= GetTime())
            {
                GetTimeBySeconds(iClient, fCPStageTime, sBuffer, sizeof(sBuffer));
                Format(sBuffer, sizeof(sBuffer), "%s", sBuffer);
                imBuffer.SetString(HKCSTime, sBuffer);
            }
            else
            {
                GetTimeBySeconds(iClient, Player[client].CompareCSTimeValue, sBuffer, sizeof(sBuffer));
                Format(sBuffer, sizeof(sBuffer), "%s", sBuffer);
                imBuffer.SetString(HKCSTime, sBuffer);
            } 

            FormatEx(sBuffer, sizeof(sBuffer), "%sCP: %d/%d", iBonus > 1 ? "B-" : "", iCheckpoint, imCheckpoints.GetInt(iBonus));
            imBuffer.SetString(HKCurrentStage, sBuffer);

            FormatEx(sBuffer, sizeof(sBuffer), "Linear %s", iBonus > 1 ? "Bonus" : "Map");
            imBuffer.SetString(HKMapType, sBuffer);
        }
        else
        {
            FormatEx(sBuffer, sizeof(sBuffer), "Linear %s", iBonus > 0 ? "Bonus" : "Map");
            imBuffer.SetString(HKMapType, sBuffer);
            imBuffer.SetString(HKCurrentStage, sBuffer);

            FormatEx(sBuffer, sizeof(sBuffer), "0.000");
            imBuffer.SetString(HKCSTime, sBuffer);

            if (iBonus > 0)
            {
                bReplaceBonus = true;
            }
        }

        FormatEx(sBuffer, sizeof(sBuffer), "Attempts: %d", fuckTimer_GetClientAttempts(client));
        imBuffer.SetString(HKAttempts, sBuffer);

        FormatEx(sBuffer, sizeof(sBuffer), "Sync: %.2f", fuckTimer_GetClientSync(client, iBonus));
        imBuffer.SetString(HKSync, sBuffer);

        FormatEx(sBuffer, sizeof(sBuffer), "Av-Speed: %d", fuckTimer_GetClientAVGSpeed(client));
        imBuffer.SetString(HKAVGSpeed, sBuffer);
        
        GetTimeBySeconds(iClient, mrDetails.AvgTime, sBuffer, sizeof(sBuffer));
        FormatEx(sBuffer, sizeof(sBuffer), "Av-Time: %s", sBuffer);
        imBuffer.SetString(HKAVGTime, sBuffer);

        FormatEx(sBuffer, sizeof(sBuffer), "Jumps: %d", fuckTimer_GetClientJumps(client));
        imBuffer.SetString(HKJumps, sBuffer);

        fTime = fuckTimer_GetClientTimeInZone(client);
        GetTimeBySeconds(iClient, fTime, sBuffer, sizeof(sBuffer));
        Format(sBuffer, sizeof(sBuffer), "Zone Time: %s", sBuffer);
        imBuffer.SetString(HKTimeInZone, sBuffer);

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
            if (bStartZone || bEndZone)
            {
                FormatEx(sBuffer, sizeof(sBuffer), "Bonus: %d/%d", iBonus, iMaxBonus);
                imBuffer.SetString(HKCurrentStage, sBuffer);
            }

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
        fuckTimer_GetClientSetting(iClient, "HUDScale", sScale);

        fuckTimer_GetClientSetting(iClient, "HUDSeparator", sSetting);
        eHUDSeparator iSeparator = view_as<eHUDSeparator>(StringToInt(sSetting));

        FormatEx(sHUD, sizeof(sHUD), "<pre><font class='fontSize-%s'>", sScale);

        fuckTimer_GetClientSetting(iClient, "HUDLength", sSetting);
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
                if (strlen(sBuffer) >= iLength)
                {
                    continue;
                }
                
                for (int j = strlen(sBuffer); j < iLength; j++)
                {
                    Format(sBuffer, sizeof(sBuffer), "%s ", sBuffer);
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
        PrintCSGOHUDText(iClient, sHUD);
    }

    delete imCheckpoints;
    delete imStages;
}

public void fuckTimer_OnEnteringZone(int client, int zone, const char[] name)
{
    Player[client].Reset(false, true);
    Player[client].LastZone = zone;

    int iBonus;
    bool bMisc = fuckTimer_IsMiscZone(zone, iBonus);

    if (bMisc)
    {
        return;
    }

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
    
    if (iStage > 1)
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
    Player[client].Reset(false, false);
    Player[client].LastZone = zone;

    int iBonus;
    bool bStart = fuckTimer_IsStartZone(zone, iBonus);
    int level = fuckTimer_GetZoneStage(zone, iBonus);
    
    bool bCheckpoint = false;
    if (level == 0)
    {
        level = fuckTimer_GetZoneCheckpoint(zone, iBonus);

        if (level > 0)
        {
            bCheckpoint = true;
        }
    }

    if (!bStart && level < 0)
    {
        return;
    }

    eCompareLocation eLocation = fuckTimer_GetClientCompareLocation(client);
    eCompareMode eMode = fuckTimer_GetClientCompareMode(client);
    eCompareAgainst eAgainst = fuckTimer_GetClientCompareAgainst(client);

    Styles sStyle = fuckTimer_GetClientStyle(client);

    char sSpeed[MAX_SETTING_VALUE_LENGTH];
    fuckTimer_GetClientSetting(client, "HUDSpeed", sSpeed);
    eHUDSpeed eSpeed = view_as<eHUDSpeed>(StringToInt(sSpeed));

    RecordData recordPR;
    RecordData recordSR;
    eCompareAgainst eReturn = GetRecord(client, sStyle, iBonus, eAgainst, recordPR, recordSR);
    PrintToChatAll("%N - eReturn: %d", client, eReturn);

    float fVelocity[3];
    GetClientVelocity(client, fVelocity);

    if (eLocation == CLChat || eLocation == CLBoth)
    {
        CompareChat_LeaveZone(client, bStart, level, eReturn, recordPR, recordSR, bCheckpoint, fVelocity, eAgainst, eMode, eSpeed);
    }

    if (eLocation == CLHUD || eLocation == CLBoth)
    {
        RecordData record;
        if (eReturn != CANONE)
        {
            if (eAgainst == CAPR)
            {
                record = recordPR;
            }
            else if (eAgainst == CASR)
            {
                record = recordSR;
            }
        }
        else
        {
            return;
        }
        
        CompareHUD_LeaveZone(client, level, bStart, fVelocity, record, eReturn, eMode, eSpeed);
    }
}

public void fuckTimer_OnClientZoneTouchStart(int client, bool stop, int bonus, TimeType type, int level, float time, float timeInZone, int attempts)
{
    if (type == TimeMain)
    {
        return;
    }

    eCompareMode eMode = fuckTimer_GetClientCompareMode(client);
    eCompareAgainst eAgainst = fuckTimer_GetClientCompareAgainst(client);
    Styles sStyle = fuckTimer_GetClientStyle(client);

    RecordData recordPR;
    RecordData recordSR;
    eCompareAgainst eReturn = GetRecord(client, sStyle, bonus, eAgainst, recordPR, recordSR);

    CSDetails detailsPR;
    if (recordPR.Details != null)
    {
        recordPR.Details.GetArray(level, detailsPR, sizeof(detailsPR));
    }

    CSDetails detailsSR;
    if (recordSR.Details != null)
    {
        recordSR.Details.GetArray(level, detailsSR, sizeof(detailsSR));
    }

    eCompareLocation eLocation = fuckTimer_GetClientCompareLocation(client);

    char sSpeed[MAX_SETTING_VALUE_LENGTH];
    fuckTimer_GetClientSetting(client, "HUDSpeed", sSpeed);
    eHUDSpeed eSpeed = view_as<eHUDSpeed>(StringToInt(sSpeed));
    float fClientSpeed = GetClientSpeed(client, eSpeed);

    if (eLocation == CLChat || eLocation == CLBoth)
    {
        CompareChat_EnterZone(client, recordPR, recordSR, eReturn, eAgainst, eMode, bonus, level, type, eSpeed, time, timeInZone, attempts, fClientSpeed);
    }

    if (eLocation == CLHUD || eLocation == CLBoth)
    {
        CSDetails details;
        if (eReturn != CANONE)
        {
            if (eAgainst == CAPR)
            {
                if (recordPR.Details == null)
                {
                    return;
                }
                
                details = detailsPR;
            }
            else if (eAgainst == CASR)
            {
                if (recordSR.Details == null)
                {
                    return;
                }
                
                details = detailsSR;
            }
        }

        float fRecordSpeed = GetVelocitySpeed(type == TimeCheckpoint ? details.StartVelocity : details.EndVelocity, eSpeed);

        CompareHUD_EnterZone(client, details, eMode, type, time, fClientSpeed, fRecordSpeed);
    }
}

public void fuckTimer_OnClientTimerEnd(int client, StringMap timemap)
{
    eCompareAgainst eAgainst = fuckTimer_GetClientCompareAgainst(client);

    int iBonus;
    timemap.GetValue("Level", iBonus);

    Styles sStyle;
    timemap.GetValue("StyleId", view_as<int>(sStyle));

    float fTime;
    timemap.GetValue("Time", fTime);

    RecordData recordPR;
    RecordData recordSR;
    eCompareAgainst eReturn = GetRecord(client, sStyle, iBonus, eAgainst, recordPR, recordSR);

    char sSpeed[MAX_SETTING_VALUE_LENGTH];
    fuckTimer_GetClientSetting(client, "HUDSpeed", sSpeed);
    eHUDSpeed eSpeed = view_as<eHUDSpeed>(StringToInt(sSpeed));

    float fClientSpeed = GetClientSpeed(client, eSpeed);

    eCompareLocation eLocation = fuckTimer_GetClientCompareLocation(client);
    eCompareMode eMode = fuckTimer_GetClientCompareMode(client);

    if (eLocation == CLChat || eLocation == CLBoth)
    {
        CompareChat_TimerEnd(client, timemap, eMode, eAgainst, iBonus, fTime, recordPR, recordSR, eReturn, eSpeed, fClientSpeed);
    }

    if (eLocation == CLHUD || eLocation == CLBoth)
    {
        RecordData record;
        if (eReturn != CANONE)
        {
            if (eAgainst == CAPR)
            {
                record = recordPR;
            }
            else if (eAgainst == CASR)
            {
                record = recordSR;
            }
        }
        else
        {
            return;
        }

        float fRecordSpeed = GetVelocitySpeed(record.EndVelocity, eSpeed);

        CompareHUD_TimerEnd(client, fTime, eMode, record, eReturn, fRecordSpeed, fClientSpeed);
    }

}

public void fuckTimer_OnNewRecord(int client, bool serverRecord, StringMap recordDetails, float oldTime)
{
    LogMessage("fuckTimer_OnNewRecord");
    
    LoadServerRecordCount();
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
    char sMessage[2048];
    VFormat(sMessage, sizeof(sMessage), format, 3);
    Format(sMessage, sizeof(sMessage), "</font> %s%s", Core.Title, sMessage);

    for(int i = strlen(sMessage); i < sizeof(sMessage)-1; i++)
    {
        sMessage[i] = ' ';
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

void GetTimeBySeconds(int client = 0, float seconds, char[] time, int length, eHUDTime format = HTMinimal, bool show0Hours = false)
{
    if (client > 0)
    {
        char sSetting[MAX_SETTING_VALUE_LENGTH];

        fuckTimer_GetClientSetting(client, "HUDTime", sSetting);
        format = view_as<eHUDTime>(StringToInt(sSetting));

        fuckTimer_GetClientSetting(client, "HUDShowTime0Hours", sSetting);
        show0Hours = StringToBool(sSetting);
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
    Player[client].Reset(true, true);

    if (!IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client))
    {
        return;
    }

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "PlayerHud/PlayerId/%d", GetSteamAccountID(client));
    fuckTimer_NewAPIHTTPRequest(sEndpoint).Get(GetPlayerHudSettings, GetClientUserId(client));
}

void CompareChat_LeaveZone(int client, bool startZone, int level, eCompareAgainst eReturn, RecordData recordPR, RecordData recordSR, bool isCheckpoint, float velocity[3], eCompareAgainst against, eCompareMode mode, eHUDSpeed speed)
{
    char sUnit[4];
    fuckTimer_GetClientSetting(client, "HUDShowSpeedUnit", sUnit);

    float fClientSpeed = GetVelocitySpeed(velocity, speed);

    char sType[12];
    if (startZone)
    {
        FormatEx(sType, sizeof(sType), "Start");
    }
    else if (level > 1)
    {
        FormatEx(sType, sizeof(sType), "%s %d", isCheckpoint ? "Checkpoint" : "Stage", level);
    }

    char sSpeed[128];
    if (eReturn != CANONE)
    {
        char sRecordType[4];
        if (eReturn == CAPR && against == CAPR)
        {
            FormatEx(sRecordType, sizeof(sRecordType), "PR");
        }
        else if (eReturn == CASR)
        {
            FormatEx(sRecordType, sizeof(sRecordType), "SR");
        }

        if (against == CAPR || against == CASR)
        {
            RecordData record;
            CSDetails recordDetails;

            if (against == CAPR && recordPR.Details != null)
            {
                recordPR.Details.GetArray(level, recordDetails, sizeof(recordDetails));
                record = recordPR;
            }
            else if (against == CASR && recordSR.Details != null)
            {
                recordSR.Details.GetArray(level, recordDetails, sizeof(recordDetails));
                record = recordSR;
            }

            float fRecordSpeed = GetVelocitySpeed(startZone ? record.StartVelocity : recordDetails.EndVelocity, speed);

            if (mode == CMFull)
            {
                FormatEx(sSpeed, sizeof(sSpeed), " (%s: %s%.0f%s{default})", sRecordType, fClientSpeed >= fRecordSpeed ? "{green}" : "{darkred}", fRecordSpeed, (StringToBool(sUnit) ? " u/s" : ""));
            }
            else
            {
                FormatEx(sSpeed, sizeof(sSpeed), " (%s: %s%.0f%s{default})", sRecordType, fClientSpeed >= fRecordSpeed ? "{green}" : "{darkred}", fRecordSpeed - fClientSpeed, (StringToBool(sUnit) ? " u/s" : ""));
            }
        }
        else if (against == CABoth)
        {
            CSDetails recordDetailsPR;
            if (recordPR.Details != null)
            {
                recordPR.Details.GetArray(level, recordDetailsPR, sizeof(recordDetailsPR));
            }

            CSDetails recordDetailsSR;
            if (recordSR.Details != null)
            {
                recordSR.Details.GetArray(level, recordDetailsSR, sizeof(recordDetailsSR));
            }

            float fRecordSpeed = GetVelocitySpeed(startZone ? recordPR.StartVelocity : recordDetailsPR.EndVelocity, speed);
            float fServerRecordSpeed = GetVelocitySpeed(startZone ? recordSR.StartVelocity : recordDetailsSR.EndVelocity, speed);

            if (mode == CMFull)
            {
                FormatEx(sSpeed, sizeof(sSpeed), " (SR: %s%.0f%s{default}, PR: %s%.0f%s{default})", fClientSpeed >= fServerRecordSpeed ? "{green}" : "{darkred}", fServerRecordSpeed, (StringToBool(sUnit) ? " u/s" : ""), fClientSpeed >= fRecordSpeed ? "{green}" : "{darkred}", fRecordSpeed, (StringToBool(sUnit) ? " u/s" : ""));
            }
            else
            {
                FormatEx(sSpeed, sizeof(sSpeed), " (SR: %s%.0f%s{default}, PR: %s%.0f%s{default})", fClientSpeed >= fServerRecordSpeed ? "{green}" : "{darkred}", fServerRecordSpeed - fClientSpeed, (StringToBool(sUnit) ? " u/s" : ""), fClientSpeed >= fRecordSpeed ? "{green}" : "{darkred}", fRecordSpeed - fClientSpeed, (StringToBool(sUnit) ? " u/s" : ""));
            }
        }
    }

    CPrintToChat(client, "%s: %.0f%s%s", sType, fClientSpeed, (StringToBool(sUnit) ? " u/s" : ""), sSpeed);
}

void CompareHUD_LeaveZone(int client, int level, bool start, float velocity[3], RecordData record, eCompareAgainst eReturn, eCompareMode mode, eHUDSpeed speed)
{
    if (eReturn == CANONE || record.Time <= 0.0)
    {
        return;
    }

    int iTime = fuckTimer_GetClientCompareTime(client);

    if (iTime <= 0)
    {
        return;
    }

    float fRecordSpeed;

    if (start)
    {
        fRecordSpeed = GetVelocitySpeed(record.StartVelocity, speed);
    }
    else
    {
        CSDetails details;
        
        if (record.Details == null)
        {
            return;
        }

        record.Details.GetArray(level, details, sizeof(details));
        fRecordSpeed = GetVelocitySpeed(details.StartVelocity, speed);
    }

    if (fRecordSpeed <= 0.0)
    {
        return;
    }

    if (mode == CMFull)
    {
        Player[client].CompareSpeedValue = fRecordSpeed;
    }
    else
    {
        float fClientSpeed = GetVelocitySpeed(velocity, speed);
        Player[client].CompareSpeedValue = fRecordSpeed - fClientSpeed;
    }

    Player[client].CompareSpeed = GetTime() + iTime;
}

void CompareHUD_EnterZone(int client, CSDetails details, eCompareMode mode, TimeType type, float time, float clientSpeed, float recordSpeed)
{
    if (mode == CMFull)
    {
        Player[client].CompareCSTimeValue = details.Time;
    }
    else if (mode == CMDifference)
    {
        Player[client].CompareCSTimeValue = time - details.Time;
    }

    int iTime = fuckTimer_GetClientCompareTime(client);

    if (iTime <= 0)
    {
        return;
    }

    Player[client].CompareCSTime = GetTime() + iTime;

    Player[client].CompareSpeed = GetTime() + iTime;

    if (type == TimeStage)
    {
        return;
    }

    char sSpeed[MAX_SETTING_VALUE_LENGTH];
    fuckTimer_GetClientSetting(client, "HUDSpeed", sSpeed);

    if (mode == CMFull)
    {
        Player[client].CompareSpeedValue = recordSpeed;
    }
    else
    {
        Player[client].CompareSpeedValue = recordSpeed - clientSpeed;
    }
}

void CompareChat_EnterZone(int client, RecordData recordPR, RecordData recordSR, eCompareAgainst eReturn, eCompareAgainst against, eCompareMode mode, int bonus, int level, TimeType type, eHUDSpeed speed, float time, float timeInZone, int attempts, float clientSpeed)
{
    char sUnit[4];
    fuckTimer_GetClientSetting(client, "HUDShowSpeedUnit", sUnit);

    char sTime[128];
    char sSpeed[128];
    char sAttempts[128];
    char sTimeInZone[128];

    if (eReturn != CANONE)
    {
        char sRecordType[4];
        if (eReturn == CAPR)
        {
            FormatEx(sRecordType, sizeof(sRecordType), "PR");
        }
        else if (eReturn == CASR)
        {
            FormatEx(sRecordType, sizeof(sRecordType), "SR");
        }

        if ((against == CAPR && recordPR.Details != null) || (against == CASR && recordSR.Details != null))
        {
            CSDetails recordDetails;

            if (against == CAPR && recordPR.Details != null)
            {
                recordPR.Details.GetArray(level, recordDetails, sizeof(recordDetails));
            }
            else if (against == CASR && recordSR.Details != null)
            {
                recordSR.Details.GetArray(level, recordDetails, sizeof(recordDetails));
            }

            float fRecordSpeed = GetVelocitySpeed(type == TimeCheckpoint ? recordDetails.StartVelocity : recordDetails.EndVelocity, speed);

            if (mode == CMFull)
            {
                FormatEx(sTime, sizeof(sTime), " (%s: %s%.3f{default})", sRecordType, time < recordDetails.Time ? "{green}" : "{darkred}", recordDetails.Time);

                if (type == TimeCheckpoint)
                {
                    FormatEx(sSpeed, sizeof(sSpeed), " (%s: %s%.0f%s{default})", sRecordType, clientSpeed >= fRecordSpeed ? "{green}" : "{darkred}", fRecordSpeed, (StringToBool(sUnit) ? " u/s" : ""));
                }
                else
                {
                    FormatEx(sAttempts, sizeof(sAttempts), " (%s: %s%d{default})", sRecordType, attempts <= recordDetails.Attempts ? "{green}" : "{darkred}", recordDetails.Attempts);
                    FormatEx(sTimeInZone, sizeof(sTimeInZone), " (%s: %s%.3f{default})", sRecordType, timeInZone < recordDetails.TimeInZone ? "{green}" : "{darkred}", recordDetails.TimeInZone);
                }
            }
            else
            {
                FormatEx(sTime, sizeof(sTime), " (%s: %s%.3f{default})", sRecordType, time < recordDetails.Time ? "{green}" : "{darkred}", time - recordDetails.Time);

                if (type == TimeCheckpoint)
                {
                    FormatEx(sSpeed, sizeof(sSpeed), " (%s: %s%.0f%s{default})", sRecordType, clientSpeed >= fRecordSpeed ? "{green}" : "{darkred}", fRecordSpeed - clientSpeed, (StringToBool(sUnit) ? " u/s" : ""));
                }
                else
                {
                    FormatEx(sAttempts, sizeof(sAttempts), " (%s: %s%d{default})", sRecordType, attempts <= recordDetails.Attempts ? "{green}" : "{darkred}", attempts - recordDetails.Attempts);
                    FormatEx(sTimeInZone, sizeof(sTimeInZone), " (%s: %s%.3f{default})", sRecordType, timeInZone < recordDetails.TimeInZone ? "{green}" : "{darkred}", timeInZone - recordDetails.TimeInZone);
                }
            }
        }
        else if (against == CABoth)
        {
            float fRecordSpeed = GetVelocitySpeed(type == TimeCheckpoint ? recordPR.StartVelocity : recordPR.EndVelocity, speed);
            float fServerRecordSpeed = GetVelocitySpeed(type == TimeCheckpoint ? recordSR.StartVelocity : recordSR.EndVelocity, speed);

            CSDetails recordDetailsPR;
            if (recordPR.Details != null)
            {
                recordPR.Details.GetArray(level, recordDetailsPR, sizeof(recordDetailsPR));
                fRecordSpeed = GetVelocitySpeed(type == TimeCheckpoint ? recordDetailsPR.StartVelocity : recordDetailsPR.EndVelocity, speed);
            }

            CSDetails recordDetailsSR;
            if (recordSR.Details != null)
            {
                recordSR.Details.GetArray(level, recordDetailsSR, sizeof(recordDetailsSR));
                fServerRecordSpeed = GetVelocitySpeed(type == TimeCheckpoint ? recordDetailsSR.StartVelocity : recordDetailsSR.EndVelocity, speed);
            }

            if (mode == CMFull)
            {
                FormatEx(sTime, sizeof(sTime), " (SR: %s%.3f{default}, PR: %s%.3f{default})", time < recordDetailsSR.Time ? "{green}" : "{darkred}", recordDetailsSR.Time, time < recordDetailsPR.Time ? "{green}" : "{darkred}", recordDetailsPR.Time);

                if (type == TimeCheckpoint)
                {
                    FormatEx(sSpeed, sizeof(sSpeed), " (SR: %s%.0f%s{default}, PR: %s%.0f%s{default})", clientSpeed >= fServerRecordSpeed ? "{green}" : "{darkred}", fServerRecordSpeed, (StringToBool(sUnit) ? " u/s" : ""), clientSpeed >= fRecordSpeed ? "{green}" : "{darkred}", fRecordSpeed, (StringToBool(sUnit) ? " u/s" : ""));
                }
                else
                {
                    FormatEx(sAttempts, sizeof(sAttempts), " (SR: %s%d{default}), (PR: %s%d{default})", attempts <= recordDetailsSR.Attempts ? "{green}" : "{darkred}", recordDetailsSR.Attempts, attempts <= recordDetailsPR.Attempts ? "{green}" : "{darkred}", recordDetailsPR.Attempts);
                    FormatEx(sTimeInZone, sizeof(sTimeInZone), " (SR: %s%.3f{default}, PR: %s%.3f{default})", timeInZone < recordDetailsSR.TimeInZone ? "{green}" : "{darkred}", recordDetailsSR.TimeInZone, timeInZone < recordDetailsPR.TimeInZone ? "{green}" : "{darkred}", recordDetailsPR.TimeInZone);
                }
            }
            else
            {
                FormatEx(sTime, sizeof(sTime), " (SR: %s%.3f{default}, PR: %s%.3f{default})", time < recordDetailsSR.Time ? "{green}" : "{darkred}", time - recordDetailsSR.Time, time < recordDetailsPR.Time ? "{green}" : "{darkred}", time - recordDetailsPR.Time);

                if (type == TimeCheckpoint)
                {
                    FormatEx(sSpeed, sizeof(sSpeed), " (SR: %s%.0f%s{default}, PR: %s%.0f%s{default})", clientSpeed >= fServerRecordSpeed ? "{green}" : "{darkred}", fServerRecordSpeed - clientSpeed, (StringToBool(sUnit) ? " u/s" : ""), clientSpeed >= fRecordSpeed ? "{green}" : "{darkred}", fRecordSpeed - clientSpeed, (StringToBool(sUnit) ? " u/s" : ""));
                }
                else
                {
                    FormatEx(sAttempts, sizeof(sAttempts), " (SR: %s%d{default}), (PR: %s%d{default})", attempts <= recordDetailsSR.Attempts ? "{green}" : "{darkred}", attempts - recordDetailsSR.Attempts, attempts <= recordDetailsPR.Attempts ? "{green}" : "{darkred}", attempts - recordDetailsPR.Attempts);
                    FormatEx(sTimeInZone, sizeof(sTimeInZone), " (SR: %s%.3f{default}, PR: %s%.3f{default})", timeInZone < recordDetailsSR.TimeInZone ? "{green}" : "{darkred}", timeInZone - recordDetailsSR.TimeInZone, timeInZone < recordDetailsPR.TimeInZone ? "{green}" : "{darkred}", timeInZone - recordDetailsPR.TimeInZone);
                }
            }
        }
    }

    CPrintToChat(client, "%s %s %d: %.3f%s", bonus ? " Bonus" : "", type == TimeCheckpoint ? "Checkpoint" : "Stage", level, time, sTime);
    
    if (type == TimeCheckpoint)
    {
        CPrintToChat(client, "Speed: %.0f%s%s", clientSpeed, (StringToBool(sUnit) ? " u/s" : ""), sSpeed);
    }
    else
    {
        CPrintToChat(client, "Attempts: %d%s", attempts, sAttempts);
        CPrintToChat(client, "Time in Zone: %.3f%s", timeInZone, sTimeInZone);
    }
}

void CompareHUD_TimerEnd(int client, float time, eCompareMode mode, RecordData record, eCompareAgainst eReturn, float recordSpeed, float clientSpeed)
{
    if (eReturn == CANONE || record.Time <= 0.0)
    {
        return;
    }

    if (mode == CMFull)
    {
        Player[client].CompareTimeValue = record.Time;
    }
    else if (mode == CMDifference)
    {
        Player[client].CompareTimeValue = time - record.Time;
    }

    int iTime = fuckTimer_GetClientCompareTime(client);

    if (iTime <= 0)
    {
        return;
    }

    Player[client].CompareTime = GetTime() + iTime;

    Player[client].CompareSpeed = GetTime() + iTime;

    if (mode == CMFull)
    {
        Player[client].CompareSpeedValue = recordSpeed;
    }
    else
    {
        
        Player[client].CompareSpeedValue = recordSpeed - clientSpeed;
    }
}

void CompareChat_TimerEnd(int client, StringMap timemap, eCompareMode mode, eCompareAgainst against, int level, float time, RecordData recordPR, RecordData recordSR, eCompareAgainst eReturn, eHUDSpeed eSpeed, float clientSpeed)
{
    char sUnit[4];
    fuckTimer_GetClientSetting(client, "HUDShowSpeedUnit", sUnit);

    int iAttempts;
    timemap.GetValue("Attempts", iAttempts);

    float fTimeInZone;
    timemap.GetValue("TimeInZone", fTimeInZone);

    char sTime[128];
    char sSpeed[128];
    char sAttempts[128];
    char sTimeInZone[128];

    char sRecordType[4];
    if (eReturn == CAPR)
    {
        FormatEx(sRecordType, sizeof(sRecordType), "PR");
    }
    else if (eReturn == CASR)
    {
        FormatEx(sRecordType, sizeof(sRecordType), "SR");
    }

    if ((against == CAPR && recordPR.Time > 0.0) || (against == CASR && recordSR.Time > 0.0))
    {
        RecordData record;
        if (against == CAPR)
        {
            record = recordPR;
        }
        else if (against == CASR)
        {
            record = recordSR;
        }

        float fRecordSpeed = GetVelocitySpeed(record.EndVelocity, eSpeed);
        
        if (mode == CMFull)
        {
            FormatEx(sTime, sizeof(sTime), " (%s: %s%.3f{default})", sRecordType, time < record.Time ? "{green}" : "{darkred}", record.Time);
            FormatEx(sSpeed, sizeof(sSpeed), " (%s: %s%.0f%s{default})", sRecordType, clientSpeed >= fRecordSpeed ? "{green}" : "{darkred}", fRecordSpeed, (StringToBool(sUnit) ? " u/s" : ""));
            FormatEx(sAttempts, sizeof(sAttempts), " (%s: %s%d{default})", sRecordType, iAttempts <= record.Attempts ? "{green}" : "{darkred}", record.Attempts);
            FormatEx(sTimeInZone, sizeof(sTimeInZone), " (%s: %s%.3f{default})", sRecordType, fTimeInZone < record.TimeInZone ? "{green}" : "{darkred}", record.TimeInZone);
        }
        else
        {
            FormatEx(sTime, sizeof(sTime), " (%s: %s%.3f{default})", sRecordType, time < record.Time ? "{green}" : "{darkred}", time - record.Time);
            FormatEx(sSpeed, sizeof(sSpeed), " (%s: %s%.0f%s{default})", sRecordType, clientSpeed >= fRecordSpeed ? "{green}" : "{darkred}", fRecordSpeed - clientSpeed, (StringToBool(sUnit) ? " u/s" : ""));
            FormatEx(sAttempts, sizeof(sAttempts), " (%s: %s%d{default})", sRecordType, iAttempts <= record.Attempts ? "{green}" : "{darkred}", iAttempts - record.Attempts);
            FormatEx(sTimeInZone, sizeof(sTimeInZone), " (%s: %s%.3f{default})", sRecordType, fTimeInZone < record.TimeInZone ? "{green}" : "{darkred}", fTimeInZone - record.TimeInZone);
        }
    }
    else if (against == CABoth)
    {
        float fRecordSpeed = GetVelocitySpeed(recordPR.EndVelocity, eSpeed);
        float fServerRecordSpeed = GetVelocitySpeed(recordSR.EndVelocity, eSpeed);

        if (mode == CMFull)
        {
            FormatEx(sTime, sizeof(sTime), " (SR: %s%.3f{default}, PR: %s%.3f{default})", time < recordSR.Time ? "{green}" : "{darkred}", recordSR.Time, time < recordPR.Time ? "{green}" : "{darkred}", recordPR.Time);
            FormatEx(sSpeed, sizeof(sSpeed), " (SR: %s%.0f%s{default}, PR: %s%.0f%s{default})", clientSpeed >= fServerRecordSpeed ? "{green}" : "{darkred}", fServerRecordSpeed, (StringToBool(sUnit) ? " u/s" : ""), clientSpeed >= fRecordSpeed ? "{green}" : "{darkred}", fRecordSpeed, (StringToBool(sUnit) ? " u/s" : ""));
            FormatEx(sAttempts, sizeof(sAttempts), " (SR: %s%d{default}), (PR: %s%d{default})", iAttempts <= recordSR.Attempts ? "{green}" : "{darkred}", recordSR.Attempts, iAttempts <= recordPR.Attempts ? "{green}" : "{darkred}", recordPR.Attempts);
            FormatEx(sTimeInZone, sizeof(sTimeInZone), " (SR: %s%.3f{default}, PR: %s%.3f{default})", fTimeInZone < recordSR.TimeInZone ? "{green}" : "{darkred}", recordSR.TimeInZone, fTimeInZone < recordPR.TimeInZone ? "{green}" : "{darkred}", recordPR.TimeInZone);
        }
        else
        {
            FormatEx(sTime, sizeof(sTime), " (SR: %s%.3f{default}, PR: %s%.3f{default})", time < recordSR.Time ? "{green}" : "{darkred}", time - recordSR.Time, time < recordPR.Time ? "{green}" : "{darkred}", time - recordPR.Time);
            FormatEx(sSpeed, sizeof(sSpeed), " (SR: %s%.0f%s{default}, PR: %s%.0f%s{default})", clientSpeed >= fServerRecordSpeed ? "{green}" : "{darkred}", fServerRecordSpeed - clientSpeed, (StringToBool(sUnit) ? " u/s" : ""), clientSpeed >= fRecordSpeed ? "{green}" : "{darkred}", fRecordSpeed - clientSpeed, (StringToBool(sUnit) ? " u/s" : ""));
            FormatEx(sAttempts, sizeof(sAttempts), " (SR: %s%d{default}), (PR: %s%d{default})", iAttempts <= recordSR.Attempts ? "{green}" : "{darkred}", iAttempts - recordSR.Attempts, iAttempts <= recordPR.Attempts ? "{green}" : "{darkred}", iAttempts - recordPR.Attempts);
            FormatEx(sTimeInZone, sizeof(sTimeInZone), " (SR: %s%.3f{default}, PR: %s%.3f{default})", fTimeInZone < recordSR.TimeInZone ? "{green}" : "{darkred}", fTimeInZone - recordSR.TimeInZone, fTimeInZone < recordPR.TimeInZone ? "{green}" : "{darkred}", fTimeInZone - recordPR.TimeInZone);
        }
    }

    char sBonus[24];

    if (level > 0)
    {
        FormatEx(sBonus, sizeof(sBonus), " for Bonus %d", level);
    }

    CPrintToChat(client, "Time%s: %.3f%s", sBonus, time, sTime);
    CPrintToChat(client, "Speed: %.0f%s%s", clientSpeed, (StringToBool(sUnit) ? " u/s" : ""), sSpeed);
    CPrintToChat(client, "Attempts: %d%s", iAttempts, sAttempts);
    CPrintToChat(client, "Time in Zone: %.3f%s", fTimeInZone, sTimeInZone);
}

eCompareAgainst GetRecord(int client, Styles style, int bonus, eCompareAgainst against, RecordData recordPR, RecordData recordSR)
{
    bool bSuccessPR = false;
    if (against == CAPR || against == CABoth)
    {
        bSuccessPR = fuckTimer_GetPlayerRecord(client, style, bonus, recordPR);
    }

    bool bSuccessSR = false;
    if (against == CASR || against == CABoth)
    {
        bSuccessSR = fuckTimer_GetServerRecord(style, bonus, recordSR);
    }

    if (bSuccessPR && bSuccessSR)
    {
        return CABoth;
    }
    else if (bSuccessPR)
    {
        return CAPR;
    }
    else if (bSuccessSR)
    {
        return CASR;
    }
    else
    {
        return CANONE;
    }
}

void LoadServerRecordCount()
{
    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Records/Count/MapId/%d", fuckTimer_GetCurrentMapId());
    fuckTimer_NewAPIHTTPRequest(sEndpoint).Get(GetRecordsCount);
}
