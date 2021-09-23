static StringMap g_mPropertiesWeaponSend[2048];
static StringMap g_mPropertiesWeaponData[2048];

static int g_iPropertiesForceWeaponAmmo = INVALID_ENT_REFERENCE;

// Load & Save Send Prop

void Properties_LoadWeaponPropInt(int iClient, int iWeapon, const char[] sProp, int iElement = 0)
{
	if (!g_mPropertiesWeaponSend[iWeapon])
		g_mPropertiesWeaponSend[iWeapon] = new StringMap();
	
	int iValue = 0;
	g_mPropertiesWeaponSend[iWeapon].GetValue(sProp, iValue);
	SetEntProp(iClient, Prop_Send, sProp, iValue, _, iElement);
}

void Properties_SaveWeaponPropInt(int iClient, int iWeapon, const char[] sProp, int iElement = 0)
{
	if (!g_mPropertiesWeaponSend[iWeapon])
		g_mPropertiesWeaponSend[iWeapon] = new StringMap();
	
	g_mPropertiesWeaponSend[iWeapon].SetValue(sProp, GetEntProp(iClient, Prop_Send, sProp, _, iElement));
	
	//Revert back to active weapon
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon != INVALID_ENT_REFERENCE && iActiveWeapon != iWeapon)
		Properties_LoadWeaponPropInt(iClient, iActiveWeapon, sProp, iElement);
}

void Properties_LoadWeaponPropFloat(int iClient, int iWeapon, const char[] sProp, int iElement = 0)
{
	if (!g_mPropertiesWeaponSend[iWeapon])
		g_mPropertiesWeaponSend[iWeapon] = new StringMap();
	
	float flValue = 0.0;
	g_mPropertiesWeaponSend[iWeapon].GetValue(sProp, flValue);
	SetEntPropFloat(iClient, Prop_Send, sProp, flValue, iElement);
}

void Properties_SaveWeaponPropFloat(int iClient, int iWeapon, const char[] sProp, int iElement = 0)
{
	if (!g_mPropertiesWeaponSend[iWeapon])
		g_mPropertiesWeaponSend[iWeapon] = new StringMap();
	
	g_mPropertiesWeaponSend[iWeapon].SetValue(sProp, GetEntPropFloat(iClient, Prop_Send, sProp, iElement));
	
	//Revert back to active weapon
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon != INVALID_ENT_REFERENCE && iActiveWeapon != iWeapon)
		Properties_LoadWeaponPropFloat(iClient, iActiveWeapon, sProp, iElement);
}

// Load & Save Data Prop

void Properties_LoadWeaponDataInt(int iClient, int iWeapon, int iOffset)
{
	if (!g_mPropertiesWeaponSend[iWeapon])
		g_mPropertiesWeaponSend[iWeapon] = new StringMap();
	
	char sBuffer[16];
	IntToString(iOffset, sBuffer, sizeof(sBuffer));
	
	int iValue = 0;
	g_mPropertiesWeaponSend[iWeapon].GetValue(sBuffer, iValue);
	SetEntData(iClient, iOffset, iValue);
}

void Properties_SaveWeaponDataInt(int iClient, int iWeapon, int iOffset)
{
	if (!g_mPropertiesWeaponSend[iWeapon])
		g_mPropertiesWeaponSend[iWeapon] = new StringMap();
	
	char sBuffer[16];
	IntToString(iOffset, sBuffer, sizeof(sBuffer));
	g_mPropertiesWeaponSend[iWeapon].SetValue(sBuffer, GetEntData(iClient, iOffset));
	
	//Revert back to active weapon
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon != INVALID_ENT_REFERENCE && iActiveWeapon != iWeapon)
		Properties_LoadWeaponDataInt(iClient, iActiveWeapon, iOffset);
}

void Properties_LoadWeaponDataFloat(int iClient, int iWeapon, int iOffset)
{
	if (!g_mPropertiesWeaponSend[iWeapon])
		g_mPropertiesWeaponSend[iWeapon] = new StringMap();
	
	char sBuffer[16];
	IntToString(iOffset, sBuffer, sizeof(sBuffer));
	
	float flValue = 0.0;
	g_mPropertiesWeaponSend[iWeapon].GetValue(sBuffer, flValue);
	SetEntDataFloat(iClient, iOffset, flValue);
}

void Properties_SaveWeaponDataFloat(int iClient, int iWeapon, int iOffset)
{
	if (!g_mPropertiesWeaponSend[iWeapon])
		g_mPropertiesWeaponSend[iWeapon] = new StringMap();
	
	char sBuffer[16];
	IntToString(iOffset, sBuffer, sizeof(sBuffer));
	g_mPropertiesWeaponSend[iWeapon].SetValue(sBuffer, GetEntDataFloat(iClient, iOffset));
	
	//Revert back to active weapon
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon != INVALID_ENT_REFERENCE && iActiveWeapon != iWeapon)
		Properties_LoadWeaponDataFloat(iClient, iActiveWeapon, iOffset);
}

