public void GetPlayerData(HTTPResponse response, any userid, const char[] error)
{
    int client = GetClientOfUserId(userid);

    if (client < 1)
    {
        LogError("[Players.GetPlayerData] Client is no longer valid.");
        return;
    }

    if (response.Status != HTTPStatus_OK)
    {
        if (response.Status == HTTPStatus_NotFound)
        {
            PreparePlayerPostData(client);
            return;
        }

        LogError("[Players.GetPlayerData] Something went wrong. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    JSONObject jPlayer = view_as<JSONObject>(response.Data);

    char sName[MAX_NAME_LENGTH];
    jPlayer.GetString("Name", sName, sizeof(sName));

    Player[client].Status = view_as<PlayerStatus>(jPlayer.GetInt("Status"));

    delete jPlayer;

    Call_StartForward(Core.OnPlayerLoaded);
    Call_PushCell(client);
    Call_Finish();

    delete Player[client].Settings;
    Player[client].Settings = new StringMap();
    
    LoadPlayerSetting(client);

    UpdatePlayer(client);
}

void PreparePlayerPostData(int client)
{
    char sName[MAX_NAME_LENGTH];
    GetClientName(client, sName, sizeof(sName));

    JSONObject jPlayer = new JSONObject();
    jPlayer.SetInt("Id", GetSteamAccountID(client));

    char sIP[18];
    GetClientIP(client, sIP, sizeof(sIP));
    jPlayer.SetString("FirstIP", sIP);
    jPlayer.SetString("LastIP", sIP);

    char sCommunityId[32];
    GetClientAuthId(client, AuthId_SteamID64, sCommunityId, sizeof(sCommunityId));
    jPlayer.SetString("CommunityId", sCommunityId);

    jPlayer.SetString("Name", sName);
    jPlayer.SetInt("Status", 1);

    fuckTimer_NewAPIHTTPRequest("Player").Post(jPlayer, PostPlayerData, GetClientUserId(client));
    delete jPlayer;
}

public void PostPlayerData(HTTPResponse response, any userid, const char[] error)
{
    int client = GetClientOfUserId(userid);

    if (client < 1)
    {
        LogError("[Players.PostPlayerData] Client is no longer valid.");
        return;
    }

    if (response.Status != HTTPStatus_Created)
    {
        LogError("[Players.PostPlayerData] Error while updating database with player details. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    LoadPlayer(client);
}

void LoadPlayerSetting(int client)
{
    char sEndpoint[MAX_URL_LENGTH];
    Format(sEndpoint, sizeof(sEndpoint), "PlayerSettings/PlayerId/%d", GetSteamAccountID(client));
    fuckTimer_NewAPIHTTPRequest(sEndpoint).Get(GetPlayerSetting, GetClientUserId(client));
}

public void GetPlayerSetting(HTTPResponse response, any userid, const char[] error)
{
    int client = GetClientOfUserId(userid);

    if (client < 1)
    {
        LogError("[Players.GetPlayerSetting] Client is no longer valid.");
        return;
    }

    char sSetting[MAX_SETTING_LENGTH];
    ArrayList alSettings = new ArrayList(ByteCountToCells(sizeof(sSetting)));
    StringMapSnapshot snap = Core.Settings.Snapshot();

    for (int i = 0; i < snap.Length; i++)
    {
        snap.GetKey(i, sSetting, sizeof(sSetting));
        alSettings.PushString(sSetting);
    }

    sSetting[0] = '\0';

    JSONArray jArray = view_as<JSONArray>(response.Data);
    JSONObject jSetting;
    char sValue[MAX_SETTING_VALUE_LENGTH];

    for (int i = 0; i < jArray.Length; i++)
    {
        jSetting = view_as<JSONObject>(jArray.Get(i));
        jSetting.GetString("Setting", sSetting, sizeof(sSetting));
        jSetting.GetString("Value", sValue, sizeof(sValue));

        Player[client].Settings.SetString(sSetting, sValue);

        int iIndex = alSettings.FindString(sSetting);

        if (iIndex != -1)
        {
            alSettings.Erase(iIndex);
        }

        delete jSetting;
        sSetting[0] = '\0';
    }

    if (alSettings.Length > 0)
    {
        for (int i = 0; i < alSettings.Length; i++)
        {
            alSettings.GetString(i, sSetting, sizeof(sSetting));
            PreparePlayerPostSetting(client, sSetting);
        }
    }

    delete alSettings;
}

void PreparePlayerPostSetting(int client, const char[] setting)
{
    JSONObject jSetting = new JSONObject();
    jSetting.SetInt("PlayerId", GetSteamAccountID(client));
    jSetting.SetString("Setting", setting);

    char sValue[MAX_SETTING_VALUE_LENGTH];
    Core.Settings.GetString(setting, sValue, sizeof(sValue));
    jSetting.SetString("Value", sValue);

    fuckTimer_NewAPIHTTPRequest("PlayerSettings").Post(jSetting, PostPlayerSetting, GetClientUserId(client));

    delete jSetting;
}

public void PostPlayerSetting(HTTPResponse response, any userid, const char[] error)
{
    int client = GetClientOfUserId(userid);

    if (client < 1)
    {
        LogError("[Players.PostPlayerSetting] Client is no longer valid.");
        return;
    }

    if (response.Status != HTTPStatus_Created)
    {
        LogError("[Players.PostPlayerSetting] Error while updating database with player setting details. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    JSONObject jSetting = view_as<JSONObject>(response.Data);

    char sSetting[MAX_SETTING_LENGTH], sValue[MAX_SETTING_VALUE_LENGTH];
    jSetting.GetString("Setting", sSetting, sizeof(sSetting));
    jSetting.GetString("Value", sValue, sizeof(sValue));

    delete jSetting;

    Player[client].Settings.SetString(sSetting, sValue);
}

void SetPlayerSetting(int client, const char[] setting, const char[] value)
{
    Player[client].Settings.SetString(setting, value);

    JSONObject jSetting = new JSONObject();
    jSetting.SetString("Value", value);

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "PlayerSettings/PlayerId/%d/Setting/%s", GetSteamAccountID(client), setting);
    
    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    pack.WriteString(setting);
    pack.WriteString(value);
    
    fuckTimer_NewAPIHTTPRequest(sEndpoint).Patch(jSetting, PatchPlayerSetting, pack);

    delete jSetting;
}

public void PatchPlayerSetting(HTTPResponse response, any pack, const char[] error)
{
    view_as<DataPack>(pack).Reset();

    int client = GetClientOfUserId(view_as<DataPack>(pack).ReadCell());

    char sSetting[MAX_SETTING_LENGTH];
    view_as<DataPack>(pack).ReadString(sSetting, sizeof(sSetting));

    char sValue[MAX_SETTING_VALUE_LENGTH];
    view_as<DataPack>(pack).ReadString(sValue, sizeof(sValue));

    delete view_as<DataPack>(pack);

    if (client < 1)
    {
        LogError("[Players.PatchPlayerSetting] Client is no longer valid.");
        return;
    }

    if (response.Status != HTTPStatus_NoContent)
    {
        LogError("[Players.PatchPlayerSetting] Something went wrong (Setting: %s). Status Code: %d, Error: %s", sSetting, response.Status, error);
        return;
    }
}

public void UpdatePlayerData(HTTPResponse response, any userid, const char[] error)
{
    if (response.Status != HTTPStatus_OK)
    {
        SetFailState("[Players.UpdatePlayerData] Something went wrong. Status Code: %d, Error: %s", response.Status, error);
        return;
    }
}
