#define FILEPATH_CONFIG_CONTROLS "configs/randomizer/controls.cfg"
#define CONFIG_MAXCHAR	64

StringMap g_mWeaponAttack2;
StringMap g_mWeaponPassive;

public void Controls_Init()
{
	g_mWeaponAttack2 = new StringMap();
	g_mWeaponPassive = new StringMap();
}

public void Controls_Refresh()
{
	KeyValues kv = LoadConfig(FILEPATH_CONFIG_CONTROLS, "Controls");
	if (!kv)
		return;
	
	Controls_LoadList(kv, "attack2", g_mWeaponAttack2);
	Controls_LoadList(kv, "passive", g_mWeaponPassive);
	
	delete kv;
}

void Controls_LoadList(KeyValues kv, char[] sSection, StringMap mMap)
{
	mMap.Clear();
	
	if (kv.JumpToKey(sSection, false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				char sName[CONFIG_MAXCHAR], sValue[CONFIG_MAXCHAR];
				kv.GetSectionName(sName, sizeof(sName));
				kv.GetString(NULL_STRING, sValue, sizeof(sValue));
				
				mMap.SetString(sName, sValue);
			}
			while (kv.GotoNextKey(false));
		}
		kv.GoBack();
	}
	kv.GoBack();
}

bool Controls_IsUsingAttack2(int iWeapon)
{
	char sClassname[CONFIG_MAXCHAR];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	
	char sBuffer[1];
	return g_mWeaponAttack2.GetString(sClassname, sBuffer, sizeof(sBuffer));
}

bool Controls_IsPassive(int iWeapon)
{
	char sClassname[CONFIG_MAXCHAR];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	
	char sBuffer[1];
	return g_mWeaponPassive.GetString(sClassname, sBuffer, sizeof(sBuffer));
}

bool Controls_GetPassiveDisplay(int iWeapon, char[] sBuffer, int iLength)
{
	char sClassname[CONFIG_MAXCHAR];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	
	return g_mWeaponPassive.GetString(sClassname, sBuffer, iLength);
}