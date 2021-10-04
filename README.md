# Randomizer  [![Action Status](https://github.com/FortyTwoFortyTwo/Randomizer/workflows/Package/badge.svg)](https://github.com/FortyTwoFortyTwo/Randomizer/actions?query=workflow%3APackage+branch%3Amaster)

TF2 Gamemode where everyone plays as random class with random weapons, a rewritten of [TF2Items randomizer](https://forums.alliedmods.net/showthread.php?p=1308831).

## ConVars
- `randomizer_version`: Plugin version number, don't touch.
- `randomizer_enabled`: Enable/Disable entire randomizer plugin, another option for load/unload plugins.
- `randomizer_class`: How should class be randomized.
- `randomizer_weapons`: How should weapons be randomized.
- `randomizer_cosmetics`: How should cosmetics be randomized.
- `randomizer_rune`: How should mannpower rune be randomized.
- `randomizer_spells`: How should halloween spells be randomized.
- `randomizer_droppedweapons`: Enable/Disable dropped weapons.
- `randomizer_huds`: Mode to display weapons from hud.
  - 0: No hud display
  - 1: Hud text
  - 2: Menu

For the convars that enables randomizations, several parameters can be set on how it should be randomized:
- `trigger`: Who can trigger the reroll.
- `group`: Group of players that will get rerolled.
- `reroll`: How triggered player can reroll loadout.
- `same`: Whenever everyone in group can get same loadout. (Does not work on cosmetics)
- `count`: How many items at a minimum to give. (weapons and cosmetics only)
- `count-primary`: How many primary items at a minimum to give. (weapons only)
- `count-secondary`: How many secondary items at a minimum to give. (weapons only)
- `count-melee`: How many melee items at a minimum to give. (weapons only)
- `defaultclass`: Whenever items to give is only for default classes. (weapons only)
- `conflicts`: Whenever to not generate item that conflicts with equipped items. (cosmetics only)

List of possible ways to reroll loadout using `reroll` param:
- `death`: Non-environment death
- `environment`: Environment death
- `suicide`: Suicide death
- `kill`: Player kill
- `assist`: Player assist
- `round`: Round start
- `fullround`: Full round start
- `capture`: Control point or flag capture

Examples:
- `randomizer_class "trigger=@all group=@me reroll=kill reroll=assist"`: Everyone's player kill or assist would reroll it's class.
- `randomizer_weapons "trigger=@all group=@me reroll=death reroll=round count-primary=1 count-secondary=1 count-melee=1"`: Everyone's death from player kill or round start would reroll it's weapons, one weapon for each slot.
- `randomizer_cosmetics "trigger=@blue group=@blue reroll=death reroll=environment reroll=suicide count=5"`: Everyone in blue team on any deaths would reroll it's cosmetics, having 5 total cosmetics equipped.
- `randomizer_rune "trigger=@humans group=@bots reroll=capture same=1"`: Every humans on capture would reroll all bot's mannpower runes to have same rune.
- `randomizer_spells "trigger=@red group=@blue reroll=death, trigger=@blue group=@red reroll=capture"`: On any red team's death, blue team spells is rerolled. And on blue team's capture, red team spells is rerolled.

## Commands
- `sm_cantsee`: Set your active weapon transparent or fully visible, for everyone
- `sm_rndclass`: Set specified player a given class, admin only
- `sm_rndsetweapon`: Replaces specified player all weapons to given weapons
- `sm_rndsetslotweapon`: Replaces specified player weapons to given weapons based on slot
- `sm_rndgiveweapon`: Gives specified player weapons
- `sm_rndgenerate`: Rerolls specified player class and weapon def index

Examples on parameters that is valid to use for `sm_rndsetweapon`, `sm_rndsetslotweapon` and `sm_rndgiveweapon`:
- `220` for Shortstop (item def index)
- `direct hit` for Direct Hit (name based in translations)
- `backburner, loch, 424` for Backburner, Loch-n-Load and Tomislav
- `primary shotgun, secondary panic attack` for Shotgun from primary slot and Panic Attack from secondary slot

## Configs
There currently 5 [configs](https://github.com/FortyTwoFortyTwo/Randomizer/tree/master/configs/randomizer) able to easily change for future TF2 updates:
- `controls.cfg`: Manages how weapons with `attack2` passive button should be handled, should it be `attack3` or `reload` instead.
- `huds.cfg`: Lists all of the netprop meters to display in hud for many weapons.
- `reskins.cfg`: List of reskins for players to equip weapon from loadout instead of default weapon.
- `viewmodels.cfg`: List of all weapons with class specified to set transparent by default, without needing to use `sm_cantsee` on weapon that covers player screen everytime.
- `weapons.cfg`: Whitelist of weapon indexs to select from random pool, along with weapon name to display in HUD.

## Builds
All builds can be found [here](https://github.com/FortyTwoFortyTwo/Randomizer/actions?query=workflow%3APackage+branch%3Amaster).
To download latest build version, select latest package then "Artifacts" section underneath.

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