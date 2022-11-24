static char g_sPlayerCondProp[][] = {
	"m_nPlayerCond",
	"m_nPlayerCondEx",
	"m_nPlayerCondEx2",
	"m_nPlayerCondEx3",
	"m_nPlayerCondEx4",
};

stock int TF2_CreateWeapon(int iClient, int iIndex, int iSlot)
{
	char sClassname[256];
	TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
	
	//We want to translate classname to correct classname AND slot wanted
	//First, try current class client playing
	if (TF2_GetSlotFromIndex(iIndex, TF2_GetPlayerClass(iClient)) == iSlot)
	{
		TF2Econ_TranslateWeaponEntForClass(sClassname, sizeof(sClassname), TF2_GetPlayerClass(iClient));
	}
	else
	{
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			if (TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass)) == iSlot)
			{
				TF2Econ_TranslateWeaponEntForClass(sClassname, sizeof(sClassname), view_as<TFClassType>(iClass));
				break;
			}
		}
	}
	
	int iWeapon = CreateEntityByName(sClassname);
	if (IsValidEntity(iWeapon))
	{
		SetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex", iIndex);
		SetEntProp(iWeapon, Prop_Send, "m_bInitialized", 1);
		
		SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", TFQual_Unique);
		SetEntProp(iWeapon, Prop_Send, "m_iEntityLevel", 1);
		
		if (TF2Econ_GetItemLoadoutSlot(iIndex, TFClass_Spy) == LoadoutSlot_Building)
		{
			SetEntProp(iWeapon, Prop_Send, "m_iObjectType", TFObject_Sapper);
			SetEntProp(iWeapon, Prop_Data, "m_iSubType", TFObject_Sapper);
		}
		
		DispatchSpawn(iWeapon);
	}
	else
	{
		PrintToChat(iClient, "Unable to create weapon! index (%d) classname (%s)", iIndex, sClassname);
		LogError("Unable to create weapon! index (%d), classname (%s)", iIndex, sClassname);
	}
	
	return iWeapon;
}

stock int TF2_GiveNamedItem(int iClient, Address pItem, int iSlot = -1)
{
	int iIndex = LoadFromAddress(pItem + view_as<Address>(g_iOffsetItemDefinitionIndex), NumberType_Int16);
	
	//We want to translate classname to correct classname AND slot wanted
	//First, try current class client playing
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	if (TF2_GetSlotFromIndex(iIndex, nClass) != iSlot)
	{
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			if (TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass)) == iSlot)
			{
				nClass = view_as<TFClassType>(iClass);
				break;
			}
		}
	}
	
	char sClassname[256];
	TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
	TF2Econ_TranslateWeaponEntForClass(sClassname, sizeof(sClassname), nClass);
	
	int iSubType = 0;
	if (TF2Econ_GetItemLoadoutSlot(iIndex, TFClass_Spy) == LoadoutSlot_Building)
		iSubType = view_as<int>(TFObject_Sapper);
	
	g_bAllowGiveNamedItem = true;
	int iWeapon = SDKCall_GiveNamedItem(iClient, sClassname, iSubType, pItem, true);
	g_bAllowGiveNamedItem = false;
	
	if (TF2Econ_GetItemLoadoutSlot(iIndex, TFClass_Engineer) == LoadoutSlot_Building)
	{
		SetEntProp(iWeapon, Prop_Send, "m_aBuildableObjectTypes", true, _, view_as<int>(TFObject_Dispenser));
		SetEntProp(iWeapon, Prop_Send, "m_aBuildableObjectTypes", true, _, view_as<int>(TFObject_Teleporter));
		SetEntProp(iWeapon, Prop_Send, "m_aBuildableObjectTypes", true, _, view_as<int>(TFObject_Sentry));
		SetEntProp(iWeapon, Prop_Send, "m_aBuildableObjectTypes", false, _, view_as<int>(TFObject_Sapper));
	}
	
	return iWeapon;
}

stock void TF2_EquipWeapon(int iClient, int iWeapon)
{
	SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", true);
	
	if (TF2_IsWearable(iWeapon))
		SDKCall_EquipWearable(iClient, iWeapon);
	else
		EquipPlayerWeapon(iClient, iWeapon);
}

