function GetSimfileString(path)

	local filename, filetype
	local files = FILEMAN:GetDirListing(path)

	for file in ivalues(files) do
		if file:find(".+%.[sS][sS][cC]$") then
			-- Finding a .ssc file is preferable.
			-- If we find one, stop looking.
			filename = file
			filetype = "ssc"
			break
		elseif file:find(".+%.[sS][mM]$") then
			-- Don't break if we find a .sm file first;
			-- there might still be a .ssc file waiting.
			filename = file
			filetype = "sm"
		end
	end

	-- if neither a .ssc nor a .sm file were found, bail now
	if not (filename and filetype) then return end

	-- create a generic RageFile that we'll use to read the contents
	-- of the desired .ssc or .sm file
	local f = RageFileUtil.CreateRageFile()
	local contents

	-- the second argument here (the 1) signifies
	-- that we are opening the file in read-only mode
	if f:Open(path .. filename, 1) then
		contents = f:Read()
	end

	-- destroy the generic RageFile now that we have the contents
	f:destroy()
	return contents, filetype
end

-- ----------------------------------------------------------------
-- SOURCE: https://github.com/JonathanKnepp/SM5StreamParser

-- Which note types are counted as part of the stream?
local TapNotes = {1,2,4}


-- Utility function to replace regex special characters with escaped characters
local function regexEncode(var)
	return (var:gsub('%%', '%%%'):gsub('%^', '%%^'):gsub('%$', '%%$'):gsub('%(', '%%('):gsub('%)', '%%)'):gsub('%.', '%%.'):gsub('%[', '%%['):gsub('%]', '%%]'):gsub('%*', '%%*'):gsub('%+', '%%+'):gsub('%-', '%%-'):gsub('%?', '%%?'))
end

