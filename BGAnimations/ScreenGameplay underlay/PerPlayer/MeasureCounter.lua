local player = ...
local pn = ToEnumShortString(player)
local mods = SL[pn].ActiveModifiers

-- don't allow MeasureCounter to appear in Casual gamemode via profile settings
if SL.Global.GameMode == "Casual"
or not mods.MeasureCounter
or mods.MeasureCounter == "None" then
	return
end


local PlayerState = GAMESTATE:GetPlayerState(player)
local streams, prev_measure, MeasureCounterBMT, RemainingCounterBMT
local current_count, stream_index, current_stream_length
local remaining_stream  -- Number of measures remaining
local total_stream  -- Number of measures total

-- We'll want to reset each of these values for each new song in the case of CourseMode
local InitializeMeasureCounter = function()
	-- SL[pn].Streams is initially set (and updated in CourseMode)
	-- in ./ScreenGameplay in/MeasureCounterAndModsLevel.lua
	streams = SL[pn].Streams
	current_count = 0
	stream_index = 1
	current_stream_length = 0
	prev_measure = 0
	remaining_stream = 0

	-- Use NPS per measure 
	for i, stream in ipairs(streams.Measures) do
		if not stream.isBreak then
			remaining_stream = remaining_stream + (stream.streamEnd - stream.streamStart)
		end
	end
	total_stream = remaining_stream
end

local GetTextForMeasure = function(measure, current_measure)
	local streamStart = measure.streamStart
	local streamEnd = measure.streamEnd
	local current_stream_length = streamEnd - streamStart
	local current_count = current_stream_length == 1 and 1 or math.floor(current_measure - streamStart) + 1

	if measure.isBreak then
		-- NOTE: We let the lowest value be 0. This means that e.g.,
		-- for an 8 measure break, we will display the numbers 7 -> 0
		local measures_left = current_stream_length - current_count

		if measures_left >= (current_stream_length-1) or measures_left <= 0 then
			text = ""
		else
			text = "(" .. measures_left .. ")"
		end
	else
		text = tostring(current_count .. "/" .. current_stream_length)
	end
	return text
end

local GetTextForCurrentMeasure = function(current_measure, Measures, stream_index)
	-- Validate indices
	local this_measure_obj = Measures[stream_index]
	if this_measure_obj == nil then return "", "" end

	local remainingStreamText = "(" .. remaining_stream .. "/" .. total_stream .. ")"

	local streamStart = this_measure_obj.streamStart
	local streamEnd = this_measure_obj.streamEnd
	-- Debugging text (this is shown in case it returns early)
	-- SCREENMAN:SystemMessage("measure " .. tostring(current_measure) .. " stream start: " .. tostring(streamStart) .. " stream end " .. tostring(streamEnd) .. " remainingText " .. remainingStreamText)
	if current_measure < streamStart then
		return "", remainingStreamText, false
	end
	-- Define end as also matching the end of the stream; this case care of 1 measure cases.
	if current_measure > streamEnd then
		 return "", remainingStreamText, true
	end

	local text = GetTextForMeasure(this_measure_obj, current_measure)
	local next_measure_obj = Measures[stream_index + 1]
	if text and text ~= "" and next_measure_obj ~= nil then
		local next_measure_obj_length = next_measure_obj.streamEnd - next_measure_obj.streamStart
		local next_text = "" .. next_measure_obj_length
		if next_measure_obj.isBreak then
			next_text = "(" .. next_measure_obj_length .. ")"
		end
		text = text .. " => " .. next_text
	end

	-- TODO rename this function to GetTextAndStyle because this styles the text...
	if Measures[stream_index].isBreak then
		-- diffuse break counter to be Still Grey, just like Pendulum intended
		MeasureCounterBMT:diffuse(0.5,0.5,0.5,1)
	else
		MeasureCounterBMT:diffuse(1,1,1,1)
	end

	local current_stream_length = streamEnd - streamStart
	local current_count = math.floor(current_measure - streamStart) + 1

	local is_end = current_count > current_stream_length
	-- Debugging text
	-- SCREENMAN:SystemMessage("measure " .. tostring(current_measure) .. " stream start: " .. tostring(streamStart) .. " stream end " .. tostring(streamEnd) .. " text " .. text .. " remaining text " .. remainingStreamText .. " is_end " .. tostring(is_end))
	return text, remainingStreamText, is_end 
