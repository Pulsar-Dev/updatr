local net_ReadString = net.ReadString
local net_ReadUInt = net.ReadUInt
local net_ReadData = net.ReadData
local util_Decompress = util.Decompress
local util_JSONToTable = util.JSONToTable
local string_Explode = string.Explode

Updatr = Updatr or {}

net.Receive("Updatr.TableData", function(len)
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
end)

function Updatr.ApplyUpdates(tbl, updates)
    for key, value in pairs(updates) do
        if type(value) == "table" then
            if not tbl[key] then
                tbl[key] = value
            else
                Updatr.ApplyUpdates(tbl[key], value)
            end
        else
            tbl[key] = value
        end
    end
end

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
end)