public void Hud_ClientDisplay(int iClient)
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
}