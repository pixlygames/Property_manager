Property = {
    property_id = nil,
    propertyData = nil,
    playersInside = nil,   -- src
    playersInGarden = nil,   -- src
    playersDoorbell = nil, -- src

    raiding = false,
}
Property.__index = Property

function Property:new(propertyData)
    local self = setmetatable({}, Property)

    self.property_id = tostring(propertyData.property_id)
    self.propertyData = propertyData

    self.playersInside = {}
    self.playersInGarden = {}
    self.playersDoorbell = {}

    local stashName = ("property_%s"):format(propertyData.property_id)
    local stashConfig = Config.Shells[propertyData.shell].stash

    for k, v in ipairs(propertyData.furnitures) do
        if v.type == 'storage' then
            Framework[Config.Inventory].RegisterInventory(k == 1 and stashName or stashName..v.id, 'Property: ' ..  (propertyData.street or propertyData.apartment or 'Unknown') .. ' #'.. propertyData.property_id or propertyData.apartment or stashName, stashConfig)
        end
    end

    return self
end

function Property:PlayerEnter(src)
    local _src = tostring(src)
    local isMlo = self.propertyData.shell == 'mlo'
    local isIpl = self.propertyData.apartment and Config.Apartments[self.propertyData.apartment].interior

    self.playersInside[_src] = true

    if not isMlo then
        TriggerClientEvent('qb-weathersync:client:DisableSync', src)
    end
    print(src, self.property_id)
    TriggerClientEvent('pmanager:client:enterProperty', src, self.property_id, isMlo, self.propertyData)

    if next(self.playersDoorbell) then
        TriggerClientEvent("pmanager:client:updateDoorbellPool", src, self.property_id, self.playersDoorbell)
        if self.playersDoorbell[_src] then
            self.playersDoorbell[_src] = nil
        end
    end

    local citizenid = GetCitizenid(src)

    if self:CheckForAccess(citizenid) then
        local Player = QBCore.Functions.GetPlayer(src)
        local insideMeta = Player.PlayerData.metadata["inside"]

        insideMeta.property_id = self.property_id
        Player.Functions.SetMetaData("inside", insideMeta)
    end

    if not isMlo or isIpl then
        local bucket = tonumber(self.property_id) -- because the property_id is a string
        QBCore.Functions.SetPlayerBucket(src, bucket)
    end
end

function Property:PlayerLeave(src)
    local _src = tostring(src)
    self.playersInside[_src] = nil

    TriggerClientEvent('qb-weathersync:client:EnableSync', src)

    local citizenid = GetCitizenid(src)

    if self:CheckForAccess(citizenid) then
        local Player = QBCore.Functions.GetPlayer(src)
        local insideMeta = Player.PlayerData.metadata["inside"]

        insideMeta.property_id = nil
        Player.Functions.SetMetaData("inside", insideMeta)
    end

    QBCore.Functions.SetPlayerBucket(src, 0)
end

function Property:CheckForAccess(citizenid)
    if self.propertyData.owner == citizenid then return true end
    return lib.table.contains(self.propertyData.has_access, citizenid)
end

function Property:AddToDoorbellPoolTemp(src)
    local _src = tostring(src)

    local name = GetCharName(src)

    self.playersDoorbell[_src] = {
        src = src,
        name = name
    }

    for src, _ in pairs(self.playersInside) do
        local targetSrc = tonumber(src)

        Framework[Config.Notify].Notify(targetSrc, "Someone is at the door.", "info")
        TriggerClientEvent("pmanager:client:updateDoorbellPool", targetSrc, self.property_id, self.playersDoorbell)
    end

    Framework[Config.Notify].Notify(src, "You rang the doorbell. Just wait...", "info")

    SetTimeout(10000, function()
        if self.playersDoorbell[_src] then
            self.playersDoorbell[_src] = nil
            Framework[Config.Notify].Notify(src, "No one answered the door.", "error")
        end

        for src, _ in pairs(self.playersInside) do
            local targetSrc = tonumber(src)

            TriggerClientEvent("pmanagerg:client:updateDoorbellPool", targetSrc, self.property_id, self.playersDoorbell)
        end
    end)
end

