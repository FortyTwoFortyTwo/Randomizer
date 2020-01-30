static Handle g_hSDKGetMaxHealth;
static Handle g_hSDKRemoveWearable;
static Handle g_hSDKEquipWearable;
static Handle g_hSDKGetMaxAmmo;

static Handle g_hDHookTaunt;

public void SDK_Init()
{
	GameData hGameData = new GameData("sdkhooks.games");
	if (!hGameData)
		SetFailState("Could not find sdkhooks.games gamedata");
	
	//Max health
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "GetMaxHealth");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetMaxHealth = EndPrepSDKCall();
	if(g_hSDKGetMaxHealth == null)
		LogMessage("Failed to create call: CTFPlayer::GetMaxHealth");
	
	delete hGameData;
	
	hGameData = new GameData("sm-tf2.games");
	if (hGameData == null)
		SetFailState("Could not find sm-tf2.games gamedata");
	
	int iRemoveWearableOffset = hGameData.GetOffset("RemoveWearable");
	
	//Remove Wearable
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetVirtual(iRemoveWearableOffset);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKRemoveWearable = EndPrepSDKCall();
	if (g_hSDKRemoveWearable == null)
		LogMessage("Failed to create call: CBasePlayer::RemoveWearable");
	
	//Equip Wearable
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetVirtual(iRemoveWearableOffset-1);//Equip Wearable is right behind Remove Wearable, should be good if valve dont add one between
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKEquipWearable = EndPrepSDKCall();
	if (g_hSDKEquipWearable == null)
		LogMessage("Failed to create call: CBasePlayer::EquipWearable");
	
	delete hGameData;
	
	hGameData = new GameData("randomizer");
	if (hGameData == null)
		SetFailState("Could not find randomizer gamedata");
	
	//Get Max Ammo
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::GetMaxAmmo");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetMaxAmmo = EndPrepSDKCall();
	if (g_hSDKGetMaxAmmo == null)
		LogMessage("Failed to create call: CTFPlayer::GetMaxAmmo");
	
	g_hDHookTaunt = DHookCreateFromConf(hGameData, "CTFPlayer::Taunt");
	if (!g_hDHookTaunt)
		LogMessage("Failed to create hook: CTFPlayer::Taunt");
}

void SDK_EnableDetour()
{
	if (g_hDHookTaunt)
	{
		DHookEnableDetour(g_hDHookTaunt, false, DHook_TauntPre);
		DHookEnableDetour(g_hDHookTaunt, true, DHook_TauntPost);
	}
}

stock void SDK_DisableDetour()
{
	if (g_hDHookTaunt)
	{
		DHookDisableDetour(g_hDHookTaunt, false, DHook_TauntPre);
		DHookDisableDetour(g_hDHookTaunt, true, DHook_TauntPost);
	}
}

stock int SDK_GetMaxHealth(int iClient)
{
	if (!g_hSDKGetMaxHealth)
		return SDKCall(g_hSDKGetMaxHealth, iClient);
	return 0;
}

stock void SDK_RemoveWearable(int iClient, int iWearable)
{
	if (!g_hSDKRemoveWearable)
		SDKCall(g_hSDKRemoveWearable, iClient, iWearable);
}

stock void SDK_EquipWearable(int iClient, int iWearable)
{
	if (!g_hSDKEquipWearable)
		SDKCall(g_hSDKEquipWearable, iClient, iWearable);
}

stock int SDK_GetMaxAmmo(int iClient, int iSlot, TFClassType iClass = TFClass_Unknown)
{
	if (!g_hSDKGetMaxAmmo)
		return SDKCall(g_hSDKGetMaxAmmo, iClient, iSlot, -1);
	
	return -1;
}

public MRESReturn DHook_TauntPre(int iClient, Handle hParams)
{
	//Player wants to taunt, set class to whoever can actually taunt with active weapon
	
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon <= MaxClients)
		return;
	
	int iSlot = TF2_GetSlotFromItem(iClient, iWeapon);
	if (iSlot < 0)
		return;
	
	int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
	TFClassType nClass = TF2_GetDefaultClassIndex(iIndex, iSlot);
	if (nClass != TFClass_Unknown)
		TF2_SetPlayerClass(iClient, nClass);
}

public MRESReturn DHook_TauntPost(int iClient, Handle hParams)
{
	//Set class back to what it was
	TF2_SetPlayerClass(iClient, g_iClientClass[iClient]);
}