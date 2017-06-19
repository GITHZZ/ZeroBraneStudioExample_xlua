local CustomApiCreater = 
{
	desc = "用于生成或修改自定义的api文件",
	author = "hezunzu",
	date = "2017-4-18 20:17:30"
}

local lfs = require("lfs")
local G = ...
local id = G.ID("sample.customLibManager")

-- Events that are marked with "return false" can return `false` to
-- abort further processing.
-- For `onEditorPreSave` event it means that file saving will be aborted.
-- For `onEditorPreClose` event it means that closing an editor tab will be aborted.
-- For `onEditorKeyDown` event it means that the key will be "eaten".
-- For `onEditorAction` event it means that the action will not be executed.
-- For `onFiletreeActivate` event it means that no further processing is done.
-- For `onEditorCharAdded` event it means that no further processing is done
-- (but the character is still added to the editor).
-- line numbers are 1-based in callbacks
local events = {
  onRegister =         function(self) end,
  onUnRegister =       function(self) end,
  onEditorLoad =       function(self, editor) end,
  onEditorPreClose =   function(self, editor) end, -- return false
  onEditorClose =      function(self, editor) end,
  onEditorNew =        function(self, editor) end,
  onEditorPreSave =    function(self, editor, filepath) end, -- return false
  onEditorSave =       function(self, editor) end,
  onEditorFocusLost =  function(self, editor) end,
  onEditorFocusSet =   function(self, editor) end,
  onEditorAction =     function(self, editor, event) end, -- return false
  onEditorKeyDown =    function(self, editor, event) end, -- return false
  onEditorCharAdded =  function(self, editor, event) end, -- return false
  onEditorUserlistSelection = function(self, editor, event) end, -- return false
  onEditorMarkerUpdate = function(self, editor, marker, line, value) end, -- return false
  onEditorUpdateUI =   function(self, editor, event) end,
  onEditorPainted =    function(self, editor, event) end,
  onEditorCallTip =    function(self, editor, tip, value, eval) end, -- return false
  onFiletreeActivate = function(self, tree, event, item) end, -- return false
  onFiletreePreExpand = function(self, tree, event, item) end, -- return false
  onFiletreeExpand =   function(self, tree, event, item) end,
  onFiletreePreCollapse = function(self, tree, event, item) end, -- return false
  onFiletreeCollapse = function(self, tree, event, item) end,
  onFiletreeLDown =    function(self, tree, event, item) end,
  onFiletreeRDown =    function(self, tree, event, item) end,
  onMenuEditor =       function(self, menu, editor, event) end,
  onMenuEditorTab =    function(self, menu, notebook, event, index) end,
  onMenuOutput =       function(self, menu, editor, event) end,
  onMenuOutputTab =    function(self, menu, notebook, event, index) end,
  onMenuConsole =      function(self, menu, editor, event) end,
  onMenuFiletree =     function(self, menu, tree, event) end,
  onMenuOutline =      function(self, menu, tree, event) end,
  onMenuWatch =        function(self, menu, tree, event) end,
  onProjectPreLoad =   function(self, project) end, -- before project is changed
  onProjectLoad =      function(self, project) end, -- after project is changed
  onProjectClose =     function(self, project) end,
  onInterpreterLoad =  function(self, interpreter) end,
  onInterpreterClose = function(self, interpreter) end,
  onDebuggerPreLoad =  function(self, debugger, options) end, -- return false
  onDebuggerLoad =     function(self, debugger, options) end,
  onDebuggerPreClose = function(self, debugger) end, -- return false
  onDebuggerClose =    function(self, debugger) end,
  onDebuggerPreActivate = function(self, debugger, file, line) end, -- return false
  onDebuggerActivate = function(self, debugger, file, line, editor) end,
  onDebuggerStatusUpdate = function(self, debugger, status) end, -- return false
  onDebuggerCommand =  function(self, debugger, command, server, options) end,
  onIdle =             function(self, event) end,
  onIdleOnce =         function(self, event) end,
  onAppFocusLost =     function(self, app) end,
  onAppFocusSet =      function(self, app) end,
  onAppLoad =          function(self, app) end,
  onAppClose =         function(self, app) end,
  onAppShutdown =      function(self, app) end, -- the last event right before exiting
}

local stringMatch = string.match
local ioOpen = io.open
local stringFind = string.find
local stringSub = string.sub
local stringLen = string.len
local tableInsert = table.insert

--过滤配置
local ingore = {
	files = {
		["middleclass.lua"] = true,
		["Main.lua"] = true,
	},
	folder = {
	},
}

local contentType = {
	enum = 1,
	func = 2,
}

--简单检测CustomLib语法格式
local function CheckLibSyntax(code)
	if not code then return nil end

	local err = nil
	if stringMatch(code, "%.") then
		err = "bad syntax:" .. code
	elseif stringMatch(code, "local") then
		err = "class name cannot include 'local'"
	end 

	return err
