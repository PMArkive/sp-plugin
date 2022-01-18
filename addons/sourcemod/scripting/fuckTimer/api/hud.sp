public void GetPlayerHudSettings(HTTPResponse response, int userid, const char[] error)
{
    int client = GetClientOfUserId(userid);

    if (client < 1)
    {
        LogError("[HUD.GetPlayerHudSettings] Client is no longer valid.");
        return;
    }

    JSONArray jArray = view_as<JSONArray>(response.Data);
    int iLength = jArray.Length;

    if (response.Status != HTTPStatus_OK || iLength < 1)
    {
        if (response.Status == HTTPStatus_NotFound || iLength < 1)
        {
            PreparePlayerPostHudSettings(client);
            return;
        }

        LogError("[HUD.GetPlayerHudSettings] Something went wrong. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    JSONObject jObj;
    int iLine;
    int iKey;
    char sSide[MAX_NAME_LENGTH];

    for (int i = 0; i < iLength; i++)
    {
        jObj = view_as<JSONObject>(jArray.Get(i));

        iLine = jObj.GetInt("Line");
        iKey = jObj.GetInt("Key");
        jObj.GetString("Side", sSide, sizeof(sSide));

        if (sSide[0] == 'L')
        {
            Player[client].LeftSide[iLine] = iKey;
        }
        else
        {
            Player[client].RightSide[iLine] = iKey;
        }

        delete jObj;
    }
}

void PreparePlayerPostHudSettings(int client, eHUDStyle style = HUD_Default)
{
    switch (style)
    {
        case HUD_Default:
        {
            Player[client].LeftSide = HUD_DEFAULT_LEFT_SIDE;
            Player[client].RightSide = HUD_DEFAULT_RIGHT_SIDE;
        }
        case HUD_KSF:
        {
            Player[client].LeftSide = HUD_KSF_LEFT_SIDE;
            Player[client].RightSide = HUD_KSF_RIGHT_SIDE;
        }
        case HUD_SH:
        {
            Player[client].LeftSide = HUD_SH_LEFT_SIDE;
            Player[client].RightSide = HUD_SH_RIGHT_SIDE;
        }
        case HUD_HORIZON:
        {
            Player[client].LeftSide = HUD_HORIZON_LEFT_SIDE;
            Player[client].RightSide = HUD_HORIZON_RIGHT_SIDE;
        }
        case HUD_GOFREE:
        {
            Player[client].LeftSide = HUD_GOFREE_LEFT_SIDE;
            Player[client].RightSide = HUD_GOFREE_RIGHT_SIDE;
        }
    }

    int iAccountID = GetSteamAccountID(client);

    JSONArray jArray = new JSONArray();
    JSONObject jObj = null;
    
    for (int j = HUD_SIDE_LEFT; j <= HUD_SIDE_RIGHT; j++)
    {
        for (int i = 0; i < MAX_HUD_LINES; i++)
        {
            jObj = new JSONObject();
            jObj.SetInt("PlayerId", iAccountID);
            jObj.SetInt("Line", i);

            if (j == HUD_SIDE_LEFT)
            {
                jObj.SetString("Side", "Left");
                jObj.SetInt("Key", Player[client].LeftSide[i]);
            }
            else
            {
                jObj.SetString("Side", "Right");
                jObj.SetInt("Key", Player[client].RightSide[i]);
            }

            jArray.Push(view_as<JSON>(jObj));
        }
    }

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "PlayerHud/PlayerId/%d", iAccountID);
    fuckTimer_NewAPIHTTPRequest(sEndpoint).Post(jArray, PostPlayerHudSettings, GetClientUserId(client));

    for (int i = 0; i < jArray.Length; i++)
    {
        jObj = view_as<JSONObject>(jArray.Get(i));
        delete jObj;
    }

    delete jArray;
}

public void PostPlayerHudSettings(HTTPResponse response, int userid, const char[] error)
{
    int client = GetClientOfUserId(userid);

    if (client < 1)
    {
        LogError("[HUD.PostPlayerHudSettings] Client is no longer valid.");
        return;
    }

    if (response.Status != HTTPStatus_Created)
    {
        LogError("[HUD.PostPlayerHudSettings] Error while updating database with player hud settings. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    LoadPlayer(client);
}

void PatchPlayerHUDKeys(int client, HUDEntry entry[2])
{
    JSONArray jArray = new JSONArray();
    JSONObject jObj = null;

    for (int i = 0; i <= 1; i++)
    {
        if (entry[i].Line == -1)
        {
            continue;
        }

        jObj = new JSONObject();
        jObj.SetString("Side", entry[i].Side == HUD_SIDE_LEFT ? "Left" : "Right");
        jObj.SetInt("Line", entry[i].Line);
        jObj.SetInt("Key", entry[i].Key);

        jArray.Push(jObj);
    }

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "PlayerHud/PlayerId/%d/", GetSteamAccountID(client));
    fuckTimer_NewAPIHTTPRequest(sEndpoint).Patch(jArray, PatchPlayerHUDKey, GetClientUserId(client));

    for (int i = 0; i < jArray.Length; i++)
    {
        jObj = view_as<JSONObject>(jArray.Get(i));
        delete jObj;
    }
    
    delete jArray;
}

public void PatchPlayerHUDKey(HTTPResponse response, int userid, const char[] error)
{
    int client = GetClientOfUserId(userid);

    if (client < 1)
    {
        LogError("[Players.PatchPlayerHUDKey] Client is no longer valid.");
        return;
    }

    if (response.Status != HTTPStatus_NoContent)
    {
        LogError("[Players.PatchPlayerHUDKey] Something went wrong. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    ClientCommand(client, "sm_hudmove");
}

public void GetRecordsCount(HTTPResponse response, any data, const char[] error)
{
    if (response.Status != HTTPStatus_OK)
    {
        LogError("[HUD.GetRecordsCount] Something went wrong. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    JSONArray jArray = view_as<JSONArray>(response.Data);
    JSONObject jCount;

    for (int i = 0; i < jArray.Length; i++)
    {
        jCount = view_as<JSONObject>(jArray.Get(i));

        int iStyle = jCount.GetInt("StyleId");
        int iLevel = jCount.GetInt("Level");

        if (Core.MapRecordDetails[iStyle] == null)
        {
            Core.MapRecordDetails[iStyle] = new IntMap();
        }

        MapRecordDetails mrDetails;
        mrDetails.Count = jCount.GetInt("Count");
        Core.MapRecordDetails[iStyle].SetArray(iLevel, mrDetails, sizeof(mrDetails));

        delete jCount;
    }

    delete jArray;

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Records/AvgTime/MapId/%d", fuckTimer_GetCurrentMapId());
    fuckTimer_NewAPIHTTPRequest(sEndpoint).Get(GetRecordsAvgTime);
}

public void GetRecordsAvgTime(HTTPResponse response, any records, const char[] error)
{
    if (response.Status != HTTPStatus_OK)
    {
        LogError("[HUD.GetRecordsAvgTime] Something went wrong. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    JSONArray jArray = view_as<JSONArray>(response.Data);
    JSONObject jAvgTime;

    for (int i = 0; i < jArray.Length; i++)
    {
        jAvgTime = view_as<JSONObject>(jArray.Get(i));

        int iStyle = jAvgTime.GetInt("StyleId");
        int iLevel = jAvgTime.GetInt("Level");

        MapRecordDetails mrDetails;
        Core.MapRecordDetails[iStyle].GetArray(iLevel, mrDetails, sizeof(mrDetails));
        mrDetails.AvgTime = jAvgTime.GetFloat("AvgTime");
        Core.MapRecordDetails[iStyle].SetArray(iLevel, mrDetails, sizeof(mrDetails));

        delete jAvgTime;
    }

    delete jArray;
}
