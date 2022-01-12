/*
    TODO:
        - Adding locations (from api and temp locations) to 2 arraylists (player and shared)
*/
enum LocationStatus
{
    lsTemp = 0,
    lsActive,
    lsShared
}

enum struct LocationData
{
    int Id;
    int MapId;
    int PlayerId;
    char PlayerName[MAX_NAME_LENGTH];
    Styles StyleId;
    int Level;
    TimeType Type;
    float Tickrate;
    float Time;
    float Sync;
    int Speed;
    int Jumps;
    int CSLevel;
    float CSTime;
    LocationStatus Status;
    float Position[3];
    float Angle[3];
    float Velocity[3];
}

enum struct PlayerLocationData
{
    int LastId;
}
// PlayerLocationData LPlayer[MAXPLAYERS + 1];

ArrayList g_alSharedLocations = null;
ArrayList g_alPlayerLocations[MAXPLAYERS + 1] = { null, ... };

static int g_iLowestId = 0;

Locations_RegisterCommands()
{
    RegConsoleCmd("sm_locations", Command_Locations, "Opens the locatios main menu");
}

Locations_RegisterSettings()
{
    fuckTimer_RegisterSetting("ShareLocations", "0");
}

public Action Command_Locations(int client, int args)
{
    if (!fuckTimer_IsClientValid(client, true, true))
    {
        return Plugin_Handled;
    }

    ShowLocationsMainMenu(client);

    return Plugin_Handled;
}

