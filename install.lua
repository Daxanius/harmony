local repoURL = "https://raw.githubusercontent.com/Daxanius/harmony/main"

-- List of files to download and their paths
local files = {
    "/harmony.lua",
    "/harmony/config.lua",
    "/harmony/gui.lua",
    "/harmony/lib.lua",
    "/harmony/update.lua",
    "/harmony/version.txt",
    "/harmony/theme/default.lua"
}

-- Function to download and save a file
local function downloadFile(fileName)
    local url = repoURL .. fileName
    local response = http.get(url)
    if response then
        local fileContent = response.readAll()
        response.close()

        local filePath = fileName
        local file = fs.open(filePath, "w")
        file.write(fileContent)
        file.close()
        print("Updated " .. fileName)
    else
        print("Failed to download " .. fileName)
    end
end

-- Install basalt
shell.run("wget", "run", "https://basalt.madefor.cc/install.lua", "packed")

-- Download all files
for _, file in ipairs(files) do
    downloadFile(file)
end

print("Installation complete.")
