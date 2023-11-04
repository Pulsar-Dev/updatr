local pairs = pairs
local type = type
local next = next
local unpack = unpack
local table_Copy = table.Copy
local table_insert = table.insert
local table_remove = table.remove
local table_Count = table.Count
local table_IsEmpty = table.IsEmpty
local string_sub = string.sub
local util_TableToJSON = util.TableToJSON
local util_Compress = util.Compress
local net_Start = net.Start
local net_WriteString = net.WriteString
local net_WriteUInt = net.WriteUInt
local net_WriteData = net.WriteData
local net_Send = net.Send
local net_Broadcast = net.Broadcast
local updatr_Debug = Updatr.DebugLog

Updatr = Updatr or {}
Updatr.RegisteredTables = Updatr.RegisteredTables or {}

util.AddNetworkString("Updatr.TableUpdates")
util.AddNetworkString("Updatr.TableData")

function Updatr.GetTableGlobalName(targetTable)
    local seenTables = {}
    local stack = {{_G, "_G"}}

    while #stack > 0 do
        local currentTable, currentTableName = unpack(table_remove(stack))

        if currentTable == targetTable then
            return string_sub(currentTableName, 4)  -- Remove the "_G." prefix
        end

        seenTables[currentTable] = true

        for name, tbl in pairs(currentTable) do
            if type(tbl) == "table" and not seenTables[tbl] then
                table_insert(stack, {tbl, currentTableName .. "." .. name})
            end
        end
    end

    return nil
end

function Updatr.RegisterTable(t, ignoreList)
    local tableName = Updatr.GetTableGlobalName(t)
    if not tableName then
        error("Unable to register table, table is not a global table or cannot be found")
        return
    end

    Updatr.RegisteredTables[tableName] = {table = t, ignoreList = ignoreList or {}}
    updatr_Debug("Registered table " .. tableName)
end

function Updatr.GetUpdatedSubTables(newTable, oldTable, ignoreList, isSubTable)
    local updates = {}
    local tableName = Updatr.GetTableGlobalName(newTable)
    if not tableName and not isSubTable then
        updatr_Debug("Table is not a global table")
        return
    end

    ignoreList = ignoreList or Updatr.RegisteredTables[tableName] and Updatr.RegisteredTables[tableName].ignoreList

    for key, value in pairs(newTable) do
        if ignoreList and ignoreList[tostring(key)] and type(key) ~= "number" then
            continue
        else
            if type(value) == "table" then
                if oldTable[key] == nil then
                    updates[key] = value
                else
                    local subUpdates = Updatr.GetUpdatedSubTables(value, oldTable[key], tableName, true)
                    if next(subUpdates) ~= nil then
                        updates[key] = subUpdates
                    end
                end
            elseif oldTable[key] ~= value then
                updates[key] = value
            end
        end
    end

    updatr_Debug("Found " .. table_Count(updates) .. " updates")
    return updates
end

function Updatr.TableCompare(t1, t2)
    for key, value in pairs(t1) do
        if type(value) == "table" then
            if type(t2[key]) ~= "table" or not Updatr.TableCompare(value, t2[key]) then
                return false
            end
        elseif value ~= t2[key] then
            return false
        end
    end

    for key, value in pairs(t2) do
        if type(value) == "table" then
            if type(t1[key]) ~= "table" or not Updatr.TableCompare(value, t1[key]) then
                return false
            end
        elseif value ~= t1[key] then
            return false
        end
    end

    return true
end

function Updatr.SendUpdates(newTable, oldTable)
    local tableName = Updatr.GetTableGlobalName(newTable)
    if not tableName then
        updatr_Debug("Table is not a global table")
        return
    end

    if not Updatr.RegisteredTables[tableName] then
        updatr_Debug("Table " .. tableName .. " is not registered")
        return
    end

    updatr_Debug("Broadcasting updates for table " .. tableName)

    local updates = Updatr.GetUpdatedSubTables(newTable, oldTable, Updatr.RegisteredTables[tableName].ignoreList)

    if not updates or table_IsEmpty(updates) then
        updatr_Debug("No updates found, skipping broadcast")
        return
    end

    local serializedUpdates = util_TableToJSON(updates)
    local compressedUpdates = util_Compress(serializedUpdates)

    net_Start("Updatr.TableUpdates")
    net_WriteString(tableName)
    net_WriteUInt(#compressedUpdates, 32)
    net_WriteData(compressedUpdates, #compressedUpdates)
    net_Broadcast()

    updatr_Debug("Broadcasted updates for table " .. tableName)
end

local function removeIgnoredKeys(t, ignoreList)
    local ignoredTable = table_Copy(t)
    for key, value in pairs(t) do
        if ignoreList and ignoreList[key] then
            ignoredTable[key] = nil
        elseif type(value) == "table" then
            removeIgnoredKeys(value, ignoreList)
        end
    end

    return ignoredTable
end

function Updatr.SendTableToClient(ply, tableName, t)
    local ignoredTable = removeIgnoredKeys(t, Updatr.RegisteredTables[tableName].ignoreList)
    local serializedTable = util_TableToJSON(ignoredTable)
    local compressedTable = util_Compress(serializedTable)

    updatr_Debug("Sending table " .. tableName .. " to " .. ply:Nick())

    net_Send("Updatr.TableData")
    net_WriteString(tableName)
    net_WriteUInt(#compressedTable, 32)
    net_WriteData(compressedTable, #compressedTable)
    net_Send(ply)
end

hook.Add("PlayerFullLoad", "Updatr.Test", function(ply)
    updatr_Debug("Sending all tables to " .. ply:Nick())
    for tableName, t in pairs(Updatr.RegisteredTables) do
        Updatr.SendTableToClient(ply, tableName, t.table)
    end
end)