local FormatNumbers = {}

function FormatNumbers.Compact(value)
	value = tonumber(value) or 0
	if value >= 1000000 then
		return string.format("%.1fM", value / 1000000)
	end
	if value >= 1000 then
		return string.format("%.1fK", value / 1000)
	end
	return tostring(math.floor(value + 0.5))
end

return FormatNumbers
