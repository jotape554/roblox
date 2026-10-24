local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }

-- 1234 -> "$1.2K", 5000000 -> "$5M"
function Format.money(amount: number): string
	local n = math.max(0, math.floor(amount))
	if n < 1000 then
		return "$" .. tostring(n)
	end
	local value = n
	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	local text
	if value >= 100 then
		text = tostring(math.floor(value))
	else
		text = string.format("%.1f", math.floor(value * 10) / 10)
		text = (string.gsub(text, "%.0$", ""))
	end
	return "$" .. text .. SUFFIXES[index]
end

-- 75 -> "1:15"
function Format.time(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

return Format
