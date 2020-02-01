#define CONFIG_FILEPATH "configs/randomizer.cfg"
#define CONFIG_MAXCHAR	256

ArrayList g_aBlacklistAttrib;
ArrayList g_aBlacklistClassname;
ArrayList g_aBlacklistName;
ArrayList g_aBlacklistIndex;
ArrayList g_aWeaponAttack2;

StringMap g_mHudWeapon;
StringMap g_mHudEntity;
StringMap g_mHudType;

public void Config_Init()
{
	g_aBlacklistAttrib = new ArrayList();
	g_aBlacklistName = new ArrayList(CONFIG_MAXCHAR);
	g_aBlacklistClassname = new ArrayList(CONFIG_MAXCHAR);
	g_aBlacklistIndex = new ArrayList();
	g_aWeaponAttack2 = new ArrayList(CONFIG_MAXCHAR);
	
	g_aHud = new ArrayList();
	
	g_mHudWeapon = new StringMap();
	g_mHudWeapon.SetValue("classname", eHudWeapon_Classname);
	g_mHudWeapon.SetValue("attrib", eHudWeapon_Attrib);
	g_mHudWeapon.SetValue("index", eHudWeapon_Index);
	
	g_mHudEntity = new StringMap();
	g_mHudEntity.SetValue("weapon", eHudEntity_Weapon);
	g_mHudEntity.SetValue("client", eHudEntity_Client);
	
	g_mHudType = new StringMap();
	g_mHudType.SetValue("int", eHudType_Int);
	g_mHudType.SetValue("float", eHudType_Float);
	g_mHudType.SetValue("time", eHudType_Time);
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
	
	g_aBlacklistAttrib.Clear();
	g_aBlacklistClassname.Clear();
	g_aBlacklistName.Clear();
	g_aBlacklistIndex.Clear();
	
	g_aHud.Clear();
	
	if (kv.JumpToKey("blacklist", false))
	{
		Config_LoadList(kv, "attrib", g_aBlacklistAttrib);
		Config_LoadList(kv, "classname", g_aBlacklistClassname, true);
		Config_LoadList(kv, "name", g_aBlacklistName, true);
		Config_LoadList(kv, "index", g_aBlacklistIndex);
		
		kv.GoBack();
	}
	
	Config_LoadList(kv, "attack2", g_aWeaponAttack2, true);
	
	if (kv.JumpToKey("hud", false))
	{
		if (kv.GotoFirstSubKey(false))	//netprop name
		{
			do
			{
				CHud hud = new CHud();
				char sNetprop[CONFIG_MAXCHAR];
				kv.GetSectionName(sNetprop, sizeof(sNetprop));
				hud.SetString("netprop", sNetprop);
				
				if (kv.GotoFirstSubKey(false))
				{
					do
					{
						char sBuffer[CONFIG_MAXCHAR];
						kv.GetSectionName(sBuffer, sizeof(sBuffer));
						
						if (StrEqual(sBuffer, "weapon"))
						{
							//If weapon, collect all and push into one
							char sWeapon[1024];
							if (kv.GotoFirstSubKey(false))
							{
								do
								{
									char sName[CONFIG_MAXCHAR], sValue[CONFIG_MAXCHAR];
									kv.GetSectionName(sName, sizeof(sName));
									StringToLower(sName);
									kv.GetString(NULL_STRING, sValue, sizeof(sValue), "");
									
									eHudWeapon hudWeapon;
									if (!g_mHudWeapon.GetValue(sName, hudWeapon))
									{
										LogMessage("[randomizer] Invalid Hud weapon at \"%s\" - \"%s\"", sNetprop, sName);
									}
									else
									{
										if (sWeapon[0] != '\0')
											Format(sWeapon, sizeof(sWeapon), "%s ; ", sWeapon);
										
										Format(sWeapon, sizeof(sWeapon), "%s%d ; %s", sWeapon, hudWeapon, sValue);
									}
								}
								while (kv.GotoNextKey(false));
								
								kv.GoBack();
							}
							
							hud.SetString("weapon", sWeapon);
						}
						else if (StrEqual(sBuffer, "text") && kv.GotoFirstSubKey(false))
						{
							//If text, and have more than 1 value, create another StringMap to store into instead
							StringMap mText = new StringMap();
							do
							{
								char sName[CONFIG_MAXCHAR], sValue[CONFIG_MAXCHAR];
								kv.GetSectionName(sName, sizeof(sName));
								kv.GetString(NULL_STRING, sValue, sizeof(sValue), "");
								mText.SetString(sName, sValue);
							}
							while (kv.GotoNextKey(false));
							
							hud.SetValue("text", mText);
							
							kv.GoBack();
						}
						else
						{
							char sValue[CONFIG_MAXCHAR];
							kv.GetString(NULL_STRING, sValue, sizeof(sValue), "");
							
							if (StrEqual(sBuffer, "entity"))
							{
								//If entity, convert string to enum from StringMap
								eHudEntity hudEntity;
								if (!g_mHudEntity.GetValue(sValue, hudEntity))
									LogMessage("[randomizer] Invalid Hud entity at \"%s\" - \"%s\"", sNetprop, sValue);
								else
									hud.SetValue("entity", hudEntity);
							}
							else if (StrEqual(sBuffer, "type"))
							{
								//If type, convert string to enum from StringMap
								eHudType hudType;
								if (!g_mHudType.GetValue(sValue, hudType))
									LogMessage("[randomizer] Invalid Hud type at \"%s\" - \"%s\"", sNetprop, sValue);
								else
									hud.SetValue("type", hudType);
							}
							else
							{
								//If none of above, store as string as normal
								hud.SetString(sBuffer, sValue);
							}
						}
					}
					while (kv.GotoNextKey(false));
				}
				
				//Push all of the StringMap stuffs into ArrayList
				g_aHud.Push(hud);
				
				kv.GoBack();
			}
			while (kv.GotoNextKey(false));
		}
		kv.GoBack();
	}

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