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
	
	bool GetEntProp(int iEntity, int &iVal)
	{
		iVal = GetEntProp(iEntity, Prop_Send, this.sNetprop, _, this.iElement);
		iVal = RoundToNearest(float(iVal) * this.flMultiply);
		iVal += RoundToNearest(this.flAdd);
		
		if (this.bMin && float(iVal) <= this.flMin)
			return false;
		
		if (this.bMax && float(iVal) >= this.flMax)
			return false;
		
		return true;
	}
	
	bool GetEntPropFloat(int iEntity, float &flVal)
	{
		flVal = GetEntPropFloat(iEntity, Prop_Send, this.sNetprop, this.iElement);
		
		if (this.nType == HudType_Time)
			flVal -= GetGameTime();
		
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

static ArrayList g_aHuds;	//Arrays of HudInfo from config
static ArrayList g_aClientHudInfo[TF_MAXPLAYERS][WeaponSlot_InvisWatch+1];	//Arrays of HudInfo to display

void Huds_Init()
{
	g_aHuds = new ArrayList(sizeof(HudInfo));
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
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_InvisWatch; iSlot++)
		delete g_aClientHudInfo[iClient][iSlot];
	
	if (!g_cvHuds.BoolValue)	//ConVar dont want us to do anything
		return;
	
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_InvisWatch; iSlot++)
	{
		int iWeapon = g_ClientWeaponInfo[iClient][iSlot].GetItem();
		if (iWeapon == INVALID_ENT_REFERENCE)
			continue;
		
		//Translate weapon name
		if (TranslationPhraseExists(g_ClientWeaponInfo[iClient][iSlot].sName))
			Format(g_ClientWeaponInfo[iClient][iSlot].sName, sizeof(g_ClientWeaponInfo[][].sName), "%T", g_ClientWeaponInfo[iClient][iSlot].sName, iClient);
		
		//Go through every HudInfo to see whenever which weapon can use
		int iLength = g_aHuds.Length;
		for (int i = 0; i < iLength; i++)
		{
			HudInfo hudInfo;
			g_aHuds.GetArray(i, hudInfo);
			
			int iEntity = hudInfo.GetEntity(iClient, iWeapon);
			if (!HasEntProp(iEntity, Prop_Send, hudInfo.sNetprop))
				continue;
			
			if (!hudInfo.weaponWhitelist.IsEmpty() && !hudInfo.weaponWhitelist.IsAllowed(g_ClientWeaponInfo[iClient][iSlot]))
				continue;
			
			if (!g_aClientHudInfo[iClient][iSlot])
				g_aClientHudInfo[iClient][iSlot] = new ArrayList(sizeof(HudInfo));
			
			g_aClientHudInfo[iClient][iSlot].PushArray(hudInfo);
		}
	}
}

public Action Huds_ClientDisplay(Handle hTimer, int iClient)
{
	if (g_hTimerClientHud[iClient] != hTimer)
		return Plugin_Stop;
	
	if (!g_cvHuds.BoolValue)	//ConVar dont want us to do anything
		return Plugin_Continue;
	
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon <= MaxClients)
		return Plugin_Continue;
	
	char sDisplay[512];
	
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_InvisWatch; iSlot++)
	{
		int iWeapon = g_ClientWeaponInfo[iClient][iSlot].GetItem();
		if (iWeapon == INVALID_ENT_REFERENCE)
			continue;
		
		//Break line
		if (sDisplay[0] != '\0')
			StrCat(sDisplay, sizeof(sDisplay), "\n");
		
		StrCat(sDisplay, sizeof(sDisplay), g_ClientWeaponInfo[iClient][iSlot].sName);
		
		//Go through every netprops to display
		if (g_aClientHudInfo[iClient][iSlot])
		{
			int iLength = g_aClientHudInfo[iClient][iSlot].Length;
			for (int i = 0; i < iLength; i++)
			{
				HudInfo hudInfo;
				g_aClientHudInfo[iClient][iSlot].GetArray(i, hudInfo);
				int iEntity = hudInfo.GetEntity(iClient, iWeapon);
				
				switch (hudInfo.nType)
				{
					case HudType_Int:
					{
						int iVal;
						if (hudInfo.GetEntProp(iEntity, iVal))
						{
							char sText[64];
							if (hudInfo.GetDynamicText(iVal, sText, sizeof(sText)))
								Format(sDisplay, sizeof(sDisplay), "%s: %T", sDisplay, sText, iClient);
							else
								Format(sDisplay, sizeof(sDisplay), "%s: %T", sDisplay, hudInfo.sText, iClient, iVal);
						}
					}
					case HudType_Float, HudType_Time:
					{
						float flVal;
						if (hudInfo.GetEntPropFloat(iEntity, flVal))
							Format(sDisplay, sizeof(sDisplay), "%s: %T", sDisplay, hudInfo.sText, iClient, flVal);
					}
				}
			}
			
			char sBuffer[64];
			if (Controls_GetPassiveInfo(iClient, iWeapon, sBuffer, sizeof(sBuffer)))
				Format(sDisplay, sizeof(sDisplay), "%s (%s)", sDisplay, sBuffer);
		}
	}
	
	SetHudTextParams(0.2, 1.0, 0.5, 255, 255, 255, 255);
	ShowHudText(iClient, 0, sDisplay);
	
	return Plugin_Continue;
}