// Other

int Properties_GetWeaponPropInt(int iWeapon, const char[] sProp)
{
	if (!g_mPropertiesWeaponSend[iWeapon])
		return 0;
	
	int iValue = 0;
	g_mPropertiesWeaponSend[iWeapon].GetValue(sProp, iValue);
	return iValue;
}

void Properties_SetWeaponPropInt(int iWeapon, const char[] sProp, int iValue)
{
	if (!g_mPropertiesWeaponSend[iWeapon])
		g_mPropertiesWeaponSend[iWeapon] = new StringMap();
	
	g_mPropertiesWeaponSend[iWeapon].SetValue(sProp, iValue);
}

void Properties_AddWeaponPropInt(int iWeapon, const char[] sProp, int iValue)
{
	if (!g_mPropertiesWeaponSend[iWeapon])
		g_mPropertiesWeaponSend[iWeapon] = new StringMap();
	
	int iAdd = 0;
	g_mPropertiesWeaponSend[iWeapon].GetValue(sProp, iAdd);
	g_mPropertiesWeaponSend[iWeapon].SetValue(sProp, iAdd + iValue);
}

float Properties_GetWeaponPropFloat(int iWeapon, const char[] sProp)
{
	if (!g_mPropertiesWeaponSend[iWeapon])
		return 0.0;
	
	float flValue = 0.0;
	g_mPropertiesWeaponSend[iWeapon].GetValue(sProp, flValue);
	return flValue;
}

void Properties_SetWeaponPropFloat(int iWeapon, const char[] sProp, float flValue)
{
	if (!g_mPropertiesWeaponSend[iWeapon])
		g_mPropertiesWeaponSend[iWeapon] = new StringMap();
	
	g_mPropertiesWeaponSend[iWeapon].SetValue(sProp, flValue);
}

void Properties_RemoveWeapon(int iWeapon)
{
	delete g_mPropertiesWeaponSend[iWeapon];
	delete g_mPropertiesWeaponData[iWeapon];
}

// Ammos

void Properties_SaveActiveWeaponAmmo(int iClient)
{
	if (g_iPropertiesForceWeaponAmmo != INVALID_ENT_REFERENCE)
		ThrowError("Properties_SaveActiveWeaponAmmo called unexpected when g_iPropertiesForceWeaponAmmo '%d' is active", g_iPropertiesForceWeaponAmmo);
	
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon == INVALID_ENT_REFERENCE)
		return;
	
	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if (iAmmoType == -1 || iAmmoType == TF_AMMO_METAL)
		return;
	
	Properties_SaveWeaponPropInt(iClient, iWeapon, "m_iAmmo", iAmmoType);
}

void Properties_UpdateActiveWeaponAmmo(int iClient)
{
	//Update ammo to use active weapon and any other weapons that doesn't use same ammotype
	int iMaxWeapons = GetMaxWeapons();
	int[] iWeapons = new int[iMaxWeapons];
	int iAmmoTypeWeapon[TF_AMMO_COUNT];
	
	for (int i = 0; i < iMaxWeapons; i++)
	{
		iWeapons[i] = GetEntPropEnt(iClient, Prop_Send, "m_hMyWeapons", i);
		if (iWeapons[i] == INVALID_ENT_REFERENCE)
			continue;
		
		int iAmmoType = GetEntProp(iWeapons[i], Prop_Send, "m_iPrimaryAmmoType");
		if (iAmmoType == -1 || iAmmoType == TF_AMMO_METAL)
			continue;
		
		if (!iAmmoTypeWeapon[iAmmoType])	//Ammotype not used yet
			iAmmoTypeWeapon[iAmmoType] = iWeapons[i];
		else if (iAmmoTypeWeapon[iAmmoType])	//More than 1 weapon use same ammotype, forget it
			iAmmoTypeWeapon[iAmmoType] = INVALID_ENT_REFERENCE;
	}
	
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon != INVALID_ENT_REFERENCE)
	{
		int iAmmoType = GetEntProp(iActiveWeapon, Prop_Send, "m_iPrimaryAmmoType");
		if (iAmmoType != -1 && iAmmoType != TF_AMMO_METAL)
			iAmmoTypeWeapon[iAmmoType] = iActiveWeapon;
	}
	
	for (int iAmmoType = 0; iAmmoType < TF_AMMO_COUNT; iAmmoType++)
		if (iAmmoTypeWeapon[iAmmoType] > 0)
			Properties_LoadWeaponPropInt(iClient, iAmmoTypeWeapon[iAmmoType], "m_iAmmo", iAmmoType);
}

