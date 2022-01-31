#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckTimer_stocks>
#include <fuckTimer_api>
#include <fuckTimer_maps>
#include <fuckTimer_timer>

enum struct PluginData
{
    IntMap Records[MAX_STYLES + 1];

    GlobalForward OnNewRecord;
    GlobalForward OnPlayerRecordsLoaded;
    GlobalForward OnServerRecordsLoaded;
}
PluginData Core;

enum struct PlayerData
{
    IntMap Records[MAX_STYLES + 1];
}
PlayerData Player[MAXPLAYERS + 1];

#include "api/records.sp"

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "Records",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    Core.OnNewRecord = new GlobalForward("fuckTimer_OnNewRecord", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float);
    Core.OnServerRecordsLoaded = new GlobalForward("fuckTimer_OnServerRecordsLoaded", ET_Ignore, Param_Cell);
    Core.OnPlayerRecordsLoaded = new GlobalForward("fuckTimer_OnPlayerRecordsLoaded", ET_Ignore, Param_Cell, Param_Cell);

    CreateNative("fuckTimer_GetServerRecord", Native_GetServerRecord);
    CreateNative("fuckTimer_GetPlayerRecord", Native_GetPlayerRecord);

    RegPluginLibrary("fuckTimer_records");

    return APLRes_Success;
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

public void fuckTimer_OnSharedLocationsLoaded()
{
    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Records/MapId/%d", fuckTimer_GetCurrentMapId());
    fuckTimer_NewAPIHTTPRequest(sEndpoint).Get(GetRecords, 0);

    RecalculateRanks();
}

public void fuckTimer_OnPlayerLoaded(int client)
{
    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Records/MapId/%d/PlayerId/%d", fuckTimer_GetCurrentMapId(), GetSteamAccountID(client));
    LogMessage(sEndpoint);
    fuckTimer_NewAPIHTTPRequest(sEndpoint).Get(GetRecords, GetClientUserId(client));
}

public void OnClientDisconnect(int client)
{
    for (int i = 0; i <= MAX_STYLES; i++)
    {
        if (Player[client].Records[i] == null)
        {
            continue;
        }

        RecordData record;
        IntMapSnapshot snap = Player[client].Records[i].Snapshot();

        for (int j = 0; j < snap.Length; j++)
        {
            Player[client].Records[i].GetArray(j, record, sizeof(record));
            delete record.Details;
        }

        delete snap;

        delete Player[client].Records[i];
    }
}

public void fuckTimer_OnClientTimerEnd(int client, StringMap temp)
{
    for (int i = 0; i < 3; i++)
    {
        PrintToServer("fuckTimer_OnClientTimerEnd");
    }
    
    // Cloning handles
    StringMap smRecord = view_as<StringMap>(CloneHandle(temp));
    IntMap imDetails;
    temp.GetValue("Details", imDetails);

    if (imDetails != null)
    {
        smRecord.SetValue("Details", CloneHandle(imDetails));
    }

    Styles iStyle;
    smRecord.GetValue("StyleId", iStyle);

    int iLevel;
    smRecord.GetValue("Level", iLevel);

    float fTime;
    smRecord.GetValue("Time", fTime);

    bool bServerRecord = false;
    bool bPlayerRecord = false;
    bool bFirstRecord = false;

    float fOldTime = 0.0;

    // Check for new server record
    if (Core.Records[iStyle] != null)
    {
        RecordData record;
        Core.Records[iStyle].GetArray(iLevel, record, sizeof(record));

        if (record.Time == 0.0 || fTime < record.Time)
        {
            CPrintToChatAll("%N has beaten %s's server record!", client, record.PlayerName);

            fOldTime = record.Time;
            bServerRecord = true;
        }
    }
    else
    {
        CPrintToChatAll("%N has set the server record!", client);
        bServerRecord = true;
    }

    // Check for new player record, when server record wasn't reached
    if (Player[client].Records[iStyle] != null)
    {
        RecordData record;
        Player[client].Records[iStyle].GetArray(iLevel, record, sizeof(record));

        if (record.Time == 0.0 || fTime < record.Time)
        {
            if (!bServerRecord)
            {
                CPrintToChatAll("%N has beaten his record!", client, record.PlayerName);
            }
            else
            {
                CPrintToChat(client, "%N has beaten his record!", client, record.PlayerName);
            }

            fOldTime = record.Time;
            bPlayerRecord = true;
        }
    }
    else
    {
        CPrintToChatAll("%N finished this map first time!", client);
        bFirstRecord = true;
        bPlayerRecord = true;
    }

    if (bServerRecord)
    {
        UpdateRecord(smRecord, false, .serverRecord=true, .oldTime=fOldTime);
    }

    if (bPlayerRecord)
    {
        UpdateRecord(smRecord, true, client, bFirstRecord);
    }
}

