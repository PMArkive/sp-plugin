LoadSharedLocations()
{
    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Location/MapId/%d", fuckTimer_GetCurrentMapId());
    fuckTimer_NewAPIHTTPRequest(sEndpoint).Get(GetLocations, 0);
}

LoadPlayerLocations(int client)
{
    char sEndpoint[MAX_URL_LENGTH];
    FormatEx(sEndpoint, sizeof(sEndpoint), "Location/MapId/%d/PlayerId/%d", fuckTimer_GetCurrentMapId(), GetSteamAccountID(client));
    fuckTimer_NewAPIHTTPRequest(sEndpoint).Get(GetLocations, GetClientUserId(client));
}
