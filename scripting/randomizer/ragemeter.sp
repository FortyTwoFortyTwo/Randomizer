static float g_flRageMeter[TF_MAXPLAYERS+1][CLASS_MAX+1];
static bool g_bRageDraining[TF_MAXPLAYERS+1][CLASS_MAX+1];

//Next several functions work together to effectively seperate m_flRageMeter between weapons
//Whenever it matters, we change the players m_flRageMeter and m_bRageDraining to whatever it should be for the weapon's class

void Rage_LoadRageProps(int iClient, TFClassType nClass)
{
	int iClass = view_as<int>(nClass);
	float flRageMeter = g_flRageMeter[iClient][iClass];
	bool bRageDraining = g_bRageDraining[iClient][iClass];
 
	SetEntPropFloat(iClient, Prop_Send, "m_flRageMeter", flRageMeter);
	SetEntProp(iClient, Prop_Send, "m_bRageDraining", view_as<int>(bRageDraining));
}

void Rage_SaveRageProps(int iClient, TFClassType nClass)
{
	int iClass = view_as<int>(nClass);
	float flRageMeter = GetEntPropFloat(iClient, Prop_Send, "m_flRageMeter");
	bool bRageDraining = !!GetEntProp(iClient, Prop_Send, "m_bRageDraining");
	
	g_flRageMeter[iClient][iClass] = flRageMeter;
	g_bRageDraining[iClient][iClass] = bRageDraining;
	
	//Revert back to the props for the current weapon's class, to allow activating rage
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon > MaxClients)
		Rage_LoadRageProps(iClient, TF2_GetDefaultClassFromItem(iWeapon));
	
}

//Rage type is determined by the "mod soldier buff type" attribute on the player
//That takes into account each weapon equipped, resulting in the sum not being the correct rage type
//This returns the sum of the attribute on each weapon, so that we can correct it ourselves

float Rage_GetBuffTypeAttribute(int iClient)
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

float Rage_GetClassMeter(int iClient, TFClassType nClass)
{
	return g_flRageMeter[iClient][nClass];
}