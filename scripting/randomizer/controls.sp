#define FILEPATH_CONFIG_CONTROLS "configs/randomizer/controls.cfg"

enum struct ControlsInfo
{
	int iButton;	//Bitflag button
	char sKey[64];	//String in config to get stuffs
	char sText[64];	//Text to display
	WeaponWhitelist weaponWhitelist;	//List of weapons that uses this control
}

enum struct ControlsPassive
{
	Button nButton;
	char sText[64];
	float flCooldown;
}

ControlsInfo g_controlsInfo[Button_MAX];
StringMap g_mControlsPassive;
bool g_bControlsButton[TF_MAXPLAYERS+1][WeaponSlot_BuilderEngie+1][view_as<int>(Button_MAX)];
float g_flControlsCooldown[TF_MAXPLAYERS+1][WeaponSlot_BuilderEngie+1];

public void Controls_Init()
{
	g_controlsInfo[Button_Attack2].iButton = IN_ATTACK2;
	g_controlsInfo[Button_Attack2].sKey = "attack2";
	g_controlsInfo[Button_Attack2].sText = "right click";
	
	g_controlsInfo[Button_Attack3].iButton = IN_ATTACK3;
	g_controlsInfo[Button_Attack3].sKey = "attack3";
	g_controlsInfo[Button_Attack3].sText = "middle click";
	
	g_controlsInfo[Button_Reload].iButton = IN_RELOAD;
	g_controlsInfo[Button_Reload].sKey = "reload";
	g_controlsInfo[Button_Reload].sText = "reload";
	
	
	g_mControlsPassive = new StringMap();
}

public void Controls_Refresh()
{
	KeyValues kv = LoadConfig(FILEPATH_CONFIG_CONTROLS, "Controls");
	if (!kv)
		return;
	
	for (int i = 0; i < sizeof(g_controlsInfo); i++)
	{
		g_controlsInfo[i].weaponWhitelist.Delete();
		g_controlsInfo[i].weaponWhitelist.Load(kv, g_controlsInfo[i].sKey);
	}
	
	g_mControlsPassive.Clear();
	
	if (kv.JumpToKey("passive", false))
	{
		if (kv.GotoFirstSubKey(false))
		{
			do
			{
				ControlsPassive controlsPassive;
				char sName[CONFIG_MAXCHAR], sButton[CONFIG_MAXCHAR];
				kv.GetSectionName(sName, sizeof(sName));
				kv.GetString("button", sButton, sizeof(sButton));
				kv.GetString("text", controlsPassive.sText, sizeof(controlsPassive.sText));
				controlsPassive.flCooldown = kv.GetFloat("cooldown", 0.0);
				
				if (StrEqual(sButton, "attack2"))
					controlsPassive.nButton = Button_Attack2;
				else if (StrEqual(sButton, "attack3"))
					controlsPassive.nButton = Button_Attack3;
				else if (StrEqual(sButton, "reload"))
					controlsPassive.nButton = Button_Reload;
				
				g_mControlsPassive.SetArray(sName, controlsPassive, sizeof(controlsPassive));
			}
			while (kv.GotoNextKey(false));
		}
		kv.GoBack();
	}
	kv.GoBack();
	
	delete kv;
}

void Controls_RefreshClient(int iClient)
{
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_InvisWatch; iSlot++)
	{
		g_flControlsCooldown[iClient][iSlot] = 0.0;
		
		int iWeapon = TF2_GetItemInSlot(iClient, iSlot);
		if (iWeapon > MaxClients)
		{
			int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
			
			for (Button nButton; nButton < Button_MAX; nButton++)
				g_bControlsButton[iClient][iSlot][nButton] = g_controlsInfo[nButton].weaponWhitelist.IsIndexAllowed(iIndex);
		}
		else
		{
			for (Button nButton; nButton < Button_MAX; nButton++)
				g_bControlsButton[iClient][iSlot][nButton] = false;
		}
	}
}

Button Controls_GetPassiveButton(int iClient, int iSlot, bool &bAllowAttack2)
{
	ControlsPassive controlsPassive;
	if (!Controls_GetPassiveFromSlot(iClient, iSlot, controlsPassive))
		return Button_Invalid;
	
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon <= MaxClients)
		return Button_Invalid;
	
	int iWeapon = TF2_GetItemInSlot(iClient, iSlot);
	int iActiveSlot = TF2_GetSlotFromItem(iClient, iActiveWeapon);
	
	if (iWeapon == iActiveWeapon && bAllowAttack2)
	{
		bAllowAttack2 = false;
		return Button_Attack2;
	}
	else if (iWeapon == iActiveWeapon)
	{
		return controlsPassive.nButton;
	}
	else if (bAllowAttack2 && !g_bControlsButton[iClient][iActiveSlot][Button_Attack2])
	{
		bAllowAttack2 = false;
		return Button_Attack2;
	}
	else if (!g_bControlsButton[iClient][iActiveSlot][controlsPassive.nButton])
	{
		return controlsPassive.nButton;
	}
	else
	{
		return Button_Invalid;
	}
}

int Controls_GetPassiveButtonBit(int iClient, int iSlot, bool &bAllowAttack2)
{
	Button nButton = Controls_GetPassiveButton(iClient, iSlot, bAllowAttack2);
	if (nButton == Button_Invalid)
		return 0;
	
	return g_controlsInfo[nButton].iButton;
}

bool Controls_GetPassiveInfo(int iClient, int iSlot, bool &bAllowAttack2, char[] sBuffer, int iLength)
{
	ControlsPassive controlsPassive;
	if (!Controls_GetPassiveFromSlot(iClient, iSlot, controlsPassive))
		return false;
	
	Button nButton = Controls_GetPassiveButton(iClient, iSlot, bAllowAttack2);
	
	if (nButton == Button_Invalid)
		Format(sBuffer, iLength, "unable to %s", controlsPassive.sText);
	else
		Format(sBuffer, iLength, "%s to %s", g_controlsInfo[nButton].sText, controlsPassive.sText);
	
	return true;
}

void Controls_OnPassiveUse(int iClient, int iSlot)
{
	ControlsPassive controlsPassive;
	if (Controls_GetPassiveFromSlot(iClient, iSlot, controlsPassive))
		g_flControlsCooldown[iClient][iSlot] = GetGameTime() + controlsPassive.flCooldown;
}

bool Controls_IsPassiveInCooldown(int iClient, int iSlot)
{
	return g_flControlsCooldown[iClient][iSlot] > GetGameTime();
}

bool Controls_GetPassiveFromSlot(int iClient, int iSlot, ControlsPassive controlsPassive)
{
	int iWeapon = TF2_GetItemInSlot(iClient, iSlot);
	if (iWeapon <= MaxClients)
		return false;
	
	char sClassname[CONFIG_MAXCHAR];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	return g_mControlsPassive.GetArray(sClassname, controlsPassive, sizeof(controlsPassive));
}