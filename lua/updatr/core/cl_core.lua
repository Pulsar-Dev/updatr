local net_ReadString = net.ReadString
local net_ReadUInt = net.ReadUInt
local net_ReadData = net.ReadData
local util_Decompress = util.Decompress
local util_JSONToTable = util.JSONToTable
local string_Explode = string.Explode

Updatr = Updatr or {}
Updatr.RecievedData = Updatr.RecievedData or {}

function Updatr.ApplyUpdates(tbl, updates)
    for key, value in pairs(updates) do
        if value == "Updatr.REMOVEDKEYVALUE" then
            tbl[key] = nil
        elseif type(value) == "table" then
            if not tbl then
                Updatr.DebugLog("Table is missing! This is bad! Updates:")
                if PulsarLib.DevelopmentMode or Updatr.Debug then
                    PrintTable(updates)
                end
            end

            if not tbl[key] then
                tbl[key] = value
            else
                Updatr.ApplyUpdates(tbl[key], value)
            end
        else
            tbl[key] = value
        end
    end

    Updatr.DebugLog("Applied updates to table")
end

net.Receive("Updatr.TableData", function()
    local tableName = net_ReadString()
    local dataLength = net_ReadUInt(32)
    local compressedData = net_ReadData(dataLength)
    local serializedTable = util_Decompress(compressedData)
    local t = util_JSONToTable(serializedTable)

    local path = string_Explode(".", tableName)
    local tableToUpdate = _G
    for i = 1, #path - 1 do
        tableToUpdate = tableToUpdate[path[i]]
    end

    tableToUpdate[path[#path]] = t
    Updatr.DebugLog("Received table data for " .. tableName)

    hook.Run("Updatr.TableDataReceived", tableName)
    Updatr.RecievedData[tableName] = t
end)


net.Receive("Updatr.TableUpdates", function()
    local tableName = net_ReadString()
    local dataLength = net_ReadUInt(32)
    local compressedData = net_ReadData(dataLength)
    local serializedUpdates = util_Decompress(compressedData)
    local updates = util_JSONToTable(serializedUpdates)

    local path = string_Explode(".", tableName)
    local tableToUpdate = _G
    for i = 1, #path - 1 do
        tableToUpdate = tableToUpdate[path[i]]
    end

    Updatr.ApplyUpdates(tableToUpdate[path[#path]], updates)
    Updatr.DebugLog("Received table updates for " .. tableName)
    if PulsarLib.DevelopmentMode or Updatr.Debug then
        Updatr.DebugLog("Updatr Table Debug: ")
        PrintTable(tableToUpdate)
    end

    hook.Run("Updatr.TableUpdatesReceived", tableName)
end)
