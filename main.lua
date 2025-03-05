--BombLib Example (Sad Bombs recreation)

local SadBombs2 = RegisterMod('Sad Bombs 2', 1)

include("BLib_src.BombLib") --Include library

local ItemId = Isaac.GetItemIdByName("Sad Bombs 2")

BombLib:RegisterBombModifier("[BombLib] Sad Bombs",
    {
		HasModifier = function(player) return player:HasCollectible(ItemId) end,

		FetusChance = function(luck) return 11 + (3 * luck) end, --Shared with epic fetus. you can input a function to scale with luck. Same as Brimstone Bombs.
		NancyChance = -1, --Whacky. Do not use ATM unless you want an "unfinished" non-vanilla version

        --Sad Bombs does not ignore any of these.
        --
		IgnoreKamikaze = false, --Shared with Swallowed M80
		IgnoreEpicFetus = false,
		IgnoreWarLocust = false,
		IgnoreBobsBrain = false,
		IgnoreBobsRottenHead = false,
		IgnoreBBF = false,

		IgnoreHotPotato = false,

		Variant = BombVariant.BOMB_SAD,
		Path = "gfx/items/pick ups/bombs/sad",
		AddPathSuffixOnGolden = true,

		CopperBombSprite = false, --Fiend Folio adds it on their side
	}
)

local BombLibCallbacks = BombLib.Callbacks

function SadBombs2:ExplodeSadBombs2(bomb, player, extraData)
    local pos = bomb.Position
    local maw = player:SpawnMawOfVoid(80)

    maw.DisableFollowParent = true
    maw.Position = pos
end

BombLibCallbacks.AddCallback(BombLibCallbacks.ID.POST_BOMB_EXPLODE, SadBombs2.ExplodeSadBombs2, "[BombLib] Sad Bombs")

--Render tears on top
--Never tried doing this so this sucks. ignore it, it's not like it's something for the library
function SadBombs2:RenderSadBombs2(bomb)
    local anm2Path = "gfx/items/pick ups/bombs/tears" .. bomb:GetData().BombLibEndingString

    local spriteTears = Sprite()
    spriteTears:Load(anm2Path, true)
    spriteTears:Reload()
    spriteTears:SetFrame("Idle", bomb:GetSprite():GetFrame() % 12)

    print(bomb.Position)

    --bomb.Position + offset
    spriteTears:Render(Isaac.WorldToScreen(bomb.Position + Vector(0, 1.5)))
end

SadBombs2:AddCallback(ModCallbacks.MC_POST_BOMB_RENDER, SadBombs2.RenderSadBombs2, BombVariant.BOMB_SAD)

--lag the game
--[[
SadBombs2:AddCallback(ModCallbacks.MC_POST_RENDER, function ()
    for i = 1, 800000 do
        math.random()
    end
end)]]