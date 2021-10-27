

public any Native_SetClientHUDLayout(Handle plugin, int numParams)
{
    PreparePlayerPostHudSettings(GetNativeCell(1), view_as<eHUDStyle>(GetNativeCell(2)));
    
    return 0;
}

public any Native_MoveClientHUDKey(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    eHUDKeys iKey = view_as<eHUDKeys>(GetNativeCell(2));
    int iSide = view_as<bool>(GetNativeCell(3));
    int iLine = GetNativeCell(4);

    HUDEntry hEntry[2];
    hEntry[0].Side = iSide;
    hEntry[0].Line = iLine;
    hEntry[0].Key = iKey;

    bool swapPositions = view_as<bool>(GetNativeCell(5));

    bool success = GetOldPosition(client, iKey, hEntry);

    if (success)
    {
        if (iSide == HUD_SIDE_LEFT)
        {
            hEntry[1].Key = Player[client].LeftSide[iLine];
        }
        else
        {
            hEntry[1].Key = Player[client].RightSide[iLine];
        }
    }
    else
    {
        hEntry[1].Line = -1;
    }

    if (!swapPositions)
    {
        hEntry[1].Key = 0;
    }

    for (int i = 0; i <= 1; i++)
    {
        if (hEntry[i].Line == -1)
        {
            continue;
        }
        
        if (hEntry[i].Side == HUD_SIDE_LEFT)
        {
            Player[client].LeftSide[hEntry[i].Line] = hEntry[i].Key;
        }
        else
        {
            Player[client].RightSide[hEntry[i].Line] = hEntry[i].Key;
        }
    }

    PatchPlayerHUDKeys(client, hEntry);
    
    return 0;
}