function Property:RemoveFromDoorbellPool(src)
    local _src = tostring(src)

    if self.playersDoorbell[_src] then
        self.playersDoorbell[_src] = nil
    end

    for src, _ in pairs(self.playersInside) do
        local targetSrc = tonumber(src)

        TriggerClientEvent("pmanager:client:updateDoorbellPool", targetSrc, self.property_id, self.playersDoorbell)
    end
end



function Property:UpdateDescription(data)
    local description = data.description
    local realtorSrc = data.realtorSrc

    if self.propertyData.description == description then return end

    self.propertyData.description = description

    MySQL.update("UPDATE properties SET description = @description WHERE property_id = @property_id", {
        ["@description"] = description,
        ["@property_id"] = self.property_id
    })

    TriggerClientEvent("pmanager:client:updateProperty", -1, "UpdateDescription", self.property_id, description)

    Framework[Config.Logs].SendLog("**Changed Description** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc))

    Debug("Changed Description of property with id: " .. self.property_id, "by: " .. GetPlayerName(realtorSrc))
end

function Property:UpdatePrice(data)
    local price = data.price
    local realtorSrc = data.realtorSrc

    if self.propertyData.price == price then return end

    self.propertyData.price = price

    MySQL.update("UPDATE properties SET price = @price WHERE property_id = @property_id", {
        ["@price"] = price,
        ["@property_id"] = self.property_id
    })

    TriggerClientEvent(pmanager:client:updateProperty", -1, "UpdatePrice", self.property_id, price)

    Framework[Config.Logs].SendLog("**Changed Price** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc))

    Debug("Changed Price of property with id: " .. self.property_id, "by: " .. GetPlayerName(realtorSrc))
end

function Property:UpdateForSale(data)
    local forsale = data.forsale
    local realtorSrc = data.realtorSrc

    self.propertyData.for_sale = forsale

    MySQL.update("UPDATE properties SET for_sale = @for_sale WHERE property_id = @property_id", {
        ["@for_sale"] = forsale and 1 or 0,
        ["@property_id"] = self.property_id
    })

    TriggerClientEvent("pmanager:client:updateProperty", -1, "UpdateForSale", self.property_id, forsale)

    Framework[Config.Logs].SendLog("**Changed For Sale** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc))

    Debug("Changed For Sale of property with id: " .. self.property_id, "by: " .. GetPlayerName(realtorSrc))
end

function Property:UpdateShell(data)
    local shell = data.shell
    local realtorSrc = data.realtorSrc

    if self.propertyData.shell == shell then return end

    self.propertyData.shell = shell

    MySQL.update("UPDATE properties SET shell = @shell WHERE property_id = @property_id", {
        ["@shell"] = shell,
        ["@property_id"] = self.property_id
    })

    TriggerClientEvent("pmanager:client:updateProperty", -1, "UpdateShell", self.property_id, shell)

    Framework[Config.Logs].SendLog("**Changed Shell** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc))

    Debug("Changed Shell of property with id: " .. self.property_id, "by: " .. GetPlayerName(realtorSrc))
end

function Property:addMloDoorsAccess(citizenid)
    if self.propertyData.shell ~= 'mlo' then return end

    if DoorResource == 'ox' then
        local ox_doorlock = exports.ox_doorlock
        for i=1 , self.propertyData.door_data.count do
            local door = ox_doorlock:getDoorFromName(('ps_mloproperty%s_%s'):format(self.property_id, i))
            local data = door.characters or {}
            table.insert(data, citizenid)
            ox_doorlock:editDoor(door.id, {characters = data})
        end
    else
        local qb_doorlock = exports['qb-doorlock']
        for i=1 , self.propertyData.door_data.count do
            local id = ('ps_mloproperty%s_%s'):format(self.property_id, i)
            local door = qb_doorlock:getDoor(id)
            local data = door.authorizedCitizenIDs or {}
            data[citizenid] = true
            qb_doorlock:updateDoor(id, {authorizedCitizenIDs = data})
        end
    end
end

function Property:removeMloDoorsAccess(citizenid)
    if self.propertyData.shell ~= 'mlo' then return end

    if DoorResource == 'ox' then
        local ox_doorlock = exports.ox_doorlock
        for i = 1, self.propertyData.door_data.count do
            local door = ox_doorlock:getDoorFromName(('ps_mloproperty%s_%s'):format(self.property_id, i))
            local data = door.characters or {}
            for index, id in ipairs(data) do
                if id == citizenid then
                    table.remove(data, index)
                    break
                end
            end
            ox_doorlock:editDoor(door.id, {characters = data})
        end
    else
        local qb_doorlock = exports['qb-doorlock']
        for i = 1, self.propertyData.door_data.count do
            local id = ('ps_mloproperty%s_%s'):format(self.property_id, i)
            local door = qb_doorlock:getDoor(id)
            local data = door.authorizedCitizenIDs or {}
            data[citizenid] = nil
            qb_doorlock:updateDoor(id, {authorizedCitizenIDs = data})
        end
    end
end

function Property:UpdateOwner(data)
    local targetSrc = data.targetSrc
    local realtorSrc = data.realtorSrc

    if not realtorSrc then Debug("No Realtor Src found") return end
    if not targetSrc then Debug("No Target Src found") return end

    local previousOwner = self.propertyData.owner

    local targetPlayer  = QBCore.Functions.GetPlayer(tonumber(targetSrc))
    if not targetPlayer then return end

    local PlayerData = targetPlayer.PlayerData
    local bank = PlayerData.money.bank
    local citizenid = PlayerData.citizenid

    self:addMloDoorsAccess(citizenid)
    if self.propertyData.shell == 'mlo' and DoorResource == 'qb' then
        Framework[Config.Notify].Notify(targetSrc, "Go far away and come back for the door to update and open/close.", "error")
    end

    if self.propertyData.owner == citizenid then
        Framework[Config.Notify].Notify(targetSrc, "You already own this property", "error")
        Framework[Config.Notify].Notify(realtorSrc, "Client already owns this property", "error")
        return
    end

    self.propertyData.owner = citizenid

    MySQL.update("UPDATE properties SET owner_citizenid = @owner_citizenid, for_sale = @for_sale WHERE property_id = @property_id", {
        ["@owner_citizenid"] = citizenid,
        ["@for_sale"] = 0,
        ["@property_id"] = self.property_id
    })

    self.propertyData.furnitures = {} -- to be fetched on enter

    TriggerClientEvent("pmanager:client:updateProperty", -1, "UpdateOwner", self.property_id, citizenid)
    TriggerClientEvent("pmanager:client:updateProperty", -1, "UpdateForSale", self.property_id, 0)
    
    Framework[Config.Logs].SendLog("**House Bought** by: **"..PlayerData.charinfo.firstname.." "..PlayerData.charinfo.lastname.."** for $"..self.propertyData.price.." from **"..realtor.PlayerData.charinfo.firstname.." "..realtor.PlayerData.charinfo.lastname.."** !")

    Framework[Config.Notify].Notify(targetSrc, "You have bought the property for $"..self.propertyData.price, "success")
    Framework[Config.Notify].Notify(realtorSrc, "Client has bought the property for $"..self.propertyData.price, "success")
end

function Property:UpdateImgs(data)
    local imgs = data.imgs
    local realtorSrc = data.realtorSrc

    self.propertyData.imgs = imgs

    MySQL.update("UPDATE properties SET extra_imgs = @extra_imgs WHERE property_id = @property_id", {
        ["@extra_imgs"] = json.encode(imgs),
        ["@property_id"] = self.property_id
    })

    TriggerClientEvent("pmanager:client:updateProperty", -1, "UpdateImgs", self.property_id, imgs)

    Framework[Config.Logs].SendLog("**Changed Images** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc))

    Debug("Changed Imgs of property with id: " .. self.property_id, "by: " .. GetPlayerName(realtorSrc))
end


function Property:UpdateDoor(data)
    local door = data.door

    if not door then return end
    local realtorSrc = data.realtorSrc

    local newDoor = {
        x = math.floor(door.x * 10000) / 10000,
        y = math.floor(door.y * 10000) / 10000,
        z = math.floor(door.z * 10000) / 10000,
        h = math.floor(door.h * 10000) / 10000,
        length = door.length or 1.5,
        width = door.width or 2.2,
        locked = door.locked or false,
    }

    self.propertyData.door_data = newDoor

    self.propertyData.street = data.street
    self.propertyData.region = data.region


    MySQL.update("UPDATE properties SET door_data = @door, street = @street, region = @region WHERE property_id = @property_id", {
        ["@door"] = json.encode(newDoor),
        ["@property_id"] = self.property_id,
        ["@street"] = data.street,
        ["@region"] = data.region
    })

    TriggerClientEvent("pmanager:client:updateProperty", -1, "UpdateDoor", self.property_id, newDoor, data.street, data.region)

    Framework[Config.Logs].SendLog("**Changed Door** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc))

    Debug("Changed Door of property with id: " .. self.property_id, "by: " .. GetPlayerName(realtorSrc))
end

function Property:UpdateHas_access(data)
    local has_access = data or {}

    self.propertyData.has_access = has_access

    MySQL.update("UPDATE properties SET has_access = @has_access WHERE property_id = @property_id", {
        ["@has_access"] = json.encode(has_access), --Array of cids
        ["@property_id"] = self.property_id
    })

    TriggerClientEvent("pmanager:client:updateProperty", -1, "UpdateHas_access", self.property_id, has_access)

    Debug("Changed Has Access of property with id: " .. self.property_id)
end


function Property:UpdateApartment(data)
    local apartment = data.apartment
    local realtorSrc = data.realtorSrc
    local targetSrc = data.targetSrc

    self.propertyData.apartment = apartment

    MySQL.update("UPDATE properties SET apartment = @apartment WHERE property_id = @property_id", {
        ["@apartment"] = apartment,
        ["@property_id"] = self.property_id
    })

    Framework[Config.Notify].Notify(realtorSrc, "Changed Apartment of property with id: " .. self.property_id .." to ".. apartment, "success")

    Framework[Config.Notify].Notify(targetSrc, "Changed Apartment to " .. apartment, "success")

    Framework[Config.Logs].SendLog("**Changed Apartment** with id: " .. self.property_id .. " by: **" .. GetPlayerName(realtorSrc) .. "** for **" .. GetPlayerName(targetSrc) .."**")

    TriggerClientEvent("pmanager:client:updateProperty", -1, "UpdateApartment", self.property_id, apartment)

    Debug("Changed Apartment of property with id: " .. self.property_id, "by: " .. GetPlayerName(realtorSrc))
end

function Property:DeleteProperty(data)
    local realtorSrc = data.realtorSrc
    local propertyid = self.property_id
    local realtorName = GetPlayerName(realtorSrc)

    MySQL.Async.execute("DELETE FROM properties WHERE property_id = @property_id", {
        ["@property_id"] = propertyid
    }, function (rowsChanged)
        if rowsChanged > 0 then
            Debug("Deleted property with id: " .. propertyid, "by: " .. realtorName)
        end
    end)

    TriggerClientEvent("pmanager:client:removeProperty", -1, propertyid)

    Framework[Config.Notify].Notify(realtorSrc, "Property with id: " .. propertyid .." has been removed.", "info")

    Framework[Config.Logs].SendLog("**Property Deleted** with id: " .. propertyid .. " by: " .. realtorName)

    PropertiesTable[propertyid] = nil
    self = nil

    Debug("Deleted property with id: " .. propertyid, "by: " .. realtorName)
end

function Property.Get(property_id)
    return PropertiesTable[tostring(property_id)]
end

RegisterNetEvent('pmanager:server:enterGarden', function (property_id)
    local src = source
    local property = Property.Get(property_id)

    if not property then
        Debug("Properties returned", json.encode(PropertiesTable, {indent = true}))
        return
    end

    property.playersInGarden[tostring(src)] = true
end)

RegisterNetEvent('pmanager:server:enterProperty', function (property_id, spawn)
    local src = source
    Debug("Player is trying to enter property", property_id)

    local property = Property.Get(property_id)
    if not property then
        Debug("Properties returned", json.encode(PropertiesTable, {indent = true}))
        return
    end

    local citizenid = GetCitizenid(src)

    if property:CheckForAccess(citizenid) then
        Debug("Player has access to property")
        if spawn == 'spawn' then
            TriggerClientEvent("pmanager:client:enterProperty", src, property_id, spawn)
        else
            property:PlayerEnter(src)
        end
        Debug("Player entered property")
        return
    end

    local ringDoorbellConfirmation = lib.callback.await('pmanager:cb:ringDoorbell', src)
    if ringDoorbellConfirmation == "confirm" then
        property:AddToDoorbellPoolTemp(src)
        Debug("Ringing doorbell")
        return
    end
end)


RegisterNetEvent("pmanager:server:removeAccess", function(property_id, citizenidToRemove)
    local src = source

    local citizenid = GetCitizenid(src)
    local property = Property.Get(property_id)
    if not property then return end

    if not property.propertyData.owner == citizenid then
        -- hacker ban or something
        Framework[Config.Notify].Notify(src, "You are not the owner of this property!", "error")
        return
    end

    local has_access = property.propertyData.has_access

    if property:CheckForAccess(citizenidToRemove) then
        for i = 1, #has_access do
            if has_access[i] == citizenidToRemove then
                table.remove(has_access, i)
                break
            end
        end 

        property:removeMloDoorsAccess(citizenidToRemove)
        property:UpdateHas_access(has_access)

        local playerToAdd = QBCore.Functions.GetPlayerByCitizenId(citizenidToRemove) or QBCore.Functions.GetOfflinePlayerByCitizenId(citizenidToRemove)
        local removePlayerData = playerToAdd.PlayerData
        local srcToRemove = removePlayerData.source

        Framework[Config.Notify].Notify(src, "You removed access from " .. removePlayerData.charinfo.firstname .. " " .. removePlayerData.charinfo.lastname, "success")

        if srcToRemove then
            Framework[Config.Notify].Notify(srcToRemove, "You lost access to " .. (property.propertyData.street or property.propertyData.apartment) .. " " .. property.property_id, "error")
        end
    else
        Framework[Config.Notify].Notify(src, "This person does not have access to this property!", "error")
    end
end)

lib.callback.register("pmanager:cb:getPlayersWithAccess", function (source, property_id)
    local src = source
    local citizenidSrc = GetCitizenid(src)
    local property = Property.Get(property_id)
    
    if not property then return end
    if property.propertyData.owner ~= citizenidSrc then return end

    local withAccess = {}
    local has_access = property.propertyData.has_access

    for i = 1, #has_access do
        local citizenid = has_access[i]
        local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid) or QBCore.Functions.GetOfflinePlayerByCitizenId(citizenid)
        if Player then
            withAccess[#withAccess + 1] = {
                citizenid = citizenid,
                name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
            }
        end
    end

    return withAccess
end)

lib.callback.register('pmanager:cb:getPropertyInfo', function (source, property_id)
    local src = source
    local property = Property.Get(property_id)

    if not property then return end

    
    local PlayerData = GetPlayerData(src)
    local job = PlayerData.job
    local jobName = job.name
    local onDuty = job.onduty

    if RealtorJobs[jobName] and not onDuty then return end

    local data = {}

    local ownerPlayer, ownerName

    local ownerCid = property.propertyData.owner
    if ownerCid then
        ownerPlayer = QBCore.Functions.GetPlayerByCitizenId(ownerCid) or QBCore.Functions.GetOfflinePlayerByCitizenId(ownerCid)
        ownerName = ownerPlayer.PlayerData.charinfo.firstname .. " " .. ownerPlayer.PlayerData.charinfo.lastname
    else
        ownerName = "No Owner"
    end

    data.owner = ownerName
    data.street = property.propertyData.street
    data.region = property.propertyData.region
    data.description = property.propertyData.description
    data.for_sale = property.propertyData.for_sale
    data.price = property.propertyData.price
    data.shell = property.propertyData.shell
    data.property_id = property.property_id

    return data
end)

RegisterNetEvent('pmanager:server:resetMetaData', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local insideMeta = Player.PlayerData.metadata["inside"]

    insideMeta.property_id = nil
    Player.Functions.SetMetaData("inside", insideMeta)
end)
