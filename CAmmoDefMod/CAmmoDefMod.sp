#pragma semicolon 1
#pragma newdecls required
#include <sdktools>

public Plugin myinfo =
{
	name = "CAmmoDefMod",
	author = "Phoenix (˙·٠●Феникс●٠·˙)",
	description = "Allows control limit of each grenade separately",
	version = "1.0.0",
	url = "https://github.com/komashchenko/sourcemod-plugins"
};

Handle g_hGetAmmoDef;
Handle g_hCAmmoDef_Index;
Address g_pCVar;
Handle g_hICvar_FindVar;

public void OnPluginStart()
{
	GameData hGameConf = LoadGameConfigFile("CAmmoDefMod");
	if (!hGameConf)
	{
		SetFailState("Couldn't load CAmmoDefMod game config!");
		
		return;
	}
	
	g_pCVar = hGameConf.GetAddress("g_pCVar");
	if(g_pCVar == Address_Null)
	{
		SetFailState("Couldn't get g_pCVar address!");
		
		return;
	}
	
	// ICvar::FindVar
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "ICvar::FindVar");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if(!(g_hICvar_FindVar = EndPrepSDKCall()))
	{
		SetFailState("Failed to create call for ICvar::FindVar");
		
		return;
	}
	
	// GetAmmoDef
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "GetAmmoDef");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if(!(g_hGetAmmoDef = EndPrepSDKCall()))
	{
		SetFailState("Failed to create call for find GetAmmoDef");
	}
	
	// CAmmoDef::Index
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CAmmoDef::Index");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	if(!(g_hCAmmoDef_Index = EndPrepSDKCall()))
	{
		SetFailState("Failed to create call for CAmmoDef::Index");
	}
	
	hGameConf.Close();
	
	/////////////////////////////////////////////////////////////
	
	CreateConVar("ammo_grenade_limit_hegrenade", "2", "", FCVAR_RELEASE);
	CreateConVar("ammo_grenade_limit_smokegrenade", "1", "", FCVAR_RELEASE);
	CreateConVar("ammo_grenade_limit_molotov", "1", "", FCVAR_RELEASE);
	CreateConVar("ammo_grenade_limit_decoy", "1", "", FCVAR_RELEASE);
	CreateConVar("ammo_grenade_limit_tagrenade", "3", "", FCVAR_RELEASE);
	
	Address pAmmoDef = SDKCall(g_hGetAmmoDef);
	Ammo_SetCarryCvar(CAmmoDef_GetAmmoOfName(pAmmoDef, "AMMO_TYPE_HEGRENADE"), "ammo_grenade_limit_hegrenade");
	Ammo_SetCarryCvar(CAmmoDef_GetAmmoOfName(pAmmoDef, "AMMO_TYPE_SMOKEGRENADE"), "ammo_grenade_limit_smokegrenade");
	Ammo_SetCarryCvar(CAmmoDef_GetAmmoOfName(pAmmoDef, "AMMO_TYPE_MOLOTOV"), "ammo_grenade_limit_molotov");
	Ammo_SetCarryCvar(CAmmoDef_GetAmmoOfName(pAmmoDef, "AMMO_TYPE_DECOY"), "ammo_grenade_limit_decoy");
	Ammo_SetCarryCvar(CAmmoDef_GetAmmoOfName(pAmmoDef, "AMMO_TYPE_TAGRENADE"), "ammo_grenade_limit_tagrenade");
	
	g_hGetAmmoDef.Close();
	g_hCAmmoDef_Index.Close();
	g_hICvar_FindVar.Close();
}

Address CAmmoDef_GetAmmoOfName(Address pAmmoDef, const char[] szName)
{
	int iAmmoIndex = SDKCall(g_hCAmmoDef_Index, pAmmoDef, szName);
	
	if(iAmmoIndex != -1)
	{
		return pAmmoDef + view_as<Address>(56 * iAmmoIndex + 8);
	}
	
	return Address_Null;
}

bool Ammo_SetCarryCvar(Address pAmmo, const char[] szCvarName)
{
	// Ammo_t
	// https://gitlab.com/SomethingFromSomewhere/cstrike15_src/-/blob/master/game/shared/ammodef.h#L19
	// https://gitlab.com/SomethingFromSomewhere/cstrike15_src/-/blob/master/game/shared/ammodef.cpp#L279
	
	int pCavr = SDKCall(g_hICvar_FindVar, g_pCVar, szCvarName);
	if(pCavr)
	{
		// pMaxCarryCVar 
		StoreToAddress(pAmmo + view_as<Address>(48), pCavr, NumberType_Int32);
		
		// USE_CVAR -1
		// pMaxCarry
		StoreToAddress(pAmmo + view_as<Address>(32), -1, NumberType_Int32);
		
		return true;
	}
	
	return false;
}