--=======================================================================================================
-- BetterContracts SCRIPT
--
-- Purpose:     Enhance ingame contracts menu.
-- Author:      Mmtrx
-- Copyright:	Mmtrx
-- License:		GNU GPL v3.0
-- Changelog:
--  v1.0.0.0    28.10.2024  1st port to FS25
--  v1.0.1.0    10.12.2024  some details, sort list
--  v1.0.1.1    20.12.2024  fix details button, enlarge contract details list
--=======================================================================================================
SC = {
	FERTILIZER = 1, -- prices index
	LIQUIDFERT = 2,
	HERBICIDE = 3,
	SEEDS = 4,
	LIME = 5,
	-- my mission cats:
	HARVEST = 1,
	SPREAD = 2,
	SIMPLE = 3,
	BALING = 4,
	TRANSP = 5,
	SUPPLY = 6,
	OTHER = 7,
	-- refresh MP:
	ADMIN = 1,
	FARMMANAGER = 2,
	PLAYER = 3,
	-- hardMode expire:
	OFF = 0,
	DAY = 1,
	MONTH = 2,
	-- Gui farmerBox controls:
	CONTROLS = {
		npcbox = "npcbox",
		sortbox = "sortbox",
		layout = "layout",
		filltype = "filltype",
		widhei = "widhei",
		ppmin = "ppmin",
		line3 = "line3",
		line4a = "line4a",
		line4b = "line4b",
		line5 = "line5",
		line6 = "line6",
		field = "field",
		dimen = "dimen",
		etime = "etime",
		valu4a = "valu4a",
		valu4b = "valu4b",
		price = "price",
		valu6 = "valu6",
		valu7 = "valu7",
		sort = "sort",
		sortcat = "sortcat", "sortrev", "sortnpc",
		sortprof = "sortprof",
		sortpmin = "sortpmin",
		helpsort = "helpsort",
		container = "container",
		mTable = "mTable",
		mToggle = "mToggle",
	},
	-- Gui contractBox controls:
	CONTBOX = {
		"detailsList", "rewardText", "prog1", "prog2",
		"progressBarBg", "progressBar1", "progressBar2"
	}
}
function debugPrint(text, ...)
	if BetterContracts.config and BetterContracts.config.debug then
		Logging.info(text,...)
	end
end
source(Utils.getFilename("RoyalMod.lua", g_currentModDirectory.."scripts/")) 	-- RoyalMod support functions
source(Utils.getFilename("Utility.lua", g_currentModDirectory.."scripts/")) 	-- RoyalMod utility functions
---@class BetterContracts : RoyalMod
BetterContracts = RoyalMod.new(true, true)     --params bool debug, bool sync

function checkOtherMods(self)
	local mods = {	
		FS22_RefreshContracts = "needsRefreshContractsConflictsPrevention",
		FS22_Contracts_Plus = "preventContractsPlus",
		FS22_SupplyTransportContracts = "supplyTransport",
		FS22_DynamicMissionVehicles = "dynamicVehicles",
		FS22_TransportMissions = "transportMission",
		FS22_LimeMission = "limeMission",
		FS22_MaizePlus = "maizePlus",
		FS22_KommunalServices = "kommunal",
		}
	for mod, switch in pairs(mods) do
		if g_modIsLoaded[mod] then
			self[switch] = true
		end
	end
end
function registerXML(self)
	self.baseXmlKey = "BetterContracts"
	self.xmlSchema = XMLSchema.new(self.baseXmlKey)
	self.xmlSchema:register(XMLValueType.BOOL, self.baseXmlKey.."#debug")
	self.xmlSchema:register(XMLValueType.BOOL, self.baseXmlKey.."#ferment")
	self.xmlSchema:register(XMLValueType.BOOL, self.baseXmlKey.."#forcePlow")
	self.xmlSchema:register(XMLValueType.BOOL, self.baseXmlKey.."#lazyNPC")
	self.xmlSchema:register(XMLValueType.BOOL, self.baseXmlKey.."#discount")
	self.xmlSchema:register(XMLValueType.BOOL, self.baseXmlKey.."#hard")

	self.xmlSchema:register(XMLValueType.INT, self.baseXmlKey.."#maxActive")
	self.xmlSchema:register(XMLValueType.INT, self.baseXmlKey.."#refreshMP")
	self.xmlSchema:register(XMLValueType.FLOAT, self.baseXmlKey.."#reward")
	self.xmlSchema:register(XMLValueType.FLOAT, self.baseXmlKey.."#rewardMow")
	self.xmlSchema:register(XMLValueType.FLOAT, self.baseXmlKey.."#lease")
	self.xmlSchema:register(XMLValueType.FLOAT, self.baseXmlKey.."#deliver")
	self.xmlSchema:register(XMLValueType.FLOAT, self.baseXmlKey.."#deliverBale")
	self.xmlSchema:register(XMLValueType.FLOAT, self.baseXmlKey.."#fieldCompletion")

	local key = self.baseXmlKey..".lazyNPC"
	self.xmlSchema:register(XMLValueType.BOOL, key.."#harvest")
	self.xmlSchema:register(XMLValueType.BOOL, key.."#plowCultivate")
	self.xmlSchema:register(XMLValueType.BOOL, key.."#sow")
	self.xmlSchema:register(XMLValueType.BOOL, key.."#weed")
	self.xmlSchema:register(XMLValueType.BOOL, key.."#fertilize")

	local key = self.baseXmlKey..".discount"
	self.xmlSchema:register(XMLValueType.FLOAT, key.."#perJob")
	self.xmlSchema:register(XMLValueType.INT,   key.."#maxJobs")

	local key = self.baseXmlKey..".hard"
	self.xmlSchema:register(XMLValueType.FLOAT, key.."#penalty")
	self.xmlSchema:register(XMLValueType.INT,   key.."#leaseJobs")
	self.xmlSchema:register(XMLValueType.INT,   key.."#expire")
	self.xmlSchema:register(XMLValueType.INT,   key.."#hardLimit")

	local key = self.baseXmlKey..".generation"
	self.xmlSchema:register(XMLValueType.INT, 	key.."#interval")
	self.xmlSchema:register(XMLValueType.FLOAT, key.."#percentage")
