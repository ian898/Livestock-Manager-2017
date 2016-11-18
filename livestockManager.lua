--
-- Filename: livestockManager.lua
-- Author: Ian898, CBModding, Xentro
-- Date: 08/11/2016
--

livestockManager = {};
livestockManager.version = ModsUtil.findModItemByModName(g_currentModName).version;
livestockManager.modDirectory = g_currentModDirectory;
livestockManager.IS_DEV = false;
livestockManager.DEBUG = false;

addModEventListener(livestockManager);

function livestockManager:loadMap()
	self.animals = {"chicken","sheep","cow","pig"};
	
	if livestockManager.IS_DEV then
		print("");
		print("-- Livestock Manager v" .. self.version .. ", author: Ian898 / CBModding --");
		print("-- WARNING : You have Livestock Manager Development Edition installed,");
		print("-- Which can contain errors and CBModding will not be held responsibility for lose of savegames or any effects this may have on your game use at your own risk.");
		print("");
		
		livestockManager.debugTableNames = {};
		for i, name in ipairs(self.animals) do
			livestockManager.debugTableNames[name] = {};
			livestockManager.debugTableNames[name]["breedingRate"] 		= "Breeding Rate: ";
			livestockManager.debugTableNames[name]["condition"] 		= "Condition: ";
			livestockManager.debugTableNames[name]["breedingChance"]	= "Breeding Chance: ";
			livestockManager.debugTableNames[name]["deathChance"] 		= "Death Chance: ";
		end;
	else
		-- Me personaly dont like unnecessary stuff like this in my log file, I want an clean log file / X 
		-- print("-- Livestock Manager v" .. self.version .. ", author: Ian898 / CBModding --");
	end;

	self.updateMs = -1; -- Do update on startup
	self.animal = g_currentMission.husbandries;
	self.night_temp = 10;
	self.overlayScale = g_gameSettings:getValue("uiScale");
	
	local x, y = livestockManager.convertOurScreen(175, 95); -- Offset values from screen edges
	local width, height = getNormalizedScreenValues(512, 512);
	self.livestockManagerOverlay = Overlay:new("LivestockManagerOverlay", Utils.getFilename("hud.dds", self.modDirectory), x, y, width, height);
	
	
	for i, name in ipairs(self.animals) do
		self.animals[name] = {};
		self.animals[name].enableBreeding = false;
		self.animals[name].enableDieing = true;
		self.animals[name].childLimit = 12;
		self.animals[name].breedingLimit = 250;
		self.animals[name].breedingRate = 672; 	-- 7 Days
		self.animals[name].breedingChance = 0;
		self.animals[name].deathRate = 96; 		-- 1 Day
		self.animals[name].deathChance = 0;
		self.animals[name].deathModifier = 1;	
		self.animals[name].manureMax = 100000;
		
		-- Synch with clients	
		self.animals[name].condition = 100;
		self.animals[name].states = {};
		self.animals[name].states.water = true;
		self.animals[name].states.feed = true;
		self.animals[name].states.bedding = true;
		self.animals[name].states.dirty = false;
		
		-- Tell if we can send an event
		if g_currentMission:getIsServer() then
			self.animals[name].lastState = {};
			self.animals[name].lastState.water = true;
			self.animals[name].lastState.feed = true;
			self.animals[name].lastState.bedding = true;
			self.animals[name].lastState.dirty = false;
			self.animals[name].lastState.condition = 100;
		end;
	end;
	
	-- Only load settings if your host/owner
	if g_currentMission:getIsServer() then
		-- Only if valid save game
		if g_currentMission.missionInfo.isValid then
			livestockManager:loadSettings();
		end;
	end;
	
	g_currentMission.livestockManager = self;
end;

function livestockManager:deleteMap()
	self.livestockManagerOverlay:delete();
end;

function livestockManager:keyEvent(unicode, sym, modifier, isDown)
end;

function livestockManager:mouseEvent(posX, posY, isDown, isUp, button)
end;

