enum eHudWeapon
{
	eHudWeapon_Classname,
	eHudWeapon_Attrib,
	eHudWeapon_Index,
}

enum eHudEntity
{
	eHudEntity_Weapon,
	eHudEntity_Client,
}

enum eHudType
{
	eHudType_Int,
	eHudType_Float,
	eHudType_Time,
}

methodmap CHud < StringMap
{
	public CHud()
	{
		return view_as<CHud>(new StringMap());
	}
	
	//Return true if index uses netprop, false otherwise
	public bool IsIndexAllowed(int iIndex)
	{
		char sWeapon[1024];
		if (!this.GetString("weapon", sWeapon, sizeof(sWeapon)))
			return true;	//weapon key not found, lets assume it for all weapons
		
		char sWep[32][32];
		int iCount = ExplodeString(sWeapon, " ; ", sWep, 32, 32);
		if (iCount <= 1)
			return true;

		for (int i = 0; i < iCount; i+= 2)
		{
			eHudWeapon hudWeapon = view_as<eHudWeapon>(StringToInt(sWep[i]));
			switch (hudWeapon)
			{
				case eHudWeapon_Classname:
				{
					char sClassname[256];
					TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
					if (StrEqual(sWep[i+1], sClassname))
						return true;
				}
				case eHudWeapon_Attrib:
				{
					ArrayList aAttrib = TF2Econ_GetItemStaticAttributes(iIndex);
					int iLength = aAttrib.Length;
					for (int j = 0; j < iLength; j++)
					{
						char sAttrib[256];
						TF2Econ_GetAttributeName(aAttrib.Get(j, 0), sAttrib, sizeof(sAttrib));
						if (StrEqual(sWep[i+1], sAttrib))
						{
							delete aAttrib;
							return true;
						}
					}
					
					delete aAttrib;
				}
				case eHudWeapon_Index:
				{
					if (StringToInt(sWep[i+1]) == iIndex)
						return true;
				}
			}
		}
		
		return false;
	}
	
	//Return either int or float of entity netprop & element value, depending on type
	public any GetNetpropValue(int iEntity)
	{
		eHudType hudType;
		this.GetValue("type", hudType);
		
		char sNetprop[256];
		this.GetString("netprop", sNetprop, sizeof(sNetprop));
		
		int iElement = 0;
		char sElement[256];
		if (this.GetString("element", sElement, sizeof(sElement)))
			iElement = StringToInt(sElement);
		
		switch (hudType)
		{
			case eHudType_Int:
			{
				return GetEntProp(iEntity, Prop_Send, sNetprop, _, iElement);
			}
			case eHudType_Float:
			{
				return GetEntPropFloat(iEntity, Prop_Send, sNetprop, iElement);
			}
			case eHudType_Time:
			{
				return GetEntPropFloat(iEntity, Prop_Send, sNetprop, iElement) - GetGameTime();
			}
		}
		
		LogError("Unable to find valid Hud type at \"%s\" - \"%d\"", sNetprop, hudType);
		return -1;
	}
};

public void Hud_ClientDisplay(int iClient)
{
	char sDisplay[512];
	//TFClassType iClass = TF2_GetPlayerClass(iClient);
	
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_InvisWatch; iSlot++)
	{
		int iWeapon = TF2_GetItemInSlot(iClient, iSlot);
		
		if (IsValidEdict(iWeapon))
		{
			//Break line
			if (!StrEqual(sDisplay, ""))
				Format(sDisplay, sizeof(sDisplay), "%s\n", sDisplay);
			//else
			//	Format(sDisplay, sizeof(sDisplay), "GetGameTime (%.8f)\n", GetGameTime());
			
			//Get Index
			int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
			
			//TODO translation support
			char sName[256];
			if (TF2Econ_GetItemName(iIndex, sName, sizeof(sName)))
				Format(sDisplay, sizeof(sDisplay), "%s%s", sDisplay, sName);
			else
				Format(sDisplay, sizeof(sDisplay), "%sUnknown Name", sDisplay);
			
			//Go through every netprops to see whenever if meter needs to be displayed
			
			int iLength = g_aHud.Length;
			for (int iNetprop = 0; iNetprop < iLength; iNetprop++)
			{
				CHud hud = g_aHud.Get(iNetprop);
				
				if (!hud.IsIndexAllowed(iIndex))
					continue;
				
				int iEntity;
				eHudEntity hudEntity;
				hud.GetValue("entity", hudEntity);
				switch (hudEntity)
				{
					case eHudEntity_Weapon: iEntity = iWeapon;
					case eHudEntity_Client: iEntity = iClient;
				}
				
				char sBuffer[256];
				
				hud.GetString("netprop", sBuffer, sizeof(sBuffer));
				if (!HasEntProp(iEntity, Prop_Send, sBuffer))
					continue;
				
				any value = hud.GetNetpropValue(iEntity);
				
				if (hud.GetString("multiply", sBuffer, sizeof(sBuffer)))
					value *= StringToFloat(sBuffer);
				
				if (hud.GetString("min", sBuffer, sizeof(sBuffer)))
					if (value <= StringToFloat(sBuffer))
						continue;
				
				if (hud.GetString("max", sBuffer, sizeof(sBuffer)))
					if (value >= StringToFloat(sBuffer))
						continue;
				
				eHudType hudType;
				hud.GetValue("type", hudType);
				if (hudType == eHudType_Int)
					Format(sDisplay, sizeof(sDisplay), "%s: %d", sDisplay, value);
				else	//float and time
					Format(sDisplay, sizeof(sDisplay), "%s: %.0f", sDisplay, value);
				
				if (hud.GetString("text", sBuffer, sizeof(sBuffer)))
				{
					Format(sDisplay, sizeof(sDisplay), "%s%s", sDisplay, sBuffer);
				}
				else
				{
					//Display text depending what current value netprop is
					StringMap mText;
					if (hud.GetValue("text", mText) && mText != null && mText.Size > 0)
					{
						char sValue[256];
						IntToString(value, sValue, sizeof(sValue));
						if (mText.GetString(sValue, sBuffer, sizeof(sBuffer)))
							Format(sDisplay, sizeof(sDisplay), "%s%s", sDisplay, sBuffer);
					}
				}
			}
		}
	}
	
	SetHudTextParams(0.2, 1.0, 0.20, 255, 255, 255, 255);
	ShowHudText(iClient, 0, sDisplay);
}