static Handle g_hSDKGetMaxHealth;
static Handle g_hSDKRemoveWearable;
static Handle g_hSDKEquipWearable;
static Handle g_hSDKGetMaxAmmo;

static Handle g_hDHookGetMaxAmmo;
static Handle g_hDHookTaunt;
static Handle g_hDHookCanAirDash;
static Handle g_hDHookItemsMatch;

static int g_iOffsetItemDefinitionIndex = -1;

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
	
	g_hDHookGetMaxAmmo = DHookCreateFromConf(hGameData, "CTFPlayer::GetMaxAmmo");
	if (!g_hDHookGetMaxAmmo)
		LogMessage("Failed to create hook: CTFPlayer::GetMaxAmmo");
	
	g_hDHookTaunt = DHookCreateFromConf(hGameData, "CTFPlayer::Taunt");
	if (!g_hDHookTaunt)
		LogMessage("Failed to create hook: CTFPlayer::Taunt");
	
	g_hDHookCanAirDash = DHookCreateFromConf(hGameData, "CTFPlayer::CanAirDash");
	if (!g_hDHookCanAirDash)
		LogMessage("Failed to create hook: CTFPlayer::CanAirDash");
	
	g_hDHookItemsMatch = DHookCreateFromConf(hGameData, "CTFPlayer::ItemsMatch");
	if (!g_hDHookItemsMatch)
		LogMessage("Failed to create hook: CTFPlayer::ItemsMatch");
	
	g_iOffsetItemDefinitionIndex = hGameData.GetOffset("CEconItemView::m_iItemDefinitionIndex");
	
	delete hGameData;
}

void SDK_EnableDetour()
{
	if (g_hDHookGetMaxAmmo)
	{
		DHookEnableDetour(g_hDHookGetMaxAmmo, false, DHook_GetMaxAmmoPre);
	}
	
	if (g_hDHookTaunt)
	{
		DHookEnableDetour(g_hDHookTaunt, false, DHook_TauntPre);
		DHookEnableDetour(g_hDHookTaunt, true, DHook_TauntPost);
	}
	
	if (g_hDHookCanAirDash)
	{
		DHookEnableDetour(g_hDHookCanAirDash, true, DHook_CanAirDashPost);
	}
	
	if (g_hDHookItemsMatch)
	{
		DHookEnableDetour(g_hDHookItemsMatch, false, DHook_ItemsMatchPre);
	}
}

stock void SDK_DisableDetour()
{
	if (g_hDHookGetMaxAmmo)
	{
		DHookDisableDetour(g_hDHookGetMaxAmmo, false, DHook_GetMaxAmmoPre);
	}
	
	if (g_hDHookTaunt)
	{
		DHookDisableDetour(g_hDHookTaunt, false, DHook_TauntPre);
		DHookDisableDetour(g_hDHookTaunt, true, DHook_TauntPost);
	}
	
	if (g_hDHookCanAirDash)
	{
		DHookDisableDetour(g_hDHookCanAirDash, true, DHook_CanAirDashPost);
	}
	
	if (g_hDHookItemsMatch)
	{
		DHookDisableDetour(g_hDHookItemsMatch, false, DHook_ItemsMatchPre);
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

stock int SDK_GetMaxAmmo(int iClient, int iAmmoType)
{
	if (!g_hSDKGetMaxAmmo)
		return SDKCall(g_hSDKGetMaxAmmo, iClient, iAmmoType, -1);
	
	return -1;
}

public MRESReturn DHook_GetMaxAmmoPre(int iClient, Handle hReturn, Handle hParams)
{
	int iAmmoType = DHookGetParam(hParams, 1);
	TFClassType nClass = DHookGetParam(hParams, 2);
	
	if (nClass != view_as<TFClassType>(-1))
		return MRES_Ignored;
	
	if (iAmmoType == TF_AMMO_METAL)
	{
		//Metal works differently, engineer have max metal 200 while others have 100
		DHookSetParam(hParams, 2, TFClass_Engineer);
		return MRES_ChangedHandled;
	}
	
	//By default iClassNumber returns -1, which would get client's class instead of given iClassNumber.
	//However using client's class can cause max ammo calculate to be incorrect,
	//We want to set iClassNumber to whatever class would normaly use weapon from iAmmoIndex.
	//TODO check shortstop's max ammo
	int iWeapon = TF2_GetItemFromAmmoType(iClient, iAmmoType);
	if (iWeapon <= MaxClients)
		return MRES_Ignored;
	
	TFClassType nDefaultClass = TF2_GetDefaultClassFromItem(iClient, iWeapon);
	DHookSetParam(hParams, 2, nDefaultClass);
	return MRES_ChangedHandled;
}

public MRESReturn DHook_TauntPre(int iClient, Handle hParams)
{
	//Player wants to taunt, set class to whoever can actually taunt with active weapon
	
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon <= MaxClients)
		return;
	
	TFClassType nClass = TF2_GetDefaultClassFromItem(iClient, iWeapon);
	if (nClass != TFClass_Unknown)
		TF2_SetPlayerClass(iClient, nClass);
}

public MRESReturn DHook_TauntPost(int iClient, Handle hParams)
{
	//Set class back to what it was
	TF2_SetPlayerClass(iClient, g_iClientClass[iClient]);
}

public MRESReturn DHook_CanAirDashPost(int iClient, Handle hReturn)
{
	//Atomizer's extra jumps does not work for non-scouts, fix that
	if (!DHookGetReturn(hReturn))
	{
		int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
		
		float flVal;
		if (!TF2_WeaponFindAttribute(iWeapon, ATTRIB_AIR_DASH_COUNT, flVal))
			return MRES_Ignored;
		
		int iAirDash = GetEntProp(iClient, Prop_Send, "m_iAirDash");
		if (iAirDash < RoundToNearest(flVal))
		{
			SetEntProp(iClient, Prop_Send, "m_iAirDash", iAirDash + 1);
			DHookSetReturn(hReturn, true);
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
public MRESReturn DHook_ItemsMatchPre(int iClient, Handle hReturn, Handle hParams)
{
	if (g_iOffsetItemDefinitionIndex == -1)
		return MRES_Ignored;
	
	if (DHookIsNullParam(hParams, 2))
		return MRES_Ignored;
	
	//We want to prevent TF2 deleting weapons generated from randomizer and use player's TF2 loadout
	int iIndex1 = DHookGetParamObjectPtrVar(hParams, 2, g_iOffsetItemDefinitionIndex, ObjectValueType_Int) & 0xFFFF;
	
	//Try find slot, may be a problem for multi-class weapon
	int iSlot = -1;
	if (!DHookIsNullParam(hParams, 4))
	{
		int iWeapon = DHookGetParam(hParams, 4);
		iSlot = TF2_GetSlotFromItem(iClient, iWeapon);
	}
	
	if (iSlot < 0)
	{
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			int iClassSlot = TF2_GetSlotFromIndex(iIndex1, view_as<TFClassType>(iClass));
			if (iClassSlot >= 0)
			{
				iSlot = iClassSlot;
				break;
			}
		}
	}
	
	if (iSlot < 0 || iSlot > WeaponSlot_BuilderEngie)
		return MRES_Ignored;
	
	//Get index we want to use from randomizer
	int iIndex2 = g_iClientWeaponIndex[iClient][iSlot];
	if (iIndex2 < 0)
	{
		DHookSetReturn(hReturn, false);
		return MRES_Supercede;
	}
	
	//Set return whenever if index to give is same as what we wanted in randomizer
	DHookSetReturn(hReturn, iIndex1 == iIndex2);
	return MRES_Supercede;
}

}