function livestockManager:update(dt)
	if g_currentMission:getIsClient() then
		-- Check if we are using GUI or player is frozen
		if g_gui.currentGui == nil and not g_currentMission.isPlayerFrozen then
			if InputBinding.hasEvent(InputBinding.LM_TOGGLE) then
				-- This is an client side only activation, no event needed.
				self.livestockManagerOverlay:setIsVisible(not self.livestockManagerOverlay.visible);
			end;
		end;
	end;
	
	-- Only do this on server, dedicated server or player which started the MP game
	if g_currentMission:getIsServer() then
		local forceUpdate = false;
		
		-- force an update if player count is different, an approuch to synch client needed data. 
		if g_currentMission.missionDynamicInfo.isMultiplayer then 	-- This let both dedicated servers and player hosted game to call the client synch
		-- if g_dedicatedServerInfo ~= nil then 					-- this limit us to dedicated server only
			if self.doWeNeedToSynchNum == nil then
				self.doWeNeedToSynchNum = 1; -- This is "server player"
			end;
			
			local numUsers = #g_currentMission.users; -- Count users
			if self.doWeNeedToSynchNum ~= numUsers then
				if numUsers > self.doWeNeedToSynchNum then
					self.doWeNeedToSynchNum = numUsers;
					forceUpdate = true;

					if livestockManager.DEBUG then
						print("LivestockManager is forcing data update due to player joining. " .. numUsers);
					end;
				else
					-- Player left
					-- print("LivestockManager is letting you know that an player has left " .. numUsers);
				end;
				
				self.doWeNeedToSynchNum = numUsers;
			end;
		end;
		
		
		if self.updateMs == -1 or self.updateMs >= 1200000 or forceUpdate then
		-- if self.updateMs == -1 or self.updateMs >= 60000 or forceUpdate then -- Needed more updates for testing
			self.updateMs = 0;
			
			for _, animalType in ipairs(self.animals) do
				
				if self.animals[animalType].enableBreeding then
					if g_currentMission.husbandries[animalType].animalDesc.birthRatePerDay ~= 0 then
						g_currentMission.husbandries[animalType].animalDesc.birthRatePerDay = 0;
					end;
				end;
				
				local numAnimals = self.animal[animalType].numAnimals[0];
				
				if numAnimals > 0 then
				
					local isBreeding, isDeteriorating, isCold;
					local hasFeed, hasWater, hasManure, hasBedding;					
					local foodTypes, gotFood, gotWater, gotManure
					
					if animalType == "pig" then
						foodTypes = {"FILLTYPE_WHEAT", 
									 "FILLTYPE_BARLEY", 
									 "FILLTYPE_RAPE",
									 "FILLTYPE_SUNFLOWER",
									 "FILLTYPE_MAIZE",
									 "FILLTYPE_POTATO",
									 "FILLTYPE_SUGARBEET"};
					elseif animalType == "cow" then
						foodTypes = {"FILLTYPE_GRASS_WINDROW", 
									 "FILLTYPE_DRYGRASS_WINDROW",
									 "FILLTYPE_SILAGE"};
					elseif animalType == "sheep" then
						foodTypes = {"FILLTYPE_GRASS_WINDROW", 
									 "FILLTYPE_DRYGRASS_WINDROW"};
					elseif animalType == "chicken" then
						foodTypes = {"FILLTYPE_WHEAT"};
					end;
					
					for _, foodType in ipairs(foodTypes) do
						if self.animal[animalType]:getFillLevel(FillUtil[foodType]) > 0 then
							gotFood = true;
							break; -- We found what we need now stop loop
						end;
					end;
					
					if self.animal[animalType]:getFillLevel(FillUtil.FILLTYPE_WATER) > 0 then
						gotWater = true;
					end;
					
					if self.animal[animalType]:getFillLevel(FillUtil.FILLTYPE_STRAW) > 0 then
						gotBedding = true;
					end;
					
					if self.animal[animalType].manureFillLevel ~= nil then
						if self.animal[animalType].manureFillLevel >= self.animals[animalType].manureMax then
							gotManure = true;
						end;
					end;
					
					hasFeed = gotFood ~= nil;
					hasWater = gotWater ~= nil;					
					hasBedding = gotBedding ~= nil;
					hasManure = gotManure ~= nil;
					
					self.animals[animalType].states.feed = hasFeed;
					self.animals[animalType].states.water = hasWater;					
					
					local state = hasFeed and hasWater;
					isBreeding = state;
					isDeteriorating = not state;
					
					if animalType == "cow" or animalType == "pig" then
					
						local state = hasBedding and not hasManure;
						isBreeding = state;
						
						self.animals[animalType].states.bedding = hasBedding;
						self.animals[animalType].states.dirty = hasManure;
						
						isCold = false;
						
						local time_hour = g_currentMission.environment.currentHour;
						
						if self.night_temp == nil then
							self.night_temp = g_currentMission.environment.weatherTemperaturesNight[1];
						end;
						
						if time_hour >= 19 or time_hour <= 5 then
							if self.night_temp <= 5 then
								if not hasBedding then								
									isBreeding = false;
									isDeteriorating = true;
									isCold = true;
								end;
							end;
						else
							self.night_temp = g_currentMission.environment.weatherTemperaturesNight[1];
						end;
					end;
					
					-- Chickens -- Work Around
					if animalType == "chicken" then
						
						hasFeed = true;
						hasWater = true;
						
						self.animals[animalType].states.feed = hasFeed;
						self.animals[animalType].states.water = hasWater;
						self.animals[animalType].states.bedding = true;
						self.animals[animalType].states.dirty = false;
						
						local state = hasFeed and hasWater;
						isBreeding = state;
						isDeteriorating = not state;						
						
					end;
					
					
					-- Configure Breeding / Condition
					if isBreeding then
						
						self.animals[animalType].condition = math.min(self.animals[animalType].condition + 2.5, 100);
						
						if self.animals[animalType].condition >= 90 then
						
							self.animals[animalType].breedingChance = self.animals[animalType].breedingChance + 1;
							
							self.animals[animalType].deathChance = math.max(self.animals[animalType].deathChance - 1, 0);
							
						end;
						
						if self.animals[animalType].breedingChance > self.animals[animalType].breedingRate then
						
							livestockManager:births(animalType, numAnimals);
							
						end;
						
					else
						
						-- Open hud if animals need attention.
						self.livestockManagerOverlay:setIsVisible(true);

						-- if no bedding degrade animal condition slowly.
						if not isDeteriorating and self.animals[animalType].condition > 65 then
							self.animals[animalType].condition = math.max(self.animals[animalType].condition - 1.00, 0);
						elseif not isDeteriorating and self.animals[animalType].condition < 62 then
							self.animals[animalType].condition = math.min(self.animals[animalType].condition + 2.5, 100);
						end;
						
						if self.animals[animalType].condition < 70 then
						
							self.animals[animalType].breedingChance = math.max(self.animals[animalType].breedingChance - 1, 0);
							
						end;
						
					end;
					
					-- Configure Deterioration
					if isDeteriorating then
					
						-- Open hud if animals need attention.
						self.livestockManagerOverlay:setIsVisible(true);
						
						if isCold then
							self.animals[animalType].condition = math.max(self.animals[animalType].condition - 1.60, 0);
							self.animals[animalType].deathChance = self.animals[animalType].deathChance + 1;
						end;
						
						-- Fix condition not degrading when still has bedding.
						if isBreeding then
							self.animals[animalType].condition = math.max(self.animals[animalType].condition - 3.30, 0);
						else
							self.animals[animalType].condition = math.max(self.animals[animalType].condition - 0.80, 0);
						end;
						
						if self.animals[animalType].condition < 60 then
						
							self.animals[animalType].deathChance = self.animals[animalType].deathChance + 1;
							
						end;
						
						if self.animals[animalType].deathChance > self.animals[animalType].deathRate then
						
							livestockManager:deaths(animalType, numAnimals);
							
						end;
					
					else
					
						self.animals[animalType].deathModifier = 1;
						
					end;
					
				else
					self.animals[animalType].condition = 100;
					self.animals[animalType].states.water = true;
					self.animals[animalType].states.feed = true;
					self.animals[animalType].states.bedding = true;
					self.animals[animalType].states.dirty = false;
				end;
				
				
				if self.animals[animalType].lastState.water ~= self.animals[animalType].states.water
				or self.animals[animalType].lastState.feed ~= self.animals[animalType].states.feed
				or self.animals[animalType].lastState.bedding ~= self.animals[animalType].states.bedding
				or self.animals[animalType].lastState.dirty ~= self.animals[animalType].states.dirty
				or self.animals[animalType].lastState.condition ~= self.animals[animalType].condition 
				or forceUpdate then
					local eventType = 0; -- For more details take a look in the event file
					if livestockManager.DEBUG then
						--print("preparing to write data to clients");
					end;
					if livestockManager.IS_DEV then
						eventType = 1;
					end;
					self.animals[animalType].lastState.water 	 = self.animals[animalType].states.water;
					self.animals[animalType].lastState.feed 	 = self.animals[animalType].states.feed;
					self.animals[animalType].lastState.bedding 	 = self.animals[animalType].states.bedding;
					self.animals[animalType].lastState.dirty 	 = self.animals[animalType].states.dirty;
					self.animals[animalType].lastState.condition = self.animals[animalType].condition;
					
					-- state have changed on server, send event to clients!
					g_server:broadcastEvent(livestockManagerEvent:new(eventType, animalType, self.animals[animalType].lastState.water, self.animals[animalType].lastState.feed, self.animals[animalType].lastState.bedding, self.animals[animalType].lastState.dirty, self.animals[animalType].lastState.condition));
					
					-- Do note that we arent sending deathChance or breedingChance so you wont be able to debug them on MP if your an client
				end;
			end;
		else
			self.updateMs = self.updateMs + (dt * g_currentMission.missionInfo.timeScale);
		end;
	end;