void ShowLocationsMainMenu(int client)
{
    Menu menu = new Menu(MenuHandler_LocationsMain);
    menu.SetTitle("Player Locations");
    menu.AddItem("c", "Create Location\n ");

    char sBuffer[32];
    FormatEx(sBuffer, sizeof(sBuffer), "My Locations (%d)", (g_alPlayerLocations[client] != null) ? g_alPlayerLocations[client].Length : 0);
    menu.AddItem("m", sBuffer);
    FormatEx(sBuffer, sizeof(sBuffer), "Shared Locations (%d)", (g_alSharedLocations != null) ? g_alSharedLocations.Length : 0);
    menu.AddItem("s", sBuffer);

    menu.ExitButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_LocationsMain(Menu menu, MenuAction action, int client, int param)
{
    if (action == MenuAction_Select)
    {
        char sOption[8];
        menu.GetItem(param, sOption, sizeof(sOption));

        if (sOption[0] == 'c')
        {
            int iLevel = fuckTimer_GetClientBonus(client);

            JSONObject jLocation = new JSONObject();

            jLocation.SetInt("Id", g_iLowestId - 1);
            jLocation.SetFloat("Tickrate", GetServerTickrate());
            jLocation.SetInt("MapId", fuckTimer_GetCurrentMapId());
            jLocation.SetInt("PlayerId", GetSteamAccountID(client));
            jLocation.SetInt("StyleId", view_as<int>(fuckTimer_GetClientStyle(client)));
            jLocation.SetInt("Level", iLevel);
            jLocation.SetFloat("Time", fuckTimer_GetClientTime(client, TimeMain));
            jLocation.SetFloat("Sync", fuckTimer_GetClientSync(client));
            jLocation.SetInt("Speed", fuckTimer_GetClientAVGSpeed(client));
            jLocation.SetInt("Jumps", fuckTimer_GetClientJumps(client));

            int iCSLevel = 0;
            float fCSTime = 0.0;
            if (fuckTimer_GetAmountOfCheckpoints(iLevel) > 0)
            {
                iCSLevel = fuckTimer_GetClientCheckpoint(client);

                jLocation.SetString("Type", "Checkpoint");
                jLocation.SetInt("CSLevel", iCSLevel);

                fCSTime = fuckTimer_GetClientTime(client, TimeCheckpoint, iCSLevel);
                jLocation.SetFloat("CSTime", fCSTime);
            }
            else if (fuckTimer_GetAmountOfStages(iLevel) > 0)
            {
                iCSLevel = fuckTimer_GetClientStage(client);

                jLocation.SetString("Type", "Stage");
                jLocation.SetInt("CSLevel", iCSLevel);

                fCSTime = fuckTimer_GetClientTime(client, TimeStage, iCSLevel);
                jLocation.SetFloat("CSTime", fCSTime);
            }
            else
            {
                jLocation.SetString("Type", "Linear");
            }

            float fPosition[3];
            GetClientPosition(client, fPosition);
            jLocation.SetFloat("PositionX", fPosition[0]);
            jLocation.SetFloat("PositionY", fPosition[1]);
            jLocation.SetFloat("PositionZ", fPosition[2]);

            float fAngle[3];
            GetClientAngle(client, fAngle);
            jLocation.SetFloat("AngleX", fAngle[0]);
            jLocation.SetFloat("AngleY", fAngle[1]);
            jLocation.SetFloat("AngleZ", fAngle[2]);

            float fVelocity[3];
            GetClientVelocity(client, fVelocity);
            jLocation.SetFloat("VelocityX", fVelocity[0]);
            jLocation.SetFloat("VelocityY", fVelocity[1]);
            jLocation.SetFloat("VelocityZ", fVelocity[2]);

            char sShare[4];
            fuckTimer_GetClientSetting(client, "ShareLocations", sShare);
            jLocation.SetInt("Status", StringToInt(sShare) + 1);

            // Only allowing posting Locations while timer is running in a main level and player isn't staying in a stage zone
            if (fuckTimer_IsClientTimeRunning(client)  && iLevel == 0 && (iCSLevel == 0 || (iCSLevel > 0 && fCSTime > 0.0)))
            {
                fuckTimer_NewAPIHTTPRequest("Location").Post(jLocation, PostPlayerLocation, GetClientUserId(client));
            }
            else // otherwise set the location status to lsTemp/0
            {
                PrintToChat(client, "Location is not valid and will not saved permanently. You can change the location status over the menu.");
                jLocation.SetInt("Status", 0);
            }

            if (g_alPlayerLocations[client] == null)
            {
                g_alPlayerLocations[client] = new ArrayList();
            }
            
            LocationsJSONObjectToArrayList(jLocation, g_alPlayerLocations[client], true);
        }
        else
        {
            PrintToChat(client, "Soon (Option: %s)...", sOption[0]);
        }

        ShowLocationsMainMenu(client);
    }
    else if (action == MenuAction_End)
    {
        delete menu;
    }

    return 0;
}

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

LocationsJSONArrayToArrayList(JSONArray jArray, ArrayList aArray, bool isCLient)
{
    JSONObject jLocation = null;
    for (int i = 0; i < jArray.Length; i++)
    {
        jLocation = view_as<JSONObject>(jArray.Get(i));
        LocationsJSONObjectToArrayList(jLocation, aArray, isCLient);
    }

    delete jArray;
}

LocationsJSONObjectToArrayList(JSONObject jLocation, ArrayList aArray, bool isClient)
{
    LocationData Location;

    Location.Status = view_as<LocationStatus>(jLocation.GetInt("Status"));

    Location.Id = jLocation.GetInt("Id");

    if (g_iLowestId == 0 || Location.Id < g_iLowestId)
    {
        g_iLowestId = Location.Id;
    }

    Location.MapId = jLocation.GetInt("MapId");
    Location.PlayerId = jLocation.GetInt("PlayerId");

    if (!isClient)
    {
        jLocation.GetString("Name", Location.PlayerName, sizeof(LocationData::PlayerName));
    }

    Location.StyleId = view_as<Styles>(jLocation.GetInt("Level"));
    Location.Level = jLocation.GetInt("Level");
    
    char sType[12];
    jLocation.GetString("Type", sType, sizeof(sType));
    if (sType[0] == 'C')
    {
        Location.Type = TimeCheckpoint;
    }
    else if (sType[0] == 'S')
    {
        Location.Type = TimeStage;
    }
    else
    {
        Location.Type = TimeMain;
    }
    
    Location.Tickrate = jLocation.GetFloat("Tickrate");
    Location.Time = jLocation.GetFloat("Time");
    Location.Sync = jLocation.GetFloat("Sync");
    Location.Speed = jLocation.GetInt("Speed");
    Location.Jumps = jLocation.GetInt("Jumps");
    Location.CSLevel = jLocation.GetInt("CSLevel");
    Location.CSTime = jLocation.GetFloat("CSTime");
    Location.Position[0] = jLocation.GetFloat("PositionX");
    Location.Position[1] = jLocation.GetFloat("PositionY");
    Location.Position[2] = jLocation.GetFloat("PositionZ");
    Location.Angle[0] = jLocation.GetFloat("AngleX");
    Location.Angle[1] = jLocation.GetFloat("AngleY");
    Location.Angle[2] = jLocation.GetFloat("AngleZ");
    Location.Velocity[0] = jLocation.GetFloat("VelocityX");
    Location.Velocity[1] = jLocation.GetFloat("VelocityY");
    Location.Velocity[2] = jLocation.GetFloat("VelocityZ");

    aArray.PushArray(Location, sizeof(Location));

    delete jLocation;
}
