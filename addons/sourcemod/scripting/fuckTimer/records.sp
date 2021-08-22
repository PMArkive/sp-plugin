#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckTimer_stocks>
#include <fuckTimer_api>
#include <fuckTimer_maps>
#include <fuckTimer_timer>

enum struct PluginData
{
    bool MapLoaded;
    bool StylesLoaded;

    IntMap Records[MAX_STYLES + 1];

    void Reset()
    {
        this.MapLoaded = false;
        this.StylesLoaded = false;
    }
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
    CreateNative("fuckTimer_GetServerRecord", Native_GetServerRecord);
    CreateNative("fuckTimer_GetPlayerRecord", Native_GetPlayerRecord);

    RegPluginLibrary("fuckTimer_records");

    return APLRes_Success;
}

public void OnPluginStart()
{
    Core.Reset();
}

public void fuckTimer_OnMapDataLoaded()
{
    Core.MapLoaded = true;

    CheckState();
}

public void fuckTimer_OnStylesLoaded()
{
    Core.StylesLoaded = true;

    CheckState();
}

void CheckState()
{
    if (!Core.StylesLoaded || !Core.MapLoaded)
    {
        return;
    }
    
    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Records/MapId/%d", fuckTimer_GetCurrentMapId());

    DataPack pack = new DataPack();
    pack.WriteCell(0);
    fuckTimer_NewAPIHTTPRequest(sEndpoint).Get(GetRecords, pack);
}

public void fuckTimer_OnPlayerLoaded(int client)
{
    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Records/MapId/%d/PlayerId/%d", fuckTimer_GetCurrentMapId(), GetSteamAccountID(client));

    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    fuckTimer_NewAPIHTTPRequest(sEndpoint).Get(GetRecords, pack);
}

public void OnClientDisconnect(int client)
{
    for (int i = 0; i <= MAX_STYLES; i++)
    {
        if (Player[client].Records[i] != null)
        {
            RecordData record;
            IntMapSnapshot snap = Player[client].Records[i].Snapshot();

            for (int j = 0; j < snap.Length; j++)
            {
                Player[client].Records[i].GetArray(j, record, sizeof(record));
                delete record.Details;
            }

            delete snap;
        }

        delete Player[client].Records[i];
    }
}

public void fuckTimer_OnClientTimerEnd(int client, StringMap temp)
{
    StringMap smRecord = view_as<StringMap>(CloneHandle(temp));

    Styles iStyle;
    smRecord.GetValue("StyleId", iStyle);

    int iLevel;
    smRecord.GetValue("Level", iLevel);

    float fTime;
    smRecord.GetValue("Time", fTime);

    bool bServerRecord = false;
    bool bPlayerRecord = false;
    bool bFirstRecord = false;

    // Check for new server record
    if (Core.Records[iStyle] != null)
    {
        RecordData record;
        Core.Records[iStyle].GetArray(iLevel, record, sizeof(record));

        if (fTime < record.Time)
        {
            PrintToChatAll("%N has beaten %s's server record!", client, record.PlayerName);
            bServerRecord = true;
        }
    }
    else
    {
        PrintToChatAll("%N has set the server record!", client);
        bServerRecord = true;
    }

    // Check for new player record, when server record wasn't reached
    if (Player[client].Records[iStyle] != null)
    {
        RecordData record;
        Player[client].Records[iStyle].GetArray(iLevel, record, sizeof(record));

        if (fTime < record.Time)
        {
            if (!bServerRecord)
            {
                PrintToChatAll("%N has beaten his record!", client, record.PlayerName);
            }
            else
            {
                PrintToChat(client, "%N has beaten his record!", client, record.PlayerName);
            }

            bPlayerRecord = true;
        }
    }
    else if (Player[client].Records[iStyle] == null)
    {
        PrintToChatAll("%N finished this map first time!", client);
        bPlayerRecord = true;
        bFirstRecord = true;
    }

    TimeType tType;
    smRecord.GetValue("Type", tType);

    float fTimeInZone;
    smRecord.GetValue("TimeInZone", fTimeInZone);

    int iAttempts;
    smRecord.GetValue("Attempts", iAttempts);

    IntMap imDetails;
    smRecord.GetValue("Details", imDetails);

    if (imDetails != null)
    {
        int iPoint;
        IntMapSnapshot snap = imDetails.Snapshot();

        CSDetails details;
        for (int i = 0; i < snap.Length; i++)
        {
            iPoint = snap.GetKey(i);
            imDetails.GetArray(iPoint, details, sizeof(details));

            if (tType == TimeStage)
            {
                PrintToConsole(client, "%s %d: TimeInZone: %.3f", tType == TimeCheckpoint ? "Checkpoint" : "Stage", iPoint, details.TimeInZone);
                PrintToConsole(client, "%s %d: Attempts: %d", tType == TimeCheckpoint ? "Checkpoint" : "Stage", iPoint, details.Attempts);

                fTimeInZone += details.TimeInZone;
                iAttempts += details.Attempts;
                
                if (iPoint > 1)
                {
                    iAttempts--;
                }
            }
        }
        
        smRecord.SetValue("TimeInZone", fTimeInZone);
        smRecord.SetValue("Attempts", iAttempts);

        delete snap;
    }

    PrintToConsole(client, "TimeInZone: %.3f, Attempts: %d", fTimeInZone, iAttempts);

    if (bServerRecord)
    {
        UpdateRecord(smRecord, false);
        return;
    }

    if (bPlayerRecord || bServerRecord)
    {
        UpdateRecord(smRecord, true, client, bFirstRecord);
        return;
    }

    delete imDetails;
    delete smRecord;
}

