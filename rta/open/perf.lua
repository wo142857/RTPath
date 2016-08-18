
module("perf", package.seeall)

local __G_MEM = {}
setmetatable(__G_MEM, {__mode = "k"})

function mem_classify_record (own, key, val)
	if not __G_MEM then
		__G_MEM = {}
		setmetatable(__G_MEM, {__mode = "k"})
	end
	if not __G_MEM[own] then
		__G_MEM[own] = {}
		setmetatable(__G_MEM[own], {__mode = "kv"})
	end

	__G_MEM[own]["KEY"] = key
	__G_MEM[own]["VAL"] = val
end

function mem_classify_obtain (own, key)
	if not __G_MEM or not __G_MEM[own] then
		return nil
	end
	if key ~= __G_MEM[own]["KEY"] then
		return nil
	else
		return __G_MEM[own]["VAL"]
	end
end


function mem_function_record (tag, fun, max)
	local mem = {}
	setmetatable(mem, {__mode = "kv"})
	local map = {}
	map["MAX"] = max
	map["IDX"] = 0

	if not __G_MEM then
		__G_MEM = {}
		setmetatable(__G_MEM, {__mode = "k"})
	end

	__G_MEM[tag] = function (...)
		local x = scan.dump({...})
		local r = mem[x]
		if r == nil then
			local idx = map["IDX"] + 1
			if idx > map["MAX"] then
				idx = 1
			end
			map["IDX"] = idx
			local old = map[idx]
			if old then
				mem[ old ] = nil
			end
			map[idx] = x

			r = { fun(...) }
			mem[x] = r
		end
		return unpack(r)
	end
	return __G_MEM[tag]
end
