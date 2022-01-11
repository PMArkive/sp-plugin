public void GetLocations(HTTPResponse response, any userid, const char[] error)
{
    JSONArray jLocations = view_as<JSONArray>(response.Data);

    int client = userid != 0 ? GetClientOfUserId(userid) : 0;
    bool bValidClient = fuckTimer_IsClientValid(client, true, true);

    if (bValidClient)
    {
        LogMessage("[Locations.GetLocations] We found %d locations for \"%N\" for this map", jLocations.Length, client);
    }
    else
    {
        LogMessage("[Locations.GetLocations] We found %d shared locations for this map", jLocations.Length);
    }
}

public void PostPlayerLocation(HTTPResponse response, any userid, const char[] error)
{
    int client = GetClientOfUserId(userid);

    if (client < 1)
    {
        LogError("[Locations.PostPlayerLocation] Client is no longer valid.");
        return;
    }

    if (response.Status != HTTPStatus_Created)
    {
        LogError("[Locations.PostPlayerLocation] Error while updating database with player setting details. Status Code: %d, Error: %s", response.Status, error);
        return;
    }

    JSONObject jLocation = view_as<JSONObject>(response.Data);

    PrintToChat(client, "Location #%d has been created successfully!", jLocation.GetInt("Id"));

    delete jLocation;
}