end
function readconfig(self)
	if g_currentMission.missionInfo.savegameDirectory == nil then return end
	-- check for config file in current savegame dir
	self.savegameDir = g_currentMission.missionInfo.savegameDirectory .."/"
	self.configFile = self.savegameDir .. self.name..'.xml'
	local xmlFile = XMLFile.loadIfExists("BCconf", self.configFile, self.xmlSchema)
	if xmlFile then
		-- read config parms:
		local key = self.baseXmlKey

		self.config.debug =		xmlFile:getValue(key.."#debug", false)			
		self.config.ferment =	xmlFile:getValue(key.."#ferment", false)			
		self.config.forcePlow =	xmlFile:getValue(key.."#forcePlow", false)			
		self.config.maxActive = xmlFile:getValue(key.."#maxActive", 3)
		self.config.multReward = xmlFile:getValue(key.."#reward", 1.)
		self.config.multRewardMow = xmlFile:getValue(key.."#rewardMow", 1.)
		self.config.multLease = xmlFile:getValue(key.."#lease", 1.)
		self.config.toDeliver = xmlFile:getValue(key.."#deliver", 0.94)
		self.config.toDeliverBale = xmlFile:getValue(key.."#deliverBale", 0.90)
		self.config.fieldCompletion = xmlFile:getValue(key.."#fieldCompletion", 0.95)
		self.config.refreshMP =	xmlFile:getValue(key.."#refreshMP", 2)		
		self.config.lazyNPC = 	xmlFile:getValue(key.."#lazyNPC", false)
		self.config.hardMode = 	xmlFile:getValue(key.."#hard", false)
		self.config.discountMode = xmlFile:getValue(key.."#discount", false)
		if self.config.lazyNPC then
			key = self.baseXmlKey..".lazyNPC"
			self.config.npcHarvest = 	xmlFile:getValue(key.."#harvest", false)			
			self.config.npcPlowCultivate =xmlFile:getValue(key.."#plowCultivate", false)		
			self.config.npcSow = 		xmlFile:getValue(key.."#sow", false)		
			self.config.npcFertilize = 	xmlFile:getValue(key.."#fertilize", false)
			self.config.npcWeed = 		xmlFile:getValue(key.."#weed", false)
		end
		if self.config.discountMode then
			key = self.baseXmlKey..".discount"
			self.config.discPerJob = MathUtil.round(xmlFile:getValue(key.."#perJob", 0.05),2)			
			self.config.discMaxJobs =	xmlFile:getValue(key.."#maxJobs", 5)		
		end
		if self.config.hardMode then
			key = self.baseXmlKey..".hard"
			self.config.hardPenalty = MathUtil.round(xmlFile:getValue(key.."#penalty", 0.1),2)			
			self.config.hardLease =		xmlFile:getValue(key.."#leaseJobs", 2)		
			self.config.hardExpire =	xmlFile:getValue(key.."#expire", SC.MONTH)		
			self.config.hardLimit =		xmlFile:getValue(key.."#hardLimit", -1)		
		end
		key = self.baseXmlKey..".generation"
		self.config.generationInterval = xmlFile:getValue(key.."#interval", 1)
		self.config.missionGenPercentage = xmlFile:getValue(key.."#percentage", 0.2)
		xmlFile:delete()
		for _,setting in ipairs(self.settings) do		
			setting:setValue(self.config[setting.name])
		end
	else
		debugPrint("[%s] config file %s not found, using default settings",self.name,self.configFile)
	end
end
function loadPrices(self)
	local prices = {}
	-- store prices per 1000 l
	local items = {
	 	{"data/objects/bigbagpallet/fertilizer/bigbagpallet_fertilizer.xml", 1, 1920, "FERTILIZER"},
		{"data/objects/pallets/liquidtank/fertilizertank.xml", 0.5, 1600, "LIQUIDFERTILIZER"},
		{"data/objects/pallets/liquidtank/herbicidetank.xml", 0.5, 1200, "HERBICIDE"},
		{"data/objects/bigbagpallet/seeds/bigbagpallet_seeds.xml", 1, 900,""},
		{"data/objects/bigbagpallet/lime/bigbagpallet_lime.xml", 0.5, 225, "LIME"}
	}
	for _, item in ipairs(items) do
		local storeItem = g_storeManager.xmlFilenameToItem[item[1]]
		local price = item[3]
		if storeItem ~= nil then 
			price = storeItem.price * item[2]
		end
		table.insert(prices, price)
	end
	return prices
