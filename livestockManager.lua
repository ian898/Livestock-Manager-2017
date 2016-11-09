--
-- Filename: livestockManager.lua
-- Author: Ian898 / CBModding
-- Date: 08/11/2016
--

local modDesc = loadXMLFile("modDesc", g_currentModDirectory .. "modDesc.xml");

livestockManager = {};
livestockManager.version = getXMLString(modDesc, "modDesc.version");
livestockManager.modDirectory = g_currentModDirectory;

addModEventListener(livestockManager);

function livestockManager:loadMap()
	
	self.isDev = true;
	if self.isDev then
		print("");
		print("-- Livestock Manager v" .. self.version .. ", author: Ian898 / CBModding --");
		print("-- WARNING : You have Livestock Manager Development Edition installed,");
		print("-- Which can contain errors and CBModding will not be held responsibility for lose of savegames or any effects this may have on your game use at your own risk.");
		print("");
	else
		print("-- Livestock Manager v" .. self.version .. ", author: Ian898 / CBModding --");
	end;
	
	self.debug = false;

	self.updateMs = 0;
	
	self.hud = {};
	self.hud.active = false;
	self.hud.overlay = createImageOverlay(Utils.getFilename("hud.png", self.modDirectory));
	self.hud.posX = -0.055600;
	self.hud.posY = -0.027000;
	
	self.animal = g_currentMission.husbandries;
	
	self.animals = {"chicken","sheep","cow","pig"};
	self.animals.pig = {};
		self.animals.pig.enableBreeding = false;
		self.animals.pig.enableDieing = true;
		self.animals.pig.childLimit = 12;
		self.animals.pig.breedingLimit = 250;
		self.animals.pig.breedingRate = 672; -- 7 Days
		self.animals.pig.breedingChance = 0;
		self.animals.pig.deathRate = 96; -- 1 Day
		self.animals.pig.deathChance = 0;
		self.animals.pig.deathModifier = 1;		
		self.animals.pig.condition = 100;
		self.animals.pig.manureMax = 100000;
		self.animals.pig.states = {};
			self.animals.pig.states.water = true;
			self.animals.pig.states.feed = true;
			self.animals.pig.states.bedding = true;
			self.animals.pig.states.dirty = false;
	
	self.animals.cow = {};
		self.animals.cow.enableBreeding = false;
		self.animals.cow.enableDieing = true;
		self.animals.cow.childLimit = 12;
		self.animals.cow.breedingLimit = 250;
		self.animals.cow.breedingRate = 672; -- 7 Days
		self.animals.cow.breedingChance = 0;
		self.animals.cow.deathRate = 96; -- 1 Day
		self.animals.cow.deathChance = 0;
		self.animals.cow.deathModifier = 1;		
		self.animals.cow.condition = 100;
		self.animals.cow.manureMax = 100000;
		self.animals.cow.states = {};
			self.animals.cow.states.water = true;
			self.animals.cow.states.feed = true;
			self.animals.cow.states.bedding = true;
			self.animals.cow.states.dirty = false;
		
	self.animals.sheep = {};
		self.animals.sheep.enableBreeding = false;
		self.animals.sheep.enableDieing = true;
		self.animals.sheep.childLimit = 12;
		self.animals.sheep.breedingLimit = 250;
		self.animals.sheep.breedingRate = 672; -- 7 Days
		self.animals.sheep.breedingChance = 0;
		self.animals.sheep.deathRate = 96; -- 1 Day
		self.animals.sheep.deathChance = 0;
		self.animals.sheep.deathModifier = 1;
		self.animals.sheep.condition = 100;
		self.animals.sheep.manureMax = 100000;
		self.animals.sheep.states = {};
			self.animals.sheep.states.water = true;
			self.animals.sheep.states.feed = true;
			self.animals.sheep.states.bedding = true;
			self.animals.sheep.states.dirty = false;
		
	self.animals.chicken = {};
		self.animals.chicken.enableBreeding = false;
		self.animals.chicken.enableDieing = true;
		self.animals.chicken.childLimit = 12;
		self.animals.chicken.breedingLimit = 250;		
		self.animals.chicken.breedingRate = 672*2; -- 7 Days
		self.animals.chicken.breedingChance = 0;
		self.animals.chicken.deathRate = 96; -- 1 Day
		self.animals.chicken.deathChance = 0;
		self.animals.chicken.deathModifier = 1;
		self.animals.chicken.condition = 100;
		self.animals.chicken.manureMax = 100000;
		self.animals.chicken.states = {};
			self.animals.chicken.states.water = true;
			self.animals.chicken.states.feed = true;
			self.animals.chicken.states.bedding = true;
			self.animals.chicken.states.dirty = false;
			
	self.night_temp = 10;	
	
	livestockManager:loadSettings();	
	g_currentMission.livestockManager = self;
