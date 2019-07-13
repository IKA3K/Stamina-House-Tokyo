local player = ...
local pn = ToEnumShortString(player)
local p = PlayerNumber:Reverse()[player]
local show = false

local function getInputHandler(actor)
    return (function (event)
        if event.GameButton == "Select" and event.PlayerNumber == player then
            if event.type == "InputEventType_FirstPress" then
                show = true
                actor:queuecommand("UpdateGraphState")
            elseif event.type == "InputEventType_Release" then
                show = false
                actor:queuecommand("UpdateGraphState")
            end
        end

        return false
    end)
end

local bannerWidth = 418
local bannerHeight = 164
local padding = 10

-- Trims streams to desired length
local function GetTrimmedStreamBreakdown(streams, maximumEntriesAllowed)
	if #streams <= maximumEntriesAllowed then
		return streams
	end

	-- Assume that maximum number of entries is 25 to keep things simple -- if it's over 25, start applying
	-- heuristics to trim the size down.

	-- Total stream/break are recorded so that we get a better picture of how much stream is in the section. For every 25% add another *.
	local tempStreams = {}
	for i, stream in ipairs(streams) do
		-- Cache the stream/break counts per stream object so that we're not
		local sectionLength = stream.streamEnd - stream.streamStart
		if stream.isBreak then
			table.insert(tempStreams, {streamStart=stream.streamStart, streamEnd=stream.streamEnd, breakCount=sectionLength, streamCount=0, combined=false, isBreak=true})
		else
			table.insert(tempStreams, {streamStart=stream.streamStart, streamEnd=stream.streamEnd, breakCount=0, streamCount=sectionLength, combined=false, isBreak=false})
		end
	end
	streams = tempStreams
	if #streams <= maximumEntriesAllowed then
		return streams
	end

	-- each pass should just try to combine adjacent sections. breaks will get longer and longer as they are removed.
	local minBreakLength = 2
	while #streams > maximumEntriesAllowed do
		-- Trim short breaks
		tempStreams = {}
		for i, stream in ipairs(streams) do
			-- Add breaks if and only if they meet the criteria
			local stream = streams[i]
			if stream.isBreak then
				if stream.streamEnd - stream.streamStart >= minBreakLength then
					table.insert(tempStreams, stream)
				end
			else
				table.insert(tempStreams, stream)
			end
		end

		streams = tempStreams
		tempStreams = {}
		i = 1
		while i <= #streams do
			-- Combine the next item into this item if and only if they're both streams
			local currStream = streams[i]
			local nextStream = streams[i+1]
			local lastStream = tempStreams[#tempStreams]
			-- First handle continuing stream
			if lastStream ~= nil and not lastStream.isBreak and not currStream.isBreak then
				tempStreams[#tempStreams] = {streamStart=lastStream.streamStart, streamEnd=currStream.streamEnd, breakCount=lastStream.breakCount + 1, streamCount=lastStream.streamCount + currStream.streamCount, combined=true, isBreak=false}
				lastStream = tempStreams[#tempStreams]
				if lastStream.streamStart + 1 == lastStream.streamEnd then
					error("Producing 1* with obj " .. table.tostring(currStream))
				end
				i = i + 1
			elseif not currStream.isBreak and nextStream ~= nil and not nextStream.isBreak then
				-- This should insert an item
				table.insert(tempStreams, {streamStart=currStream.streamStart, streamEnd=nextStream.streamEnd, breakCount=minBreakLength - 1, streamCount=currStream.streamCount + nextStream.streamCount, isBreak=false, combined=true})
				lastStream = tempStreams[#tempStreams]
				if lastStream.streamStart + 1 == lastStream.streamEnd then
					error("Producing 1* with curr obj " .. table.tostring(currStream) .. " next obj " .. table.tostring(nextStream))
				end
				i = i + 2
			else
				table.insert(tempStreams, currStream)
				i = i + 1
			end
		end

		streams = tempStreams

		if #streams <= maximumEntriesAllowed then
			return streams
		end
		minBreakLength = minBreakLength + 1
	end
	return streams
end

-- Get breakdown to show above banner
local function GetStreamBreakdownShort(SongDir, StepsType, Difficulty)
	local NotesPerMeasure = 16
	local MeasureSequenceThreshold = 2
	local streams = GetStreams(SongDir, StepsType, Difficulty, NotesPerMeasure, nil)
	
	local ismarathon = false
	-- if the length of the song is over 30 minutes, use marathon notation.
	if GAMESTATE:GetCurrentSong():MusicLengthSeconds() >= 16*60 then
		ismarathon = true
	end

	-- nil out unused big objects which prevent errors from being shown.
	SongDir = nil
	StepsType = nil

	if not streams then
		return ""
	end

	-- Truncate breaks at the beginning and end.
	if streams[1] ~= nil and streams[1].isBreak then
		table.remove(streams, 1)
	end

	if streams[#streams] ~= nil and streams[#streams].isBreak then
		table.remove(streams, #streams)
	end
	
	streams = GetTrimmedStreamBreakdown(streams, 20) -- Maximum 20 entries
	local lastStream
	local streamText = {}
	for i, stream in ipairs(streams) do
		local streamLength = stream.streamEnd - stream.streamStart	
		local streamString = tostring(streamLength)
		if stream.isBreak then
			local breakString =  "(" .. streamString .. ")"
			streamText[i] = breakString
		elseif stream.combined then
			local stars = "****"
			if stream.streamCount / streamLength > 0.75 then
				stars = "*"
			elseif stream.streamCount / streamLength > 0.50 then
				stars = "**"
			elseif stream.streamCount / streamLength > 0.25 then
				stars = "***"
			end
			if ismarathon then
				streamText[i] = tostring(stream.streamCount) .. stars
			else
				streamText[i] = streamLength .. stars
			end
		else
			streamText[i] = streamLength
		end
		lastStream = stream
	end

	-- Print a debug string showing the measure breakdown in case something is funky
	-- local measure_breakdown = ""
	-- for i, stream in ipairs(streams) do
	--	measure_breakdown = measure_breakdown .. "[" .. tostring(stream.streamStart) .. "/" .. tostring(stream.streamEnd) .. "]"
	-- end
	-- SCREENMAN:SystemMessage(measure_breakdown)

	return table.concat(streamText, " "), ismarathon
end

-- TODO make this global
local function getTimes(npsPerMeasure, timingData)
    if (npsPerMeasure == nil) then
        return {firstSecond=0, lastSecond=0, totalSeconds=0}
    end

    -- insane, but whatever
    local totalMeasures = 0
    for i, a in ipairs(npsPerMeasure) do
        totalMeasures = totalMeasures + 1
    end

    local firstSecond = 0
    local lastSecond = timingData:GetElapsedTimeFromBeat(totalMeasures * 4)
    local totalSeconds = lastSecond - firstSecond

    return {firstSecond=firstSecond, lastSecond=lastSecond, totalSeconds=totalSeconds}
end

local function getGraphParams(song, steps)
    	local difficulty = ToEnumShortString(steps:GetDifficulty())
    	local stepsType = ToEnumShortString(steps:GetStepsType()):gsub("_", "-"):lower()
    	local peakNps, npsPerMeasure = GetNPSperMeasure(song, stepsType, difficulty)
	local timingData = song:GetTimingData()
	local times = getTimes(npsPerMeasure, timingData)

	local rvalue = {
		second=times.firstSecond,
		graphWidthSeconds=times.lastSecond - times.firstSecond,
		song=song,
		steps=steps,
		peakNps=peakNps,
		npsPerMeasure=npsPerMeasure
	}
	return rvalue
end


return Def.ActorFrame {
    -- song and course changes
    OnCommand=cmd(queuecommand, "StepsHaveChanged"),
    CurrentSongChangedMessageCommand=cmd(queuecommand, "StepsHaveChanged"),
    CurrentCourseChangedMessageCommand=cmd(queuecommand, "StepsHaveChanged"),

    InitCommand=function(self)
        local zoom, xPos

        if IsUsingWideScreen() then
            zoom = 0.7655
            xPos = 170
        else
            zoom = 0.75
            xPos = 166
        end

        self:zoom(zoom)
        self:xy(_screen.cx - xPos - ((bannerWidth / 2 - padding) * zoom), 112 - ((bannerHeight / 2 - padding) * zoom))

        if (player == PLAYER_2) then
            self:addy((bannerHeight / 2 - (padding * 0.5)) * zoom)
        end

        self:diffusealpha(0)
        self:queuecommand("Capture")
    end,

    CaptureCommand=function(self)
        SCREENMAN:GetTopScreen():AddInputCallback(getInputHandler(self))
    end,

    StepsHaveChangedCommand=function(self, params)
        if show then
            self:queuecommand("UpdateGraphState")
        end
    end,

    UpdateGraphStateCommand=function(self, params)
        if show and not GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentSong() then
            local song = GAMESTATE:GetCurrentSong()
            local steps = GAMESTATE:GetCurrentSteps(player)
            self:playcommand("ChangeSteps", getGraphParams(song,steps))
            self:stoptweening()
            self:linear(0.1):diffusealpha(0.9)
        else
            self:stoptweening()
            self:linear(0.1):diffusealpha(0)
        end
    end,

    CreateDensityGraph(bannerWidth - (padding * 2), bannerHeight / 2 - (padding * 1.5)),

    Def.Quad {
        InitCommand=function(self)
            self:zoomto(bannerWidth - (padding * 2), 20)
                :diffuse(color("#000000"))
                :diffusealpha(0.8)
                :align(0, 0)
                :y(bannerHeight / 2 - (padding * 1.5) - 20)
        end,
    },

    Def.BitmapText{
        Font="_miso",
        InitCommand=function(self)
            self:diffuse(color("#ffffff"))
                :horizalign("left")
                :y(bannerHeight / 2 - (padding * 1.5) - 20 + 2)
                :x(5)
                :maxwidth(bannerWidth - (padding * 2) - 10)
                :align(0, 0)
                :Stroke(color("#000000"))
        end,

        StepsHaveChangedCommand=function(self, params)
            if show then
                self:queuecommand("UpdateGraphState")
            end
        end,

        UpdateGraphStateCommand=function(self)
            if show and not GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentSong() then
                local song_dir = GAMESTATE:GetCurrentSong():GetSongDir()
                local steps = GAMESTATE:GetCurrentSteps(player)
                local steps_type = ToEnumShortString( steps:GetStepsType() ):gsub("_", "-"):lower()
                local difficulty = ToEnumShortString( steps:GetDifficulty() )
                local breakdown, ismarathon = GetStreamBreakdownShort(song_dir, steps_type, difficulty)

                if breakdown == "" then
                    self:settext("No streams!")
                elseif ismarathon then
                    self:settext("Marathon: " .. breakdown)
		else
                    self:settext("Streams: " .. breakdown)
                end

                return true
            end
        end
    }
}