void UpdateRecord(StringMap smRecord, bool updatePlayer, int client = 0, bool firstRecord = false)
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
    smRecord.GetValue("Status", record.Status);
    smRecord.GetArray("StartPosition", record.StartPosition, 3);
    smRecord.GetArray("EndPosition", record.EndPosition, 3);
    smRecord.GetArray("StartAngle", record.StartAngle, 3);
    smRecord.GetArray("EndAngle", record.EndAngle, 3);
    smRecord.GetArray("StartVelocity", record.StartVelocity, 3);
    smRecord.GetArray("EndVelocity", record.EndVelocity, 3);

    LogMessage("Style: %d, Level: %d, Player: %s (Id: %d), Type: %d, Tickrate: %.1f, Time: %.3f, TimeInZone: %.3f, Attempts: %d, Status: %d, StartPosition: %.3f/%.3f/%.3f", record.Style, record.Level, record.PlayerName, record.PlayerId, record.Type, record.Tickrate, record.Time, record.TimeInZone, record.Attempts, record.Status, record.StartPosition[0], record.StartPosition[1], record.StartPosition[2]);

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
    if (record.Type == TimeStage)
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

    if (record.Type == TimeCheckpoint || record.Type == TimeStage)
    {
        if (record.Details == null)
        {
            record.Details = new IntMap();
        }

        IntMap imDetails;
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

                LogMessage("Stage: %d, Time: %.3f, TimeInZone: %.3f, Attempts: %d, StartPosition: %.3f/%.3f/%.3f", iPoint, details.Time, details.TimeInZone, details.Attempts, details.StartPosition[0], details.StartPosition[1], details.StartPosition[2]);
            }
            else
            {
                jDetails = new JSONObject();
                jDetails.SetInt("Checkpoint", iPoint);
                jDetails.SetFloat("Time", details.Time);
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

                LogMessage("Checkpoint: %d, Time: %.3f, StartPosition: %.3f/%.3f/%.3f", iPoint, details.Time, details.StartPosition[0], details.StartPosition[1], details.StartPosition[2]);
            }

            record.Details.SetArray(iPoint, details, sizeof(details));
        }

        delete snap;
        delete imDetails;
    }

    delete smRecord;

    jRecord.Set("Details", jRecords);

    PostPlayerRecord(client, firstRecord, jRecord);

    if (updatePlayer)
    {
        Player[client].Records[record.Style].SetArray(record.Level, record, sizeof(record));
    }
    else
    {
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
