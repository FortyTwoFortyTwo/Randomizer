#define ATTRIB_MAXHEALTH_30SECONDS		139
#define ATTRIB_MAXHEALTH				140
#define ATTRIB_WEAPON_MODE				144
#define ATTRIB_RECHARGE_RATE 			801

#define ITEM_BONK_COOLDOWN				30.0
#define ITEM_BONK_DURATION				8.0
#define ITEM_CRITCOLA_COOLDOWN			30.0
#define ITEM_CRITCOLA_DURATION			8.0

#define ITEM_GASPASSER_METER_TIME		60.0
#define ITEM_GASPASSER_METER_DAMAGE		750.0

#define ITEM_SANDVICH_HEAL				75
#define ITEM_SANDVICH_OVERHEAL			0
#define ITEM_DALOKOHS_HEAL				25
#define ITEM_DALOKOHS_OVERHEAL			0
#define ITEM_DALOKOHS_MAXHEAL			50.0
#define ITEM_DALOKOHS_DURATION			30.0
#define ITEM_STEAK_DURATION				16.0

float g_flClientPreviousThink[TF_MAXPLAYERS];

public void Weapons_ClientThink(int iClient)
{
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	char sClassname[256];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	
	//Gas Passer
	if (StrEqual(sClassname, "tf_weapon_jar_gas"))
	{
		//Non-Pyros cant refill gas meter, fix that
		if (nClass != TFClass_Pyro)
		{
			float flTimeGap = GetGameTime() - g_flClientPreviousThink[iClient];
			
			flMeter += flTimeGap / ITEM_GASPASSER_METER_TIME * 100.0;
			if (flMeter >= 100.0)
			{
				flMeter = 100.0;
				TF2_SetAmmo(iWeapon, 1);
			}
			else
			{
				TF2_SetAmmo(iWeapon, 0);
			}
			
			SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", flMeter, 1);
		}
	}
	
	g_flClientPreviousThink[iClient] = GetGameTime();
}

/*
public void TF2_OnConditionAdded(int iClient, TFCond condition)
{
	PrintToChatAll("(%N) have cond (%d)", iClient, condition);
}
*/
public Action OnPlayerRunCmd(int iClient, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!(buttons & IN_ATTACK))
		return;
	
	if (!(GetEntityFlags(iClient) & FL_ONGROUND))
		return;
	/*
	if (0.0 < GetEntPropFloat(iClient, Prop_Send, "m_flNextAttack") < GetGameTime())
		return;
	*/
	//Get class, active weapon, index, slot and classname
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	int iIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
	int iSlot = TF2_GetSlotFromWeapon(iClient, iWeapon);
	char sClassname[256];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	
	//We dont need to bother do anything if active weapon uses same class as default, works fine
	if (TF2Econ_GetItemSlot(iIndex, nClass) == iSlot)
		return;
	
	//Check if filled
	int iAmmo = TF2_GetCurrentAmmo(iWeapon);
	if (iAmmo <= 0)
		return;
	
	float flVal;
	
	if (StrEqual(sClassname, "tf_weapon_lunchbox_drink"))
	{
		//Since class dont have special taunt for eat/drink, we use stun instead
		TF2_StunPlayer(iClient, 1.0, 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT, 0);
		
		//Reduce ammo by one
		TF2_SetAmmo(iWeapon, iAmmo - 1);
		
		if (TF2_WeaponFindAttribute(iWeapon, ATTRIB_WEAPON_MODE, flVal) && flVal == 2.0)
		{
			//Crit-a-Cola
			SetEntPropFloat(iWeapon, Prop_Send, "m_flEffectBarRegenTime", GetGameTime() + ITEM_CRITCOLA_COOLDOWN);
			ApplyDelayCond(1.2, iClient, TFCond_CritCola, ITEM_CRITCOLA_DURATION);
		}
		else
		{
			//Bonk! Atomic Punch
			SetEntPropFloat(iWeapon, Prop_Send, "m_flEffectBarRegenTime", GetGameTime() + ITEM_BONK_COOLDOWN);
			ApplyDelayCond(1.2, iClient, TFCond_Bonked, ITEM_BONK_DURATION);
		}
	}
	
	if (StrEqual(sClassname, "tf_weapon_lunchbox"))
	{
		//Reset timer
		delete g_hClientEventTimer[iClient][iSlot];
		
		//Since class dont have special taunt for eat/drink, we use stun instead
		TF2_StunPlayer(iClient, 3.8, 0.0, TF_STUNFLAG_BONKSTUCK|TF_STUNFLAG_NOSOUNDOREFFECT, 0);
		
		//Reduce ammo by one
		TF2_SetAmmo(iWeapon, iAmmo - 1);
		
		//Set cooldown to item
		if (TF2_WeaponFindAttribute(iWeapon, ATTRIB_RECHARGE_RATE, flVal))
			SetEntPropFloat(iWeapon, Prop_Send, "m_flEffectBarRegenTime", GetGameTime() + flVal);
		
		//Steak
		if (TF2_WeaponFindAttribute(iWeapon, ATTRIB_WEAPON_MODE, flVal) && flVal == 2.0)
		{
			//Give minicrit & melee only
			ApplyDelayCond(2.0, iClient, TFCond_CritCola, ITEM_STEAK_DURATION);
			ApplyDelayCond(2.0, iClient, TFCond_RestrictToMelee, ITEM_STEAK_DURATION);
			
			int iMelee = TF2_GetItemInSlot(iClient, WeaponSlot_Melee);
			SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iMelee);
			
			return;
		}
		
		int iAdditionalHeal;
		int iMaxOverHeal;
		
		//Dalokohs
		if (TF2_WeaponFindAttribute(iWeapon, ATTRIB_MAXHEALTH_30SECONDS, flVal) && flVal == 1.0)
		{
			//Dalokohs
			
			//Set +50 max health
			TF2Attrib_SetByDefIndex(iWeapon, ATTRIB_MAXHEALTH, ITEM_DALOKOHS_MAXHEAL);
			
			iAdditionalHeal = ITEM_DALOKOHS_HEAL;
			iMaxOverHeal = ITEM_DALOKOHS_OVERHEAL;
			
			//Create timer to reset max health
			DataPack datareset = new DataPack();
			datareset.WriteCell(EntIndexToEntRef(iWeapon));
			datareset.WriteCell(ATTRIB_MAXHEALTH);
			g_hClientEventTimer[iClient][iSlot] = CreateTimer(ITEM_DALOKOHS_DURATION, Timer_RemoveAttribute, datareset);
		}
		else
		{
			//Sandvich
			iAdditionalHeal = ITEM_SANDVICH_HEAL;
			iMaxOverHeal = ITEM_SANDVICH_OVERHEAL;
		}
		
		//Heal
		DataPack dataheal = new DataPack();
		dataheal.WriteCell(EntIndexToEntRef(iClient));
		dataheal.WriteCell(iAdditionalHeal);
		dataheal.WriteCell(iMaxOverHeal);
		dataheal.WriteCell(4);
		CreateTimer(1.0, Timer_RegenerateHealth, dataheal);
	}
	
	return;
}