stock Address TF2_FindReskinItem(int iClient, int iIndex)
{
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		int iSlot = TF2Econ_GetItemLoadoutSlot(iIndex, view_as<TFClassType>(iClass));
		Address pItem = SDKCall_GetLoadoutItem(iClient, view_as<TFClassType>(iClass), iSlot);
		if (TF2_IsValidEconItemView(pItem) && Weapons_GetReskinIndex(LoadFromAddress(pItem + view_as<Address>(g_iOffsetItemDefinitionIndex), NumberType_Int16)) == iIndex)
			return pItem;
	}
	
	return Address_Null;
}

stock bool TF2_IsValidEconItemView(Address pItem)
{
	if (!pItem)
		return false;
	
	int iIndex = LoadFromAddress(pItem + view_as<Address>(g_iOffsetItemDefinitionIndex), NumberType_Int16);
	
	// 65535 is basically unsigned -1 in int16
	return 0 <= iIndex < 65535;
}

stock bool TF2_IsWearable(int iWeapon)
{
	char sClassname[256];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	return StrContains(sClassname, "tf_wearable") == 0 || StrEqual(sClassname, "tf_powerup_bottle");
}


stock int TF2_GetWearableCount(int iClient)
{
	return GetEntData(iClient, g_iOffsetMyWearables + 0x0C);
}

stock int TF2_GetWearable(int iClient, int iIndex)
{
	Address pData = view_as<Address>(LoadFromAddress(GetEntityAddress(iClient) + view_as<Address>(g_iOffsetMyWearables), NumberType_Int32));
	return EntRefToEntIndex(LoadFromAddress(pData + view_as<Address>(0x04 * iIndex), NumberType_Int32) | (1 << 31));
}

stock bool TF2_IndexFindAttribute(int iIndex, const char[] sAttrib, float &flVal)
{
	ArrayList aAttribs = TF2Econ_GetItemStaticAttributes(iIndex);
	int iAttrib = TF2Econ_TranslateAttributeNameToDefinitionIndex(sAttrib);
	
	int iPos = aAttribs.FindValue(iAttrib, 0);
	if (iPos >= 0)
	{
		flVal = aAttribs.Get(iPos, 1);
		delete aAttribs;
		return true;
	}
	
	delete aAttribs;
	return false;
}

stock bool TF2_GetItem(int iClient, int &iWeapon, int &iPos, bool bCosmetic = false)
{
	//Could be looped through client slots, but would cause issues with >1 weapons in same slot
	int iMaxWeapons = GetMaxWeapons();
	
	//Loop though all weapons (non-wearables)
	while (iPos < iMaxWeapons)
	{
		iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", iPos);
		iPos++;
		
		if (iWeapon != INVALID_ENT_REFERENCE)
			return true;
	}
	
	int iWearableIndex = iPos - iMaxWeapons;
	int iWearableCount = TF2_GetWearableCount(iClient);
	
	//Loop through all wearables
	while (iWearableCount > iWearableIndex)
	{
		iWeapon = TF2_GetWearable(iClient, iWearableIndex);
		iPos++;
		iWearableIndex++;
		if (iWeapon == INVALID_ENT_REFERENCE)
			continue;
		
		int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		if (iIndex < 0 || iIndex >= 65535)
			continue;	//Probably attached wearable from weapon
		
		if (bCosmetic)
			return true;
		
		//Check if it not cosmetic
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
			if (0 <= iSlot <= WeaponSlot_Building)
				return true;
		}
	}
	
	//No more weapons to loop
	iWeapon = INVALID_ENT_REFERENCE;
	iPos = 0;
	return false;
}

stock bool TF2_GetItemFromClassname(int iClient, const char[] sClassname, int &iWeapon, int &iPos)
{
	while (TF2_GetItem(iClient, iWeapon, iPos, true))
		if (IsClassname(iWeapon, sClassname))
			return true;
	
	return false;
}