end;

function livestockManager:update(dt)
	
	if g_currentMission:getIsServer() then

		if InputBinding.hasEvent(InputBinding.LM_TOGGLE) then
			self.hud.active =not self.hud.active;
		end;	
		
		self.updateMs = self.updateMs + (dt * g_currentMission.missionInfo.timeScale);
		
		if self.updateMs >= 1200000 then
			
			self.updateMs = self.updateMs - 1200000;
			
			for _,animalType in ipairs(self.animals) do

				local numAnimals = self.animal[animalType].numAnimals[0];
				
				if numAnimals > 0 then				
					
					local isBreeding, isDeteriorating, isCold;
					local hasFeed, hasWater, hasManure, hasBedding;				
					local storageGrass, storageDryGrass, storageSilage, storageForage, storageStraw, storageManure, storageWater;
					local storageWheat, storageBarley, storageOSR, storageSunflower, storageSoybean, storageMaize, storagePotato, storageBeet;

					-- Get Storage
					if animalType == "pig" then
					
						if self.animal[animalType]:getFillLevel(FillUtil.FILLTYPE_WHEAT) > 0 then
							storageWheat = true;
						end;
						
						if self.animal[animalType]:getFillLevel(FillUtil.FILLTYPE_BARLEY) > 0 then
							storageBarley = true;
						end;
						
						if self.animal[animalType]:getFillLevel(FillUtil.FILLTYPE_RAPE) > 0 then
							storageOSR = true;
						end;
						
						if self.animal[animalType]:getFillLevel(FillUtil.FILLTYPE_SUNFLOWER) > 0 then
							storageSunflower = true;
						end;
						
						if self.animal[animalType]:getFillLevel(FillUtil.FILLTYPE_SOYBEAN) > 0 then
							storageSoybean = true;
						end;
						
						if self.animal[animalType]:getFillLevel(FillUtil.FILLTYPE_MAIZE) > 0 then
							storageMaize = true;
						end;
						
						if self.animal[animalType]:getFillLevel(FillUtil.FILLTYPE_POTATO) > 0 then
							storagePotato = true;
						end;
						
						if self.animal[animalType]:getFillLevel(FillUtil.FILLTYPE_SUGARBEET) > 0 then
							storageBeet = true;
						end;
						
					end;
					
					if self.animal[animalType]:getFillLevel(FillUtil.FILLTYPE_GRASS_WINDROW) > 0 then
						storageGrass = true;
					end;
					
					if self.animal[animalType]:getFillLevel(FillUtil.FILLTYPE_DRYGRASS_WINDROW) > 0 then
						storageDryGrass = true;
					end;
					
					if self.animal[animalType]:getFillLevel(FillUtil.FILLTYPE_SILAGE) > 0 then
						storageSilage = true;
					end;
					
					if self.animal[animalType]:getFillLevel(FillUtil.FILLTYPE_POWERFOOD) > 0 then
						storageForage = true;
					end;
					
					if self.animal[animalType]:getFillLevel(FillUtil.FILLTYPE_STRAW) > 0 then
						storageStraw = true;
					end;
					
					if self.animal[animalType].manureFillLevel ~= nil then
						if self.animal[animalType].manureFillLevel >= self.animals[animalType].manureMax then
							storageManure = true;
						end;
					end;
					
					if self.animal[animalType]:getFillLevel(FillUtil.FILLTYPE_WATER) > 0 then
						storageWater = true;
					end;				

					
					isCold = false;
					
					-- Pigs
					if animalType == "pig" then
						
						if storageWater then
							hasWater = true;
							self.animals[animalType].states.water = true;
						else
							hasWater = false;
							self.animals[animalType].states.water = false;
						end;
						
						if storageWheat or storageBarley or storageOSR or storageSunflower or storageSoybean or storageMaize or storagePotato or storageBeet then
							hasFeed = true;
							self.animals[animalType].states.feed = true;
						else
							hasFeed = false;
							self.animals[animalType].states.feed = false;
						end;
						
						if storageStraw then
							hasBedding = true;
							self.animals[animalType].states.bedding = true;
						else
							hasBedding = false;
							self.animals[animalType].states.bedding = false;
						end;
						
						if storageManure then
							hasManure = true;
							self.animals[animalType].states.dirty = true;
						else
							hasManure = false;
							self.animals[animalType].states.dirty = false;
						end;
						
						if hasFeed and hasWater then
							isBreeding = true;
							isDeteriorating = false;
						else
							isBreeding = false;
							isDeteriorating = true;
						end;
						
						if hasBedding and not hasManure then
							isBreeding = true;
						else
							isBreeding = false;
						end;
						
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
					
					-- Cows
					if animalType == "cow" then
						
						if storageWater then
							hasWater = true;
							self.animals[animalType].states.water = true;
						else
							hasWater = false;
							self.animals[animalType].states.water = false;
						end;
						
						if storageGrass or storageDryGrass or storageSilage then
							hasFeed = true;
							self.animals[animalType].states.feed = true;
						else
							hasFeed = false;
							self.animals[animalType].states.feed = false;
						end;
						
						if storageStraw then
							hasBedding = true;
							self.animals[animalType].states.bedding = true;
						else
							hasBedding = false;
							self.animals[animalType].states.bedding = false;
						end;
						
						if storageManure then
							hasManure = true;
							self.animals[animalType].states.dirty = true;
						else
							hasManure = false;
							self.animals[animalType].states.dirty = false;
						end;
						
						if hasFeed and hasWater then
							isBreeding = true;
							isDeteriorating = false;
						else
							isBreeding = false;
							isDeteriorating = true;
						end;
						
						if hasBedding and not hasManure then
							isBreeding = true;
						else
							isBreeding = false;
						end;
						
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
					
					-- Sheep
					if animalType == "sheep" then
						
						if storageWater then
							hasWater = true;
							self.animals[animalType].states.water = true;
						else
							hasWater = false;
							self.animals[animalType].states.water = false;
						end;
						
						if storageGrass or storageDryGrass then
							hasFeed = true;
							self.animals[animalType].states.feed = true;
						else
							hasFeed = false;
							self.animals[animalType].states.feed = false;
						end;
						
						if hasFeed and hasWater then
							isBreeding = true;
							isDeteriorating = false;
						else
							isBreeding = false;
							isDeteriorating = true;
						end;
						
					end;
					
					-- Chickens
					if animalType == "chicken" then
						
						-- Maybe a mod will come out to reactivate chickens feed and water so leave it here.
						--[[
						
						if storageWater then
							hasWater = true;
							self.animals[animalType].states.water = true;
						else
							hasWater = false;
							self.animals[animalType].states.water = false;
						end;
						
						if storageWheat then
							hasFeed = true;
							self.animals[animalType].states.feed = true;
						else
							hasFeed = false;
							self.animals[animalType].states.feed = false;
						end;
						
						]]--
						
						hasFeed = true;
						hasWater = true;
						
						if hasFeed and hasWater then
							isBreeding = true;
							isDeteriorating = false;
						else
							isBreeding = false;
							isDeteriorating = true;
						end;					
						
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
						self.hud.active = true;

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
						self.hud.active = true;
						
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
			end;
		end;
	end;
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
			self.animal[animalType]:addAnimals(-math.ceil(death),0);
		else
				self.animal[animalType]:addAnimals(-1,0);
		end;
	end;
	
	self.animals[animalType].deathChance = 0;
	
