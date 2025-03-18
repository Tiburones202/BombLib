---@diagnostic disable

--BombLib Created by [No need to credit directly on the mod page. Though, a thanks would be appreciated]:
-- * Tiburones202

--[[
	--TODO:
	* Base game callbacks with modifier as limiters [Later?]
]]

--Debug [DO NOT MODIFY]
local VERSION = 1
local FORCE_VERSION_UPDATE = true

local game = Game()
local Mod = BombLib or nil

local CACHED_CALLBACKS
local CACHED_BOMBS
local CACHED_MOD_CALLBACKS

local function InitMod()
	local BombLib = RegisterMod("BombLibrary", 1)

	BombLib.Version = VERSION

	BombLib.AddedCallbacks = {
		[ModCallbacks.MC_POST_BOMB_UPDATE] = {},
		[ModCallbacks.MC_PRE_USE_ITEM] = {},
		[ModCallbacks.MC_POST_EFFECT_INIT] = {},
		[ModCallbacks.MC_POST_PEFFECT_UPDATE] = {},
		[ModCallbacks.MC_POST_NEW_ROOM] = {},
		[ModCallbacks.MC_POST_EFFECT_INIT] = {},
		[ModCallbacks.MC_ENTITY_TAKE_DMG] = {},
	} -- for any vanilla callback functions added by this library

	BombLib.Callbacks = BombLib.Callbacks or {}
	BombLib.Callbacks.RegisteredCallbacks = game:GetFrameCount() == 0 and CACHED_CALLBACKS or {}
	BombLib.RegisteredBombs = game:GetFrameCount() == 0 and CACHED_BOMBS or {}
	BombLib.AddedCallbacks = game:GetFrameCount() == 0 and CACHED_MOD_CALLBACKS or BombLib.AddedCallbacks
	
	return BombLib
end

--[[
	--BOMB EXAMPLE:

	RegisterBombModifier("My Custom Bomb", {
		HasModifier = function(player) return player:HasCollectible(Isaac.GetItemIdByName("My Bomb")) end,

		FetusChance = BombLib.DefaultFetusChance, --Shared with epic fetus. input a function. luck is offered as a parameter
		NancyChance = -1, --Not recommended until I find a "vanilla" way to include custom bombs

		IgnoreSmallBomb = false,
		IgnoreBomberBoy = true,

		IgnoreKamikaze = false, --Shared with Swallowed M80
		IgnoreEpicFetus = false,
		IgnoreWarLocust = false,
		IgnoreBobsBrain = false,
		IgnoreBobsRottenHead = false,
		IgnoreBBF = false,

		IgnoreHotPotato = false,

		Variant = Isaac.GetEntityVariantByName("My Bomb Variant"),
		Path = "gfx/items/pick ups/bombs/custom",
		AddPathSuffixOnGolden = true,

		CopperBombSprite = false,
	})
]]

