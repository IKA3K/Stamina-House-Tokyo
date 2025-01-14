-- ReceptorArrow positions are hardcoded using Metrics.ini
-- in both Casual, Competitive, and ECFA modes.  If we're in one
-- of those modes, bail now.

-- IKA3K: disable this since we need this for horizontal positioning
-- if SL.Global.GameMode ~= "StomperZ" then return end

local player = ...

-- these numbers are relative to the ReceptorArrowsYStandard and ReceptorArrowsYReverse
-- positions already specified in Metrics
local ReceptorPositions = {
	Standard = {
		ITG = -40,  -- SMX is too tall, default is 45
		StomperZ = 0
	},
	Reverse = {
		ITG = -30,
		StomperZ = 0
	}
}

-- IKA3K offset for SMX cabs
local WidescreenXOffset = 70

return Def.Actor{
	DoneLoadingNextSongMessageCommand=function(self) self:queuecommand("Position") end,
	PositionCommand=function(self)

		local topscreen = SCREENMAN:GetTopScreen()
		local playeroptions = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
		local p = ToEnumShortString(player)

		local scroll = playeroptions:UsingReverse() and "Reverse" or "Standard"
		local position = SL[p].ActiveModifiers.ReceptorArrowsPosition

		local styleType = GAMESTATE:GetCurrentStyle():GetStyleType()

		-- The "Player ActorFrame contains several things like NoteField, Judgment, HoldJudgment, etc.
		-- Shift the entire ActorFrame up/down, rather than try to position its children individually.
		topscreen:GetChild('Player'..p):addy( ReceptorPositions[scroll][position] )

		-- IKA3K edits to move player 
		if (styleType == "StyleType_OnePlayerOneSide" and not PREFSMAN:GetPreference("Center1Player")) or styleType == "StyleType_TwoPlayersTwoSides" then
			if player == PLAYER_1 then
				topscreen:GetChild('Player'..p):addx( -1 * WidescreenXOffset )
			else 
				topscreen:GetChild('Player'..p):addx( WidescreenXOffset )
			end
			WidescreenXOffset = 0
		end
		--SCREENMAN:SystemMessage(string.format('repositioned to %d', topscreen:GetChild('Player'..p):GetX))
	end
}
