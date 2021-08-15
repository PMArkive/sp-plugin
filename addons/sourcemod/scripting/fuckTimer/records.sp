#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckTimer_stocks>
#include <fuckTimer_api>
#include <fuckTimer_maps>
#include <fuckTimer_timer>

IntMap g_imServerRecords[MAX_STYLES + 1] = { null, ... };

#include "api/records.sp"

enum struct PluginData
{
    bool MapLoaded;
    bool StylesLoaded;

    void Reset()
    {
        this.MapLoaded = false;
        this.StylesLoaded = false;
    }
}
PluginData Core;

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
    fuckTimer_NewAPIHTTPRequest(sEndpoint).Get(GetServerRecords);
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

    char sPlayerName[MAX_NAME_LENGTH];
    smRecord.GetString("PlayerName", sPlayerName, sizeof(sPlayerName));
    PrintToConsoleAll("Main: PlayerName: %s", sPlayerName);

    if (g_imServerRecords[iStyle] != null)
    {
        RecordData record;
        g_imServerRecords[iStyle].GetArray(iLevel, record, sizeof(record));

        if (fTime < record.Time)
        {
            PrintToChatAll("%N has beaten %s's server record!", client, record.PlayerName);
        }
    }
    else
    {
        PrintToChatAll("%N has set the server record!", client);
    }

    int iMapId;
    smRecord.GetValue("MapId", iMapId);
    PrintToConsoleAll("Main: MapId: %d", iMapId);

    int iPlayerId;
    smRecord.GetValue("PlayerId", iPlayerId);
    PrintToConsoleAll("Main: PlayerId: %d", iPlayerId);

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

    any aDetails;
    smRecord.GetValue("Details", aDetails);

    IntMap imDetails;
    if (aDetails != 0)
    {
        int iPoint;
        imDetails = view_as<IntMap>(CloneHandle(aDetails));
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
            }
            
            PrintToConsoleAll("%s %d: StartPosition[0]: %.5f, StartPosition[1]: %.5f, StartPosition[2]: %.5f", tType == TimeCheckpoint ? "Checkpoint" : "Stage", iPoint, details.StartPosition[0], details.StartPosition[1], details.StartPosition[2]);
            PrintToConsoleAll("%s %d: StartAngle[0]: %.5f, StartAngle[1]: %.5f, StartAngle[2]: %.5f", tType == TimeCheckpoint ? "Checkpoint" : "Stage", iPoint, details.StartAngle[0], details.StartAngle[1], details.StartAngle[2]);
            PrintToConsoleAll("%s %d: StartVelocity[0]: %.5f, StartVelocity[1]: %.5f, StartVelocity[2]: %.5f", tType == TimeCheckpoint ? "Checkpoint" : "Stage", iPoint, details.StartVelocity[0], details.StartVelocity[1], details.StartVelocity[2]);
            PrintToConsoleAll("%s %d: EndPosition[0]: %.5f, EndPosition[1]: %.5f, EndPosition[2]: %.5f", tType == TimeCheckpoint ? "Checkpoint" : "Stage", iPoint, details.EndPosition[0], details.EndPosition[1], details.EndPosition[2]);
            PrintToConsoleAll("%s %d: EndAngle[0]: %.5f, EndAngle[1]: %.5f, EndAngle[2]: %.5f", tType == TimeCheckpoint ? "Checkpoint" : "Stage", iPoint, details.EndAngle[0], details.EndAngle[1], details.EndAngle[2]);
            PrintToConsoleAll("%s %d: EndVelocity[0]: %.5f, EndVelocity[1]: %.5f, EndVelocity[2]: %.5f", tType == TimeCheckpoint ? "Checkpoint" : "Stage", iPoint, details.EndVelocity[0], details.EndVelocity[1], details.EndVelocity[2]);
        }

        delete snap;
        delete imDetails;
    }

    delete smRecord;
}

public any Native_GetServerRecord(Handle plugin, int numParams)
{
    Styles style = view_as<Styles>(GetNativeCell(1));
    int iLevel = GetNativeCell(2);

    if (g_imServerRecords[style] != null)
    {
        RecordData record;
        if (g_imServerRecords[style].GetArray(iLevel, record, sizeof(record)))
        {
            SetNativeArray(3, record, sizeof(record));
            return true;
        }

    }

    return false;
}
