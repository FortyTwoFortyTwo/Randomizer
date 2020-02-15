#define FILEPATH_CONFIG_HUDS "configs/randomizer/huds.cfg"

enum
{
	HudWeapon_Classname,
	HudWeapon_Attrib,
	HudWeapon_Index,
	HudWeapon_MAX,
}

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
	ArrayList aWeapons[HudWeapon_MAX];	//If any not null, only display if weapon have one of those
	char sNetprop[32];	//Netprop to get value
	int iElement;		//If netprop is array, element postition to get
	HudEntity nEntity;	//Entity to target from netprop
	HudType nType;		//How is netprop value stored
	float flMultiply;	//Multiply netprop value to display
	bool bMin;			//Is there netprop min value?
	float flMin;		//Netprop min value inorder to display
	bool bMax;			//Is there netprop max value?
	float flMax;		//Netprop max value inorder to display
	char sText[64];		//Text to display next to value
	StringMap mText;	//If not null, use this instead of sText to get text depending on netprop value
	
	bool IsIndexAllowed(int iIndex)
	{
		bool bNull = true;
		
		if (this.aWeapons[HudWeapon_Classname])
		{
			bNull = false;
			char sClassname[256];
			TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
			
			int iLength = this.aWeapons[HudWeapon_Classname].Length;
			for (int i = 0; i < iLength; i++)
			{
				char sBuffer[256];
				this.aWeapons[HudWeapon_Classname].GetString(i, sBuffer, sizeof(sBuffer));
				if (StrEqual(sClassname, sBuffer))
					return true;
			}
		}
		
		if (this.aWeapons[HudWeapon_Attrib])
		{
			bNull = false;
			ArrayList aIndexAttrib = TF2Econ_GetItemStaticAttributes(iIndex);
			int iIndexAttribLength = aIndexAttrib.Length;
			int iAllowedAttribLength = this.aWeapons[HudWeapon_Attrib].Length;
			
			for (int i = 0; i < iIndexAttribLength; i++)
			{
				int iIndexAttrib = aIndexAttrib.Get(i);
				for (int j = 0; j < iAllowedAttribLength; j++)
				{
					if (iIndexAttrib == this.aWeapons[HudWeapon_Attrib].Get(j))
					{
						delete aIndexAttrib;
						return true;
					}
				}
			}
			
			delete aIndexAttrib;
		}
		
		if (this.aWeapons[HudWeapon_Index])
		{
			int iLength = this.aWeapons[HudWeapon_Index].Length;
			for (int i = 0; i < iLength; i++)
				if (iIndex == this.aWeapons[HudWeapon_Index].Get(i))
					return true;
		}
		
		//If all whitelist arrays is null, assume it for all weapons
		return bNull;
	}
	
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
	int iRef;				//Weapon ref
	char sName[64];			//Name of weapon to display
	ArrayList aHudInfo;		//Arrays of HudInfo to display
	bool bAttack2;			//Does this weapon do something on attack2
	bool bPassive;			//Does this weapon have attack2 works on any weapons?
	char sPassiveText[64];	//Text to display if bPassive
}

