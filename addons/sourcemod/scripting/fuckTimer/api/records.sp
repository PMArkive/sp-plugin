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
        SetFailState("[Records.GetServerRecords] We didn't found any records for this map...");
        return;
    }
}
