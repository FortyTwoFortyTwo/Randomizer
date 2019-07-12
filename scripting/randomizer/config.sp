#define CONFIG_FILEPATH "configs/randomizer.cfg"
#define CONFIG_MAXCHAR	256

ArrayList g_aBlacklistAttrib;
ArrayList g_aBlacklistClassname;
ArrayList g_aBlacklistName;
ArrayList g_aBlacklistIndex;

public void Config_InitTemplates()
{
	g_aBlacklistAttrib = new ArrayList();
	g_aBlacklistName = new ArrayList(CONFIG_MAXCHAR);
	g_aBlacklistClassname = new ArrayList(CONFIG_MAXCHAR);
	g_aBlacklistIndex = new ArrayList();
}

public void Config_LoadTemplates()
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
	
	if (kv.JumpToKey("blacklist", false))
	{
		Config_LoadList(kv, "attrib", g_aBlacklistAttrib);
		Config_LoadList(kv, "classname", g_aBlacklistClassname, true);
		Config_LoadList(kv, "name", g_aBlacklistName, true);
		Config_LoadList(kv, "index", g_aBlacklistIndex);
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