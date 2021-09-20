#define FILEPATH_CONFIG_HUDS "configs/randomizer/huds.cfg"

enum HudEntity
{
	HudEntity_Client,
	HudEntity_Weapon,
}

enum HudType
{
	HudType_Int,
	HudType_Float,
	HudType_Time,
}

enum struct HudInfo
{
	WeaponWhitelist weaponWhitelist;	//Weapons that uses this netprop
	char sNetprop[32];	//Netprop to get value
	int iElement;		//If netprop is array, element postition to get
	HudEntity nEntity;	//Entity to target from netprop
	HudType nType;		//How is netprop value stored
	float flAdd;		//Add netprop value to display
	float flMultiply;	//Multiply netprop value to display
	bool bMin;			//Is there netprop min value?
	float flMin;		//Netprop min value inorder to display
	bool bMax;			//Is there netprop max value?
	float flMax;		//Netprop max value inorder to display
	char sText[64];		//Text to display next to value
	StringMap mText;	//If not null, use this instead of sText to get text depending on netprop value
	
	int GetEntity(int iClient, int iWeapon)
	{
		switch (this.nEntity)
		{
			case HudEntity_Client: return iClient;
			case HudEntity_Weapon: return iWeapon;
			default: return -1;
		}
	}
	
	bool CalculateIntValue(int &iVal)
	{
		iVal = RoundToNearest(float(iVal) * this.flMultiply);
		iVal += RoundToNearest(this.flAdd);
		
		if (this.bMin && float(iVal) <= this.flMin)
			return false;
		
		if (this.bMax && float(iVal) >= this.flMax)
			return false;
		
		return true;
	}
	
	bool CalculateFloatValue(float &flVal)
	{
		flVal *= this.flMultiply;
		flVal += this.flAdd;
		
		if (this.bMin && flVal <= this.flMin)
			return false;
		
		if (this.bMax && flVal >= this.flMax)
			return false;
		
		return true;
	}
	
	bool GetDynamicText(int iVal, char[] sBuffer, int iLength)
	{
		if (!this.mText)
			return false;
		
		char sVal[16];
		IntToString(iVal, sVal, sizeof(sVal));
		return this.mText.GetString(sVal, sBuffer, iLength);
	}
}

enum struct HudWeapon
{
	int iRef;					//Weapon ref
	char sName[64];				//Translated name of weapon to display
	ArrayList aHudInfo;			//Arrays of HudInfo to display
	
	bool GetText(int iClient, char[] sDisplay, int iLength)
	{
		int iWeapon = EntRefToEntIndex(this.iRef);
		if (iWeapon == INVALID_ENT_REFERENCE)
			return false;
		
		strcopy(sDisplay, iLength, this.sName);
		
		//Go through every netprops to display
		if (this.aHudInfo)
		{
			int iHudLength = this.aHudInfo.Length;
			for (int j = 0; j < iHudLength; j++)
			{
				HudInfo hudInfo;
				this.aHudInfo.GetArray(j, hudInfo);
				int iEntity = hudInfo.GetEntity(iClient, iWeapon);
				
				float flVal;
				
				switch (hudInfo.nType)
				{
					case HudType_Int:
					{
						int iVal;
						if (hudInfo.nEntity == HudEntity_Client && Properties_HasWeaponProp(iWeapon, hudInfo.sNetprop))
							iVal = Properties_GetWeaponPropInt(iWeapon, hudInfo.sNetprop);
						else
							iVal = GetEntProp(iEntity, Prop_Send, hudInfo.sNetprop, _, hudInfo.iElement);
						
						if (hudInfo.CalculateIntValue(iVal))
						{
							char sText[64];
							if (hudInfo.GetDynamicText(iVal, sText, sizeof(sText)))
								Format(sDisplay, iLength, "%s: %T", sDisplay, sText, iClient);
							else
								Format(sDisplay, iLength, "%s: %T", sDisplay, hudInfo.sText, iClient, iVal);
						}
						
						continue;	//Don't do float stuff below
					}
					case HudType_Float:
					{
						if (hudInfo.nEntity == HudEntity_Client && Properties_HasWeaponProp(iWeapon, hudInfo.sNetprop))
							flVal = Properties_GetWeaponPropFloat(iWeapon, hudInfo.sNetprop);
						else
							flVal = GetEntPropFloat(iEntity, Prop_Send, hudInfo.sNetprop, hudInfo.iElement);
					}
					case HudType_Time:
					{
						if (hudInfo.nEntity == HudEntity_Client && Properties_HasWeaponProp(iWeapon, hudInfo.sNetprop))
							flVal = Properties_GetWeaponPropFloat(iWeapon, hudInfo.sNetprop) - GetGameTime();
						else
							flVal = GetEntPropFloat(iEntity, Prop_Send, hudInfo.sNetprop, hudInfo.iElement) - GetGameTime();
					}
				}
				
				if (hudInfo.CalculateFloatValue(flVal))
					Format(sDisplay, iLength, "%s: %T", sDisplay, hudInfo.sText, iClient, flVal);
			}
			
			char sBuffer[64];
			if (Controls_GetPassiveInfo(iClient, iWeapon, sBuffer, sizeof(sBuffer)))
				Format(sDisplay, iLength, "%s (%s)", sDisplay, sBuffer);
		}
		
		return true;
	}
}