---Initializes data and functions that get overwritten when a newer version of the mod is loaded.
local function InitFunctions()
	BombLib.DefaultFetusChance = function(luck) return 11 + (3 * luck) end --Brimstone bombs chance as a placeholder
	BombLib.DefaultNancyChance = -1 --Disabled normally. Will have a base chance once I figure out how it works.

	BombLib.BLACKLISTED_VARIANTS = {
		[BombVariant.BOMB_GIGA] = true,
		[BombVariant.BOMB_THROWABLE] = true,
	}
		
	--#region Utils

	---Will attempt to find the player using the attached Entity, EntityRef, or EntityPtr.
	---Will return if its a player, the player's familiar, or loop again if it has a SpawnerEntity
	---@param ent Entity | EntityRef | EntityPtr
	---@param directOnly? boolean
	---@return EntityPlayer?
	function Mod:TryGetPlayer(ent, directOnly)
		if not ent then return end
		if string.find(getmetatable(ent).__type, "EntityPtr") then
			if ent.Ref then
				return Mod:TryGetPlayer(ent.Ref)
			end
		elseif string.find(getmetatable(ent).__type, "EntityRef") then
			if ent.Entity then
				return Mod:TryGetPlayer(ent.Entity)
			end
		elseif ent:ToPlayer() then
			return ent:ToPlayer()
		elseif ent:ToFamiliar() and ent:ToFamiliar().Player and not directOnly then
			return ent:ToFamiliar().Player
		elseif ent.SpawnerEntity and not directOnly then
			return Mod:TryGetPlayer(ent.SpawnerEntity)
		end
	end

	---Executes given function for every player
	---Return anything to end the loop early
	---@param func fun(player: EntityPlayer, playerNum?: integer): any?
	function Mod:ForEachPlayer(func)
		if REPENTOGON then
			for i, player in ipairs(PlayerManager.GetPlayers()) do
				if func(player, i) then
					return true
				end
			end
		else
			for i = 0, game:GetNumPlayers() - 1 do
				if func(Isaac.GetPlayer(i), i) then
					return true
				end
			end
		end
	end

	---Explosion will (almsot) always be in the same position
	function Mod:IsNotBomberBoyExplosion(effect, spawner)
		--print(effect.Position.X, spawner.Position.X, effect.Position.Y, spawner.Position.Y)
		return (effect.Position.X == spawner.Position.X) and (effect.Position.Y == spawner.Position.Y)
	end

	--Gets the bomb size
	--2 for Normal, 0 for Scatter Bomb, 
	--3 for Mr. Mega and Best Friend, and 1 for Mr. Mega Scatter Bombs
	function Mod:GetBombSize(bomb)
		if bomb.Variant == BombVariant.BOMB_DECOY then return 3 end --Best Friend doesn't follow the rules

		local file = bomb:GetSprite():GetFilename()
		return tonumber(file:sub(file:len()-5, -6))
	end

	function Mod:CheckExplosionType(extraData, registeredBomb, checkFor)
		return extraData["Is" .. checkFor] and not registeredBomb["Ignore" .. checkFor]
	end

	function Mod:ShouldFireStandard(identificator, extraData, sawnerThing)
		local registeredBomb = Mod.RegisteredBombs[identificator]

		if not ((extraData.IsBomberBoy and not registeredBomb.IgnoreBomberBoy) or not extraData.IsBomberBoy) then
			return false
		end

		if Mod:CheckExplosionType(extraData, registeredBomb, "Kamikaze") then
			return registeredBomb.HasModifier(player)
		elseif Mod:CheckExplosionType(extraData, registeredBomb, "WarLocust") then
			return registeredBomb.HasModifier(player)
		elseif Mod:CheckExplosionType(extraData, registeredBomb, "BobsBrain") then
			return registeredBomb.HasModifier(player)
		elseif Mod:CheckExplosionType(extraData, registeredBomb, "BBF") then
			return registeredBomb.HasModifier(player)
		elseif Mod:CheckExplosionType(extraData, registeredBomb, "BobsRottenHead") then
			return registeredBomb.HasModifier(player)
		elseif Mod:CheckExplosionType(extraData, registeredBomb, "HotPotato") then
			return registeredBomb.HasModifier(player)
		elseif Mod:CheckExplosionType(extraData, registeredBomb, "EpicFetus") then
			local rng = player:GetCollectibleRNG(CollectibleType.COLLECTIBLE_EPIC_FETUS)
			if rng:RandomInt(100) > registeredBomb.FetusChance(player.Luck) then return false end

			return registeredBomb.HasModifier(player)
		else
			local bomb
			if sawnerThing:ToBomb() then
				bomb = sawnerThing:ToBomb()
			else
				bomb = sawnerThing.SpawnerEntity:ToBomb()
			end

			if bomb and ((extraData.IsSmallBomb and not registeredBomb.IgnoreSmallBomb) or not extraData.IsSmallBomb)
				and ((extraData.IsBomberBoy and not registeredBomb.IgnoreBomberBoy) or not extraData.IsBomberBoy)
			then
				return bomb:GetData()[identificator]
			end
		end
	end

	--endregion

	--#region Callbacks

	BombLib.Callbacks.ID = {
		--"New" callbacks
		POST_BOMB_EXPLODE = 0, --No pre because it just kinda doesn't exist lmfao

		PRE_PROPER_BOMB_INIT = 1, --Before adding modifiers and changing sprite
		POST_PROPER_BOMB_INIT = 2, --After doing that thingy

		ENTITY_TAKE_EXPLOSION_DMG = 3, 
	}

	for _, v in pairs(BombLib.Callbacks.ID) do
		if not BombLib.Callbacks.RegisteredCallbacks[v] then
			BombLib.Callbacks.RegisteredCallbacks[v] = {}
		end
	end

	BombLib.CallbackPriority = {
		HIGHEST = 0,
		HIGH = 10,
		NORMAL = 20,
		LOW = 30,
		LOWEST = 40,
	}

	---@param id number
	---@param priority integer
	---@param func function
	---@param ... any
	function BombLib.Callbacks.AddPriorityCallback(id, priority, func, ...)
		local callbacks = BombLib.Callbacks.RegisteredCallbacks[id]
		local callback = {
			Priority = priority,
			Function = func,
			Args = { ... },
		}

		if #callbacks == 0 then
			callbacks[#callbacks + 1] = callback
		else
			for i = #callbacks, 1, -1 do
				if callbacks[i].Priority <= priority then
					table.insert(callbacks, i + 1, callback)
					return
				end
			end
			table.insert(callbacks, 1, callback)
		end
	end

	---@param id number
	---@param func function
	---@param ... any
	function BombLib.Callbacks.AddCallback(id, func, ...)
		BombLib.Callbacks.AddPriorityCallback(id, BombLib.CallbackPriority.NORMAL, func, ...)
	end

	---@param id string
	---@param func function
	function BombLib.Callbacks.RemoveCallback(id, func)
		local callbacks = BombLib.Callbacks.RegisteredCallbacks[id]
		for i = #callbacks, 1, -1 do
			if callbacks[i].Function == func then
				table.remove(callbacks, i)
			end
		end
	end

	function BombLib.Callbacks.FireCallback(callbackId, ...)
		local callbacks = Mod.Callbacks.RegisteredCallbacks[callbackId]
		if callbacks ~= nil then
			return Mod.CallbackHandlers[callbackId](callbacks, ...)
		end
	end

	BombLib.CallbackHandlers = {
		[Mod.Callbacks.ID.POST_BOMB_EXPLODE] = function(callbacks, effect, player, extraData)
			local effectData = effect:GetData()

			if effectData.BombLibChecked then goto continue2 end
			effectData.BombLibChecked = true

			for i = 1, #callbacks do
				local identificator = callbacks[i].Args[1]
				local shouldFire = (not identificator) or Mod:ShouldFireStandard(identificator, extraData, effect)

				if shouldFire then
					callbacks[i].Function(BombLib, effect, player, extraData)
				end

				::continue::
			end
			::continue2::
		end,

		[Mod.Callbacks.ID.PRE_PROPER_BOMB_INIT] = function (callbacks, bomb, player)
			for i = 1, #callbacks do --No extra parameters
				callbacks[i].Function(BombLib, bomb, player)
			end
		end,

		[Mod.Callbacks.ID.POST_PROPER_BOMB_INIT] = function (callbacks, bomb, player)
			for i = 1, #callbacks do
				local identificator = callbacks[i].Args[1]
				local shouldFire = not identificator

				if not shouldFire then
					shouldFire = bomb:GetData()[identificator]
				end

				if shouldFire then
					callbacks[i].Function(BombLib, bomb, player)
				end
			end
		end,

		[Mod.Callbacks.ID.ENTITY_TAKE_EXPLOSION_DMG] = function (callbacks, Entity, Amount, DamageFlags, source, CountdownFrames, extraData)
			for i = 1, #callbacks do --No extra parameters
				local identificator = callbacks[i].Args[1]
				local shouldFire = (not identificator) or Mod:ShouldFireStandard(identificator, extraData, source)

				if shouldFire then
					callbacks[i].Function(BombLib, Entity, Amount, DamageFlags, source, CountdownFrames, extraData)
				end
			end
		end,
	}

	--#endregion

	for callback, funcs in pairs(BombLib.AddedCallbacks) do
		for i = 1, #funcs do
			BombLib:RemoveCallback(callback, funcs[i])
		end
	end

	local function AddPriorityCallback(callback, priority, func, arg)
		BombLib:AddPriorityCallback(callback, priority, func, arg)

		if not BombLib.AddedCallbacks[callback] then
			BombLib.AddedCallbacks[callback] = {}
		end
		table.insert(BombLib.AddedCallbacks[callback], func)
	end

	local function AddCallback(callback, func, arg)
		AddPriorityCallback(callback, CallbackPriority.DEFAULT, func, arg)
	end

	function BombLib:RegisterBombModifier(Identifier, BombData)
		BombLib.RegisteredBombs[Identifier] =
		{
			HasModifier = BombData.HasModifier,

			FetusChance = BombData.FetusChance or BombLib.DefaultFetusChance,
			NancyChance = BombData.NancyChance or BombLib.DefaultNancyChance,

			IgnoreSmallBomb = BombData.IgnoreSmallBomb or false,
			IgnoreBomberBoy = BombData.IgnoreBomberBoy == nil and true or BombData.IgnoreBomberBoy,

			IgnoreKamikaze = BombData.IgnoreKamikaze or false,
			IgnoreEpicFetus = BombData.IgnoreEpicFetus or false,
			IgnoreWarLocust = BombData.IgnoreWarLocust or false,
			IgnoreBobsBrain = BombData.IgnoreBobsBrain or false,
			IgnoreBobsRottenHead = BombData.IgnoreBobsRottenHead or false,
			IgnoreBBF = BombData.IgnoreBBF or false,

			IgnoreHotPotato = BombData.IgnoreHotPotato or false,

			Variant = BombData.Variant or nil,
			Anm2Path = BombData.Anm2Path or nil,
			PngPath = BombData.PngPath or nil, --game stupid and can't get png path :c

			AddPathSuffixOnGolden = BombData.AddPathSuffixOnGolden or false,

			CopperBombSprite = BombData.CopperBombSprite or false,
		}

		--#region Dynamic Bomb HUD Compatibility

		local DBHUDCompat = BombData.DynamicBombHUDCompat
		if DBHUDCompat then
			CustomBombHUDIcons:AddPriorityBombIcon(DBHUDCompat.Priority or CustomBombHUDIcons.BombPriority.DEFAULT,
    		{
    		    Name = DBHUDCompat.Name,

    		    Anm2 = DBHUDCompat.Anm2,
    		    GoldAnm2 = DBHUDCompat.GoldAnm2,
    		    CopperAnm2 = DBHUDCompat.CopperAnm2,
    		    FrameName = DBHUDCompat.FrameName,
    		    Frame = DBHUDCompat.Frame,

    		    Condition = DBHUDCompat.Condition
    		})
		end

		--#endregion
	end

	--#region Bomb States

	function BombLib:ReloadSpecialSkins(bomb, sprite, bombData, isCopper)
		local spritesheetSuffix

		if isCopper then
			spritesheetSuffix = "_copper"
		elseif bombData.AddPathSuffixOnGolden and bomb:HasTearFlags(TearFlags.TEAR_GOLDEN_BOMB) then
			spritesheetSuffix = "_gold"
		end

		if spritesheetSuffix then
			sprite:ReplaceSpritesheet(0, bombData.PngPath .. spritesheetSuffix .. ".png")
			sprite:LoadGraphics()
		end
	end

	function BombLib:ChangeVariant(bomb, identifier, bombData)
		local variant = bombData.Variant
		local isCopper = CopperBombSprite and FiendFolio and (bomb.Variant == FiendFolio.BOMB.COPPER)

		local sprite = bomb:GetSprite()
	    local file = sprite:GetFilename()
		local endingString = file:sub(file:len()-5)

	    if isCopper or bomb.Variant == 0 then --Change skin if normal bomb
			if variant and not isCopper then 
				bomb.Variant = variant
			end

			local path = bombData.Anm2Path

			if path then
				local anim = sprite:GetAnimation()

			    sprite:Load(path .. endingString, true)

				Mod:ReloadSpecialSkins(bomb, sprite, bombData, isCopper)

			    sprite:Play(anim, true)
			end
	    end

		::continue::

	    bomb:GetData()[identifier] = true
	end

	---@param bomb EntityBomb
	function BombLib:ProperBombInit(bomb, player)
	    if not player then return end
	    if BombLib.BLACKLISTED_VARIANTS[bomb.Variant] then return end

		Mod.Callbacks.FireCallback(Mod.Callbacks.ID.PRE_PROPER_BOMB_INIT, bomb, player)

		local HasNancy = player:HasCollectible(CollectibleType.COLLECTIBLE_NANCY_BOMBS)
		local NancyRNG = HasNancy and player:GetCollectibleRNG(CollectibleType.COLLECTIBLE_NANCY_BOMBS) or nil

	    --Detect nancy bombs anddddd the dr fetus from SMB yeah
		for identifier, bombData in pairs(BombLib.RegisteredBombs) do
			if bombData.HasModifier(player, bomb) then
			    if bomb.IsFetus then
			        local rng = bomb:GetDropRNG()

			        if rng:RandomInt(100) > bombData.FetusChance(player.Luck) then
			            goto continue
			        end
			    end

			    BombLib:ChangeVariant(bomb, identifier, bombData)
			elseif HasNancy then
			    --TODO: Better way to add modifiers by nancy bombs

			    if NancyRNG:RandomInt(100) > bombData.NancyChance then
			        goto continue
			    end

			    BombLib:ChangeVariant(bomb, identifier, bombData)
			end

			::continue::
		end

		Mod.Callbacks.FireCallback(Mod.Callbacks.ID.POST_PROPER_BOMB_INIT, bomb, player)
	end

	---@param bomb EntityBomb
	function BombLib:BombUpdate(bomb)
		if bomb.FrameCount == 1 then
			local player = Mod:TryGetPlayer(bomb)

			BombLib:ProperBombInit(bomb, player)
		end
	end
	AddCallback(ModCallbacks.MC_POST_BOMB_UPDATE, BombLib.BombUpdate)

	--#endregion

	--#region Bomb Explosion

	function BombLib:DetectBombByInit(effect, spawner)
		local bomb = spawner:ToBomb()
		if not bomb then return end

		local extraData = {}

		if Mod:GetBombSize(bomb) < 2 then --Mini bomb
			extraData.IsSmallBomb = true
			extraData.SmallExplosion = true
		end

		if not Mod:IsNotBomberBoyExplosion(effect, bomb) then
			extraData.IsBomberBoy = true
		end

		Mod.Callbacks.FireCallback(Mod.Callbacks.ID.POST_BOMB_EXPLODE, effect, Mod:TryGetPlayer(bomb), extraData)
	end

	--#endregion

	--#region Kamikaze

	function BombLib:UseKamikaze(_, _, player)
		local pData = player:GetData()
		pData.BombLibKamikazeUses = 1
	end

	AddPriorityCallback(ModCallbacks.MC_PRE_USE_ITEM, CallbackPriority.LATE, BombLib.UseKamikaze, CollectibleType.COLLECTIBLE_KAMIKAZE)

	function BombLib:DetectKamikazeByInit(effect, spawner)
	    local player = spawner:ToPlayer()

	    if not player then return end

		local pData = player:GetData()
	    if pData.BombLibKamikazeUses then
	        pData.BombLibKamikazeUses = pData.BombLibKamikazeUses - 1
	        if pData.BombLibKamikazeUses <= 0 then
	            pData.BombLibKamikazeUses = nil
	        end

			local extraData = {
				IsKamikaze = true
			}

	        Mod.Callbacks.FireCallback(Mod.Callbacks.ID.POST_BOMB_EXPLODE, effect, player, extraData)
	    end
	end

	--#endregion

	--#region Epic Fetus

	function BombLib:DetectEpicFetusByInit(effect, spawner)
		if spawner.Variant == EffectVariant.ROCKET or spawner.Variant == EffectVariant.SMALL_ROCKET then
			local extraData = {
				IsEpicFetus = true,
				IsBomberBoy = not Mod:IsNotBomberBoyExplosion(effect, spawner),
			}

			Mod.Callbacks.FireCallback(Mod.Callbacks.ID.POST_BOMB_EXPLODE, effect, Mod:TryGetPlayer(spawner), extraData)
		end
	end

	--#endregion

	--#region Locust of War

	function BombLib:DetectWarLocustByInit(effect, spawner)
		if spawner.Variant ~= FamiliarVariant.BLUE_FLY or spawner.SubType ~= 1 then return end

		local extraData = {
			IsWarLocust = true,
			SmallExplosion = true,
		}

		if not Mod:IsNotBomberBoyExplosion(effect, spawner) then
			extraData.IsBomberBoy = true
		end

		Mod.Callbacks.FireCallback(Mod.Callbacks.ID.POST_BOMB_EXPLODE, effect, Mod:TryGetPlayer(spawner), extraData)
	end

	--#endregion

	--#region Bob's Brain

	function BombLib:DetectBobsBrainByInit(effect, spawner)
		if spawner.Variant ~= FamiliarVariant.BOBS_BRAIN then return end

		local extraData = {
			IsBobsBrain = true
		}

		if not Mod:IsNotBomberBoyExplosion(effect, spawner) then
			extraData.IsBomberBoy = true
		end

		Mod.Callbacks.FireCallback(Mod.Callbacks.ID.POST_BOMB_EXPLODE, effect, Mod:TryGetPlayer(spawner), extraData)
	end

	--#endregion

	--#region Bob's Rotten Head

	function BombLib:DetectBobsRottenHeadtByInit(effect)
		local player = effect.SpawnerEntity
		if not player then return end
		player = player:ToPlayer()
		if not player then return end

		local bobsRottenHead = Isaac.FindInRadius(effect.Position, 0)[1]:ToTear()

		if not bobsRottenHead then return end

		local extraData = {
			IsBobsRottenHead = true
		}

		Mod.Callbacks.FireCallback(Mod.Callbacks.ID.POST_BOMB_EXPLODE, bobsRottenHead, player, extraData)
	end

	AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, BombLib.DetectBobsRottenHeadtByInit, EffectVariant.SMOKE_CLOUD)

	--#endregion

	--#region BBF

	function BombLib:DetectBBFByInit(effect, spawner)
		if spawner.Variant ~= FamiliarVariant.BBF then return end

		local extraData = {
			IsBBF = true
		}

		if not Mod:IsNotBomberBoyExplosion(effect, spawner) then
			extraData.IsBomberBoy = true
		end

		Mod.Callbacks.FireCallback(Mod.Callbacks.ID.POST_BOMB_EXPLODE, effect, Mod:TryGetPlayer(spawner), extraData)
	end

	--#endregion

	--#region Hot Potato

	function BombLib:HotPotatoForgorPEffectUpdate(player)
		if game.Challenge ~= Challenge.CHALLENGE_HOT_POTATO then return end

		local FrameCountRoom = (player.FrameCount - (player:GetData().BombLibStartingFrames or 0))
		if (FrameCountRoom % 73 == 0) and FrameCountRoom > 0 then 
			local extraData = {
				IsHotPotato = true
			}

			Mod.Callbacks.FireCallback(Mod.Callbacks.ID.POST_BOMB_EXPLODE, player, player, extraData)
		end
	end

	AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, BombLib.HotPotatoForgorPEffectUpdate, PlayerType.PLAYER_THEFORGOTTEN_B)

	function BombLib:HotPotatoNewRoom() --Reset frames on new room
		if game.Challenge ~= Challenge.CHALLENGE_HOT_POTATO then return end

		Mod:ForEachPlayer(function(player)
			if player:GetPlayerType() == PlayerType.PLAYER_THEFORGOTTEN_B then
				player:GetData().BombLibStartingFrames = player.FrameCount - 1
			end
		end)
	end

	AddCallback(ModCallbacks.MC_POST_NEW_ROOM, BombLib.HotPotatoNewRoom)

	--#endregion

	function BombLib:CustomBombInteractionsInit(effect)
		local spawner = effect.SpawnerEntity

		if spawner then
			BombLib:DetectBombByInit(effect, spawner) --Normal Bomb

			BombLib:DetectKamikazeByInit(effect, spawner) --Kamikaze
			--BombLib:DetectHotPotatoByInit(effect) --Hot Potato
			BombLib:DetectEpicFetusByInit(effect, spawner) --Epic Fetus
			if spawner.Type == EntityType.ENTITY_FAMILIAR then
				BombLib:DetectBobsBrainByInit(effect, spawner) --Bob's Brain
				BombLib:DetectWarLocustByInit(effect, spawner) --War Locust
				BombLib:DetectBBFByInit(effect, spawner) --BBF
			end
		end
	end

	AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, BombLib.CustomBombInteractionsInit, EffectVariant.BOMB_EXPLOSION)

	function BombLib:PostEntityTakeExplosionDamage(Entity, Amount, DamageFlags, Source, CountdownFrames)
		local source = Source.Entity

		if not source then goto continue end

		source = source:ToBomb()

		if not source then goto continue end
		if BombLib.BLACKLISTED_VARIANTS[source.Variant] then goto continue end

		print(source.Type, source.Variant, source.SubType)

		local WillDie = false
		if Entity:ToPlayer() then
			print(Amount)
			local player = Entity:ToPlayer()
			local healthLeft = ((player:GetHearts() - player:GetRottenHearts() * 2) + player:GetSoulHearts() + player:GetRottenHearts() +
				player:GetEternalHearts() + player:GetBoneHearts())
			WillDie = (healthLeft - Amount) <= 0
		else
			WillDie = (Entity.HitPoints - Amount) <= 0
		end
		local extraData = {
			WillDie = WillDie,
		}

		if Mod:GetBombSize(bomb) < 2 then --Mini bomb
			extraData.IsSmallBomb = true
			extraData.SmallExplosion = true
		end

		Mod.Callbacks.FireCallback(Mod.Callbacks.ID.ENTITY_TAKE_EXPLOSION_DMG, Entity, Amount, DamageFlags, source, CountdownFrames, extraData)

		::continue::
	end

	AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, BombLib.PostEntityTakeExplosionDamage)