end;

function livestockManager:draw()
	if not self.livestockManagerOverlay.visible then return end;

	local posX = self.livestockManagerOverlay.x;
	local posY = self.livestockManagerOverlay.y;
	local fontSize = getCorrectTextSize(0.013 * self.overlayScale);
	local spacing = 0.016 * self.overlayScale;
	local spacingHeight = 0.01 * self.overlayScale;
	local heightOffset = 0;
	
	setTextBold(true);
	setTextColor(1, 1, 1, 0.5);
	setTextAlignment(RenderText.ALIGN_LEFT);
	
	-- Get text from modDesc
	renderText(posX + 0.002, posY - heightOffset, getCorrectTextSize(0.016 * self.overlayScale), "Livestock Manager 2017"); 
	setTextBold(false);

	heightOffset = heightOffset + (spacing * 2);
	
	for _, animalType in ipairs(self.animals) do
		local numAnimals = self.animal[animalType].numAnimals[0];

		if numAnimals > 0 then
			setTextBold(true);
			renderText(posX, posY - heightOffset, fontSize, string.format(g_i18n:getText("LM_" .. string.upper(animalType) .. "_TITLE"), round(self.animals[animalType].condition)));
			setTextBold(false);
			heightOffset = heightOffset + spacing;	

			if not self.animals[animalType].states.water then
				renderText(posX + spacingHeight, posY - heightOffset, fontSize, g_i18n:getText("LM_NEEDS1"));	
				heightOffset = heightOffset + spacing;
			end;

			if not self.animals[animalType].states.feed then
				renderText(posX + spacingHeight, posY - heightOffset, fontSize, g_i18n:getText("LM_NEEDS2")); 
				heightOffset = heightOffset + spacing;
			end;

			if not self.animals[animalType].states.bedding then
				renderText(posX + spacingHeight, posY - heightOffset, fontSize, string.format(g_i18n:getText("LM_NEEDS3"), self.night_temp)); 
				heightOffset = heightOffset + spacing;
			end;

			if self.animals[animalType].states.dirty then
				renderText(posX + spacingHeight, posY - heightOffset, fontSize, g_i18n:getText("LM_NEEDS4")); 
				heightOffset = heightOffset + spacing;
			end;

			if self.animals[animalType].states.water and self.animals[animalType].states.feed and self.animals[animalType].states.bedding and not self.animals[animalType].states.dirty then
				renderText(posX + spacingHeight, posY - heightOffset, fontSize, g_i18n:getText("LM_NEEDS0")); 
				heightOffset = heightOffset + spacing;
			end;		
		end;
	end;

	
	if livestockManager.DEBUG then
		heightOffset = heightOffset + (spacing * 2);
		local strs = {"", ""};
		
		strs[1] = strs[1] .. "Debug Settings \n";
		strs[2] = strs[2] .. "\n";
		strs[1] = strs[1] .. "Update \n";
		strs[2] = strs[2] .. string.format("%s\n", math.ceil(self.updateMs / 60000));
		
		for name, v in pairs(livestockManager.debugTableNames) do
			strs[1] = strs[1] .. string.format("%s:\n", name);
			strs[2] = strs[2] .. "\n";
			
			for var, text in pairs(v) do
				strs[1] = strs[1] .. string.format("   %s\n", text);
				strs[2] = strs[2] .. string.format("%s\n", self.animals[name][var]);
			end;
		end;
		
		strs[1] = strs[1] .. "\n";
		strs[2] = strs[2] .. "\n";
		strs[1] = strs[1] .. "WeatherTemp Day: \n";
		strs[2] = strs[2] .. string.format("%s\n", g_currentMission.environment.weatherTemperaturesDay[1]);
		strs[1] = strs[1] .. "WeatherTemp Night: \n";
		strs[2] = strs[2] .. string.format("%s\n", g_currentMission.environment.weatherTemperaturesNight[1]);
		
		-- pos X, pos Y, text size, table (texts), min width space
		Utils.renderMultiColumnText(posX, posY - heightOffset, fontSize, strs, 0.012, {RenderText.ALIGN_LEFT, RenderText.ALIGN_LEFT});
		heightOffset = heightOffset + ((spacing * 1.75) * 13); -- we got 13 debug lines
	end;
	
	
	renderOverlay(self.livestockManagerOverlay.overlayId, posX - 0.005, posY - heightOffset, 0.12 * self.overlayScale, (0.024 * self.overlayScale) + heightOffset);
	-- The above does the same but it saves us from setting new values for x, y, widht, height trough self.livestockManagerOverlay
	-- self.livestockManagerOverlay:render();
	
	
	-- clean up after us, text render after this will be affected otherwise.
	setTextColor(1, 1, 1, 1);
	setTextBold(false);
