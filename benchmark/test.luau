local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage.Scripts.Packages
local Broom = require(packages.Broom)
local Signal = require(packages.UsefulSignal)
local Janitor = require(packages.Janitor)
local Trove = require(packages.Trove)
local Maid = require(packages.Maid)
local Scythe = require(packages.Scythe)
local ScytheScope = Scythe.scope()

local modules = {
	Broom = {
		object = Broom,
		add = "add",
		cleanup = "cleanup",
		provideMethod = false,
	},
	
	Janitor = {
		object = Janitor,
		add = "Add",
		cleanup = "Cleanup",
	},
	
	Trove = {
		object = Trove,
		add = "Add",
		cleanup = "Clean",		
	},
	
	Maid = {
		object = Maid,
		add = "GiveTask",
		cleanup = "DoCleaning",
	},
	
	Scythe = {
		addMethod = function(_, object)
			Scythe.add(ScytheScope, object)
		end,
		
		cleanupMethod = function(_, object)
			Scythe.clean(ScytheScope)
		end,
	},
	
}

local function add(name: string, amount: number): number
	local info = modules[name]
	local object = info.object
	if object then
		object = object.new()
	end
	local addName = info.add
	local add
	if info.addMethod then
		add = info.addMethod
		
	else
		add = object[addName]
	end

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
	if object then
		object = object.new()
	end
	local addName = info.add
	
	local add
	if info.addMethod then
		add = info.addMethod

	else
		add = object[addName]
	end
	
	local cleanName = info.cleanup
	local cleanup
	if info.cleanupMethod then
		cleanup = info.cleanupMethod
	else
		cleanup = object[cleanName]
	end

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
	local testFunc = tests[testName]	
	local duration = testFunc(name, amount)
	local txt = string.format("[%s] [%s]: %.4fs", name, testName, duration)
	print(txt)
	return duration
end

local function bench(count: number)
	local addTimes = {}
	local cleanupTimes = {}
	
	print("====Add Test====")
	for name, _ in modules do
		task.wait(3)
		local duration = test(name, "add", count)
		addTimes[name] = duration
	end
	
	print("\n====Cleanup Test====")
	task.wait(2)
	
	for name, _ in modules do
		task.wait(3)
		local duration = test(name, "cleanup", count)
		cleanupTimes[name] = duration
	end
	
	print("\n====Total Time====")
	for name, _ in modules do
		local total = addTimes[name] + cleanupTimes[name]
		local txt = string.format("[%s] [%s]: %.4fs", name, "Total time", total)
		print(txt)
	end
end

task.wait(2)
bench(100000)

