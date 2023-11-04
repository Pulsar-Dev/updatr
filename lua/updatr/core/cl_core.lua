Updatr = Updatr or {}

net.Receive("Updatr.TableData", function(len)
    local tableName = net.ReadString()
    local dataLength = net.ReadUInt(32)
    local compressedData = net.ReadData(dataLength)
    local serializedTable = util.Decompress(compressedData)
    local t = util.JSONToTable(serializedTable)

    _G[tableName] = t
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
    local tableName = net.ReadString()
    local dataLength = net.ReadUInt(32)
    local compressedData = net.ReadData(dataLength)
    local serializedUpdates = util.Decompress(compressedData)
    local updates = util.JSONToTable(serializedUpdates)

    Updatr.ApplyUpdates(TestTable, updates)
    print(tableName, "updated")
end)