Updatr = Updatr or {}
Updatr.Debug = false

function Updatr.DebugLog(...)
    if PulsarLib.DevelopmentMode or Updatr.Debug then
        MsgC(Color(255, 255, 0), "[Updatr] ", Color(255, 255, 255), ... .. "\n")
    end
end

function Updatr.LoadDirectory(path)
    local files, folders = file.Find(path .. "/*", "LUA")

    for _, fileName in ipairs(files) do
        local filePath = path .. "/" .. fileName

        if CLIENT then
            include(filePath)
        else
            if fileName:StartWith("cl_") then
                AddCSLuaFile(filePath)
            elseif fileName:StartWith("sh_") then
                AddCSLuaFile(filePath)
                include(filePath)
            else
                include(filePath)
            end
        end
    end

    return files, folders
end

function Updatr.LoadDirectoryRecursive(basePath, onLoad)
    local _, folders = Updatr.LoadDirectory(basePath)

    for _, folderName in ipairs(folders) do
        Updatr.LoadDirectoryRecursive(basePath .. "/" .. folderName)
    end

    if onLoad and isfunction(onLoad) then
        onLoad()
    end
end

Updatr.LoadDirectoryRecursive("updatr")
hook.Run("Updatr.FullyLoaded")