#pragma semicolon 1
#pragma newdecls required
#include <sdktools>
#include <dhooks>

public Plugin myinfo =
{
	name = "Drops summoner",
	author = "Phoenix (˙·٠●Феникс●٠·˙)",
	version = "1.0.5",
	url = "https://github.com/komashchenko/sourcemod-plugins"
};

bool g_bWindows;
Handle g_hRewardMatchEndDrops = null;
Handle g_hTimerWaitDrops = null;
Address g_pDropForAllPlayersPatch = Address_Null;
char g_szLogFile[256];
ConVar g_hDSWaitTimer = null;
ConVar g_hDSInfo = null;
ConVar g_hDSPlaySound = null;
int m_pPersonaDataPublic = -1;
ConVar g_hDSIgnoreNonPrime = null;
ConVar sv_matchend_drops_enabled = null;

public void OnPluginStart()
{
	GameData hGameData = LoadGameConfigFile("DropsSummoner.games");
	if (!hGameData)
	{
		SetFailState("Failed to load DropsSummoner gamedata.");
		
		return;
	}
	
	// Is windows
	char szBuf[14];
	GetCommandLine(szBuf, sizeof szBuf);
	g_bWindows = strcmp(szBuf, "./srcds_linux") != 0;
	
	StartPrepSDKCall(g_bWindows ? SDKCall_Static : SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CCSGameRules::RewardMatchEndDrops");
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	if (!(g_hRewardMatchEndDrops = EndPrepSDKCall()))
	{
		SetFailState("Failed to create call for CCSGameRules::RewardMatchEndDrops");
		
		return;
	}
	
	DynamicDetour hCCSGameRules_RecordPlayerItemDrop = DynamicDetour.FromConf(hGameData, "CCSGameRules::RecordPlayerItemDrop");
	if (!hCCSGameRules_RecordPlayerItemDrop)
	{
		SetFailState("Failed to setup detour for CCSGameRules::RecordPlayerItemDrop");
		
		return;
	}
	
	if(!hCCSGameRules_RecordPlayerItemDrop.Enable(Hook_Post, Detour_RecordPlayerItemDrop))
	{
		SetFailState("Failed to detour CCSGameRules::RecordPlayerItemDrop.");
		
		return;
	}
	
	g_pDropForAllPlayersPatch = hGameData.GetAddress("DropForAllPlayersPatch");
	if(g_pDropForAllPlayersPatch != Address_Null)
	{
		// ja always false
		// 83 F8 01 ?? [cmp eax, 1]
		if((LoadFromAddress(g_pDropForAllPlayersPatch, NumberType_Int32) & 0xFFFFFF) == 0x1F883)
		{
			// 39 C0 [cmp eax, eax]
			StoreToAddress(g_pDropForAllPlayersPatch, 0xC039, NumberType_Int16);
			// 90 [nop]
			StoreToAddress(g_pDropForAllPlayersPatch + view_as<Address>(2), 0x90, NumberType_Int8);
		}
		else
		{
			g_pDropForAllPlayersPatch = Address_Null;
			
			LogError("At address g_pDropForAllPlayersPatch received not what we expected, drop for all players will be unavailable.");
		}
	}
	else
	{
		LogError("Failed to get address DropForAllPlayersPatch, drop for all players will be unavailable.");
	}
	
	hGameData.Close();
	
	m_pPersonaDataPublic = FindSendPropInfo("CCSPlayer", "m_unMusicID") + 0xA;
	
	sv_matchend_drops_enabled = FindConVar("sv_matchend_drops_enabled");
	ToggleMatchendDrops(false);
	
	BuildPath(Path_SM, g_szLogFile, sizeof g_szLogFile, "logs/DropsSummoner.log");
	
	g_hDSWaitTimer = CreateConVar("sm_drops_summoner_wait_timer", "605", "The duration between attempts to summon a drop in seconds", _, true, 603.0);
	g_hDSInfo = CreateConVar("sm_drops_summoner_info", "1", "Notify in chat about attempts to summon a drop", _, true, 0.0, true, 1.0);
	g_hDSPlaySound = CreateConVar("sm_drops_summoner_play_sound", "2", "Play sound when receiving a drop [0 - no | 1 - only for the recipient | 2 - everyone]", _, true, 0.0, true, 2.0);
	g_hDSIgnoreNonPrime = CreateConVar("sm_drops_summoner_ignore_non_prime", "1", "Ignore drops for non-prime players (doesn't affect logging)", _, true, 0.0, true, 1.0);
	
	g_hDSWaitTimer.AddChangeHook(OnDSWaitTimerChanged);
	OnDSWaitTimerChanged(g_hDSWaitTimer, NULL_STRING, NULL_STRING);
	
	AutoExecConfig(true, "DropsSummoner");
	
	LoadTranslations("DropsSummoner.phrases");
}

public void OnPluginEnd()
{
	if(g_pDropForAllPlayersPatch != Address_Null)
	{
		StoreToAddress(g_pDropForAllPlayersPatch, 0xF883, NumberType_Int16);
		StoreToAddress(g_pDropForAllPlayersPatch + view_as<Address>(2), 0x01, NumberType_Int8);
	}
	
	sv_matchend_drops_enabled.SetBounds(ConVarBound_Lower, true, 0.0);
	sv_matchend_drops_enabled.SetBounds(ConVarBound_Upper, true, 1.0);
	sv_matchend_drops_enabled.RestoreDefault();
}

public void OnMapStart()
{
	PrecacheSound("ui/panorama/case_awarded_1_uncommon_01.wav");
}

void OnDSWaitTimerChanged(ConVar hConVar, const char[] szOldValue, const char[] szNewValue)
{
	static Handle hTimer = null;
	
	hTimer.Close();
	
	hTimer = CreateTimer(g_hDSWaitTimer.FloatValue, Timer_SendRewardMatchEndDrops, _, TIMER_REPEAT);
}

MRESReturn Detour_RecordPlayerItemDrop(DHookParam hParams)
{
	int iAccountID = hParams.GetObjectVar(1, 16, ObjectValueType_Int);
	int iClient = GetClientFromAccountID(iAccountID);
	
	if(iClient != -1)
	{
		bool bPrime = IsPrimeClient(iClient);
		int iDefIndex = hParams.GetObjectVar(1, 20, ObjectValueType_Int);
		int iPaintIndex = hParams.GetObjectVar(1, 24, ObjectValueType_Int);
		int iRarity = hParams.GetObjectVar(1, 28, ObjectValueType_Int);
		int iQuality = hParams.GetObjectVar(1, 32, ObjectValueType_Int);
		
		static const char szPrime[] = "non-prime";
		LogToFile(g_szLogFile, "The player %L<%s> got [%u-%u-%u-%u]", iClient, szPrime[bPrime ? 4 : 0], iDefIndex, iPaintIndex, iRarity, iQuality);
		
		if(!g_hDSIgnoreNonPrime.BoolValue || bPrime)
		{
			delete g_hTimerWaitDrops;
			
			Protobuf hSendPlayerItemFound = view_as<Protobuf>(StartMessageAll("SendPlayerItemFound", USERMSG_RELIABLE));
			hSendPlayerItemFound.SetInt("entindex", iClient);
			
			Protobuf hIteminfo = hSendPlayerItemFound.ReadMessage("iteminfo");
			hIteminfo.SetInt("defindex", iDefIndex);
			hIteminfo.SetInt("paintindex", iPaintIndex);
			hIteminfo.SetInt("rarity", iRarity);
			hIteminfo.SetInt("quality", iQuality);
			hIteminfo.SetInt("inventory", 6); // UNACK_ITEM_GIFTED
			
			EndMessage();
			
			SetHudTextParams(-1.0, 0.4, 3.0, 0, 255, 255, 255);
			ShowHudText(iClient, -1, "%t", "HudNotify");
			
			int iPlaySound = g_hDSPlaySound.IntValue;
			
			if(iPlaySound == 2)
			{
				EmitSoundToAll("ui/panorama/case_awarded_1_uncommon_01.wav", SOUND_FROM_LOCAL_PLAYER, _, SNDLEVEL_NONE);
			}
			else if(iPlaySound == 1)
			{
				EmitSoundToClient(iClient, "ui/panorama/case_awarded_1_uncommon_01.wav", SOUND_FROM_LOCAL_PLAYER, _, SNDLEVEL_NONE);
			}
		}
	}
	
	return MRES_Ignored;
}

int GetClientFromAccountID(int iAccountID)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && !IsFakeClient(i))
		{
			if(GetSteamAccountID(i, false) == iAccountID)
			{
				return i;
			}
		}
	}
	
	return -1;
}

