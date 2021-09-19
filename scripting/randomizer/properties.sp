static StringMap g_mPropertiesWeaponSend[2048];
static StringMap g_mPropertiesWeaponData[2048];

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

bool Properties_HasWeaponProp(int iWeapon, const char[] sProp)
{
	if (!g_mPropertiesWeaponSend[iWeapon])
		return false;
	
	any value;
	return g_mPropertiesWeaponSend[iWeapon].GetValue(sProp, value);
}

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

void Properties_RemoveWeapon(int iWeapon)
{
	delete g_mPropertiesWeaponSend[iWeapon];
	delete g_mPropertiesWeaponData[iWeapon];
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

float Properties_GetBuffTypeAttribute(int iClient)
{
	float flTotal;
	int iWeapon;
	int iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		float flVal;
		TF2_WeaponFindAttribute(iWeapon, "mod soldier buff type", flVal);
		flTotal += flVal;
	}
	
	return flTotal;
}