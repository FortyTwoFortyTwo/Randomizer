# Randomizer  [![Action Status](https://github.com/FortyTwoFortyTwo/Randomizer/workflows/Package/badge.svg)](https://github.com/FortyTwoFortyTwo/Randomizer/actions?query=workflow%3APackage+branch%3Amaster)

Team Fortress 2 plugin that randomizes player loadout in any imaginable combinations, a rewritten of [TF2Items randomizer](https://forums.alliedmods.net/showthread.php?p=1308831).
Supports all TF2 stock gamemodes excluding Mann Vs Machine, allow servers using ConVars to randomize specific players by whatever loadouts from whatever events.

## Builds
All builds can be found [here](https://github.com/FortyTwoFortyTwo/Randomizer/actions?query=workflow%3APackage+branch%3Amaster).
To download latest build version, select latest package then "Artifacts" section underneath.

## Requirements
- SourceMod 1.11
- [tf2attributes](https://forums.alliedmods.net/showthread.php?t=210221)
- [tf_econ_data](https://forums.alliedmods.net/showthread.php?t=315011)

## ConVars
- `randomizer_version`: Plugin version number, don't touch.
- `randomizer_enabled`: Enable/Disable entire randomizer plugin, another option for load/unload plugins.
- `randomizer_debug`: Enable/Disable debugging infos, not recommended to enable it.
- `randomizer_class`: How should class be randomized.
- `randomizer_weapons`: How should weapons be randomized.
- `randomizer_cosmetics`: How should cosmetics be randomized.
- `randomizer_rune`: How should mannpower rune be randomized.
- `randomizer_spells`: How should halloween spells be randomized.
- `randomizer_droppedweapons`: Enable/Disable dropped weapons.
- `randomizer_fix_taunt`: Enable/Disable `CTFPlayer::Taunt` detour fix.
- `randomizer_huds`: Mode to display weapons from hud.
  - 0: No hud display
  - 1: Hud text
  - 2: Menu

For the convars that enables randomizations, several parameters can be set on how it should be randomized:
- `trigger`: Who can trigger the reroll.
- `group`: Group of players that will get rerolled.
- `action`: How triggered player can reroll loadout.
- `same`: Whenever everyone in group can get same loadout. (Does not work on cosmetics)
- `count`: How many items at a minimum to give. (weapons and cosmetics only)
- `count-primary`: How many primary items at a minimum to give. (weapons only)
- `count-secondary`: How many secondary items at a minimum to give. (weapons only)
- `count-melee`: How many melee items at a minimum to give. (weapons only)
- `defaultclass`: Whenever items to give is only for default classes. (weapons only)
- `conflicts`: Whenever to not generate item that conflicts with equipped items. (cosmetics only)

List of possible ways to reroll loadout using `reroll` param:
- `death`: Any deaths
- `death-kill`: Death from player kill
- `death-env`: Death from environment
- `death-suicide`: Death from suicide
- `kill`: Player kill
- `assist`: Player assist
- `round`: Round start
- `round-full`: Full round start
- `cp-capture`: Control point capture
- `flag-capture`: Flag capture
- `pass-score`: Passtime score

Examples:
- `randomizer_class "trigger=@all group=@me action=kill action=assist"`: Everyone's player kill or assist would reroll it's class.
- `randomizer_weapons "trigger=@all group=@me action=death-kill action=round count-primary=1 count-secondary=1 count-melee=1"`: Everyone's death from player kill or round start would reroll it's weapons, one weapon for each slot.
- `randomizer_cosmetics "trigger=@blue group=@blue action=death count=5"`: Everyone in blue team on any deaths would reroll it's cosmetics, having 5 total cosmetics equipped.
- `randomizer_rune "trigger=@humans group=@bots action=cp-capture same=1"`: Every humans on capture would reroll all bot's mannpower runes to have same rune.
- `randomizer_spells "trigger=@red group=@blue action=death, trigger=@blue group=@red action=cp-capture"`: On any red team's death, blue team spells is rerolled. And on blue team's capture, red team spells is rerolled.

## Commands
- `sm_rndclass`: Set specified player a given class, admin only
- `sm_rndsetweapon`: Replaces specified player all weapons to given weapons
- `sm_rndsetslotweapon`: Replaces specified player weapons to given weapons based on slot
- `sm_rndgiveweapon`: Gives specified player weapons
- `sm_rndrune`: Set specified player a rune type
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
- `weapons.cfg`: Whitelist of weapon indexs to select from random pool, along with weapon name to display in HUD.

## TF2 Updates
This plugin itself aims to not not require modifications when valve releases TF2 updates.
Gamedatas is likely to break if TF2 update were to also break other plugin's gamedata (e.g. TF2Items).
If weapon additions or rebalances were to happen, it's possible configs need an update, or possibly even plugin itself if TF2 update were to make changes only work for one class.