end
function hookFunctions()
 --[[
	-- to show our ingame menu settings page when admin logs in:
	Utility.appendedFunction(InGameMenuMultiplayerUsersFrame,"onAdminLoginSuccess",adminMP)
	-- to allow forage wagon on bale missions:
	Utility.overwrittenFunction(BaleMission, "new", baleMissionNew)
	-- to allow MOWER / SWATHER on harvest missions:
	Utility.overwrittenFunction(HarvestMission, "new", harvestMissionNew)
	Utility.prependedFunction(HarvestMission, "completeField", harvestCompleteField)
	-- to set missionBale for packed 240cm bales:
	Utility.overwrittenFunction(Bale, "loadBaleAttributesFromXML", loadBaleAttributes)
	-- allow stationary baler to produce mission bales:
	local pType =  g_vehicleTypeManager:getTypeByName("pdlc_goeweilPack.balerStationary")
	if pType ~= nil then
		SpecializationUtil.registerOverwrittenFunction(pType, "createBale", self.createBale)
	end

	-- to count and save/load # of jobs per farm per NPC
	Utility.appendedFunction(AbstractFieldMission,"finish",finish)
	Utility.appendedFunction(FarmStats,"saveToXMLFile",saveToXML)
	Utility.appendedFunction(FarmStats,"loadFromXMLFile",loadFromXML)
	Utility.appendedFunction(Farm,"writeStream",farmWrite)
	Utility.appendedFunction(Farm,"readStream",farmRead)
	Utility.overwrittenFunction(FarmlandManager, "saveToXMLFile", farmlandManagerSaveToXMLFile)

	-- to adjust contracts field compl / reward / vehicle lease values:
	Utility.overwrittenFunction(AbstractFieldMission,"getCompletion",getCompletion)
	Utility.overwrittenFunction(HarvestMission,"getCompletion",harvestCompletion)
	Utility.overwrittenFunction(BaleMission,"getCompletion",baleCompletion)
	Utility.overwrittenFunction(AbstractFieldMission,"getReward",getReward)
	Utility.overwrittenFunction(AbstractFieldMission,"calculateVehicleUseCost",calcLeaseCost)

	-- adjust NPC activity for missions: 
	Utility.overwrittenFunction(FieldManager, "updateNPCField", NPCHarvest)

	-- hard mode:
	Utility.overwrittenFunction(HarvestMission,"calculateStealingCost",harvestCalcStealing)
	Utility.overwrittenFunction(InGameMenuContractsFrame, "onButtonCancel", onButtonCancel)
	Utility.appendedFunction(InGameMenuContractsFrame, "updateDetailContents", updateDetails)
	Utility.appendedFunction(AbstractMission, "dismiss", dismiss)
	g_messageCenter:subscribe(MessageType.DAY_CHANGED, self.onDayChanged, self)
	g_messageCenter:subscribe(MessageType.HOUR_CHANGED, self.onHourChanged, self)
	g_messageCenter:subscribe(MessageType.PERIOD_CHANGED, self.onPeriodChanged, self)

	-- discount mode:
	-- to display discount if farmland selected / on buy dialog
	Utility.appendedFunction(InGameMenuMapFrame, "onClickMap", onClickFarmland)
	Utility.overwrittenFunction(InGameMenuMapFrame, "onClickBuyFarmland", onClickBuyFarmland)
	-- to handle disct price on farmland buy
	g_farmlandManager:addStateChangeListener(self)

	-- to load own mission vehicles:
	Utility.overwrittenFunction(MissionManager, "loadMissionVehicles", BetterContracts.loadMissionVehicles)
	Utility.overwrittenFunction(AbstractFieldMission, "loadNextVehicleCallback", loadNextVehicle)
	Utility.prependedFunction(AbstractFieldMission, "removeAccess", removeAccess)
	Utility.appendedFunction(AbstractFieldMission, "onVehicleReset", onVehicleReset)

	for name, typeDef in pairs(g_vehicleTypeManager.types) do
		-- rename mission vehicle: 
		if typeDef ~= nil and not TableUtility.contains({"horse","pallet","locomotive"}, name) then
			SpecializationUtil.registerOverwrittenFunction(typeDef, "getName", vehicleGetName)
		end
	end
	Utility.appendedFunction(MissionManager, "loadFromXMLFile", missionManagerLoadFromXMLFile)
	Utility.appendedFunction(InGameMenuMapUtil, "showContextBox", showContextBox)

	-- tag mission fields in map: 
	Utility.appendedFunction(FieldHotspot, "render", renderIcon)

	-- get addtnl mission values from server:
	Utility.appendedFunction(BaleMission, "writeStream", BetterContracts.writeStream)
	Utility.appendedFunction(BaleMission, "readStream", BetterContracts.readStream)
	Utility.appendedFunction(TransportMission, "writeStream", BetterContracts.writeTransport)
	Utility.appendedFunction(TransportMission, "readStream", BetterContracts.readTransport)
	Utility.appendedFunction(AbstractMission, "writeUpdateStream", BetterContracts.writeUpdateStream)
	Utility.appendedFunction(AbstractMission, "readUpdateStream", BetterContracts.readUpdateStream)
 ]]
	-- get addtnl mission values from server:
	Utility.appendedFunction(HarvestMission, "writeStream", BetterContracts.writeStream)
	Utility.appendedFunction(HarvestMission, "readStream", BetterContracts.readStream)
	Utility.appendedFunction(HarvestMission, "onSavegameLoaded", onSavegameLoaded)
	-- flexible mission limit: 
	Utility.overwrittenFunction(MissionManager, "hasFarmReachedMissionLimit", hasFarmReachedMissionLimit)
	-- possibly generate more than 1 mission : 
	Utility.overwrittenFunction(MissionManager, "generateMission", generateMission)
	-- set estimated work time for Field Mission: 
	Utility.appendedFunction(MissionManager, "addMission", addMission)
	-- set more details:
	Utility.overwrittenFunction(AbstractFieldMission,"getLocation",getLocation)
	Utility.overwrittenFunction(AbstractFieldMission,"getDetails",fieldGetDetails)
	Utility.overwrittenFunction(HarvestMission,"getDetails",harvestGetDetails)

	-- functions for ingame menu contracts frame:
	Utility.appendedFunction(InGameMenuContractsFrame, "onFrameOpen", onFrameOpen)
	Utility.appendedFunction(InGameMenuContractsFrame, "onFrameClose", onFrameClose)
	-- only need for Details button:
	Utility.appendedFunction(InGameMenuContractsFrame, "setButtonsForState", setButtonsForState)
	Utility.appendedFunction(InGameMenuContractsFrame, "populateCellForItemInSection", populateCell)
	Utility.overwrittenFunction(InGameMenuContractsFrame, "sortList", sortList)
	--[[
	Utility.appendedFunction(InGameMenuContractsFrame, "updateFarmersBox", updateFarmersBox)
	Utility.overwrittenFunction(InGameMenuContractsFrame, "updateList", updateList)
	Utility.overwrittenFunction(InGameMenuContractsFrame, "startContract", startContract)
	Utility.appendedFunction(InGameMenu, "updateButtonsPanel", updateButtonsPanel)
	]]
