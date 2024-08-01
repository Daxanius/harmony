require("update")

local basalt         = require("/basalt")
local config         = require("config")
local HarmonySession = require("lib")

local session        = HarmonySession:new(config.server, config.streamSize, config.streamFailCooldown,
    config.maxStreamFails, config.debug,
    function(message)
        basalt.debug(message)
    end)

local main           = basalt.createFrame()
local frame          = main:addFrame():setSize("parent.w", "parent.h"):setBackground(config.theme.background)
local playThread     = main:addThread()

local function Format(Int)
    return string.format("%02i", Int)
end

local function convertToMS(Seconds)
    local Minutes = (Seconds - Seconds % 60) / 60
    Seconds = Seconds - Minutes * 60
    return Format(Minutes) .. ":" .. Format(Seconds)
end

local function isSmall(parent)
    return parent:getWidth() < 30
end

local function createButton(parent)
    return parent:addButton():setForeground(config.theme.inputForeground):setBackground(config.theme.inputBackground)
        :setBorder(parent
            :getBackground())
end

local function createInput(parent)
    return parent:addInput():setForeground(config.theme.inputForeground)
end

local function createPopup(parent, extraWidth, extraHeight)
    local control = parent:addMovableFrame("notification"):setBackground(config.theme.decoration):setForeground(config
            .theme.foreGround)
        :setZIndex(100)

    if isSmall(parent) then
        control:setSize("parent.w", "parent.h")
    else
        control:setSize("parent.w / 2 + " .. (extraWidth or 0), "parent.h / 2 + " .. (extraHeight or 0)):setPosition(
            "parent.w / 2 - self.w / 2",
            "parent.h / 2 - self.h / 2")
    end

    return control
end

-- Dialogue is a table of strings
local function createDialogue(title, dialogue, onDone)
    local function createControl(id, x, y)
        local control = createPopup(main)

        if x and y then
            control:setPosition(x, y)
        end

        local titleLabel = control:addLabel():setText(title):setForeground(config.theme.foreGround):setPosition(
            "parent.w / 2 - self.w / 2", "parent.h / 2 - 3"):setTextAlign(
            "center")
        local textLabel = control:addLabel():setText(dialogue[id]):setPosition(2,
            "parent.h / 2 - 1"):setSize(
            "parent.w - 2", "parent.h - 2")

        if id < #dialogue then
            local nextButton = createButton(control):setPosition("parent.w - self.w + 1", "parent.h - self.h + 1")
                :setText("Next")

            nextButton:onClick(function(self, event, button, x, y)
                control:remove()
                createControl(id + 1, control:getX(), control:getY())
            end)
        else
            local doneButton = createButton(control):setPosition("parent.w - self.w + 1", "parent.h - self.h + 1")
                :setText("Done")

            doneButton:onClick(function(self, event, button, x, y)
                control:remove()
                onDone()
            end)
        end


        if id > 1 then
            local previousButton = createButton(control):setPosition(1, "parent.h - self.h + 1")
                :setText("Previous")

            previousButton:onClick(function(self, event, button, x, y)
                control:remove()
                createControl(id - 1, control:getX(), control:getY())
            end)
        end
    end

    createControl(1)
end

local function showNotification(message, borderColor)
    local notification = createPopup(main):setBorder(borderColor)
    local notificationLabel = notification:addLabel():setText(message):setSize(
            "parent.w - 2", "parent.h - 2")
        :setPosition(2, 2)
    local notificationButton = createButton(notification):setPosition(
        "parent.w / 2 - self.w / 2",
        "parent.h - 3"):setText("Ok")

    notificationButton:onClick(function(self, event, button, x, y)
        notification:remove()
    end)
end

local function createLoginControl(parent, onLogin)
    local control = createPopup(parent)
    local titleLabel = control:addLabel():setText("Harmony"):setForeground(config.theme.foreGround):setPosition(
        "parent.w / 2 - self.w / 2", "parent.h / 2 - 3"):setTextAlign(
        "center")
    local userNameInput = createInput(control):setSize("parent.w - 10", 1):setPosition("parent.w / 2 - self.w / 2",
            "parent.h / 2 - 1")
        :setDefaultText("Username")
    local passwordInput = createInput(control):setSize("parent.w - 10", 1):setPosition("parent.w / 2 - self.w / 2",
            "parent.h / 2 + 1")
        :setDefaultText("Password")
        :setInputType("password")
    local loginButton = createButton(control):setPosition("parent.w - self.w + 1", "parent.h - self.h + 1")
        :setText("Login")
    local registerButton = createButton(control):setPosition(1, "parent.h - self.h + 1")
        :setText("Register")

    loginButton:onClick(function(self, event, button, x, y)
        local success, message = session:login(userNameInput:getValue(), passwordInput:getValue())

        if not success then
            showNotification(message, config.theme.errorColor)
            return
        end

        control:remove()
        onLogin()
    end)

    registerButton:onClick(function(self, event, button, x, y)
        local success, message = session:register(userNameInput:getValue(), passwordInput:getValue())

        if not success then
            showNotification(message, config.theme.errorColor)
            return
        end

        control:remove()
        createDialogue("Welcome",
            {
                "Welcome to Harmony " .. session.user.name .. "!",
                "Harmony is a music streaming service created by Daxanius.",
                "You can add your own songs by pressing the plus icon in the top right corner.",
                "Songs that you add are visible to other users.",
                "Please make sure not the abuse this service.",
                "Enjoy listening to music!"
            }, onLogin)
    end)
