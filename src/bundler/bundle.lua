local PARAMS = { ... }

local function getFlag(flag)
	for _, v in next, PARAMS do
		if v == flag then
			return true
		end
	end
	return false
end

local SCRIPT_NAME = assert(PARAMS[1], "No script name specified")
local VERSION = assert(PARAMS[2], "No version specified")
local OUTPUT_PATH = string.format("output/%s-build.lua", SCRIPT_NAME)
local DEBUG_MODE = getFlag("debug")
local VERBOSE = getFlag("verbose")
local MINIFY = getFlag("minify")

local ROJO_INPUT = "Input.rbxm"
local RUNTIME_FILE = "bundler/runtime.lua"
local BUNDLE_TEMP = "bundler/bundle.tmp"

local format, gsub, match = string.format, string.gsub, string.match
local insert, concat = table.insert, table.concat

---Converts a string to be safely read by the Lua interpreter.
---@param input string
---@return string
local function safeFormat(input)
	return format("%q", input)
end

---Convert some specific snippets to work in luamin.
---@param source string
---@return string
local function transformInput(source)
	-- Capture (var) (+-/*%^..)= (value)
	-- Substitute %1 = %1 %2 %3
	source = gsub(source, "([%w_]+)%s*([%+%-%*/%%^%.]%.?)=%s*", "%1 = %1 %2")

	-- Capture whole word 'continue'
	-- Substitute __CONTINUE__()
	source = gsub(source, "(%s+)continue(%s+)", "%1__CONTINUE__()%2")

	return source
end

---@param source string
---@return string
local function transformOutput(source)
	-- Substitute ...: with (...):
	-- For a luamin bug caused by calling varargs
	source = gsub(source, "%.%.%.:", "(...):")

	-- Capture __CONTINUE__()
	-- Substitute continue
	source = gsub(source, "__CONTINUE__%(%)", "continue;")

	return source
end

---@param source string
---@return string
local function minify(source)
	remodel.writeFile(BUNDLE_TEMP, transformInput(source))

	os.execute("node bundler/minify.js")
	local output = remodel.readFile(BUNDLE_TEMP)

	os.remove(BUNDLE_TEMP)

	return transformOutput(output)
end

---@param object LocalScript | ModuleScript
---@param output table<number, string>
local function writeModule(object, output)
	local id = object:GetFullName()
	local source = remodel.getRawProperty(object, "Source")

	local path = safeFormat(id)
	local parent = object.Parent and safeFormat(object.Parent:GetFullName()) or "nil"
	local name = safeFormat(object.Name)
	local className = safeFormat(object.ClassName)

	if DEBUG_MODE then
		local def = concat({
			"newModule(" .. name .. ", " .. className .. ", " .. path .. ", " .. parent .. ", function ()",
			"local fn = assert(loadstring(" .. safeFormat(source) .. ", '@'.." .. path .. "))",
			"setfenv(fn, newEnv(" .. path .. "))",
			"return fn()",
			"end)",
		}, " ")
		insert(output, def)
	else
		local def = concat({
			"newModule(" .. name .. ", " .. className .. ", " .. path .. ", " .. parent .. ", function ()",
			"return setfenv(function()",
			source,
			"end, newEnv(" .. path .. "))()",
			"end)",
		}, " ")
		insert(output, def)
	end
end

---@param object Instance
---@param output table<number, string>
local function writeInstance(object, output)
	local id = object:GetFullName()

	local path = safeFormat(id)
	local parent = object.Parent and safeFormat(object.Parent:GetFullName()) or "nil"
	local name = safeFormat(object.Name)
	local className = safeFormat(object.ClassName)

	local def = concat({
		"newInstance(" .. name .. ", " .. className .. ", " .. path .. ", " .. parent .. ")",
	}, "\n")
	insert(output, def)
end

---@param object LocalScript | ModuleScript
---@param output table<number, string>
local function writeInstanceTree(object, output)
	if object.ClassName == "LocalScript" or object.ClassName == "ModuleScript" then
		writeModule(object, output)
	else
		writeInstance(object, output)
	end

	for _, child in next, object:GetChildren() do
		writeInstanceTree(child, output)
	end
end

local function main()
	local output = {}
	local model = remodel.readModelFile(ROJO_INPUT)[1]

	-- Add instances
	writeInstanceTree(model, output)

	-- Minify current output
	if MINIFY then
		output = { minify(concat(output, "\n")) }
	end

	-- Core runtime
	local runtime = gsub(remodel.readFile(RUNTIME_FILE), "__VERSION__", safeFormat(VERSION))
	insert(output, 1, runtime)
	insert(output, "init()")

	if VERBOSE then
		insert(output, 2, "local START_TIME = os.clock()")
		insert(output, 'print("[' .. SCRIPT_NAME .. ']: Ran in " .. (os.clock() - START_TIME) * 1000 .. " ms")')
	end

	-- Write to file
	remodel.createDirAll(match(OUTPUT_PATH, "^(.*)[/\\]"))
	remodel.writeFile(OUTPUT_PATH, concat(output, "\n\n"))

	print("[CI " .. VERSION .. "] Bundle written to " .. OUTPUT_PATH)
end

main()
