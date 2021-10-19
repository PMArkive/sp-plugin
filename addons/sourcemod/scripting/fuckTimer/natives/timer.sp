
public any Native_GetClientTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    TimeType type = GetNativeCell(2);

    int level = GetNativeCell(3);

    CSDetails details;

    if (type == TimeMain)
    {
        if (Player[client].Time > 0.0)
        {
            return Player[client].Time;
        }
    }
    else if (type == TimeCheckpoint)
    {
        if (Player[client].CheckpointDetails != null)
        {
            Player[client].CheckpointDetails.GetArray(level, details, sizeof(details));
            return details.Time;
        }
    }
    else if (type == TimeStage)
    {
        if (Player[client].StageDetails != null)
        {
            Player[client].StageDetails.GetArray(level, details, sizeof(details));
            return details.Time;
        }
    }

    return 0.0;
}

public int Native_IsClientTimeRunning(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    if (Player[client].Time > 0.0)
    {
        return true;
    }
    else if (Player[client].CheckpointDetails != null)
    {
        return true;
    }
    else if (Player[client].StageDetails != null)
    {
        return true;
    }

    return false;
}

public any Native_GetClientTimeInZone(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int level = GetNativeCell(2);

    if (level == 0)
    {
        return Player[client].TimeInZone;
    }
    else if (level > 0)
    {
        return GetIntMapTimeInZone(Player[client].StageDetails, level);
    }

    return 0.0;
}

public int Native_GetClientAttempts(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int level = GetNativeCell(2);

    if (level == 0)
    {
        return Player[client].Attempts;
    }
    else if (level > 0)
    {
        return GetIntMapAttempts(Player[client].StageDetails, level);
    }

    return 0;
}

public int Native_GetClientCheckpoint(Handle plugin, int numParams)
{
    return Player[GetNativeCell(1)].Checkpoint;
}

public int Native_GetClientStage(Handle plugin, int numParams)
{
    return Player[GetNativeCell(1)].Stage;
}

public int Native_GetClientBonus(Handle plugin, int numParams)
{
    return Player[GetNativeCell(1)].Bonus;
}

public int Native_GetClientValidator(Handle plugin, int numParams)
{
    return Player[GetNativeCell(1)].Validator;
}

public int Native_GetAmountOfCheckpoints(Handle plugin, int numParams)
{
    int iBonus = GetNativeCell(1);
    return Core.Checkpoints.GetInt(iBonus);
}

public int Native_GetAmountOfStages(Handle plugin, int numParams)
{
    int iBonus = GetNativeCell(1);
    return Core.Stages.GetInt(iBonus);
}

public int Native_GetAmountOfBonus(Handle plugin, int numParams)
{
    return Core.Bonus;
}

public int Native_ResetClientTimer(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    Player[client].Reset();
}