end;

function livestockManager:draw()
	
	if g_currentMission:getIsServer() then
	
		if not self.hud.active then return end;

		local posX = g_currentMission.timeBgOverlay.x - self.hud.posX;
		local posY = g_currentMission.timeBgOverlay.y + self.hud.posY;
		
		local posOffsetY = 0;
		local fontSize = 0.013;
		
		setTextBold(true);
		setTextColor(1,1,1,0.5);
		setTextAlignment(RenderText.ALIGN_LEFT);
		renderText(posX + 0.002, posY - posOffsetY, 0.016, "Livestock Manager 2017");
		setTextBold(false);

		posOffsetY = posOffsetY + 0.030;
		
		for _,animalType in ipairs(self.animals) do
			
			if self.animals[animalType].enableBreeding then
				if g_currentMission.husbandries[animalType].animalDesc.birthRatePerDay ~= 0 then
					g_currentMission.husbandries[animalType].animalDesc.birthRatePerDay = 0;
				end;
			end;
			
			local numAnimals = self.animal[animalType].numAnimals[0];

			if numAnimals > 0 then
				setTextBold(true);
				if animalType == "chicken" then renderText(posX, posY - posOffsetY, fontSize, g_i18n:getText("LM_CHICKEN_TITLE") .. round(self.animals[animalType].condition) .. "%"); end;
				if animalType == "sheep" then renderText(posX, posY - posOffsetY, fontSize, g_i18n:getText("LM_SHEEP_TITLE") .. round(self.animals[animalType].condition) .. "%"); end;
				if animalType == "cow" then renderText(posX, posY - posOffsetY, fontSize, g_i18n:getText("LM_COW_TITLE") .. round(self.animals[animalType].condition) .. "%"); end;
				if animalType == "pig" then renderText(posX, posY - posOffsetY, fontSize, g_i18n:getText("LM_PIG_TITLE") .. round(self.animals[animalType].condition) .. "%"); end;
				setTextBold(false);
				posOffsetY = posOffsetY + 0.016;	
				
				if not self.animals[animalType].states.water then
					renderText(posX + 0.010, posY - posOffsetY, fontSize, g_i18n:getText("LM_NEEDS1"));	posOffsetY = posOffsetY + 0.016;
				end;
					
				if not self.animals[animalType].states.feed then
					renderText(posX + 0.010, posY - posOffsetY, fontSize, g_i18n:getText("LM_NEEDS2")); posOffsetY = posOffsetY + 0.016;
				end;
				
				if not self.animals[animalType].states.bedding then
					renderText(posX + 0.010, posY - posOffsetY, fontSize, g_i18n:getText("LM_NEEDS3").." ("..self.night_temp.." C)"); posOffsetY = posOffsetY + 0.016;
				end;
				
				if self.animals[animalType].states.dirty then
					renderText(posX + 0.010, posY - posOffsetY, fontSize, g_i18n:getText("LM_NEEDS4")); posOffsetY = posOffsetY + 0.016;
				end;
					
				if self.animals[animalType].states.water and self.animals[animalType].states.feed and self.animals[animalType].states.bedding and not self.animals[animalType].states.dirty then
					renderText(posX + 0.010, posY - posOffsetY, fontSize, g_i18n:getText("LM_NEEDS0")); posOffsetY = posOffsetY + 0.016;
				end;		
			end;
		end;
		
		if self.debug then
			posOffsetY = posOffsetY + 0.008;
			renderText(posX, posY - posOffsetY, fontSize - 0.003, "Debug Settings"); posOffsetY = posOffsetY + 0.016;
			renderText(posX, posY - posOffsetY, fontSize - 0.003, "Update: "..math.ceil(self.updateMs/60000)); posOffsetY = posOffsetY + 0.016;
			
			renderText(posX, posY - posOffsetY, fontSize - 0.003, "Chickens: "); posOffsetY = posOffsetY + 0.016;
			renderText(posX + 0.004, posY - posOffsetY, fontSize - 0.003, "Breeding Rate: "..math.ceil(self.animals.chicken.breedingRate)); posOffsetY = posOffsetY + 0.016;
			renderText(posX + 0.004, posY - posOffsetY, fontSize - 0.003, "Condition: "..math.ceil(self.animals.chicken.condition)); posOffsetY = posOffsetY + 0.016;
			renderText(posX + 0.004, posY - posOffsetY, fontSize - 0.003, "Breeding Chance: "..math.ceil(self.animals.chicken.breedingChance)); posOffsetY = posOffsetY + 0.016;
			renderText(posX + 0.004, posY - posOffsetY, fontSize - 0.003, "Death Chance: "..math.ceil(self.animals.chicken.deathChance)); posOffsetY = posOffsetY + 0.016;
			
			renderText(posX, posY - posOffsetY, fontSize - 0.003, "Sheep: "); posOffsetY = posOffsetY + 0.016;
			renderText(posX + 0.004, posY - posOffsetY, fontSize - 0.003, "Breeding Rate: "..math.ceil(self.animals.sheep.breedingRate)); posOffsetY = posOffsetY + 0.016;
			renderText(posX + 0.004, posY - posOffsetY, fontSize - 0.003, "Condition: "..math.ceil(self.animals.sheep.condition)); posOffsetY = posOffsetY + 0.016;
			renderText(posX + 0.004, posY - posOffsetY, fontSize - 0.003, "Breeding Chance: "..math.ceil(self.animals.sheep.breedingChance)); posOffsetY = posOffsetY + 0.016;
			renderText(posX + 0.004, posY - posOffsetY, fontSize - 0.003, "Death Chance: "..math.ceil(self.animals.sheep.deathChance)); posOffsetY = posOffsetY + 0.016;
			
			renderText(posX, posY - posOffsetY, fontSize - 0.003, "Cows: "); posOffsetY = posOffsetY + 0.016;
			renderText(posX + 0.004, posY - posOffsetY, fontSize - 0.003, "Breeding Rate: "..math.ceil(self.animals.cow.breedingRate)); posOffsetY = posOffsetY + 0.016;
			renderText(posX + 0.004, posY - posOffsetY, fontSize - 0.003, "Condition: "..math.ceil(self.animals.cow.condition)); posOffsetY = posOffsetY + 0.016;
			renderText(posX + 0.004, posY - posOffsetY, fontSize - 0.003, "Breeding Chance: "..math.ceil(self.animals.cow.breedingChance)); posOffsetY = posOffsetY + 0.016;
			renderText(posX + 0.004, posY - posOffsetY, fontSize - 0.003, "Death Chance: "..math.ceil(self.animals.cow.deathChance)); posOffsetY = posOffsetY + 0.016;
			
			renderText(posX, posY - posOffsetY, fontSize - 0.003, "Pigs: "); posOffsetY = posOffsetY + 0.016;
			renderText(posX + 0.004, posY - posOffsetY, fontSize - 0.003, "Breeding Rate: "..math.ceil(self.animals.pig.breedingRate)); posOffsetY = posOffsetY + 0.016;
			renderText(posX + 0.004, posY - posOffsetY, fontSize - 0.003, "Condition: "..math.ceil(self.animals.pig.condition)); posOffsetY = posOffsetY + 0.016;
			renderText(posX + 0.004, posY - posOffsetY, fontSize - 0.003, "Breeding Chance: "..math.ceil(self.animals.pig.breedingChance)); posOffsetY = posOffsetY + 0.016;
			renderText(posX + 0.004, posY - posOffsetY, fontSize - 0.003, "Death Chance: "..math.ceil(self.animals.pig.deathChance)); posOffsetY = posOffsetY + 0.016;
			
			posOffsetY = posOffsetY + 0.016;
			renderText(posX + 0.004, posY - posOffsetY, fontSize - 0.003, "weatherTemp Day: "..tostring(g_currentMission.environment.weatherTemperaturesDay[1])); posOffsetY = posOffsetY + 0.016;
			renderText(posX + 0.004, posY - posOffsetY, fontSize - 0.003, "weatherTemp Night: "..tostring(g_currentMission.environment.weatherTemperaturesNight[1])); posOffsetY = posOffsetY + 0.016;
		end;

		renderOverlay(self.hud.overlay, posX - 0.005, posY - (posOffsetY), 0.12, (posOffsetY + 0.022));	
	
	end;
