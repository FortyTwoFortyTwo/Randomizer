const SDKType SDKType_Unknown = view_as<SDKType>(-1);

static Handle g_hSDKGetMaxAmmo;
static Handle g_hSDKAddObject;
static Handle g_hSDKRemoveObject;
static Handle g_hSDKDoClassSpecialSkill;
static Handle g_hSDKEndClassSpecialSkill;
static Handle g_hSDKGetLoadoutItem;
static Handle g_hSDKRollNewSpell;
static Handle g_hSDKUpdateRageBuffsAndRage;
static Handle g_hSDKModifyRage;
static Handle g_hSDKSetCarryingRuneType;
static Handle g_hSDKHandleRageGain;
static Handle g_hSDKSetItem;
static Handle g_hSDKGetBaseEntity;
static Handle g_hSDKGetMaxHealth;
static Handle g_hSDKGetSwordHealthMod;
static Handle g_hSDKWeaponCanSwitchTo;
static Handle g_hSDKEquipWearable;
static Handle g_hSDKGiveNamedItem;

public void SDKCall_Init(GameData hGameData)
{
	g_hSDKGetMaxAmmo = SDKCall_Create(hGameData, SDKCall_Player, SDKConf_Signature, "CTFPlayer::GetMaxAmmo", SDKType_PlainOldData, SDKType_PlainOldData, SDKType_PlainOldData);
	g_hSDKAddObject = SDKCall_Create(hGameData, SDKCall_Player, SDKConf_Signature, "CTFPlayer::AddObject", _, SDKType_CBaseEntity);
	g_hSDKRemoveObject = SDKCall_Create(hGameData, SDKCall_Player, SDKConf_Signature, "CTFPlayer::RemoveObject", _, SDKType_CBaseEntity);
	g_hSDKDoClassSpecialSkill = SDKCall_Create(hGameData, SDKCall_Player, SDKConf_Signature, "CTFPlayer::DoClassSpecialSkill", SDKType_Bool);
	g_hSDKEndClassSpecialSkill = SDKCall_Create(hGameData, SDKCall_Player, SDKConf_Signature, "CTFPlayer::EndClassSpecialSkill", SDKType_Bool);
	g_hSDKGetLoadoutItem = SDKCall_Create(hGameData, SDKCall_Player, SDKConf_Signature, "CTFPlayer::GetLoadoutItem", SDKType_PlainOldData, SDKType_PlainOldData, SDKType_PlainOldData, SDKType_PlainOldData);
	g_hSDKRollNewSpell = SDKCall_Create(hGameData, SDKCall_Entity, SDKConf_Signature, "CTFSpellBook::RollNewSpell", _, SDKType_PlainOldData, SDKType_Bool);
	g_hSDKUpdateRageBuffsAndRage = SDKCall_Create(hGameData, SDKCall_Raw, SDKConf_Signature, "CTFPlayerShared::UpdateRageBuffsAndRage");
	g_hSDKModifyRage = SDKCall_Create(hGameData, SDKCall_Raw, SDKConf_Signature, "CTFPlayerShared::ModifyRage", _, SDKType_Float);
	g_hSDKSetCarryingRuneType = SDKCall_Create(hGameData, SDKCall_Raw, SDKConf_Signature, "CTFPlayerShared::SetCarryingRuneType", _, SDKType_PlainOldData);
	g_hSDKHandleRageGain = SDKCall_Create(hGameData, SDKCall_Static, SDKConf_Signature, "HandleRageGain", _, SDKType_CBaseEntity, SDKType_PlainOldData, SDKType_Float, SDKType_Float);
	g_hSDKSetItem = SDKCall_Create(hGameData, SDKCall_Raw, SDKConf_Signature, "CEconItemView::operator=", SDKType_PlainOldData, SDKType_PlainOldData);
	g_hSDKGetBaseEntity = SDKCall_Create(hGameData, SDKCall_Raw, SDKConf_Virtual, "CBaseEntity::GetBaseEntity", SDKType_CBaseEntity);
	g_hSDKGetMaxHealth = SDKCall_Create(hGameData, SDKCall_Player, SDKConf_Virtual, "CBaseEntity::GetMaxHealth", SDKType_PlainOldData);
	g_hSDKGetSwordHealthMod = SDKCall_Create(hGameData, SDKCall_Entity, SDKConf_Virtual, "CTFSword::GetSwordHealthMod", SDKType_PlainOldData);
	g_hSDKWeaponCanSwitchTo = SDKCall_Create(hGameData, SDKCall_Player, SDKConf_Virtual, "CBaseCombatCharacter::Weapon_CanSwitchTo", SDKType_Bool, SDKType_CBaseEntity);
	g_hSDKEquipWearable = SDKCall_Create(hGameData, SDKCall_Player, SDKConf_Virtual, "CBasePlayer::EquipWearable", _, SDKType_CBaseEntity);
	g_hSDKGiveNamedItem = SDKCall_Create(hGameData, SDKCall_Player, SDKConf_Virtual, "CTFPlayer::GiveNamedItem", SDKType_CBaseEntity, SDKType_String, SDKType_PlainOldData, SDKType_PlainOldData, SDKType_PlainOldData);
}