stock bool TF2_GetItemFromLoadoutSlot(int iClient, int iSlot, int &iWeapon, int &iPos)
{
	while (TF2_GetItem(iClient, iWeapon, iPos, true))
	{
		int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			if (TF2Econ_GetItemLoadoutSlot(iIndex, view_as<TFClassType>(iClass)) == iSlot)
				return true;
		}
	}
	
	return false;
}

stock bool TF2_GetItemFromAttribute(int iClient, const char[] sAttrib, int &iWeapon, int &iPos)
{
	while (TF2_GetItem(iClient, iWeapon, iPos, true))
		if (SDKCall_AttribHookValueFloat(0.0, sAttrib, iWeapon))
			return true;
	
	return false;
}

stock int TF2_GetSlot(int iWeapon)
{
	int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
	TFClassType nClass = TF2_GetDefaultClassFromItem(iWeapon);
	int iSlot = TF2_GetSlotFromIndex(iIndex, nClass);
	if (iSlot == -1)
	{
		char sClassname[256];
		GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
		ThrowError("Could not find slot from item def index '%d' and classname '%s'", iIndex, sClassname);
	}
	
	return iSlot;
}

stock int TF2_GetSlotFromIndex(int iIndex, TFClassType nClass = TFClass_Unknown)
{
	int iSlot = TF2Econ_GetItemLoadoutSlot(iIndex, nClass);
	if (iSlot == LoadoutSlot_Action)
	{
		iSlot = WeaponSlot_Building;
	}
	else
	{
		// Econ reports wrong slots for Engineer and Spy
		switch (nClass)
		{
			case TFClass_Engineer:
			{
				switch (iSlot)
				{
					case LoadoutSlot_Building: iSlot = WeaponSlot_Building; // Toolbox
					case LoadoutSlot_PDA: iSlot = WeaponSlot_PDA; // Construction PDA
					case LoadoutSlot_PDA2: iSlot = WeaponSlot_PDA2; // Destruction PDA
				}
			}
			case TFClass_Spy:
			{
				switch (iSlot)
				{
					case LoadoutSlot_Secondary: iSlot = WeaponSlot_Primary; // Revolver
					case LoadoutSlot_Building: iSlot = WeaponSlot_Secondary; // Sapper
					case LoadoutSlot_PDA: iSlot = WeaponSlot_PDA; // Disguise Kit
					case LoadoutSlot_PDA2: iSlot = WeaponSlot_PDA2; // Invis Watch
				}
			}
		}
	}
	
	return iSlot;
}

stock TFClassType TF2_GetDefaultClassFromItem(int iWeapon)
{
	int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
	
	char sWeaponClassname[256], sIndexClassname[256];
	GetEntityClassname(iWeapon, sWeaponClassname, sizeof(sWeaponClassname));
	TF2Econ_GetItemClassName(iIndex, sIndexClassname, sizeof(sIndexClassname));
	
	//Try client class first
	int iClient = GetEntProp(iWeapon, Prop_Send, "m_hOwnerEntity");
	if (0 < iClient <= MaxClients)
	{
		TFClassType nClass = TF2_GetPlayerClass(iClient);
		if (TF2_GetSlotFromIndex(iIndex, nClass) != -1)
		{
			char sClassClassname[256];
			sClassClassname = sIndexClassname;
			TF2Econ_TranslateWeaponEntForClass(sClassClassname, sizeof(sClassClassname), nClass);
			
			if (StrEqual(sWeaponClassname, sClassClassname))
				return nClass;
		}
	}
	
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		if (TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass)) >= WeaponSlot_Primary)
		{
			char sClassClassname[256];
			sClassClassname = sIndexClassname;
			TF2Econ_TranslateWeaponEntForClass(sClassClassname, sizeof(sClassClassname), view_as<TFClassType>(iClass));
			
			if (StrEqual(sWeaponClassname, sClassClassname))
				return view_as<TFClassType>(iClass);
		}
	}
	
	return TFClass_Unknown;
}

stock TFClassType TF2_GetRandomClass()
{
	return view_as<TFClassType>(GetRandomInt(CLASS_MIN, CLASS_MAX));
}

stock int TF2_GetSapper(int iObject)
{
	if (!GetEntProp(iObject, Prop_Send, "m_bHasSapper"))
		return INVALID_ENT_REFERENCE;
	
	return GetEntPropEnt(iObject, Prop_Data, "m_hMoveChild");
}

