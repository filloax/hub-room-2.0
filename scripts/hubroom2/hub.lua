local hub2 = require "scripts.hubroom2"

local game = Game()
local music = MusicManager()

hub2.CustomStagesInHub2 = {}
hub2.CustomStagesContainingHub2 = {}

-- all params except stage are optional. 
-- stageConditions gets called upon first entering hub2.0 for the first time each level. Returning true will add the stage to that hub2.0
function hub2.AddCustomStageToHub2(stage, quadPng, trapdoorAnm2, trapdoorSize, stageConditions, addHub2ToStage, levelStage)
	local quad = quadPng or "gfx/backdrop/hubroom_2.0/hubquads/closet_quad.png"
	
	table.insert(hub2.CustomStagesInHub2, {
		Stage = stage,
		QuadPng = quad,
		TrapdoorAnm2 = trapdoorAnm2 or "gfx/grid/door_11_trapdoor.anm2",
		TrapdoorSize = trapdoorSize,
		Conditions = stageConditions,
		DisableTrapdoor = stage == nil
	})
	
	if addHub2ToStage and stage then
		hub2.AddHub2ToCustomStage(stage, quad, levelStage)
	end
end

function hub2.AddHub2ToCustomStage(stage, quadPng, levelStage)
	hub2.CustomStagesContainingHub2[stage.Name] = {
		QuadPng = quadPng,
		LevelStage = levelStage
	}
end

function hub2.IsRepStage()
	local stageType = game:GetLevel():GetStageType()
	
	return stageType == StageType.STAGETYPE_REPENTANCE or stageType == StageType.STAGETYPE_REPENTANCE_B
end

local tombMausoleumDoorPayments = 0

local function mausoleumDoorUpdate(door, isInit)
	local sprite = door:GetSprite()
	
	if isInit then
		local anim = sprite:GetAnimation()
		
		sprite:Load(hub2.RepHub2Doors.Mausoleum, true)

		if door:IsLocked() then
			door:TryUnlock(Isaac.GetPlayer(0), true)
		end
		
		if tombMausoleumDoorPayments < 2 then
			door.CollisionClass = GridCollisionClass.COLLISION_WALL
			sprite:SetFrame("KeyClosed", 0)
			
		else
			sprite:SetFrame("Opened", 0)
		end
	end
	
	-- mausoleum door not fully paid yet
	if tombMausoleumDoorPayments < 2 then
		door.CollisionClass = GridCollisionClass.COLLISION_WALL
		
		local sprite = door:GetSprite()
		
		if not sprite:IsPlaying("Feed") then
			for i=0, game:GetNumPlayers() - 1 do
				local player = Isaac.GetPlayer(i)
				
				if player.Position:Distance(door.Position) <= 30 + player.Size then
					if player:TakeDamage(2, DamageFlag.DAMAGE_RED_HEARTS, EntityRef(player), 0) then
						tombMausoleumDoorPayments = tombMausoleumDoorPayments + 1
						
						if tombMausoleumDoorPayments == 2 then
							sprite:Play("KeyOpen", true)
							door.CollisionClass = GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER
						else
							sprite:Play("Feed", true)
						end
					end
				end
			end
		end
	end
end

function hub2.IsTransitionRoom()
	-- Rooms of RoomType 27 are alt-path transition rooms (not present in RoomType enum)
	local altpathTransitionRoomType = 27
	return game:GetRoom():GetType() == altpathTransitionRoomType
end

