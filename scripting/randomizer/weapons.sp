#define ITEM_GASPASSER_METER_TIME		60.0
#define ITEM_GASPASSER_METER_DAMAGE		750.0

static float g_flClientPreviousThink[TF_MAXPLAYERS];

public void Weapons_ClientThink(int iClient)
{
	TFClassType nClass = TF2_GetPlayerClass(iClient);
	int iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");
	if (iWeapon <= MaxClients) return;
	
	char sClassname[256];
	GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
	
	//Gas Passer
	if (StrEqual(sClassname, "tf_weapon_jar_gas"))
	{
		//Non-Pyros cant refill gas meter, fix that
		if (nClass != TFClass_Pyro)
		{
			float flTimeGap = GetGameTime() - g_flClientPreviousThink[iClient];
			float flMeter = GetEntPropFloat(iWeapon, Prop_Send, "m_flEffectBarRegenTime");
			flMeter -= GetGameTime();
			
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