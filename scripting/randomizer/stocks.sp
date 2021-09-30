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
	
	bool bSapper;
	if (StrEqual(sClassname, "tf_weapon_builder") || StrEqual(sClassname, "tf_weapon_sapper"))
	{
		bSapper = true;
		
		//tf_weapon_sapper is bad and give client crashes
		sClassname = "tf_weapon_builder";
	}
	
	int iWeapon = CreateEntityByName(sClassname);
	if (IsValidEntity(iWeapon))
	{
		SetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex", iIndex);
		SetEntProp(iWeapon, Prop_Send, "m_bInitialized", 1);
		
		SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", TFQual_Unique);
		SetEntProp(iWeapon, Prop_Send, "m_iEntityLevel", 1);
		
		if (bSapper)
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
	int iSubType = 0;
	
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
	
	TFClassType nClassBuilder = TFClass_Unknown;
	if (StrEqual(sClassname, "tf_weapon_builder") || StrEqual(sClassname, "tf_weapon_sapper"))
		nClassBuilder = nClass;
	
	if (nClassBuilder == TFClass_Spy)
		iSubType = view_as<int>(TFObject_Sapper);
	
	g_bAllowGiveNamedItem = true;
	int iWeapon = SDKCall_GiveNamedItem(iClient, sClassname, iSubType, pItem, true);
	g_bAllowGiveNamedItem = false;
	
	if (nClassBuilder == TFClass_Engineer)
	{
		SetEntProp(iWeapon, Prop_Send, "m_aBuildableObjectTypes", true, _, view_as<int>(TFObject_Dispenser));
		SetEntProp(iWeapon, Prop_Send, "m_aBuildableObjectTypes", true, _, view_as<int>(TFObject_Teleporter));
		SetEntProp(iWeapon, Prop_Send, "m_aBuildableObjectTypes", true, _, view_as<int>(TFObject_Sentry));
		SetEntProp(iWeapon, Prop_Send, "m_aBuildableObjectTypes", false, _, view_as<int>(TFObject_Sapper));
	}
	
	return iWeapon;
}

stock int TF2_EquipWeapon(int iClient, int iWeapon)
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

stock bool TF2_WeaponFindAttribute(int iWeapon, char[] sAttrib, float &flVal)
{
	Address pAttrib = TF2Attrib_GetByName(iWeapon, sAttrib);
	if (pAttrib != Address_Null)
	{
		flVal = TF2Attrib_GetValue(pAttrib);
		return true;
	}
	
	if (!GetEntProp(iWeapon, Prop_Send, "m_bOnlyIterateItemViewAttributes")) //Weapon is still using it's default attributes
	{
		int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		return TF2_IndexFindAttribute(iIndex, sAttrib, flVal);
	}
	
	return false;
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

float TF2_GetAttributePercentage(int iClient, char[] sAttrib)
{
	float flTotal = 1.0;
	
	Address pAttrib = TF2Attrib_GetByName(iClient, sAttrib);
	if (pAttrib != Address_Null)
		flTotal *= TF2Attrib_GetValue(pAttrib);
	
	int iWeapon, iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		float flVal;
		if (TF2_WeaponFindAttribute(iWeapon, sAttrib, flVal))
			flTotal *= flVal;
	}
	
	return flTotal;
}