local checkedOutDoorSlots = {}
function hub2.UpdateHub2Doors()
	local room = game:GetRoom()
	local level = game:GetLevel()
	
	if room:GetType() == RoomType.ROOM_BOSS or hub2.IsTransitionRoom() then
		local levelStage = hub2.GetCorrectedLevelStage()
		
		-- mausoleum door (instead of mines door)
		if StageAPI.InNewStage() and levelStage == LevelStage.STAGE3_1 then
			for slot=DoorSlot.LEFT0, DoorSlot.DOWN1 do
				local door = room:GetDoor(slot)
				
				if door then
					if door.TargetRoomType == 27 then
						hub2.Hub2BossRoomIndex = level:GetCurrentRoomIndex()
						
						if not checkedOutDoorSlots[slot] then
							mausoleumDoorUpdate(door, true)
							checkedOutDoorSlots[slot] = true
							
						else
							mausoleumDoorUpdate(door, false)
						end
						
					elseif room:GetType() == 27 then
						local sprite = door:GetSprite()
						local anim = sprite:GetAnimation()
		
						sprite:Load(hub2.RepHub2Doors.Mausoleum, true)
						sprite:Play(anim, true)
						sprite:SetLastFrame()

						if door:IsLocked() then
							door:TryUnlock(Isaac.GetPlayer(0), true)
						end
					end
				end
			end
			
		else
			for slot=DoorSlot.LEFT0, DoorSlot.DOWN1 do
				local door = room:GetDoor(slot)
				
				if door then
					if (door.TargetRoomType == 27 or room:GetType() == 27) and not checkedOutDoorSlots[slot] then
						if StageAPI.InNewStage() and levelStage%2 == 0 or not door:IsLocked() then
							local stageName = hub2.RepHub2Quads[levelStage]:gsub("^%l", string.upper)
							
							local anim = door:GetSprite():GetAnimation()
							
							door:GetSprite():Load(hub2.RepHub2Doors[stageName], true)
							door:GetSprite():Play(anim, true)
							door:GetSprite():SetLastFrame()
							
							if door:IsLocked() then
								door:TryUnlock(Isaac.GetPlayer(0), true)
							end
						end
						
						checkedOutDoorSlots[slot] = true
					end
				end
			end
		end
	end
end

function hub2.GetCorrectedLevelStage()
	local level = game:GetLevel()
	local levelStage = level:GetAbsoluteStage()
	
	if hub2.HasBit(level:GetCurses(), LevelCurse.CURSE_OF_LABYRINTH) then
		levelStage = levelStage + 1
	end
	
	if StageAPI.InNewStage() then
		local stage = StageAPI.GetCurrentStage()
		
		if hub2.CustomStagesContainingHub2[stage.Name] and hub2.CustomStagesContainingHub2[stage.Name].LevelStage then
			levelStage = hub2.CustomStagesContainingHub2[stage.Name].LevelStage
		end

	elseif hub2.IsRepStage() then
		levelStage = levelStage + 1
	end
	
	return levelStage
end

local hub2EmptyRoomList = StageAPI.RoomsList("Hub2.0_RoomList", {StageAPI.CreateEmptyRoomLayout(RoomShape.ROOMSHAPE_1x1)})

