#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf_econ_data>
#include <tf2attributes>

#pragma newdecls required

#define TF_MAXPLAYERS 32

#define CLASS_MIN	1	//First valid TFClassType, Scout
#define CLASS_MAX	9	//Last valid TFClassType, Engineer

//Attributes that should be blacklisted
#define ATTRIB_CANNOT_TRADE				153
#define ATTRIB_ALWAYS_TRADE				195
#define ATTRIB_LIMITED_ITEM				692
#define ATTRIB_MARKETABLE				2028


//Ammo attributes
#define ATTRIB_AMMO_SECONDARY_HIDDEN	25
#define ATTRIB_AMMO_PRIMARY_HIDDEN		37
//#define ATTRIB_AMMO_PRIMARY_BONUS		76
//#define ATTRIB_AMMO_PRIMARY_PENALTY	77
//#define ATTRIB_AMMO_SECONDARY_BONUS	78
//#define ATTRIB_AMMO_SECONDARY_PENALTY	79


//Misc attributes
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

enum
{
	WeaponSlot_Primary = 0,
	WeaponSlot_Secondary,
	WeaponSlot_Melee,
	WeaponSlot_PDABuild,
	WeaponSlot_PDADisguise = 3,
	WeaponSlot_PDADestroy,
	WeaponSlot_InvisWatch = 4,
	WeaponSlot_BuilderEngie,
	WeaponSlot_Unknown1,
	WeaponSlot_Head,
	WeaponSlot_Misc1,
	WeaponSlot_Action,
	WeaponSlot_Misc2
};

//Base Max Ammo for each 9 class, primary and secondary
int g_iClassMaxAmmo[][2] = {
	{-1, -1},	// Unknown
	{32, 36},	// Scout
	{25, 75},	// Sniper
	{20, 32},	// Soldier
	{16, 24},	// Demoman
	{150, 150},	// Medic
	{200, 32},	// Heavy
	{200, 32},	// Pyro
	{20, 24},	// Spy
	{32, 200},	// Engineer
};

ArrayList g_aIndexList[WeaponSlot_BuilderEngie+1];

float g_flClientPreviousThink[TF_MAXPLAYERS+1];
TFClassType g_iClientClass[TF_MAXPLAYERS+1];
int g_iClientWeaponIndex[TF_MAXPLAYERS+1][WeaponSlot_BuilderEngie+1];
Handle g_hClientEventTimer[TF_MAXPLAYERS+1][WeaponSlot_BuilderEngie+1];

Handle g_hSDKGetMaxHealth;
Handle g_hSDKRemoveWearable;
Handle g_hSDKEquipWearable;
Handle g_hSDKGetWearable;
Handle g_hSDKGetMaxAmmo;

public Plugin myinfo =
{
	name = "Randomizer",
	author = "42",
	description = "",
	version = "0.0.0",
	url = "",
};

public void OnPluginStart()
{
	RegAdminCmd("weapon", Command_Weapon, ADMFLAG_CHANGEMAP);
	
	HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("post_inventory_application", Event_PlayerInventoryUpdate);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	
	SDK_Init();
	
	CreateWeaponList();
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		g_iClientClass[iClient] = TFClass_Unknown;
		
		for (int iSlot = 0; iSlot < sizeof(g_iClientWeaponIndex[]); iSlot++)
			g_iClientWeaponIndex[iClient][iSlot] = -1;
		
		if (IsClientInGame(iClient))
			OnClientPutInServer(iClient);
	}
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_PreThink, Client_OnThink);
	
	GenerateRandonWeapon(iClient);
}

public void CreateWeaponList()
{
	for (int iSlot = 0; iSlot < sizeof(g_aIndexList); iSlot++)
	{
		if (g_aIndexList[iSlot] != null)
			delete g_aIndexList[iSlot];
		
		g_aIndexList[iSlot] = TF2Econ_GetItemList(FilterTF2EconSlot, iSlot);
	}
}

public bool FilterTF2EconSlot(int iIndex, int iSlot)
{
	//TODO blacklist reskin weapons
	
	for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
		if (TF2Econ_GetItemSlot(iIndex, view_as<TFClassType>(iClass)) == iSlot)
			return true;
	
	return false;
}

