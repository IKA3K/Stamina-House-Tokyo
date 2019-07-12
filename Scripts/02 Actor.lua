-- Force Stepmania to move the background to the middle as needed
function Actor:scale_or_crop_background()
	if SL.Global.BackgroundZoom == 1 and SL.Global.BackgroundYOffset == 0 then
		self:scale_or_crop_background_no_move()
		self:xy(SCREEN_CENTER_X, SCREEN_CENTER_Y)
	else
		local xscale= 240 / self:GetWidth()
		local yscale= 135 / self:GetHeight()
		self:zoom(math.min(math.min(xscale, yscale), SL.Global.BackgroundZoom))
		self:xy(SCREEN_CENTER_X + SL.Global.BackgroundXOffset, SCREEN_CENTER_Y + SL.Global.BackgroundYOffset)
	end
	return self
end

