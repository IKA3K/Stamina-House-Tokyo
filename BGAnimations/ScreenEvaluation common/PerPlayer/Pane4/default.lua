local player = ...
local pn = ToEnumShortString(player)

-- table of offet values obtained during this song's playthrough
-- obtained via ./BGAnimations/ScreenGameplay overlay/JudgmentOffsetTracking.lua
local sequential_offsets = SL[pn].Stages.Stats[SL.Global.Stages.PlayedThisGame + 1].sequential_offsets
local pane_width, pane_height = 300, 180

-- ---------------------------------------------

local abbreviations = {
	Competitive = { "Fan", "Ex", "Gr", "Dec", "WO" },
	ECFA = { "Fan", "Fan", "Ex", "Gr", "Dec" },
	StomperZ = { "Perf", "Gr", "Good", "Hit", "" }
}

-- ---------------------------------------------
-- if players have disabled W4 or W4+W5, there will be a smaller pool
-- of judgments that could have possibly been earned
local num_judgments_available = SL.Global.ActiveModifiers.WorstTimingWindow
local worst_window = SL.Preferences[SL.Global.GameMode]["TimingWindowSecondsW"..(num_judgments_available > 0 and num_judgments_available or 5)]

-- ---------------------------------------------
-- sequential_offsets is a table of all timing offsets in the order they were earned.
-- The sequence is important for the Scatter Plot, but irrelevant here; we are only really
-- interested in how many +0.001 offsets were earned, how many -0.001, how many +0.002, etc.
-- So, we loop through sequential_offsets, and tally offset counts into a new offsets table.
local offsets = {}
local val

for t in ivalues(sequential_offsets) do
	-- the first value in t is CurrentMusicSeconds when the offset occurred, which we don't need here
	-- the second value in t is the offset value or the string "Miss"
	val = t[2]

	if val ~= "Miss" then
		val = (math.floor(val*1000))/1000

		if not offsets[val] then
			offsets[val] = 1
		else
			offsets[val] = offsets[val] + 1
		end
	end
end

-- ---------------------------------------------
-- Actors

local pane = Def.ActorFrame{
	Name="Pane4",
	InitCommand=function(self)
		self:visible(false)
			:xy(-pane_width*0.5, pane_height*1.95)
	end
}

-- "Early" text
pane[#pane+1] = Def.BitmapText{
	Font="_wendy small",
	Text=ScreenString("Early"),
	InitCommand=function(self)
		self:addx(10):addy(-125)
			:zoom(0.3)
			:horizalign(left)
	end,
}

-- "Late" text
pane[#pane+1] = Def.BitmapText{
	Font="_wendy small",
	Text=ScreenString("Late"),
	InitCommand=function(self)
		self:addx(pane_width-10):addy(-125)
			:zoom(0.3)
			:horizalign(right)
	end,
}


-- darkened quad behind bottom judment labels
pane[#pane+1] = Def.Quad{
	InitCommand=function(self)
		self:vertalign(top)
			:zoomto(pane_width, 13 )
			:xy(pane_width/2, 0)
			:diffuse(color("#101519"))
	end,
}


-- centered text for W1
pane[#pane+1] = Def.BitmapText{
	Font="_miso",
	Text=abbreviations[SL.Global.GameMode][1],
	InitCommand=function(self)
		local x = pane_width/2

		self:diffuse( SL.JudgmentColors[SL.Global.GameMode][1] )
			:addx(x):addy(7)
			:zoom(0.65)
	end,
}