-- Parse the measures section out of our simfile
local function GetSimfileChartString(SimfileString, StepsType, Difficulty, Filetype)
	local measuresString = nil

	if Filetype == "ssc" then
		-- SSC File
		-- Loop through each chart in the SSC file
		for chart in SimfileString:gmatch("#NOTEDATA.-#NOTES:[^;]*") do
			-- Find the chart that matches our difficulty and game type
			if(chart:match("#STEPSTYPE:"..regexEncode(StepsType)) and chart:match("#DIFFICULTY:"..regexEncode(Difficulty))) then
				--Find just the notes and remove comments
				measuresString = chart:match("#NOTES:[\r\n]+([^;]*)\n?$"):gsub("\\[^\r\n]*","") .. ";"
			end
		end
	elseif Filetype == "sm" then
		-- SM FILE
		-- Loop through each chart in the SM file
		for chart in SimfileString:gmatch("#NOTES[^;]*") do
			-- split the entire chart string into pieces on ":"
			local pieces = {}
			for str in chart:gmatch("[^:]+") do
				pieces[#pieces+1] = str
			end

			-- the pieces table should contain 7 numerically indexed items
			-- 2, 4, and 7 are the indices we care about for finding the correct chart
			-- index 2 will contain the steps_type (like "dance-single")
			-- index 4 will contain the difficulty (like "challenge")

			-- use gsub to scrub out line breaks (and other irrelevant characters?)
			local st = pieces[2]:gsub("[^%w-]", "")
			local diff = pieces[4]:gsub("[^%w]", "")

			-- if this particular chart's steps_type matches the desired StepsType
			-- and its difficulty string matches the desired Difficulty
			if (st == StepsType) and (diff == Difficulty) then
				-- then index 7 contains the notedata that we're looking for
				-- use gsub to remove comments, store the resulting string,
				-- and break out of the chart loop now
				measuresString = pieces[7]:gsub("//[^\r\n]*","") .. ";"
				break
			end
		end
	end

	return measuresString
end

-- Figure out which measures are considered a stream of notes
local function getStreamMeasures(measuresString, notesPerMeasure)
	-- Make our stream notes array into a string for regex
	local TapNotesString = ""
	for i, v in ipairs(TapNotes) do
		TapNotesString = TapNotesString .. v
	end

	-- Which measures are considered a stream?
	local streamMeasures = {}

	-- Keep track of the measure and its timing (8ths, 16ths, etc)
	local measureCount = 1
	local measureTiming = 0
	-- Keep track of the notes in a measure
	local measureNotes = {}

	-- How many

	-- Loop through each line in our string of measures
	for line in measuresString:gmatch("[^\r\n]+")
	do
		-- If we hit a comma or a semi-colon, then we've hit the end of our measure
		if(line:match("^[,;]%s*")) then
			-- Does this measure contain a stream of notes based on our notesPerMeasure global?
			if(#measureNotes >= notesPerMeasure) then
				table.insert(streamMeasures, measureCount)
			end

			-- Reset iterative variables
			measureTiming = 0
			measureCount = measureCount + 1
			measureNotes = {}
		else
			-- Iterate the measure timing
			measureTiming = measureTiming + 1

			-- Is this a note?
			if(line:match("["..TapNotesString.."]")) then
				table.insert(measureNotes, measureTiming)
			end
		end
	end

	return streamMeasures, measureCount
end

-- Get the start/end of each stream and break sequence in our table of measures
local function getStreamSequences(streamMeasures, measureSequenceThreshold, totalMeasures)
	local streamSequences = {}

	local counter = 1
	local streamEnd = nil

	-- Allow for nil threshold, which will be used to provide an accurate breakdown
	local minimumBreakSequence = 2
	local minimumStreamSequence = 1
	if measureSequenceThreshold ~= nil then
		if measureSequenceThreshold > minimumBreakSequence then
			minimumBreakSequence = measureSequenceThreshold
		end

		if measureSequenceThreshold > minimumStreamSequence then
			minimumStreamSequence = measureSequenceThreshold
		end
	end

	-- First add an initial break if it's larger than measureSequenceThreshold
	-- Also predefine streamEnd, or this won't work for single stream seqeuences to start.
	-- This needs to be the measure after the break ends, or it'll be off by one on ONLY
	-- the first stream :loam:
	if(#streamMeasures > 0) then
		local breakStart = 0
		local k, v = next(streamMeasures) -- first element of a table
		local breakEnd = streamMeasures[k] - 1
		streamEnd = breakEnd + 1
		if (breakEnd - breakStart >= minimumBreakSequence) then
			table.insert(streamSequences,
				{streamStart=breakStart, streamEnd=breakEnd, isBreak=true})
		end
	end

	-- Which sequences of measures are considered a stream?
	for k,v in pairs(streamMeasures) do
		local curVal = streamMeasures[k]
		local nextVal = streamMeasures[k+1] and streamMeasures[k+1] or -1

		-- Are we still in sequence?
		if(curVal + 1 == nextVal) then
			counter = counter + 1
			streamEnd = curVal + 1
		else
			-- Found the first section that counts as a stream
			if(counter >= minimumStreamSequence) then
				streamStart = (streamEnd - counter)
				-- Add the current stream.
				table.insert(streamSequences,
					{streamStart=streamStart, streamEnd=streamEnd, isBreak=false})
			end

			-- Add any trailing breaks if they're larger than minimumBreakSequence
			-- as the next item is going to be a stream measure.
			local breakStart = curVal
			local breakEnd = (nextVal ~= -1) and nextVal - 1 or totalMeasures
			if (breakEnd - breakStart >= minimumBreakSequence) then
				table.insert(streamSequences,
					{streamStart=breakStart, streamEnd=breakEnd, isBreak=true})
			end
			counter = 1
			-- Need to modify streamEnd to nextVal just in case there's another 1 measure stream 
			-- coming up after a minimum length break (e.g. 1 (1) 1); the streamEnd gets messed up
			-- and reports the 2nd one as starting on the first's end measure; nextVal contains the
			-- next stream so we're good.
			streamEnd = nextVal	
		end
	end

	return streamSequences
end


-- GetNPSperMeasure() accepts three arguments:
-- 		Song, a song object provided by something like GAMESTATE:GetCurrentSong()
-- 		StepsType, a string like "dance-single" or "pump-double"
-- 		Difficulty, a string like "Beginner" or "Challenge"
-- GetNPSperMeasure() returns two values
--		PeakNPS, a number representing the peak notes-per-second for the given stepchart
--			This is an imperfect measurement, as we sample the note density per-second-per-measure, not per-second.
--			It is (unlikely but) possible for the true PeakNPS to be spread across the boundary of two measures.
--		Density, a numerically indexed table containing the notes-per-second value for each measure
--			The Density table is indexed from 1 (as Lua tables go); simfile charts, however, start at measure 0.
--			So if you're looping through the Density table, subtract 1 from the current index to get the
--			actual measure number.

function GetNPSperMeasure(Song, StepsType, Difficulty)
	local SongDir = Song:GetSongDir()
	local SimfileString, Filetype = GetSimfileString( SongDir )
	if not SimfileString then return end

	-- Discard header info; parse out only the notes
	local ChartString = GetSimfileChartString(SimfileString, StepsType, Difficulty, Filetype)
	if not ChartString then return end

	-- Make our stream notes array into a string for regex
	local TapNotesString = ""
	for i, v in ipairs(TapNotes) do
		TapNotesString = TapNotesString .. v
	end

	-- the main density table, indexed by measure number
	local Density = {}
	-- Keep track of the measure
	local measureCount = 0
	-- Keep track of the number of notes in the current measure while we iterate
	local NotesInThisMeasure = 0

	local NPSforThisMeasure, PeakNPS, BPM = 0, 0, 0
	local TimingData = Song:GetTimingData()

	-- Loop through each line in our string of measures
	for line in ChartString:gmatch("[^\r\n]+") do

		-- If we hit a comma or a semi-colon, then we've hit the end of our measure
		if(line:match("^[,;]%s*")) then

			DurationOfMeasureInSeconds = TimingData:GetElapsedTimeFromBeat((measureCount+1)*4) - TimingData:GetElapsedTimeFromBeat(measureCount*4)
			if (DurationOfMeasureInSeconds == 0) then
				NPSforThisMeasure = 0
			else
				NPSforThisMeasure = NotesInThisMeasure/DurationOfMeasureInSeconds
			end

			-- measureCount in SM truly starts at 0, but indexed Lua tables start at 1
			-- add 1 now so the table behaves and subtract 1 later when drawing the histogram
			Density[measureCount+1] = NPSforThisMeasure

			-- determine whether this measure contained the PeakNPS
			if NPSforThisMeasure > PeakNPS then PeakNPS = NPSforThisMeasure end
			-- increment the measureCount
			measureCount = measureCount + 1
			-- and reset NotesInThisMeasure
			NotesInThisMeasure = 0
		else
			-- does this line contain a note?
			if(line:match("["..TapNotesString.."]")) then
				NotesInThisMeasure = NotesInThisMeasure + 1
			end
		end
	end

	return PeakNPS, Density
end



function GetStreams(SongDir, StepsType, Difficulty, NotesPerMeasure, MeasureSequenceThreshold)

	local SimfileString, Filetype = GetSimfileString( SongDir )
	if not SimfileString then return end

	-- Parse out just the contents of the notes
	local ChartString = GetSimfileChartString(SimfileString, StepsType, Difficulty, Filetype)
	if not ChartString then return end

	-- Which measures have enough notes to be considered as part of a stream?
	local StreamMeasures, totalMeasures = getStreamMeasures(ChartString, NotesPerMeasure)

	-- Empty out all vars that are unusedg once done to allow errors to be shown correctly.
	SongDir = nil
	StepsType = nil
	ChartString = nil
	
	-- Which sequences of measures are considered a stream?
	return (getStreamSequences(StreamMeasures, MeasureSequenceThreshold, totalMeasures))
end


-- Additions from old files


-- Get breakdown to show above banner
function GetStreamBreakdown(SongDir, StepsType, Difficulty)
	local NotesPerMeasure = 16
	local MeasureSequenceThreshold = 2
	local streams = GetStreams(SongDir, StepsType, Difficulty, NotesPerMeasure, MeasureSequenceThreshold)

	if not streams then
		return ""
	end

	for i, stream in ipairs(streams) do
		local streamString = tostring(stream.streamEnd - stream.streamStart)
		if stream.isBreak then
			streams[i] = "(" .. streamString .. ")"
		else
			streams[i] = streamString
		end
	end

	return table.concat(streams, " ")
end

