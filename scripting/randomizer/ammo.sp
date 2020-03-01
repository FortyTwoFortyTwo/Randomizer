static StringMap g_mDefaultAmmoType;

void Ammo_Init()
{
	g_mDefaultAmmoType = new StringMap();
}

public Action Ammo_OnEntitySpawned(int iWeapon)
{
	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if (iAmmoType != TF_AMMO_GRENADES1 && iAmmoType != TF_AMMO_GRENADES2)
		return;
	
	//Its possible that client can have 2 weapons with same ammotype (TF_AMMO_GRENADES).
	// To prevent this, secondary weapons always use TF_AMMO_GRENADES2 slot, and melee
	// weapon at TF_AMMO_GRENADES1
	int iNewAmmoType;
	int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
	
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
	{
		int iSlot = TF2_GetSlotFromIndex(iIndex, view_as<TFClassType>(iClass));
		if (iSlot == WeaponSlot_Secondary)
		{
			iNewAmmoType = TF_AMMO_GRENADES2;
			break;
		}
		else if (iSlot == WeaponSlot_Melee)
		{
			iNewAmmoType = TF_AMMO_GRENADES1;
			break;
		}
	}
	
	if (iAmmoType != TF_AMMO_GRENADES1 && iAmmoType != TF_AMMO_GRENADES2)
		return;
	
	//Store old ammotype using classname
	char sClassname[256];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	g_mDefaultAmmoType.SetValue(sClassname, iAmmoType);
	
	//Set new ammotype location to weapon
	SetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType", iNewAmmoType);
}

bool Ammo_GetDefaultType(int iClient, int &iAmmoType, TFClassType &nClass)
{
	if (iAmmoType == TF_AMMO_METAL)
	{
		//Metal works differently, engineer have max metal 200 while others have 100
		nClass = TFClass_Engineer;
		return true;
	}
	
	int iWeapon = TF2_GetItemFromAmmoType(iClient, iAmmoType);
	if (iWeapon <= MaxClients)
		return false;
	
	//Check if weapon uses moved ammotype location, and use
	// old location for GetMaxAmmo to get correct value
	char sClassname[256];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	g_mDefaultAmmoType.GetValue(sClassname, iAmmoType);
	
	//Get default class for GetMaxAmmo to get correct value
	nClass = TF2_GetDefaultClassFromItem(iClient, iWeapon);
	return true;
}