static ArrayList g_aHuds;	//Arrays of HudInfo
static ArrayList g_aHudWeapon[TF_MAXPLAYERS];	//Arrays of HudWeapon

void Huds_Init()
{
	g_aHuds = new ArrayList(sizeof(HudInfo));
	
	for (int iClient = 0; iClient < sizeof(g_aHudWeapon); iClient++)
		g_aHudWeapon[iClient] = new ArrayList(sizeof(HudWeapon));
}

void Huds_Refresh()
{
	KeyValues kv = LoadConfig(FILEPATH_CONFIG_HUDS, "Huds");
	if (!kv)
		return;
	
	//Clear handles
	int iLength = g_aHuds.Length;
	for (int i = 0; i < iLength; i++)
	{
		HudInfo hudInfo;
		g_aHuds.GetArray(i, hudInfo);
		hudInfo.weaponWhitelist.Delete();
		delete hudInfo.mText;
	}
	
	g_aHuds.Clear();
	
	if (kv.GotoFirstSubKey(false))	//netprop name
	{
		do
		{
			char sBuffer[256];
			HudInfo hudInfo;
			kv.GetSectionName(hudInfo.sNetprop, sizeof(hudInfo.sNetprop));
			hudInfo.iElement = kv.GetNum("element", 0);
			hudInfo.flAdd = kv.GetFloat("add", 0.0);
			hudInfo.flMultiply = kv.GetFloat("multiply", 1.0);
			
			kv.GetString("entity", sBuffer, sizeof(sBuffer));
			if (StrEqual(sBuffer, "client"))
			{
				hudInfo.nEntity = HudEntity_Client;
			}
			else if (StrEqual(sBuffer, "weapon"))
			{
				hudInfo.nEntity = HudEntity_Weapon;
			}
			else
			{
				LogError("Invalid entity type at %s: %s", hudInfo.sNetprop, sBuffer);
				continue;
			}
			
			kv.GetString("type", sBuffer, sizeof(sBuffer));
			if (StrEqual(sBuffer, "int"))
			{
				hudInfo.nType = HudType_Int;
			}
			else if (StrEqual(sBuffer, "float"))
			{
				hudInfo.nType = HudType_Float;
			}
			else if (StrEqual(sBuffer, "time"))
			{
				hudInfo.nType = HudType_Time;
			}
			else
			{
				LogError("Invalid value type at %s: %s", hudInfo.sNetprop, sBuffer);
				continue;
			}
			
			kv.GetString("min", sBuffer, sizeof(sBuffer), "");
			if (sBuffer[0] != '\0')
			{
				hudInfo.bMin = true;
				hudInfo.flMin = StringToFloat(sBuffer);
			}
			
			kv.GetString("max", sBuffer, sizeof(sBuffer), "");
			if (sBuffer[0] != '\0')
			{
				hudInfo.bMax = true;
				hudInfo.flMax = StringToFloat(sBuffer);
			}
			
			if (kv.JumpToKey("text", false))
			{
				if (kv.GotoFirstSubKey(false))
				{
					hudInfo.mText = new StringMap();
					
					do
					{
						char sValue[CONFIG_MAXCHAR], sText[CONFIG_MAXCHAR];
						kv.GetSectionName(sValue, sizeof(sValue));
						kv.GetString(NULL_STRING, sText, sizeof(sText));
						hudInfo.mText.SetString(sValue, sText);
					}
					while (kv.GotoNextKey(false));
					kv.GoBack();
				}
				else
				{
					kv.GetString(NULL_STRING, hudInfo.sText, sizeof(hudInfo.sText));
				}
				
				kv.GoBack();
			}
			
			hudInfo.weaponWhitelist.Load(kv, "weapon");
			
			//Push all of the stuffs to ArrayList
			g_aHuds.PushArray(hudInfo);
		}
		while (kv.GotoNextKey(false));
		kv.GoBack();
	}
}