public void GenerateRandonWeapon(int iClient)
{
	//Random Class
	g_iClientClass[iClient] = view_as<TFClassType>(GetRandomInt(CLASS_MIN, CLASS_MAX));
	//TF2_SetPlayerClass(iClient, g_iClientClass[iClient]);
	SetEntProp(iClient, Prop_Send, "m_iDesiredPlayerClass", view_as<int>(g_iClientClass[iClient]));
	
	//Random Weapon
	for (int iSlot = 0; iSlot <= WeaponSlot_Melee; iSlot++)
	{
		if (g_aIndexList[iSlot].Length <= 0)
			ThrowError("[randomizer] Index list slot %d is empty!", iSlot);
		
		int iRandom = GetRandomInt(0, g_aIndexList[iSlot].Length-1);
		int iIndex = g_aIndexList[iSlot].Get(iRandom);
		
		g_iClientWeaponIndex[iClient][iSlot] = iIndex;
	}
	
	//Reset Gas Passer meter
	SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 0.0, 1);
	
	if (IsPlayerAlive(iClient))
		TF2_RespawnPlayer(iClient);
}

public Action Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast)
{
	//New round, generate new weapons for everyone
	for (int iClient = 1; iClient <= MaxClients; iClient++)
		if (IsClientInGame(iClient))
			GenerateRandonWeapon(iClient);
}

public Action Event_PlayerSpawn(Event event, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	TFClassType iClass = TF2_GetPlayerClass(iClient);
	
	//If client is playing incorrect class, set as that class
	if (iClass != g_iClientClass[iClient])
	{
		TF2_SetPlayerClass(iClient, g_iClientClass[iClient]);
		TF2_RespawnPlayer(iClient);
	}
}

public Action Event_PlayerInventoryUpdate(Event event, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	if (GetClientTeam(iClient) <= 1) return;
	
	for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
	{
		TF2_RemoveItemInSlot(iClient, iSlot);
		
		int iIndex = g_iClientWeaponIndex[iClient][iSlot];
		if (iIndex < 0) continue;
		
		//Create weapon
		int iWeapon = TF2_CreateAndEquipWeapon(iClient, iIndex);
		
		//We want to scale max ammo to correct value as it different between class
		if (WeaponSlot_Primary <= iSlot <= WeaponSlot_Secondary && HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType"))
		{
			int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
			if (iAmmoType < 1 || iAmmoType > 2) continue;	//We only need to change ammo type 1 and 2
			
			//Think Shortstop ammo still bugged?
			
			TFClassType nWeaponClass = TFClass_Unknown;
			for (int iClass = CLASS_MIN; iClass <= CLASS_MAX; iClass++)
			{
				if (TF2Econ_GetItemSlot(iIndex, view_as<TFClassType>(iClass)) == iSlot)
				{
					nWeaponClass = view_as<TFClassType>(iClass);
					break;
				}
			}
			
			if (nWeaponClass == TFClass_Unknown)
				ThrowError("[randomizer] Unable to find class in slot %d that uses index %d!", iSlot, iIndex);
			
			float flAmmoScale = float(g_iClassMaxAmmo[nWeaponClass][iSlot]) / float(g_iClassMaxAmmo[TF2_GetPlayerClass(iClient)][iSlot]);
			if (flAmmoScale == 1.0) continue;
			
			float flOldAmmoScale = 1.0;
			switch (iSlot)
			{
				case WeaponSlot_Primary:
				{
					TF2_WeaponFindAttribute(iWeapon, ATTRIB_AMMO_PRIMARY_HIDDEN, flOldAmmoScale);
					TF2Attrib_SetByDefIndex(iWeapon, ATTRIB_AMMO_PRIMARY_HIDDEN, flAmmoScale * flOldAmmoScale);
				}
				case WeaponSlot_Secondary:
				{
					TF2_WeaponFindAttribute(iWeapon, ATTRIB_AMMO_SECONDARY_HIDDEN, flOldAmmoScale);
					TF2Attrib_SetByDefIndex(iWeapon, ATTRIB_AMMO_SECONDARY_HIDDEN, flAmmoScale * flOldAmmoScale);
				}
			}
			
			//Refresh max ammo
			int iAmmo = SDK_GetMaxAmmo(iClient, iAmmoType);
			//PrintToChatAll("slot (%d) max ammo (%d) ammo type (%d)", iSlot, iAmmo, iAmmoType);
			SetEntProp(iClient, Prop_Send, "m_iAmmo", iAmmo, _, iAmmoType);
		}
	}
}

public Action Event_PlayerHurt(Event event, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	int iDamageAmount = event.GetInt("damageamount");
	
	if (iClient <= 0 || iClient > MaxClients || iAttacker <= 0 || iAttacker > MaxClients) return;
	if (GetClientTeam(iClient) <= 1 || GetClientTeam(iAttacker) <= 1) return;
	if (iClient == iAttacker) return;
	
	//Fill Gas Meter
	float flMeter = GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 1);
	if (0.0 < flMeter < 100.0)
	{
		flMeter += iDamageAmount / ITEM_GASPASSER_METER_DAMAGE * 100.0;
		if (flMeter > 100.0) flMeter = 100.0;
		SetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", flMeter, 1);
	}
}

