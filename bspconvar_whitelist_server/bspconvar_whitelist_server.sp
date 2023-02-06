#pragma semicolon 1
#pragma newdecls required
#include <sdktools>

public Plugin myinfo =
{
	name = "bspconvar_whitelist server",
	author = "Phoenix (˙·٠●Феникс●٠·˙)",
	description = "Using bspconvar_whitelist_server.txt instead of the default",
	version = "1.0.0",
	url = "https://github.com/komashchenko/sourcemod-plugins"
};

public void OnPluginStart()
{
	GameData hGameConf = LoadGameConfigFile("bspconvar_whitelist_server");
	if (!hGameConf)
	{
		SetFailState("Couldn't load bspconvar_whitelist_server game config!");
		
		return;
	}
	
	Address pMemAlloc = hGameConf.GetAddress("g_pMemAlloc");
	if(pMemAlloc == Address_Null)
	{
		SetFailState("Couldn't get g_pMemAlloc address!");
		
		return;
	}
	
	Address pIsWhiteListedCmd = hGameConf.GetMemSig("IsWhiteListedCmd");
	if(pIsWhiteListedCmd == Address_Null)
	{
		SetFailState("Couldn't get IsWhiteListedCmd address!");
		
		return;
	}
	
	Address pCMultiplayRules = hGameConf.GetMemSig("CMultiplayRules::CMultiplayRules");
	if(pCMultiplayRules == Address_Null)
	{
		SetFailState("Couldn't get CMultiplayRules::CMultiplayRules address!");
		
		return;
	}
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetVirtual(hGameConf.GetOffset("Malloc"));
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	Handle hMalloc = EndPrepSDKCall();
	
	char szFileName[] = "bspconvar_whitelist_server.txt";
	char szWarning[] = "%s - missing cvar specified in bspconvar_whitelist_server.txt\n";
	
	int pszFileName = SDKCall(hMalloc, pMemAlloc, sizeof szFileName);
	int pszWarning = SDKCall(hMalloc, pMemAlloc, sizeof szWarning);
	
	hMalloc.Close();

	memcpy(pszFileName, szFileName, sizeof szFileName);
	memcpy(pszWarning, szWarning, sizeof szWarning);
	
	StoreToAddress(pIsWhiteListedCmd + view_as<Address>(hGameConf.GetOffset("IsWhiteListedCmd_Patch0")), pszFileName, NumberType_Int32);
	StoreToAddress(pIsWhiteListedCmd + view_as<Address>(hGameConf.GetOffset("IsWhiteListedCmd_Patch1")), pszFileName, NumberType_Int32);
	StoreToAddress(pCMultiplayRules + view_as<Address>(hGameConf.GetOffset("CMultiplayRules::CMultiplayRules_Patch0")), pszFileName, NumberType_Int32);
	StoreToAddress(pCMultiplayRules + view_as<Address>(hGameConf.GetOffset("CMultiplayRules::CMultiplayRules_Patch1")), pszWarning, NumberType_Int32);
	
	hGameConf.Close();
}

void memcpy(any pAddr, const char[] data, int iSize)
{
	for(int i = 0; i < iSize; i++)
	{
		StoreToAddress(view_as<Address>(pAddr + i), data[i], NumberType_Int8);
	}
}