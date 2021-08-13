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

    LogMessage("[Records.GetServerRecords] We found %d records for this map", jsonArray.Length);

    for (int i = 0; i < jsonArray.Length; i++)
    {
        JSONObject jObj = view_as<JSONObject>(jsonArray.Get(i));
        JSONArray jArr = view_as<JSONArray>(jObj.Get("*items"));
        char sType[12];
        jObj.GetString("Type", sType, sizeof(sType));
        LogMessage("We found %d %s%s for record %d.", jArr.Length, sType, jArr.Length != 1 ? "s" : "", i+1);
    }
}