// Thanks Wend4r
bool IsPrimeClient(int iClient)
{
	Address pPersonaDataPublic = view_as<Address>(GetEntData(iClient, m_pPersonaDataPublic));
	if(pPersonaDataPublic != Address_Null)
	{
		return view_as<bool>(LoadFromAddress(pPersonaDataPublic + view_as<Address>(20), NumberType_Int8));
	}
	
	return false;
}

Action Timer_SendRewardMatchEndDrops(Handle hTimer)
{
	if(g_hDSInfo.BoolValue)
	{
		g_hTimerWaitDrops = CreateTimer(1.2, Timer_WaitDrops);
		
		PrintToChatAll(" %t", "SummonDrop");
	}
	
	ToggleMatchendDrops(true);
	
	if(g_bWindows)
	{
		SDKCall(g_hRewardMatchEndDrops, false);
	}
	else
	{
		SDKCall(g_hRewardMatchEndDrops, 0xDEADC0DE, false);
	}
	
	ToggleMatchendDrops(false);
	
	return Plugin_Continue;
}

Action Timer_WaitDrops(Handle hTimer)
{
	g_hTimerWaitDrops = null;
	
	PrintToChatAll(" %t", "AttemptFailed");
	
	return Plugin_Continue;
}

void ToggleMatchendDrops(bool bEnable)
{
	// Prevent others from changing the value
	float fValue = bEnable ? 1.0:0.0;
	sv_matchend_drops_enabled.SetBounds(ConVarBound_Lower, true, fValue);
	sv_matchend_drops_enabled.SetBounds(ConVarBound_Upper, true, fValue);
	
	sv_matchend_drops_enabled.BoolValue = bEnable;
}