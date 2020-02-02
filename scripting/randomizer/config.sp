#define CONFIG_FILEPATH "configs/randomizer.cfg"
#define CONFIG_MAXCHAR	256

ArrayList g_aWeaponAttack2;

public void Config_Init()
{
	g_aWeaponAttack2 = new ArrayList(CONFIG_MAXCHAR);
}

public void Config_Refresh()
{
	char sConfigPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigPath, sizeof(sConfigPath), CONFIG_FILEPATH);
	if(!FileExists(sConfigPath))
	{
		LogMessage("Failed to load Randomizer config file (file missing): %s!", CONFIG_FILEPATH);
		return;
	}
	
	KeyValues kv = new KeyValues("Randomizer");
	kv.SetEscapeSequences(true);

	if(!kv.ImportFromFile(sConfigPath))
	{
		LogMessage("Failed to parse Randomizer config file: %s!", CONFIG_FILEPATH);
		delete kv;
		return;
	}
	
	Config_LoadList(kv, "attack2", g_aWeaponAttack2, true);
	
	delete kv;
}

void Config_LoadList(KeyValues kv, char[] sSection, ArrayList aArray, bool bString = false)
{
	if (kv.JumpToKey(sSection, false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				char sBuffer[CONFIG_MAXCHAR];
				kv.GetSectionName(sBuffer, sizeof(sBuffer));
				
				if (bString)
					aArray.PushString(sBuffer);
				else
					aArray.Push(StringToInt(sBuffer));
			}
			while (kv.GotoNextKey(false));
		}
		kv.GoBack();
	}
	kv.GoBack();
}

bool Config_IsUsingAttack2(int iWeapon)
{
	char sClassname[CONFIG_MAXCHAR];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	
	int iLength = g_aWeaponAttack2.Length;
	for (int i = 0; i < iLength; i++)
	{
		char sBuffer[CONFIG_MAXCHAR];
		g_aWeaponAttack2.GetString(i, sBuffer, sizeof(sBuffer));
		if (StrEqual(sClassname, sBuffer))
			return true;
	}
	
	return false;
}