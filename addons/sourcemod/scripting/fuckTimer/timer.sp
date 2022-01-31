/**
 * Merge Checkpoint stuff from OnLeavingZone into OnEnteringZone
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <fuckZones>
#include <fuckTimer_players>
#include <fuckTimer_records>
#include <fuckTimer_stocks>
#include <fuckTimer_zones>
#include <fuckTimer_timer>
#include <fuckTimer_maps>

enum struct PlayerData
{
    int Checkpoint;
    int Stage;
    int Bonus;
    int Attempts;
    int Jumps;
    int Speed;
    int SpeedCount;
    int Validator;
    int Zone;

    bool MainRunning;
    bool CheckpointRunning;
    bool StageRunning;

    bool SetSpeed;
    bool BlockJump;
    bool BlockTeleport;

    // Sync
    int SyncCount;
    int GoodGains;
    float LastAngle;

    // Prestrafe
    int LastButtons;
    bool Prestrafe;

    float Time;
    float TimeInZone;

    // Variables for Offset calculation
    float Fraction;
    float Offset[OFFSET_MAX]; // 0 - Start, 1 - End
    bool GetOffset;
    float Origin1[3];
    float Origin2[3];

    float StartPosition[3];
    float StartAngle[3];
    float StartVelocity[3];

    float EndPosition[3];
    float EndAngle[3];
    float EndVelocity[3];

    IntMap StageDetails;
    IntMap CheckpointDetails;

    void Reset(bool noCheckpoint = false, bool resetTimeInZone = true, bool resetAttempts = true)
    {
        if (!noCheckpoint)
        {
            this.Checkpoint = 0;
        }

        this.Stage = 0;
        this.Bonus = 0;
        
        if (resetAttempts)
        {
            this.Attempts = 0;
        }

        this.Validator = 0;
        this.Zone = 0;
        this.Jumps = 0;

        // Sync
        this.SyncCount = 0;
        this.GoodGains = 0;
        this.LastAngle = 0.0;

        this.MainRunning = false;
        this.CheckpointRunning = false;
        this.StageRunning = false;

        this.SetSpeed = false;
        this.BlockJump = false;

        this.LastButtons = 0;
        this.Prestrafe = false;

        this.Time = 0.0;
        this.Speed = 0;
        this.SpeedCount = 0;

        if (resetTimeInZone)
        {
            this.TimeInZone = 0.0;
        }

        this.Fraction = 0.0;
        this.GetOffset = false;

#if SOURCEMOD_V_MINOR > 10
        this.Offset = { 0.0, 0.0 };
        this.Origin1 = {0.0, 0.0, 0.0};
        this.Origin2 = {0.0, 0.0, 0.0};
        this.StartPosition = {0.0, 0.0, 0.0};
        this.StartAngle = {0.0, 0.0, 0.0};
        this.StartVelocity = {0.0, 0.0, 0.0};
        this.EndPosition = {0.0, 0.0, 0.0};
        this.EndAngle = {0.0, 0.0, 0.0};
        this.EndVelocity = {0.0, 0.0, 0.0};
#else
        this.Offset[0] = 0.0; this.Offset[1] = 0.0;
        this.Origin1[0] = 0.0; this.Origin1[1] = 0.0; this.Origin1[2] = 0.0;
        this.Origin2[0] = 0.0; this.Origin2[1] = 0.0; this.Origin2[2] = 0.0;
        this.StartPosition[0] = 0.0; this.StartPosition[1] = 0.0; this.StartPosition[2] = 0.0;
        this.StartAngle[0] = 0.0; this.StartAngle[1] = 0.0; this.StartAngle[2] = 0.0;
        this.StartVelocity[0] = 0.0; this.StartVelocity[1] = 0.0; this.StartVelocity[2] = 0.0;
        this.EndPosition[0] = 0.0; this.EndPosition[1] = 0.0; this.EndPosition[2] = 0.0;
        this.EndAngle[0] = 0.0; this.EndAngle[1] = 0.0; this.EndAngle[2] = 0.0;
        this.EndVelocity[0] = 0.0; this.EndVelocity[1] = 0.0; this.EndVelocity[2] = 0.0;
#endif


        delete this.CheckpointDetails;
        delete this.StageDetails;
    }

    void AllowPrestrafe(bool status)
    {
        this.Prestrafe = status;
    }
}

PlayerData Player[MAXPLAYERS + 1];

enum struct PluginData
{
    IntMap Stages;
    IntMap Checkpoints;

    int Bonus;

    GlobalForward OnClientTimerStart;
    GlobalForward OnClientZoneTouchStart;
    GlobalForward OnClientZoneTouchEnd;
    GlobalForward OnClientTimerEnd;
}
PluginData Core;

#include "natives/timer.sp"

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "Timer",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    Core.OnClientTimerStart = new GlobalForward("fuckTimer_OnClientTimerStart", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    Core.OnClientZoneTouchStart = new GlobalForward("fuckTimer_OnClientZoneTouchStart", ET_Ignore, Param_Cell, Param_Cell,  Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Cell);
    Core.OnClientZoneTouchEnd = new GlobalForward("fuckTimer_OnClientZoneTouchEnd", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    Core.OnClientTimerEnd = new GlobalForward("fuckTimer_OnClientTimerEnd", ET_Ignore, Param_Cell, Param_Any);

    CreateNative("fuckTimer_GetClientTime", Native_GetClientTime);
    CreateNative("fuckTimer_IsClientTimeRunning", Native_IsClientTimeRunning);

    CreateNative("fuckTimer_GetClientTimeInZone", Native_GetClientTimeInZone);
    CreateNative("fuckTimer_GetClientAttempts", Native_GetClientAttempts);
    CreateNative("fuckTimer_GetClientSync", Native_GetClientSync);
    CreateNative("fuckTimer_GetClientAVGSpeed", Native_GetClientAVGSpeed);
    CreateNative("fuckTimer_GetClientJumps", Native_GetClientJumps);

    CreateNative("fuckTimer_GetClientCheckpoint", Native_GetClientCheckpoint);
    CreateNative("fuckTimer_GetClientStage", Native_GetClientStage);
    CreateNative("fuckTimer_GetClientBonus", Native_GetClientBonus);
    CreateNative("fuckTimer_GetClientValidator", Native_GetClientValidator);

    CreateNative("fuckTimer_GetAmountOfCheckpoints", Native_GetAmountOfCheckpoints);
    CreateNative("fuckTimer_GetAmountOfStages", Native_GetAmountOfStages);
    CreateNative("fuckTimer_GetAmountOfBonus", Native_GetAmountOfBonus);

    CreateNative("fuckTimer_ResetClientTimer", Native_ResetClientTimer);

    RegPluginLibrary("fuckTimer_timer");

    return APLRes_Success;
}

public void OnPluginStart()
{
    if (GetExtensionFileStatus("accelerator.ext") != 1)
    {
        SetFailState("Extension \"Accelerator\" not found!");
        return;
    }

    fuckTimer_LoopClients(client, false, false)
    {
        LoadPlayer(client);
    }

    HookEvent("round_poststart", Event_RoundReset);
    HookEvent("round_end", Event_RoundReset);
    HookEvent("player_activate", Event_PlayerActivate);
    HookEvent("player_jump", Event_PlayerJump);
}

public void OnAllPluginsLoaded()
{
    if (!LibraryExists("endtouchfix"))
    {
        SetFailState("Plugin \"End Touch Fix\" not found!");
        return;
    }
}

public void OnMapStart()
{
    delete Core.Stages;
    Core.Stages = new IntMap();
    
    delete Core.Checkpoints;
    Core.Checkpoints = new IntMap();
    
    Core.Bonus = 0;
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

public void OnClientDisconnect(int client)
{
    Player[client].Reset();
}

public void fuckZones_OnZoneCreate(int entity, const char[] zone_name, int type)
{
    StringMap smEffects = fuckZones_GetZoneEffects(entity);

    StringMap smValues;
    smEffects.GetValue(FUCKTIMER_EFFECT_NAME, smValues);

    StringMapSnapshot snap = smValues.Snapshot();

    char sKey[MAX_KEY_NAME_LENGTH];
    char sValue[MAX_KEY_VALUE_LENGTH];
    int iStage = 0;
    int iCheckpoint = 0;
    int iBonus = 0;

    if (snap != null)
    {
        for (int i = 0; i < snap.Length; i++)
        {
            snap.GetKey(i, sKey, sizeof(sKey));

            switch (sKey[0])
            {
                case 'B':
                {
                    smValues.GetString(sKey, sValue, sizeof(sValue));

                    iBonus = StringToInt(sValue);

                    if (iBonus > 0 && iBonus > Core.Bonus)
                    {
                        Core.Bonus = iBonus;
                    }
                }

                case 'S':
                {
                    if (GetfuckTimerZoneValue(smEffects, "Bonus", sValue, sizeof(sValue)))
                    {
                        iBonus = StringToInt(sValue);
                    }

                    smValues.GetString(sKey, sValue, sizeof(sValue));

                    iStage = StringToInt(sValue);

                    if (iStage > 0 && iStage > Core.Stages.GetInt(iBonus))
                    {
                        Core.Stages.SetValue(iBonus, iStage);
                    }
                }

                case 'C':
                {
                    if (GetfuckTimerZoneValue(smEffects, "Bonus", sValue, sizeof(sValue)))
                    {
                        iBonus = StringToInt(sValue);
                    }

                    if (Core.Checkpoints.GetInt(iBonus) == -1)
                    {
                        Core.Checkpoints.SetValue(iBonus, 0);
                    }
                    
                    if (Core.Checkpoints.GetInt(iBonus) == 1)
                    {
                        Core.Checkpoints.SetValue(iBonus, 2); // If we've a checkpoint map here, add one additional checkpoint more for the end zone as workaround without adding/changing each map zone config.
                    }

                    smValues.GetString(sKey, sValue, sizeof(sValue));

                    iCheckpoint = StringToInt(sValue);

                    if (iCheckpoint > 0 && iCheckpoint > Core.Checkpoints.GetInt(iBonus))
                    {
                        Core.Checkpoints.SetValue(iBonus, Core.Checkpoints.GetInt(iBonus) + 1);
                    }
                }
            }

            iCheckpoint = 0;
            iStage = 0;
            iBonus = 0;
        }
    }

    delete snap;
}

public Action Event_RoundReset(Event event, const char[] name, bool dontBroadcast)
{
    fuckTimer_LoopClients(client, false, false)
    {
        Player[client].Reset();
    }
    
    return Plugin_Continue;
}

public Action Event_PlayerActivate(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    LoadPlayer(client);
    
    return Plugin_Continue;
}

public Action Event_PlayerJump(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (fuckTimer_IsClientValid(client))
    {
        if (fuckTimer_GetCurrentMapStatus() == msInactive || fuckTimer_GetClientStatus(client) == psInactive)
        {
            return Plugin_Continue;
        }

        if (Player[client].MainRunning)
        {
            Player[client].Jumps++;
        }

        if (Player[client].CheckpointRunning)
        {
            SetIntMapJumps(Player[client].CheckpointDetails, Player[client].Checkpoint, 1);
        }
        else if (Player[client].StageRunning)
        {
            SetIntMapJumps(Player[client].StageDetails, Player[client].Stage, 1);
        }
    }

    return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    if (fuckTimer_GetCurrentMapStatus() == msInactive || fuckTimer_GetClientStatus(client) == psInactive)
    {
        return Plugin_Continue;
    }

    for (int i = 0; i < 25; i++)
    {
        int button = (1 << i);

        if ((buttons & button))
        {
            if (!(Player[client].LastButtons & button))
            {
                OnButtonPress(client, button);
            }
        }
    }

    Player[client].LastButtons = buttons;

    if (!Player[client].MainRunning)
    {
        return Plugin_Continue;
    }

    if (IsPlayerAlive(client))
    {
        if (Player[client].SetSpeed && !Player[client].Prestrafe)
        {
            int iMaxSpeed = fuckTimer_GetZonePreSpeed(Player[client].Zone);

            SetClientSpeed(client, iMaxSpeed);
        }

        if (Player[client].BlockJump && buttons & IN_JUMP)
        {
            buttons &= ~IN_JUMP;
            return Plugin_Changed;
        }

        // Thanks to bhoptimer for this code.
        // Source:  https://github.com/shavitush/bhoptimer/blob/d86ac3f434b532f850a059dde3a62399860172dc/addons/sourcemod/scripting/shavit-core.sp#L4045-L4066
        float fAngle = GetAngleDiff(angles[1], Player[client].LastAngle);
        if (GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1 && (GetEntityFlags(client) & FL_INWATER) == 0 && fAngle != 0.0)
        {
            float fAbsVelocity[3];
            GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);

            if (GetClientSpeed(client) > 0.0)
            {
                float fTempAngle = angles[1];

                float fAngles[3];
                GetVectorAngles(fAbsVelocity, fAngles);

                if (fTempAngle < 0.0)
                {
                    fTempAngle += 360.0;
                }

                TestAngles(client, (fTempAngle - fAngles[1]), fAngle, vel);
            }
        }

        Player[client].LastAngle = angles[1];
    }

    return Plugin_Continue;
}

void OnButtonPress(int client, int button)
{
    if (button & IN_JUMP)
    {
        // Check if client is in a zone who we'll set the speed
        if (!Player[client].SetSpeed)
        {
            return;
        }

        Player[client].AllowPrestrafe(true);
    }
}

public void fuckTimer_OnEnteringZone(int client, int zone, const char[] name)
{
    if (!IsPlayerAlive(client))
    {
        return;
    }
    
    if (fuckTimer_GetCurrentMapStatus() == msInactive || fuckTimer_GetClientStatus(client) == psInactive)
    {
        return;
    }

    Player[client].Zone = zone;

    int iBonus = 0;
    float fClientSpeed = GetClientSpeed(client);
    int iPreSpeed = fuckTimer_GetZonePreSpeed(zone);
    int iMaxSpeed = fuckTimer_GetZoneMaxSpeed(zone);

    if (iMaxSpeed > 0 && fClientSpeed > view_as<float>(iMaxSpeed))
    {
        SetClientSpeed(client, iMaxSpeed);
    }

    if (fuckTimer_IsStartZone(zone, iBonus) && !fuckTimer_IsMiscZone(zone, iBonus))
    {
        SetClientStartValues(client, iBonus);
        Player[client].AllowPrestrafe(false);

        if (iPreSpeed > 0 && fClientSpeed > view_as<float>(iPreSpeed))
        {
            SetClientSpeed(client, iPreSpeed);
        }

        return;
    }

    if (fuckTimer_IsMiscZone(zone, iBonus))
    {
        if (fuckTimer_IsStopZone(zone, iBonus))
        {
            Player[client].Reset();

            Call_StartForward(Core.OnClientZoneTouchStart);
            Call_PushCell(client);
            Call_PushCell(view_as<int>(true));
            Call_PushCell(iBonus);
            Call_PushCell(0);
            Call_PushCell(0);
            Call_PushFloat(0.0);
            Call_PushFloat(0.0);
            Call_PushCell(0);
            Call_Finish();
            
            return;
        }

        if (fuckTimer_IsTeleToStartZone(zone, iBonus) && !Player[client].BlockTeleport)
        {
            bool bStart = fuckTimer_IsStartZone(zone, iBonus);

            int iZone = bStart ? fuckTimer_GetStartZone(iBonus) : fuckTimer_GetStageZone(Player[client].Bonus, Player[client].Stage);

            if (bStart)
            {
                Player[client].Reset();

                Call_StartForward(Core.OnClientZoneTouchStart);
                Call_PushCell(client);
                Call_PushCell(view_as<int>(true));
                Call_PushCell(iBonus);
                Call_PushCell(0);
                Call_PushCell(0);
                Call_PushFloat(0.0);
                Call_PushFloat(0.0);
                Call_PushCell(0);
                Call_Finish();
            }

            if (iZone > 0)
            {
                fuckTimer_TeleportEntityToZone(client, iZone);

                Player[client].BlockTeleport = true;
            }

            return;
        }

        if (fuckTimer_IsAntiJumpZone(zone, iBonus))
        {
            Player[client].BlockJump = true;
        }

        int iValidators;
        if (fuckTimer_IsCheckerZone(zone, iBonus, iValidators) && !Player[client].BlockTeleport)
        {
            if (iBonus == Player[client].Bonus && iValidators > 0 && Player[client].Validator >= iValidators)
            {
                return;
            }

            int iZone = fuckTimer_GetStageZone(Player[client].Bonus, Player[client].Stage);

            if (iZone > 0)
            {
                fuckTimer_TeleportEntityToZone(client, iZone);

                Player[client].BlockTeleport = true;
            }
            
            return;
        }

        if (fuckTimer_IsValidatorZone(zone, Player[client].Bonus))
        {
            Player[client].Validator++;
        }

        return;
    }

    int iStage = fuckTimer_GetStageByIndex(zone, iBonus);
    if (fuckTimer_IsEndZone(zone, Player[client].Bonus) && iStage < 1 && Player[client].Stage > 0)
    {
        Player[client].Stage++;
        iStage = Player[client].Stage;
    }

    CSDetails details;

    char sBuffer[MAX_NAME_LENGTH];
    Styles style = fuckTimer_GetClientStyle(client);
    
    if (Player[client].StageRunning && iStage > 0)
    {
        if (iPreSpeed > 0 && fClientSpeed > view_as<float>(iPreSpeed))
        {
            SetClientSpeed(client, iPreSpeed);
        }

        Player[client].Validator = 0;
        Player[client].SetSpeed = true;

        Player[client].Stage = iStage;
        Player[client].AllowPrestrafe(false);

        // That isn't really an workaround or dirty fix but... 
        // with this check we're able to start the stage timer
        // and just count the stage times. So you don't need to
        // restart the whole timer from the first stage to your
        // selected or current stage.
        if (Player[client].StageDetails == null)
        {
            Player[client].StageDetails = new IntMap();
            return;
        }

        Player[client].StageDetails.GetArray(iStage, details, sizeof(details));

        if (details.Time > 0.0)
        {
            SetIntMapTime(Player[client].StageDetails, iStage, 0.0);
            return;
        }

        int iPrevStage = iStage - 1;

        if (iPrevStage < 1)
        {
            iPrevStage = 1;
        }

        Player[client].StageDetails.GetArray(iPrevStage, details, sizeof(details));
        CalculateTickIntervalOffsetCS(client, Player[client].StageDetails, iPrevStage, true);
        details.Time += GetIntMapOffset(Player[client].StageDetails, iPrevStage, OFFSET_START);
        details.Time -= GetTickInterval();
        details.Time += GetIntMapOffset(Player[client].StageDetails, iPrevStage, OFFSET_END);
        Player[client].StageDetails.SetArray(iPrevStage, details, sizeof(details));

        Player[client].StageRunning = false;

        SetIntMapAttempts(Player[client].StageDetails, iPrevStage, Player[client].Attempts);
        SetIntMapTimeInZone(Player[client].StageDetails, iPrevStage, Player[client].TimeInZone);
        SetIntMapPositionAngleVelocity(client, Player[client].StageDetails, iPrevStage, false);

        Call_StartForward(Core.OnClientZoneTouchStart);
        Call_PushCell(client);
        Call_PushCell(view_as<int>(false));
        Call_PushCell(iBonus);
        Call_PushCell(TimeStage);
        Call_PushCell(iPrevStage);
        Call_PushFloat(details.Time);
        Call_PushFloat(Player[client].TimeInZone);
        Call_PushCell(Player[client].Attempts);
        Call_Finish();
        
        if (!fuckTimer_IsEndZone(zone, Player[client].Bonus))
        {
            Player[client].Attempts = 0;
            Player[client].TimeInZone = 0.0;
        }
    }

    // Fix for missing checkpoint entry in end zone
    int iCheckpoint = fuckTimer_GetCheckpointByIndex(zone, iBonus);
    if (fuckTimer_IsEndZone(zone, Player[client].Bonus) && iCheckpoint < 1 && Player[client].Checkpoint > 0)
    {
        // Player[client].Checkpoint++;
        iCheckpoint = Player[client].Checkpoint;
    }
    
    if (Player[client].CheckpointRunning && iCheckpoint > 0)
    {
        if (Player[client].CheckpointDetails == null)
        {
            return;
        }
        
        iCheckpoint = Player[client].Checkpoint + 1;
        Player[client].Stage = 0;

        Player[client].CheckpointDetails.GetArray(iCheckpoint, details, sizeof(details));

        if (details.Time > 0.0)
        {
            SetIntMapTime(Player[client].CheckpointDetails, iCheckpoint, 0.0);
        }

        int iPrevCheckpoint = iCheckpoint - 1;

        if (iPrevCheckpoint < 0)
        {
            iPrevCheckpoint = 0;
        }

        Player[client].CheckpointDetails.GetArray(iPrevCheckpoint, details, sizeof(details));

        if (iPrevCheckpoint > Core.Checkpoints.GetInt(iBonus))
        {
            iPrevCheckpoint = Core.Checkpoints.GetInt(iBonus);
        }

        CalculateTickIntervalOffsetCS(client, Player[client].CheckpointDetails, iPrevCheckpoint, true);
        details.Time += GetIntMapOffset(Player[client].CheckpointDetails, iPrevCheckpoint, OFFSET_START);
        details.Time -= GetTickInterval();
        details.Time += GetIntMapOffset(Player[client].CheckpointDetails, iPrevCheckpoint, OFFSET_END);
        Player[client].CheckpointDetails.SetArray(iPrevCheckpoint, details, sizeof(details));

        SetIntMapTime(Player[client].CheckpointDetails, iPrevCheckpoint, details.Time, false);
        SetIntMapPositionAngleVelocity(client, Player[client].CheckpointDetails, iPrevCheckpoint, false, true);

        Player[client].CheckpointRunning = false;

        Call_StartForward(Core.OnClientZoneTouchStart);
        Call_PushCell(client);
        Call_PushCell(view_as<int>(false));
        Call_PushCell(iBonus);
        Call_PushCell(TimeCheckpoint);
        Call_PushCell(iPrevCheckpoint);
        Call_PushFloat(details.Time);
        Call_PushFloat(0.0);
        Call_PushCell(0);
        Call_Finish();

        if (fuckTimer_IsEndZone(zone, Player[client].Bonus))
        {
            Player[client].Checkpoint++;
        }
    }
    
    int bonus = fuckTimer_GetZoneBonus(zone);
    
    if (Player[client].MainRunning && fuckTimer_IsEndZone(zone, Player[client].Bonus) && Player[client].Time > 0.0)
    {
        CalculateTickIntervalOffset(client, true);

        Player[client].Time += Player[client].Offset[OFFSET_START];
        Player[client].Time -= GetTickInterval();
        Player[client].Time += Player[client].Offset[OFFSET_END];

        GetClientPosition(client, Player[client].EndPosition);
        GetClientAngle(client, Player[client].EndAngle);
        GetClientVelocity(client, Player[client].EndVelocity);

        StringMap map = new StringMap();
        map.SetValue("MapId", fuckTimer_GetCurrentMapId());
        map.SetValue("PlayerId", GetSteamAccountID(client));

        GetClientName(client, sBuffer, sizeof(sBuffer));
        map.SetString("PlayerName", sBuffer);

        map.SetValue("StyleId", style);
        map.SetValue("Level", Player[client].Bonus);
        
        if (Player[client].CheckpointDetails != null)
        {
            map.SetValue("Type", TimeCheckpoint);
            map.SetValue("Details", CloneHandle(Player[client].CheckpointDetails));
        }
        else if (Player[client].StageDetails != null)
        {
            map.SetValue("Type", TimeStage);

            int iPoint;
            IntMapSnapshot snap = Player[client].StageDetails.Snapshot();

            for (int i = 0; i < snap.Length; i++)
            {
                iPoint = snap.GetKey(i);

                Player[client].StageDetails.GetArray(iPoint, details, sizeof(details));

                Player[client].TimeInZone += details.TimeInZone;
                Player[client].Attempts += details.Attempts;
                
                if (iPoint > 1)
                {
                    Player[client].Attempts--;
                }
            }
            
            map.SetValue("TimeInZone", Player[client].TimeInZone);
            map.SetValue("Attempts", Player[client].Attempts);

            delete snap;

            map.SetValue("Details", CloneHandle(Player[client].StageDetails));
        }
        else
        {
            map.SetValue("Type", TimeMain);
            map.SetValue("Details", 0);
        }

        map.SetValue("Tickrate", GetServerTickrate());
        map.SetValue("Time", Player[client].Time);
        map.SetValue("TimeInZone", Player[client].TimeInZone);
        map.SetValue("Attempts", Player[client].Attempts);
        map.SetValue("Sync", fuckTimer_GetClientSync(client, Player[client].Bonus));
        map.SetValue("Speed", Player[client].Speed / Player[client].SpeedCount);
        map.SetValue("Jumps", Player[client].Jumps);
        map.SetArray("StartPosition", Player[client].StartPosition, 3);
        map.SetArray("StartAngle", Player[client].StartAngle, 3);
        map.SetArray("StartVelocity", Player[client].StartVelocity, 3);
        map.SetArray("EndPosition", Player[client].EndPosition, 3);
        map.SetArray("EndAngle", Player[client].EndAngle, 3);
        map.SetArray("EndVelocity", Player[client].EndVelocity, 3);

        Call_StartForward(Core.OnClientTimerEnd);
        Call_PushCell(client);
        Call_PushCell(view_as<int>(map));
        Call_Finish();

        RequestFrame(Frame_DeleteStringMap, map);
        
        Player[client].MainRunning = false;

        Player[client].Reset(true);
        Player[client].Bonus = bonus;
    }
}

public void Frame_DeleteStringMap(StringMap map)
{
    IntMap details;
    map.GetValue("Details", details);
    delete details;
    
    delete map;
}

public void fuckTimer_OnTouchZone(int client, int zone, const char[] name)
{
    if (!IsPlayerAlive(client))
    {
        return;
    }

    if (fuckTimer_GetCurrentMapStatus() == msInactive || fuckTimer_GetClientStatus(client) == psInactive)
    {
        return;
    }

    Player[client].Zone = zone;
    Player[client].Bonus = fuckTimer_GetZoneBonus(Player[client].Zone);

    int iBonus = 0;
    bool bStart = fuckTimer_IsStartZone(Player[client].Zone, iBonus);
    bool bEnd = fuckTimer_IsEndZone(Player[client].Zone, iBonus);
    int iStage = fuckTimer_GetStageByIndex(Player[client].Zone, iBonus);

    if (iStage > 0)
    {
        Player[client].Stage = iStage;
    }

    if (bEnd)
    {
        Player[client].Stage = Core.Stages.GetInt(iBonus);
    }

    if (Player[client].Time == 0.0)
    {
        Player[client].TimeInZone += GetTickInterval();

        // We need to check this here, otherwise set speed can be abused
        if (!fuckTimer_IsMiscZone(Player[client].Zone, iBonus) && iStage > 0)
        {
            Player[client].SetSpeed = true;
        }

        return;
    }
    
    if (bStart)
    {
        SetClientStartValues(client, iBonus);
    }

    int iCheckpoint = fuckTimer_GetCheckpointByIndex(zone, iBonus);

    if (!fuckTimer_IsMiscZone(Player[client].Zone, iBonus) && iStage > 0)
    {
        Player[client].SetSpeed = true;
        Player[client].StageRunning = false;
        SetIntMapTime(Player[client].StageDetails, iStage, 0.0);
        Player[client].TimeInZone += GetTickInterval();
    }

    if (!fuckTimer_IsMiscZone(Player[client].Zone, iBonus) && iCheckpoint > 0)
    {
        Player[client].CheckpointRunning = false;
        SetIntMapTime(Player[client].CheckpointDetails, iCheckpoint, 0.0);
    }

    if (fuckTimer_IsAntiJumpZone(Player[client].Zone, iBonus))
    {
        Player[client].BlockJump = true;
    }
}

public void fuckTimer_OnClientCommand(int client, int level, bool start)
{
    Player[client].Reset();
}

public void fuckTimer_OnLeavingZone(int client, int zone, const char[] name)
{
    if (!IsPlayerAlive(client))
    {
        return;
    }

    if (fuckTimer_GetCurrentMapStatus() == msInactive || fuckTimer_GetClientStatus(client) == psInactive)
    {
        return;
    }
    
    int bonus = fuckTimer_GetZoneBonus(zone);
    if (Player[client].Zone != zone)
    {
        return;
    }
    
    Player[client].SetSpeed = false;
    Player[client].BlockJump = false;

    bool bSkipAttempts = false;

    if (fuckTimer_IsStartZone(zone, bonus) && !fuckTimer_IsMiscZone(zone, bonus))
    {
        Player[client].Reset(.resetTimeInZone = false, .resetAttempts = false);
        Player[client].AllowPrestrafe(false);

        int iSpeed = RoundToNearest(GetClientSpeed(client));
        Player[client].Speed = iSpeed;
        Player[client].SpeedCount = 1;

        Player[client].Bonus = bonus;
        Player[client].MainRunning = true;
        Player[client].GetOffset = true;

        GetClientPosition(client, Player[client].StartPosition);
        GetClientAngle(client, Player[client].StartAngle);
        GetClientVelocity(client, Player[client].StartVelocity);

        bool bStage = (Core.Stages.GetInt(bonus) > 0);

        if (bStage)
        {
            if (Player[client].StageDetails == null)
            {
                Player[client].StageDetails = new IntMap();
            }

            Player[client].Stage = 1;
            Player[client].StageRunning = true;
            SetIntMapTime(Player[client].StageDetails, Player[client].Stage, 0.0);
            SetIntMapPositionAngleVelocity(client, Player[client].StageDetails, Player[client].Stage, true);
            SetIntMapSpeed(Player[client].StageDetails, Player[client].Stage, iSpeed, false);
        }

        if (Core.Checkpoints.GetInt(bonus) > 0)
        {
            if (Player[client].CheckpointDetails == null)
            {
                Player[client].CheckpointDetails = new IntMap();
            }

            Player[client].Checkpoint = 1;
            Player[client].CheckpointRunning = true;
            SetIntMapTime(Player[client].CheckpointDetails, Player[client].Checkpoint, 0.0);
            SetIntMapPositionAngleVelocity(client, Player[client].CheckpointDetails, Player[client].Checkpoint - 1, true, true);
            SetIntMapSpeed(Player[client].CheckpointDetails, Player[client].Checkpoint, iSpeed, false);
        }

        if (Player[client].Attempts < 0)
        {
            Player[client].Attempts = 0;
            bSkipAttempts = true;
        }

        Player[client].BlockTeleport = false;
    }

    int iStage = fuckTimer_GetStageByIndex(zone, Player[client].Bonus);
    if (iStage > 1 && Player[client].StageDetails != null)
    {
        if (Player[client].Stage < iStage)
        {
            Player[client].Attempts = 0;
        }

        Player[client].AllowPrestrafe(false);
        
        Player[client].Stage = iStage;
        Player[client].StageRunning = true;
        SetIntMapTime(Player[client].StageDetails, Player[client].Stage, 0.0);
        SetIntMapPositionAngleVelocity(client, Player[client].StageDetails, Player[client].Stage, true);
        SetIntMapGetOffset(Player[client].StageDetails, Player[client].Stage, true);

        Player[client].BlockTeleport = false;
    }

    int iCheckpoint = fuckTimer_GetCheckpointByIndex(zone, Player[client].Bonus);
    if (iCheckpoint > 1 && Player[client].CheckpointDetails != null)
    {
        Player[client].Checkpoint++;
        Player[client].CheckpointRunning = true;
        // ???
        // SetIntMapTime(Player[client].CheckpointDetails, Player[client].Checkpoint, 0.0);
        // SetIntMapPositionAngleVelocity(client, Player[client].CheckpointDetails, Player[client].Checkpoint, true, true);
        // SetIntMapGetOffset(Player[client].CheckpointDetails, Player[client].Checkpoint, true);
        
        Player[client].BlockTeleport = false;
    }

    if (Player[client].MainRunning)
    {
        Call_StartForward(Core.OnClientTimerStart);
        Call_PushCell(client);
        Call_PushCell(Player[client].Bonus);

        if (!bSkipAttempts && iCheckpoint == 0)
        {
            Player[client].Attempts++;
        }

        if (Player[client].Checkpoint > 0)
        {
            Call_PushCell(TimeCheckpoint);
            Call_PushCell(Player[client].Checkpoint);
        }
        else if (Player[client].Stage > 0)
        {
            Call_PushCell(TimeStage);
            Call_PushCell(Player[client].Stage);
        }
        else
        {
            Call_PushCell(TimeMain);
            Call_PushCell(0);
        }

        Call_Finish();
    }

    Call_StartForward(Core.OnClientZoneTouchEnd);
    Call_PushCell(client);
    Call_PushCell(Player[client].Bonus);

    if (Player[client].CheckpointRunning)
    {
        Call_PushCell(TimeCheckpoint);
        Call_PushCell(Player[client].Checkpoint);
    }
    if (Player[client].StageRunning)
    {
        Call_PushCell(TimeStage);
        Call_PushCell(Player[client].Stage);
    }

    Call_Finish();

    Player[client].Zone = 0;
}

public Action OnPostThinkPost(int client)
{
    if (client < 1 || IsFakeClient(client) || IsClientSourceTV(client))
    {
        return Plugin_Continue;
    }

    if (fuckTimer_GetCurrentMapStatus() == msInactive || fuckTimer_GetClientStatus(client) == psInactive)
    {
        return Plugin_Continue;
    }

    if (Player[client].Prestrafe && Player[client].SetSpeed)
    {
        if (GetEntityFlags(client) & FL_ONGROUND)
        {
            Player[client].AllowPrestrafe(false);
        }
    }

    Player[client].Origin2 = Player[client].Origin1;
    GetEntPropVector(client, Prop_Data, "m_vecOrigin", Player[client].Origin1);

    float fTickInterval = GetTickInterval();

    float fSpeed = GetClientSpeed(client);
    int iSpeed = RoundToNearest(fSpeed);

    if (Player[client].MainRunning)
    {
        if (Player[client].GetOffset)
        {
            Player[client].GetOffset = false;

            CalculateTickIntervalOffset(client, false);
        }

        Player[client].Time += fTickInterval;
        Player[client].Speed += iSpeed;
        Player[client].SpeedCount++;
    }

    if (Player[client].CheckpointRunning)
    {
        if (GetIntMapGetOffset(Player[client].CheckpointDetails, Player[client].Checkpoint))
        {
            CalculateTickIntervalOffsetCS(client, Player[client].CheckpointDetails, Player[client].Checkpoint, false);
            SetIntMapGetOffset(Player[client].CheckpointDetails, Player[client].Checkpoint, false);
        }

        SetIntMapTime(Player[client].CheckpointDetails, Player[client].Checkpoint, fTickInterval);
        SetIntMapSpeed(Player[client].CheckpointDetails, Player[client].Checkpoint, iSpeed);
    }

    if (Player[client].StageRunning)
    {
        if (GetIntMapGetOffset(Player[client].StageDetails, Player[client].Stage))
        {
            CalculateTickIntervalOffsetCS(client, Player[client].StageDetails, Player[client].Stage, false);
            SetIntMapGetOffset(Player[client].StageDetails, Player[client].Stage, false);
        }

        SetIntMapTime(Player[client].StageDetails, Player[client].Stage, fTickInterval);
        SetIntMapSpeed(Player[client].StageDetails, Player[client].Stage, iSpeed);
    }
    
    return Plugin_Continue;
}

void SetClientStartValues(int client, int bonus)
{
    Player[client].Reset(.resetTimeInZone = false, .resetAttempts = false);

    Player[client].SetSpeed = true;

    if (bonus > 0)
    {
        Player[client].Bonus = bonus;
    }
    else if (Core.Stages.GetInt(bonus) > 0)
    {
        Player[client].Stage = 1;
    }
    else if (Core.Checkpoints.GetInt(bonus) > 0)
    {
        Player[client].Checkpoint = 0;
    }

    if (Player[client].TimeInZone < 0.0)
    {
        Player[client].TimeInZone = 0.0;
    }

    if (Player[client].Attempts < 0)
    {
        Player[client].Attempts = 0;
    }

    Player[client].TimeInZone += GetTickInterval();
}

void LoadPlayer(int client)
{
    Player[client].Reset();

    SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}

void SetIntMapTime(IntMap map, int key, float value, bool add = true)
{
    if (map == null)
    {
        return;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    if (value == 0.0 || !add)
    {
        details.Time = value;
    }
    else
    {
        details.Time += value;
    }

    map.SetArray(key, details, sizeof(details));
}

void SetIntMapSync(IntMap map, int key, bool goodGains)
{
    if (map == null)
    {
        return;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    if (goodGains)
    {
        details.GoodGains++;
    }
    else
    {
        details.SyncCount++;
    }

    map.SetArray(key, details, sizeof(details));
}

float GetIntMapSync(IntMap map, int key)
{
    if (map == null)
    {
        return 0.0;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    return details.GoodGains / float(details.SyncCount) * 100.0;
}

void SetIntMapSpeed(IntMap map, int key, int value, bool add = true)
{
    if (map == null)
    {
        return;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    if (value == 0.0 || !add)
    {
        details.Speed = value;
    }
    else
    {
        details.Speed += value;
    }

    if (add)
    {
        details.SpeedCount++;
    }
    else
    {
        details.SpeedCount = 1;
    }

    map.SetArray(key, details, sizeof(details));
}

int GetIntMapSpeed(IntMap map, int key)
{
    if (map == null)
    {
        return 0;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    if (details.Speed == 0)
    {
        return 0;
    }

    return details.Speed / details.SpeedCount;
}

void SetIntMapJumps(IntMap map, int key, int value, bool add = true)
{
    if (map == null)
    {
        return;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    if (value == 0.0 || !add)
    {
        details.Jumps = value;
    }
    else
    {
        details.Jumps += value;
    }

    map.SetArray(key, details, sizeof(details));
}

int GetIntMapJumps(IntMap map, int key)
{
    if (map == null)
    {
        return 0;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    return details.Jumps;
}

void SetIntMapTimeInZone(IntMap map, int key, float value)
{
    if (map == null)
    {
        return;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    details.TimeInZone = value;

    map.SetArray(key, details, sizeof(details));
}

void SetIntMapPositionAngleVelocity(int client, IntMap map, int key, bool start, bool checkpoint = false)
{
    if (map == null)
    {
        return;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    if (start || checkpoint)
    {
        GetClientPosition(client, details.StartPosition);
        GetClientAngle(client, details.StartAngle);
        GetClientVelocity(client, details.StartVelocity);
    }
    else
    {
        GetClientPosition(client, details.EndPosition);
        GetClientAngle(client, details.EndAngle);
        GetClientVelocity(client, details.EndVelocity);
    }

    map.SetArray(key, details, sizeof(details));
}

bool GetIntMapGetOffset(IntMap map, int key)
{
    if (map == null)
    {
        return false;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    return details.GetOffset;
}

bool SetIntMapGetOffset(IntMap map, int key, bool status)
{
    if (map == null)
    {
        return false;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));
    details.GetOffset = status;
    map.SetArray(key, details, sizeof(details));

    return details.GetOffset;
}

float GetIntMapOffset(IntMap map, int key, int offset)
{
    if (map == null)
    {
        return 0.0;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    return details.Offset[offset];
}

float GetIntMapTimeInZone(IntMap map, int key)
{
    if (map == null)
    {
        return  0.0;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    return details.TimeInZone;
}

void SetIntMapAttempts(IntMap map, int key, int value)
{
    if (map == null)
    {
        return;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    details.Attempts = value;

    map.SetArray(key, details, sizeof(details));
}

int GetIntMapAttempts(IntMap map, int key)
{
    if (map == null)
    {
        return 0;
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));

    return details.Attempts;
}

// Thanks to bhoptimer for this code.
// Source: https://github.com/shavitush/bhoptimer/blob/e6de599808b5a8c1b2e74729da0820e73392cdce/addons/sourcemod/scripting/shavit-core.sp#L3487
// Reference: https://github.com/momentum-mod/game/blob/5e2d1995ca7c599907980ee5b5da04d7b5474c61/mp/src/game/server/momentum/mom_timer.cpp#L388
void CalculateTickIntervalOffset(int client, bool end)
{
    float fOrigin[3];
    float fMins[3];
    float fMaxs[3];

    GetEntPropVector(client, Prop_Data, "m_vecOrigin", fOrigin);
    GetEntPropVector(client, Prop_Data, "m_vecMins", fMins);
    GetEntPropVector(client, Prop_Data, "m_vecMaxs", fMaxs);

    if (!end)
    {
        TR_EnumerateEntitiesHull(fOrigin, Player[client].Origin2, fMins, fMaxs, PARTITION_TRIGGER_EDICTS, TREnumTrigger, client);
    }
    else
    {
        TR_EnumerateEntitiesHull(Player[client].Origin1, fOrigin, fMins, fMaxs, PARTITION_TRIGGER_EDICTS, TREnumTrigger, client);
    }

    Player[client].Offset[end ? OFFSET_END : OFFSET_START] = Player[client].Fraction * GetTickInterval();
}

bool TREnumTrigger(int entity, any client)
{
    if (entity <= MaxClients)
    {
        return true;
    }

    char sClass[32];
    GetEntityClassname(entity, sClass, sizeof(sClass));

    if (StrContains(sClass, "trigger_multiple") > -1)
    {
        TR_ClipCurrentRayToEntity(MASK_ALL, entity);
        
        Player[client].Fraction = TR_GetFraction();

        return false;
    }
    return true;
}

void CalculateTickIntervalOffsetCS(int client, IntMap map, int key, bool end)
{
    float fFraction;
    float fOrigin[3];
    float fMins[3];
    float fMaxs[3];

    GetEntPropVector(client, Prop_Data, "m_vecOrigin", fOrigin);
    GetEntPropVector(client, Prop_Data, "m_vecMins", fMins);
    GetEntPropVector(client, Prop_Data, "m_vecMaxs", fMaxs);

    if (!end)
    {
        TR_EnumerateEntitiesHull(fOrigin, Player[client].Origin2, fMins, fMaxs, PARTITION_TRIGGER_EDICTS, TREnumTriggerCS, fFraction);
    }
    else
    {
        TR_EnumerateEntitiesHull(Player[client].Origin1, fOrigin, fMins, fMaxs, PARTITION_TRIGGER_EDICTS, TREnumTriggerCS, fFraction);
    }

    CSDetails details;
    map.GetArray(key, details, sizeof(details));
    details.Fraction = fFraction;
    details.Offset[end ? OFFSET_END : OFFSET_START] = details.Fraction * GetTickInterval();
    map.SetArray(key, details, sizeof(details));
}

bool TREnumTriggerCS(int entity, any fraction)
{
    if (entity <= MaxClients)
    {
        return true;
    }

    char sClass[32];
    GetEntityClassname(entity, sClass, sizeof(sClass));

    if (StrContains(sClass, "trigger_multiple") > -1)
    {
        TR_ClipCurrentRayToEntity(MASK_ALL, entity);
        
        fraction = TR_GetFraction();

        return false;
    }
    return true;
}

float GetAngleDiff(float current, float previous)
{
    float diff = current - previous;
    return diff - 360.0 * RoundToFloor((diff + 180.0) / 360.0);
}

void TestAngles(int client, float dirangle, float yawdelta, float vel[3])
{
    if (dirangle < 0.0)
    {
        dirangle = -dirangle;
    }

    bool bCount = false;
    bool bGain = false;

    if (dirangle < 22.5 || dirangle > 337.5)
    {
        bCount = true;

        if ((yawdelta > 0.0 && vel[1] <= -100.0) || (yawdelta < 0.0 && vel[1] >= 100.0))
        {
            bGain = true;
        }
    }
    else if ((dirangle > 22.5 && dirangle < 67.5)) // HSW
    {
        bCount = true;

        if ((yawdelta != 0.0) && (vel[0] >= 100.0 || vel[1] >= 100.0) && (vel[0] >= -100.0 || vel[1] >= -100.0))
        {
            bGain = true;
        }
    }
    else if ((dirangle > 67.5 && dirangle < 112.5) || (dirangle > 247.5 && dirangle < 292.5)) // SW
    {
        bCount = true;

        if (vel[0] <= -100.0 || vel[0] >= 100.0)
        {
            bGain = true;
        }
    }

    if (bCount)
    {
        Player[client].SyncCount++;

        if (Player[client].CheckpointRunning)
        {
            SetIntMapSync(Player[client].CheckpointDetails, Player[client].Checkpoint, false);
        }
        else if (Player[client].StageRunning)
        {
            SetIntMapSync(Player[client].StageDetails, Player[client].Stage, false);
        }
    }

    if (bGain)
    {
        Player[client].GoodGains++;

        if (Player[client].CheckpointRunning)
        {
            SetIntMapSync(Player[client].CheckpointDetails, Player[client].Checkpoint, true);
        }
        else if (Player[client].StageRunning)
        {
            SetIntMapSync(Player[client].StageDetails, Player[client].Stage, true);
        }
    }
}
