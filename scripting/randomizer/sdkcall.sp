static Handle g_hSDKGetBaseEntity;
static Handle g_hSDKGetDefaultItemChargeMeterValue;
static Handle g_hSDKEquipWearable;
static Handle g_hSDKWeaponReset;
static Handle g_hSDKAddObject;
static Handle g_hSDKRemoveObject;
static Handle g_hSDKDoClassSpecialSkill;
static Handle g_hSDKUpdateItemChargeMeters;
static Handle g_hSDKDrainCharge;

static Address g_pPlayerShared;
static Address g_pPlayerSharedOuter;

public void SDKCall_Init(GameData hGameData)
{
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBaseEntity::GetBaseEntity");
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKGetBaseEntity = EndPrepSDKCall();
	if (!g_hSDKGetBaseEntity)
		LogError("Failed to create call: CBaseEntity::GetBaseEntity");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "CBaseEntity::GetDefaultItemChargeMeterValue");
	PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
	g_hSDKGetDefaultItemChargeMeterValue = EndPrepSDKCall();
	if (!g_hSDKGetDefaultItemChargeMeterValue)
		LogError("Failed to create call: CBaseEntity::GetDefaultItemChargeMeterValue");
	
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
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayerShared::UpdateItemChargeMeters");
	g_hSDKUpdateItemChargeMeters = EndPrepSDKCall();
	if (!g_hSDKUpdateItemChargeMeters)
		LogError("Failed to create call: CTFPlayerShared::UpdateItemChargeMeters");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CWeaponMedigun::DrainCharge");
	g_hSDKDrainCharge = EndPrepSDKCall();
	if (!g_hSDKDrainCharge)
		LogError("Failed to create call: CWeaponMedigun::DrainCharge");
	
	g_pPlayerShared = view_as<Address>(FindSendPropInfo("CTFPlayer", "m_Shared"));
	g_pPlayerSharedOuter = view_as<Address>(hGameData.GetOffset("CTFPlayerShared::m_pOuter"));
}

float SDKCall_GetDefaultItemChargeMeterValue(int iWeapon)
{
	if (g_hSDKGetDefaultItemChargeMeterValue)
		return SDKCall(g_hSDKGetDefaultItemChargeMeterValue, iWeapon);
	
	return 0.0;
}

void SDKCall_EquipWearable(int iClient, int iWearable)
{
	if (g_hSDKEquipWearable)
		SDKCall(g_hSDKEquipWearable, iClient, iWearable);
}

void SDKCall_WeaponReset(int iWeapon)
{
	if (g_hSDKWeaponReset)
		SDKCall(g_hSDKWeaponReset, iWeapon);
}

void SDKCall_AddObject(int iClient, int iObject)
{
	if (g_hSDKAddObject)
		SDKCall(g_hSDKAddObject, iClient, iObject);
}

void SDKCall_RemoveObject(int iClient, int iObject)
{
	if (g_hSDKRemoveObject)
		SDKCall(g_hSDKRemoveObject, iClient, iObject);
}

bool SDKCall_DoClassSpecialSkill(int iClient)
{
	if (g_hSDKDoClassSpecialSkill)
		return SDKCall(g_hSDKDoClassSpecialSkill, iClient);
	
	return false;
}

void SDKCall_UpdateItemChargeMeters(int iClient)
{
	if (g_hSDKUpdateItemChargeMeters)
	{
		Address pThis = GetEntityAddress(iClient) + g_pPlayerShared;
		SDKCall(g_hSDKUpdateItemChargeMeters, pThis);
	}
}

void SDKCall_DrainCharge(int iMedigun)
{
	if (g_hSDKDrainCharge)
		SDKCall(g_hSDKDrainCharge, iMedigun);
}

int SDKCall_GetClientFromPlayerShared(Address pPlayerShared)
{
	Address pEntity = view_as<Address>(LoadFromAddress(pPlayerShared + g_pPlayerSharedOuter, NumberType_Int32));
	return SDKCall(g_hSDKGetBaseEntity, pEntity);
}