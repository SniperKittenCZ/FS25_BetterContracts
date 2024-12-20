--=======================================================================================================
-- BetterContracts SCRIPT
--
-- Purpose:		Enhance ingame contracts menu.
-- Author:		Mmtrx
-- Copyright:	Mmtrx
-- License:		GNU GPL v3.0
-- Changelog:
--  v1.0.0.0    28.10.2024  1st port to FS25
--  v1.0.1.0    10.12.2024  some details
--=======================================================================================================

function loadIcons(self)
	-- maybe later use
	local iconFile = Utils.getFilename("gui/ui_2.dds", self.directory)
	local missionUVs = {
		plow = 		{ 64,  0, 64, 64},
		harvest = 	{128,  0, 64, 64},
		sow = 		{192,  0, 64, 64},
		hay = 		{  0, 64, 64, 64},
		silage = 	{ 64, 64, 64, 64},
		fertilize = {128, 64, 64, 64},
		weed = 		{192, 64, 64, 64},
	}
	self.missionIcons = {}
	local icon 
	for type, uvs in pairs(missionUVs) do 
		icon = Overlay.new(iconFile,0,0, getNormalizedScreenValues(30, 30))
		icon:setUVs(GuiUtils.getUVs(uvs, {256,256}))
		self.missionIcons[type] = icon 
	end
end
function loadGuiFile(self, fname, parent, initial)
	-- load gui from file, attach to parent, call initial func
	if fileExists(fname) then
		xmlFile = loadXMLFile("Temp", fname)
		g_gui:loadGuiRec(xmlFile, "GUI", parent, self.frCon)
		initial(parent)
		delete(xmlFile)
	else
		Logging.error("[GuiLoader %s]  Required file '%s' could not be found!", self.name, fname)
		return false
	end
	return true
end
function fixPosition(element, invLayout)
	--element:applyScreenAlignment()
	element:updateAbsolutePosition()
	if invLayout then 
		element:invalidateLayout(true)
	end
end
function loadGUI(self, guiPath)
	-- load my gui profiles
	local fname = guiPath .. "guiProfiles.xml"
	if fileExists(fname) then
		g_gui:loadProfiles(fname)
	else
		Logging.error("[GuiLoader %s]  Required file '%s' could not be found!", self.name, fname)
		return false
	end
	-- load our sortbox (and mission table) as child of contractsListBox:
	local canLoad = loadGuiFile(self, guiPath.."BCGui.xml", self.frCon.contractsListBox, function(parent)
		self.my.sortbox = parent:getDescendantById("sortbox")
		fixPosition(self.my.sortbox)
		parent:getDescendantById("layout"):invalidateLayout(true) -- adjust sort buttons

		-- position mission table:
		--fixPosition(parent:getDescendantById("container"))
	end)
	-- load filter buttons
  --[[
	if canLoad then 
		canLoad = loadGuiFile(self, guiPath.."filterGui.xml", self.frCon.contractsContainer, function(parent)
			fixPosition(parent:getDescendantById("filterlayout"), true)
			fixPosition(parent:getDescendantById("hidden"))
		end)
	end
	-- load progress bars
	if canLoad then 
		canLoad = loadGuiFile(self, guiPath.."progressGui.xml", self.frCon.contractBox, function(parent)
			for _,id in ipairs({"box1","box2"}) do
				fixPosition(parent:getDescendantById(id), true)
			end
		end)
	end
	if not canLoad then return false end 
	-- load "BCsettingsPage.lua"
	if g_gui ~= nil and g_gui.guis.BCSettingsFrame == nil then
		local luaPath = guiPath .. "BCsettingsPage.lua"
		if fileExists(luaPath) then
			source(luaPath)
		else
			Logging.error("[GuiLoader %s]  Required file '%s' could not be found!", self.name, luaPath)
			return false
		end
	end
	-- load "settingsPage.xml"
	fname = guiPath .. "settingsPage.xml"
	if fileExists(fname) then
		self.settingsPage = BCSettingsPage:new()
		if g_gui:loadGui(fname, "BCSettingsFrame", self.settingsPage, true) == nil then
			Logging.error("[GuiLoader %s]  Error loading SettingsPage", self.name)
			return false
		end
	else
		Logging.error("[GuiLoader %s]  Required file '%s' could not be found!", self.name, fname)
		return false
	end
  ]]
	return canLoad
