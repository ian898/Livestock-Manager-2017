livestockManagerEvent = {};

livestockManagerEvent.REGULAR_UPDATES = 0;
livestockManagerEvent.DEBUG_UPDATES = 1;
livestockManagerEvent.NUM_BITS = 1;

livestockManagerEvent_mt = Class(livestockManagerEvent, Event);

InitEventClass(livestockManagerEvent, "livestockManagerEvent");

function livestockManagerEvent:emptyNew()
    local self = Event:new(livestockManagerEvent_mt);
    return self;
end;

function livestockManagerEvent:new(eventType, animalType, water, feed, bedding, dirty, condition)
    local self = livestockManagerEvent:emptyNew()
	
	self.eventType = eventType;
	self.animalType = animalType;
	self.water = water;
	self.feed = feed;
	self.bedding = bedding;
	self.dirty = dirty;
	self.condition = condition;
	
    return self;
end;

-- Something to note for read and write stream is the order which they follow
-- like for example eventType is the 1th in both functions same goes for condition while it being last but you get where Im going
-- the reason for this is because the data are received in the same order it was sent so that means its vital that you keep that order or problems will be at your door!
-- It will put the whole MP stream out of synch!

function livestockManagerEvent:readStream(streamId, connection)
	self.eventType = streamReadUIntN(streamId, livestockManagerEvent.NUM_BITS);
	
	self.animalType = streamReadString(streamId);
	self.water = streamReadBool(streamId);
	self.feed = streamReadBool(streamId);
	self.bedding = streamReadBool(streamId);
	self.dirty = streamReadBool(streamId);
	self.condition = streamReadFloat32(streamId);
	
	if self.eventType == livestockManagerEvent.DEBUG_UPDATES then
		-- here you could read data which you want to debug like deathChance or breedingChance etc
	end;
	
	self:run(connection);
end;

function livestockManagerEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.eventType, livestockManagerEvent.NUM_BITS);
	
	streamWriteString(streamId, self.animalType);
	streamWriteBool(streamId, self.water);
	streamWriteBool(streamId, self.feed);
	streamWriteBool(streamId, self.bedding);
	streamWriteBool(streamId, self.dirty);
	streamWriteFloat32(streamId, self.condition);
	
	if self.eventType == livestockManagerEvent.DEBUG_UPDATES then
		-- same description as in read function
	end;
	
	if livestockManager.DEBUG then
		-- print(" Writing data from server to clients");
		print("  type: " .. tostring(self.animalType));
		print("  water: " .. tostring(self.water));
		print("  bedding: " .. tostring(self.bedding));
		print("  dirty: " .. tostring(self.dirty));
		print("  condition: " .. tostring(self.condition));
	end;
end;

function livestockManagerEvent:run(connection)
	if connection:getIsServer() then -- This one is reversed, meaning if true then we are client
		g_currentMission.livestockManager.animals[self.animalType].states.water = self.water;
		g_currentMission.livestockManager.animals[self.animalType].states.feed = self.feed;
		g_currentMission.livestockManager.animals[self.animalType].states.bedding = self.bedding;
		g_currentMission.livestockManager.animals[self.animalType].states.dirty = self.dirty;
		g_currentMission.livestockManager.animals[self.animalType].condition = self.condition;
		
		if self.eventType == livestockManagerEvent.DEBUG_UPDATES then
			print("Hello dev user " .. g_currentMission.missionInfo.playerName);
		end;
		
		if livestockManager.DEBUG then
			print("We are receiving data from livestockManagerEvent");
			print("  type: " .. tostring(self.animalType));
			print("  water: " .. tostring(self.water));
			print("  bedding: " .. tostring(self.bedding));
			print("  dirty: " .. tostring(self.dirty));
			print("  condition: " .. tostring(self.condition));
		end;
	else
		print("Error: livestockManagerEvent are an server -> client event");
	end;
end;