end;

function livestockManager:births(animalType, numAnimals)
	if self.animals[animalType].breedingLimit > numAnimals then
		if numAnimals >= 2 or animalType == "chicken" and numAnimals >= 1 then
			local newChild = math.min(math.ceil(numAnimals / 8), self.animals[animalType].childLimit);
			
			if self.animals[animalType].enableBreeding then
				self.animal[animalType]:addAnimals(newChild,0);
			end;
		end;
	end;
	
	self.animals[animalType].breedingChance = 0;
end;

function livestockManager:deaths(animalType, numAnimals)
	if numAnimals <= 0 then
		return false;
	end;

	local death = math.min(math.ceil(numAnimals / 8), 12);
	
	death = math.ceil(death * self.animals[animalType].deathModifier);
	
	self.animals[animalType].deathModifier = self.animals[animalType].deathModifier + 0.25;
	
	if self.animals[animalType].enableDieing then
		if numAnimals > death then
			self.animal[animalType]:removeAnimals(math.ceil(death),0);
		else
			self.animal[animalType]:removeAnimals(1,0);
		end;
	end;
	
	self.animals[animalType].deathChance = 0;
end;

function livestockManager:loadSettings()
	local xmlPath = g_currentMission.missionInfo.savegameDirectory .. "/livestockManager.xml";

	if fileExists(xmlPath) then
		xml = loadXMLFile("livestockManagerState", xmlPath, "livestockManager");
		
		-- Load Hud Positions
		local hudPosX = getXMLFloat(xml, "livestockManager.hud.posX");
		local hudPosY = getXMLFloat(xml, "livestockManager.hud.posY");
		if hudPosX ~= nil and hudPosY ~= nil then
			self.livestockManagerOverlay:setPosition(hudPosX, hudPosY);
		end;
		
		for k, type in ipairs(self.animals) do
			self:loadSettingAndSet(xml, type, "enableBreeding", "bool");
			self:loadSettingAndSet(xml, type, "enableDieing", "bool");
			self:loadSettingAndSet(xml, type, "childLimit", "float");
			self:loadSettingAndSet(xml, type, "breedingLimit", "float");
			self:loadSettingAndSet(xml, type, "breedingRate", "float");
			self:loadSettingAndSet(xml, type, "condition", "float");
			self:loadSettingAndSet(xml, type, "breedingChance", "float");
			self:loadSettingAndSet(xml, type, "deathChance", "float");
			if type == "cow" or type == "pig" then
				self:loadSettingAndSet(xml, type, "manureMax", "float");
			end;
		end;		
	end;
