public void GetRecords(HTTPResponse response, any pack, const char[] error)
{
    if (response.Status != HTTPStatus_OK)
    {
        SetFailState("[Records.GetRecords] Something went wrong. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    view_as<DataPack>(pack).Reset();
    int client = GetClientOfUserId(view_as<DataPack>(pack).ReadCell());
    delete view_as<DataPack>(pack);

    JSONArray jMainrecords = view_as<JSONArray>(response.Data);

    if (jMainrecords.Length < 1)
    {
        LogMessage("[Records.GetRecords] We didn't found any records for this map...");
        return;
    }

    for (int i = 0; i <= MAX_STYLES; i++)
    {
        if (client > 0)
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
        else
        {
            if (Core.Records[i] != null)
            {
                RecordData record;
                IntMapSnapshot snap = Core.Records[i].Snapshot();

                for (int j = 0; j < snap.Length; j++)
                {
                    Core.Records[i].GetArray(j, record, sizeof(record));
                    delete record.Details;
                }

                delete snap;
            }

            delete Core.Records[i];
        }
    }

    int iStyles = fuckTimer_GetStyles().Size + 10;
    LogMessage("iStyles: %d", iStyles);

    if (iStyles > MAX_STYLES)
    {
        iStyles = MAX_STYLES;
    }

    for (int i = 1; i <= iStyles; i++)
    {
        if (client > 0)
        {
            Player[client].Records[i] = new IntMap();
        }
        else
        {
            Core.Records[i] = new IntMap();
        }
    }

    LogMessage("[Records.GetRecords] We found %d records for this map", jMainrecords.Length);

    JSONObject jMainRecord = null;

    for (int i = 0; i < jMainrecords.Length; i++)
    {
        jMainRecord = view_as<JSONObject>(jMainrecords.Get(i));

        RecordData record;
        record.PlayerId = jMainRecord.GetInt("PlayerId");
        jMainRecord.GetString("Name", record.PlayerName, sizeof(RecordData::PlayerName));
        record.Style = view_as<Styles>(jMainRecord.GetInt("StyleId"));
        record.Level = jMainRecord.GetInt("Level");

        char sType[12];
        jMainRecord.GetString("Type", sType, sizeof(sType));
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

        record.Tickrate = jMainRecord.GetFloat("Tickrate");
        record.Time = jMainRecord.GetFloat("Time");
        record.TimeInZone = jMainRecord.GetFloat("TimeInZone");
        record.Attempts = jMainRecord.GetInt("Attempts");
        record.Status = jMainRecord.GetInt("Status");
        record.StartPosition[0] = jMainRecord.GetFloat("StartPositionX");
        record.StartPosition[1] = jMainRecord.GetFloat("StartPositionY");
        record.StartPosition[2] = jMainRecord.GetFloat("StartPositionZ");
        record.EndPosition[0] = jMainRecord.GetFloat("EndPositionX");
        record.EndPosition[1] = jMainRecord.GetFloat("EndPositionY");
        record.EndPosition[2] = jMainRecord.GetFloat("EndPositionZ");
        record.StartAngle[0] = jMainRecord.GetFloat("StartAngleX");
        record.StartAngle[1] = jMainRecord.GetFloat("StartAngleY");
        record.StartAngle[2] = jMainRecord.GetFloat("StartAngleZ");
        record.EndAngle[0] = jMainRecord.GetFloat("EndAngleX");
        record.EndAngle[1] = jMainRecord.GetFloat("EndAngleY");
        record.EndAngle[2] = jMainRecord.GetFloat("EndAngleZ");
        record.StartVelocity[0] = jMainRecord.GetFloat("StartVelocityX");
        record.StartVelocity[1] = jMainRecord.GetFloat("StartVelocityY");
        record.StartVelocity[2] = jMainRecord.GetFloat("StartVelocityZ");
        record.EndVelocity[0] = jMainRecord.GetFloat("EndVelocityX");
        record.EndVelocity[1] = jMainRecord.GetFloat("EndVelocityY");
        record.EndVelocity[2] = jMainRecord.GetFloat("EndVelocityZ");

        LogMessage("Style: %d, Level: %d, Player: %s (Id: %d), Type: %s, Tickrate: %.1f (%.1f), Time: %.3f, TimeInZone: %.3f, Attempts: %d, Status: %d, StartPosition: %.3f/%.3f/%.3f", record.Style, record.Level, record.PlayerName, record.PlayerId, sType, record.Tickrate, jMainRecord.GetFloat("Tickrate"), record.Time, record.TimeInZone, record.Attempts, record.Status, record.StartPosition[0], record.StartPosition[1], record.StartPosition[2]);

        if (record.Type == TimeCheckpoint || record.Type == TimeStage)
        {
            if (record.Details == null)
            {
                record.Details = new IntMap();
            }

            JSONArray jCSRecords = view_as<JSONArray>(jMainRecord.Get("*items"));
            JSONObject jCSRecord = null;

            for (int j = 0; j < jCSRecords.Length; j++)
            {
                jCSRecord = view_as<JSONObject>(jCSRecords.Get(j));

                CSDetails details;
                int iCSLevel = jCSRecord.GetInt(record.Type == TimeStage ? "Stage" : "Checkpoint");
                details.Time = jCSRecord.GetFloat("Time");

                if (record.Type == TimeStage)
                {
                    details.TimeInZone = jCSRecord.GetFloat("TimeInZone");
                    details.Attempts = jCSRecord.GetInt("Attempts");

                    details.StartPosition[0] = jCSRecord.GetFloat("StartPositionX");
                    details.StartPosition[1] = jCSRecord.GetFloat("StartPositionY");
                    details.StartPosition[2] = jCSRecord.GetFloat("StartPositionZ");
                    details.StartAngle[0] = jCSRecord.GetFloat("StartAngleX");
                    details.StartAngle[1] = jCSRecord.GetFloat("StartAngleY");
                    details.StartAngle[2] = jCSRecord.GetFloat("StartAngleZ");
                    details.StartVelocity[0] = jCSRecord.GetFloat("StartVelocityX");
                    details.StartVelocity[1] = jCSRecord.GetFloat("StartVelocityY");
                    details.StartVelocity[2] = jCSRecord.GetFloat("StartVelocityZ");
                    details.EndPosition[0] = jCSRecord.GetFloat("EndPositionX");
                    details.EndPosition[1] = jCSRecord.GetFloat("EndPositionY");
                    details.EndPosition[2] = jCSRecord.GetFloat("EndPositionZ");
                    details.EndAngle[0] = jCSRecord.GetFloat("EndAngleX");
                    details.EndAngle[1] = jCSRecord.GetFloat("EndAngleY");
                    details.EndAngle[2] = jCSRecord.GetFloat("EndAngleZ");
                    details.EndVelocity[0] = jCSRecord.GetFloat("EndVelocityX");
                    details.EndVelocity[1] = jCSRecord.GetFloat("EndVelocityY");
                    details.EndVelocity[2] = jCSRecord.GetFloat("EndVelocityZ");

                    LogMessage("Stage: %d, Time: %.3f, TimeInZone: %.3f, Attempts: %d", iCSLevel, details.Time, details.TimeInZone, details.Attempts);
                }
                else
                {
                    details.StartPosition[0] = jCSRecord.GetFloat("PositionX");
                    details.StartPosition[1] = jCSRecord.GetFloat("PositionY");
                    details.StartPosition[2] = jCSRecord.GetFloat("PositionZ");
                    details.StartAngle[0] = jCSRecord.GetFloat("AngleX");
                    details.StartAngle[1] = jCSRecord.GetFloat("AngleY");
                    details.StartAngle[2] = jCSRecord.GetFloat("AngleZ");
                    details.StartVelocity[0] = jCSRecord.GetFloat("VelocityX");
                    details.StartVelocity[1] = jCSRecord.GetFloat("VelocityY");
                    details.StartVelocity[2] = jCSRecord.GetFloat("VelocityZ");

                    LogMessage("Checkpoint: %d, Time: %.3f", iCSLevel, details.Time);
                }

                record.Details.SetArray(iCSLevel, details, sizeof(details));

                delete jCSRecord;
            }

            delete jCSRecords;
        }

        if (client > 0)
        {
            Player[client].Records[record.Style].SetArray(record.Level, record, sizeof(record));
        }
        else
        {
            Core.Records[record.Style].SetArray(record.Level, record, sizeof(record));
        }

        delete jMainRecord;
    }
}

void PostPlayerRecord(int client, bool firstRecord, JSONObject record)
{
    if (client){}

    if (firstRecord)
    {
        char sFile[PLATFORM_MAX_PATH + 1];
        BuildPath(Path_SM, sFile, sizeof(sFile), "data/fucktimer/record_%s.txt", "post");
        record.ToFile(sFile, 0x1F);
        // fuckTimer_NewAPIHTTPRequest(sEndpoint).Post(record, SendRecord, GetClientUserId(client));
    }
    else
    {
        char sFile[PLATFORM_MAX_PATH + 1];
        BuildPath(Path_SM, sFile, sizeof(sFile), "data/fucktimer/record_%s.txt", "put");
        record.ToFile(sFile, 0x1F);
        // fuckTimer_NewAPIHTTPRequest(sEndpoint).Put(record, SendRecord, GetClientUserId(client));
    }
}