void Properties_SetForceWeaponAmmo(int iWeapon)
{
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity");
	Properties_SaveActiveWeaponAmmo(iClient);
	
	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	Properties_LoadWeaponPropInt(iClient, iWeapon, "m_iAmmo", iAmmoType);
	
	g_iPropertiesForceWeaponAmmo = iWeapon;
}

void Properties_ResetForceWeaponAmmo()
{
	if (g_iPropertiesForceWeaponAmmo != INVALID_ENT_REFERENCE)
		Properties_UpdateActiveWeaponAmmo(GetEntPropEnt(g_iPropertiesForceWeaponAmmo, Prop_Send, "m_hOwnerEntity"));
	
	g_iPropertiesForceWeaponAmmo = INVALID_ENT_REFERENCE;
}

int Properties_GetForceWeaponAmmo()
{
	return g_iPropertiesForceWeaponAmmo;
}

//Next several functions work together to effectively seperate m_flRageMeter between weapons
//Whenever it matters, we change the players m_flRageMeter and m_bRageDraining to whatever it should be for the weapon's class

void Properties_LoadRageProps(int iClient, int iWeapon)
{
	int iOffset = FindSendPropInfo("CTFPlayer", "m_flNextRageEarnTime");
	
	Properties_LoadWeaponPropFloat(iClient, iWeapon, "m_flRageMeter");
	Properties_LoadWeaponPropInt(iClient, iWeapon, "m_bRageDraining");
	Properties_LoadWeaponDataInt(iClient, iWeapon, iOffset + 4);	//RageBuff.m_iBuffTypeActive
	Properties_LoadWeaponDataInt(iClient, iWeapon, iOffset + 8);	//RageBuff.m_iBuffPulseCount
	Properties_LoadWeaponDataFloat(iClient, iWeapon, iOffset + 12);	//RageBuff.m_flNextBuffPulseTime
}

void Properties_SaveRageProps(int iClient, int iWeapon)
{
	int iOffset = FindSendPropInfo("CTFPlayer", "m_flNextRageEarnTime");
	
	Properties_SaveWeaponPropFloat(iClient, iWeapon, "m_flRageMeter");
	Properties_SaveWeaponPropInt(iClient, iWeapon, "m_bRageDraining");
	Properties_SaveWeaponDataInt(iClient, iWeapon, iOffset + 4);	//RageBuff.m_iBuffTypeActive
	Properties_SaveWeaponDataInt(iClient, iWeapon, iOffset + 8);	//RageBuff.m_iBuffPulseCount
	Properties_SaveWeaponDataFloat(iClient, iWeapon, iOffset + 12);	//RageBuff.m_flNextBuffPulseTime
}

// Item charge meter

void Properties_AddWeaponChargeMeter(int iClient, int iWeapon, float flValue)
{
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon != INVALID_ENT_REFERENCE)
		Properties_SaveWeaponPropFloat(iClient, iActiveWeapon, "m_flItemChargeMeter", TF2_GetSlot(iActiveWeapon));
	
	float flCurrent = Properties_GetWeaponPropFloat(iWeapon, "m_flItemChargeMeter");
	if (flCurrent < 100.0 && flCurrent + flValue >= 100.0)
	{
		Properties_SetWeaponPropFloat(iWeapon, "m_flItemChargeMeter", 100.0);
		
		if (HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType"))
		{
			int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
			if (TF_AMMO_GRENADES1 <= iAmmoType <= TF_AMMO_GRENADES3)
			{
				int iAdd = TF2_GiveAmmo(iClient, iWeapon, Properties_GetWeaponPropInt(iWeapon, "m_iAmmo"), 1, iAmmoType, true, kAmmoSource_Pickup);
				
				Properties_SaveActiveWeaponAmmo(iClient);
				Properties_AddWeaponPropInt(iWeapon, "m_iAmmo", iAdd);
				Properties_UpdateActiveWeaponAmmo(iClient);
			}
		}
		
		if (IsClassname(iWeapon, "tf_wearable_razorback"))
			SetEntProp(iWeapon, Prop_Send, "m_fEffects", GetEntProp(iWeapon, Prop_Send, "m_fEffects") & ~EF_NODRAW);
	}
	else if (flCurrent < 100.0)
	{
		Properties_SetWeaponPropFloat(iWeapon, "m_flItemChargeMeter", flCurrent + flValue);
	}
	
	if (iWeapon == iActiveWeapon)
		Properties_LoadWeaponPropFloat(iClient, iWeapon, "m_flItemChargeMeter", TF2_GetSlot(iActiveWeapon));
}