end;

function livestockManager:saveSettings()
	local savegame = self.savegames[self.selectedIndex];
	if savegame ~= nil then
		local xml = createXMLFile("livestockManagerState", savegame.savegameDirectory .. "/livestockManager.xml", "livestockManager");
		
		setXMLFloat(xml, "livestockManager.hud.posX", g_currentMission.livestockManager.livestockManagerOverlay.x);
		setXMLFloat(xml, "livestockManager.hud.posY", g_currentMission.livestockManager.livestockManagerOverlay.y);
		for k, type in ipairs(g_currentMission.livestockManager.animals) do
			setXMLBool(xml, "livestockManager.".. tostring(type) .. ".enableBreeding", g_currentMission.livestockManager.animals[type].enableBreeding);
			setXMLBool(xml, "livestockManager.".. tostring(type) .. ".enableDieing", g_currentMission.livestockManager.animals[type].enableDieing);
			setXMLInt(xml, "livestockManager.".. tostring(type) .. ".childLimit", g_currentMission.livestockManager.animals[type].childLimit);
			setXMLInt(xml, "livestockManager.".. tostring(type) .. ".breedingLimit", g_currentMission.livestockManager.animals[type].breedingLimit);
			setXMLString(xml, "livestockManager.".. tostring(type) .. ".breedingRate", string.format("%.2f",(g_currentMission.livestockManager.animals[type].breedingRate / 96)));
			setXMLInt(xml, "livestockManager.".. tostring(type) .. ".condition", g_currentMission.livestockManager.animals[type].condition);
			setXMLInt(xml, "livestockManager.".. tostring(type) .. ".breedingChance", g_currentMission.livestockManager.animals[type].breedingChance);
			setXMLInt(xml, "livestockManager.".. tostring(type) .. ".deathChance", g_currentMission.livestockManager.animals[type].deathChance);
			if type == "cow" or type == "pig" then
				setXMLInt(xml, "livestockManager.".. tostring(type) .. ".manureMax", g_currentMission.livestockManager.animals[type].manureMax);
			end;
		end;
		saveXMLFile(xml);
		delete(xml);
	end;
