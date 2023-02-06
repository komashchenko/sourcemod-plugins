#pragma semicolon 1
#pragma newdecls required
#include <sdktools>

public Plugin myinfo =
{
	name = "NoDisarmMod",
	author = "Phoenix (˙·٠●Феникс●٠·˙)",
	description = "Strong punching (right click) won't knock the weapon out of the enemy's hands",
	version = "1.0.0",
	url = "https://github.com/komashchenko/sourcemod-plugins"
};

Address g_NoDisarmMod_Start, g_NoDisarmMod_End;
int g_NoDisarmModSave_Start;

public void OnPluginStart()
{
	GameData hGameData = LoadGameConfigFile("NoDisarmMod");
	if(!hGameData)
	{
		SetFailState("Failed to load NoDisarmMod gamedata.");
		
		return;
	}
	
	Address NoDisarmMod = hGameData.GetAddress("NoDisarmMod");
	if(NoDisarmMod == Address_Null)
	{
		SetFailState("Failed to get NoDisarmMod address.");
		
		return;
	}
	
	g_NoDisarmMod_Start = NoDisarmMod + view_as<Address>(hGameData.GetOffset("NoDisarmMod_Start"));
	g_NoDisarmMod_End = NoDisarmMod + view_as<Address>(hGameData.GetOffset("NoDisarmMod_End"));
	
	hGameData.Close();
	
	if(LoadFromAddress(g_NoDisarmMod_Start, NumberType_Int8) != 0x80 || LoadFromAddress(g_NoDisarmMod_End, NumberType_Int8) != 0x8B)
	{
		SetFailState("Found not what they expected.");
		
		return;
	}
	
	g_NoDisarmModSave_Start = LoadFromAddress(g_NoDisarmMod_Start + view_as<Address>(1), NumberType_Int32);
	
	int jmp = view_as<int>(g_NoDisarmMod_End - g_NoDisarmMod_Start) - 5;
	
	StoreToAddress(g_NoDisarmMod_Start, 0xE9, NumberType_Int8);
	StoreToAddress(g_NoDisarmMod_Start + view_as<Address>(1), jmp, NumberType_Int32);
}

public void OnPluginEnd()
{
	StoreToAddress(g_NoDisarmMod_Start, 0x80, NumberType_Int8);
	StoreToAddress(g_NoDisarmMod_Start + view_as<Address>(1), g_NoDisarmModSave_Start, NumberType_Int32);
}