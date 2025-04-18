--BombLib Example (Sad Bombs recreation)
--I might make more recreations in the future as this one is not the best one as it
--involves doing some stupid stuff lmfao
--Anyways, enjoy my shitty example of an attempt to recreate sad bombs 1:1 (except tears falling sprite lolz)

local SadBombs2 = RegisterMod('Sad Bombs 2', 1)

include("BLib_src.BombLib") --Include library

SadBombs2.ID = Isaac.GetItemIdByName("Sad Bombs 2")
SadBombs2.Variant = Isaac.GetEntityVariantByName("Sad Bomb 2")
SadBombs2.TammyTears = 10 --Sad Bombs jsut actives tammy's head.

BombLib:RegisterBombModifier("[BombLib] Sad Bombs",
    {
		HasModifier = function(player) return player:HasCollectible(SadBombs2.ID) end,

		FetusChance = function(luck) return 11 + (3 * luck) end, --Shared with epic fetus. you can input a function to scale with luck. Same chance as Brimstone Bombs.
		NancyChance = -1, --Whacky. Do not use ATM unless you want an "unfinished" non-vanilla version

        --Sad Bombs does not ignore any of these.
        
        IgnoreSmallBomb = false,
        IgnoreBomberBoy = true,

		IgnoreKamikaze = false, --Shared with Swallowed M80
		IgnoreEpicFetus = false,
		IgnoreWarLocust = false,
		IgnoreBobsBrain = false,
		IgnoreBobsRottenHead = false,
		IgnoreBBF = false,

		IgnoreHotPotato = false,

		Variant = SadBombs2.Variant,
		Path = "gfx/items/pick ups/bombs/sad",
		AddPathSuffixOnGolden = true,

		CopperBombSprite = false, --Fiend Folio adds it on their side
	}
)

local BombLibCallbacks = BombLib.Callbacks

function SadBombs2:ExplodeSadBombs2(effect, player, extraData)
    player:UseActiveItem(CollectibleType.COLLECTIBLE_TAMMYS_HEAD, UseFlag.USE_NOANIM, -1)

    for _, tear in ipairs(Isaac.FindByType(EntityType.ENTITY_TEAR)) do
        if tear.FrameCount == 0 then
            local data = tear:GetData()
            if not data.tammySpecial then
                tear.Position = effect.Position

                --Actually supposed to collide with all
                --But that removes tears instantly when colliding with small scatter bombs
                tear.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ENEMIES

                data.tammySpecial = true
                if extraData.IsWarLocust then
                    data.WarLocust = true
                elseif extraData.IsSmallBomb then
                    data.Scatter = true
                end
            end
        end
    end
end

BombLibCallbacks.AddCallback(BombLibCallbacks.ID.POST_BOMB_EXPLODE, SadBombs2.ExplodeSadBombs2, "[BombLib] Sad Bombs")

--Render tears on top
--Never tried doing this so this sucks. ignore it, it's not like it's something specific for the library

--[[
function SadBombs2:RenderSadBombs2(bomb)
    local anm2Path = "gfx/items/pick ups/bombs/tears" .. bomb:GetData().BombLibEndingString

    local spriteTears = Sprite()
    spriteTears:Load(anm2Path, true)
    spriteTears:Reload()
    spriteTears:SetFrame("Idle", bomb:GetSprite():GetFrame() % 12)

    --print(bomb.Position)

    --bomb.Position + offset
    --spriteTears:Render(Isaac.WorldToScreen(bomb.Position + Vector(0, 1.5)))
end

SadBombs2:AddCallback(ModCallbacks.MC_POST_BOMB_RENDER, SadBombs2.RenderSadBombs2, SadBombs2.Variant)]]

function SadBombs2:TearStuff2(tear)
    if tear.FrameCount == 1 and tear:GetData().tammySpecial then
        if tear:GetData().Scatter then 
            tear.Scale = tear.Scale*0.65
            tear.CollisionDamage = tear.CollisionDamage*0.75
        elseif tear:GetData().WarLocust then
            tear.Scale = 0.813
            tear.CollisionDamage = 17.1
        end
    end
end

SadBombs2:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, SadBombs2.TearStuff2)

function SadBombs2:Help(gridEnt, _, _, player)
    local maw = player:SpawnMawOfVoid(60)
    maw.DisableFollowParent = true
    maw.Position = gridEnt.Position
    maw.Radius = 30
end
BombLibCallbacks.AddCallback(BombLibCallbacks.ID.POST_EXPLOSION_DESTROY_GRID_ROCK, SadBombs2.Help, "[BombLib] Sad Bombs")

function SadBombs2:Help2()
    print('hit')
end
BombLibCallbacks.AddCallback(BombLibCallbacks.ID.ENTITY_TAKE_EXPLOSION_DMG, SadBombs2.Help2, "[BombLib] Sad Bombs")

--lag the game
--[[
SadBombs2:AddCallback(ModCallbacks.MC_POST_RENDER, function ()
    for i = 1, 800000 do
        math.random()
    end
end)]]