stock bool TF2_CanSwitchTo(int iClient, int iWeapon)
{
	char sClassname[256];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	if (StrContains(sClassname, "tf_weapon") != 0)
		return false;
	
	return SDKCall_WeaponCanSwitchTo(iClient, iWeapon);
}

stock void TF2_SwitchToWeapon(int iClient, int iWeapon)
{
	//Deatch other weapons first as some may have same classname
	int iMaxWeapons = GetMaxWeapons();
	int[] iWeapons = new int[iMaxWeapons];
	
	for (int i = 0; i < iMaxWeapons; i++)
	{
		iWeapons[i] = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", i);
		if (iWeapons[i] != iWeapon)
			SetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", -1, i);
	}
	
	char sClassname[256];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	FakeClientCommand(iClient, "use %s", sClassname);
	
	for (int i = 0; i < iMaxWeapons; i++)
		SetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", iWeapons[i], i);
}

stock int TF2_GiveAmmo(int iClient, int iWeapon, int iCurrent, int iAdd, int iAmmoType, bool bSuppressSound, EAmmoSource eAmmoSource)
{
	//Basically CTFPlayer::GiveAmmo but without interfering m_iAmmo and other weapons
	if (iAdd <= 0 || iAmmoType < 0 || iAmmoType >= TF_AMMO_COUNT)	//TF2 using MAX_AMMO_SLOTS (32) instead of TF_AMMO_COUNT...
		return 0;
	
	if (eAmmoSource == kAmmoSource_Resupply)
	{
		switch (iAmmoType)
		{
			case TF_AMMO_GRENADES1:
			{
				if (SDKCall_AttribHookValueFloat(0.0, "grenades1_resupply_denied", iWeapon))
					return 0;
			}
			case TF_AMMO_GRENADES2:
			{
				if (SDKCall_AttribHookValueFloat(0.0, "grenades2_resupply_denied", iWeapon))
					return 0;
			}
			case TF_AMMO_GRENADES3:
			{
				if (SDKCall_AttribHookValueFloat(0.0, "grenades3_resupply_denied", iWeapon))
					return 0;
			}
		}
	}
	else if (iAmmoType == TF_AMMO_METAL)	//Must not be from kAmmoSource_Resupply
	{
		float flVal = SDKCall_AttribHookValueFloat(1.0, "mult_metal_pickup", iClient);
		iAdd = RoundToFloor(flVal * float(iAdd));
	}
	
	int iMaxAmmo = TF2_GetMaxAmmo(iClient, iWeapon, iAmmoType);
	if (iAdd + iCurrent > iMaxAmmo)
		iAdd = iMaxAmmo - iCurrent;
	
	if (iAdd <= 0)
		return 0;
	
	if (!bSuppressSound)
		EmitGameSoundToClient(iClient, "BaseCombatCharacter.AmmoPickup");
	
	return iAdd;
}

stock int TF2_GetMaxAmmo(int iClient, int iWeapon, int iAmmoType)
{
	//CTFPlayer::GetMaxAmmo gets attribute by whole from client, which we dont want all weapons.
	//We only want to scale attrib with weapon itself and all other weapons not using same ammotype
	
	int iMaxAmmo = SDKCall_GetMaxAmmo(iClient, iAmmoType, TF2_GetDefaultClassFromItem(iWeapon));
	float flMultiClient = TF2_GetMultiMaxAmmo(1.0, iAmmoType, iClient);
	float flMultiWeapon = 1.0;
	
	int iMaxWeapons = GetMaxWeapons();
	for (int i = 0; i < iMaxWeapons; i++)
	{
		int iTempWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", i);
		if (iTempWeapon == INVALID_ENT_REFERENCE)
			continue;
		
		if (iTempWeapon != iWeapon && GetEntProp(iTempWeapon, Prop_Send, "m_iPrimaryAmmoType") == iAmmoType)
			continue;
		
		flMultiWeapon = TF2_GetMultiMaxAmmo(flMultiWeapon, iAmmoType, iTempWeapon);
	}
	
	return RoundToFloor(float(iMaxAmmo) / flMultiClient * flMultiWeapon);
}