local function generateHub2Layout(levelStage, entranceDoorSlot)
	local level = game:GetLevel()
	
	local hub2Slots
	if StageAPI.InNewStage() then
		local stage = StageAPI.GetCurrentStage()
		if levelStage%2 == 0 then -- first floor
			hub2Slots = {
				{
					[entranceDoorSlot] = {
						Quad = hub2.CustomStagesContainingHub2[stage.Name].QuadPng,
						BossDoor = true
					},
					[(entranceDoorSlot+1)%4] = {
						Quad = hub2.VanillaHub2Quads[levelStage + 1],
						Trapdoor = "vanilla"
					},
					[(entranceDoorSlot+3)%4] = {
						Quad = hub2.RepHub2Quads[levelStage],
						Trapdoor = "rep"
					}
				}
			}
		else -- second floor
			hub2Slots = {
				{
					[entranceDoorSlot] = {
						Quad = hub2.CustomStagesContainingHub2[stage.Name].QuadPng,
						BossDoor = true
					},
					[(entranceDoorSlot+1)%4] = {
						Quad = hub2.RepHub2Quads[levelStage],
						Trapdoor = "rep"
					}
				}
			}

		end
	
	elseif hub2.IsRepStage() then
		hub2Slots = {
			{
				[entranceDoorSlot] = {
					Quad = hub2.RepHub2Quads[levelStage],
					BossDoor = true
				},
				[(entranceDoorSlot+1)%4] = {
					Quad = hub2.RepHub2Quads[levelStage],
					Trapdoor = "rep"
				}
			}
		}
		
	else
		hub2Slots = {
			{
				[entranceDoorSlot] = {
					Quad = hub2.VanillaHub2Quads[levelStage],
					BossDoor = true
				},
				[(entranceDoorSlot+1)%4] = {
					Quad = hub2.RepHub2Quads[levelStage],
					Trapdoor = "rep"
				}
			}
		}
	end
	
	hub2.Hub2MainChamberRoomIndex = level:GetCurrentRoomIndex()
	
	local customStagesToAdd = {}
	for _,customStage in ipairs(hub2.CustomStagesInHub2) do
		if not customStage.Conditions or customStage.Conditions() then
			table.insert(customStagesToAdd, customStage)
		end
	end
	
	local numChambers = math.floor((#customStagesToAdd + 2)/2)
	for chamberId=1, numChambers do
		if not hub2Slots[chamberId] then
			hub2Slots[chamberId] = {}
		end
		
		-- add doors to previous chambers
		if chamberId ~= 1 and not hub2Slots[chamberId][entranceDoorSlot] then
			hub2Slots[chamberId][entranceDoorSlot] = {
				Quad = "closet",
				Door = chamberId - 1
			}
		end
		
		-- add doors to upcoming chambers
		if chamberId ~= numChambers and not hub2Slots[chamberId][(entranceDoorSlot+2)%4] then
			hub2Slots[chamberId][(entranceDoorSlot+2)%4] = {
				Quad = "closet",
				Door = chamberId + 1
			}
		end
		
		-- setup LevelRoom
		if chamberId ~= 1 then
			local chamber = StageAPI.LevelRoom(
				nil, 
				hub2EmptyRoomList,
				nil, 
				RoomShape.ROOMSHAPE_1x1, 
				"Hub2.0_Chamber_" .. tostring(chamberId), 
				chamberId ~= 1
			)
			StageAPI.GetDefaultLevelMap():AddRoom(chamber, {RoomID = "Hub2.0_Chamber_" .. tostring(chamberId)})
		end
	end
	
	for _,customStage in ipairs(customStagesToAdd) do
		for _,hubChamber in ipairs(hub2Slots) do
			local addQuad = false
			for slot=DoorSlot.LEFT0, DoorSlot.DOWN0 do
				if not hubChamber[slot] then
					hubChamber[slot] = customStage
					addQuad = true
					break
				end
			end
			
			if addQuad then
				break
			end
		end
	end
	
	-- empty quads get changed into empty closet quads
	for _,hubChamber in ipairs(hub2Slots) do
		for slot=DoorSlot.LEFT0, DoorSlot.DOWN0 do
			if not hubChamber[slot] then
				hubChamber[slot] = {
					Quad = "closet"
				}
			end
		end
	end
	
	return hub2Slots
end

StageAPI.AddCallback("Hub2.0", "POST_STAGEAPI_NEW_ROOM", 1, function()
	local level = game:GetLevel()
	local room = game:GetRoom()
	
	for _,eff in ipairs(hub2.Hub2StatueEffects) do
		eff:Remove()
	end
	hub2.Hub2StatueEffects = {}
	checkedOutDoorSlots = {}
	
	if room:GetType() == RoomType.ROOM_BOSS then
		hub2.Hub2BossRoomIndex = level:GetCurrentRoomIndex()
	end
	
	if hub2.data.isHub2Active and level:GetAbsoluteStage() < LevelStage.STAGE3_2 then
		-- Rooms of RoomType 27 are alt-path transition rooms (not present in RoomType enum)
		if room:GetType() == 27 then
			hub2.CurrentSelectedHub2ChamberId = 1
			
			hub2.TransformRoomToHub2()
			
		else
			local currentRoom = StageAPI.GetCurrentRoom()
			local prefix = "Hub2.0_Chamber_"
			if currentRoom and type(currentRoom.RoomType) == "string" 
					and currentRoom.RoomType:sub(1, prefix:len()) == prefix then

				local chamberIdStr = currentRoom.RoomType:gsub(prefix, "")
				hub2.CurrentSelectedHub2ChamberId = tonumber(chamberIdStr)
				
				hub2.Hub2EnteredBackChambers = true
				
				hub2.TransformRoomToHub2()
			end
		end
		
		hub2.UpdateHub2Doors()
	end
end)

hub2:AddCallback(ModCallbacks.MC_POST_RENDER, function()
	if hub2.IsTransitionRoom() then
		local musicId = music:GetCurrentMusicID()

		if StageAPI.CanOverrideMusic(musicId) -- hub room music makes this returns false, among others
		or musicId == Music.MUSIC_JINGLE_BOSS_OVER or musicId == Music.MUSIC_JINGLE_BOSS_OVER2 then
			music:Play(hub2.SFX.HUB_ROOM, 0)
			music:UpdateVolume()
		end
	end
end)

hub2:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function()
	hub2.Hub2Slots = nil
	hub2.Hub2EnteredBackChambers = false
	hub2.CurrentSelectedHub2ChamberId = 1
	tombMausoleumDoorPayments = 0
end)

function hub2.TransformRoomToHub2()
	local room = game:GetRoom()
	local isFirstVisit = room:IsFirstVisit()
	local levelStage = hub2.GetCorrectedLevelStage()
	
	-- fix for fireplaces invisibly staying and blocking new grids from spawning
	for _,ent in ipairs(Isaac.FindByType(EntityType.ENTITY_FIREPLACE)) do
		ent:Die()
		ent:Update()
	end
	
	-- remove old room layout
	StageAPI.ClearRoomLayout(false, true, true, isFirstVisit)

	local entranceDoorSlot
	for slot=DoorSlot.LEFT0, DoorSlot.DOWN0 do
		if room:GetDoor(slot) then
			entranceDoorSlot = slot
			break
		end
	end
	
	if not hub2.Hub2Slots then
		hub2.Hub2Slots = generateHub2Layout(levelStage, entranceDoorSlot)
	end
	
	local currentHubChamber = hub2.Hub2Slots[hub2.CurrentSelectedHub2ChamberId]
	hub2.SetUpHub2Background(currentHubChamber)
	
	if hub2.Hub2EnteredBackChambers then
		for slot=DoorSlot.LEFT0, DoorSlot.DOWN0 do
			room:RemoveDoor(slot)
		end
	end
	
	-- spawn new trapdoors
	for slot=DoorSlot.LEFT0, DoorSlot.DOWN0 do
		--[[if hub2Slots[slot].Trapdoor == "rep" then
			Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 0, room:GetGridPosition(hub2.Hub2TrapdoorSpots[slot]), true)
		]]
		if currentHubChamber[slot].Trapdoor or currentHubChamber[slot].TrapdoorAnm2 then
			local stageName
			if currentHubChamber[slot].Trapdoor == "rep" then
				stageName = hub2.RepHub2Quads[levelStage]:gsub("^%l", string.upper)
			end
			
			local trapdoor = hub2.Hub2CustomTrapdoors[stageName]
			
			local stage
			if currentHubChamber[slot].Stage then
				stage = currentHubChamber[slot].Stage
				
			else
				stage = {
					NormalStage = true,
					Stage = currentHubChamber[slot].Trapdoor == "vanilla" and levelStage + 1 or levelStage,
					StageType = hub2.SimulateStageTransitionStageType(levelStage + levelStage%2, trapdoor and trapdoor.StageType == "rep")
				}
			end
			
			local trapdoorEnt = StageAPI.SpawnCustomTrapdoor(
					room:GetGridPosition(hub2.Hub2TrapdoorSpots[slot]), 
					stage, 
					currentHubChamber[slot].TrapdoorAnm2 or trapdoor and trapdoor.Anm2, 
					currentHubChamber[slot].TrapdoorSize or trapdoor and trapdoor.Size or 24,
					false
				)
			
			if currentHubChamber[slot].DisableTrapdoor then
				trapdoorEnt:GetData().IsDisabledHub2Trapdoor = true
			end
		end
		
		if currentHubChamber[slot].Door then
			if currentHubChamber[slot].Door == 1 then
				StageAPI.SpawnCustomDoor(
					slot, 
					hub2.Hub2MainChamberRoomIndex, 
					nil, 
					"Hub2.0_Chamber_" .. tostring(currentHubChamber[slot].Door) .. "_Door_" .. tostring(slot)
				)
				
			else
				local chamberRoomData = StageAPI.GetDefaultLevelMap():GetRoomDataFromRoomID("Hub2.0_Chamber_" .. tostring(currentHubChamber[slot].Door))
				StageAPI.SpawnCustomDoor(
					slot, 
					chamberRoomData.MapID, 
					StageAPI.DefaultLevelMapID, 
					"Hub2.0_Chamber_" .. tostring(currentHubChamber[slot].Door) .. "_Door_" .. tostring(slot)
				)
			end
		end
		
		if currentHubChamber[slot].BossDoor then
			if hub2.Hub2EnteredBackChambers then
			
				-- removing old grid as game doesn't seem to do it justice in the same frame with room:RemoveDoor()
				local grid = room:GetGridEntity(room:GetGridIndex(room:GetDoorSlotPosition(slot)))
				if grid then
					room:RemoveGridEntity(grid:GetGridIndex(), 0, false)
					room:Update()
					Isaac.GridSpawn(GridEntityType.GRID_DECORATION, 0, grid.Position, true)
				end
				
				local stageName = hub2.RepHub2Quads[levelStage]:gsub("^%l", string.upper)
				local doorDataName = "Hub2.0_Chamber_" .. tostring(currentHubChamber[slot].Door) .. "_Door_" .. tostring(slot)
				StageAPI.CustomDoor(doorDataName, hub2.RepHub2Doors[stageName])

				StageAPI.SpawnCustomDoor(
					slot, 
					hub2.Hub2BossRoomIndex, 
					nil, 
					doorDataName
				)
				
				hub2.Hub2EnteredBackChambers = false
			end
		end
	end
	
	-- spawn statues
	if hub2.CurrentSelectedHub2ChamberId == 1 then
		if isFirstVisit then
			hub2.data.run.level.hub2Statues = {}
		end
		
		local statueIndices = {16, 28, 106, 118}
		for i=1, 4 do
			local grid = hub2.GRIDENT.HUB2_STATUE:Spawn(statueIndices[i], true, false)
			local persistData = StageAPI.GetCustomGrid(statueIndices[i], hub2.GRIDENT.HUB2_STATUE.Name).PersistentData
			local sprite = hub2.Hub2StatueEffects[persistData.StatueEffId]:GetSprite()
			sprite.FlipX = i%2 == 0
			sprite.FlipY = i>2
			
			if isFirstVisit then
				table.insert(hub2.data.run.level.hub2Statues, {
					Index = statueIndices[i],
					StatueId = persistData.StatueId,
					IsBroken = false
				})
			end
		end
	end