end

local function GetContentStringAndType(str)
	--检测枚举还是方法
	local enumString = stringMatch(str, "Enum_%S+ = {")
	local funcString = stringMatch(str, "%a+")

	if enumString then
		return contentType.enum, enumString, nil, nil
	elseif funcString == "function" then
		local decodeString = stringMatch(str, "%a+%.%a+")
		if decodeString then
			local idx = stringFind(decodeString, "%.")
			local className = stringSub(decodeString, 1, idx - 1)
			local funcName = stringSub(decodeString, idx + 1, stringLen(decodeString))
			local argsName = stringMatch(str, "%b()") or "()"
			return contentType.func, className .. "={", funcName, argsName
		end
	end 
	return nil, nil, nil, nil
end

local function SaveContentToCustomLib(srcPathTbl)
	local function WriteFunctionToLib(desFile, funcName, argsStr)
		desFile:write(funcName .. "={type='function',")
		desFile:write("args ='" .. argsStr .. "'},")
		desFile:write('\n')
	end

	local projectDir = ide.config.path.projectdir
	local desFile, err = ioOpen("api/lua/unity.lua", "w")
	if not desFile then
		if err then
			print("Error to load unity.lua error:" .. err)
		end
		return
	end

	desFile:write("return{\n")
	for i = 1, #srcPathTbl, 1 do
		local srcFile = ioOpen(srcPathTbl[i], "r")

		if not srcFile then return end

		local ty = nil
		local starting = false

		for line in srcFile:lines() do
			local str = line

			local t, className, funcName, argsName = GetContentStringAndType(str)

			local isEnd = stringMatch(str, "}")

			if ty == nil then ty = t end
			--判断顺序不改变
			if not isEnd and className ~= nil and not starting then
				--检测语法
				local err = CheckLibSyntax(className)
				if err then
					DisplayOutputLn("错误:", srcPathTbl[i] .. "文件格式存在问题,错误信息如下:" .. err)
				else 
					desFile:write(className .. "\n")
					desFile:write("type='lib',\n")
					desFile:write("childs={\n")

					if ty == contentType.func then
						WriteFunctionToLib(desFile, funcName, argsName)
					end
					starting = true
				end
			elseif ty == contentType.enum and isEnd then
				if starting then
					desFile:write("},\n},\n\n")
				end
				starting = false
				ty = nil
			elseif starting then
				if ty == contentType.enum then
					local idx = stringFind(str, '=')
					if idx ~= nil then
						str = stringSub(str, 1, idx - 1)
						desFile:write(str .. "={type='value'},")
						desFile:write('\n')
					end
				elseif ty == contentType.func then
					if funcName then
						WriteFunctionToLib(desFile, funcName, argsName)
					end
				end
			end
		end

		if ty == contentType.func and starting then
			desFile:write("},\n},\n\n")
			starting = false
			ty = nil
		end
		srcFile:close()
	end

	desFile:write("}")
	desFile:close()  
end

--获取项目文件夹下所有lua文件
local function GetLoadFileList()
	local resultList = {}
	local count = 0

	local function GetLuaFileFromDir(path)
		for file in lfs.dir(path) do
			local isMeta = stringMatch(file, ".meta")
			if not isMeta and file ~= "." and file ~= ".." then
				local isLuaFile = stringMatch(file, "%a+%.lua")
				if isLuaFile then
					local isIngore = ingore.files[file]
					if not isIngore then
						tableInsert(resultList, path .. "/" .. file)
						count = count + 1
					end
				else
					local isIngore = ingore.folder[file]
					local newPath = path .. "/" .. file
					local attr = lfs.attributes(newPath)
					if not isIngore and attr and attr.mode == "directory" then
						GetLuaFileFromDir(newPath)
					end
				end
			end
		end
	end 

	local path = ide.config.path.projectdir
	GetLuaFileFromDir(path)

	return resultList, count
end 

--[[
	跨文件提示
	目前支持:
	1.枚举:格式如下(需要提示Enum_ 开头即可)
	Enum_XXX = {
	}

	2.静态方法
	function class.staticFunc()
]]
CustomApiCreater.onEditorSave = function (self, editor)
	local function CheckLuaSyntax()
		--ActivateOutput()
		CompileProgram(GetEditor(), {
			keepoutput = ide:GetLaunchedProcess() ~= nil or ide:GetDebugger():IsConnected()
		})
	end
	CheckLuaSyntax() --检测语法

	local s = os.clock()
	local loadFileList, fileCount = GetLoadFileList()
	SaveContentToCustomLib(loadFileList)

	ide.apis["lua"]["unity"] = "api/lua/unity.lua"
	ReloadAPIs("lua")

	local e = os.clock()
	DisplayOutputLn("提示:", "lua代码重新读取完毕:文件数量:" .. fileCount .. " 耗时:" .. (e - s))
end

return CustomApiCreater