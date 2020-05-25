static StringMap g_mDefaultAmmoType;
static int g_iGiveAmmoSlot = -1;

void Ammo_Init()
{
	g_mDefaultAmmoType = new StringMap();
}

void Ammo_OnWeaponSpawned(int iWeapon)
{
	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if (iAmmoType != TF_AMMO_GRENADES1 && iAmmoType != TF_AMMO_GRENADES2)
		return;
	
	//Its possible that client can have 2 weapons with same ammotype (TF_AMMO_GRENADES).
	// To prevent this, secondary weapons always use TF_AMMO_GRENADES2 slot, and melee
	// weapon at TF_AMMO_GRENADES1
	int iNewAmmoType = TF_AMMO_DUMMY;
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
	
	if (iNewAmmoType == TF_AMMO_DUMMY || iAmmoType == iNewAmmoType)
		return;
	
	//Store old ammotype using classname
	char sClassname[256];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	g_mDefaultAmmoType.SetValue(sClassname, iAmmoType);
	
	//Set new ammotype location to weapon
	SetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType", iNewAmmoType);
}

bool Ammo_GetDefaultType(int iClient, int &iAmmoType, TFClassType &nClass = TFClass_Unknown)
{
	if (g_iGiveAmmoSlot >= WeaponSlot_Primary)
	{
		int iWeapon = GetPlayerWeaponSlot(iClient, g_iGiveAmmoSlot);
		if (iWeapon > MaxClients)
		{
			Ammo_GetDefaultTypeFromWeapon(iClient, iWeapon, iAmmoType, nClass);
			return true;
		}
		
		return false;
	}
	
	int iWeapon = TF2_GetItemFromAmmoType(iClient, iAmmoType);
	if (iWeapon > MaxClients)
	{
		Ammo_GetDefaultTypeFromWeapon(iClient, iWeapon, iAmmoType, nClass);
		return true;
	}
	
	return false;
}

void Ammo_GetDefaultTypeFromWeapon(int iClient, int iWeapon, int &iAmmoType, TFClassType &nClass = TFClass_Unknown)
{
	char sClassname[256];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	g_mDefaultAmmoType.GetValue(sClassname, iAmmoType);
	
	//Get new ammotype and default class
	nClass = TF2_GetDefaultClassFromItem(iClient, iWeapon);
}

void Ammo_SetGiveAmmoSlot(int iSlot)
{
	g_iGiveAmmoSlot = iSlot;
}

int Ammo_GetGiveAmmoSlot()
{
	return g_iGiveAmmoSlot;
}