end;

function livestockManager:loadSettings()

	if g_currentMission:getIsServer() then
	
		local path = ('%ssavegame%d/'):format(getUserProfileAppPath(), g_careerScreen.currentSavegame.savegameIndex);
		local xml;
		local file = path .. 'livestockManager.xml';
		
		if fileExists(file) then
			xml = loadXMLFile("livestockManagerState", file, "livestockManager");
			
			-- Load Hud Positions
			local hudPosX = getXMLFloat(xml, "livestockManager.hud.posX");
			if hudPosX ~= nil then
				self.hud.posX = hudPosX;
			end;
			
			local hudPosY = getXMLFloat(xml, "livestockManager.hud.posY");
			if hudPosY ~= nil then
				self.hud.posY = hudPosY;
			end;
			
			-- Load Pig Settings
			
			local EnableBreeding = getXMLBool(xml, "livestockManager.pig.enableBreeding");
			if EnableBreeding ~= nil then
				self.animals.pig.enableBreeding = EnableBreeding;
			end;
			
			local EnableDieing = getXMLBool(xml, "livestockManager.pig.enableDieing");
			if EnableDieing ~= nil then
				self.animals.pig.enableDieing = EnableDieing;
			end;
			
			local ChildLimit = getXMLFloat(xml, "livestockManager.pig.childLimit");
			if ChildLimit ~= nil then
				self.animals.pig.childLimit = ChildLimit;
			end;
			
			local BreedingLimit = getXMLFloat(xml, "livestockManager.pig.breedingLimit");
			if BreedingLimit ~= nil then
				self.animals.pig.breedingLimit = BreedingLimit;
			end;
			
			local BreedingRate = getXMLFloat(xml, "livestockManager.pig.breedingDays");
			if BreedingRate ~= nil then
				self.animals.pig.breedingRate = BreedingRate * 96;
			end;
			
			local Condition = getXMLFloat(xml, "livestockManager.pig.condition");
			if Condition ~= nil then
				self.animals.pig.condition = Condition;
			end;
			
			local BreedingChance = getXMLFloat(xml, "livestockManager.pig.breedingTimer");
			if BreedingChance ~= nil then
				self.animals.pig.breedingChance = BreedingChance;
			end;		
			
			local DeathChance = getXMLFloat(xml, "livestockManager.pig.deathTimer");
			if DeathChance ~= nil then
				self.animals.pig.deathChance = DeathChance;
			end;
			
			local ManureMax = getXMLFloat(xml, "livestockManager.pig.manureMax");
			if ManureMax ~= nil then
				self.animals.pig.manureMax = ManureMax;
			end;
			
			-- Load Cow Settings
			
			local EnableBreeding = getXMLBool(xml, "livestockManager.cow.enableBreeding");
			if EnableBreeding ~= nil then
				self.animals.cow.enableBreeding = EnableBreeding;
			end;
			
			local EnableDieing = getXMLBool(xml, "livestockManager.cow.enableDieing");
			if EnableDieing ~= nil then
				self.animals.cow.enableDieing = EnableDieing;
			end;
			
			local ChildLimit = getXMLFloat(xml, "livestockManager.cow.childLimit");
			if ChildLimit ~= nil then
				self.animals.cow.childLimit = ChildLimit;
			end;
			
			local BreedingLimit = getXMLFloat(xml, "livestockManager.cow.breedingLimit");
			if BreedingLimit ~= nil then
				self.animals.cow.breedingLimit = BreedingLimit;
			end;
			
			local BreedingRate = getXMLFloat(xml, "livestockManager.cow.breedingDays");
			if BreedingRate ~= nil then
				self.animals.cow.breedingRate = BreedingRate * 96;
			end;
			
			local Condition = getXMLFloat(xml, "livestockManager.cow.condition");
			if Condition ~= nil then
				self.animals.cow.condition = Condition;
			end;
			
			local BreedingChance = getXMLFloat(xml, "livestockManager.cow.breedingTimer");
			if BreedingChance ~= nil then
				self.animals.cow.breedingChance = BreedingChance;
			end;		
			
			local DeathChance = getXMLFloat(xml, "livestockManager.cow.deathTimer");
			if DeathChance ~= nil then
				self.animals.cow.deathChance = DeathChance;
			end;
			
			local ManureMax = getXMLFloat(xml, "livestockManager.cow.manureMax");
			if ManureMax ~= nil then
				self.animals.cow.manureMax = ManureMax;
			end;
			
			-- Load Sheep Settings
			
			local EnableBreeding = getXMLBool(xml, "livestockManager.sheep.enableBreeding");
			if EnableBreeding ~= nil then
				self.animals.sheep.enableBreeding = EnableBreeding;
			end;
			
			local EnableDieing = getXMLBool(xml, "livestockManager.sheep.enableDieing");
			if EnableDieing ~= nil then
				self.animals.sheep.enableDieing = EnableDieing;
			end;
			
			local ChildLimit = getXMLFloat(xml, "livestockManager.sheep.childLimit");
			if ChildLimit ~= nil then
				self.animals.sheep.childLimit = ChildLimit;
			end;
			
			local BreedingLimit = getXMLFloat(xml, "livestockManager.sheep.breedingLimit");
			if BreedingLimit ~= nil then
				self.animals.sheep.breedingLimit = BreedingLimit;
			end;
			
			local BreedingRate = getXMLFloat(xml, "livestockManager.sheep.breedingDays");
			if BreedingRate ~= nil then
				self.animals.sheep.breedingRate = BreedingRate * 96;
			end;
			
			local Condition = getXMLFloat(xml, "livestockManager.sheep.condition");
			if Condition ~= nil then
				self.animals.sheep.condition = Condition;
			end;		
			
			local BreedingChance = getXMLFloat(xml, "livestockManager.sheep.breedingTimer");
			if BreedingChance ~= nil then
				self.animals.sheep.breedingChance = BreedingChance;
			end;	
			
			local DeathChance = getXMLFloat(xml, "livestockManager.sheep.deathTimer");
			if DeathChance ~= nil then
				self.animals.sheep.deathChance = DeathChance;
			end;


			-- Load Chicken Settings
			
			local EnableBreeding = getXMLBool(xml, "livestockManager.chicken.enableBreeding");
			if EnableBreeding ~= nil then
				self.animals.chicken.enableBreeding = EnableBreeding;
			end;
			
			local EnableDieing = getXMLBool(xml, "livestockManager.chicken.enableDieing");
			if EnableDieing ~= nil then
				self.animals.chicken.enableDieing = EnableDieing;
			end;
			
			local ChildLimit = getXMLFloat(xml, "livestockManager.chicken.childLimit");
			if ChildLimit ~= nil then
				self.animals.chicken.childLimit = ChildLimit;
			end;
			
			local BreedingLimit = getXMLFloat(xml, "livestockManager.chicken.breedingLimit");
			if BreedingLimit ~= nil then
				self.animals.chicken.breedingLimit = BreedingLimit;
			end;
			
			local BreedingRate = getXMLFloat(xml, "livestockManager.chicken.breedingDays");
			if BreedingRate ~= nil then
				self.animals.chicken.breedingRate = BreedingRate * 96;
			end;
			
			local Condition = getXMLFloat(xml, "livestockManager.chicken.condition");
			if Condition ~= nil then
				self.animals.chicken.condition = Condition;
			end;
			
			local BreedingChance = getXMLFloat(xml, "livestockManager.chicken.breedingTimer");
			if BreedingChance ~= nil then
				self.animals.chicken.breedingChance = BreedingChance;
			end;
			
			local DeathChance = getXMLFloat(xml, "livestockManager.chicken.deathTimer");
			if DeathChance ~= nil then
				self.animals.chicken.deathChance = DeathChance;
			end;
		
		end;
	end;
