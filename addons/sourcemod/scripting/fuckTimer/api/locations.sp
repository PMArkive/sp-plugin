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