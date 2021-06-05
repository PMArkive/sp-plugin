#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckTimer_stocks>
#include <fuckTimer_api>
#include <fuckTimer_timer>

public Plugin myinfo =
{
    name = FUCKTIMER_PLUGIN_NAME ... "Records",
    author = FUCKTIMER_PLUGIN_AUTHOR,
    description = FUCKTIMER_PLUGIN_DESCRIPTION,
    version = FUCKTIMER_PLUGIN_VERSION,
    url = FUCKTIMER_PLUGIN_URL
};

public void fuckTimer_OnClientTimerEnd(int client, StringMap temp)
{
    StringMap record = view_as<StringMap>(CloneHandle(temp));

    int iPlayerId;
    record.GetValue("PlayerId", iPlayerId);
    PrintToConsoleAll("Main: PlayerId: %d", iPlayerId);

    char sPlayerName[MAX_NAME_LENGTH];
    record.GetString("PlayerName", sPlayerName, sizeof(sPlayerName));
    PrintToConsoleAll("Main: PlayerName: %s", sPlayerName);

    Styles iStyle;
    record.GetValue("StyleId", iStyle);
    PrintToConsoleAll("Main: Style: %d", iStyle);

    int iMapId;
    record.GetValue("MapId", iMapId);
    PrintToConsoleAll("Main: MapId: %d", iMapId);

    int iZoneNormal;
    record.GetValue("ZoneNormal", iZoneNormal);
    PrintToConsoleAll("Main: ZoneNormal: %d", iZoneNormal);

    TimeType tType;
    record.GetValue("Type", tType);
    PrintToConsoleAll("Main: Type: %d", tType);

    float fTickrate;
    record.GetValue("Tickrate", fTickrate);
    PrintToConsoleAll("Main: Tickrate: %.2f", fTickrate);

    float fDuration;
    record.GetValue("Duration", fDuration);
    PrintToConsoleAll("Main: Duration: %.3f", fDuration);

    float fTimeInZone;
    record.GetValue("TimeInZone", fTimeInZone);
    PrintToConsoleAll("Main: TimeInZone: %.3f", fTimeInZone);

    int iAttempts;
    record.GetValue("Attempts", iAttempts);
    PrintToConsoleAll("Main: Attempts: %d", iAttempts);

    float fStartPosition[3];
    record.GetArray("StartPosition", fStartPosition, 3);
    PrintToConsoleAll("Main: StartPosition[0]: %.5f, StartPosition[1]: %.5f, StartPosition[2]: %.5f", fStartPosition[0], fStartPosition[1], fStartPosition[2]);

    float fStartAngle[3];
    record.GetArray("StartAngle", fStartAngle, 3);
    PrintToConsoleAll("Main: StartAngle[0]: %.5f, StartAngle[1]: %.5f, StartAngle[2]: %.5f", fStartAngle[0], fStartAngle[1], fStartAngle[2]);

    float fStartVelocity[3];
    record.GetArray("StartVelocity", fStartVelocity, 3);
    PrintToConsoleAll("Main: StartVelocity[0]: %.5f, StartVelocity[1]: %.5f, StartVelocity[2]: %.5f", fStartVelocity[0], fStartVelocity[1], fStartVelocity[2]);

    float fEndPosition[3];
    record.GetArray("EndPosition", fEndPosition, 3);
    PrintToConsoleAll("Main: EndPosition[0]: %.5f, EndPosition[1]: %.5f, EndPosition[2]: %.5f", fEndPosition[0], fEndPosition[1], fEndPosition[2]);

    float fEndAngle[3];
    record.GetArray("EndAngle", fEndAngle, 3);
    PrintToConsoleAll("Main: EndAngle[0]: %.5f, EndAngle[1]: %.5f, EndAngle[2]: %.5f", fEndAngle[0], fEndAngle[1], fEndAngle[2]);

    float fEndVelocity[3];
    record.GetArray("EndVelocity", fEndVelocity, 3);
    PrintToConsoleAll("Main: EndVelocity[0]: %.5f, EndVelocity[1]: %.5f, EndVelocity[2]: %.5f", fEndVelocity[0], fEndVelocity[1], fEndVelocity[2]);

    any aDetails;
    record.GetValue("Details", aDetails);

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

    delete record;
}
