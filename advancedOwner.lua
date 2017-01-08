--
-- advancedOwner
--
-- Version 1.0
-- Author: Ian898
-- Date: 07/01/2017

advancedOwner = {}

function advancedOwner.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Motorized, specializations)
end

function advancedOwner:load(savegame)
	self.advancedOwner = {};
	self.advancedOwner.owner = "";
	
	if savegame ~= nil then
	
		local vehicleOwner = Utils.getNoNil(getXMLString(savegame.xmlFile, savegame.key.."#owner"), "")
		
		if vehicleOwner ~= nil then
			self.advancedOwner.owner = vehicleOwner
			self.nonTabbable = (self.advancedOwner.owner ~= "" and self.advancedOwner.owner ~= g_currentMission.users[g_currentMission.playerUserId].nickname)
		end
	end

	VehicleEnterRequestEvent.run = advancedOwner.overrideVehicleEnterRequestEvent
end

function advancedOwner:update(dt)
	
	if self.advancedOwner == nil then
		self.advancedOwner = {}
	end
	
	if not self.advancedOwner.initialize then
		g_client:getServerConnection():sendEvent(advancedOwnerRefreshEvent:new(self))		
		self.advancedOwner.initialize = true
	end
	
	if g_currentMission:getIsServer() or g_currentMission.isMasterUser then
		if self.isActive then
			if self:getIsActiveForInput() then
				if InputBinding.hasEvent(InputBinding.advancedOwner) then
						
					local user = ""
					
					if self.advancedOwner.owner ~= self.controllerName then
						user = self.controllerName
					end
					
					g_client:getServerConnection():sendEvent(advancedOwnerEvent:new(self, user))
				end
			end
		end
		
		if self == g_currentMission.controlledVehicle then
			if self.isActive then
				if self.advancedOwner.owner == "" then
					g_currentMission:addHelpButtonText("Owner:".." ".."Everyone", InputBinding.advancedOwner)
				else
					g_currentMission:addHelpButtonText("Owner:".." "..Utils.getNoNil(self.advancedOwner.owner, "Everyone"), InputBinding.advancedOwner)
				end
			end
		end
	end	
end

function advancedOwner:overrideVehicleEnterRequestEvent(connection)
	
	local allowEnter = false
	
	if self.object.advancedOwner == nil then
		allowEnter = true
	else
		allowEnter = (self.object == nil or self.object.advancedOwner.owner == nil or self.object.advancedOwner.owner == self.controllerName or self.object.advancedOwner.owner == "" )
	end
	
	if allowEnter == true then		
		if self.object.isControlled == false then			
			self.object:setOwner(connection)
			g_server:broadcastEvent(VehicleEnterResponseEvent:new(self.objectId, false, self.controllerName, self.playerIndex, self.playerColorIndex), true, connection, self.object)
			connection:sendEvent(VehicleEnterResponseEvent:new(self.objectId, true, self.controllerName, self.playerIndex, self.playerColorIndex))
			if not self.object.isEntered then			
				self.object:enterVehicle(false, playerIndex, playerColorIndex)
			end
		end
	else
		g_currentMission:showBlinkingWarning(string.format("This vehicle is owned by %s!", self.object.advancedOwner.owner), 3000);
	end
end

function advancedOwner:draw()end

function advancedOwner:getSaveAttributesAndNodes()
	local vehicleOwner = 'owner="' .. Utils.getNoNil(self.advancedOwner.owner) .. '"'
    return vehicleOwner, nil
end

function advancedOwner:delete()end
function advancedOwner:readStream(streamId, connection)end
function advancedOwner:readUpdateStream(streamId, timestamp, connection)end
function advancedOwner:writeStream(streamId, connection)end
function advancedOwner:writeUpdateStream(streamId, connection, dirtyMask)end
function advancedOwner:mouseEvent(posX, posY, isDown, isUp, button)end
function advancedOwner:keyEvent(unicode, sym, modifier, isDown)end
function advancedOwner:updateTick(dt)end

-- Events

advancedOwnerEvent = {};
advancedOwnerEvent_mt = Class(advancedOwnerEvent, Event);
InitEventClass(advancedOwnerEvent, "advancedOwnerEvent");

function advancedOwnerEvent:emptyNew()
	local self = Event:new(advancedOwnerEvent_mt);
	return self;
end;

function advancedOwnerEvent:new(vehicle, owner)

	local self = advancedOwnerEvent:emptyNew();
	self.vehicle = vehicle;
	self.owner = owner;
  
	return self;
end;

function advancedOwnerEvent:readStream(streamId, connection)

	local id = streamReadInt32(streamId)
	self.vehicle = networkGetObject(id);
	self.owner = streamReadString(streamId);
 
	self:run(connection);
end;

function advancedOwnerEvent:writeStream(streamId, connection)

	local id = networkGetObjectId(self.vehicle)
	streamWriteInt32(streamId, id);
	streamWriteString(streamId, Utils.getNoNil(self.owner, ""));
end;

function advancedOwnerEvent:run(connection)
	
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, true);
	else
		if self.vehicle ~= nil then

			if self.vehicle.advancedOwner == nil then
				self.vehicle.advancedOwner = {};
				self.vehicle.advancedOwner.owner = "";
			end;
			
			if self.vehicle.advancedOwner.owner == nil then
				self.vehicle.advancedOwner.owner = "";
			end;

			self.vehicle.advancedOwner.owner = self.owner;

			if self.vehicle.nonTabbable ~= nil then
				self.vehicle.nonTabbable = (self.vehicle.advancedOwner.owner ~= "" and self.vehicle.advancedOwner.owner ~= g_currentMission.users[g_currentMission.playerUserId].nickname);
			end;
		end;
	end;
end;

advancedOwnerRefreshEvent = {};
advancedOwnerRefreshEvent_mt = Class(advancedOwnerRefreshEvent, Event);
InitEventClass(advancedOwnerRefreshEvent, "advancedOwnerRefreshEvent");

function advancedOwnerRefreshEvent:emptyNew()
	local self = Event:new(advancedOwnerRefreshEvent_mt);
	return self;
end;

function advancedOwnerRefreshEvent:new(vehicle)

	local self = advancedOwnerRefreshEvent:emptyNew();
	self.vehicle = vehicle;
  
	return self;
end;

function advancedOwnerRefreshEvent:readStream(streamId, connection)

	local id = streamReadInt32(streamId);
	self.vehicle = networkGetObject(id);
 
	self:run(connection);
end;

function advancedOwnerRefreshEvent:writeStream(streamId, connection)

	local id = networkGetObjectId(self.vehicle);
	
	streamWriteInt32(streamId, id);
	streamWriteString(streamId, Utils.getNoNil(self.owner, ""));
end;

function advancedOwnerRefreshEvent:run(connection)
	if not connection:getIsServer() then
		g_client:getServerConnection():sendEvent(advancedOwnerEvent:new(self.vehicle, self.vehicle.advancedOwner.owner))
	end;
end;