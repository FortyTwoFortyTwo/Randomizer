static Handle g_hSDKAddObject;
static Handle g_hSDKRemoveObject;
static Handle g_hSDKDoClassSpecialSkill;
static Handle g_hSDKGetLoadoutItem;
static Handle g_hSDKHandleRageGain;
static Handle g_hSDKGetSlot;
static Handle g_hSDKEquipWearable;
static Handle g_hSDKWeaponReset;
static Handle g_hSDKGiveNamedItem;

public void SDKCall_Init(GameData hGameData)
{
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::AddObject");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKAddObject = EndPrepSDKCall();
	if (g_hSDKAddObject == null)
		LogMessage("Failed to create call: CTFPlayer::AddObject");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::RemoveObject");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKRemoveObject = EndPrepSDKCall();
	if (g_hSDKRemoveObject == null)
		LogMessage("Failed to create call: CTFPlayer::RemoveObject");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::DoClassSpecialSkill");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hSDKDoClassSpecialSkill = EndPrepSDKCall();
	if (!g_hSDKDoClassSpecialSkill)
		LogError("Failed to create call: CTFPlayer::DoClassSpecialSkill");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::GetLoadoutItem");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	g_hSDKGetLoadoutItem = EndPrepSDKCall();
	if (!g_hSDKGetLoadoutItem)
		SetFailState("Failed to create call: CTFPlayer::GetLoadoutItem");
	
	//This function is actually not a class entity, but still works like this
	// void HandleRageGain( CTFPlayer *pPlayer, unsigned int iRequiredBuffFlags, float flDamage, float fInverseRageGainScale )
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "HandleRageGain");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);	// unsigned int
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_ByValue);
	g_hSDKHandleRageGain = EndPrepSDKCall();
	if (!g_hSDKHandleRageGain)
		SetFailState("Failed to create call: HandleRageGain");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBaseCombatWeapon::GetSlot");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	g_hSDKGetSlot = EndPrepSDKCall();
	if (!g_hSDKGetSlot)
		LogError("Failed to create call: CBaseCombatWeapon::GetSlot");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBasePlayer::EquipWearable");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKEquipWearable = EndPrepSDKCall();
	if (!g_hSDKEquipWearable)
		LogError("Failed to create call: CBasePlayer::EquipWearable");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTFWeaponBase::WeaponReset");
	g_hSDKWeaponReset = EndPrepSDKCall();
	if (!g_hSDKWeaponReset)
		LogError("Failed to create call: CTFWeaponBase::WeaponReset");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CTFPlayer::GiveNamedItem");
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_ByValue);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKGiveNamedItem = EndPrepSDKCall();
	if (!g_hSDKGiveNamedItem)
		SetFailState("Failed to create call: CTFPlayer::GiveNamedItem");
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

Address SDKCall_GetLoadoutItem(int iClient, TFClassType nClass, int iSlot, bool b = false)
{
	return SDKCall(g_hSDKGetLoadoutItem, iClient, nClass, iSlot, b);
}

void SDKCall_HandleRageGain(int iClient, int iRequiredBuffFlags, float flDamage, float fInverseRageGainScale)
{
	SDKCall(g_hSDKHandleRageGain, iClient, iRequiredBuffFlags, flDamage, fInverseRageGainScale);
}

int SDKCall_GetSlot(int iWeapon)
{
	return SDKCall(g_hSDKGetSlot, iWeapon);
}

void SDKCall_EquipWearable(int iClient, int iWearable)
{
	SDKCall(g_hSDKEquipWearable, iClient, iWearable);
}

void SDKCall_WeaponReset(int iWeapon)
{
	SDKCall(g_hSDKWeaponReset, iWeapon);
}

int SDKCall_GiveNamedItem(int iClient, const char[] sClassname, int iSubType, Address pItem, bool b = false)
{
	return SDKCall(g_hSDKGiveNamedItem, iClient, sClassname, iSubType, pItem, b);
}