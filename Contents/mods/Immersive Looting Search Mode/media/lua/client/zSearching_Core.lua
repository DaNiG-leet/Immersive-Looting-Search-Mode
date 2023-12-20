-- Coded by DaNiG

local player

-- Main table of searched containers.
local hasBeenSearched = {}

---Checks to see if the container's been searched.
---@param ItemContainer ItemContainer
---@return boolean
local isSearched = function(ItemContainer)
    if not player then return true end
    if instanceof(ItemContainer:getParent(), 'IsoPlayer') then return true end
    if ItemContainer:getType() == 'floor' or ItemContainer:getType():contains("Seat") then return true end
    if isClient() and ItemContainer:getParent() and not (instanceof(ItemContainer:getParent(), 'BaseVehicle') or instanceof(ItemContainer:getParent(), 'IsoDeadBody')) and SafeHouse.getSafeHouse(ItemContainer:getParent():getSquare()) and SafeHouse.getSafeHouse(ItemContainer:getParent():getSquare()):playerAllowed(player) then
        return true 
    end
    return hasBeenSearched[tostring(ItemContainer)]
end

--- Enters the ItemContainer into the table.
---@param ItemContainer ItemContainer
local setSearched = function(ItemContainer)
    hasBeenSearched[tostring(ItemContainer)] = true
    triggerEvent("OnContainerSearched", player, ItemContainer)
end

--- Let's start the search.
---@param page ISInventoryPage
local startSearching = function(page)
    ISTimedActionQueue.add(SearchingAction:new(page, player, setSearched))
end

------------------------------------------------------- INJECTIONS

-- Injection to create a button.
local ISInventoryPage_createChildren = ISInventoryPage.createChildren
function ISInventoryPage:createChildren()
    self.searchBtn = ISButton:new(self.height / 2, 0, 50, 16, getText('UI_action_start_search'), self, startSearching)
    self.searchBtn:initialise()
    self.searchBtn.borderColor.a = 0.0
    self.searchBtn.backgroundColor.a = 0.0
    self.searchBtn.backgroundColorMouseOver.a = 0.7
    self:addChild(self.searchBtn)
    self.searchBtn:setVisible(true)
    ISInventoryPage_createChildren(self)
end

-- Injection to display the button at the right moment and move it.
local ISInventoryPage_prerender = ISInventoryPage.prerender
function ISInventoryPage:prerender()
    if self.searchBtn:getIsVisible() ~= not isSearched(self.inventory) then self.searchBtn:setVisible(not isSearched(self.inventory)) end

    --Compatible with a list of specific mods that add a button for the interface. Thanks to Arendameth for the code. I hope you're not too upset that I took it.
    if self.searchBtn:getIsVisible() and not self.onCharacter then
        local visibleButtons = {}

        -- Turn on button for stove
        if self.toggleStove:getIsVisible() then
            table.insert(visibleButtons, self.toggleStove)
        end

        -- Remove all button for trash bins
        if self.removeAll:getIsVisible() then
            table.insert(visibleButtons, self.removeAll)
        end

        -- NFQualityOfLife mod
        if self.dropAllBtn and self.dropAllBtn:getIsVisible() then
            table.insert(visibleButtons, self.dropAllBtn)
        end

        if self.washBtn and self.washBtn:getIsVisible() then
            table.insert(visibleButtons, self.washBtn)
        end

        -- Auto Loot Mod
        if self.stackItemsButtonIcon and self.stackItemsButtonIcon:getIsVisible() then
            table.insert(visibleButtons, self.stackItemsButtonIcon)
        end

        -- Easy Drop'n'Loot mod
        if self.KAlootAllCompulsively and self.KAlootAllCompulsively:getIsVisible() then
            table.insert(visibleButtons, self.KAlootAllCompulsively)
        end

        -- Elgin's Street Sweeper mod
        if self.autoRemoveBtn and self.autoRemoveBtn:getIsVisible() then
            table.insert(visibleButtons, self.autoRemoveBtn)
        end

        -- Search Containers mod
        if self.searchButton and self.searchButton:getIsVisible() then
            table.insert(visibleButtons, self.searchButton)
        end

        local x = self.lootAll:getRight() + 16
        for _, button in ipairs(visibleButtons) do
            local right = button:getRight()
            if right > x then
                x = right + 16
            end
        end
        self.searchBtn:setX(x)

    elseif self.searchBtn:getIsVisible() and self.onCharacter then
        if self.swapAutoLoot and self.swapAutoLoot:getIsVisible() then
            self.searchBtn:setX(self.swapAutoLoot:getX() - self.searchBtn:getWidth()) -- AutoLoot compatibility
        elseif self.transferAll and self.transferAll:getIsVisible() then
            self.searchBtn:setX(self.transferAll:getX() - self.searchBtn:getWidth() - 16) 
        end
    end
    
    if not isSearched(self.inventoryPane.inventory) and not isAdmin() then
        -- Thank you Star for this code
        -- Injection so as not to output the amount of weight in the container.
        local obj = self
        local old_round = _G.round
        _G.round = function(num, idp)
            if num == obj.totalWeight then return '?' end
            return old_round(num, idp)
        end
        ISInventoryPage_prerender(self)
        _G.round = old_round
    else
        ISInventoryPage_prerender(self)
    end
