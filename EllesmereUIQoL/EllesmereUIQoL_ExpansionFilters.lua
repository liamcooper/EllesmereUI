-------------------------------------------------------------------------------
--  EllesmereUIQoL_ExpansionFilters.lua
--  Auto-enable "Current Expansion Only" on Auction House browse and
--  Place Crafting Order (customer orders table at crafting stations).
-------------------------------------------------------------------------------

do
    local EXPANSION_FILTER = Enum and Enum.AuctionHouseFilter and Enum.AuctionHouseFilter.CurrentExpansionOnly

    local function IsCurrentExpansionEnabled()
        return EllesmereUIDB and EllesmereUIDB.ahCurrentExpansion
    end

    local function ApplyExpansionCheckboxFilter(filterControl, force)
        if not EXPANSION_FILTER or not filterControl then return end
        if not filterControl.filters and AUCTION_HOUSE_DEFAULT_FILTERS and CopyTable then
            filterControl.filters = CopyTable(AUCTION_HOUSE_DEFAULT_FILTERS)
        end
        local filters = filterControl.filters
        if not filters then return end
        if not force and filters[EXPANSION_FILTER] then return end
        if filterControl.ToggleFilter and not force then
            filterControl:ToggleFilter(EXPANSION_FILTER)
        else
            filters[EXPANSION_FILTER] = true
        end
        if filterControl.ValidateResetState then
            filterControl:ValidateResetState()
        end
    end

    local function ApplySearchBarExpansionFilter(searchBar)
        if not searchBar then return end
        ApplyExpansionCheckboxFilter(searchBar.FilterButton or searchBar.FilterDropdown)
        if searchBar.UpdateClearFiltersButton then
            searchBar:UpdateClearFiltersButton()
        end
    end

    local function ApplyAuctionHouseExpansionFilter(searchBar)
        if not IsCurrentExpansionEnabled() then return end
        if searchBar then
            ApplySearchBarExpansionFilter(searchBar)
            return
        end
        if not AuctionHouseFrame then return end
        C_Timer.After(0, function()
            if AuctionHouseFrame.BrowseTab and AuctionHouseFrame.BrowseTab.ItemSearchBar then
                ApplySearchBarExpansionFilter(AuctionHouseFrame.BrowseTab.ItemSearchBar)
            end
            if AuctionHouseFrame.SearchBar then
                ApplySearchBarExpansionFilter(AuctionHouseFrame.SearchBar)
            end
        end)
    end

    local ahHooksInstalled = false
    local function InstallAuctionHouseHooks()
        if ahHooksInstalled or not AuctionHouseSearchBarMixin or not AuctionHouseSearchBarMixin.OnShow then return end
        ahHooksInstalled = true
        hooksecurefunc(AuctionHouseSearchBarMixin, "OnShow", function(self)
            ApplyAuctionHouseExpansionFilter(self)
        end)
    end

    local function LoadCustomerOrdersAddons()
        if not C_AddOns or not C_AddOns.LoadAddOn then return end
        C_AddOns.LoadAddOn("Blizzard_AuctionHouseUI")
        C_AddOns.LoadAddOn("Blizzard_ProfessionsCustomerOrders")
    end

    local function GetCustomerOrdersBrowsePage()
        if ProfessionsCustomerOrdersFrame and ProfessionsCustomerOrdersFrame.BrowseOrders then
            return ProfessionsCustomerOrdersFrame.BrowseOrders
        end
    end

    local function ForceCustomerOrdersExpansionFilter(browsePage)
        if not IsCurrentExpansionEnabled() then return end
        browsePage = browsePage or GetCustomerOrdersBrowsePage()
        if not browsePage or not browsePage.SearchBar then return end
        ApplyExpansionCheckboxFilter(browsePage.SearchBar.FilterDropdown, true)
    end

    local function ApplyCustomerOrdersExpansionFilter(browsePage)
        if not IsCurrentExpansionEnabled() then return end
        if browsePage and browsePage._euiUserClearedExpansionFilter then return end
        ForceCustomerOrdersExpansionFilter(browsePage)
    end

    local function ResetCustomerOrdersExpansionSession(browsePage)
        if browsePage then
            browsePage._euiUserClearedExpansionFilter = nil
            browsePage._euiOpenApplyComplete = nil
        end
    end

    local function MarkCustomerOrdersExpansionCleared(browsePage)
        if browsePage then
            browsePage._euiUserClearedExpansionFilter = true
        end
    end

    local pendingCustomerFilterTimer
    local function ScheduleCustomerOrdersOpenApply(browsePage)
        if pendingCustomerFilterTimer then
            pendingCustomerFilterTimer:Cancel()
        end
        pendingCustomerFilterTimer = C_Timer.NewTimer(0.35, function()
            pendingCustomerFilterTimer = nil
            ForceCustomerOrdersExpansionFilter(browsePage)
            if browsePage then
                browsePage._euiOpenApplyComplete = true
            end
        end)
    end

    local function WrapCustomerOrdersStartSearch(browsePage)
        if not browsePage or browsePage._euiStartSearchWrapped then return end
        local originalStartSearch = browsePage.StartSearch
        if type(originalStartSearch) ~= "function" then return end
        browsePage._euiOriginalStartSearch = originalStartSearch
        browsePage.StartSearch = function(self, isFavoritesSearch)
            local startSearch = self._euiOriginalStartSearch or originalStartSearch
            if type(startSearch) == "function" then
                return startSearch(self, isFavoritesSearch)
            end
        end
        browsePage._euiStartSearchWrapped = true
    end

    local filterMenuHooked = false
    local function InstallCustomerOrdersFilterMenuHook()
        if filterMenuHooked or not WowStyle1FilterDropdownMixin or not WowStyle1FilterDropdownMixin.OnMouseDown then return end
        filterMenuHooked = true
        hooksecurefunc(WowStyle1FilterDropdownMixin, "OnMouseDown", function(self)
            if not IsCurrentExpansionEnabled() then return end
            if not ProfessionsCustomerOrdersFrame or not ProfessionsCustomerOrdersFrame:IsShown() then return end
            local searchBar = self:GetParent()
            if not searchBar or searchBar.FilterDropdown ~= self then return end
            local browsePage = searchBar:GetParent()
            if not browsePage or not browsePage._euiOpenApplyComplete then return end
            C_Timer.After(0, function()
                if not browsePage.SearchBar or not browsePage.SearchBar.FilterDropdown then return end
                local filters = browsePage.SearchBar.FilterDropdown.filters
                if filters and not filters[EXPANSION_FILTER] then
                    MarkCustomerOrdersExpansionCleared(browsePage)
                end
            end)
        end)
    end

    local function OnCustomerOrdersBrowseOpen(browsePage)
        if not IsCurrentExpansionEnabled() then return end
        browsePage = browsePage or GetCustomerOrdersBrowsePage()
        if not browsePage then return end
        WrapCustomerOrdersStartSearch(browsePage)
        ForceCustomerOrdersExpansionFilter(browsePage)
        ScheduleCustomerOrdersOpenApply(browsePage)
    end

    local customerHooksInstalled = false
    local function InstallCustomerOrdersHooks()
        if customerHooksInstalled or not ProfessionsCustomerOrdersBrowsePageMixin then return end
        customerHooksInstalled = true

        if ProfessionsCustomerOrdersBrowsePageMixin.SetDefaultFilters then
            hooksecurefunc(ProfessionsCustomerOrdersBrowsePageMixin, "SetDefaultFilters", function(self)
                ResetCustomerOrdersExpansionSession(self)
                WrapCustomerOrdersStartSearch(self)
                ForceCustomerOrdersExpansionFilter(self)
            end)
        end
        if ProfessionsCustomerOrdersBrowsePageMixin.InitFilterDropdown then
            hooksecurefunc(ProfessionsCustomerOrdersBrowsePageMixin, "InitFilterDropdown", function(self)
                ForceCustomerOrdersExpansionFilter(self)
            end)
        end
        if ProfessionsCustomerOrdersBrowsePageMixin.Init then
            hooksecurefunc(ProfessionsCustomerOrdersBrowsePageMixin, "Init", function(self)
                ForceCustomerOrdersExpansionFilter(self)
                ScheduleCustomerOrdersOpenApply(self)
            end)
        end
        if ProfessionsCustomerOrdersBrowsePageMixin.OnLoad then
            hooksecurefunc(ProfessionsCustomerOrdersBrowsePageMixin, "OnLoad", function(self)
                WrapCustomerOrdersStartSearch(self)
            end)
        end

        if ProfessionsCustomerOrdersMixin and ProfessionsCustomerOrdersMixin.OnShow then
            hooksecurefunc(ProfessionsCustomerOrdersMixin, "OnShow", function(self)
                OnCustomerOrdersBrowseOpen(self.BrowseOrders)
            end)
        end

        if ProfessionsCustomerOrdersFrame and not ProfessionsCustomerOrdersFrame._euiExpansionOnShow then
            ProfessionsCustomerOrdersFrame._euiExpansionOnShow = true
            ProfessionsCustomerOrdersFrame:HookScript("OnShow", function()
                C_Timer.After(0, function()
                    OnCustomerOrdersBrowseOpen(GetCustomerOrdersBrowsePage())
                end)
            end)
        end

        WrapCustomerOrdersStartSearch(GetCustomerOrdersBrowsePage())
        InstallCustomerOrdersFilterMenuHook()
    end

    local function OnCustomerOrdersInteraction()
        if not IsCurrentExpansionEnabled() then return end
        if not C_AddOns or not C_AddOns.IsAddOnLoaded("Blizzard_ProfessionsCustomerOrders") then
            LoadCustomerOrdersAddons()
        end
        InstallCustomerOrdersHooks()
        InstallCustomerOrdersFilterMenuHook()
        C_Timer.After(0, function()
            OnCustomerOrdersBrowseOpen(GetCustomerOrdersBrowsePage())
        end)
    end

    local setupFrame = CreateFrame("Frame")
    local setupEventsUnregistered = false

    local function TryUnregisterSetupEvents()
        if setupEventsUnregistered then return end
        if not ahHooksInstalled or not customerHooksInstalled then return end
        setupEventsUnregistered = true
        setupFrame:UnregisterEvent("ADDON_LOADED")
        setupFrame:UnregisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    end

    local function TryInstallAllHooks()
        InstallCustomerOrdersFilterMenuHook()
        TryUnregisterSetupEvents()
    end

    setupFrame:RegisterEvent("ADDON_LOADED")
    setupFrame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    setupFrame:SetScript("OnEvent", function(self, event, arg1)
        if event == "ADDON_LOADED" then
            if arg1 == "Blizzard_AuctionHouseUI" then
                InstallAuctionHouseHooks()
            elseif arg1 == "Blizzard_ProfessionsCustomerOrders" then
                InstallCustomerOrdersHooks()
            elseif arg1 == "Blizzard_Menu" then
                InstallCustomerOrdersFilterMenuHook()
            end
            TryInstallAllHooks()
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            if arg1 == Enum.PlayerInteractionType.ProfessionsCustomerOrders then
                OnCustomerOrdersInteraction()
                TryInstallAllHooks()
            end
        end
    end)

    local ahFrame = CreateFrame("Frame")
    ahFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
    ahFrame:SetScript("OnEvent", function(self, event)
        if event == "AUCTION_HOUSE_SHOW" then
            InstallAuctionHouseHooks()
            ApplyAuctionHouseExpansionFilter()
        end
    end)

    if C_AddOns and C_AddOns.IsAddOnLoaded then
        if C_AddOns.IsAddOnLoaded("Blizzard_AuctionHouseUI") then
            InstallAuctionHouseHooks()
        end
        if C_AddOns.IsAddOnLoaded("Blizzard_ProfessionsCustomerOrders") then
            InstallCustomerOrdersHooks()
        end
        if C_AddOns.IsAddOnLoaded("Blizzard_Menu") then
            InstallCustomerOrdersFilterMenuHook()
        end
        TryInstallAllHooks()
    end
end
