#define FILEPATH_CONFIG_CONTROLS "configs/randomizer/controls.cfg"

enum struct ControlsInfo
{
	int iButton;	//Bitflag button
	char sKey[64];	//String in config to get stuffs
	WeaponWhitelist weaponWhitelist;	//List of weapons that uses this control
}

enum struct ControlsPassive
{
	Button nButton;		//Which button to use as alt way
	float flCooldown;	//After passive is used, cooldown before able to use again
	bool bInvis;		//Can this be used while cloaked?
	
	char sTextMain[64];	//Text to use if button not changed
	char sTextAlt[64];	//Text to use if button is changed to alt way
	char sTextNone[64];	//Text to use if no buttons to use
}

static ControlsInfo g_controlsInfo[Button_MAX];
static StringMap g_mControlsPassive;
static bool g_bControlsButton[MAXPLAYERS][WeaponSlot_Building+1][view_as<int>(Button_MAX)];
static float g_flControlsCooldown[MAXPLAYERS][WeaponSlot_Building+1];

public void Controls_Init()
{
	g_controlsInfo[Button_Attack2].iButton = IN_ATTACK2;
	g_controlsInfo[Button_Attack2].sKey = "attack2";
	
	g_controlsInfo[Button_Attack3].iButton = IN_ATTACK3;
	g_controlsInfo[Button_Attack3].sKey = "attack3";
	
	g_controlsInfo[Button_Reload].iButton = IN_RELOAD;
	g_controlsInfo[Button_Reload].sKey = "reload";
	
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
				controlsPassive.flCooldown = kv.GetFloat("cooldown", 0.0);
				controlsPassive.bInvis = !!kv.GetNum("invis", false);
				
				if (StrEqual(sButton, "attack2"))
					controlsPassive.nButton = Button_Attack2;
				else if (StrEqual(sButton, "attack3"))
					controlsPassive.nButton = Button_Attack3;
				else if (StrEqual(sButton, "reload"))
					controlsPassive.nButton = Button_Reload;
				else
					controlsPassive.nButton = Button_Invalid;
				
				Controls_GetTranslation(kv, sName, "textmain", controlsPassive.sTextMain, sizeof(controlsPassive.sTextMain));
				Controls_GetTranslation(kv, sName, "textalt", controlsPassive.sTextAlt, sizeof(controlsPassive.sTextAlt));
				Controls_GetTranslation(kv, sName, "textnone", controlsPassive.sTextNone, sizeof(controlsPassive.sTextNone));
				
				g_mControlsPassive.SetArray(sName, controlsPassive, sizeof(controlsPassive));
			}
			while (kv.GotoNextKey(false));
		}
		kv.GoBack();
	}
	kv.GoBack();
	
	delete kv;
}

void Controls_GetTranslation(KeyValues kv, const char[] sName, const char[] sKey, char[] sBuffer, int iLength)
{
	kv.GetString(sKey, sBuffer, iLength);
	if (!sBuffer[0])
		return;
	
	if (!TranslationPhraseExists(sBuffer))
		LogError("Found controls classname '%s' but translation '%s' doesn't exist", sName, sBuffer);
}

void Controls_RefreshClient(int iClient)
{
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_PDA2; iSlot++)
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

Button Controls_GetPassiveButton(int iClient, int iWeapon)
{
	ControlsPassive controlsPassive;
	if (!Controls_GetPassive(iWeapon, controlsPassive))
		return Button_Invalid;
	
	int iActiveWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon == INVALID_ENT_REFERENCE)
		return Button_Invalid;
	
	//Active weapon always use attack2
	if (iWeapon == iActiveWeapon)
		return Button_Attack2;
	
	int iActiveSlot = TF2_GetSlot(iActiveWeapon);
	if (g_bControlsButton[iClient][iActiveSlot][Button_Attack2])
	{
		//Active slot use attack2, use alt button instead if possible
		if (controlsPassive.nButton == Button_Invalid)
			return Button_Invalid;
		if (g_bControlsButton[iClient][iActiveSlot][controlsPassive.nButton])
			return Button_Invalid;
		else
			return controlsPassive.nButton;
	}
	
	int iSlot = TF2_GetSlot(iWeapon);
	int iWeaponTemp, iPos;
	while (TF2_GetItem(iClient, iWeaponTemp, iPos))
	{
		ControlsPassive buffer;
		if (!Controls_GetPassive(iWeaponTemp, buffer))
			continue;	//not passive
		
		int iSlotTemp = TF2_GetSlot(iWeaponTemp);
		if (g_bControlsButton[iClient][iSlotTemp][Button_Attack2] && iSlotTemp < iSlot)
		{
			//iWeaponTemp uses attack2 and have higher priority than iWeapon, use alt
			return controlsPassive.nButton;
		}
	}
	
	return Button_Attack2;
}

int Controls_GetPassiveButtonBit(int iClient, int iWeapon)
{
	Button nButton = Controls_GetPassiveButton(iClient, iWeapon);
	if (nButton == Button_Invalid)
		return 0;
	
	return g_controlsInfo[nButton].iButton;
}

bool Controls_GetPassiveInfo(int iClient, int iWeapon, char[] sText, int iLength)
{
	ControlsPassive controlsPassive;
	if (!Controls_GetPassive(iWeapon, controlsPassive))
		return false;
	
	Button nButton = Controls_GetPassiveButton(iClient, iWeapon);
	
	if (nButton == Button_Invalid)
		Format(sText, iLength, "%T", controlsPassive.sTextNone, iClient);
	else if (nButton == Button_Attack2)
		Format(sText, iLength, "%T", controlsPassive.sTextMain, iClient);
	else
		Format(sText, iLength, "%T", controlsPassive.sTextAlt, iClient);
	
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

bool Controls_GetPassive(int iWeapon, ControlsPassive controlsPassive)
{
	char sClassname[CONFIG_MAXCHAR];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	return g_mControlsPassive.GetArray(sClassname, controlsPassive, sizeof(controlsPassive));
}

bool Controls_CanUse(int iClient, int iWeapon)
{
	int iSlot = TF2_GetSlot(iWeapon);
	if (g_flControlsCooldown[iClient][iSlot] > GetGameTime())
		return false;
	
	ControlsPassive controlsPassive;
	Controls_GetPassive(iWeapon, controlsPassive);
	if (!controlsPassive.bInvis && TF2_IsPlayerInCondition(iClient, TFCond_Cloaked))
		return false;
	
	return true;
}