end;

function livestockManager:saveSettings()

	if g_currentMission:getIsServer() then
	
		local path = ('%ssavegame%d/'):format(getUserProfileAppPath(), g_careerScreen.currentSavegame.savegameIndex);
		local xml;
		local file = path .. 'livestockManager.xml';
		
		xml = createXMLFile("livestockManagerState", file, "livestockManager");
		
		setXMLFloat(xml, "livestockManager.hud.posX", g_currentMission.livestockManager.hud.posX);
		setXMLFloat(xml, "livestockManager.hud.posY", g_currentMission.livestockManager.hud.posY);
		
		setXMLBool(xml, "livestockManager.pig.enableBreeding", g_currentMission.livestockManager.animals.pig.enableBreeding);
		setXMLBool(xml, "livestockManager.pig.enableDieing", g_currentMission.livestockManager.animals.pig.enableDieing);
		setXMLInt(xml, "livestockManager.pig.childLimit", g_currentMission.livestockManager.animals.pig.childLimit);
		setXMLInt(xml, "livestockManager.pig.breedingLimit", g_currentMission.livestockManager.animals.pig.breedingLimit);
		setXMLString(xml, "livestockManager.pig.breedingDays", string.format("%.2f",(g_currentMission.livestockManager.animals.pig.breedingRate / 96)));
		setXMLInt(xml, "livestockManager.pig.condition", g_currentMission.livestockManager.animals.pig.condition);
		setXMLInt(xml, "livestockManager.pig.breedingTimer", g_currentMission.livestockManager.animals.pig.breedingChance);
		setXMLInt(xml, "livestockManager.pig.deathTimer", g_currentMission.livestockManager.animals.pig.deathChance);
		setXMLInt(xml, "livestockManager.pig.manureMax", g_currentMission.livestockManager.animals.pig.manureMax);
		
		setXMLBool(xml, "livestockManager.cow.enableBreeding", g_currentMission.livestockManager.animals.cow.enableBreeding);
		setXMLBool(xml, "livestockManager.cow.enableDieing", g_currentMission.livestockManager.animals.cow.enableDieing);
		setXMLInt(xml, "livestockManager.cow.childLimit", g_currentMission.livestockManager.animals.pig.childLimit);
		setXMLInt(xml, "livestockManager.cow.breedingLimit", g_currentMission.livestockManager.animals.cow.breedingLimit);
		setXMLString(xml, "livestockManager.cow.breedingDays", string.format("%.2f",(g_currentMission.livestockManager.animals.cow.breedingRate / 96)));
		setXMLInt(xml, "livestockManager.cow.condition", g_currentMission.livestockManager.animals.cow.condition);
		setXMLInt(xml, "livestockManager.cow.breedingTimer", g_currentMission.livestockManager.animals.cow.breedingChance);
		setXMLInt(xml, "livestockManager.cow.deathTimer", g_currentMission.livestockManager.animals.cow.deathChance);
		setXMLInt(xml, "livestockManager.cow.manureMax", g_currentMission.livestockManager.animals.cow.manureMax);
		
		setXMLBool(xml, "livestockManager.sheep.enableBreeding", g_currentMission.livestockManager.animals.sheep.enableBreeding);
		setXMLBool(xml, "livestockManager.sheep.enableDieing", g_currentMission.livestockManager.animals.sheep.enableDieing);
		setXMLInt(xml, "livestockManager.sheep.childLimit", g_currentMission.livestockManager.animals.sheep.childLimit);
		setXMLInt(xml, "livestockManager.sheep.breedingLimit", g_currentMission.livestockManager.animals.sheep.breedingLimit);
		setXMLString(xml, "livestockManager.sheep.breedingDays", string.format("%.2f",(g_currentMission.livestockManager.animals.sheep.breedingRate / 96)));
		setXMLInt(xml, "livestockManager.sheep.condition", g_currentMission.livestockManager.animals.sheep.condition);
		setXMLInt(xml, "livestockManager.sheep.breedingTimer", g_currentMission.livestockManager.animals.sheep.breedingChance);
		setXMLInt(xml, "livestockManager.sheep.deathTimer", g_currentMission.livestockManager.animals.sheep.deathChance);
		
		setXMLBool(xml, "livestockManager.chicken.enableBreeding", g_currentMission.livestockManager.animals.chicken.enableBreeding);
		setXMLBool(xml, "livestockManager.chicken.enableDieing", g_currentMission.livestockManager.animals.chicken.enableDieing);
		setXMLInt(xml, "livestockManager.chicken.childLimit", g_currentMission.livestockManager.animals.chicken.childLimit);
		setXMLInt(xml, "livestockManager.chicken.breedingLimit", g_currentMission.livestockManager.animals.chicken.breedingLimit);
		setXMLString(xml, "livestockManager.chicken.breedingDays", string.format("%.2f",(g_currentMission.livestockManager.animals.chicken.breedingRate / 96)));
		setXMLInt(xml, "livestockManager.chicken.condition", g_currentMission.livestockManager.animals.chicken.condition);
		setXMLInt(xml, "livestockManager.chicken.breedingTimer", g_currentMission.livestockManager.animals.chicken.breedingChance);
		setXMLInt(xml, "livestockManager.chicken.deathTimer", g_currentMission.livestockManager.animals.chicken.deathChance);
		
		saveXMLFile(xml);
		delete(xml);
		
	end;