stock float TF2_GetMultiMaxAmmo(float flInitial, int iAmmoType, int iEntity)
{
	switch (iAmmoType)
	{
		case TF_AMMO_PRIMARY: return SDKCall_AttribHookValueFloat(flInitial, "mult_maxammo_primary", iEntity);
		case TF_AMMO_SECONDARY: return SDKCall_AttribHookValueFloat(flInitial, "mult_maxammo_secondary", iEntity);
		case TF_AMMO_METAL: return SDKCall_AttribHookValueFloat(flInitial, "mult_maxammo_metal", iEntity);
		case TF_AMMO_GRENADES1: return SDKCall_AttribHookValueFloat(flInitial, "mult_maxammo_grenades1", iEntity);
		default: return flInitial;
	}
}

stock void TF2_RemoveItem(int iClient, int iWeapon)
{
	if (TF2_IsWearable(iWeapon))
	{
		//If wearable, just simply use TF2_RemoveWearable
		TF2_RemoveWearable(iClient, iWeapon);
		return;
	}
	
	//Below similar to TF2_RemoveWeaponSlot, but only removes 1 weapon instead of all weapons in 1 slot
	
	int iExtraWearable = GetEntPropEnt(iWeapon, Prop_Send, "m_hExtraWearable");
	if (iExtraWearable != -1)
		TF2_RemoveWearable(iClient, iExtraWearable);
	
	iExtraWearable = GetEntPropEnt(iWeapon, Prop_Send, "m_hExtraWearableViewModel");
	if (iExtraWearable != -1)
		TF2_RemoveWearable(iClient, iExtraWearable);
	
	RemovePlayerItem(iClient, iWeapon);
	
	//Add to list to remove later instead of removing all weapons at once
	g_aEntityToRemove.Push(EntIndexToEntRef(iWeapon));
}

stock void TF2_AddConditionFake(int iClient, TFCond nCond)
{
	int iCond = view_as<int>(nCond);
	int iArray = iCond / 32;
	int iBit = (1 << (iCond - (iArray * 32)));
	SetEntProp(iClient, Prop_Send, g_sPlayerCondProp[iArray], GetEntProp(iClient, Prop_Send, g_sPlayerCondProp[iArray]) | iBit);
}

stock void TF2_RemoveConditionFake(int iClient, TFCond nCond)
{
	int iCond = view_as<int>(nCond);
	int iArray = iCond / 32;
	int iBit = (1 << (iCond - (iArray * 32)));
	SetEntProp(iClient, Prop_Send, g_sPlayerCondProp[iArray], GetEntProp(iClient, Prop_Send, g_sPlayerCondProp[iArray]) & ~iBit);
	
	if (iArray == 0)	//Thanks legacy TF2
		SetEntProp(iClient, Prop_Send, "_condition_bits", GetEntProp(iClient, Prop_Send, "_condition_bits") & ~iBit);
}

