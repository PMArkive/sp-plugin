public void GetPlayerHudSettings(HTTPResponse response, any userid, const char[] error)
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
            LogMessage("[HUD.GetPlayerHudSettings] 404 Player HUD Settings not found, we'll add this player.");
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

        LogMessage("[HUD.GetPlayerHudSettings] (Status Code: %d) Player: %N, Side: %s, Line: %d, Key: %d", response.Status, client, sSide, iLine, iKey);

        if (StrEqual(sSide, "Left", false))
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

void PreparePlayerPostHudSettings(int client, char[] layout = "default")
{
    if (StrEqual(layout, "default", false))
    {
        Player[client].LeftSide = HUD_DEFAULT_LEFT_SIDE;
        Player[client].RightSide = HUD_DEFAULT_RIGHT_SIDE;
    }
    else if (StrEqual(layout, "ksf", false))
    {
        Player[client].LeftSide = HUD_KSF_LEFT_SIDE;
        Player[client].RightSide = HUD_KSF_RIGHT_SIDE;
    }
    else if (StrEqual(layout, "sh", false))
    {
        Player[client].LeftSide = HUD_SH_LEFT_SIDE;
        Player[client].RightSide = HUD_SH_RIGHT_SIDE;
    }
    else if (StrEqual(layout, "horizon", false))
    {
        Player[client].LeftSide = HUD_HORIZON_LEFT_SIDE;
        Player[client].RightSide = HUD_HORIZON_RIGHT_SIDE;
    }
    else if (StrEqual(layout, "gofree", false))
    {
        Player[client].LeftSide = HUD_GOFREE_LEFT_SIDE;
        Player[client].RightSide = HUD_GOFREE_RIGHT_SIDE;
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

    HTTPRequest request = fuckTimer_NewAPIHTTPRequest(sEndpoint);

    request.Post(jArray, PostPlayerHudSettings, GetClientUserId(client));

    for (int i = 0; i < jArray.Length; i++)
    {
        jObj = view_as<JSONObject>(jArray.Get(i));
        delete jObj;
    }

    delete jArray;
}

public void PostPlayerHudSettings(HTTPResponse response, any userid, const char[] error)
{
    int client = GetClientOfUserId(userid);

    if (client < 1)
    {
        LogError("[HUD.PostPlayerHudSettings] Client is no longer valid.");
        return;
    }

    if (response.Status != HTTPStatus_Created)
    {
        LogError("[HUD.PostPlayerHudSettings] Can't post player hud. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    LogMessage("[HUD.PostPlayerHudSettings] Success. Status Code: %d", response.Status);

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

        PrintToChat(client, "%d - Side: %d, Line: %d, Key: %d", i, entry[i].Side, entry[i].Line, entry[i].Key);

        jObj = new JSONObject();
        jObj.SetString("Side", entry[i].Side == HUD_SIDE_LEFT ? "Left" : "Right");
        jObj.SetInt("Line", entry[i].Line);
        jObj.SetInt("Key", entry[i].Key);

        jArray.Push(jObj);
    }

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "PlayerHud/PlayerId/%d/", GetSteamAccountID(client));

    HTTPRequest request = fuckTimer_NewAPIHTTPRequest(sEndpoint);

    request.Patch(jArray, PatchPlayerHUDKey, GetClientUserId(client));

    for (int i = 0; i < jArray.Length; i++)
    {
        jObj = view_as<JSONObject>(jArray.Get(i));
        PrintToChat(client, "Delete jObj%d", i);
        delete jObj;
    }
    
    delete jArray;
}

public void PatchPlayerHUDKey(HTTPResponse response, any userid, const char[] error)
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

    LogMessage("[Players.PatchPlayerHUDKey] Success. Status Code: %d", response.Status);
}
