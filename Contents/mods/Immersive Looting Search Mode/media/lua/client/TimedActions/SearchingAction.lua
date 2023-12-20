require "TimedActions/ISBaseTimedAction"

SearchingAction = ISBaseTimedAction:derive("SearchingAction")

function SearchingAction:isValid()
	return true
end

function SearchingAction:waitToStart()	
	if self.character:getVehicle() then return false end
	self.character:faceThisObject(self.container:getParent())
	return self.character:shouldBeTurning()
end

function SearchingAction:update()
	self.character:faceThisObject(self.container:getParent())
	if not self.sound then
		self.sound = self.character:getEmitter():playSound("PutItemInBag2")
	end
end

function SearchingAction:start()
    self.sound = self.character:getEmitter():playSound("PutItemInBag2")
	local cont = self.container

	self:setActionAnim("Loot")
	self:setAnimVariable("LootPosition", "")
	self:setOverrideHandModels(nil, nil)
	self.character:clearVariable("LootPosition")
	if cont:getContainerPosition() then
		self:setAnimVariable("LootPosition", cont:getContainerPosition())
	end
	if cont:getType() == "freezer" and cont:getFreezerPosition() then
		self:setAnimVariable("LootPosition", cont:getFreezerPosition())
	end
	if instanceof(cont:getParent(), "IsoDeadBody") or cont:getType() == "floor" then
		self:setAnimVariable("LootPosition", "Low")
	end
	if cont:getContainingItem() and cont:getContainingItem():getWorldItem() then
		self:setAnimVariable("LootPosition", "Low")
	end
	self.character:playSound("PutItemInBag")
end

function SearchingAction:stop()	
	if self.sound then
		self.character:getEmitter():stopSound(self.sound)
		self.sound = nil
	end
    ISBaseTimedAction.stop(self)
end

function SearchingAction:perform()
	if self.sound then
		self.character:getEmitter():stopSound(self.sound)
		self.sound = nil
	end
	self.action:stopTimedActionAnim()
	self.action:setLoopedAction(false)
	self.fn(self.container)
	local pdata = getPlayerData(self.character:getPlayerNum())
	pdata.lootInventory:refreshBackpacks()
	pdata.playerInventory:refreshBackpacks()
	ISBaseTimedAction.perform(self)
end

function SearchingAction:new(page, playerObj, fn)
	local minTime = 100
	local time = page.inventory:getMaxWeight() + (page.inventory:getCapacityWeight() * 2)
    if playerObj:HasTrait("Dextrous") then
		time = time * 0.5
	end
	if playerObj:HasTrait("AllThumbs") then
		time = time * 1.5
	end
	time = time*2.5
    local o = {}
	setmetatable(o, self)
	self.__index = self
	o.page = page
	o.character =  playerObj
	o.container = page.inventory
	o.stopOnWalk = true
	o.stopOnRun = true
	if time < minTime then time = minTime end
	o.maxTime = time * SandboxVars.SearchingMod.SearchActionTimeMult
	o.fn = fn
	return o
end