end

local function createAddSongControl(parent, onAdd, onCancel)
    local control = createPopup(parent, 0, 2)
    local titleLabel = control:addLabel():setText("Add Song"):setForeground(config.theme.foreGround):setPosition(
        "parent.w / 2 - self.w / 2", 2):setTextAlign(
        "center")
    local nameInput = createInput(control):setSize("parent.w - 10", 1):setPosition("parent.w / 2 - self.w / 2", 4)
        :setDefaultText("Name")
    local authorInput = createInput(control):setSize("parent.w - 10", 1):setPosition("parent.w / 2 - self.w / 2", 6)
        :setDefaultText("Author")
    local urlInput = createInput(control):setSize("parent.w - 10", 1):setPosition("parent.w / 2 - self.w / 2", 8)
        :setDefaultText("YouTube URL")
    local addButton = createButton(control):setPosition("parent.w - self.w + 1", "parent.h - self.h + 1")
        :setText("Add")
    local cancelButton = createButton(control):setPosition(1, "parent.h - self.h + 1")
        :setText("Cancel")

    cancelButton:onClick(function(self, event, button, x, y)
        control:remove()

        if onCancel ~= nil then
            onCancel()
        end
    end)

    addButton:onClick(function(self, event, button, x, y)
        local success, message = session:addSong(nameInput:getValue(), authorInput:getValue(), urlInput:getValue())

        if not success then
            showNotification(message, config.theme.errorColor)
            return
        end

        if onAdd then
            onAdd()
        end

        control:remove()
    end)
end

local function createUpdateControl(parent, onCancel)
    local control = createPopup(parent)
    local titleLabel = control:addLabel():setText("Update"):setForeground(config.theme.foreGround):setPosition(
        "parent.w / 2 - self.w / 2", 2):setTextAlign(
        "center")
    local label = control:addLabel():setText("There is an update available, would you like to install it now?"):setSize(
            "parent.w - 2", "parent.h - 2")
        :setPosition(2, 4)
    local installButton = createButton(control):setPosition("parent.w - self.w + 1", "parent.h - self.h + 1")
        :setText("Install")
    local cancelButton = createButton(control):setPosition(1, "parent.h - self.h + 1")
        :setText("Cancel")

    cancelButton:onClick(function(self, event, button, x, y)
        control:remove()

        if onCancel ~= nil then
            onCancel()
        end
    end)

    installButton:onClick(function(self, event, button, x, y)
        basalt.stop()
        update()
    end)
end

