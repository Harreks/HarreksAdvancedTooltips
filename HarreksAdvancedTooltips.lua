--Edge cases: some talents buff a specific spell but don't mention that spell in the description, this is a list of them
local talentsMissingName = {
    ----Preservation Evoker
    --Emerald Communion
    [370960] = {
        --Dreamwalker
        [377082] = true
    }
}

--Edge cases: when a spell replaces another, the name of the replacement won't be on the talents while still affecting it, this is a list matching the replacement with the replaced
local replacedSpells = {
    ----Preservation Evoker
    --Chronoflame replaces Living Flame
    [431443] = 361469,
    ----Mistweaver Monk
    --Rushing Wind Kick replaces Rising Sun Kick
    [467307] = 107428,
    ----Restoration Shaman
    --Cloudburst Totem replaces Healing Stream Totem
    [157153] = 5394,
    -----Farseer Shaman
    --Ancestral Swiftness replaces Natures Swiftness
    [443454] = 378081,
    ----Subtlety Rogue
    --Gloomblade replaces Backstab
    [200758] = 53,
    ---Affliction Warlock
    --Drain Soul replaces Shadow Bolt
    [388667] = 686,
}

--Edge cases: some talents mention spells in their tooltips even tho the effect doesn't really buff casts of that spell, heres the blacklist
local blacklistedTalents = {
    ----Monk
    --Enveloping Mist
    [124682] = {
        --Thunder Focus Tea
        [116680] = true,
        --Secret Infusion
        [388491] = true
    },
    --Renewing Mist
    [115151] = {
        --Thunder Focus Tea
        [116680] = true,
        --Secret Infusion
        [388491] = true
    },
    --Vivify
    [116670] = {
        --Thunder Focus Tea
        [116680] = true,
        --Secret Infusion
        [388491] = true
    },
    --Rising Sun Kick
    [107428] = {
        --Thunder Focus Tea
        [116680] = true,
        --Secret Infusion
        [388491] = true
    },
    --Essence Font
    [191837] = {
        --Thunder Focus Tea
        [116680] = true,
        --Secret Infusion
        [388491] = true
    },
    --Expel Harm
    [322101] = {
        --Thunder Focus Tea
        [116680] = true,
        --Secret Infusion
        [388491] = true
    },
    ----Druid
    --Rejuvenation
    [774] = {
        --Incarnation: Tree of Life
        [33891] = true
    },
    --Wild Growth
    [48438] = {
        --Incarnation: Tree of Life
        [33891] = true
    },
    --Regrowth
    [8936] = {
        --Incarnation: Tree of Life
        [33891] = true
    },
    --Wrath
    [5176] = {
        --Incarnation: Tree of Life
        [33891] = true
    },
    --Entangling Roots
    [339] = {
        --Incarnation: Tree of Life
        [33891] = true
    },
    --Grove Guardians
    [102693] = {
        --Cenarius' Guidance
        [393371] = true
    },
    ----Shaman
    --Flame Shock
    [188389] = {
        --Surge of Power
        [262303] = true,
        --Deeply Rooted Elements
        [378270] = true,
        --Ascendance
        [114050] = true
    },
    --Chain Lightning
    [188443] = {
        --Surge of Power
        [262303] = true,
    },
    --Lightning Bolt
    [188196] = {
        --Surge of Power
        [262303] = true,
    },
    --Frost Shock
    [196840] = {
        --Surge of Power
        [262303] = true
    },
    --Lava Burst
    [51505] = {
        --Surge of Power
        [262303] = true
    }
}

local talentCache = {}

local function UpdateTalentCache()
    table.wipe(talentCache)
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return end

    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo then return end

    for _, treeID in ipairs(configInfo.treeIDs) do
        local nodes = C_Traits.GetTreeNodes(treeID)
        for _, nodeID in ipairs(nodes) do
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
            for _, entryID in ipairs(nodeInfo.entryIDs) do
                local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                if entryInfo and entryInfo.definitionID then
                    local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                    if definitionInfo.spellID and C_SpellBook.IsSpellKnown(definitionInfo.spellID) then
                        local talentSpellID = definitionInfo.spellID
                        if talentSpellID then
                            local talent = Spell:CreateFromSpellID(talentSpellID)
                            talent:ContinueOnSpellLoad(function()
                                talentCache[talentSpellID] = {
                                    name = talent:GetSpellName(),
                                    desc = talent:GetSpellDescription()
                                }
                            end)
                        end
                    end
                end
            end
        end
    end
end

local function DelayedUpdate()
    C_Timer.After(1, UpdateTalentCache)
end

-- Once on login
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("TRAIT_CONFIG_UPDATED")
f:SetScript("OnEvent", DelayedUpdate)

local function SearchTreeCached(spellID, tooltip)
    local spellInfo = C_Spell.GetSpellInfo(spellID)
    if not spellInfo then return end
    local spellName = spellInfo.name
    local extraSpellName = nil
    if replacedSpells[spellID] then
        local extraSpellInfo = C_Spell.GetSpellInfo(replacedSpells[spellID])
        extraSpellName = extraSpellInfo.name
    end

    for talentSpellID, talentInfo in pairs(talentCache) do
        local isNotBlacklisted = not (blacklistedTalents[spellID] and blacklistedTalents[spellID][talentSpellID])
        local isMissingName = talentsMissingName[spellID] and talentsMissingName[spellID][talentSpellID]

        if (isMissingName or (isNotBlacklisted and talentInfo.name ~= spellName and talentInfo.desc and (string.find(talentInfo.desc, spellName) or (extraSpellName and string.find(talentInfo.desc, extraSpellName))))) then
            local tooltipText = '\n|cffffffff' .. talentInfo.name .. ':|r ' .. talentInfo.desc .. '\n'
            tooltip:AddLine(tooltipText, 1.0, 0.82, 0.0, true)
        end
    end
    tooltip:Show()
end

if TooltipDataProcessor then
    TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
        if not data or issecretvalue(data.type) then return end

        if data.type == Enum.TooltipDataType.Spell and C_SpellBook.IsSpellInSpellBook(data.id) then
            SearchTreeCached(data.id, tooltip)
        elseif data.type == Enum.TooltipDataType.Macro and data.lines[1].tooltipID and C_SpellBook.IsSpellInSpellBook(data.lines[1].tooltipID) then
            SearchTreeCached(data.lines[1].tooltipID, tooltip)
        end
    end)
end