public Action Event_PlayerDeath(Event event, const char[] sName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));
	int iAttacker = GetClientOfUserId(event.GetInt("attacker"));
	
	//Only generate new weapons if killed from attacker
	if (0 < iAttacker <= MaxClients && IsClientInGame(iAttacker) && iClient != iAttacker)
		RequestFrame(GenerateRandonWeapon, iClient);	//Can be buggy if done same frame as death
}

public void Client_OnThink(int iClient)
{
	char sDisplay[512];
	TFClassType iClass = TF2_GetPlayerClass(iClient);
	
	for (int iSlot = WeaponSlot_Primary; iSlot <= WeaponSlot_InvisWatch; iSlot++)
	{
		int iWeapon = TF2_GetItemInSlot(iClient, iSlot);
		
		if (IsValidEntity(iWeapon))
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
			
			//Go through every netprops/classname to see whenever if meter needs to be displayed
			//TODO config support
			int iMeter;
			float flMeter;
			char sClassname[256];
			GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
			
			//Bonk, Milk, Cleaver, Sandman, Wrap Assassin, Sandvich and Jarate
			if (HasEntProp(iWeapon, Prop_Send, "m_flEffectBarRegenTime"))
			{
				flMeter = GetEntPropFloat(iWeapon, Prop_Send, "m_flEffectBarRegenTime");
				flMeter -= GetGameTime();
				
				//Format(sDisplay, sizeof(sDisplay), "%s (%.8f)", sDisplay, flMeter);
				
				if (flMeter > 0.0)
					Format(sDisplay, sizeof(sDisplay), "%s: %.0f sec", sDisplay, flMeter);
			}
			
			//Cow Mangler, Bison and Pomson
			if (HasEntProp(iWeapon, Prop_Send, "m_flEnergy"))
			{
				flMeter = GetEntPropFloat(iWeapon, Prop_Send, "m_flEnergy") * 5.0;
				if (flMeter != 100.0)
				{
					Format(sDisplay, sizeof(sDisplay), "%s: %.0f%%%", sDisplay, flMeter);
				}
			}
			
			//Loose Cannon
			if (HasEntProp(iWeapon, Prop_Send, "m_flDetonateTime"))
			{
				flMeter = GetEntPropFloat(iWeapon, Prop_Send, "m_flDetonateTime");
				if (flMeter != 0.0)
				{
					flMeter -= GetGameTime();
					Format(sDisplay, sizeof(sDisplay), "%s: %.2fs", sDisplay, flMeter);
				}
			}
			
			//Stickybomb
			if (HasEntProp(iWeapon, Prop_Send, "m_iPipebombCount"))
			{
				iMeter = GetEntProp(iWeapon, Prop_Send, "m_iPipebombCount");
				Format(sDisplay, sizeof(sDisplay), "%s: %d Stickies", sDisplay, iMeter);
			}
			
			//Stickybomb and Huntsman
			if (HasEntProp(iWeapon, Prop_Send, "m_flChargeBeginTime"))
			{
				flMeter = GetEntPropFloat(iWeapon, Prop_Send, "m_flChargeBeginTime");
				if (flMeter != 0.0)
				{
					flMeter = (GetGameTime() - flMeter) * 100.0;
					if (flMeter > 100.0) flMeter = 100.0;
					Format(sDisplay, sizeof(sDisplay), "%s: %.0f%%%", sDisplay, flMeter);
				}
			}
			
			//Medigun (TODO Vaccinator support)
			if (HasEntProp(iWeapon, Prop_Send, "m_flChargeLevel"))
			{
				flMeter = GetEntPropFloat(iWeapon, Prop_Send, "m_flChargeLevel") * 100.0;
				Format(sDisplay, sizeof(sDisplay), "%s: %.0f%%%", sDisplay, flMeter);
			}
			
			//Banners, Phlogistinator and Hitman Heatmaker
			if (StrEqual(sClassname, "tf_weapon_buff_item") || StrEqual(sClassname, "tf_weapon_flamethrower") || StrEqual(sClassname, "tf_weapon_sniperrifle"))
			{
				flMeter = GetEntPropFloat(iClient, Prop_Send, "m_flRageMeter");
				if (flMeter > 0.0)
				{
					Format(sDisplay, sizeof(sDisplay), "%s: %.0f%%%", sDisplay, flMeter);
				}
			}
			
			//Airstrike, Eyelander and Bazzar Bargin
			if (StrEqual(sClassname, "tf_weapon_rocketlauncher_airstrike") || StrEqual(sClassname, "tf_weapon_sword") || StrEqual(sClassname, "tf_weapon_sniperrifle_decap"))
			{
				iMeter = GetEntProp(iClient, Prop_Send, "m_iDecapitations");
				if (iMeter > 0)
				{
					Format(sDisplay, sizeof(sDisplay), "%s: %d Head%s", sDisplay, iMeter, (iMeter > 1) ? "s" : "");
				}
			}
			
			//Manmelter and Frontier Justice (TODO diamondback)
			if (StrEqual(sClassname, "tf_weapon_flaregun_revenge") || StrEqual(sClassname, "tf_weapon_sentry_revenge"))
			{
				iMeter = GetEntProp(iClient, Prop_Send, "m_iRevengeCrits");
				if (iMeter > 0)
				{
					Format(sDisplay, sizeof(sDisplay), "%s: %d Crit%s", sDisplay, iMeter, (iMeter > 1) ? "s" : "");
				}
			}
			
			//Gas Passer
			if (StrEqual(sClassname, "tf_weapon_jar_gas"))
			{
				flMeter = GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter", 1);
				
				//Non-Pyros cant refill gas meter, fix that
				if (iClass != TFClass_Pyro)
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
				
				Format(sDisplay, sizeof(sDisplay), "%s: %.0f%%%", sDisplay, flMeter);
			}
			
			//Short Circuit, Wrench and Gunslinger (TODO widomaker)
			if (StrEqual(sClassname, "tf_weapon_mechanical_arm") || StrEqual(sClassname, "tf_weapon_wrench") || StrEqual(sClassname, "tf_weapon_robot_arm"))
			{
				iMeter = GetEntProp(iClient, Prop_Send, "m_iAmmo", _, 3);
				Format(sDisplay, sizeof(sDisplay), "%s: %d Metal", sDisplay, iMeter);
			}
			
			switch (iSlot)
			{
				case WeaponSlot_Primary:
				{
					//Soda Popper and Baby Face Blaster
					flMeter = GetEntPropFloat(iClient, Prop_Send, "m_flHypeMeter");
					if (flMeter > 0.0)
					{
						Format(sDisplay, sizeof(sDisplay), "%s: %.0f%%%", sDisplay, flMeter);
					}
				}
				case WeaponSlot_Secondary:
				{
					//Chargin Targe
					flMeter = GetEntPropFloat(iClient, Prop_Send, "m_flChargeMeter");
					if (flMeter != 100.0)
					{
						Format(sDisplay, sizeof(sDisplay), "%s: %.0f%%%", sDisplay, flMeter);
					}
					
					//Razorback
					flMeter = GetEntPropFloat(iClient, Prop_Send, "m_flItemChargeMeter");
					if (0.0 < flMeter < 100.0)
					{
						Format(sDisplay, sizeof(sDisplay), "%s: %.0f%%%", sDisplay, flMeter);
					}
				}
			}
			
			//TODO Spy-cicle
			//TODO Disguise
			//TODO Thermal Thruster (CTFRocketPack? m_flLastFireTime, m_flEffectBarRegenTime, m_flInitLaunchTime, m_flLaunchTime)
			//TODO Gas Passer (CTFJarGas? m_flEffectBarRegenTime? already here....)
		}
	}
	
	SetHudTextParams(0.2, 1.0, 0.20, 255, 255, 255, 255);
	ShowHudText(iClient, 0, sDisplay);
	
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