local function createAudioControl(parent, fetchSongs, onAdd)
    local barThread = parent:addThread()
    local queryCache = nil

    local control = parent:addFrame():setSize("parent.w", "parent.h"):setBackground(config.theme.background)
    local topBar = control:addFrame():setSize("parent.w", 1):setBackground(config.theme.inputBackground)
    local searchBar = createInput(topBar):setInputType("text"):setDefaultText("Search"):setInputLimit(64):setSize(
        "parent.w - 3", 1)
    local addButton = createButton(topBar):setText("+"):setPosition("parent.w - 3", 1):setSize(3, 1)

    local songList = control:addList():setSize("parent.w", "parent.h - 5"):setBackground(config.theme.listBackground)
        :setForeground(config.theme.foreGround):setSelectionColor(config.theme.decoration, config.theme.foreGround)
        :setPosition(1, 2)

    local controlFrame = control:addFrame():setSize("parent.w - 3", 4):setPosition("parent.w / 2 - self.w / 2",
            "parent.h - self.h + 1")
        :setBackground(config.theme.background)

    local playButton = createButton(controlFrame):setText("Play"):setPosition("parent.w / 2 - self.w / 2", 1):setSize(
        "self.w", 3)
    local previousButton = createButton(controlFrame):setText("<"):setPosition("parent.w / 2 - self.w / 2 - 7", 1)
        :setSize(3, 3)
    local nextButton = createButton(controlFrame):setText(">"):setPosition("parent.w / 2 - self.w / 2 + 6", 1)
        :setSize(3, 3)

    local volumeSlider = controlFrame:addSlider():setBarType("horizontal"):setMaxValue(10):setIndex(Volume / 3.0 *
            10):setPosition(2, 2)
        :setForeground(config.theme.inputBackground)


    local typeDropdown = controlFrame:addDropdown():setForeground(config.theme.inputForeground):setBackground(config
        .theme.inputBackground):addItem(
        "Normal"):addItem(
        "Shuffle"):addItem(
        "Loop"):addItem(
        "Stop"):setPosition("parent.w - self.w - 2", 2):setScrollable(true)

    local progressBar = controlFrame:addProgressbar():setDirection("right"):setProgressBar(config.theme.inputBackground)
        :setSize(
            "parent.w", 1):setBackground(config.theme.inputForeground):setPosition(1, 4)

    local songLabel = controlFrame:addLabel():setForeground(config.theme.barLabel):setBackground(false):setPosition(
        "parent.w / 2 - self.w / 2", 4):setText(""):setZIndex(10)

    local timeLabel = controlFrame:addLabel():setForeground(config.theme.barLabel):setBackground(false):setPosition(2, 4)
        :setText(
            ""):setZIndex(10)

    local totalTimeLabel = controlFrame:addLabel():setForeground(config.theme.barLabel):setBackground(false):setPosition(
            "parent.w - self.w - 1", 4)
        :setText(
            ""):setZIndex(10)


    local function listSongs(query)
        if query == "" then
            query = nil
        end

        local success, songs = fetchSongs(query)

        if not success or not songs then
            return
        end

        local selected = songList:getItemIndex()
        local offset = songList:getOffset()

        songList:clear()
        songList:setOffset(0)
        for songCount = 1, #songs do
            local color = nil
            if session.songState ~= nil and songs[songCount].id == session.songState.song.id then
                color = config.theme.inputBackground
            end

            local name = songs[songCount].name
            if songs[songCount].author ~= nil then
                name = name .. " - " .. songs[songCount].author
            end

            songList:addItem(name, color, nil, songs[songCount])
        end

        songList:selectItem(selected)
        songList:setOffset(offset)
    end

    local function updateBar()
        local secondsPerSample = (2.7 / (16 * 1024)) * session.streamSize
        totalTimeLabel:setText(convertToMS(math.floor(session.songState.size / session.streamSize *
            secondsPerSample)))

        while true do
            if session.songState ~= nil then
                progressBar:setProgress(session.songState.position * session.streamSize / session.songState
                    .size *
                    100)

                songLabel:setText(session.songState.song.name)
                timeLabel:setText(convertToMS(math.floor(session.songState.position * secondsPerSample)))
            else
                progressBar:setProgress(0)
            end

            sleep(secondsPerSample)
        end
    end

    local function stop()
        session:stopStream()
        playThread:stop()
        barThread:stop()
        progressBar:setProgress(0)
        playButton:setText("Play"):setBackground(config.theme.inputBackground)
        songLabel:setText("")
        timeLabel:setText("")
        totalTimeLabel:setText("")
        session.songState = nil
        listSongs(queryCache)
    end

    local function playTask()
        session:playStream()
        stop()
    end

    local function play()
        if songList:getValue() == nil or songList:getValue().args == nil then
            return
        end

        session:stopStream()
        if session:loadStream(songList:getValue().args[1]) then
            listSongs(queryCache)
            playButton:setText("Stop"):setBackground(config.theme.errorColor)
            playThread:start(playTask)
            barThread:start(updateBar)
        end
    end

    addButton:onClick(function(self, event, item, x, y)
        onAdd()
        listSongs(queryCache)
    end)

    playButton:onClick(function(self, event, item, x, y)
        if session.songState ~= nil then
            stop()
        else
            play()
        end
    end)

    searchBar:onChange(function(self, event, item)
        listSongs(item)
        queryCache = item
    end)

    volumeSlider:onChange(function(self, event, value)
        Volume = (value / 10.0) * 3.0
    end)

    listSongs()
end

local function app()
    createLoginControl(frame, function()
        createAudioControl(frame,
            function(query)
                return session:listSongs(query)
            end,
            function()
                createAddSongControl(frame)
            end)
    end)
end

if checkForUpdates() then
    createUpdateControl(frame, app)
else
    app()
end

basalt.autoUpdate()
