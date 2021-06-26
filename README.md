# Randomizer  [![Action Status](https://github.com/FortyTwoFortyTwo/Randomizer/workflows/Package/badge.svg)](https://github.com/FortyTwoFortyTwo/Randomizer/actions?query=workflow%3APackage+branch%3Amaster)

TF2 Gamemode where everyone plays as random class with random weapons, a rewritten of [TF2Items randomizer](https://forums.alliedmods.net/showthread.php?p=1308831).

## ConVars
- `randomizer_version`: Plugin version number, don't touch.
- `randomizer_enabled`: Enable/Disable entire randomizer plugin, another option for load/unload plugins.
- `randomizer_droppedweapons`: Enable/Disable dropped weapons.
- `randomizer_huds`: Enable/Disable weapon huds.
- `randomizer_weaponsfromclass`: Whenever generated weapon should only be whatever class can normally equip.
- `randomizer_randomclass`/`randomizer_randomweapons`: Modes to change player class/weapon randomization.
  - 0: No randomizes, allowing players to freely change class/weapon themself
  - 1: Randomizes on death
  - 2: Randomizes on new round
  - 3: Every team get same class/weapon randomizes every round
  - 4: Everyone get same class/weapon randomizes every round
- `randomizer_teamclass`/`randomizer_teamweapons`: Teams to randomize class/weapon.
  - 1: Both teams
  - 2: Only red team
  - 3: Only blu team

## Commands
- `sm_cantsee`: Set your active weapon transparent or fully visible, for everyone
- `sm_rndclass`: Set specified player a given class, admin only
- `sm_rndweapon`: Set specified player a given weapon def index at given slot, admin only
- `sm_rndgenerate`: Rerolls given player class and weapon def index

## Builds
All builds can be found [here](https://github.com/FortyTwoFortyTwo/Randomizer/actions?query=workflow%3APackage+branch%3Amaster).
To download latest build version, select latest package then "Artifacts" button at top right.

## Requirements
- SourceMod 1.10
- [tf2attributes](https://forums.alliedmods.net/showthread.php?t=210221)
- [tf_econ_data](https://forums.alliedmods.net/showthread.php?t=315011)
- [dhooks with detour support](https://forums.alliedmods.net/showpost.php?p=2588686&postcount=589)

## TF2 Major Updates
Whenever valve releases a major TF2 update, this gamemode expects to:
- Require gamedata update for several SDK call/hooks
- Update configs and translations for any possible weapon balance changes for HUD meter, or adding new TF2 weapons
- Not require any SP plugin update/changes (hopefully)

## Configs
There currently 5 [configs](https://github.com/FortyTwoFortyTwo/Randomizer/tree/master/configs/randomizer) able to easily change for future TF2 updates:
- `controls.cfg`: Manages how weapons with `attack2` passive button should be handled, should it be `attack3` or `reload` instead.
- `huds.cfg`: Lists all of the netprop meters to display in hud for many weapons.
- `reskins.cfg`: List of reskins for players to equip weapon from loadout instead of default weapon.
- `viewmodels.cfg`: List of all weapons with class specified to set transparent by default, without needing to use `sm_cantsee` on weapon that covers player screen everytime.
- `weapons.cfg`: Whitelist of weapon indexs to select from random pool, along with weapon name to display in HUD.