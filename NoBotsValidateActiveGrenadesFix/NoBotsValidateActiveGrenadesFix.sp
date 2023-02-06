#pragma semicolon 1
#pragma newdecls required
#include <sdktools>

public Plugin myinfo =
{
	name = "NoBotsValidateActiveGrenadesFix",
	author = "Phoenix (˙·٠●Феникс●٠·˙)",
	description = "Fixes visibility on radar in smoke when using -nobots",
	version = "1.0.0",
	url = "https://github.com/komashchenko/sourcemod-plugins"
};

Address g_pTheBots;
Handle g_hValidateActiveGrenades;

public void OnPluginStart()
{
	GameData hGameConf = LoadGameConfigFile("NoBotsValidateActiveGrenadesFix");
	if (hGameConf == null)
	{
		SetFailState("Couldn't load NoBotsValidateActiveGrenadesFix game config");
		
		return;
	}
	
	g_pTheBots = hGameConf.GetAddress("TheBots");
	if(g_pTheBots == Address_Null)
	{
		SetFailState("Failed to get TheBots address");
		
		return;
	}
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CBotManager::ValidateActiveGrenades");
	g_hValidateActiveGrenades = EndPrepSDKCall();
	if(g_hValidateActiveGrenades == null)
	{
		SetFailState("Failed to create call for CBotManager::ValidateActiveGrenades");
		
		return;
	}
	
	hGameConf.Close();
}

public void OnGameFrame()
{
	SDKCall(g_hValidateActiveGrenades, g_pTheBots);
}