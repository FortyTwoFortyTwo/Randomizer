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
static Handle g_hSDKAttribHookValueFloat;
static Handle g_hSDKHandleRageGain;
static Handle g_hSDKGetBaseEntity;
static Handle g_hSDKGetMaxHealth;
static Handle g_hSDKWeaponCanSwitchTo;
static Handle g_hSDKEquipWearable;
static Handle g_hSDKGiveNamedItem;

public void SDKCall_Init(GameData hGameData)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::GetMaxAmmo");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetMaxAmmo = EndPrepSDKCall();
	if (!g_hSDKGetMaxAmmo)
		LogMessage("Failed to create call: CTFPlayer::GetMaxAmmo");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::AddObject");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKAddObject = EndPrepSDKCall();
	if (!g_hSDKAddObject)
		LogError("Failed to create call: CTFPlayer::AddObject");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::RemoveObject");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKRemoveObject = EndPrepSDKCall();
	if (!g_hSDKRemoveObject)
		LogError("Failed to create call: CTFPlayer::RemoveObject");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::DoClassSpecialSkill");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKDoClassSpecialSkill = EndPrepSDKCall();
	if (!g_hSDKDoClassSpecialSkill)
		LogError("Failed to create call: CTFPlayer::DoClassSpecialSkill");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::EndClassSpecialSkill");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKEndClassSpecialSkill = EndPrepSDKCall();
	if (!g_hSDKEndClassSpecialSkill)
		LogError("Failed to create call: CTFPlayer::EndClassSpecialSkill");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::GetLoadoutItem");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	g_hSDKGetLoadoutItem = EndPrepSDKCall();
	if (!g_hSDKGetLoadoutItem)
		LogError("Failed to create call: CTFPlayer::GetLoadoutItem");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFSpellBook::RollNewSpell");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_ByValue);
	g_hSDKRollNewSpell = EndPrepSDKCall();
	if (!g_hSDKRollNewSpell)
		LogError("Failed to create call: CTFSpellBook::RollNewSpell");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayerShared::UpdateRageBuffsAndRage");
	g_hSDKUpdateRageBuffsAndRage = EndPrepSDKCall();
	if (!g_hSDKUpdateRageBuffsAndRage)
		LogError("Failed to create call: CTFPlayerShared::UpdateRageBuffsAndRage");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayerShared::ModifyRage");
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_ByValue);
	g_hSDKModifyRage = EndPrepSDKCall();
	if (!g_hSDKModifyRage)
		LogError("Failed to create call: CTFPlayerShared::ModifyRage");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayerShared::SetCarryingRuneType");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	g_hSDKSetCarryingRuneType = EndPrepSDKCall();
	if (!g_hSDKSetCarryingRuneType)
		LogError("Failed to create call: CTFPlayerShared::SetCarryingRuneType");
	
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CAttributeManager::AttribHookValue<float>");
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	g_hSDKAttribHookValueFloat = EndPrepSDKCall();
	if (!g_hSDKAttribHookValueFloat)
		LogError("Failed to create call: CAttributeManager::AttribHookValue<float>");
	
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "HandleRageGain");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);	// unsigned int
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_ByValue);
	g_hSDKHandleRageGain = EndPrepSDKCall();
	if (!g_hSDKHandleRageGain)
		LogError("Failed to create call: HandleRageGain");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBaseEntity::GetBaseEntity");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKGetBaseEntity = EndPrepSDKCall();
	if (!g_hSDKGetBaseEntity)
		LogError("Failed to create call: CBaseEntity::GetBaseEntity");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBaseEntity::GetMaxHealth");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	g_hSDKGetMaxHealth = EndPrepSDKCall();
	if (!g_hSDKGetMaxHealth)
		LogError("Failed to create call: CBaseEntity::GetMaxHealth");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBaseCombatCharacter::Weapon_CanSwitchTo");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_ByValue);
	g_hSDKWeaponCanSwitchTo = EndPrepSDKCall();
	if (!g_hSDKWeaponCanSwitchTo)
		LogError("Failed to create call: CBaseCombatCharacter::Weapon_CanSwitchTo");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBasePlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKEquipWearable = EndPrepSDKCall();
	if (!g_hSDKEquipWearable)
		LogError("Failed to create call: CBasePlayer::EquipWearable");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTFPlayer::GiveNamedItem");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKGiveNamedItem = EndPrepSDKCall();
	if (!g_hSDKGiveNamedItem)
		LogError("Failed to create call: CTFPlayer::GiveNamedItem");
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

float SDKCall_AttribHookValueFloat(float flInitial, const char[] sAttribClass, int iEntity, Address pItemList = Address_Null, bool bString = false)
{
	return SDKCall(g_hSDKAttribHookValueFloat, flInitial, sAttribClass, iEntity, pItemList, bString);
}

void SDKCall_HandleRageGain(int iClient, int iRequiredBuffFlags, float flDamage, float fInverseRageGainScale)
{
	SDKCall(g_hSDKHandleRageGain, iClient, iRequiredBuffFlags, flDamage, fInverseRageGainScale);
}

int SDKCall_GetBaseEntity(Address pEntity)
{
	return SDKCall(g_hSDKGetBaseEntity, pEntity);
}

bool SDKCall_GetMaxHealth(int iEntity)
{
	return SDKCall(g_hSDKGetMaxHealth, iEntity);
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
