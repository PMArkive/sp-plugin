#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <fuckZones>
#include <fuckTimer_stocks>
#include <fuckTimer_core>
#include <fuckTimer_timer>
#include <fuckTimer_zones>

enum struct PlayerData
{
	char Zone[MAX_ZONE_NAME_LENGTH];

	int Stage;
	int Checkpoint;

	void Reset()
	{
		this.Zone[0] = '\0';

		this.Stage = 0;
		this.Checkpoint = 0;
	}
}

PlayerData Player[MAXPLAYERS + 1];

int g_iMaxStage = 0;
int g_iMaxCheckpoint = 0;

public Plugin myinfo =
{
	name = FUCKTIMER_PLUGIN_NAME ... "HUD",
	author = FUCKTIMER_PLUGIN_AUTHOR,
	description = FUCKTIMER_PLUGIN_DESCRIPTION,
	version = FUCKTIMER_PLUGIN_VERSION,
	url = FUCKTIMER_PLUGIN_URL
};

public void OnMapStart()
{
	g_iMaxStage = 0;
}

public void OnClientPutInServer(int client)
{
	Player[client].Reset();
}

public void fuckZones_OnZoneCreate(int entity, const char[] zone_name, int type)
{
	StringMap smEffects = fuckZones_GetZoneEffects(entity);

	StringMap smValues;
	smEffects.GetValue(FUCKTIMER_EFFECT_NAME, smValues);

	StringMapSnapshot snap = smValues.Snapshot();

	char sKey[MAX_KEY_NAME_LENGTH];
	char sValue[MAX_KEY_VALUE_LENGTH];
	int iStage = 0;
	int iCheckpoint = 0;

	if (snap != null)
	{
		for (int i = 0; i < snap.Length; i++)
		{
			snap.GetKey(i, sKey, sizeof(sKey));

			if (StrEqual(sKey, "Stage", false))
			{
				smValues.GetString(sKey, sValue, sizeof(sValue));

				iStage = StringToInt(sValue);

				if (iStage > 0 && iStage > g_iMaxStage)
				{
					g_iMaxStage = iStage;
				}

				iStage = 0;
			}

			if (StrEqual(sKey, "Checkpoint", false))
			{
				smValues.GetString(sKey, sValue, sizeof(sValue));

				iCheckpoint = StringToInt(sValue);

				if (iCheckpoint > 0 && iCheckpoint > g_iMaxCheckpoint)
				{
					g_iMaxCheckpoint = iCheckpoint;
				}

				iCheckpoint = 0;
			}
		}
	}

	delete snap;
}

public void OnGameFrame()
{
	float fTime = 0.0;

	fuckTimer_LoopClients(client, false, false)
	{
		fTime = fuckTimer_GetClientTime(client, TimeMain);

		if (fTime > 0.0)
		{
			fTime = GetGameTime() - fTime;
		}

		char sZone[MAX_ZONE_NAME_LENGTH + 6], sCPStage[12];

		if (strlen(Player[client].Zone) > 1)
		{
			FormatEx(sZone, sizeof(sZone), " | Zone: %s", Player[client].Zone);
		}

		if (g_iMaxStage > 0)
		{
			FormatEx(sCPStage, sizeof(sCPStage), "Stage: %d/%d", Player[client].Stage, g_iMaxStage);
		}
		else if (g_iMaxCheckpoint > 0)
		{
			FormatEx(sCPStage, sizeof(sCPStage), "CP: %d/%d", Player[client].Checkpoint, g_iMaxCheckpoint);
		}
		else
		{
			FormatEx(sCPStage, sizeof(sCPStage), "Linear");
		}
		
		PrintCSGOHUDText(client, "Speed: %.0f | Time: %.3f\n %s%s", GetSpeed(client), fTime, sCPStage, sZone);
	}
}

public void fuckTimer_OnEnteringZone(int client, int zone, const char[] name, bool start, bool end, int stage, int checkpoint)
{
	Player[client].Reset();

	if (start)
	{
		FormatEx(Player[client].Zone, sizeof(PlayerData::Zone), "Start");
		
		if (g_iMaxStage > 0)
		{
			Player[client].Stage = 1;
		}

		if (g_iMaxCheckpoint > 0)
		{
			Player[client].Checkpoint = 1;
		}
	}
	else if (end)
	{
		FormatEx(Player[client].Zone, sizeof(PlayerData::Zone), "End");
	}
	
	if (stage > 0)
	{
		Player[client].Stage = stage;
		FormatEx(Player[client].Zone, sizeof(PlayerData::Zone), "Stage %d", stage);
	}
	
	if (checkpoint > 0)
	{
		Player[client].Checkpoint = checkpoint;
	}
	// TODO: Add Bonus
}

public void fuckTimer_OnLeavingZone(int client, int zone, const char[] name, bool start, bool end, int stage, int checkpoint)
{
	Player[client].Reset();

	if ((start && g_iMaxStage > 0))
	{
		Player[client].Stage = 1;
	}
	else if (stage > 0)
	{
		Player[client].Stage = stage;
	}

	if ((start && g_iMaxCheckpoint > 0))
	{
		Player[client].Checkpoint = 1;
	}
	else if (checkpoint > 0)
	{
		Player[client].Checkpoint = checkpoint;
	}
}

void PrintCSGOHUDText(int client, const char[] format, any ...)
{
	char sMessage[225];
	VFormat(sMessage, sizeof(sMessage), format, 3);
	Format(sMessage, sizeof(sMessage), "</font>%s ", sMessage);
	
	for(int i = strlen(sMessage); i < sizeof(sMessage); i++)
	{
		sMessage[i] = '\n';
	}
	
	Protobuf pbBuf = view_as<Protobuf>(StartMessageOne("TextMsg", client, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS));
	pbBuf.SetInt("msg_dst", 4);
	pbBuf.AddString("params", "#SFUI_ContractKillStart");
	pbBuf.AddString("params", sMessage);
	pbBuf.AddString("params", NULL_STRING);
	pbBuf.AddString("params", NULL_STRING);
	pbBuf.AddString("params", NULL_STRING);
	pbBuf.AddString("params", NULL_STRING);
	
	EndMessage();
}

float GetSpeed(int client)
{
	float fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
	float speed = SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0));

	return speed;
}
