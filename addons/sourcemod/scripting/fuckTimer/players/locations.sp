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
    menu.AddItem("m", "My Locations");
    menu.AddItem("s", "Shared Locations");
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

            // TODO: Store this locally too

            delete jLocation;
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