float TF2_GetAttributeAdditive(int iClient, char[] sAttrib)
{
	float flTotal;
	
	Address pAttrib = TF2Attrib_GetByName(iClient, sAttrib);
	if (pAttrib != Address_Null)
		flTotal += TF2Attrib_GetValue(pAttrib);
	
	int iWeapon, iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		float flVal;
		if (TF2_WeaponFindAttribute(iWeapon, sAttrib, flVal))
			flTotal += flVal;
	}
	
	return flTotal;
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
		
		//Reset iWeapon for wearable loop below
		if (iPos == iMaxWeapons)
			iWeapon = INVALID_ENT_REFERENCE;
	}
	
	if (iPos == iMaxWeapons)
	{
		//Loop through all wearables
		while ((iWeapon = FindEntityByClassname(iWeapon, "tf_wearable*")) != INVALID_ENT_REFERENCE)
		{
			if (GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity") == iClient)
			{
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
		}
		
		//Reset iWeapon for canteen loop below
		iWeapon = INVALID_ENT_REFERENCE;
		iPos = iMaxWeapons + 1;
	}
	
	//Loop through all canteens
	if (bCosmetic)
		while ((iWeapon = FindEntityByClassname(iWeapon, "tf_powerup_bottle")) != INVALID_ENT_REFERENCE)
			if (GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity") == iClient)
				return true;
	
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

stock bool TF2_GetItemFromAttribute(int iClient, char[] sAttrib, int &iWeapon, int &iPos)
{
	float flVal;
	
	while (TF2_GetItem(iClient, iWeapon, iPos, true))
		if (TF2_WeaponFindAttribute(iWeapon, sAttrib, flVal))
			return true;
	
	return false;
}

stock int TF2_GetSlot(int iWeapon)
{
	if (TF2_IsWearable(iWeapon))
	{
		int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		{
			int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
			if (0 <= iSlot <= WeaponSlot_Building)
				return iSlot;
		}
	}
	else
	{
		return SDKCall_GetSlot(iWeapon);
	}
	
	return -1;
}

stock int TF2_GetSlotFromIndex(int iIndex, TFClassType nClass = TFClass_Unknown)
{
	int iSlot = TF2Econ_GetItemLoadoutSlot(iIndex, nClass);
	if (iSlot >= 0)
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

stock bool TF2_SwitchToWeapon(int iClient, int iWeapon)
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
		float flVal;
		
		switch (iAmmoType)
		{
			case TF_AMMO_GRENADES1:
			{
				if (TF2_WeaponFindAttribute(iWeapon, "grenades1_resupply_denied", flVal) && flVal > 0.0)
					return 0;
			}
			case TF_AMMO_GRENADES2:
			{
				if (TF2_WeaponFindAttribute(iWeapon, "grenades2_resupply_denied", flVal) && flVal > 0.0)
					return 0;
			}
			case TF_AMMO_GRENADES3:
			{
				if (TF2_WeaponFindAttribute(iWeapon, "grenades3_resupply_denied", flVal) && flVal > 0.0)
					return 0;
			}
		}
	}
	else if (iAmmoType == TF_AMMO_METAL)	//Must not be from kAmmoSource_Resupply
	{
		float flVal = TF2_GetAttributePercentage(iClient, "metal_pickup_decreased");
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
	//Same as CTFPlayer::GetMaxAmmo, this is made because of multiple weapons conflicts eachother on attributes
	//TODO this function is so horrible with lots of hardcode, is there a better way to do this?
	
	int iClassMaxAmmo[CLASS_MAX+1][TF_AMMO_COUNT] = {
		{0, 0, 0, 0, 0, 0, 0},		//Undefined
		{0, 32, 36, 200, 1, 1, 1},	//Scout	
		{0, 25, 75, 200, 1, 1, 1},	//Sniper
		{0, 20, 32, 200, 1, 1, 1},	//Soldier
		{0, 16, 24, 200, 1, 1, 1},	//Demoman
		{0, 150, 0, 200, 1, 1, 1},	//Medic
		{0, 200, 32, 200, 1, 1, 1},	//Heavy
		{0, 200, 32, 200, 1, 1, 1},	//Pyro
		{0, 0, 24, 200, 1, 1, 1},	//Spy
		{0, 32, 200, 200, 1, 1, 1},	//Engineer
	};
	
	int iMaxAmmo = iClassMaxAmmo[TF2_GetDefaultClassFromItem(iWeapon)][iAmmoType];
	
	//Remove all weapons using same ammo index so they don't interfere with max ammo attributes
	//Don't remove weapons with different ammo index so they could interfere with max ammo attributes
	int iMaxWeapons = GetMaxWeapons();
	int[] iWeapons = new int[iMaxWeapons];
	
	for (int i = 0; i < iMaxWeapons; i++)
	{
		iWeapons[i] = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", i);
		if (iWeapons[i] != INVALID_ENT_REFERENCE && iWeapons[i] != iWeapon && GetEntProp(iWeapons[i], Prop_Send, "m_iPrimaryAmmoType") == iAmmoType)
			SetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", -1, i);
	}
	
	float flVal = 1.0;
	switch (iAmmoType)
	{
		case TF_AMMO_PRIMARY:
		{
			flVal *= TF2_GetAttributePercentage(iClient, "hidden primary max ammo bonus");
			flVal *= TF2_GetAttributePercentage(iClient, "maxammo primary increased");
			flVal *= TF2_GetAttributePercentage(iClient, "maxammo primary reduced");
			
		}
		case TF_AMMO_SECONDARY:
		{
			flVal *= TF2_GetAttributePercentage(iClient, "hidden secondary max ammo penalty");
			flVal *= TF2_GetAttributePercentage(iClient, "maxammo secondary increased");
			flVal *= TF2_GetAttributePercentage(iClient, "maxammo secondary reduced");
			
		}
		case TF_AMMO_METAL:
		{
			flVal *= TF2_GetAttributePercentage(iClient, "maxammo metal increased");
			flVal *= TF2_GetAttributePercentage(iClient, "maxammo metal reduced");
		}
		case TF_AMMO_GRENADES1:
		{
			flVal *= TF2_GetAttributePercentage(iClient, "maxammo grenades1 increased");
		}
	}
	
	if (TF2_IsPlayerInCondition(iClient, TFCond_RuneHaste))
		flVal *= 2.0;
	
	//Set it back
	for (int i = 0; i < iMaxWeapons; i++)
		SetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", iWeapons[i], i);
	
	return RoundToFloor(float(iMaxAmmo) * flVal);
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
	RemoveEntity(iWeapon);
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

stock bool IsClassname(int iEntity, const char[] sClassname)
{
	char sBuffer[256];
	GetEntityClassname(iEntity, sBuffer, sizeof(sBuffer));
	return StrEqual(sBuffer, sClassname);
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

stock bool CanKeepWeapon(int iClient, const char[] sClassname, int iIndex)
{
	if (g_bAllowGiveNamedItem)
		return true;
	
	//Allow grappling hook and passtime gun
	if (StrEqual(sClassname, "tf_weapon_grapplinghook") || StrEqual(sClassname, "tf_weapon_passtime_gun"))
		return true;
	
	int iSlot = -1;
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		iSlot = TF2Econ_GetItemLoadoutSlot(iIndex, view_as<TFClassType>(iClass));
		if (iSlot != -1)
			break;
	}
	
	//Allow action items
	if (iSlot == LoadoutSlot_Action)
		return true;
	
	if (IsWeaponRandomized(iClient))
	{
		//Dont allow weapons
		if (LoadoutSlot_Primary <= iSlot <= LoadoutSlot_PDA2)
			return false;
	}
	
	if (IsCosmeticRandomized(iClient))
	{
		//Dont allow cosmetics
		if (iSlot == LoadoutSlot_Misc)
			return false;
	}
	
	//Should be allowed
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