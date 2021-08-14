public void GetServerRecords(HTTPResponse response, any value, const char[] error)
{
    if (response.Status != HTTPStatus_OK)
    {
        SetFailState("[Records.GetServerRecords] Something went wrong. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    JSONArray jsonArray = view_as<JSONArray>(response.Data);

    if (jsonArray.Length < 1)
    {
        LogMessage("[Records.GetServerRecords] We didn't found any records for this map...");
        return;
    }

    for (int i = 0; i <= MAX_STYLES; i++)
    {
        delete g_imServerRecords[i];
    }

    int iStyles = fuckTimer_GetStyles().Size + 10; // TODO: Remove +10
    LogMessage("iStyles: %d", iStyles);

    if (iStyles > MAX_STYLES)
    {
        iStyles = MAX_STYLES;
    }

    for (int i = 1; i <= iStyles; i++)
    {
        g_imServerRecords[i] = new IntMap();
    }

    LogMessage("[Records.GetServerRecords] We found %d records for this map", jsonArray.Length);

    for (int i = 0; i < jsonArray.Length; i++)
    {
        JSONObject jObj = view_as<JSONObject>(jsonArray.Get(i));

        RecordData record;
        record.PlayerId = jObj.GetInt("PlayerId");
        jObj.GetString("Name", record.PlayerName, sizeof(RecordData::PlayerName));
        record.Style = view_as<Styles>(jObj.GetInt("StyleId"));
        record.Level = jObj.GetInt("Level");

        char sType[12];
        jObj.GetString("Type", sType, sizeof(sType));
        if (StrEqual(sType, "Checkpoint", false))
        {
            record.Type = TimeCheckpoint;
        }
        else if (StrEqual(sType, "Stage", false))
        {
            record.Type = TimeStage;
        }
        else
        {
            record.Type = TimeMain;
        }

        record.Tickrate = jObj.GetFloat("Tickrate");
        record.Time = jObj.GetFloat("Time");
        record.TimeInZone = jObj.GetFloat("TimeInZone");
        record.Attempts = jObj.GetInt("Attempts");
        record.Status = jObj.GetInt("Status");
        record.StartPosition[0] = jObj.GetFloat("StartPositionX");
        record.StartPosition[1] = jObj.GetFloat("StartPositionY");
        record.StartPosition[2] = jObj.GetFloat("StartPositionZ");
        record.EndPosition[0] = jObj.GetFloat("EndPositionX");
        record.EndPosition[1] = jObj.GetFloat("EndPositionY");
        record.EndPosition[2] = jObj.GetFloat("EndPositionZ");
        record.StartAngle[0] = jObj.GetFloat("StartAngleX");
        record.StartAngle[1] = jObj.GetFloat("StartAngleY");
        record.StartAngle[2] = jObj.GetFloat("StartAngleZ");
        record.EndAngle[0] = jObj.GetFloat("EndAngleX");
        record.EndAngle[1] = jObj.GetFloat("EndAngleY");
        record.EndAngle[2] = jObj.GetFloat("EndAngleZ");
        record.StartVelocity[0] = jObj.GetFloat("StartVelocityX");
        record.StartVelocity[1] = jObj.GetFloat("StartVelocityY");
        record.StartVelocity[2] = jObj.GetFloat("StartVelocityZ");
        record.EndVelocity[0] = jObj.GetFloat("EndVelocityX");
        record.EndVelocity[1] = jObj.GetFloat("EndVelocityY");
        record.EndVelocity[2] = jObj.GetFloat("EndVelocityZ");

        LogMessage("Style: %d, Level: %d, Player: %s (Id: %d), Type: %s, Tickrate: %.1f, Time: %.3f, TimeInZone: %.3f, Attempts: %d, Status: %d", record.Style, record.Level, record.PlayerName, record.PlayerId, sType, record.Tickrate, record.Time, record.TimeInZone, record.Attempts, record.Status);

        g_imServerRecords[record.Style].SetArray(record.Level, record, sizeof(record));

        delete jObj;
    }
}
