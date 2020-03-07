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

static ControlsInfo g_controlsInfo[Button_MAX];
static StringMap g_mControlsPassive;
static bool g_bControlsButton[TF_MAXPLAYERS+1][WeaponSlot_BuilderEngie+1][view_as<int>(Button_MAX)];
static float g_flControlsCooldown[TF_MAXPLAYERS+1][WeaponSlot_BuilderEngie+1];

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
		
		for (Button nButton; nButton < Button_MAX; nButton++)
			g_bControlsButton[iClient][iSlot][nButton] = false;
	}
	
	int iWeapon;
	int iPos;
	while (TF2_GetItem(iClient, iWeapon, iPos))
	{
		int iSlot = TF2_GetSlot(iWeapon);
		int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		
		for (Button nButton; nButton < Button_MAX; nButton++)
			if (g_controlsInfo[nButton].weaponWhitelist.IsIndexAllowed(iIndex))
				g_bControlsButton[iClient][iSlot][nButton] = true;
	}
}

Button Controls_GetPassiveButton(int iClient, int iWeapon, bool &bAllowAttack2)
{
	ControlsPassive controlsPassive;
	if (!Controls_GetPassive(iWeapon, controlsPassive))
		return Button_Invalid;
	
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon <= MaxClients)
		return Button_Invalid;
	
	int iActiveSlot = TF2_GetSlot(iActiveWeapon);
	
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

int Controls_GetPassiveButtonBit(int iClient, int iWeapon, bool &bAllowAttack2)
{
	Button nButton = Controls_GetPassiveButton(iClient, iWeapon, bAllowAttack2);
	if (nButton == Button_Invalid)
		return 0;
	
	return g_controlsInfo[nButton].iButton;
}

bool Controls_GetPassiveInfo(int iClient, int iWeapon, bool &bAllowAttack2, char[] sBuffer, int iLength)
{
	ControlsPassive controlsPassive;
	if (!Controls_GetPassive(iWeapon, controlsPassive))
		return false;
	
	Button nButton = Controls_GetPassiveButton(iClient, iWeapon, bAllowAttack2);
	
	if (nButton == Button_Invalid)
		Format(sBuffer, iLength, "unable to %s", controlsPassive.sText);
	else
		Format(sBuffer, iLength, "%s to %s", g_controlsInfo[nButton].sText, controlsPassive.sText);
	
	return true;
}

void Controls_OnPassiveUse(int iClient, int iWeapon)
{
	ControlsPassive controlsPassive;
	if (Controls_GetPassive(iWeapon, controlsPassive))
	{
		int iSlot = TF2_GetSlot(iWeapon);
		g_flControlsCooldown[iClient][iSlot] = GetGameTime() + controlsPassive.flCooldown;
	}
}

bool Controls_IsPassiveInCooldown(int iClient, int iWeapon)
{
	int iSlot = TF2_GetSlot(iWeapon);
	return g_flControlsCooldown[iClient][iSlot] > GetGameTime();
}

bool Controls_GetPassive(int iWeapon, ControlsPassive controlsPassive)
{
	char sClassname[CONFIG_MAXCHAR];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	return g_mControlsPassive.GetArray(sClassname, controlsPassive, sizeof(controlsPassive));
}