end
function initGui(self)
	if not loadGUI(self, self.directory .. "gui/") then
		Logging.warning("'%s.Gui' failed to load! Supporting files are missing.", self.name)
	else
		debugPrint("-------- gui loaded -----------")
	end
	-- add new buttons
	self.detailsButtonInfo = {
		inputAction = InputAction.MENU_EXTRA_3,
		text = g_i18n:getText("bc_detailsOn"),
		callback = detailsButtonCallback
	}
	-- register action, so that our button is also activated by keystroke
	local _, eventId = g_inputBinding:registerActionEvent("MENU_EXTRA_3", g_inGameMenu, onClickMenuExtra3, false, true, false, true)
	self.eventExtra3 = eventId

	-- setup new / clear buttons for contracts page:
	local parent = g_inGameMenu.menuButton[1].parent
	local button = g_inGameMenu.menuButton[1]:clone(parent)
	button.onClickCallback = onClickNewContractsCallback
	button:setText(g_i18n:getText("bc_new_contracts"))
	button:setInputAction("MENU_EXTRA_1")
	self.newButton = button 
	
	button = g_inGameMenu.menuButton[1]:clone(parent)
	button.onClickCallback = onClickClearContractsCallback
	button:setText(g_i18n:getText("bc_clear_contracts"))
	button:setInputAction("MENU_EXTRA_2")
	self.clearButton = button 

	Utility.overwrittenFunction(g_inGameMenu,"onClickMenuExtra1",onClickMenuExtra1)
	Utility.overwrittenFunction(g_inGameMenu,"onClickMenuExtra2",onClickMenuExtra2)

	-- inform us on subCategoryChange:
	self.frCon.subCategorySelector.onClickCallback = onChangeSubCategory

 --[[
	self:fixInGameMenuPage(self.settingsPage, "pageBCSettings", "gui/ui_2.dds",
			{0, 0, 64, 64}, {256,256}, nil, function () 
				if g_currentMission.missionDynamicInfo.isMultiplayer then
					return g_currentMission.isMasterUser 
				end
				return true
				end)
	loadIcons(self)
	]]
	------------------- setup my display elements -------------------------------------
 -- enlarge contract details listbox
	self.frCon.farmerBox:applyProfile("BC_contractsFarmerBox")
	self.frCon.farmerImage:applyProfile("BC_contractsFarmerImage")
	--self.frCon.farmerName:applyProfile("BC_contractsFarmerName")

	self.frCon.contractBox:applyProfile("BC_contractsContractBox")
	local desc = self.frCon.contractBox:getDescendants(function(elem)
		return elem.text == g_i18n:getText("ui_contractsInfo"):upper()
		end)
	if desc[1] then  
		desc[1]:applyProfile("BC_contractsContractInfoTitle")
	end
	self.frCon.contractDescriptionText:applyProfile("BC_contractsContractInfo")
 	self.frCon.detailsList:applyProfile("BC_contractsDetailsList")

 -- add field "profit" to all listItems
	local time = self.frCon.contractsList.cellDatabase.autoCell1:getDescendantByName("time")
	local profit = time:clone(self.frCon.contractsList.cellDatabase.autoCell1)
	profit.name = "profit"
	profit:setPosition(-50/2560 *g_aspectScaleX,  80/1440 *g_aspectScaleY) 	-- 
	profit.textBold = false
	profit:applyProfile("BCprofit")
	profit:setVisible(true)

 -- set controls for npcbox, sortbox and their elements:
	--for _, name in pairs(SC.CONTROLS) do
	--	self.my[name] = self.frCon.detailsBox:getDescendantById(name)
	--end
	-- set controls for contractBox:
	for _, name in pairs(SC.CONTBOX) do
		self.my[name] = self.frCon.contractBox:getDescendantById(name)
	end
	-- set callbacks for our 5 sort buttons
	for _, name in ipairs({"sortcat", "sortrev", "sortnpc", "sortprof", "sortpmin"}) do
		self.my[name] = self.frCon.contractsListBox:getDescendantById(name)
		self.my[name].onClickCallback = onClickSortButton
		self.my[name].onHighlightCallback = onHighSortButton
		self.my[name].onHighlightRemoveCallback = onRemoveSortButton
		self.my[name].onFocusCallback = onHighSortButton
		self.my[name].onLeaveCallback = onRemoveSortButton
	end
	self.my.helpsort = self.frCon.contractsListBox:getDescendantById("helpsort")

	-- setupMissionFilter(self)
	-- add field "owner" to InGameMenuMapFrame farmland view:
	-- init other farms mission table
