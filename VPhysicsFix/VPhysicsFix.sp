#pragma semicolon 1
#pragma newdecls required
#include <sdktools>
#include <sdkhooks>

public Plugin myinfo =
{
	name = "VPhysics fix",
	author = "Phoenix (˙·٠●Феникс●٠·˙)",
	version = "1.0.0",
	url = "https://github.com/komashchenko/sourcemod-plugins"
};

Address g_pMDLCache;
Handle g_hCCollisionProperty_SetSolid;
Handle g_hCMDLCache_GetVCollide;
int g_iCollisionOffs;
int g_nSolidTypeOffs;
int g_iStudioHdrOffs;

public void OnPluginStart()	 
{
	GameData hGameConf = LoadGameConfigFile("VPhysicsFix");
	if (!hGameConf)
	{
		SetFailState("Couldn't load VPhysicsFix game config");
		
		return;
	}
	
	g_pMDLCache = hGameConf.GetAddress("g_pMDLCache");
	
	if(g_pMDLCache == Address_Null)
	{
		SetFailState("Couldn't get g_pMDLCache address");
		
		return;
	}
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "CCollisionProperty::SetSolid");
	g_hCCollisionProperty_SetSolid = EndPrepSDKCall();
	if(!g_hCCollisionProperty_SetSolid)
	{
		SetFailState("Failed to find CCollisionProperty::SetSolid");
		
		return;
	}
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CMDLCache::GetVCollide");
	g_hCMDLCache_GetVCollide = EndPrepSDKCall();
	if(!g_hCMDLCache_GetVCollide)
	{
		SetFailState("Failed to find CMDLCache::GetVCollide");
		
		return;
	}
	
	hGameConf.Close();
	
	g_iCollisionOffs = FindSendPropInfo("CBaseEntity", "m_Collision");
	g_nSolidTypeOffs = FindSendPropInfo("CBaseEntity", "m_nSolidType");
	// CBaseAnimating::GetModelPtr - по нормальному нужно вызывать
	// Но делаем так https://github.com/qubka/Zombie-Plague/blob/67266c6b90d88180264745ccebff709531c722d0/gamedata/plugin.turret.txt#L8
	g_iStudioHdrOffs = FindSendPropInfo("CBaseAnimating", "m_hLightingOrigin") + 68;
}

public void OnEntityCreated(int iEnt, const char[] szClassname)
{
	if (strncmp(szClassname, "prop_dynamic", 12) == 0) // prop_dynamic*
	{
		SDKHook(iEnt, SDKHook_SpawnPost, OnPropDynamicSpawned);
	}
}

void OnPropDynamicSpawned(int iEnt)
{
	if (GetEntData(iEnt, g_nSolidTypeOffs, 1) == 6)
	{
		int studiohdr = LoadFromAddress(view_as<Address>(GetEntData(iEnt, g_iStudioHdrOffs)), NumberType_Int32); // CStudioHdr::m_pStudioHdr
		// Всегда присутствует ?
		int studiohdr2index = LoadFromAddress(view_as<Address>(studiohdr + 400), NumberType_Int32); // studiohdr_t::studiohdr2index
		if(studiohdr2index)
		{
			int pStudioHdr2 = studiohdr + studiohdr2index; // studiohdr2_t
			int virtualModel = LoadFromAddress(view_as<Address>(pStudioHdr2 + 48), NumberType_Int32); // studiohdr2_t::virtualModel
			
			if(!SDKCall(g_hCMDLCache_GetVCollide, g_pMDLCache, virtualModel))
			{
				SDKCall(g_hCCollisionProperty_SetSolid, GetEntityAddress(iEnt) + view_as<Address>(g_iCollisionOffs), 0);
			}
		}
	}
}