end

hub2:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, function(_, eff)
	if eff:GetData().IsDisabledHub2Trapdoor then -- forces the trapdoor to stay closed
		local sprite = eff:GetSprite()
		if sprite:IsPlaying("Open Animation") then
			sprite:SetFrame("Closed", 0)
		end
	end
end, StageAPI.E.Trapdoor.V)

function hub2.SetUpHub2Background(hubChamber)
	local room = game:GetRoom()
	local eff = Isaac.Spawn(EntityType.ENTITY_EFFECT, 6, 0, room:GetTopLeftPos(), Vector.Zero, nil)
	local sprite = eff:GetSprite()
	
	sprite:Load("gfx/backdrop/hubroom_2.0/hub_2.0_backdrop.anm2", true)
	sprite:Play("1x1", true)
	
	for slot=DoorSlot.LEFT0, DoorSlot.DOWN0 do
		if hubChamber[slot].QuadPng then
			sprite:ReplaceSpritesheet(slot, hubChamber[slot].QuadPng)
		else
			sprite:ReplaceSpritesheet(slot, "gfx/backdrop/hubroom_2.0/hubquads/" .. hubChamber[slot].Quad .. "_quad.png")
		end
	end
	sprite:LoadGraphics()
	
	eff:AddEntityFlags(hub2.BitOr(EntityFlag.FLAG_RENDER_FLOOR, EntityFlag.FLAG_RENDER_WALL))
end