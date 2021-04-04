void GetHTTPClient()
{
    bool bSkip = true;

    if (fuckTimer_GetHTTPClient() != null)
    {
        Core.HTTPClient = fuckTimer_GetHTTPClient();
        bSkip = false;
    }

    if (!bSkip)
    {
        fuckTimer_LoopClients(client, true, true)
        {
            OnClientPutInServer(client);
        }
    }
}

public void GetPlayerData(HTTPResponse response, int userid, const char[] error)
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
            LogMessage("[Players.GetPlayerData] 404 Player Not Found, we'll add this player.");
            PreparePlayerPostData(client);
            return;
        }

        LogError("[Players.GetPlayerData] Something went wrong. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    JSONObject jPlayer = view_as<JSONObject>(response.Data);

    char sName[MAX_NAME_LENGTH];
    jPlayer.GetString("Name", sName, sizeof(sName));

    Player[client].IsActive = jPlayer.GetBool("IsActive");

    delete jPlayer;

    LogMessage("[Players.GetPlayerData] Player Found. Name: %s, Active: %d", sName, Player[client].IsActive);

    LoadPlayerSetting(client, "Style");
    LoadPlayerSetting(client, "InvalidKeyPref");
}

void PreparePlayerPostData(int client)
{
    char sName[MAX_NAME_LENGTH];
    GetClientName(client, sName, sizeof(sName));

    JSONObject jPlayer = new JSONObject();
    jPlayer.SetInt("Id", GetSteamAccountID(client));
    jPlayer.SetString("Name", sName);
    jPlayer.SetBool("IsActive", true);

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Player");

    Core.HTTPClient.Post(sEndpoint, jPlayer, PostPlayerData, GetClientUserId(client));
    delete jPlayer;
}

public void PostPlayerData(HTTPResponse response, int userid, const char[] error)
{
    int client = GetClientOfUserId(userid);

    if (client < 1)
    {
        LogError("[Players.PostPlayerData] Client is no longer valid.");
        return;
    }

    if (response.Status != HTTPStatus_Created)
    {
        LogError("[Players.PostPlayerData] Can't post player data. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    LogMessage("[Players.PostPlayerData] Success. Status Code: %d", response.Status);

    OnClientPutInServer(client);
}

void LoadPlayerSetting(int client, const char[] setting)
{
    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "PlayerSettings/PlayerId/%d/Setting/%s", GetSteamAccountID(client), setting);

    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    pack.WriteString(setting);

    Core.HTTPClient.Get(sEndpoint, GetPlayerSetting, pack);
}

public void GetPlayerSetting(HTTPResponse response, DataPack pack, const char[] error)
{
    pack.Reset();

    int client = GetClientOfUserId(pack.ReadCell());

    char sSetting[MAX_SETTING_LENGTH];
    pack.ReadString(sSetting, sizeof(sSetting));

    delete pack;

    if (client < 1)
    {
        LogError("[Players.GetPlayerSetting] Client is no longer valid.");
        return;
    }

    if (response.Status != HTTPStatus_OK)
    {
        if (response.Status == HTTPStatus_NotFound)
        {
            LogMessage("[Players.GetPlayerSetting] 404 Setting \"%s\" Not Found, we'll add it.", sSetting);
            PreparePlayerPostSetting(client, sSetting);
            return;
        }

        LogError("[Players.GetPlayerSetting] Something went wrong. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    JSONObject jSetting = view_as<JSONObject>(response.Data);

    char sValue[MAX_SETTING_VALUE_LENGTH];
    jSetting.GetString("Value", sValue, sizeof(sValue));
    
    if (StrEqual(sSetting, "Style", false))
    {
        Player[client].Style = view_as<Styles>(StringToInt(sValue));
    }
    else if (StrEqual(sSetting, "InvalidKeyPref", false))
    {
        Player[client].InvalidKeyPref = view_as<eInvalidKeyPref>(StringToInt(sValue));
    }

    LogMessage("[Players.GetPlayerSetting] Success for setting \"%s\". Status Code: %d", sSetting, response.Status);
}

void PreparePlayerPostSetting(int client, const char[] setting)
{
    JSONObject jSetting = new JSONObject();
    jSetting.SetInt("PlayerId", GetSteamAccountID(client));
    jSetting.SetString("Setting", setting);

    char sBuffer[MAX_SETTING_VALUE_LENGTH];

    if (StrEqual(setting, "Style", false))
    {
        IntToString(view_as<int>(StyleNormal), sBuffer, sizeof(sBuffer));
        jSetting.SetString("Value", sBuffer);
    }
    else if (StrEqual(setting, "InvalidKeyPref", false))
    {
        IntToString(view_as<int>(IKStop), sBuffer, sizeof(sBuffer));
        jSetting.SetString("Value", sBuffer);
    }

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "PlayerSettings");

    Core.HTTPClient.Post(sEndpoint, jSetting, PostPlayerSetting, GetClientUserId(client));

    delete jSetting;
}

public void PostPlayerSetting(HTTPResponse response, int userid, const char[] error)
{
    int client = GetClientOfUserId(userid);

    if (client < 1)
    {
        LogError("[Players.PostPlayerSetting] Client is no longer valid.");
        return;
    }

    if (response.Status != HTTPStatus_Created)
    {
        LogError("[Players.PostPlayerSetting] Can't post player setting. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    JSONObject jSetting = view_as<JSONObject>(response.Data);

    char sSetting[MAX_SETTING_LENGTH], sValue[MAX_SETTING_VALUE_LENGTH];
    jSetting.GetString("Setting", sSetting, sizeof(sSetting));
    jSetting.GetString("Value", sValue, sizeof(sValue));

    delete jSetting;
    
    if (StrEqual(sSetting, "Style", false))
    {
        Player[client].Style = view_as<Styles>(StringToInt(sValue));
    }
    else if (StrEqual(sSetting, "InvalidKeyPref", false))
    {
        Player[client].InvalidKeyPref = view_as<eInvalidKeyPref>(StringToInt(sValue));
    }

    LogMessage("[Players.PostPlayerSetting] Success for setting \"%s\". Status Code: %d", sSetting, response.Status);
}

void SetPlayerSetting(int client, const char[] setting, const char[] value)
{
    JSONObject jSetting = new JSONObject();
    jSetting.SetString("Value", value);

    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "PlayerSettings/PlayerId/%d/Setting/%s", GetSteamAccountID(client), setting);

    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    pack.WriteString(setting);
    pack.WriteString(value);
    Core.HTTPClient.Patch(sEndpoint, jSetting, PatchPlayerSetting, pack);

    delete jSetting;
}

public void PatchPlayerSetting(HTTPResponse response, DataPack pack, const char[] error)
{
    pack.Reset();

    int client = GetClientOfUserId(pack.ReadCell());

    char sSetting[MAX_SETTING_LENGTH];
    pack.ReadString(sSetting, sizeof(sSetting));

    char sValue[MAX_SETTING_VALUE_LENGTH];
    pack.ReadString(sValue, sizeof(sValue));

    delete pack;
    delete response.Data;

    if (client < 1)
    {
        LogError("[Players.PatchPlayerSetting] Client is no longer valid.");
        return;
    }

    if (response.Status != HTTPStatus_NoContent)
    {
        LogError("[Players.PatchPlayerSetting] Something went wrong. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    LogMessage("[Players.PatchPlayerSetting] Success for setting \"%s\". Status Code: %d", sSetting, response.Status);
}