end;
g_careerScreen.saveSavegame = Utils.appendedFunction(g_careerScreen.saveSavegame, livestockManager.saveSettings);

function round(num, idp)
	if Utils.getNoNil(num, 0) > 0 then
		local mult = 10^(idp or 0);
		return math.floor(num * mult + 0.5) / mult;
	else 
		return 0;
	end;
end;

function livestockManager:keyEvent(unicode, sym, modifier, isDown)end;
function livestockManager:mouseEvent(posX, posY, isDown, isUp, button)end;
function livestockManager:deleteMap()end;


-- LivestockManagerHudY
--addConsoleCommand("LivestockManagerHudY", "LivestockManagerHudY", "LivestockManagerHudY", livestockManager);
function livestockManager:LivestockManagerHudY(value)
	if value ~= nil then
		livestockManager.hud.posY = tonumber(value);
		print("LivestockManagerHudY: " .. tostring(value));
	else
		print("LivestockManagerHudY: " .. tostring(livestockManager.hud.posY));
	end;
end;

-- LivestockManagerHudX
--addConsoleCommand("LivestockManagerHudX", "LivestockManagerHudX", "LivestockManagerHudX", livestockManager);
function livestockManager:LivestockManagerHudX(value)
	if value ~= nil then
		livestockManager.hud.posX = tonumber(value);
		print("LivestockManagerHudX: " .. tostring(value));
	else
		print("LivestockManagerHudX: " .. tostring(livestockManager.hud.posX));
	end;
end;