end
function BetterContracts:initialize()
	debugPrint("[%s] initialize(): %s", self.name,self.initialized)
	if self.initialized ~= nil then return end -- run only once
	self.initialized = false
	self.config = {
		debug = false, 				-- debug mode
		ferment = false, 			-- allow insta-fermenting wrapped bales by player
		forcePlow = false, 			-- force plow after root crop harvest
		maxActive = 3, 				-- max active contracts
		multReward = 1., 			-- general reward multiplier
		multRewardMow = 1.,   		-- mow reward multiplier
		multLease = 1.,				-- general lease cost multiplier
		toDeliver = 0.94,			-- HarvestMission.SUCCESS_FACTOR
		toDeliverBale = 0.90,		-- BaleMission.FILL_SUCCESS_FACTOR
		fieldCompletion = 0.95,		-- AbstractMission.SUCCESS_FACTOR
		generationInterval = 1, 	-- MissionManager.MISSION_GENERATION_INTERVAL
		missionGenPercentage = 0.2, -- percent of missions to be generated (default: 20%)
		refreshMP = SC.ADMIN, 		-- necessary permission to refresh contract list (MP)
		lazyNPC = false, 			-- adjust NPC field work activity
		hardMode = false, 			-- penalty for canceled missions
		discountMode = false, 		-- get field price discount for successfull missions
		npcHarvest = false,
		npcPlowCultivate = false,
		npcSow = false,	
		npcFertilize = false,
		npcWeed = false,
		discPerJob = 0.05,
		discMaxJobs = 5,
		hardPenalty = 0.1, 		-- % of total reward for missin cancel
		hardLease =	2, 			-- # of jobs to allow borrowing equipment
		hardExpire = SC.MONTH, 	-- or "day"
		hardLimit = -1, 		-- max jobs to accept per farm and month
	}
	self.NPCAllowWork = false 				-- npc should not work before noon of last 2 days in month
	self.settingsByName = {}				-- will hold setting objects, init by BCsetting.init()
	self.settings = BCsetting.init(self) 	-- settings list
	self.missionVecs = {} 					-- holds names of active mission vehicles

	g_missionManager.missionMapNumChannels = 6
	self.missionUpdTimeout = 15000
	self.missionUpdTimer = 0 -- will also update on frame open of contracts page
	self.turnTime = 5.0 -- estimated seconds per turn at end of each lane
	self.events = {}
	--  Amazon ZA-TS3200,   Hardi Mega, TerraC6F, Lemken Az9,  mission,grain potat Titan18       
	--  default:spreader,   sprayer,    sower,    planter,     empty,  harv, harv, plow, mow,lime
	self.SPEEDLIMS = {15,   12,         15,        15,         0,      10,   10,   12,   20, 18}
	self.WORKWIDTH = {42,   24,          6,         6,         0,       9,   3.3,  4.9,   9, 18} 
	self.catHarvest = "BEETHARVESTING BEETVEHICLES CORNHEADERS COTTONVEHICLES CUTTERS POTATOHARVESTING POTATOVEHICLES SUGARCANEHARVESTING SUGARCANEVEHICLES"
	self.catSpread = "fertilizerspreaders seeders planters sprayers sprayervehicles slurrytanks manurespreaders"
	self.catSimple = "CULTIVATORS DISCHARROWS PLOWS POWERHARROWS SUBSOILERS WEEDERS ROLLERS"
	self.isOn = true  	-- start with our add-ons
	self.numCont = 0 	-- # of contracts in our tables
	self.numHidden = 0 	-- # of hidden (filtered) contracts 
	self.my = {} 		-- will hold my gui element adresses
	self.sort = 0 		-- sorted status: 1 cat, 2 prof, 3 permin
	self.lastSort = 0 	-- last sorted status
	self.buttons = {
		{"sortcat", g_i18n:getText("SC_sortCat")}, -- {button id, help text}
		{"sortrev", g_i18n:getText("SC_sortRev")},
		{"sortnpc", g_i18n:getText("SC_sortNpc")},
		{"sortprof", g_i18n:getText("SC_sortProf")},
		{"sortpmin", g_i18n:getText("SC_sortpMin")}
	}
	self.npcProb = {
		harvest = 1.0,
		plowCultivate = 0.5,
		sow = 0.5,
		fertilize = 0.9,
		weed = 0.9,
		lime = 0.9
	}
	--checkOtherMods(self)
	registerXML(self) 			-- register xml: self.xmlSchema
	hookFunctions()