stock void Client_AddHealth(int iClient, int iAdditionalHeal, int iMaxOverHeal=0)
{
	int iMaxHealth = SDK_GetMaxHealth(iClient);
	int iHealth = GetEntProp(iClient, Prop_Send, "m_iHealth");
	int iTrueMaxHealth = iMaxHealth+iMaxOverHeal;

	if (iHealth < iTrueMaxHealth)
	{
		iHealth += iAdditionalHeal;
		if (iHealth > iTrueMaxHealth) iHealth = iTrueMaxHealth;
		SetEntProp(iClient, Prop_Send, "m_iHealth", iHealth);
	}
}

public Action Command_Weapon(int iClient, int iArgs)
{
	if (iArgs <= 1) return Plugin_Handled;
	
	char sArg1[256], sArg2[256];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));
	
	g_iClientWeaponIndex[iClient][StringToInt(sArg1)] = StringToInt(sArg2);
	
	return Plugin_Handled;
}

public void SDK_Init()
{
	Handle hGameData = LoadGameConfigFile("sdkhooks.games");
	if (hGameData == null) SetFailState("Could not find sdkhooks.games gamedata!");
	
	//Max health
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "GetMaxHealth");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetMaxHealth = EndPrepSDKCall();
	if(g_hSDKGetMaxHealth == null)
		LogMessage("Failed to create call: CTFPlayer::GetMaxHealth!");
	
	delete hGameData;
	
	hGameData = LoadGameConfigFile("sm-tf2.games");
	if (hGameData == null) SetFailState("Could not find sm-tf2.games gamedata!");
	
	int iRemoveWearableOffset = GameConfGetOffset(hGameData, "RemoveWearable");
	
	//Remove Wearable
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetVirtual(iRemoveWearableOffset);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKRemoveWearable = EndPrepSDKCall();
	if(g_hSDKRemoveWearable == null)
		LogMessage("Failed to create call: CBasePlayer::RemoveWearable!");
	
	//Equip Wearable
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetVirtual(iRemoveWearableOffset-1);//Equip Wearable is right behind Remove Wearable, should be good if valve dont add one between
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKEquipWearable = EndPrepSDKCall();
	if(g_hSDKEquipWearable == null)
		LogMessage("Failed to create call: CBasePlayer::EquipWearable!");
	
	delete hGameData;
	
	hGameData = LoadGameConfigFile("randomizer");
	if (hGameData == null) SetFailState("Could not find randomizer gamedata!");
	
	//Get Wearable
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::GetEquippedWearableForLoadoutSlot");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Pointer);
	g_hSDKGetWearable = EndPrepSDKCall();
	if(g_hSDKGetWearable == null)
		LogMessage("Failed to create call: CTFPlayer::GetEquippedWearableForLoadoutSlot!");
	
	//Get Max Ammo
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTFPlayer::GetMaxAmmo");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_hSDKGetMaxAmmo = EndPrepSDKCall();
	if(g_hSDKGetMaxAmmo == null)
		LogMessage("Failed to create call: CTFPlayer::GetMaxAmmo!");
}