end
function onFrameOpen(self)
	-- appended to InGameMenuContractsFrame:onFrameOpen
	local bc = BetterContracts
	local inGameMenu = bc.gameMenu
	--FocusManager:unsetFocus(self.frCon.contractsList)  -- to allow focus movement

 	local newContracts = self.subCategorySelector.state == 1
	bc.newButton:setVisible(newContracts)
	bc.clearButton:setVisible(newContracts and 
	  self.sectionContracts[1][1]) -- at least 1 section new

	-- if we were sorted on last frame close, focus the corresponding sort button
	if bc.isOn and bc.sort > 0 then
		bc:radioButton(bc.sort)
	end
end
function onFrameClose()
	local bc = BetterContracts
	for _, button in ipairs(
		{	bc.newButton,
			bc.clearButton
		}) do
		button:setVisible(false)
	end
end
function onChangeSubCategory(self,element)
	-- overwritten to InGameMenuContractsFrame:onChangeSubCategory()
	-- switch visibility of our menu buttons
	local bc = BetterContracts
 	local newContracts = self.subCategorySelector.state == 1
 	debugPrint("** onChangeSubCategory, newContracts %s", newContracts)
	bc.newButton:setVisible(newContracts)
	bc.clearButton:setVisible(newContracts and 
	  self.sectionContracts[1][1]) -- at least 1 section in new contracts

	g_inGameMenu.pageContracts:onChangeSubCategory(element)
end
function setButtonsForState(self,state)
	-- appended to InGameMenuContractsFrame:setButtonsForState(state)
	local bc = BetterContracts
	local text = g_i18n:getText("bc_detailsOn")
	if bc.isOn then
		text = g_i18n:getText("bc_detailsOff")
	end
	bc.detailsButtonInfo.text = text 
	table.insert(self.menuButtonInfo, bc.detailsButtonInfo)
end

function onClickMenuExtra1(inGameMenu, superFunc, ...)
	local bc = BetterContracts
	if superFunc ~= nil then
		superFunc(inGameMenu, ...)
	end
	if bc.newButton ~= nil then
		bc.newButton.onClickCallback(inGameMenu)
	end
end
function onClickMenuExtra2(inGameMenu, superFunc, ...)
	local bc = BetterContracts
	if superFunc ~= nil then
		superFunc(inGameMenu, ...)
	end
	if bc.clearButton ~= nil then
		bc.clearButton.onClickCallback(inGameMenu)
	end
end
function onClickMenuExtra3(inGameMenu)
	-- do we stil need this?
end
function onClickNewContractsCallback(inGameMenu)
	BetterContractsNewEvent.sendEvent()
end
function onClickClearContractsCallback(inGameMenu)
	BetterContractsClearEvent.sendEvent()
end
function detailsButtonCallback(inGameMenu, detailsButton)
	local self = BetterContracts
	local frCon = self.frCon

	-- it's a toggle button - change my "on" state
	self.isOn = not self.isOn
	--self.my.npcbox:setVisible(self.isOn)
	self.my.sortbox:setVisible(self.isOn)

	if inGameMenu == nil then  -- were called from input action (key D)
		detailsButton = nil 
		-- find our details button:
		for _, button in ipairs(g_inGameMenu.menuButton) do
			if button.text:sub(1,2) == "BC" then 
				detailsButton = button 
				break
			end
		end
		if detailsButton == nil then  
			Logging.error("[%s] did not find detailsButton", self.name)
			return
		end
	end

	if self.isOn then
		detailsButton:setText(g_i18n:getText("bc_detailsOff"))
		
		-- if we were sorted on last "off" click, then one of our sort buttons might still have focus
		if self.lastSort > 0 then
			FocusManager:setFocus(frCon.contractsList, "top") -- remove focus from our sort buttton
		end
	else
		detailsButton:setText(g_i18n:getText("bc_detailsOn"))
		-- "off" always resets sorting to default
		if self.sort > 0 then
			self:radioButton(0) -- reset all sort buttons
		end
		self.my.helpsort:setText("")
	end
	frCon:updateList() -- restore standard sort order
	-- refresh detailsBox
	local s, i = frCon.contractsList:getSelectedPath()
	frCon:updateDetailContents(s, i)
end
function formatReward(x)
	-- return g_i18n:formatMoney(), but special handling for big values >100k
	if x < 100000.6 then return g_i18n:formatMoney(x,0,true,true)
	end
	local xk = MathUtil.round(x/1000)
	return g_i18n:formatMoney(xk,0,true,true) .."k"