stock int TF2_SpawnParticle(const char[] sParticle, int iEntity)
{
	int iParticle = CreateEntityByName("info_particle_system");
	DispatchKeyValue(iParticle, "effect_name", sParticle);
	DispatchSpawn(iParticle);
	
	float vecOrigin[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", vecOrigin);
	TeleportEntity(iParticle, vecOrigin, NULL_VECTOR, NULL_VECTOR);
	
	SetVariantString("!activator");
	AcceptEntityInput(iParticle, "SetParent", iEntity);
	
	SetVariantString("weapon_bone_L");
	AcceptEntityInput(iParticle, "SetParentAttachment");
	
	//Return ref of entity
	return EntIndexToEntRef(iParticle);
}

stock float min(float a, float b)
{
	return a < b ? a : b;
}

stock float max(float a, float b)
{
	return a > b ? a : b;
}

stock float clamp(float val, float minVal, float maxVal)
{
	if (maxVal < minVal)
		return maxVal;
	else if (val < minVal)
		return minVal;
	else if (val > maxVal)
		return maxVal;
	else
		return val;
}

stock float RemapValClamped(float val, float A, float B, float C, float D)
{
	if ( A == B )
		return val >= B ? D : C;
	
	float cVal = (val - A) / (B - A);
	cVal = clamp(cVal, 0.0, 1.0);
	
	return C + (D - C) * cVal;
}

stock bool IsClassname(int iEntity, const char[] sClassname)
{
	char sBuffer[256];
	GetEntityClassname(iEntity, sBuffer, sizeof(sBuffer));
	return StrEqual(sBuffer, sClassname);
}

stock void AddEntityEffect(int iEntity, int iFlag)
{
	SetEntProp(iEntity, Prop_Send, "m_fEffects", GetEntProp(iEntity, Prop_Send, "m_fEffects") | iFlag);
}

stock void RemoveEntityEffect(int iEntity, int iFlag)
{
	SetEntProp(iEntity, Prop_Send, "m_fEffects", GetEntProp(iEntity, Prop_Send, "m_fEffects") & ~iFlag);
}

stock bool ItemIsAllowed(int iIndex)
{
	if (GameRules_GetProp("m_bPlayingMedieval") || (GameRules_GetRoundState() == RoundState_Stalemate && FindConVar("mp_stalemate_meleeonly").BoolValue))
	{
		//TF2 hack!
		char sClassname[256];
		TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
		if (StrEqual(sClassname, "tf_weapon_passtime_gun"))
			return true;
		
		//For medieval and melee stalemate, allow melee and spy PDA
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
			if (iSlot == WeaponSlot_Melee)
				return true;
			else if ((iSlot == WeaponSlot_PDA || iSlot == WeaponSlot_PDA2) && view_as<TFClassType>(iClass) == TFClass_Spy)
				return true;
		}
		
		//For medieval, allow medieval weapons
		if (GameRules_GetProp("m_bPlayingMedieval"))
		{
			float flVal;
			if (TF2_IndexFindAttribute(iIndex, "allowed in medieval mode", flVal) && flVal)
				return true;
		}
		
		return false;
	}
	
	return true;
}

stock int GetMaxWeapons()
{
	static int iMaxWeapons;
	if (!iMaxWeapons)
	{
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (IsClientInGame(iClient))
			{
				iMaxWeapons = GetEntPropArraySize(iClient, Prop_Send, "m_hMyWeapons");
				break;
			}
		}
	}
	
	return iMaxWeapons;
}

stock void GetEntityModel(int iEntity, char[] sModel, int iMaxSize)
{
	int iIndex = GetEntProp(iEntity, Prop_Send, "m_nModelIndex");
	int iTable = FindStringTable("modelprecache");
	ReadStringTable(iTable, iIndex, sModel, iMaxSize);
}

stock int GetModelIndex(const char[] sModel)
{
	int iTable = FindStringTable("modelprecache");
	return FindStringIndex(iTable, sModel);
}

stock int PrecacheParticleSystem(const char[] sParticle)
{
	static int iParticleEffectNames = INVALID_STRING_TABLE;
	if (iParticleEffectNames == INVALID_STRING_TABLE)
		if ((iParticleEffectNames = FindStringTable("ParticleEffectNames")) == INVALID_STRING_TABLE)
			return INVALID_STRING_INDEX;
	
	int iIndex = FindStringIndex2(iParticleEffectNames, sParticle);
	if (iIndex == INVALID_STRING_INDEX)
	{
		int iNumStrings = GetStringTableNumStrings(iParticleEffectNames);
		if (iNumStrings >= GetStringTableMaxStrings(iParticleEffectNames))
			return INVALID_STRING_INDEX;
		
		AddToStringTable(iParticleEffectNames, sParticle);
		iIndex = iNumStrings;
	}

	return iIndex;
}

stock int FindStringIndex2(int iTableId, const char[] sParticle)
{
	char sBuffer[1024];
	int iNumStrings = GetStringTableNumStrings(iTableId);
	for (int i = 0; i < iNumStrings; i++)
	{
		ReadStringTable(iTableId, i, sBuffer, sizeof(sBuffer));
		if (StrEqual(sBuffer, sParticle))
			return i;
	}

	return INVALID_STRING_INDEX;
}