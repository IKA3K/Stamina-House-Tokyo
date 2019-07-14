local players = ...
local barWidthStandard = _screen.w/2-10 + WideScale(0, (84 - 27) * 2)
local barWidthFull = _screen.w-10
local barWidth = barWidthStandard

-- If both players are using non-standard lifebars
local player1str = ToEnumShortString(players[1])
local player1lifeMeterType = SL[player1str].ActiveModifiers.LifeMeterType or CustomOptionRow("LifeMeterType").Choices[1]
if #players == 2 then
	local player2str = ToEnumShortString(players[2])
	local player2lifeMeterType = SL[player2str].ActiveModifiers.LifeMeterType or CustomOptionRow("LifeMeterType").Choices[1]

	if player1lifeMeterType ~= "Standard" and player2lifeMeterType ~= "Standard" then
		barWidth = barWidthFull
	end
elseif #players == 1 then
	if player1lifeMeterType ~= "Standard" or PREFSMAN:GetPreference("Center1Player") then
		barWidth = barWidthFull
	end
end

return Def.ActorFrame{

	-- Song Completion Meter
	Def.ActorFrame{
		Name="SongMeter",
		InitCommand=cmd(xy, _screen.cx, 20 ),

		Def.SongMeterDisplay{
			-- StreamWidth=_screen.w/2-10,
			StreamWidth=barWidth,
			Stream=Def.Quad{ 
				InitCommand=cmd(zoomy,18; diffuse,DifficultyIndexColor(2))
			}
		},

		-- Border( _screen.w/2-10, 22, 2 ),
		Border( barWidth, 22, 2 ),
	},

	-- Song Title
	LoadFont("_miso")..{
		Name="SongTitle",
		InitCommand=cmd(zoom,0.8; shadowlength,0.6; maxwidth, _screen.w/2.5 - 10; xy, _screen.cx, 20 ),
		CurrentSongChangedMessageCommand=cmd(playcommand, "Update"),
		UpdateCommand=function(self)
			local song = GAMESTATE:GetCurrentSong()
			self:settext( song and song:GetDisplayFullTitle() or "" )
		end
	}
}
