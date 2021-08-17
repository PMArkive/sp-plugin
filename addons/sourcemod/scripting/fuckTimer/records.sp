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
        }

        delete Player[client].Records[i];
    }
}

public void fuckTimer_OnClientTimerEnd(int client, StringMap temp)
{
    StringMap smRecord = view_as<StringMap>(CloneHandle(temp));

    Styles iStyle;
    smRecord.GetValue("StyleId", iStyle);
    PrintToConsoleAll("Main: Style: %d", iStyle);

    int iLevel;
    smRecord.GetValue("Level", iLevel);
    PrintToConsoleAll("Main: Level: %d", iLevel);

    float fTime;
    smRecord.GetValue("Time", fTime);
    PrintToConsoleAll("Main: Time: %.3f", fTime);

    bool bServerRecord = false;
    bool bPlayerRecord = false;

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
    }


    int iMapId;
    smRecord.GetValue("MapId", iMapId);
    PrintToConsoleAll("Main: MapId: %d", iMapId);

    int iPlayerId;
    smRecord.GetValue("PlayerId", iPlayerId);
    PrintToConsoleAll("Main: PlayerId: %d", iPlayerId);

    char sPlayerName[MAX_NAME_LENGTH];
    smRecord.GetString("PlayerName", sPlayerName, sizeof(sPlayerName));
    PrintToConsoleAll("Main: PlayerName: %s", sPlayerName);

    TimeType tType;
    smRecord.GetValue("Type", tType);

    char sType[12];
    if (tType == TimeMain)
    {
        FormatEx(sType, sizeof(sType), "Main");
    }
    else if (tType == TimeCheckpoint)
    {
        FormatEx(sType, sizeof(sType), "Checkpoint");
    }
    else if (tType == TimeStage)
    {
        FormatEx(sType, sizeof(sType), "Stage");
    }
    PrintToConsoleAll("Main: Type: %d (String: %s)", tType, sType);

    float fTickrate;
    smRecord.GetValue("Tickrate", fTickrate);
    PrintToConsoleAll("Main: Tickrate: %.2f", fTickrate);

    float fTimeInZone;
    smRecord.GetValue("TimeInZone", fTimeInZone);
    PrintToConsoleAll("Main: TimeInZone: %.3f", fTimeInZone);

    int iAttempts;
    smRecord.GetValue("Attempts", iAttempts);
    PrintToConsoleAll("Main: Attempts: %d", iAttempts);

    float fStartPosition[3];
    smRecord.GetArray("StartPosition", fStartPosition, 3);
    PrintToConsoleAll("Main: StartPosition[0]: %.5f, StartPosition[1]: %.5f, StartPosition[2]: %.5f", fStartPosition[0], fStartPosition[1], fStartPosition[2]);

    float fStartAngle[3];
    smRecord.GetArray("StartAngle", fStartAngle, 3);
    PrintToConsoleAll("Main: StartAngle[0]: %.5f, StartAngle[1]: %.5f, StartAngle[2]: %.5f", fStartAngle[0], fStartAngle[1], fStartAngle[2]);

    float fStartVelocity[3];
    smRecord.GetArray("StartVelocity", fStartVelocity, 3);
    PrintToConsoleAll("Main: StartVelocity[0]: %.5f, StartVelocity[1]: %.5f, StartVelocity[2]: %.5f", fStartVelocity[0], fStartVelocity[1], fStartVelocity[2]);

    float fEndPosition[3];
    smRecord.GetArray("EndPosition", fEndPosition, 3);
    PrintToConsoleAll("Main: EndPosition[0]: %.5f, EndPosition[1]: %.5f, EndPosition[2]: %.5f", fEndPosition[0], fEndPosition[1], fEndPosition[2]);

    float fEndAngle[3];
    smRecord.GetArray("EndAngle", fEndAngle, 3);
    PrintToConsoleAll("Main: EndAngle[0]: %.5f, EndAngle[1]: %.5f, EndAngle[2]: %.5f", fEndAngle[0], fEndAngle[1], fEndAngle[2]);

    float fEndVelocity[3];
    smRecord.GetArray("EndVelocity", fEndVelocity, 3);
    PrintToConsoleAll("Main: EndVelocity[0]: %.5f, EndVelocity[1]: %.5f, EndVelocity[2]: %.5f", fEndVelocity[0], fEndVelocity[1], fEndVelocity[2]);

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

            PrintToConsoleAll("%s %d: Time: %.3f, ", tType == TimeCheckpoint ? "Checkpoint" : "Stage", iPoint, details.Time);

            if (tType == TimeStage)
            {
                PrintToConsoleAll("%s %d: TimeInZone: %.3f", tType == TimeCheckpoint ? "Checkpoint" : "Stage", iPoint, details.TimeInZone);
                PrintToConsoleAll("%s %d: Attempts: %d", tType == TimeCheckpoint ? "Checkpoint" : "Stage", iPoint, details.Attempts);

                fTimeInZone += details.TimeInZone;
                
                // TODO: Make this more beautiful, but for testing it should be fine
                if (iPoint == 1)
                {
                    iAttempts += details.Attempts;
                }
                else
                {
                    iAttempts += details.Attempts;
                    iAttempts--;
                }
            }
            
            PrintToConsoleAll("%s %d: StartPosition[0]: %.5f, StartPosition[1]: %.5f, StartPosition[2]: %.5f", tType == TimeCheckpoint ? "Checkpoint" : "Stage", iPoint, details.StartPosition[0], details.StartPosition[1], details.StartPosition[2]);
            PrintToConsoleAll("%s %d: StartAngle[0]: %.5f, StartAngle[1]: %.5f, StartAngle[2]: %.5f", tType == TimeCheckpoint ? "Checkpoint" : "Stage", iPoint, details.StartAngle[0], details.StartAngle[1], details.StartAngle[2]);
            PrintToConsoleAll("%s %d: StartVelocity[0]: %.5f, StartVelocity[1]: %.5f, StartVelocity[2]: %.5f", tType == TimeCheckpoint ? "Checkpoint" : "Stage", iPoint, details.StartVelocity[0], details.StartVelocity[1], details.StartVelocity[2]);
            PrintToConsoleAll("%s %d: EndPosition[0]: %.5f, EndPosition[1]: %.5f, EndPosition[2]: %.5f", tType == TimeCheckpoint ? "Checkpoint" : "Stage", iPoint, details.EndPosition[0], details.EndPosition[1], details.EndPosition[2]);
            PrintToConsoleAll("%s %d: EndAngle[0]: %.5f, EndAngle[1]: %.5f, EndAngle[2]: %.5f", tType == TimeCheckpoint ? "Checkpoint" : "Stage", iPoint, details.EndAngle[0], details.EndAngle[1], details.EndAngle[2]);
            PrintToConsoleAll("%s %d: EndVelocity[0]: %.5f, EndVelocity[1]: %.5f, EndVelocity[2]: %.5f", tType == TimeCheckpoint ? "Checkpoint" : "Stage", iPoint, details.EndVelocity[0], details.EndVelocity[1], details.EndVelocity[2]);
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
        UpdateRecord(smRecord, true, client);
        return;
    }

    delete imDetails;
    delete smRecord;
}

void UpdateRecord(StringMap smRecord, bool updatePlayer, int client = 0)
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

        for (int j = 0; j < snap.Length; j++)
        {
            iPoint = snap.GetKey(j);
            imDetails.GetArray(iPoint, details, sizeof(details));

            if (record.Type == TimeStage)
            {
                LogMessage("Stage: %d, Time: %.3f, TimeInZone: %.3f, Attempts: %d, StartPosition: %.3f/%.3f/%.3f", iPoint, details.Time, details.TimeInZone, details.Attempts, details.StartPosition[0], details.StartPosition[1], details.StartPosition[2]);
            }
            else
            {
                LogMessage("Checkpoint: %d, Time: %.3f, StartPosition: %.3f/%.3f/%.3f", iPoint, details.Time, details.StartPosition[0], details.StartPosition[1], details.StartPosition[2]);
            }

            record.Details.SetArray(iPoint, details, sizeof(details));
        }

        delete imDetails;
    }

    delete smRecord;

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