void Huds_RefreshClient(int iClient)
{
	int iLength = g_aHudWeapon[iClient].Length;
	for (int i = 0; i < iLength; i++)
		delete view_as<ArrayList>(g_aHudWeapon[iClient].Get(i, HudWeapon::aHudInfo));
	
	g_aHudWeapon[iClient].Clear();
	
	if (g_cvHuds.IntValue == HudMode_None)	//ConVar dont want us to do anything
		return;
	
	int iWeapon;
	int iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		if (TF2_GetSlot(iWeapon) >= WeaponSlot_Building)	//Ignore toolbox
			continue;
		
		HudWeapon hudWeapon;
		hudWeapon.iRef = EntIndexToEntRef(iWeapon);
		
		int iIndex = Weapons_GetReskinIndex(GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex"));
		if (!Weapons_GetName(iIndex, hudWeapon.sName, sizeof(hudWeapon.sName)))
			continue;	//This weapon is probably a special one and not from randomizer, ignore
		
		//Translate weapon name
		Format(hudWeapon.sName, sizeof(hudWeapon.sName), "%T", hudWeapon.sName, iClient);
		
		//Go through every HudInfo to see whenever which weapon can use
		int iHudLength = g_aHuds.Length;
		for (int i = 0; i < iHudLength; i++)
		{
			HudInfo hudInfo;
			g_aHuds.GetArray(i, hudInfo);
			
			int iEntity = hudInfo.GetEntity(iClient, iWeapon);
			if (!HasEntProp(iEntity, Prop_Send, hudInfo.sNetprop))
				continue;
			
			if (!hudInfo.weaponWhitelist.IsEmpty() && !hudInfo.weaponWhitelist.IsIndexAllowed(iIndex))
				continue;
			
			if (!hudWeapon.aHudInfo)
				hudWeapon.aHudInfo = new ArrayList(sizeof(HudInfo));
			
			hudWeapon.aHudInfo.PushArray(hudInfo);
		}
		
		g_aHudWeapon[iClient].PushArray(hudWeapon);
	}
	
	g_aHudWeapon[iClient].SortCustom(Huds_SortWeapons);
}

public int Huds_SortWeapons(int iPos1, int iPos2, Handle hMap, Handle hHandle)
{
	HudWeapon hudWeapon1, hudWeapon2;
	GetArrayArray(hMap, iPos1, hudWeapon1);	//Callback using legacy handle reeee
	GetArrayArray(hMap, iPos2, hudWeapon2);
	
	//Sort by slot position
	int iSlot1 = TF2_GetSlot(hudWeapon1.iRef);
	int iSlot2 = TF2_GetSlot(hudWeapon2.iRef);
	if (iSlot1 < iSlot2)
		return -1;
	else if (iSlot1 > iSlot2)
		return 1;
	
	//Sort by wearable
	bool bWearable1 = TF2_IsWearable(hudWeapon1.iRef);
	bool bWearable2 = TF2_IsWearable(hudWeapon2.iRef);
	if (!bWearable1 && bWearable2)
		return -1;
	else if (bWearable1 && !bWearable2)
		return 1;
	
	if (!bWearable1 && !bWearable2)
	{
		//If both not wearable, sort by ammo type
		int iAmmoType1 = GetEntProp(hudWeapon1.iRef, Prop_Send, "m_iPrimaryAmmoType");
		int iAmmoType2 = GetEntProp(hudWeapon2.iRef, Prop_Send, "m_iPrimaryAmmoType");
		if (iAmmoType1 == -1 && iAmmoType2 != -1)
			return 1;
		else if (iAmmoType1 != -1 && iAmmoType2 == -1)
			return -1;
		else if (iAmmoType1 < iAmmoType2)
			return -1;
		else if (iAmmoType1 > iAmmoType2)
			return 1;
	}
	
	//Sort by def index
	int iIndex1 = Weapons_GetReskinIndex(GetEntProp(hudWeapon1.iRef, Prop_Send, "m_iItemDefinitionIndex"));
	int iIndex2 = Weapons_GetReskinIndex(GetEntProp(hudWeapon2.iRef, Prop_Send, "m_iItemDefinitionIndex"));
	if (iIndex1 < iIndex2)
		return -1;
	else if (iIndex1 > iIndex2)
		return 1;
	
	//Literally exact same weapon bro
	return hudWeapon1.iRef < hudWeapon2.iRef ? -1 : 1;
}

