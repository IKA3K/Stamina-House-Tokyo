local player = ...

return Def.ActorFrame{
	InitCommand=function(self)
		local playeroptions = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
		local scroll = playeroptions:UsingReverse() and "Reverse" or "Standard"
		local ypos = {
			Standard = 56,
			Reverse = 445,
		} 
		self:xy( 27, ypos[scroll] )
		
		if #GAMESTATE:GetHumanPlayers() == 1 and PREFSMAN:GetPreference("Center1Player") then
			-- TODO more center hacks 
			self:x( _screen.cx - 95 - 20 )
		elseif player == PLAYER_2 then
			self:x( _screen.w-27 )
		end

		if SL.Global.GameMode == "StomperZ" then
			self:y( 20 )
		end
	end,


	-- colored background for player's chart's difficulty meter
	Def.Quad{
		InitCommand=function(self)
			self:zoomto(30, 30)
		end,
		OnCommand=function(self)
			local currentSteps = GAMESTATE:GetCurrentSteps(player)
			if currentSteps then
				local currentDifficulty = currentSteps:GetDifficulty()
				self:diffuse(DifficultyColor(currentDifficulty))
			end
		end
	},

	-- player's chart's difficulty meter
	LoadFont("_wendy small")..{
		InitCommand=function(self)
			self:diffuse( Color.Black )
			self:zoom( 0.4 )
		end,
		CurrentSongChangedMessageCommand=cmd(queuecommand,"Begin"),
		BeginCommand=function(self)
			local steps = GAMESTATE:GetCurrentSteps(player)
			local meter = steps:GetMeter()

			if meter then
				self:settext(meter)
			end
		end
	}
}
