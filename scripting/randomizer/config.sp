#define CONFIG_FILEPATH "configs/randomizer.cfg"
#define CONFIG_MAXCHAR	256

ArrayList g_aBlacklistAttrib;
ArrayList g_aBlacklistName;
ArrayList g_aBlacklistIndex;

public void Config_InitTemplates()
{
	g_aBlacklistAttrib = new ArrayList();
	g_aBlacklistName = new ArrayList(CONFIG_MAXCHAR);
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
	g_aBlacklistName.Clear();
	g_aBlacklistIndex.Clear();
	
	if (kv.JumpToKey("blacklist", false))
	{
		if (kv.JumpToKey("attrib", false))
		{
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					char sBuffer[CONFIG_MAXCHAR];
					kv.GetSectionName(sBuffer, sizeof(sBuffer));
					g_aBlacklistAttrib.Push(StringToInt(sBuffer));
				}
				while (kv.GotoNextKey(false));
			}
			kv.GoBack();
		}
		kv.GoBack();
		
		if (kv.JumpToKey("name", false))
		{
			if (kv.GotoFirstSubKey(false))
			{
				do
				{
					char sBuffer[CONFIG_MAXCHAR];
					kv.GetSectionName(sBuffer, sizeof(sBuffer));
					g_aBlacklistName.PushString(sBuffer);
				}
				while (kv.GotoNextKey(false));
			}
			kv.GoBack();
		}
		kv.GoBack();
	}

	delete kv;
}