end
function populateCell(self, list, sect, index, cell)
	-- appended to InGameMenuContractsFrame:populateCellForItemInSection()
	if list == self.detailsList then 
		--local m = self.currentContract.mission
		--local miss = self.currentContract.mission
	return end  -- details List finished

	local profit = cell:getAttribute("profit")
	local bc = BetterContracts
	if not bc.isOn then
		profit:setVisible(false)
		return
	end
	local listType = self.subCategorySelector:getState()
	local m = self.sectionContracts[listType][sect].contracts[index].mission
	if m == nil then 
		Logging.warning("* BetterContracts: could not find mission for contract")
		return
	end	
	local profValue = m.info.profit or 0
	local rewValue = m:getReward()
	cell:getAttribute("reward"):setText(formatReward(rewValue)) 	-- formats values > 1k

	if m.type.name == "harvestMission" then 
		-- update total profit
		_,_, profValue = bc:calcProfit(m, HarvestMission.SUCCESS_FACTOR)
		
		--[[ overwrite "contract" with fruittype to harvest
		local fruit = cell:getAttribute("contract")
		local txt = string.format(g_i18n:getText("bc_harvest"), cont.ftype)
		if m.type.name == "chaffMission" then 
			txt = string.format(g_i18n:getText("bc_chaff"), bc.ft[m.orgFillType].title)
		fruit:setText(txt)
		end
		]]
	end
	if profValue ~= 0 then
		profit:setText(formatReward(rewValue + profValue))
	end
	profit:setVisible(profValue ~= 0)

	-- indicate leased equipment for active missions
	if cont and cont.miss.status == AbstractMission.STATUS_RUNNING then
		local indicator = cell:getAttribute("indicatorActive")
		local txt = ""
		if cont.miss.spawnedVehicles then
			txt = g_i18n:getText("bc_leased")
		end
		indicator:setText(g_i18n:getText("fieldJob_active")..txt)
		indicator:setVisible(true)
	end