end

--#region Base Game callbacks, passing a modifier [Add later?] --#endregion

--#region Update

if BombLib then
	if BombLib.Version > VERSION and not FORCE_VERSION_UPDATE then
		return
	end

	CACHED_CALLBACKS = BombLib.Callbacks.RegisteredCallbacks
	CACHED_BOMBS = BombLib.RegisteredBombs
	CACHED_MOD_CALLBACKS = BombLib.AddedCallbacks
end

BombLib = InitMod()
Mod = BombLib
InitFunctions()

--#region Scheduler

--[[
local function schedulerInit()
	local scheduler = {}
	local Mod = BombLib
	scheduler.ScheduleData = {}
	---
	---@param delay integer
	---@param func function
	---@param args any
	---@function
	---@scope Scheduler
	function scheduler.Schedule(delay, func, args)
		table.insert(scheduler.ScheduleData, {
			Time = game:GetFrameCount(),
			Delay = delay,
			Call = func,
			Args = args or {},
		})
	end
	
	Mod:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
		local time = game:GetFrameCount()
		for i = #scheduler.ScheduleData, 1, -1 do
			local data = scheduler.ScheduleData[i]
			if data.Time + data.Delay <= time then
				table.remove(scheduler.ScheduleData, i)
				data.Call(table.unpack(data.Args))
			end
		end
	end)
	
	Mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function()
		scheduler.ScheduleData = {}
	end)
	
	return scheduler
end

BombLib.Scheduler = schedulerInit()]]

--#endregion

--#endregion