stock int SDK_GetMaxHealth(int iClient)
{
	if (g_hSDKGetMaxHealth != null)
		return SDKCall(g_hSDKGetMaxHealth, iClient);
	return 0;
}

stock void SDK_RemoveWearable(int iClient, int iWearable)
{
	if(g_hSDKRemoveWearable != null)
		SDKCall(g_hSDKRemoveWearable, iClient, iWearable);
}

stock void SDK_EquipWearable(int iClient, int iWearable)
{
	if(g_hSDKEquipWearable != null)
		SDKCall(g_hSDKEquipWearable, iClient, iWearable);
}

stock int SDK_GetEquippedWearable(int iClient, int iSlot)
{
	if(g_hSDKGetWearable != null)
		return SDKCall(g_hSDKGetWearable, iClient, iSlot);
	
	return -1;
}

stock int SDK_GetMaxAmmo(int iClient, int iSlot, TFClassType iClass = TFClass_Unknown)
{
	if(g_hSDKGetMaxAmmo != null)
		return SDKCall(g_hSDKGetMaxAmmo, iClient, iSlot, -1);
	return -1;
}

stock int TF2_CreateAndEquipWeapon(int iClient, int iIndex)
{
	char sClassname[256];
	TF2Econ_GetItemClassName(iIndex, sClassname, sizeof(sClassname));
	TF2Econ_TranslateWeaponEntForClass(sClassname, sizeof(sClassname), TF2_GetPlayerClass(iClient));	//Will this break with class equipping any weapons?
	
	int iWeapon = CreateEntityByName(sClassname);
	
	if (IsValidEntity(iWeapon))
	{
		SetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex", iIndex);
		SetEntProp(iWeapon, Prop_Send, "m_bInitialized", 1);
		
		// Allow quality / level override by updating through the offset.
		char sNetClass[64];
		GetEntityNetClass(iWeapon, sNetClass, sizeof(sNetClass));
		SetEntData(iWeapon, FindSendPropInfo(sNetClass, "m_iEntityQuality"), 6);
		SetEntData(iWeapon, FindSendPropInfo(sNetClass, "m_iEntityLevel"), 1);
			
		SetEntProp(iWeapon, Prop_Send, "m_iEntityQuality", 6);
		SetEntProp(iWeapon, Prop_Send, "m_iEntityLevel", 1);
		
		DispatchSpawn(iWeapon);
		SetEntProp(iWeapon, Prop_Send, "m_bValidatedAttachedEntity", true);
		
		if (StrContains(sClassname, "tf_weapon") == 0)
		{
			EquipPlayerWeapon(iClient, iWeapon);
			
			//Not sure if this even works
			int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
			if (iAmmoType > -1)
			{
				int iAmmo = SDK_GetMaxAmmo(iClient, iAmmoType);
				SetEntProp(iClient, Prop_Send, "m_iAmmo", iAmmo, _, iAmmoType);
			}
		}
		else if (StrContains(sClassname, "tf_wearable") == 0)
		{
			SDK_EquipWearable(iClient, iWeapon);
		}
		else
		{
			AcceptEntityInput(iWeapon, "Kill");
			return -1;
		}
	}
	else
	{
		PrintToChatAll("Unable to create weapon for client (%N), class (%d), classname (%s)", iClient, TF2_GetPlayerClass(iClient), sClassname);
		LogError("Unable to create weapon for client (%N), class (%d), classname (%s)", iClient, TF2_GetPlayerClass(iClient), sClassname);
	}
	
	return iWeapon;
}

