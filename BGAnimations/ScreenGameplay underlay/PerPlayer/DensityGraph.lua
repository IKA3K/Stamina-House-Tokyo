local player = ...

if SL[ToEnumShortString(player)].ActiveModifiers.DensityGraph == "Disabled" then
	return Def.Actor{ InitCommand=function(self) self:visible(false) end }
end

-- local left = WideScale(27,84) + 20
local leftStandard = 27 + 20
local left = leftStandard

-- local right = _screen.cx - _screen.w/9
local rightStandard = _screen.cx - WideScale(_screen.w/9, _screen.w/9 + 84 - 27)
local right = rightStandard

if #GAMESTATE:GetHumanPlayers() == 1 and PREFSMAN:GetPreference("Center1Player") then
	-- TODO more center hacks 
	left = _screen.cx - 95
	right = left + (rightStandard - leftStandard)
end

local width = rightStandard - leftStandard
local height = 30

local SongNumberInCourse = 0
-- Change this if your CPU is fast enough to push out more
local fps = 60.0

local function getCurrentStepsInfo()
	local steps, song

	if GAMESTATE:IsCourseMode() then
		local trailEntry = GAMESTATE:GetCurrentTrail(player):GetTrailEntries()[SongNumberInCourse+1]
		steps = trailEntry:GetSteps()
		song = trailEntry:GetSong()
	else
		steps = GAMESTATE:GetCurrentSteps(player)
		song = GAMESTATE:GetCurrentSong()
	end

    	local difficulty = ToEnumShortString(steps:GetDifficulty())
    	local stepsType = ToEnumShortString(steps:GetStepsType()):gsub("_", "-"):lower()
    	local peakNps, npsPerMeasure = GetNPSperMeasure(song, stepsType, difficulty)
	return {steps=steps, song=song, peakNps=peakNps, npsPerMeasure=npsPerMeasure, fps=fps}
end

local currentSteps = nil

local function getCurrentGraphState(currentSteps)
	-- Only used if scrolling.
	local second = GAMESTATE:GetSongPosition():GetMusicSeconds()
 	local graphWidthSeconds = 120  -- Change this to change the width of the chart

	-- Need to merge in table which is really freaking annoying in Lua :( :(
	local rvalue = {
		second=second,
		graphWidthSeconds=graphWidthSeconds,
	}
	for k, v in pairs(currentSteps) do
		rvalue[k] = v
	end
	return rvalue
end

local af = Def.ActorFrame{
	InitCommand=function(self)
		-- If reverse, put this underneath the targets
		local playeroptions = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
		currentSteps = getCurrentStepsInfo()		

		if playeroptions:UsingReverse() then
			self:xy(left, 430)
		else
			self:xy(left, 56 - height / 2)
		end		

		if player == PLAYER_2 then
			self:x( _screen.w - left - width)
		end

		self:queuecommand("Sample")
	end,
	CurrentSongChangedMessageCommand=function(self)
		self:queuecommand("Reinitalize")
	end,
	ReinitalizeCommand=function(self)
		self:playcommand("ChangeSteps", getCurrentGraphState(currentSteps))
		SongNumberInCourse = SongNumberInCourse + 1
	end,
	SampleCommand=function(self)
		local second = GAMESTATE:GetSongPosition():GetMusicSeconds()
		-- Overhead scroll is disabled
		-- self:playcommand("ChangeSongProgress", {second=second})
		self:playcommand("ChangeSteps", getCurrentGraphState(currentSteps))
		self:sleep(1/fps):queuecommand("Sample")
	end
}

af[#af+1] = CreateDensityGraph(width, height)

return af