end

-- Injection to prevent items from being obtained from an unsearched container.
local ISInventoryPage_lootAll = ISInventoryPage.lootAll
function ISInventoryPage:lootAll()
    if not SandboxVars.SearchingMod.ToggleLootTransferAll then
        ISInventoryPage_lootAll(self)
    elseif isSearched(self.inventory) then
        ISInventoryPage_lootAll(self)
    end
end

-- Injection to prevent items from being obtained from an unsearched container.
local ISInventoryPage_transferAll = ISInventoryPage.transferAll
function ISInventoryPage:transferAll()
    if not SandboxVars.SearchingMod.ToggleLootTransferAll then
        ISInventoryPage_transferAll(self)
    elseif isSearched(self.inventory) then
        ISInventoryPage_transferAll(self)
    end
end

-- Injection to avoid rendering items in an unrendered container.
local ISInventoryPane_rendericons = ISInventoryPane.rendericons
function ISInventoryPane:rendericons()
    if isAdmin() then
        ISInventoryPane_rendericons(self)
        return
    end
    if isSearched(self.inventory) then
        ISInventoryPane_rendericons(self)
    elseif #self.items > 0 then
        self.items = {}
    end
end

-- Injection to avoid rendering items in an unrendered container.
local ISInventoryPane_renderdetails = ISInventoryPane.renderdetails
function ISInventoryPane:renderdetails(...)
    if isAdmin() then
        ISInventoryPane_renderdetails(self, ...)
        return
    end
    if isSearched(self.inventory) then
        ISInventoryPane_renderdetails(self, ...)
    elseif #self.items > 0 then
        self.items = {}
    end
end

-- Injection to prevent you from getting information about items in the container via a tooltip.
-- Hopefully I can find another way to prevent items in bags from being previewed.
local old_render = ISToolTipInv.render
function ISToolTipInv:render()
    if not SandboxVars.SearchingMod.ToggleRander then old_render(self) end
    if not instanceof(self.item, 'InventoryContainer') then
        old_render(self)
    elseif instanceof(self.item, 'InventoryContainer') and hasBeenSearched[tostring(self.item)] then
        old_render(self)
    end
end

-- Injection to prevent getting items from unsearchable containers for the context menu.
local ISInventoryPaneContextMenu_getContainers = ISInventoryPaneContextMenu.getContainers
ISInventoryPaneContextMenu.getContainers = function(...)
    if isAdmin() then return ISInventoryPaneContextMenu_getContainers(...) end
    local containers = ISInventoryPaneContextMenu_getContainers(...)
    local array = ArrayList.new()
    for i = 0, containers:size() - 1 do
        local itemContainer = containers:get(i)
        if isSearched(itemContainer) then array:add(itemContainer) end
    end
    return array
end

-- Injection to prevent items from being obtained from unsearchable containers for use in crafting.
local ISCraftingUI_getContainers = ISCraftingUI.getContainers
function ISCraftingUI:getContainers()
    ISCraftingUI_getContainers(self)
    if isAdmin() then return end
    local array = ArrayList.new()
    for i = 0, self.containerList:size() - 1 do
        local itemContainer = self.containerList:get(i)
        if isSearched(itemContainer) then array:add(itemContainer) end
    end
    self.containerList = array
end

------------------------------------------------------- EVENTS

local function OnRefreshInventoryWindowContainers(inventoryPage, type)
    if type == 'buttonsAdded' then
        for _, v in pairs(inventoryPage.backpacks) do
            if v.inventory and not isSearched(v.inventory) and not v.textureOverride then
                v.textureOverride = getTexture("media/ui/questionMark.png")
                v:setTextureRGBA(0.1, 0.1, 0.1, 1.0)
                v:setBackgroundRGBA(0.5, 0.5, 0.5, 1.0)
            end
        end
    end
end

Events.OnRefreshInventoryWindowContainers.Add(OnRefreshInventoryWindowContainers)

local function OnCreatePlayer(index, IsoPlayer)
    player = IsoPlayer
end

Events.OnCreatePlayer.Add(OnCreatePlayer)

------------------------------------------------------- MCM INTEGRATION

-- I couldn't think of anything better than doing an integration with Mod Config Menu. It is extremely good though.
if Mod.IsMCMInstalled_v1 then
    local option = ModOptionTable:New("ImmersiveLooting", "Immersive Looting: Search Mode", false)
    option:AddModOption("StartSearchBtn", "keybind", 34, nil, getText('UI_start_search_option_name'), getText('UI_start_search_tooltip'), function()
        if not player then return end
		local lootInventoryPage = getPlayerLoot(player:getPlayerNum())
        if not isSearched(lootInventoryPage.inventory) then
            startSearching(lootInventoryPage)
        end
	end)
end

------------------------------------------------------- COMPATIBILITY

-- Autoloot
if AutoDrop and AutoDrop.LootContainer then
    local AutoDrop_LootContainer = AutoDrop.LootContainer
    function AutoDrop.LootContainer(itemContainer, ...)
        print('AUTOHOOET BLEAT')
        if not isSearched(itemContainer) then return false end
        return AutoDrop_LootContainer(itemContainer, ...)
    end
end