void UpdateRecord(StringMap smRecord, bool updatePlayer, int client = 0, bool firstRecord = false, bool serverRecord = false, float oldTime = 0.0)
{
    RecordData record;
    smRecord.GetValue("PlayerId", record.PlayerId);
    smRecord.GetString("PlayerName", record.PlayerName, sizeof(RecordData::PlayerName));
    smRecord.GetValue("StyleId", record.Style);
    smRecord.GetValue("Level", record.Level);
    smRecord.GetValue("Type", record.Type);
    smRecord.GetValue("Tickrate", record.Tickrate);
    smRecord.GetValue("Time", record.Time);
    smRecord.GetValue("TimeInZone", record.TimeInZone);
    smRecord.GetValue("Attempts", record.Attempts);
    smRecord.GetValue("Sync", record.Sync);
    smRecord.GetValue("Speed", record.Speed);
    smRecord.GetValue("Jumps", record.Jumps);
    smRecord.GetArray("StartPosition", record.StartPosition, 3);
    smRecord.GetArray("EndPosition", record.EndPosition, 3);
    smRecord.GetArray("StartAngle", record.StartAngle, 3);
    smRecord.GetArray("EndAngle", record.EndAngle, 3);
    smRecord.GetArray("StartVelocity", record.StartVelocity, 3);
    smRecord.GetArray("EndVelocity", record.EndVelocity, 3);

    JSONObject jRecord = new JSONObject();
    jRecord.SetInt("MapId", fuckTimer_GetCurrentMapId());
    jRecord.SetInt("PlayerId", record.PlayerId);
    jRecord.SetInt("StyleId", view_as<int>(record.Style));
    jRecord.SetInt("Level", record.Level);

    char sStype[12];
    if (record.Type == TimeCheckpoint)
    {
        FormatEx(sStype, sizeof(sStype), "Checkpoint");
    }
    else if (record.Type == TimeStage)
    {
        FormatEx(sStype, sizeof(sStype), "Stage");
    }
    else
    {
        FormatEx(sStype, sizeof(sStype), "Linear");
    }

    jRecord.SetString("Type", sStype);
    jRecord.SetFloat("Tickrate", record.Tickrate);
    jRecord.SetFloat("Time", record.Time);
    jRecord.SetFloat("TimeInZone", record.TimeInZone);
    jRecord.SetInt("Attempts", record.Attempts);
    jRecord.SetFloat("Sync", record.Sync);
    jRecord.SetInt("Speed", record.Speed);
    jRecord.SetInt("Jumps", record.Jumps);
    jRecord.SetFloat("StartPositionX", record.StartPosition[0]);
    jRecord.SetFloat("StartPositionY", record.StartPosition[1]);
    jRecord.SetFloat("StartPositionZ", record.StartPosition[2]);
    jRecord.SetFloat("EndPositionX", record.EndPosition[0]);
    jRecord.SetFloat("EndPositionY", record.EndPosition[1]);
    jRecord.SetFloat("EndPositionZ", record.EndPosition[2]);
    jRecord.SetFloat("StartAngleX", record.StartAngle[0]);
    jRecord.SetFloat("StartAngleY", record.StartAngle[1]);
    jRecord.SetFloat("StartAngleZ", record.StartAngle[2]);
    jRecord.SetFloat("EndAngleX", record.EndAngle[0]);
    jRecord.SetFloat("EndAngleY", record.EndAngle[1]);
    jRecord.SetFloat("EndAngleZ", record.EndAngle[2]);
    jRecord.SetFloat("StartVelocityX", record.StartVelocity[0]);
    jRecord.SetFloat("StartVelocityY", record.StartVelocity[1]);
    jRecord.SetFloat("StartVelocityZ", record.StartVelocity[2]);
    jRecord.SetFloat("EndVelocityX", record.EndVelocity[0]);
    jRecord.SetFloat("EndVelocityY", record.EndVelocity[1]);
    jRecord.SetFloat("EndVelocityZ", record.EndVelocity[2]);

    JSONArray jRecords = new JSONArray();
    IntMap imDetails;

    if (record.Type == TimeCheckpoint || record.Type == TimeStage)
    {
        if (record.Details == null)
        {
            record.Details = new IntMap();
        }

        smRecord.GetValue("Details", imDetails);

        int iPoint;
        IntMapSnapshot snap = imDetails.Snapshot();
        CSDetails details;

        JSONObject jDetails = null;

        for (int j = 0; j < snap.Length; j++)
        {
            iPoint = snap.GetKey(j);
            imDetails.GetArray(iPoint, details, sizeof(details));

            if (record.Type == TimeStage)
            {
                jDetails = new JSONObject();
                jDetails.SetInt("Stage", iPoint);
                jDetails.SetFloat("Time", details.Time);
                jDetails.SetFloat("TimeInZone", details.TimeInZone);
                jDetails.SetInt("Attempts", details.Attempts);
                jDetails.SetFloat("Sync", details.GoodGains / float(details.SyncCount) * 100.0);
                jDetails.SetInt("Speed", details.Speed / details.SpeedCount);
                jDetails.SetInt("Jumps", details.Jumps);
                jDetails.SetFloat("StartPositionX", details.StartPosition[0]);
                jDetails.SetFloat("StartPositionY", details.StartPosition[1]);
                jDetails.SetFloat("StartPositionZ", details.StartPosition[2]);
                jDetails.SetFloat("EndPositionX", details.EndPosition[0]);
                jDetails.SetFloat("EndPositionY", details.EndPosition[1]);
                jDetails.SetFloat("EndPositionZ", details.EndPosition[2]);
                jDetails.SetFloat("StartAngleX", details.StartAngle[0]);
                jDetails.SetFloat("StartAngleY", details.StartAngle[1]);
                jDetails.SetFloat("StartAngleZ", details.StartAngle[2]);
                jDetails.SetFloat("EndAngleX", details.EndAngle[0]);
                jDetails.SetFloat("EndAngleY", details.EndAngle[1]);
                jDetails.SetFloat("EndAngleZ", details.EndAngle[2]);
                jDetails.SetFloat("StartVelocityX", details.StartVelocity[0]);
                jDetails.SetFloat("StartVelocityY", details.StartVelocity[1]);
                jDetails.SetFloat("StartVelocityZ", details.StartVelocity[2]);
                jDetails.SetFloat("EndVelocityX", details.EndVelocity[0]);
                jDetails.SetFloat("EndVelocityY", details.EndVelocity[1]);
                jDetails.SetFloat("EndVelocityZ", details.EndVelocity[2]);
                jRecords.Push(jDetails);
            }
            else
            {
                jDetails = new JSONObject();
                jDetails.SetInt("Checkpoint", iPoint);
                jDetails.SetFloat("Time", details.Time);
                jDetails.SetFloat("Sync", details.GoodGains / float(details.SyncCount) * 100.0);
                jDetails.SetInt("Speed", details.Speed / details.SpeedCount);
                jDetails.SetInt("Jumps", details.Jumps);
                jDetails.SetFloat("PositionX", details.StartPosition[0]);
                jDetails.SetFloat("PositionY", details.StartPosition[1]);
                jDetails.SetFloat("PositionZ", details.StartPosition[2]);
                jDetails.SetFloat("AngleX", details.StartAngle[0]);
                jDetails.SetFloat("AngleY", details.StartAngle[1]);
                jDetails.SetFloat("AngleZ", details.StartAngle[2]);
                jDetails.SetFloat("VelocityX", details.StartVelocity[0]);
                jDetails.SetFloat("VelocityY", details.StartVelocity[1]);
                jDetails.SetFloat("VelocityZ", details.StartVelocity[2]);
                jRecords.Push(jDetails);
            }

            record.Details.SetArray(iPoint, details, sizeof(details));
        }

        delete snap;
    }

    jRecord.Set("Details", jRecords);

    if (updatePlayer)
    {
        PostPlayerRecord(client, firstRecord, jRecord, serverRecord, oldTime, smRecord);
        if (Player[client].Records[record.Style] == null)
        {
            Player[client].Records[record.Style] = new IntMap();
        }

        Player[client].Records[record.Style].SetArray(record.Level, record, sizeof(record));
    }
    else
    {
        if (Core.Records[record.Style] == null)
        {
            Core.Records[record.Style] = new IntMap();
        }

        Core.Records[record.Style].SetArray(record.Level, record, sizeof(record));
    }
}

public any Native_GetServerRecord(Handle plugin, int numParams)
{
    Styles style = view_as<Styles>(GetNativeCell(1));
    int iLevel = GetNativeCell(2);

    if (Core.Records[style] != null)
    {
        RecordData record;
        if (Core.Records[style].GetArray(iLevel, record, sizeof(record)))
        {
            SetNativeArray(3, record, sizeof(record));
            return true;
        }
    }

    return false;
}

public any Native_GetPlayerRecord(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    Styles style = view_as<Styles>(GetNativeCell(2));
    int iLevel = GetNativeCell(3);

    if (Player[client].Records[style] != null)
    {
        RecordData record;
        if (Player[client].Records[style].GetArray(iLevel, record, sizeof(record)))
        {
            SetNativeArray(4, record, sizeof(record));
            return true;
        }
    }

    return false;
}