end
function generateMission(self, superf)
	-- overwritten, to not finish after 1st mission generated
	--[[debugPrint("** tried %d %s. inProgess %s, canStart %s. Total missions %d",
		self.currentMissionTypeIndex,
		self.missionTypes[self.currentMissionTypeIndex].name,
		self.missionGenerationInProgress,
		self:getCanStartNewMissionGeneration(),
		#self.missions)
	]]
   	local missionType = self.missionTypes[self.currentMissionTypeIndex]
   	if missionType == nil then
	  self:finishMissionGeneration()
	  return
   	end
   
   	if  missionType.classObject.tryGenerateMission ~= nil then
	  mission = missionType.classObject.tryGenerateMission()
		if mission ~= nil then
		 self:registerMission(mission, missionType)
	  	else 
		 self.currentMissionTypeIndex = self.currentMissionTypeIndex +1
		 if self.currentMissionTypeIndex > #self.missionTypes then
			self.currentMissionTypeIndex = 1
		 end
		 if self.currentMissionTypeIndex == self.startMissionTypeIndex then
			self:finishMissionGeneration()
		 end
	  	end
   end
end
function onSavegameLoaded(self)
	-- appended to HarvestMission:onSavegameLoaded()
	-- add selling station fruit price to harvest mission. Really needed?
	self.info.price = BetterContracts:getFilltypePrice(self)
end
function BetterContracts:getFilltypePrice(m)
	-- get price for harvest/ mow-bale missions
	if  m.sellingStation == nil then
		m:tryToResolveSellingStation()
	end
	if m.sellingStation == nil then
		-- can happen when mission loaded from savegame xml. Selling stations are 
		-- only added after "savegameLoaded"
		--Logging.warning("[%s]:addMission(): contract '%s %s on field %s' has no sellingStation.", 
		--	self.name, m.title, self.ft[m.fillTypeIndex].title, m.field:getName())
		return 0
	end
	-- check for Maize+ (or other unknown) filltype
	local fillType = m.fillTypeIndex
	if m.sellingStation.fillTypePrices[fillType] ~= nil then
		return m.sellingStation:getEffectiveFillTypePrice(fillType)
	end
	if m.sellingStation.fillTypePrices[FillType.SILAGE] then
		return m.sellingStation:getEffectiveFillTypePrice(FillType.SILAGE)
	end
	Logging.warning("[%s]:addMission(): sellingStation %s has no price for fillType %s.", 
		self.name, m.sellingStation:getName(), self.ft[m.fillType].title)
	return 0
end
function BetterContracts:calcProfit(m, successFactor)
	-- calculate addtl income as value of kept harvest
	local keep = math.floor(m.expectedLiters *(1 - successFactor))
	local price = self:getFilltypePrice(m)
	return keep, price, keep * price
end
function addMission(self, mission)
	-- appended to MissionManager:addMission(mission)
	local bc = BetterContracts
	local info =  mission.info 					-- store our additional info
	if mission.field ~= nil then
		debugPrint("** add %s on field %s", mission.type.name, mission.field:getName())
		local size = mission.field:getAreaHa()
		info.worktime = size * 600  	-- (sec) 10 min/ha, TODO: make better estimate
		info.profit = 0

		-- consumables cost estimate
		if mission.type.name == "fertilizeMission" then
			info.usage = size * bc.sprUse[SC.FERTILIZER] *36000
			info.profit = -info.usage * bc.prices[SC.FERTILIZER] /1000 
		elseif mission.type.name == "herbicideMission" then
			info.usage = size * bc.sprUse[SC.HERBICIDE] *36000
			info.profit = -info.usage * bc.prices[SC.HERBICIDE] /1000
		elseif mission.type.name == "sowMission" then
			info.usage = size *g_fruitTypeManager:getFruitTypeByIndex(mission.fruitTypeIndex).seedUsagePerSqm *10000
			info.profit = -info.usage * bc.prices[SC.SEEDS] /1000
		elseif mission.type.name == "harvestMission" then
			if mission.expectedLiters == nil then
				Logging.warning("[%s]:addMission(): contract '%s %s on field %s' has no expectedLiters.", 
					bc.name, mission.type.name, bc.ft[mission.fillType].title, mission.field:getName())
				mission.expectedLiters = 0 
			end 
			if mission.expectedLiters == 0 then  
				mission.expectedLiters = mission:getMaxCutLiters()
			end
			info.keep, info.price, info.profit = bc:calcProfit(mission, HarvestMission.SUCCESS_FACTOR)
			info.deliver = math.ceil(mission.expectedLiters - info.keep) 	--must be delivered
		end  	

		info.perMin = (mission:getReward() + info.profit) /info.worktime *60
	end
end
function getLocation(self, superf)
	--overwrites AbstractFieldMission:getLocation()
	if BetterContracts.isOn then
		local fieldId = self.field:getName()
		return string.format("F. %s - %s",fieldId, self.title)
	else
		return superf(self)
	end
end
function fieldGetDetails(self, superf)
	--overwrites AbstractFieldMission:getDetails()
	local list = superf(self)
	if not BetterContracts.isOn then  
		return list
	end
	-- add our values to show in contract details list
	table.insert(list, {
		title = g_i18n:getText("SC_worktim"),
		value = g_i18n:formatMinutes(self.info.worktime /60)
	})
	table.insert(list, {
		title = g_i18n:getText("SC_profpmin"),
		value = g_i18n:formatMoney(self.info.perMin)
	})
	if TableUtility.contains({"fertilizeMission","herbicideMission","sowMission"}, self.type.name) then
		table.insert(list, {
			title = g_i18n:getText("SC_usage"),
			value = g_i18n:formatVolume(self.info.usage)
		})
		table.insert(list, {
			title = g_i18n:getText("SC_cost"),
			value = g_i18n:formatMoney(self.info.profit)
		})
	end
	return list
end
function harvestGetDetails(self, superf)
	--overwrites HarvestMission:getDetails()

	local list = superf(self)
	if not BetterContracts.isOn then  
		return list
	end
	-- add our values to show in contract details list
	local price = BetterContracts:getFilltypePrice(self)
	local deliver = self.expectedLiters - self.info.keep

	if self.status == MissionStatus.RUNNING then
		local eta = {
			["title"] = g_i18n:getText("SC_worked"),
			["value"] = string.format("%.1f%%", self.fieldPercentageDone * 100)
		}
		table.insert(list, eta)
		local depo = 0 		-- just as protection
		if self.depositedLiters then depo = self.depositedLiters end
		depo = MathUtil.round(depo / 100) * 100
		-- don't show negative togos:
		local togo = math.max(MathUtil.round((self.expectedLiters -self.info.keep -depo)/100)*100, 0)
		eta = {
			["title"] = g_i18n:getText("SC_delivered"),
			["value"] = g_i18n:formatVolume(depo)
		}
		table.insert(list, eta)
		eta = {
			["title"] = g_i18n:getText("SC_togo"),
			["value"] = g_i18n:formatVolume(togo)
		}
		table.insert(list, eta)
	else  -- status NEW ----------------------------------------
		local eta = {
			["title"] = g_i18n:getText("SC_deliver"),
			["value"] = g_i18n:formatVolume(MathUtil.round(deliver/100) *100)
		}
		table.insert(list, eta)
		eta = {
			["title"] = g_i18n:getText("SC_keep"),
			["value"] = g_i18n:formatVolume(MathUtil.round(self.info.keep/100) *100)
		}
		table.insert(list, eta)
		eta = {
			["title"] = g_i18n:getText("SC_price"),
			["value"] = g_i18n:formatMoney(price*1000)
		}
		table.insert(list, eta)
	end

	eta = {
		["title"] = g_i18n:getText("SC_profit"),
		["value"] = g_i18n:formatMoney(price*self.info.keep)
	}
	table.insert(list, eta)

	return list
end

function BetterContracts:onSetMissionInfo(missionInfo, missionDynamicInfo)
	PlowMission.REWARD_PER_HA = 2800 	-- tweak plow reward (#137)
	self:updateGenerationInterval()
end
function BetterContracts:onStartMission()
	-- check mission vehicles
	BetterContracts:validateMissionVehicles()
end
function BetterContracts:onPostLoadMap(mapNode, mapFile)
	-- handle our config and optional settings
	if g_server ~= nil then
		readconfig(self)
		local txt = string.format("%s read config: maxActive %d",self.name, self.config.maxActive)
		if self.config.lazyNPC then txt = txt..", lazyNPC" end
		if self.config.hardMode then txt = txt..", hardMode" end
		if self.config.discountMode then txt = txt..", discountMode" end
		debugPrint(txt)
	end
	addConsoleCommand("bcPrint","Print detail stats for all available missions.","consoleCommandPrint",self)
	addConsoleCommand("bcMissions","Print stats for other clients active missions.","bcMissions",self)
	addConsoleCommand("bcPrintVehicles","Print all available vehicle groups for mission types.","printMissionVehicles",self)
	if self.config.debug then
		addConsoleCommand("bcFieldGenerateMission", "Force generating a new mission for given field", "consoleGenerateFieldMission", g_missionManager)
		addConsoleCommand("gsMissionLoadAllVehicles", "Loading and unloading all field mission vehicles", "consoleLoadAllFieldMissionVehicles", g_missionManager)
		addConsoleCommand("gsMissionHarvestField", "Harvest a field and print the liters", "consoleHarvestField", g_missionManager)
		addConsoleCommand("gsMissionTestHarvests", "Run an expansive tests for harvest missions", "consoleHarvestTests", g_missionManager)
	end
	-- init Harvest SUCCESS_FACTORs (std is harv = .93, bale = .9, abstract = .95)
	HarvestMission.SUCCESS_FACTOR = self.config.toDeliver
	BaleMission.FILL_SUCCESS_FACTOR = self.config.toDeliverBale 

	BetterContracts:updateGenerationSettings()

	-- initialize constants depending on game manager instances
	self.isMultiplayer = g_currentMission.missionDynamicInfo.isMultiplayer
	self.ft = g_fillTypeManager.fillTypes
	self.prices = loadPrices()
	self.sprUse = {
		g_sprayTypeManager.sprayTypes[SprayType.FERTILIZER].litersPerSecond,
		g_sprayTypeManager.sprayTypes[SprayType.LIQUIDFERTILIZER].litersPerSecond,
		g_sprayTypeManager.sprayTypes[SprayType.HERBICIDE].litersPerSecond,
		0, -- seeds are measured per sqm, not per second
		g_sprayTypeManager.sprayTypes[SprayType.LIME].litersPerSecond
	}
	self.mtype = {
		FERTILIZE = g_missionManager:getMissionType("fertilizeMission").typeId,
		SOW = g_missionManager:getMissionType("sowMission").typeId,
		SPRAY = g_missionManager:getMissionType("HERBICIDEMISSION").typeId,
	}
	if self.limeMission then 
		self.mtype.LIME = g_missionManager:getMissionType("lime").typeId
	end
	self.gameMenu = g_inGameMenu
	self.frCon = self.gameMenu.pageContracts
	self.frMap = self.gameMenu.pageMapOverview
	--self.frMap.ingameMap.onClickMapCallback = self.frMap.onClickMap
	--self.frMap.buttonBuyFarmland.onClickCallback = onClickBuyFarmland

	initGui(self) 			-- setup my gui additions
	self.initialized = true
end

function BetterContracts:updateGenerationInterval()
	-- init Mission generation rate (std is 1 hour)
	MissionManager.MISSION_GENERATION_INTERVAL = self.config.generationInterval * 3600000
end
function BetterContracts:updateGenerationSettings()
	self:updateGenerationInterval()

	-- adjust max missions
	local fieldsAmount = table.size(g_fieldManager.fields)
	local adjustedFieldsAmount = math.max(fieldsAmount, 45)
	MissionManager.MAX_MISSIONS = math.min(80, math.ceil(adjustedFieldsAmount * 0.60)) -- max missions = 60% of fields amount (minimum 45 fields) max 120
	debugPrint("[%s] Fields amount %s (%s)", self.name, fieldsAmount, adjustedFieldsAmount)
	debugPrint("[%s] MAX_MISSIONS set to %s", self.name, MissionManager.MAX_MISSIONS)
end

function BetterContracts:onPostSaveSavegame(saveDir, savegameIndex)
	-- save our settings
	debugPrint("** saving settings to %s (%d)", saveDir, savegameIndex)
	self.configFile = saveDir.."/".. self.name..'.xml'
	local xmlFile = XMLFile.create("BCconf", self.configFile, self.baseXmlKey, self.xmlSchema)
	if xmlFile == nil then return end 

	local conf = self.config
	local key = self.baseXmlKey 
	xmlFile:setBool ( key.."#debug", 		  conf.debug)
	xmlFile:setBool ( key.."#ferment", 		  conf.ferment)
	xmlFile:setBool ( key.."#forcePlow", 	  conf.forcePlow)
	xmlFile:setInt  ( key.."#maxActive",	  conf.maxActive)
	xmlFile:setFloat( key.."#reward", 		  conf.multReward)
	xmlFile:setFloat( key.."#rewardMow", 	  conf.multRewardMow)
	xmlFile:setFloat( key.."#lease", 		  conf.multLease)
	xmlFile:setFloat( key.."#deliver", 		  conf.toDeliver)
	xmlFile:setFloat( key.."#deliverBale", 	  conf.toDeliverBale)
	xmlFile:setFloat( key.."#fieldCompletion",conf.fieldCompletion)
	xmlFile:setInt  ( key.."#refreshMP",	  conf.refreshMP)
	xmlFile:setBool ( key.."#lazyNPC", 		  conf.lazyNPC)
	xmlFile:setBool ( key.."#discount", 	  conf.discountMode)
	xmlFile:setBool ( key.."#hard", 		  conf.hardMode)
	if conf.lazyNPC then
		key = self.baseXmlKey .. ".lazyNPC"
		xmlFile:setBool (key.."#harvest", 	conf.npcHarvest)
		xmlFile:setBool (key.."#plowCultivate",conf.npcPlowCultivate)
		xmlFile:setBool (key.."#sow", 		conf.npcSow)
		xmlFile:setBool (key.."#weed", 		conf.npcWeed)
		xmlFile:setBool (key.."#fertilize", conf.npcFertilize)
	end
	if conf.discountMode then
		key = self.baseXmlKey .. ".discount"
		xmlFile:setFloat(key.."#perJob", 	conf.discPerJob)
		xmlFile:setInt  (key.."#maxJobs",	conf.discMaxJobs)
	end
	if conf.hardMode then
		key = self.baseXmlKey .. ".hard"
		xmlFile:setFloat(key.."#penalty", 	conf.hardPenalty)
		xmlFile:setInt  (key.."#leaseJobs",	conf.hardLease)
		xmlFile:setInt  (key.."#expire",	conf.hardExpire)
		xmlFile:setInt  (key.."#hardLimit",	conf.hardLimit)
	end
	key = self.baseXmlKey .. ".generation"
	xmlFile:setInt	( key.."#interval",   conf.generationInterval)
	xmlFile:setFloat( key.."#percentage", conf.missionGenPercentage)
	xmlFile:save()
	xmlFile:delete()
end
function BetterContracts:onWriteStream(streamId)
	-- write settings to a client when it joins
	for _, setting in ipairs(self.settings) do 
		setting:writeStream(streamId)
	end
end
function BetterContracts:onReadStream(streamId)
	-- client reads our config settings when it joins
	for _, setting in ipairs(self.settings) do 
		setting:readStream(streamId)
	end
end
function BetterContracts:onUpdate(dt)
	if self.transportMission and g_server == nil then 
		updateTransportTimes(dt)
	end 
end

function BetterContracts.writeStream(self, streamId, connection)
	streamWriteFloat32(streamId, self.expectedLiters)
	streamWriteFloat32(streamId, self.depositedLiters)
end
function BetterContracts.readStream(self, streamId, connection)
	self.expectedLiters = streamReadFloat32(streamId)
	self.depositedLiters = streamReadFloat32(streamId)
end
function BetterContracts.writeTransport(self, streamId, connection)
	-- timeleft for transport mission
	streamWriteInt32(streamId, self.timeLeft or 0)
end
function BetterContracts.readTransport(self, streamId, connection)
	self.timeLeft = streamReadInt32(streamId)
end
function updateTransportTimes(dt)
	-- update timeLeft for transport missions on an MP client
	for _,m in ipairs(g_missionManager.missions) do
		if m.timeLeft ~= nil then 
			m.timeLeft = m.timeLeft - dt * g_currentMission:getEffectiveTimeScale()
		end
	end
end
function BetterContracts.writeUpdateStream(self, streamId, connection, dirtyMask)
	-- only called for active missions
	if self.status == AbstractMission.STATUS_RUNNING then
		streamWriteBool(streamId, self.spawnedVehicles or false)
		streamWriteFloat32(streamId, self.fieldPercentageDone or 0.)
		streamWriteFloat32(streamId, self.depositedLiters or 0.)
	end
end
function BetterContracts.readUpdateStream(self, streamId, timestamp, connection)
	if self.status == AbstractMission.STATUS_RUNNING then
		self.spawnedVehicles = streamReadBool(streamId)
		self.fieldPercentageDone = streamReadFloat32(streamId)
		self.depositedLiters = streamReadFloat32(streamId)
	end
end
function hasFarmReachedMissionLimit(self,superf,farmId)
	-- overwritten from MissionManager
	local maxActive = BetterContracts.config.maxActive
	if maxActive == 0 then return false end 

	MissionManager.ACTIVE_CONTRACT_LIMIT = maxActive
	return superf(self, farmId)
end
function adminMP(self)
	-- appended to InGameMenuMultiplayerUsersFrame:onAdminLoginSuccess()
	BetterContracts.gameMenu:updatePages()
end
function baleMissionNew(isServer, superf, isClient, customMt )
	-- allow forage wagons to collect grass/ hay, for baling/wrapping at stationary baler
	local self = superf(isServer, isClient, customMt)
	self.workAreaTypes[WorkAreaType.FORAGEWAGON] = true 
	self.workAreaTypes[WorkAreaType.CUTTER] = true 
	return self
end
function harvestMissionNew(isServer, superf, isClient, customMt )
	-- allow mower/ swather to harvest swaths
	local self = superf(isServer, isClient, customMt)
	self.workAreaTypes[WorkAreaType.MOWER] = true 
	self.workAreaTypes[WorkAreaType.FORAGEWAGON] = true 
	return self
end
