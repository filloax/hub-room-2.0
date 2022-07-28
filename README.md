# Hub room 2.0

## What is it?

Hub room 2.0 is a library which mods can integrate into their files to expand the floor transition room introduced in Repentance. The transition room will be turned into a hub room with a different background and space for additional trapdoors. This allows multiple mods to add paths towards their own custom floors in the hub rooms without worrying about running out of space. The hub room generates trapdoors for each additional floor added on each side of the room. If the hub runs out of space it will simply branch out to additional rooms allowing for unlimited unique paths.

The hub has the same enter costs as the regular transition room and contains 4 statues of playable characters which the player can blow up for potential rewards. Mods are able to add statues of their own custom characters to the roster.

## Requirements

[Stage api] (https://steamcommunity.com/workshop/filedetails/?id=1348031964) is required for hub 2.0 to work. Make sure StageAPI is loaded before requiring hub 2.0!

## Integrating hub room 2.0 into your mod

Integrating hub room 2.0 is quite straighforward. The resources and scripts folder can directly be copied into your mod. The content folder contains a music.xml file. If your mod already has a music.xml file, copy the entry "Hub Room 2.0" into your music.xml file. If not, you can directly copy the content folder into yours.

To activate and begin making use of hub room 2.0, you will have to require it like this:

```lua
local hub2 = require("scripts.hubroom2.init")
```

## Hub room 2.0 savedata

Hub room 2.0 has its own savedata which it automatically saves and loads. This is undesirable behaviour if your mod has savedata of its own.

To stop hub room 2.0 from saving and loading its savedata, you can call the following method after requiring hub 2.0:

```lua
hub2.SetDisableSaving(true)
```

To still have the savedata of hub room 2.0 work correctly, it is recommended to put it in your own savedata. When saving savedata, get the savedata table of hub 2.0 with ``hub2.GetSaveData()`` and add it to your own savedata. When loading savedata (if it contains hub 2.0 savedata), load the hub 2.0 savedata into hub 2.0 using ``hub2.LoadSaveData(newSaveTable)``

## Usage

### Adding hub room 2.0 to your custom stage

Custom stages do not naturally have hub 2.0 enabled. You can enable it with the following method:

```lua
hub2.AddHub2ToCustomStage(stage, quadPng, levelStage)
```

  - ``stage``:  StageAPI stage object. Which custom stage you are targeting.
  - ``quadPng``: String. Path towards quad image of your custom stage. See "gfx/backdrop/hubroom_2.0/hubquads/" for references.
  - ``levelStage``: LevelStage enum. Which LevelStage hub 2.0 should see your stage as. Matters for which rep/vanilla trapdoors it contains.

### Adding your custom stage trapdoor into hub room 2.0

Naturally none of the hub rooms contain trapdoors to custom stages. They can be added with the following method:

```lua
hub2.AddCustomStageToHub2(stage, quadPng, trapdoorAnm2, trapdoorSize, stageConditions, addHub2ToStage, levelStage)
```

  - ``stage``:  StageAPI stage object. Which custom stage you are targeting.
  - ``quadPng``: String. Path towards quad image of your custom stage. See "gfx/backdrop/hubroom_2.0/hubquads/" for references.
  - ``trapdoorAnm2``: String. Path towards the .anm2 of the trapdoor. Optional.
  - ``trapdoorSize``: Number. Size of the trapdoor. Optional.
  - ``stageConditions``: Function. Called when a hub room is generated. Return true if the trapdoor towards the custom stage should generate. If not filled in, it will always return true.
  - ``addHub2ToStage``: Boolean. Additionally adds hub room 2.0 to the custom stage if true. Optional.
  - ``levelStage``: LevelStage enum. Which LevelStage hub 2.0 should see your stage as. Matters for which rep/vanilla trapdoors it contains. Only optional if ``addHub2ToStage`` is not true.

In ``stageConditions`` it is recommended to use ``hub2.GetCorrectedLevelStage()`` instead of the regular ``level:GetStage()`` when checking for LevelStage. This takes into account specific LevelStages specified for custom floors and XLL floors.

### Adding additional statues to hub room 2.0

The following method adds a new statue to hub room 2.0:

```lua
hub2.AddHub2Statue(statueData)
```

  - ``statueData``: Table. Contains statue info:

    - ``StatueAnm2``: String. Path towards the .anm2 of the statue.
	- ``StatueAnimation``: String. Animation name of the statue. Takes default animation if not set.
	
	- ``AltStatueAnm2``: String. Path towards the .anm2 of the alt variation of the statue. Optional.
	- ``AltStatueAnimation``: String. Animation name of the alt variation of the statue. Takes default animation if not set. Optional.
	- ``AltConditions``: Function. Returns true if the statue should be its alt variation. If not set the statue will not have an alt variation. Optional.
	
	- ``TrinketDrop``: TrinketType Enum. Default drop normally, if set, unlocked en not encountered already by the player. Optional.
	- ``SoulDrop``: Card Enum. Rare drop. 20% chance on top of the 25% to drop if set and unlocked by the player. Optional.
	- ``ConsumableCount``: Integer. the number of ConsumableDrop (field below) drops. Optional.
	- ``ConsumableDrop``: {Variant = PickupVariant Enum, SubType = Integer}. Variant and SubType can be left blank for randomizing the consumable. Optional.
	- ``WispCount``: Integer. Statue drops a number of wisps as consumables drop. Optional.
	- ``FlyCount``: Integer. Statue drops a number of blue flies as consumables drop. Optional.
	- ``SpiderCount``: Integer. Statue drops a number of blue spiders as consumables drop. Optional.

Statues currently have a 25% chance of dropping something when bombed.