end
function sortList(self, superfunc)
	--[[ sort self.contracts according to sort button clicked:
		1 "sortcat",  mission category / field (defaut)
		2 "sortrev",  Revenue / contract value
		3 "sortnpc",  NPC farmer offering mission
		4 "sortprof", net profit
		5 "sortpmin", net profit per minute
	]]
	local bc = BetterContracts
	if not bc.isOn or bc.sort < 2 then
		superfunc(self)
		return
	end
	local sorts = function(a, b)
		local av, bv = 1000000.0 * (a.active and 1 or 0) + 500000.0 * (a.finished and 1 or 0), 1000000.0 * (b.active and 1 or 0) + 500000.0 * (b.finished and 1 or 0)
		local am, bm = a.mission, b.mission
		local ar, br = am:getReward(), bm:getReward()

		if bc.sort == 5 then -- sort profit per Minute
			-- if permin == 0 for both am, bm, then sort on reward
			local aperMin = am.info.perMin or 0
			local bperMin = bm.info.perMin or 0
			av = av +  50.0 * aperMin + 0.0001 * ar
			bv = bv +  50.0 * bperMin + 0.0001 * br

		elseif bc.sort == 4 then -- sort profit
			av = av + (am.info.profit or 0) + ar
			bv = bv + (bm.info.profit or 0) + br

		elseif bc.sort == 3 then -- sort NPC
			local anpc, bnpc = am:getNPC().title, bm:getNPC().title 
			local afield = am.field ~= nil and am.field:getName() or 0
			local bfield = bm.field ~= nil and bm.field:getName() or 0
			local z = anpc < bnpc and 1000 or -1000

			if anpc == bnpc then z = 0 end
			av = av + z - afield
			bv = bv - z - bfield

		elseif bc.sort == 2 then -- sort revenue
			av = av + ar
			bv = bv + br

		else -- should not happen
			av, bv = am.generationTime, bm.generationTime
		end
		return av > bv
	end
	table.sort(self.contracts, sorts)

	-- distribute contracts to sections
	self.sectionContracts = {}
	self.sectionContracts[1] = {
		{	title = g_i18n:getText("SC_sortpMin"):upper(),  -- assume bc.sort == 5
			contracts = {}
		}
	}
	self.sectionContracts[2] = {
		{	title = g_i18n:getText("SC_sortpMin"):upper(),  
			contracts = {}
		}
	}
	if bc.sort == 3 then 		-- npc sort, only type that needs multiple sections
		self.sectionContracts = { {},{} }
	elseif bc.sort == 4 then 
		self.sectionContracts[1][1].title = g_i18n:getText("SC_sortProf"):upper()
		self.sectionContracts[2][1].title = g_i18n:getText("SC_sortProf"):upper()
	elseif bc.sort == 2 then
		self.sectionContracts[1][1].title = g_i18n:getText("SC_sortRev"):upper()
		self.sectionContracts[2][1].title = g_i18n:getText("SC_sortRev"):upper()
	end
	local lastNpc = {}  -- [1]: current npc in NEW-list, [2]: same for ACTIVE-list
	local npc 

	for _, contract in ipairs(self.contracts) do
		local status = InGameMenuContractsFrame.CONTRACT_STATE.NEW
		if contract.active or contract.finished then
			status = InGameMenuContractsFrame.CONTRACT_STATE.ACTIVE
		end
		if bc.sort ~= 3 then 
			table.insert(self.sectionContracts[status][1].contracts, contract)
		else 
			-- if new npc, make a section, else insert contract in current sect
			npc = contract.mission:getNPC()
			if lastNpc[status] ~= npc then
				table.insert(self.sectionContracts[status], {
					title = npc.title,
					contracts = {}
				})
				lastNpc[status] = npc
			end
			table.insert(self.sectionContracts[status][#self.sectionContracts[status]].contracts, contract)
		end
	end
	local numNew = #self.sectionContracts[1]
	local numActive = #self.sectionContracts[2]

	if numNew > 0 and #self.sectionContracts[1][1].contracts==0 then  
	-- remove section title if no contracts
		self.sectionContracts[1] = {}
		numNew = 0 
	end
	if numNew == 0 then
		if #self.sectionContracts[2] > 0 then
			self.subCategorySelector:setState(2)
		end
	end
end
function updateButtonsPanel(menu, page)
	-- called by TabbedMenu.onPageChange(), after page:onFrameOpen()
	local inGameMenu = BetterContracts.gameMenu
	if page.id ~= "pageContracts" or inGameMenu.newButton == nil 
		or not g_currentMission.missionDynamicInfo.isMultiplayer then
		return end 
	-- disable buttons according to setting refreshMP
	local refresh = BetterContracts.config.refreshMP
	local enable = g_currentMission.isMasterUser or refresh == SC.PLAYER  
		or refresh == SC.FARMMANAGER and g_currentMission:getHasPlayerPermission("farmManager")  

	inGameMenu.newButton:setDisabled(not enable)
	inGameMenu.clearButton:setDisabled(not enable)
end
function BetterContracts:radioButton(st)
	-- implement radiobutton behaviour: max. one sort button can be active
	self.sort = st
	local prof = {
		active = {"BCactiveCat", "BCactiveRev", "BCactiveNpc", "BCactiveProf", "BCactivepMin"},
		std = {"BCsortCat", "BCsortRev", "BCsortNpc", "BCsortProf", "BCsortpMin"}
	}
	local bname
	if st == 0 then -- called from buttonCallback() when switching to off
		if self.lastSort > 0 then -- reset the active sort icon
			local a = self.lastSort
			bname = self.buttons[a][1]
			self.my[bname]:applyProfile(prof.std[a])
			FocusManager:unsetFocus(self.my[bname]) -- remove focus if we are sorted
			FocusManager:unsetHighlight(self.my[bname]) -- remove highlight
		end
		return
	end
	self.my[self.buttons[st][1]]:applyProfile(prof.active[st]) -- set this Button Active

	local last = self.lastSort
	if last > 0 then 
		self.my[self.buttons[last][1]]:applyProfile(prof.std[last]) -- reset the last active button
	end
	self.lastSort = self.sort
end
function onClickSortButton(frCon, button)
	local self, n = BetterContracts, 0
	for i, bu in ipairs(self.buttons) do
		if bu[1] == button.id then
			n = i
			break
		end
	end
	self:radioButton(n)
	frCon:updateList()
end
function onHighSortButton(frCon, button)
	-- show help text
	local self = BetterContracts
	--print(button.id.." -onHighlight / onFocusEnter, sort "..tostring(self.sort))
	local tx = ""
	for _, bu in ipairs(self.buttons) do
		if bu[1] == button.id then
			tx = bu[2]
			break
		end
	end
	self.my.helpsort:setText(tx)
end
function onRemoveSortButton(frCon, button)
	-- reset help text
	local self = BetterContracts
	--print(button.id.." -onHighlightRemove / onFocusLeave, sort "..tostring(self.sort))
	if self.sort == 0 then
		self.my.helpsort:setText("")
	else
		self.my.helpsort:setText(self.buttons[self.sort][2])
	end
end
