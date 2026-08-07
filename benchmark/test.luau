local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage.Scripts.Packages
local Broom = require(packages.Broom)
local Signal = require(packages.UsefulSignal)
local Janitor = require(packages.Janitor)
local Trove = require(packages.Trove)
local Maid = require(packages.Maid)

local modules = {
	Broom = {
		object = Broom.new(),
		add = "add",
		cleanup = "cleanup",
		provideMethod = false,
	},
	
	Janitor = {
		object = Janitor.new(),
		add = "Add",
		cleanup = "Cleanup",
	},
	
	Trove = {
		object = Trove.new(),
		add = "Add",
		cleanup = "Clean",		
	},
	
	Maid = {
		object = Maid.new(),
		add = "GiveTask",
		cleanup = "DoCleaning",
	},
}

local function add(name: string, amount: number): number
	local info = modules[name]
	local object = info.object
	local addName = info.add
	local add = object[addName]
	local provideMethod = info.provideMethod ~= false
	local method = provideMethod and "Disconnect" or nil
	local total = 0
	
	for i = 1, amount do
		local signal = Signal.new()
		local conn = signal:Connect(function()

		end)
		local t1 = os.clock()
		add(object, conn, method)
		total += os.clock() - t1
	end
	return total
end

local function cleanup(name: string, amount: number): number
	local info = modules[name]
	local object = info.object
	local addName = info.add
	local add = object[addName]
	local cleanName = info.cleanup
	local cleanup = object[cleanName]
	local provideMethod = info.provideMethod ~= false
	local method = provideMethod and "Disconnect" or nil

	for i = 1, amount do
		local item = {Disconnect = function() end}
		add(object, item, method)
	end
	
	local t1 = os.clock()
	cleanup(object)
	return os.clock() - t1
end


local tests = {
	add = add,
	cleanup = cleanup,
}

local function test(name: string, testName: string, amount: number)
	local conns = {}
	for i = 1, amount do
		local signal = Signal.new()
		local conn = signal:Connect(function()

		end)
		conns[i] = conn
	end
	
	local testFunc = tests[testName]	
	local duration = testFunc(name, amount)
	local txt = string.format("[%s] [%s]: %.4fs", name, testName, duration)
	print(txt)
end

for name, _ in modules do
	task.wait(3)
	test(name, "add", 100000)
end