public Action Huds_ClientDisplayText(Handle hTimer, int iClient)
{
	if (g_hTimerClientHud[iClient] != hTimer)
		return Plugin_Stop;
	
	Huds_ClientDisplayMenu(iClient); //TODO remove me
	
	if (g_cvHuds.IntValue != HudMode_Text)
		return Plugin_Continue;
	
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon != INVALID_ENT_REFERENCE)
		iActiveWeapon = EntIndexToEntRef(iActiveWeapon);
	
	char sDisplay[512];
	
	int iLength = g_aHudWeapon[iClient].Length;
	for (int i = 0; i < iLength; i++)
	{
		HudWeapon hudWeapon;
		g_aHudWeapon[iClient].GetArray(i, hudWeapon);
		
		char sBuffer[256];
		if (!hudWeapon.GetText(iClient, sBuffer, sizeof(sBuffer)))
			continue;
		
		if (iActiveWeapon == hudWeapon.iRef)
			Format(sBuffer, sizeof(sBuffer), "> %s", sBuffer);
		
		if (sDisplay[0])
			Format(sDisplay, sizeof(sDisplay), "%s\n%s", sDisplay, sBuffer);
		else
			strcopy(sDisplay, sizeof(sDisplay), sBuffer);
	}
	
	SetHudTextParams(0.2, 1.0, 0.5, 255, 255, 255, 255);
	ShowHudText(iClient, 0, sDisplay);
	
	return Plugin_Continue;
}

void Huds_ClientDisplayMenu(int iClient)
{
	if (g_cvHuds.IntValue != HudMode_Menu)
		return;
	
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon != INVALID_ENT_REFERENCE)
		iActiveWeapon = EntIndexToEntRef(iActiveWeapon);
	
	Menu hMenu = new Menu(Huds_MenuAction);
	int iCount;
	
	int iLength = g_aHudWeapon[iClient].Length;
	for (int i = 0; i < iLength; i++)
	{
		HudWeapon hudWeapon;
		g_aHudWeapon[iClient].GetArray(i, hudWeapon);
		
		char sBuffer[256];
		if (!hudWeapon.GetText(iClient, sBuffer, sizeof(sBuffer)))
			continue;
		
		if (iActiveWeapon == hudWeapon.iRef)
			Format(sBuffer, sizeof(sBuffer), "> %s", sBuffer);
		
		char sValue[16];
		IntToString(hudWeapon.iRef, sValue, sizeof(sValue));
		bool bSwitch = iActiveWeapon == hudWeapon.iRef || TF2_CanSwitchTo(iClient, hudWeapon.iRef);
		hMenu.AddItem(sValue, sBuffer, bSwitch ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		iCount++;
	}
	
	if (iCount <= 9)
		hMenu.Pagination = MENU_NO_PAGINATION;
	
	hMenu.OptionFlags |= MENUFLAG_NO_SOUND;
	hMenu.Display(iClient, MENU_TIME_FOREVER);
}

public int Huds_MenuAction(Menu hMenu, MenuAction action, int iClient, int iChoice)
{
	switch (action)
	{
		case MenuAction_End:
		{
			delete hMenu;
		}
		case MenuAction_Select:
		{
			char sValue[16];
			hMenu.GetItem(iChoice, sValue, sizeof(sValue));
			int iRef = StringToInt(sValue);
			if (IsValidEntity(iRef))
				TF2_SwitchToWeapon(iClient, EntRefToEntIndex(iRef));
		}
	}
}