end

local Update = function(self, delta)

	if not streams.Measures then return end

	-- Note this is a floating point value...
	local curr_measure = (math.floor(PlayerState:GetSongPosition():GetSongBeatVisible()))/4

	-- if a new measure has occurred
	if curr_measure > prev_measure then
		prev_measure = curr_measure
		local curr_measure_obj = streams.Measures[stream_index]
		local text, remaining_text, is_end = GetTextForCurrentMeasure(curr_measure, streams.Measures, stream_index)
		-- Subtract from the total stream counter if we've made forward progress
		-- We need to do this first, or the update will be late.
		local progress_into_stream = 0
		if curr_measure_obj then
			progress_into_stream = curr_measure - curr_measure_obj.streamStart
		end

		-- I have no idea why we need to update on beat 3 but this works...
		local is_measure_boundary = progress_into_stream > 0 and progress_into_stream % 1 == 0.75

		-- If stream_index is 1 and we're not yet in the first measure, blank out the remaining text.
		if stream_index == 1 and progress_into_stream < 1 then
			remaining_text = ""
		end 

		if curr_measure_obj and not curr_measure_obj.isBreak and is_measure_boundary then
			remaining_stream = remaining_stream - 1
		end
		-- If we're still within the current section
		if not is_end then
			MeasureCounterBMT:settext(text)
			RemainingCounterBMT:settext(remaining_text)
		-- In a new section, we should check if curr_measure overlaps with it
		else
			stream_index = stream_index + 1
			text, remaining_text, is_end = GetTextForCurrentMeasure(curr_measure, streams.Measures, stream_index)
			MeasureCounterBMT:settext(text)
			RemainingCounterBMT:settext(remaining_text)
		end
	end
end


local af = Def.ActorFrame{
	InitCommand=function(self)
		self:queuecommand("SetUpdate")
	end,
	CurrentSongChangedMessageCommand=function(self)
		InitializeMeasureCounter()
	end,
	SetUpdateCommand=function(self)
		self:SetUpdateFunction( Update )
	end
}

af[#af+1] = LoadFont("_wendy small")..{
	InitCommand=function(self)
		MeasureCounterBMT = self

		local xPosition = 0
		local playeroptions = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
		local is_reverse = playeroptions:UsingReverse()
		-- Permanently enable recentering
		local width = GAMESTATE:GetCurrentStyle(player):GetWidth(player)
		local NumColumns = GAMESTATE:GetCurrentStyle():ColumnsPerPlayer()
		local xOffset = (width/NumColumns)
		if player == PLAYER_1 then
			xPosition = GetNotefieldX(player) - xOffset
		else
			xPosition = GetNotefieldX(player) + xOffset
		end

		self:zoom(0.35):shadowlength(1):horizalign(center)
		self:xy( xPosition, _screen.cy )
	end
}

-- Remaining stream counter
af[#af+1] = LoadFont("_wendy small")..{
	InitCommand=function(self)
		RemainingCounterBMT = self
		RemainingCounterBMT:diffuse(0.5,0.5,0.5,1)

		local xPosition = 0
		local playeroptions = GAMESTATE:GetPlayerState(player):GetPlayerOptions("ModsLevel_Preferred")
		local is_reverse = playeroptions:UsingReverse()
		local yPosition = _screen.cy + 25 * (is_reverse and -1 or 1)   -- Lower on screen (higher if using reverse)
		-- Permanently enable recentering
		local width = GAMESTATE:GetCurrentStyle(player):GetWidth(player)
		local NumColumns = GAMESTATE:GetCurrentStyle():ColumnsPerPlayer()
		local xOffset = (width/NumColumns)
		if player == PLAYER_1 then
			xPosition = GetNotefieldX(player) - xOffset
		else
			xPosition = GetNotefieldX(player) + xOffset
		end
		
		-- Permanently enable offset
		-- local yOffset = 55 * (is_reverse and -1 or 1) 
		self:zoom(0.35):shadowlength(1):horizalign(center)
		self:xy( xPosition, yPosition )
	end
}

return af