static Handle SDKCall_Create(GameData hGameData, SDKCallType nType, SDKFuncConfSource nSource, const char[] sName, SDKType nReturn = SDKType_Unknown, SDKType nParam1 = SDKType_Unknown, SDKType nParam2 = SDKType_Unknown, SDKType nParam3 = SDKType_Unknown, SDKType nParam4 = SDKType_Unknown)
{
	StartPrepSDKCall(nType);
	PrepSDKCall_SetFromConf(hGameData, nSource, sName);
	
	SDKCall_AddParameter(nParam1);
	SDKCall_AddParameter(nParam2);
	SDKCall_AddParameter(nParam3);
	SDKCall_AddParameter(nParam4);
	
	if (nReturn != SDKType_Unknown)
	{
		if (nReturn == SDKType_String || nReturn == SDKType_CBaseEntity)
			PrepSDKCall_SetReturnInfo(nReturn, SDKPass_Pointer);
		else
			PrepSDKCall_SetReturnInfo(nReturn, SDKPass_ByValue);
	}
	
	Handle hSDKCall = EndPrepSDKCall();
	if (!hSDKCall)
		LogError("Failed to create call: %s", sName);
	
	return hSDKCall;
}

static void SDKCall_AddParameter(SDKType nParam)
{
	if (nParam == SDKType_Unknown)
		return;
	
	if (nParam == SDKType_String || nParam == SDKType_CBaseEntity)
		PrepSDKCall_AddParameter(nParam, SDKPass_Pointer);
	else
		PrepSDKCall_AddParameter(nParam, SDKPass_ByValue);
}

int SDKCall_GetMaxAmmo(int iClient, int iAmmoType, TFClassType nClass = view_as<TFClassType>(-1))
{
	return SDKCall(g_hSDKGetMaxAmmo, iClient, iAmmoType, nClass);
}

void SDKCall_AddObject(int iClient, int iObject)
{
	SDKCall(g_hSDKAddObject, iClient, iObject);
}

void SDKCall_RemoveObject(int iClient, int iObject)
{
	SDKCall(g_hSDKRemoveObject, iClient, iObject);
}

bool SDKCall_DoClassSpecialSkill(int iClient)
{
	return SDKCall(g_hSDKDoClassSpecialSkill, iClient);
}

bool SDKCall_EndClassSpecialSkill(int iClient)
{
	return SDKCall(g_hSDKEndClassSpecialSkill, iClient);
}

Address SDKCall_GetLoadoutItem(int iClient, TFClassType nClass, int iSlot, bool bReportWhitelistFails = false)
{
	return SDKCall(g_hSDKGetLoadoutItem, iClient, nClass, iSlot, bReportWhitelistFails);
}

void SDKCall_RollNewSpell(int iSpellbook, int iTier, bool bForceReroll)
{
	SDKCall(g_hSDKRollNewSpell, iSpellbook, iTier, bForceReroll);
}

void SDKCall_UpdateRageBuffsAndRage(Address pPlayerShared)
{
	SDKCall(g_hSDKUpdateRageBuffsAndRage, pPlayerShared);
}

void SDKCall_ModifyRage(Address pPlayerShared, float flAdd)
{
	SDKCall(g_hSDKModifyRage, pPlayerShared, flAdd);
}

void SDKCall_SetCarryingRuneType(Address pPlayerShared, int iRuneType)
{
	SDKCall(g_hSDKSetCarryingRuneType, pPlayerShared, iRuneType);
}

void SDKCall_HandleRageGain(int iClient, int iRequiredBuffFlags, float flDamage, float fInverseRageGainScale)
{
	SDKCall(g_hSDKHandleRageGain, iClient, iRequiredBuffFlags, flDamage, fInverseRageGainScale);
}

void SDKCall_SetItem(Address pItem, Address pOther)
{
	SDKCall(g_hSDKSetItem, pItem, pOther);
}

int SDKCall_GetBaseEntity(Address pEntity)
{
	return SDKCall(g_hSDKGetBaseEntity, pEntity);
}

int SDKCall_GetMaxHealth(int iEntity)
{
	return SDKCall(g_hSDKGetMaxHealth, iEntity);
}

int SDKCall_GetSwordHealthMod(int iSword)
{
	return SDKCall(g_hSDKGetSwordHealthMod, iSword);
}

bool SDKCall_WeaponCanSwitchTo(int iClient, int iWeapon)
{
	return SDKCall(g_hSDKWeaponCanSwitchTo, iClient, iWeapon);
}

void SDKCall_EquipWearable(int iClient, int iWearable)
{
	SDKCall(g_hSDKEquipWearable, iClient, iWearable);
}

int SDKCall_GiveNamedItem(int iClient, const char[] sClassname, int iSubType, Address pItem, bool b = false)
{
	return SDKCall(g_hSDKGiveNamedItem, iClient, sClassname, iSubType, pItem, b);
}