static ArrayList g_aHuds;	//Arrays of HudInfo
static HudWeapon g_hudWeapon[TF_MAXPLAYERS+1][WeaponSlot_InvisWatch+1];	//What to display for each weapons

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
		
		for (int j = 0; j < sizeof(hudInfo.aWeapons); j++)
			delete hudInfo.aWeapons[j];
		
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
			
			if (kv.JumpToKey("weapon", false))
			{
				if (kv.GotoFirstSubKey(false))	//netprop name
				{
					do
					{
						char sType[CONFIG_MAXCHAR], sValue[CONFIG_MAXCHAR];
						kv.GetSectionName(sType, sizeof(sType));
						kv.GetString(NULL_STRING, sValue, sizeof(sValue));
						
						if (StrEqual(sType, "classname", false))
						{
							if (!hudInfo.aWeapons[HudWeapon_Classname])
								hudInfo.aWeapons[HudWeapon_Classname] = new ArrayList(CONFIG_MAXCHAR);
							hudInfo.aWeapons[HudWeapon_Classname].PushString(sValue);
						}
						else if (StrEqual(sType, "attrib", false))
						{
							if (!hudInfo.aWeapons[HudWeapon_Attrib])
								hudInfo.aWeapons[HudWeapon_Attrib] = new ArrayList();
							hudInfo.aWeapons[HudWeapon_Attrib].Push(TF2Econ_TranslateAttributeNameToDefinitionIndex(sValue));
						}
						else if (StrEqual(sType, "index", false))
						{
							if (!hudInfo.aWeapons[HudWeapon_Index])
								hudInfo.aWeapons[HudWeapon_Index] = new ArrayList();
							hudInfo.aWeapons[HudWeapon_Index].Push(StringToInt(sValue));
						}
					}
					while (kv.GotoNextKey(false));
					kv.GoBack();
				}
				kv.GoBack();
			}
			
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
	{
		delete g_hudWeapon[iClient][iSlot].aHudInfo;
		
		int iWeapon = TF2_GetItemInSlot(iClient, iSlot);
		if (iWeapon > MaxClients)
		{
			HudWeapon hudWeapon;
			hudWeapon.iRef = EntIndexToEntRef(iWeapon);
			
			int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
			if (!Weapons_GetName(iIndex, hudWeapon.sName, sizeof(hudWeapon.sName)))
				hudWeapon.sName = "Unknown Name";
			
			//Go through every HudInfo to see whenever which weapon can use
			int iLength = g_aHuds.Length;
			for (int i = 0; i < iLength; i++)
			{
				HudInfo hudInfo;
				g_aHuds.GetArray(i, hudInfo);
				
				int iEntity = hudInfo.GetEntity(iClient, iWeapon);
				if (!HasEntProp(iEntity, Prop_Send, hudInfo.sNetprop))
					continue;
				
				if (!hudInfo.IsIndexAllowed(iIndex))
					continue;
				
				if (!hudWeapon.aHudInfo)
					hudWeapon.aHudInfo = new ArrayList(sizeof(HudInfo));
				
				hudWeapon.aHudInfo.PushArray(hudInfo);
			}
			
			hudWeapon.bAttack2 = Controls_IsUsingAttack2(iWeapon);
			hudWeapon.bPassive = Controls_GetPassiveDisplay(iWeapon, hudWeapon.sPassiveText, sizeof(hudWeapon.sPassiveText));
			
			g_hudWeapon[iClient][iSlot] = hudWeapon;
		}
		else
		{
			HudWeapon nothing;
			g_hudWeapon[iClient][iSlot] = nothing;
		}
	}
}

public void Huds_ClientDisplay(int iClient)
{
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon <= MaxClients)
		return;
	
	int iActiveSlot = TF2_GetSlotFromItem(iClient, iActiveWeapon);
	
	char sDisplay[512];
	
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_InvisWatch; iSlot++)
	{
		int iWeapon = EntRefToEntIndex(g_hudWeapon[iClient][iSlot].iRef);
		if (iWeapon <= MaxClients)
			continue;
		
		//Break line
		if (sDisplay[0] != '\0')
			StrCat(sDisplay, sizeof(sDisplay), "\n");
		
		StrCat(sDisplay, sizeof(sDisplay), g_hudWeapon[iClient][iSlot].sName);
		
		//Go through every netprops to display
		if (g_hudWeapon[iClient][iSlot].aHudInfo)
		{
			int iLength = g_hudWeapon[iClient][iSlot].aHudInfo.Length;
			for (int i = 0; i < iLength; i++)
			{
				HudInfo hudInfo;
				g_hudWeapon[iClient][iSlot].aHudInfo.GetArray(i, hudInfo);
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
								Format(sDisplay, sizeof(sDisplay), "%s: %s", sDisplay, sText);
							else
								Format(sDisplay, sizeof(sDisplay), "%s: %d%s", sDisplay, iVal, hudInfo.sText);
						}
					}
					case HudType_Float, HudType_Time:
					{
						float flVal;
						if (hudInfo.GetEntPropFloat(iEntity, flVal))
							Format(sDisplay, sizeof(sDisplay), "%s: %.0f%s", sDisplay, flVal, hudInfo.sText);
					}
				}
			}
			
			if (g_hudWeapon[iClient][iSlot].bPassive)
			{
				if (g_hudWeapon[iClient][iActiveSlot].bAttack2 && iWeapon != iActiveWeapon)
					Format(sDisplay, sizeof(sDisplay), "%s (reload to %s)", sDisplay, g_hudWeapon[iClient][iSlot].sPassiveText);
				else
					Format(sDisplay, sizeof(sDisplay), "%s (right click to %s)", sDisplay, g_hudWeapon[iClient][iSlot].sPassiveText);
			}
		}
	}
	
	SetHudTextParams(0.2, 1.0, 0.20, 255, 255, 255, 255);
	ShowHudText(iClient, 0, sDisplay);
}