-- loop from W2 to the worst_window and add judgment text
-- underneath that portion of the histogram
for i=2,num_judgments_available do

	-- early (left) judgment text
	pane[#pane+1] = Def.BitmapText{
		Font="_miso",
		Text=abbreviations[SL.Global.GameMode][i],
		InitCommand=function(self)
			local window = -1 * SL.Preferences[SL.Global.GameMode]["TimingWindowSecondsW"..i]
			local better_window = -1 * SL.Preferences[SL.Global.GameMode]["TimingWindowSecondsW"..i-1]

			local x = scale(window, -worst_window, worst_window, 0, pane_width )
			local x_better = scale(better_window, -worst_window, worst_window, 0, pane_width)
			local x_avg = (x+x_better)/2

			self:diffuse( SL.JudgmentColors[SL.Global.GameMode][i] )
				:addx(x_avg):addy(7)
				:zoom(0.65)
		end,
	}

	-- late (right) judgment text
	pane[#pane+1] = Def.BitmapText{
		Font="_miso",
		Text=abbreviations[SL.Global.GameMode][i],
		InitCommand=function(self)
			local window = SL.Preferences[SL.Global.GameMode]["TimingWindowSecondsW"..i]
			local better_window = SL.Preferences[SL.Global.GameMode]["TimingWindowSecondsW"..i-1]

			local x = scale(window, -worst_window, worst_window, 0, pane_width )
			local x_better = scale(better_window, -worst_window, worst_window, 0, pane_width)
			local x_avg = (x+x_better)/2

			self:diffuse( SL.JudgmentColors[SL.Global.GameMode][i] )
				:addx(x_avg):addy(7)
				:zoom(0.65)
		end,
	}

end

-- --------------------------------------------------------

-- the line in the middle indicating where truly flawless timing (0ms offset) is
pane[#pane+1] = Def.Quad{
	InitCommand=function(self)
		local x = pane_width/2

		self:vertalign(top)
			:zoomto(1, pane_height - 40 )
			:xy(x, -140)
			:diffuse(1,1,1,0.666)

		if SL.Global.GameMode == "StomperZ" then
			self:diffuse(0,0,0,0.666)
		end
	end,
}


-- --------------------------------------------------------
-- INLINE STATS
-- --------------------------------------------------------

-- --------------------------------------------------------
-- TOPBAR WITH STATISTICS

-- topbar background quad
pane[#pane+1] = Def.Quad{
	InitCommand=function(self)
		self:vertalign(top)
			:zoomto(pane_width, 26 )
			:xy(pane_width/2, -pane_height+13)
			:diffuse(color("#101519"))
	end,
}

-- only bother crunching the numbers and adding extra BitmapText actors if there are
-- valid offset values to analyze; (MISS has no numerical offset and can't be analyzed)
if next(offsets) ~= nil then
	pane[#pane+1] = LoadActor("./Calculations.lua", {offsets, worst_window, pane_width, pane_height})
end

-- avg_timing_error label
pane[#pane+1] = Def.BitmapText{
	Font="_miso",
	Text=ScreenString("MeanTimingError"),
	InitCommand=function(self)
		self:x(25):y(-pane_height+20)
			:zoom(0.575)
	end,
}

-- Standard Dev Label
pane[#pane+1] = Def.BitmapText{
	Font="_miso",
	Text=ScreenString("StandardDeviation"),
	InitCommand=function(self)
		self:x(pane_width/4 + 10):y(-pane_height+20)
			:zoom(0.575)
	end,
}

-- 95th %tile label
pane[#pane+1] = Def.BitmapText{
	Font="_miso",
	Text=ScreenString("Percentile95th"),
	InitCommand=function(self)
		self:x(pane_width/2):y(-pane_height+20)
			:zoom(0.575)
	end,
}

-- median_offset label
pane[#pane+1] = Def.BitmapText{
	Font="_miso",
	Text=ScreenString("Median"),
	InitCommand=function(self)
		self:x(pane_width/4*3 - 10):y(-pane_height+20)
			:zoom(0.575)
	end,
}

-- mode_offset label
pane[#pane+1] = Def.BitmapText{
	Font="_miso",
	Text=ScreenString("Mode"),
	InitCommand=function(self)
		self:x(pane_width-25):y(-pane_height+20)
			:zoom(0.575)
	end,
}

return pane
