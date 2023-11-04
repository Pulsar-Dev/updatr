Updatr = Updatr or {}
Updatr.RegisteredTables = Updatr.RegisteredTables or {}

util.AddNetworkString("Updatr.TableUpdates")
util.AddNetworkString("Updatr.TableData")

function Updatr.RegisterTable(t)
    local tableName = Updatr.GetTableGlobalName(t)
    if not tableName then
        error("Table is not a global table")
        return
    end

    Updatr.RegisteredTables[tableName] = t
    Updatr.DebugLog("Registered table " .. tableName)
end

function Updatr.GetUpdatedSubTables(newTable, oldTable)
    local updates = {}

    for key, value in pairs(newTable) do
        if type(value) == "table" then
            if oldTable[key] == nil then
                updates[key] = value
            else
                local subUpdates = Updatr.GetUpdatedSubTables(value, oldTable[key])
                if next(subUpdates) ~= nil then
                    updates[key] = subUpdates
                end
            end
        elseif oldTable[key] ~= value then
            updates[key] = value
        end
    end

    Updatr.DebugLog("Found " .. table.Count(updates) .. " updates")
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

function Updatr.GetTableGlobalName(t)
    for k, v in pairs(_G) do
        if v == t then
            Updatr.DebugLog("Found table " .. k)
            return k
        end
    end

    Updatr.DebugLog("Table not found")
    return nil
end

function Updatr.SendUpdates(newTable, oldTable)
    local tableName = Updatr.GetTableGlobalName(newTable)
    if not tableName then
        Updatr.DebugLog("Table is not a global table")
        return
    end

    Updatr.DebugLog("Broadcasting updates for table " .. tableName)

    local updates = Updatr.GetUpdatedSubTables(newTable, oldTable)
    local serializedUpdates = util.TableToJSON(updates)
    local compressedUpdates = util.Compress(serializedUpdates)

    net.Start("Updatr.TableUpdates")
    net.WriteString(tableName)
    net.WriteUInt(#compressedUpdates, 32)
    net.WriteData(compressedUpdates, #compressedUpdates)
    net.Broadcast()

    Updatr.DebugLog("Broadcasted updates for table " .. tableName)
end

function Updatr.SendTableToClient(ply, tableName, t)
    local serializedTable = util.TableToJSON(t)
    local compressedTable = util.Compress(serializedTable)

    Updatr.DebugLog("Sending table " .. tableName .. " to " .. ply:Nick())

    net.Start("Updatr.TableData")
    net.WriteString(tableName)
    net.WriteUInt(#compressedTable, 32)
    net.WriteData(compressedTable, #compressedTable)
    net.Send(ply)
end

hook.Add("PlayerFullLoad", "Updatr.Test", function(ply)
    Updatr.DebugLog("Sending all tables to " .. ply:Nick())
    for tableName, t in pairs(Updatr.RegisteredTables) do
        Updatr.SendTableToClient(ply, tableName, t)
    end
end)

-- debug stuff

-- TestTable = {
--     test1 = {
--         data = "test1",
--         data2 = "test2"
--     },
--     test2 = {
--         data = {
--             test3 = "test3",
--             test4 = "test4"
--         },
--         data2 = {
--             test5 = "test5",
--             test6 = "test6"
--         },
--     },
--     test3 = {
--         data = {
--             test7 = {
--                 test8 = "test8",
--                 test9 = "test9"
--             },
--             test10 = {
--                 test11 = "test11",
--                 test12 = "test12"
--             },
--         },
--         data2 = {
--             test13 = {
--                 test14 = "test14",
--                 test15 = "test15"
--             },
--             test16 = {
--                 test17 = "test17",
--                 test18 = "test18"
--             },
--         },
--     },
-- }

-- Updatr.RegisteredTables = {}
-- Updatr.RegisterTable(TestTable)

-- for tableName, t in pairs(Updatr.RegisteredTables) do
--     Updatr.SendTableToClient(Entity(1), tableName, t)
-- end

-- local oldTable = table.Copy(TestTable)
-- TestTable.test1.data = "test1.1"
-- TestTable.test2.data.test3 = "test3.1"

-- Updatr.SendUpdates(TestTable, oldTable)