public void ApplyDelayCond(float flDelay, int iClient, TFCond cond, float flDuration)
{
	DataPack data = new DataPack();
	data.WriteCell(EntIndexToEntRef(iClient));
	data.WriteCell(cond);
	data.WriteFloat(flDuration);
	CreateTimer(flDelay, Timer_ApplyCond, data);
}

public Action Timer_ApplyCond(Handle hTimer, DataPack data)
{
	data.Reset();
	int iClient = EntRefToEntIndex(data.ReadCell());
	TFCond cond = data.ReadCell();
	float flDuration = data.ReadFloat();
	delete data;
	
	//Check client still valid
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return;
	
	//Give cond
	TF2_AddCondition(iClient, cond, flDuration);
}
/*
public void ApplyAttribute(int iEntity, int iAttribute, float flVal, float flDuration)
{
	TF2Attrib_SetByDefIndex(iEntity, iAttribute, flVal);
	TF2Attrib_ClearCache(iEntity);
	
	//Create timer to reset attribute
	if (flDuration >= 0.0)
	{
		DataPack data = new DataPack();
		data.WriteCell(EntIndexToEntRef(iEntity));
		data.WriteCell(iAttribute);
		CreateTimer(flDuration, Timer_RemoveAttribute, data);
	}
}
*/
public Action Timer_RemoveAttribute(Handle hTimer, DataPack data)
{
	data.Reset();
	int iEntity = EntRefToEntIndex(data.ReadCell());
	int iAttribute = data.ReadCell();
	delete data;
	
	TF2Attrib_RemoveByDefIndex(iEntity, iAttribute);
	TF2Attrib_ClearCache(iEntity);
}

public Action Timer_RegenerateHealth(Handle hTimer, DataPack data)
{
	//Collect data
	data.Reset();
	int iClient = EntRefToEntIndex(data.ReadCell());
	int iAdditionalHeal = data.ReadCell();
	int iMaxOverHeal = data.ReadCell();
	int iAmount = data.ReadCell();
	delete data;
	
	//Check client still valid
	if (iClient <= 0 || iClient > MaxClients || !IsClientInGame(iClient) || !IsPlayerAlive(iClient))
		return;
	
	Client_AddHealth(iClient, iAdditionalHeal, iMaxOverHeal);
	
	iAmount--;
	if (iAmount > 0)
	{
		//Create another timer to regenerate health
		DataPack dataheal = new DataPack();
		dataheal.WriteCell(EntIndexToEntRef(iClient));
		dataheal.WriteCell(iAdditionalHeal);
		dataheal.WriteCell(iMaxOverHeal);
		dataheal.WriteCell(iAmount);
		
		CreateTimer(1.0, Timer_RegenerateHealth, dataheal);
	}
}