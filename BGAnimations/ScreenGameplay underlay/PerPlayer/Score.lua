local player = ...
local pn = ToEnumShortString(player)
local mods = SL[pn].ActiveModifiers
local center1p = PREFSMAN:GetPreference("Center1Player")

if mods.HideScore then return end

if #GAMESTATE:GetHumanPlayers() > 1
and mods.NPSGraphAtTop
and SL.Global.GameMode ~= "StomperZ"
then return end

if #GAMESTATE:GetHumanPlayers() == 1
and SL.Global.GameMode ~= "StomperZ"
and mods.NPSGraphAtTop
and mods.DataVisualizations ~= "Step Statistics"
and not center1p
then return end

local dance_points, percent
local pss = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)

return LoadFont("_wendy monospace numbers")..{
	Text="0.00",

	Name=pn.."Score",
	InitCommand=function(self)
		self:valign(1):halign(1)
		local playeroptions = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
		local scroll = playeroptions:UsingReverse() and "Reverse" or "Standard"
		local ypos = {
			Standard = 56,
			Reverse = 447,
		} 

		if SL.Global.GameMode == "StomperZ" then
			self:zoom(0.4):x( WideScale(160, 214) ):y(20)
			if player == PLAYER_2 then
				self:x( _screen.w - WideScale(50, 104) )
			end
		else

			-- if mods.NPSGraphAtTop and mods.DataVisualizations=="Step Statistics" then
			--	self:zoom(0.5)
			--	self:x( player==PLAYER_1 and _screen.w-WideScale(15, center1p and 9 or 67) or WideScale(306, center1p and 280 or 358) )
			--	self:y( _screen.cy + 40 )
			-- else
			self:zoom(0.4)
			self:x( _screen.cx - 40 ):y(ypos[scroll])
			if #GAMESTATE:GetHumanPlayers() == 1 and PREFSMAN:GetPreference("Center1Player") then
				-- TODO more center hacks 
				self:x( _screen.cx - 95 - 20 - 25)
			elseif player == PLAYER_2 then
				self:x( _screen.cx + 150 )
			end
			-- end
		end
	end,
	JudgmentMessageCommand=function(self) self:queuecommand("RedrawScore") end,
	RedrawScoreCommand=function(self)
		dance_points = pss:GetPercentDancePoints()
		percent = FormatPercentScore( dance_points ):sub(1,-2)
		self:settext(percent)
	end
}