end;
g_careerScreen.saveSavegame = Utils.appendedFunction(g_careerScreen.saveSavegame, livestockManager.saveSettings);

-- Convert our screen space from bottom left to top right
function livestockManager.convertOurScreen(x, y)
	local x, y = getNormalizedScreenValues(x, y);
	
	-- Convert screen values
	x = math.abs(x - 1);
	y = math.abs(y - 1);
	
	return x, y;
end;

function round(num, idp)
	if Utils.getNoNil(num, 0) > 0 then
		local mult = 10^(idp or 0);
		return math.floor(num * mult + 0.5) / mult;
	else 
		return 0;
	end;
end;

function livestockManager:loadSettingAndSet(xml, name, setting, varType)
	local str = "livestockManager." .. name .. "." .. setting;
	local value;
	
	if varType == "bool" then
		value = getXMLBool(xml, str);
	elseif varType == "float" then
		value = getXMLFloat(xml, str);
	end;
	
	if value ~= nil then
		if string.match(setting, "breedingRate") ~= nil then
			value = value * 96;
		end;
		
		self.animals[name][setting] = value;
	end;
end;

-- Dev tools
function livestockManager:LivestockManagerHudX(value)
	if value == nil then
		value = value * g_screenWidth;
	end;
	
	local x, _ = livestockManager.convertOurScreen(tonumber(value), 0);
	if value ~= nil then
		livestockManager.livestockManagerOverlay.x = x;
	end;
	
	print("Livstock overlay X: " .. tostring(value) .. " - " .. tostring(x));
end;

function livestockManager:LivestockManagerHudY(value)
	if value == nil then
		value = value * g_screenHeight;
	end;
	
	local _, y = livestockManager.convertOurScreen(0, tonumber(value));
	if value ~= nil then
		livestockManager.livestockManagerOverlay.y = y;
	end;
	
	print("Livstock overlay Y: " .. tostring(value) .. " - " .. tostring(y));
end;

if livestockManager.IS_DEV then
	addConsoleCommand("LivestockManagerHudY", "LivestockManagerHudY", "LivestockManagerHudY", livestockManager);
	addConsoleCommand("LivestockManagerHudX", "LivestockManagerHudX", "LivestockManagerHudX", livestockManager);
end;