stock bool TF2_WeaponFindAttribute(int iWeapon, int iAttrib, float &flVal)
{
	Address addAttrib = TF2Attrib_GetByDefIndex(iWeapon, iAttrib);
	if (addAttrib == Address_Null)
	{
		int iItemDefIndex = GetEntProp(iWeapon, Prop_Send, "m_iItemDefinitionIndex");
		int iAttributes[16];
		float flAttribValues[16];

		int iMaxAttrib = TF2Attrib_GetStaticAttribs(iItemDefIndex, iAttributes, flAttribValues);
		for (int i = 0; i < iMaxAttrib; i++)
		{
			if (iAttributes[i] == iAttrib)
			{
				flVal = flAttribValues[i];
				return true;
			}
		}
		return false;
	}
	flVal = TF2Attrib_GetValue(addAttrib);
	return true;
}

stock int TF2_GetItemInSlot(int iClient, int iSlot)
{
	int iWeapon = GetPlayerWeaponSlot(iClient, iSlot);
	if (!IsValidEdict(iWeapon))
	{
		//If weapon not found in slot, check if it a wearable
		int iWearable = SDK_GetEquippedWearable(iClient, iSlot);
		if (IsValidEdict(iWearable))
			iWeapon = iWearable;
	}
	
	return iWeapon;
}

stock int TF2_GetSlotFromWeapon(int iClient, int iWeapon)
{
	for (int iSlot = 0; iSlot <= WeaponSlot_BuilderEngie; iSlot++)
		if (iWeapon == TF2_GetItemInSlot(iClient, iSlot))
			return iSlot;
	
	return -1;
}

stock void TF2_RemoveItemInSlot(int client, int slot)
{
	TF2_RemoveWeaponSlot(client, slot);

	int iWearable = SDK_GetEquippedWearable(client, slot);
	if (iWearable > MaxClients)
	{
		SDK_RemoveWearable(client, iWearable);
		AcceptEntityInput(iWearable, "Kill");
	}
}

stock int TF2_GetCurrentAmmo(int iWeapon)
{
	if (!HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType")) return -1;

	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if (iAmmoType == -1) return -1;
	
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity"); 
	return GetEntProp(iClient, Prop_Send, "m_iAmmo", _, iAmmoType);
}

stock void TF2_SetAmmo(int iWeapon, int iAmmo)
{
	if (!HasEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType")) return;

	int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType");
	if (iAmmoType == -1) return;
	
	int iClient = GetEntPropEnt(iWeapon, Prop_Send, "m_hOwnerEntity"); 
	SetEntProp(iClient, Prop_Send, "m_iAmmo", iAmmo, _, iAmmoType);
}