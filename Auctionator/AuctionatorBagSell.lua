local SELL_TAB_INDEX = 1
local BAG_ICON_SIZE = 36
local BAG_ICON_GAP = 2
local BAG_COLUMNS = 5
local ICON_STEP = BAG_ICON_SIZE + BAG_ICON_GAP

local HEADER_LAYOUT = {
  icon = { x = 15, y = -32, size = 50 },
  name = { x = 15, y = -6, width = 400, height = 18 },
  -- Перетащите в данную область предмет...
  message = { x = -140, y = 20, width = 520, height = 18 },
  qtyInput = { x = 355, y = -65, width = 36 },
  qtyMax = { x = 420, y = -65, width = 45, height = 20 },

  stackLabel = { x = 75, y = -36 },
  stackInput = { x = 170, y = -30, width = 96 },
  itemLabel = { x = 75, y = -70 },
  itemInput = { x = 170, y = -65, width = 96 },
  durationLabel = { x = 470, y = -10 },
  duration = { x = 450, y = -25 },
  commission = { x = 350, y = -36, width = 175 },
  post = { x = 465, y = -64, width = 113, height = 22 },
}

local L
if GetLocale() == "ruRU" then
  L = {
    blacklist = "Черный список",
    pcs = "шт.",
    max = "Макс",
    price = "Цена за штуку",
    stackPrice = "Цена за все",
    duration = "Длительность",
    commission = "Комиссия",
    post = "Продать",
    hours12 = "12 часов",
    hours24 = "24 часа",
    hours48 = "48 часов",
    noPrice = "Укажите цену",
    noItem = "Предмет не выбран",
    postError = "Не удалось выставить лот",
  }
else
  L = {
    blacklist = "Blacklist",
    pcs = "pcs",
    max = "Max",
    price = "Unit price",
    stackPrice = "Stack price",
    duration = "Duration",
    commission = "Commission",
    post = "Sell",
    hours12 = "12 hours",
    hours24 = "24 hours",
    hours48 = "48 hours",
    noPrice = "Enter a price",
    noItem = "No item selected",
    postError = "Failed to post auction",
  }
end

local function GetBlacklist()
  _G.AUCTIONATOR_SAVEDVARS = _G.AUCTIONATOR_SAVEDVARS or {}
  local list = _G.AUCTIONATOR_SAVEDVARS.BAG_SELL_BLACKLIST
  if type(list) ~= "table" then
    list = {}
    _G.AUCTIONATOR_SAVEDVARS.BAG_SELL_BLACKLIST = list
  end
  return list
end

local function GetBlacklistKey(entry)
  return entry and (entry.itemID or entry.link) or nil
end

local CLASS_ORDER = {
  LE_ITEM_CLASS_WEAPON,
  LE_ITEM_CLASS_ARMOR,
  LE_ITEM_CLASS_CONTAINER,
  LE_ITEM_CLASS_GEM,
  LE_ITEM_CLASS_CONSUMABLE,
  LE_ITEM_CLASS_GLYPH,
  LE_ITEM_CLASS_TRADEGOODS,
  LE_ITEM_CLASS_RECIPE,
  LE_ITEM_CLASS_QUESTITEM,
  LE_ITEM_CLASS_AMMO,
  LE_ITEM_CLASS_QUIVER,
  LE_ITEM_CLASS_MISCELLANEOUS,
}

local CLASS_ORDER_INDEX = {}
for index, classID in ipairs(CLASS_ORDER) do
  CLASS_ORDER_INDEX[classID] = index
end

local CLASS_TOKEN_MAP = {}
local function AddClassToken(token, classID)
  if token then
    CLASS_TOKEN_MAP[token] = classID
  end
end
AddClassToken(ITEM_CLASS_0, LE_ITEM_CLASS_CONSUMABLE)
AddClassToken(ITEM_CLASS_1, LE_ITEM_CLASS_CONTAINER)
AddClassToken(ITEM_CLASS_2, LE_ITEM_CLASS_WEAPON)
AddClassToken(ITEM_CLASS_3, LE_ITEM_CLASS_GEM)
AddClassToken(ITEM_CLASS_4, LE_ITEM_CLASS_ARMOR)
AddClassToken(ITEM_CLASS_6, LE_ITEM_CLASS_AMMO)
AddClassToken(ITEM_CLASS_7, LE_ITEM_CLASS_TRADEGOODS)
AddClassToken(ITEM_CLASS_9, LE_ITEM_CLASS_RECIPE)
AddClassToken(ITEM_CLASS_11, LE_ITEM_CLASS_QUIVER)
AddClassToken(ITEM_CLASS_12, LE_ITEM_CLASS_QUESTITEM)
AddClassToken(ITEM_CLASS_15, LE_ITEM_CLASS_MISCELLANEOUS)
AddClassToken(ITEM_CLASS_16, LE_ITEM_CLASS_GLYPH)

local NAME_ORDER = {}

local frame
local headerPanel
local emptySlot
local bagPanel
local bagScroll
local bagContent
local bagHeaders = {}
local bagButtons = {}
local collapsedGroups = { blacklist = true }

local qtyBox
local qtyMaxButton
local qtyPcs
local priceInput
local stackPriceInput
local durationDropDown
local itemNameText
local summaryText
local postButton
local selectedDuration = 24
local moneyUpdateDepth = 0
local postingInProgress = false

local selectedEntry
local selectedRows = {}
local priceDirty = false
local initialized = false
local outerHookDone = false
local bagRefreshPending = false
local selectingSellPane = false
local pendingSellDefault = false
local legacyHiddenRegions = {}
local messageHookInstalled = false
local stackPriceHookInstalled = false
local showItemHookInstalled = false
local recommendHookInstalled = false
local showElemsHookInstalled = false
local updateUIHookInstalled = false
local paneHookInstalled = false
local searchCompleteHookInstalled = false
local cancelHookInstalled = false

local function GetContentBase()
  return _G.AuctionHouseFrame or _G.Atr_Main_Panel or _G.Atr_SellControls or UIParent
end

local function PlaceHeaderRegion(region, cfg, point)
  if not region or not headerPanel then
    return
  end
  region:ClearAllPoints()
  region:SetPoint(point or "TOPLEFT", headerPanel, "TOPLEFT", cfg.x or 0, cfg.y or 0)
  if cfg.width then
    region:SetWidth(cfg.width)
  end
  if cfg.height then
    region:SetHeight(cfg.height)
  end
end

local function GetTabsAnchor()
  local tabs = { _G.AuctionFrameTab4, _G.AuctionFrameTab5, _G.AuctionFrameTab6 }
  local rightmost
  for _, tab in ipairs(tabs) do
    if tab and tab:IsShown() then
      if not rightmost or (tab:GetRight() or 0) > (rightmost:GetRight() or 0) then
        rightmost = tab
      end
    end
  end
  return rightmost
end

local function PlaceMessageFrame(region)
  if not region then
    return
  end
  local cfg = HEADER_LAYOUT.message
  region:ClearAllPoints()
  region:SetHeight(cfg.height or 18)
  region:SetJustifyH("CENTER")
  region:SetJustifyV("MIDDLE")

  local tab = GetTabsAnchor()
  if tab and headerPanel then
    region:SetPoint("BOTTOMLEFT", tab, "RIGHT", cfg.x, cfg.y)
    region:SetPoint("BOTTOMRIGHT", headerPanel, "RIGHT", -8, cfg.y)
  else
    region:SetPoint("BOTTOMLEFT", headerPanel, "TOPLEFT", 8, cfg.y + 6)
    region:SetWidth(cfg.width)
  end
end

local function ApplyHeaderLayout()
  if not headerPanel then
    return
  end

  local icon = _G.Atr_RecommendItem_Tex
  if icon then
    PlaceHeaderRegion(icon, HEADER_LAYOUT.icon)
    icon:SetSize(HEADER_LAYOUT.icon.size, HEADER_LAYOUT.icon.size)
    icon:SetShown(selectedEntry ~= nil)
  end

  if itemNameText then
    PlaceHeaderRegion(itemNameText, HEADER_LAYOUT.name)
  end

  if not emptySlot then
    local cfg = HEADER_LAYOUT.icon
    emptySlot = CreateFrame("Frame", nil, headerPanel)
    emptySlot:SetSize(cfg.size, cfg.size)
    emptySlot:SetPoint("TOPLEFT", headerPanel, "TOPLEFT", cfg.x, cfg.y)
    emptySlot:SetFrameLevel((headerPanel:GetFrameLevel() or 0) + 10)
    emptySlot.tex = emptySlot:CreateTexture(nil, "ARTWORK")
    emptySlot.tex:SetAllPoints()
    emptySlot.tex:SetTexture("Interface\\BUTTONS\\UI-Slot-Background")
    emptySlot.tex:SetTexCoord(0, 0.640625, 0, 0.640625)
    emptySlot.border = emptySlot:CreateTexture(nil, "OVERLAY")
    emptySlot.border:SetAllPoints()
    emptySlot.border:SetTexture("Interface\\Common\\WhiteIconFrame")
    emptySlot.border:SetVertexColor(0.4, 0.4, 0.4, 1)
  end
  emptySlot:SetShown(selectedEntry == nil)

  local iconCount = _G.Atr_RecommendItem_TexCount
  if iconCount then
    if selectedEntry then
      local total = selectedEntry.totalCount or selectedEntry.count or 0
      if total > 1 then
        iconCount:SetText(tostring(total))
        iconCount:Show()
      else
        iconCount:Hide()
      end
    else
      iconCount:Hide()
    end
  end

  PlaceMessageFrame(_G.AuctionatorMessageFrame)
  PlaceMessageFrame(_G.AuctionatorMessage2Frame)

  local duplicates = {
    _G.Atr_Recommend_Text,
    _G.Atr_RecommendPerStack_Text,
    _G.Atr_RecommendPerItem_Text,
    _G.Atr_RecommendPerStack_Price,
    _G.Atr_RecommendPerItem_Price,
    _G.Atr_ItemPriceText,
    _G.Atr_StackPriceText,
    _G.Atr_ItemPrice,
    _G.Atr_StackPrice,
  }
  for _, widget in ipairs(duplicates) do
    if widget then
      widget:Hide()
    end
  end

  local basis = _G.Atr_Recommend_Basis_Text
  if basis then
    basis:Hide()
  end
end

local function HideLegacySellUI()
  if not Atr_SellControls then
    return
  end

  for _, child in ipairs({Atr_SellControls:GetChildren()}) do
    if child ~= frame then
      if not child.__atrBagSellHidden then
        child.__atrBagSellHidden = true
        pcall(function()
          child:HookScript("OnShow", function(self)
            if frame and frame:IsShown() then
              self:Hide()
            end
          end)
        end)
      end
      child:Hide()
    end
  end

  for _, region in ipairs({Atr_SellControls:GetRegions()}) do
    region:Hide()
  end

  local regions = {
    AuctionatorTitle,
  }
  for _, region in ipairs(regions) do
    if region then
      if legacyHiddenRegions[region] == nil then
        legacyHiddenRegions[region] = region:IsShown()
      end
      region:Hide()
    end
  end

  ApplyHeaderLayout()
end

local function RestoreLegacySellUI()
  for region, wasShown in pairs(legacyHiddenRegions) do
    if wasShown then
      region:Show()
    end
  end
  for region in pairs(legacyHiddenRegions) do
    legacyHiddenRegions[region] = nil
  end
end

local function Say(message)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Auctionator|r " .. tostring(message))
  end
end

local function After(delay, func)
  if C_Timer and C_Timer.After then
    C_Timer.After(delay, func)
  else
    func()
  end
end

local function Money(copper)
  copper = copper or 0
  if copper <= 0 then
    return "0|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"
  end
  if GetCoinTextureString then
    return GetCoinTextureString(copper)
  end
  return tostring(copper)
end

local function GetDurationValue()
  return selectedDuration or 24
end

local function GetDurationEnum()
  local value = GetDurationValue()
  if value == 12 then
    return 1
  elseif value == 48 then
    return 3
  end
  return 2
end

local function GetQuantity()
  local value = tonumber(qtyBox:GetText()) or 0
  return math.max(0, math.floor(value))
end

local function GetUnitPrice()
  if not priceInput then
    return 0
  end
  return MoneyInputFrame_GetCopper(priceInput) or 0
end

local function ApplyUndercut(price)
  price = price or 0
  if price <= 0 then
    return 0
  end
  if Atr_CalcUndercutPrice then
    local ok, result = pcall(Atr_CalcUndercutPrice, price)
    if ok and result and result > 0 then
      return result
    end
  end
  return math.max(1, price - 1)
end

local function GetMaxQuantity(entry)
  if not entry then
    return 0
  end
  return math.max(entry.totalCount or 0, entry.count or 0)
end

local function GetSellStackSize(quantity)
  quantity = math.max(0, quantity or 0)
  if quantity <= 0 then
    return 1
  end
  if not selectedEntry or not selectedEntry.link then
    return quantity
  end
  local maxStack = select(8, GetItemInfo(selectedEntry.link))
  if type(maxStack) ~= "number" or maxStack <= 0 then
    maxStack = quantity
  end
  return math.max(1, math.min(quantity, maxStack))
end

local function IsCommodity(entry)
  if not entry or not entry.itemKey then
    return false
  end
  local ok, result = pcall(C_AuctionHouse.IsItemKeyCommodity, entry.itemKey)
  return ok and result
end

local function GetDeposit(entry, quantity)
  if not entry or not entry.location or quantity <= 0 then
    return 0
  end
  local duration = GetDurationEnum()
  if IsCommodity(entry) then
    local ok, deposit = pcall(C_AuctionHouse.CalculateCommodityDeposit, entry.itemKey.itemID, duration, quantity)
    if ok and deposit then
      return deposit
    end
    return 0
  end

  local locations = entry.locations
  if not locations or #locations == 0 then
    locations = { { location = entry.location, count = entry.count } }
  end

  local total = 0
  local remaining = quantity
  for _, info in ipairs(locations) do
    if remaining <= 0 then
      break
    end
    local count = math.min(remaining, info.count or 0)
    if count > 0 and info.location then
      local ok, deposit = pcall(C_AuctionHouse.CalculateItemDeposit, info.location, duration, count)
      if ok and deposit then
        total = total + deposit
      end
      remaining = remaining - count
    end
  end
  return total
end

local function IsAuctionThrottleReady()
  if C_AuctionHouse and C_AuctionHouse.IsThrottledMessageSystemReady then
    local ok, ready = pcall(C_AuctionHouse.IsThrottledMessageSystemReady)
    if ok then
      return ready and true or false
    end
  end
  return true
end

local ownedRefreshScheduled = false

local function RefreshOwnedAuctions()
  if not (C_AuctionHouse and C_AuctionHouse.QueryOwnedAuctions) then
    return
  end
  if not IsAuctionThrottleReady() then
    if not ownedRefreshScheduled then
      ownedRefreshScheduled = true
      After(0.5, function()
        ownedRefreshScheduled = false
        RefreshOwnedAuctions()
      end)
    end
    return
  end

  pcall(C_AuctionHouse.QueryOwnedAuctions, {})

  local function update()
    if Atr_OnAuctionOwnedUpdate then
      pcall(Atr_OnAuctionOwnedUpdate)
    end
    if Atr_IsModeActiveAuctions and Atr_IsModeActiveAuctions() and Atr_DisplayHlist then
      pcall(Atr_DisplayHlist)
    end
  end
  After(0.5, update)
  After(1.5, update)
  After(3.0, update)
end

local function CancelAuctionByID(auctionID)
  if not auctionID then
    return
  end
  if not IsAuctionThrottleReady() then
    After(0.3, function()
      CancelAuctionByID(auctionID)
    end)
    return
  end
  pcall(C_AuctionHouse.CancelAuction, auctionID)
end

local function RecordPostedAuction(entry, count, unitPrice)
  if not (entry and entry.name and count and count > 0) then
    return
  end
  if not (Atr_IsTabSelected and Atr_IsTabSelected(SELL_TAB_INDEX)) then
    return
  end
  if Atr_AddToScan then
    pcall(Atr_AddToScan, entry.name, count, unitPrice * count, 1)
  end
  if Atr_AddHistoricalPrice and entry.link then
    pcall(Atr_AddHistoricalPrice, entry.name, unitPrice, count, entry.link)
  end
end

local function UpdateTotals()
  local quantity = GetQuantity()
  local unitPrice = GetUnitPrice()
  local deposit = GetDeposit(selectedEntry, quantity)

  if summaryText then
    summaryText:SetText(string.format("%s: %s", L.commission, Money(deposit)))
  end

  if postButton then
    local canPost = not postingInProgress
      and selectedEntry ~= nil
      and quantity > 0
      and unitPrice > 0
    postButton:SetEnabled(canPost)
  end
end

local function SetMoney(frame, copper)
  if not frame then
    return
  end
  moneyUpdateDepth = moneyUpdateDepth + 1
  MoneyInputFrame_SetCopper(frame, copper or 0)
  After(0.05, function()
    moneyUpdateDepth = math.max(0, moneyUpdateDepth - 1)
  end)
end

local function SetSuggestedPrice(unitPrice)
  SetMoney(priceInput, unitPrice or 0)
  SetMoney(stackPriceInput, (unitPrice or 0) * GetSellStackSize(GetQuantity()))
  UpdateTotals()
end

local function SetSelectedRows(rows)
  selectedRows = rows
  table.sort(selectedRows, function(left, right)
    return (left.unitPrice or 0) < (right.unitPrice or 0)
  end)

  if not priceDirty then
    local suggestion
    if selectedRows[1] and selectedRows[1].unitPrice then
      suggestion = ApplyUndercut(selectedRows[1].unitPrice)
    elseif selectedEntry and gAtr_ScanDB and gAtr_ScanDB[selectedEntry.name] then
      suggestion = ApplyUndercut(gAtr_ScanDB[selectedEntry.name])
    end
    if suggestion and suggestion > 0 then
      SetSuggestedPrice(suggestion)
    end
  end
end

local function IsOwnAuctionResult(result)
  if not result then
    return false
  end
  if result.owner == "player" then
    return true
  end
  local owners = result.owners
  if type(owners) == "table" and #owners == 1 and owners[1] == "player" then
    return true
  end
  return false
end

local function ProcessItemResults(itemKey)
  if not selectedEntry or not selectedEntry.itemKey or not itemKey then
    return
  end
  if itemKey.itemID ~= selectedEntry.itemKey.itemID then
    return
  end
  if (itemKey.itemSuffix or 0) ~= (selectedEntry.itemKey.itemSuffix or 0) then
    return
  end

  local total = 0
  local ok, count = pcall(C_AuctionHouse.GetNumItemSearchResults, itemKey)
  if ok and count then
    total = count
  end

  local rows = {}
  for index = 1, total do
    local ok2, result = pcall(C_AuctionHouse.GetItemSearchResultInfo, itemKey, index)
    if ok2 and result then
      local quantity = result.quantity or 0
      local buyout = result.buyoutAmount or result.bidAmount or 0
      if quantity > 0 and buyout > 0 and not IsOwnAuctionResult(result) then
        rows[#rows + 1] = {
          unitPrice = math.floor(buyout / quantity),
          quantity = quantity,
          timeLeft = result.timeLeft,
        }
      end
    end
  end

  SetSelectedRows(rows)
end

local function ProcessCommodityResults(itemID)
  if not selectedEntry or not selectedEntry.itemKey then
    return
  end
  if itemID ~= selectedEntry.itemKey.itemID then
    return
  end

  local total = 0
  local ok, count = pcall(C_AuctionHouse.GetNumCommoditySearchResults, itemID)
  if ok and count then
    total = count
  end

  local rows = {}
  for index = 1, total do
    local ok2, result = pcall(C_AuctionHouse.GetCommoditySearchResultInfo, itemID, index)
    if ok2 and result then
      local quantity = result.quantity or 0
      local unitPrice = result.unitPrice or 0
      if quantity > 0 and unitPrice > 0 and not IsOwnAuctionResult(result) then
        rows[#rows + 1] = {
          unitPrice = unitPrice,
          quantity = quantity,
          timeLeft = result.timeLeft,
        }
      end
    end
  end

  SetSelectedRows(rows)
end

local pendingSearchEntry
local searchRetryScheduled = false

local function SendSearchNow(entry)
  if IsCommodity(entry) then
    local sortingOrder = { sortOrder = 0, reverseSort = false }
    pcall(C_AuctionHouse.SendSearchQuery, entry.itemKey, { sortingOrder }, true)
  else
    local sortingOrder = { sortOrder = 4, reverseSort = false }
    pcall(C_AuctionHouse.SendSellSearchQuery, entry.itemKey, { sortingOrder }, true)
  end
end

local function TrySendSearch()
  searchRetryScheduled = false
  local entry = pendingSearchEntry
  if not entry then
    return
  end
  if not IsAuctionThrottleReady() then
    if not searchRetryScheduled then
      searchRetryScheduled = true
      After(0.3, TrySendSearch)
    end
    return
  end
  pendingSearchEntry = nil
  SendSearchNow(entry)
end

local function SendSearch(entry)
  if not entry or not entry.itemKey then
    return
  end

  selectedRows = {}
  pendingSearchEntry = entry
  TrySendSearch()
end

local function GetQualityColor(quality)
  quality = tonumber(quality) or 1
  if _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[quality] then
    local color = _G.ITEM_QUALITY_COLORS[quality]
    if color.color then
      local r, g, b = color.color:GetRGB()
      return r, g, b
    end
    return color.r or 1, color.g or 1, color.b or 1
  end
  if GetItemQualityColor then
    local r, g, b = GetItemQualityColor(quality)
    return r or 1, g or 1, b or 1
  end
  return 1, 1, 1
end

local function UpdateCard()
  if not qtyBox or not priceInput then
    return
  end

  if not selectedEntry then
    qtyBox:SetText("0")
    qtyBox:Show()
    if qtyMaxButton then
      qtyMaxButton:Show()
    end
    if qtyPcs then
      qtyPcs:Show()
    end
    if itemNameText then
      itemNameText:SetText(L.noItem)
      itemNameText:SetTextColor(0.55, 0.55, 0.55)
    end
    SetMoney(priceInput, 0)
    SetMoney(stackPriceInput, 0)
    UpdateTotals()
    ApplyHeaderLayout()
    return
  end

  qtyBox:Show()
  if qtyMaxButton then
    qtyMaxButton:Show()
  end
  if qtyPcs then
    qtyPcs:Show()
  end
  if itemNameText then
    itemNameText:SetText(selectedEntry.name or selectedEntry.link or "")
    local r, g, b = GetQualityColor(selectedEntry.quality)
    itemNameText:SetTextColor(r, g, b)
  end

  local maxQuantity = GetMaxQuantity(selectedEntry)
  if GetQuantity() <= 0 or GetQuantity() > maxQuantity then
    qtyBox:SetText(tostring(maxQuantity))
  end

  UpdateTotals()
  ApplyHeaderLayout()
end

local function SelectLegacySellItem(entry)
  if not entry or not entry.bag or not entry.slot then
    return
  end
  local pickup = (_G.C_Container and _G.C_Container.PickupContainerItem) or PickupContainerItem
  if pickup then
    pickup(entry.bag, entry.slot)
  end
  if GetCursorInfo() ~= "item" then
    return
  end
  if Atr_ClearAll then
    pcall(Atr_ClearAll)
  end
  local button = _G.Atr_SellControls_Tex
  if Atr_ClickAuctionSellItemButton then
    pcall(Atr_ClickAuctionSellItemButton, button, "LeftButton")
  elseif ClickAuctionSellItemButton then
    pcall(ClickAuctionSellItemButton, button, "LeftButton")
  end
  ClearCursor()
end

local function SelectEntry(entry)
  if qtyBox then
    qtyBox:ClearFocus()
  end
  selectedEntry = entry
  priceDirty = false
  qtyBox:SetText(tostring(GetMaxQuantity(entry)))
  SetMoney(priceInput, 0)
  SetMoney(stackPriceInput, 0)
  UpdateCard()
  local dbPrice = gAtr_ScanDB and gAtr_ScanDB[entry.name]
  if dbPrice and dbPrice > 0 then
    SetSuggestedPrice(ApplyUndercut(dbPrice))
  end
  SelectLegacySellItem(entry)
  SendSearch(entry)
  After(0.8, function()
    if selectedEntry ~= entry or priceDirty or GetUnitPrice() > 0 then
      return
    end
    local price = gAtr_ScanDB and gAtr_ScanDB[entry.name]
    if price and price > 0 then
      SetSuggestedPrice(ApplyUndercut(price))
    end
  end)
  After(0.1, UpdateTotals)
end

local function PostSelected()
  if qtyBox then
    qtyBox:ClearFocus()
  end
  if postingInProgress then
    return
  end
  if not selectedEntry then
    Say(L.noItem)
    return
  end

  local quantity = GetQuantity()
  local maxQuantity = GetMaxQuantity(selectedEntry)
  if quantity > maxQuantity then
    quantity = maxQuantity
  end
  if quantity <= 0 then
    Say(L.noPrice)
    return
  end
  qtyBox:SetText(tostring(quantity))

  local unitPrice = GetUnitPrice()
  if unitPrice <= 0 then
    Say(L.noPrice)
    return
  end

  if not C_AuctionHouse then
    Say(L.postError)
    return
  end

  local duration = GetDurationEnum()
  local entryAtStart = selectedEntry

  local source = entryAtStart.locations
  if not source and entryAtStart.location then
    source = { { location = entryAtStart.location, count = entryAtStart.count } }
  end
  if not source or #source == 0 then
    Say(L.postError)
    return
  end

  local commodity = IsCommodity(entryAtStart)
  if commodity and not C_AuctionHouse.PostCommodity then
    Say(L.postError)
    return
  end
  if not commodity and not C_AuctionHouse.PostItem then
    Say(L.postError)
    return
  end

  local locations = {}
  for _, info in ipairs(source) do
    if info.location and (info.count or 0) > 0 then
      locations[#locations + 1] = {
        location = info.location,
        count = info.count,
        retries = 0,
      }
    end
  end
  if #locations == 0 then
    Say(L.postError)
    return
  end

  local function GetAvailable(info)
    local count = info.count or 0
    if C_AuctionHouse.GetAvailablePostCount then
      local ok, available = pcall(C_AuctionHouse.GetAvailablePostCount, info.location)
      if ok and type(available) == "number" then
        count = math.min(count, available)
      end
    end
    return count
  end

  postingInProgress = true
  UpdateTotals()

  local remaining = quantity
  local index = 1

  local function Finish()
    postingInProgress = false
    UpdateTotals()
    After(0.5, function()
      if Atr_BagSell_Refresh then
        Atr_BagSell_Refresh()
      end
      RefreshOwnedAuctions()
    end)
  end

  local function PostNext()
    if not postingInProgress then
      return
    end
    if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then
      postingInProgress = false
      UpdateTotals()
      return
    end
    if not selectedEntry or selectedEntry.key ~= entryAtStart.key then
      Finish()
      return
    end
    if remaining <= 0 then
      Finish()
      return
    end
    if not IsAuctionThrottleReady() then
      After(0.25, PostNext)
      return
    end

    if commodity then
      while index <= #locations do
        local info = locations[index]
        local count = math.min(remaining, GetAvailable(info))
        if count > 0 then
          local ok, err = pcall(C_AuctionHouse.PostCommodity, info.location, duration, count, unitPrice)
          if not ok then
            postingInProgress = false
            UpdateTotals()
            Say(L.postError .. ": " .. tostring(err))
            return
          end
          RecordPostedAuction(entryAtStart, count, unitPrice)
          remaining = remaining - count
          if remaining <= 0 then
            Finish()
          else
            index = index + 1
            After(0.15, PostNext)
          end
          return
        end
        index = index + 1
      end

      postingInProgress = false
      UpdateTotals()
      Say(L.postError .. ": not enough items")
      return
    end

    while index <= #locations do
      local info = locations[index]
      local count = GetAvailable(info)
      if count > 0 then
        local postCount = math.min(remaining, count)
        local ok, err = pcall(C_AuctionHouse.PostItem, info.location, duration, postCount, nil, unitPrice * postCount)
        if not ok then
          postingInProgress = false
          UpdateTotals()
          Say(L.postError .. ": " .. tostring(err))
          return
        end
        RecordPostedAuction(entryAtStart, postCount, unitPrice)
        remaining = remaining - postCount
        info.count = (info.count or 0) - postCount
        if info.count <= 0 then
          index = index + 1
        end
        if remaining <= 0 then
          Finish()
        else
          After(0.15, PostNext)
        end
        return
      end

      info.retries = (info.retries or 0) + 1
      if info.retries < 10 then
        After(0.3, PostNext)
        return
      end
      index = index + 1
    end

    postingInProgress = false
    UpdateTotals()
    Say(L.postError .. ": not enough items")
  end

  PostNext()
end

local function GetBagSlots(bag)
  if _G.C_Container and _G.C_Container.GetContainerNumSlots then
    return _G.C_Container.GetContainerNumSlots(bag) or 0
  end
  return GetContainerNumSlots(bag) or 0
end

local function GetBagItem(bag, slot)
  if _G.C_Container and _G.C_Container.GetContainerItemInfo then
    local info = _G.C_Container.GetContainerItemInfo(bag, slot)
    if info then
      return info.iconFileID or info.icon, info.stackCount, info.isLocked, info.quality, nil, nil, info.hyperlink
    end
  end
  return GetContainerItemInfo(bag, slot)
end

local function GetItemIDFromLink(link)
  if type(link) ~= "string" then
    return nil
  end
  return tonumber(link:match("item:(%d+)"))
end

local function ScanBags()
  local groups = {}
  local groupByClass = {}
  local blacklist = GetBlacklist()
  local blacklistGroup = {
    key = "blacklist",
    name = L.blacklist,
    order = 1000,
    items = {},
  }
  groups.blacklist = blacklistGroup

  for bag = 0, (NUM_BAG_SLOTS or 4) do
    local slots = GetBagSlots(bag)
    for slot = 1, slots do
      local texture, count, locked, quality, _, _, link = GetBagItem(bag, slot)
      if link and count and count > 0 then
        local location
        pcall(function()
          location = ItemLocation:CreateFromBagAndSlot(bag, slot)
        end)
        local valid = location and location:IsValid()
        local sellable = locked
        if not sellable and valid then
          local ok, result = pcall(C_AuctionHouse.IsSellItemValid, location, false)
          sellable = ok and result
          if not sellable then
            local ok2, result2 = pcall(C_AuctionHouse.IsSellItemValid, location, true)
            sellable = ok2 and result2
          end
        end

        if sellable then
          local itemKey
          pcall(function()
            itemKey = C_AuctionHouse.GetItemKeyFromItem(location)
          end)

          local key
          if itemKey then
            key = table.concat({
              tostring(itemKey.itemID or 0),
              tostring(itemKey.itemSuffix or 0),
              tostring(itemKey.itemLevel or 0),
              tostring(itemKey.battlePetSpeciesID or 0),
            }, ":")
          else
            key = tostring(link)
          end

          local existing = groupByClass[key]
          if existing then
            existing.totalCount = (existing.totalCount or existing.count) + count
            existing.locations = existing.locations or { { location = existing.location, count = existing.count } }
            existing.locations[#existing.locations + 1] = { location = location, count = count }
          else
            local name, _, itemQuality, _, _, classToken = GetItemInfo(link)
            local classID = select(12, GetItemInfo(link))
            if type(classID) ~= "number" then
              classID = CLASS_TOKEN_MAP[classToken]
            end

            local itemID = itemKey and itemKey.itemID or GetItemIDFromLink(link)
            local blKey = itemID or link
            local isBlacklisted = blKey and blacklist[blKey] ~= nil

            local groupKey = classID or classToken or "?"
            local order
            if isBlacklisted then
              order = 1000
            else
              order = CLASS_ORDER_INDEX[classID] or NAME_ORDER[classToken] or 99
            end

            local entry = {
              key = key,
              name = name or link,
              link = link,
              texture = texture,
              quality = itemQuality or quality,
              count = count,
              totalCount = count,
              bag = bag,
              slot = slot,
              location = location,
              locations = { { location = location, count = count } },
              itemKey = itemKey,
              itemID = itemID,
              classID = classID,
              class = classToken or "?",
              order = order,
              blacklisted = isBlacklisted,
            }

            groupByClass[key] = entry

            local group
            if isBlacklisted then
              group = blacklistGroup
            else
              group = groups[groupKey]
              if not group then
                group = {
                  key = groupKey,
                  name = classToken or "?",
                  order = order,
                  items = {},
                }
                groups[groupKey] = group
              end
            end
            group.items[#group.items + 1] = entry
          end
        end
      end
    end
  end

  if #blacklistGroup.items == 0 then
    groups.blacklist = nil
  end

  local result = {}
  for _, group in pairs(groups) do
    table.sort(group.items, function(left, right)
      return left.name < right.name
    end)
    result[#result + 1] = group
  end

  table.sort(result, function(left, right)
    if left.order == right.order then
      return left.name < right.name
    end
    return left.order < right.order
  end)

  return result, groupByClass
end

local function ClearSelection()
  selectedEntry = nil
  selectedRows = {}
  pendingSearchEntry = nil
  UpdateCard()
end

local function ScrollBags(delta)
  if not bagScroll or not bagContent then
    return
  end
  local viewHeight = bagScroll:GetHeight() or 0
  local contentHeight = bagContent:GetHeight() or 0
  local maxScroll = math.max(0, contentHeight - viewHeight)
  local offset = (bagScroll:GetVerticalScroll() or 0) - (delta or 0) * (ICON_STEP + 4)
  if offset < 0 then
    offset = 0
  elseif offset > maxScroll then
    offset = maxScroll
  end
  bagScroll:SetVerticalScroll(offset)
end

local function ToggleBlacklist(entry)
  local key = GetBlacklistKey(entry)
  if not key then
    return
  end
  local list = GetBlacklist()
  if list[key] then
    list[key] = nil
  else
    list[key] = {
      name = entry.name,
      link = entry.link,
      quality = entry.quality,
      texture = entry.texture,
    }
    if selectedEntry and selectedEntry.key == entry.key then
      ClearSelection()
    end
  end
  if Atr_BagSell_Refresh then
    Atr_BagSell_Refresh()
  end
end

local function AcquireHeader(index)
  local header = bagHeaders[index]
  if not header then
    header = CreateFrame("Button", nil, bagContent)
    header:SetHeight(18)
    header:SetPoint("RIGHT", bagContent, "RIGHT", 0, 0)
    header:EnableMouseWheel(true)
    header:SetScript("OnMouseWheel", function(_, delta)
      ScrollBags(delta)
    end)

    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.text:SetPoint("LEFT", 2, 0)
    header.text:SetJustifyH("LEFT")

    local highlight = header:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")

    header:SetScript("OnClick", function(self)
      if self.groupKey then
        collapsedGroups[self.groupKey] = not collapsedGroups[self.groupKey]
        if Atr_BagSell_Refresh then
          Atr_BagSell_Refresh()
        end
      end
    end)

    bagHeaders[index] = header
  end
  return header
end

local function AcquireButton(index)
  local button = bagButtons[index]
  if not button then
    button = CreateFrame("Button", nil, bagContent)
    button:SetSize(BAG_ICON_SIZE, BAG_ICON_SIZE)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetBackdrop({
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      edgeSize = 1,
    })

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 1, -1)
    button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button.icon)
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")

    button:SetScript("OnEnter", function(self)
      local entry = self.entry
      if not entry then
        return
      end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetBagItem(entry.bag, entry.slot)
      local price = gAtr_ScanDB and gAtr_ScanDB[entry.name]
      if price then
        GameTooltip:AddLine("Auctionator: " .. Money(price), 1, 1, 1)
      end
      GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    button:EnableMouseWheel(true)
    button:SetScript("OnMouseWheel", function(_, delta)
      ScrollBags(delta)
    end)

    button:SetScript("OnClick", function(self, mouseButton)
      if not self.entry then
        return
      end
      if mouseButton == "RightButton" then
        ToggleBlacklist(self.entry)
      else
        SelectEntry(self.entry)
      end
    end)

    bagButtons[index] = button
  end
  return button
end

function Atr_BagSell_Refresh()
  if not initialized or not bagContent then
    return
  end
  if frame and frame:IsShown() then
    HideLegacySellUI()
  end

  local groups, byKey = ScanBags()
  local y = 0
  local buttonIndex = 0
  local headerIndex = 0
  local total = 0

  for _, group in ipairs(groups) do
    total = total + #group.items

    headerIndex = headerIndex + 1
    local header = AcquireHeader(headerIndex)
    header.groupKey = group.key
    header.text:SetText(string.format("%s (%d)", group.name, #group.items))
    header:SetPoint("TOPLEFT", bagContent, "TOPLEFT", 0, y)
    header:Show()
    y = y - 20

    if not collapsedGroups[group.key] then
      for index, entry in ipairs(group.items) do
        local column = (index - 1) % BAG_COLUMNS
        local row = math.floor((index - 1) / BAG_COLUMNS)

        buttonIndex = buttonIndex + 1
        local button = AcquireButton(buttonIndex)
        button.entry = entry
        button.icon:SetTexture(entry.texture)
        local totalCount = entry.totalCount or entry.count
        button.count:SetText(totalCount > 1 and tostring(totalCount) or "")
        local qualityValue = entry.quality or select(3, GetItemInfo(entry.link)) or 1
        local r, g, b = GetQualityColor(qualityValue)
        button:SetBackdropBorderColor(r, g, b, 1)
        button:SetPoint("TOPLEFT", bagContent, "TOPLEFT", column * ICON_STEP, y - row * ICON_STEP)
        button:Show()
      end

      local rows = math.ceil(#group.items / BAG_COLUMNS)
      y = y - rows * ICON_STEP - 4
    end
  end

  for index = buttonIndex + 1, #bagButtons do
    bagButtons[index]:Hide()
  end
  for index = headerIndex + 1, #bagHeaders do
    bagHeaders[index]:Hide()
  end

  local contentHeight = math.max(1, -y + 4)
  local contentWidth = bagScroll and bagScroll:GetWidth() or 0
  if contentWidth <= 0 then
    contentWidth = BAG_COLUMNS * ICON_STEP
  end
  bagContent:SetSize(contentWidth, contentHeight)
  if bagScroll then
    local maxScroll = math.max(0, contentHeight - (bagScroll:GetHeight() or 0))
    if (bagScroll:GetVerticalScroll() or 0) > maxScroll then
      bagScroll:SetVerticalScroll(maxScroll)
    end
  end

  if selectedEntry then
    local fresh = byKey and byKey[selectedEntry.key]
    if fresh then
      selectedEntry = fresh
      local maxQuantity = GetMaxQuantity(fresh)
      if maxQuantity <= 0 then
        ClearSelection()
      else
        if GetQuantity() <= 0 or GetQuantity() > maxQuantity then
          qtyBox:SetText(tostring(maxQuantity))
        end
        UpdateCard()
      end
    else
      ClearSelection()
    end
  end
end

local function ScheduleBagRefresh()
  if bagRefreshPending then
    return
  end
  bagRefreshPending = true
  After(0.25, function()
    bagRefreshPending = false
    Atr_BagSell_Refresh()
  end)
end

local function BuildBagPanel()
  bagPanel = CreateFrame("Frame", nil, frame)
  bagPanel:SetAllPoints(frame)

  bagScroll = CreateFrame("ScrollFrame", "Atr_BagSellBagScroll", bagPanel)
  bagScroll:SetPoint("TOPLEFT", bagPanel, "TOPLEFT", 2, -2)
  bagScroll:SetPoint("BOTTOMRIGHT", bagPanel, "BOTTOMRIGHT", -2, 2)
  bagScroll:EnableMouseWheel(true)
  bagScroll:SetScript("OnMouseWheel", function(_, delta)
    ScrollBags(delta)
  end)
  pcall(function()
    bagScroll:SetClipsChildren(true)
  end)

  bagContent = CreateFrame("Frame", "Atr_BagSellBagContent", bagScroll)
  bagContent:SetSize(1, 1)
  bagScroll:SetScrollChild(bagContent)
end

local function BuildHeaderPanel()
  local itemPanel = _G.AddonCompatAuctionatorItemPanel
  headerPanel = CreateFrame("Frame", nil, frame)
  if itemPanel then
    headerPanel:SetAllPoints(itemPanel)
  else
    headerPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    headerPanel:SetSize(595, 100)
  end
  headerPanel:SetFrameLevel((frame or itemPanel):GetFrameLevel() + 5)

  itemNameText = headerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  itemNameText:SetJustifyH("LEFT")
  itemNameText:SetJustifyV("MIDDLE")
  itemNameText:SetWordWrap(false)
  itemNameText:SetText("")

  qtyBox = CreateFrame("EditBox", "Atr_BagSellQuantity", headerPanel, "InputBoxTemplate")
  qtyBox:SetSize(HEADER_LAYOUT.qtyInput.width, 20)
  qtyBox:SetPoint("TOPLEFT", HEADER_LAYOUT.qtyInput.x, HEADER_LAYOUT.qtyInput.y)
  qtyBox:SetAutoFocus(false)
  qtyBox:SetNumeric(true)
  qtyBox:SetMaxLetters(6)
  qtyBox:SetFontObject(NumberFontNormal)
  qtyBox:SetJustifyH("CENTER")
  qtyBox:SetTextInsets(2, 2, 0, 0)
  qtyBox:SetText("0")
  qtyBox:SetScript("OnTextChanged", function()
    SetMoney(stackPriceInput, GetUnitPrice() * GetSellStackSize(GetQuantity()))
    UpdateTotals()
  end)
  qtyBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  qtyBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)

  qtyMaxButton = CreateFrame("Button", nil, headerPanel, "UIPanelButtonTemplate")
  qtyMaxButton:SetSize(HEADER_LAYOUT.qtyMax.width, HEADER_LAYOUT.qtyMax.height)
  qtyMaxButton:SetPoint("TOPLEFT", HEADER_LAYOUT.qtyMax.x, HEADER_LAYOUT.qtyMax.y)
  qtyMaxButton:SetText(L.max)
  qtyMaxButton:SetScript("OnClick", function()
    if selectedEntry then
      qtyBox:SetText(tostring(GetMaxQuantity(selectedEntry)))
    end
  end)

  qtyPcs = headerPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  qtyPcs:SetPoint("LEFT", qtyBox, "RIGHT", 4, 0)
  qtyPcs:SetText(L.pcs)
  qtyPcs:SetTextColor(0.55, 0.55, 0.55)

  local function ClearQuantityFocus()
    if qtyBox then
      qtyBox:ClearFocus()
    end
  end
  local function HookFocusClear(widget)
    if not widget or not widget.HookScript then
      return
    end
    pcall(function()
      widget:EnableMouse(true)
      widget:HookScript("OnMouseDown", ClearQuantityFocus)
    end)
  end
  HookFocusClear(frame)
  HookFocusClear(headerPanel)
  HookFocusClear(bagContent)
  HookFocusClear(_G.AddonCompatAuctionatorHost)
  HookFocusClear(_G.AuctionHouseFrame)
  HookFocusClear(_G.Atr_Main_Panel)

  local stackLabel = headerPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  stackLabel:SetPoint("TOPLEFT", HEADER_LAYOUT.stackLabel.x, HEADER_LAYOUT.stackLabel.y)
  stackLabel:SetText(L.stackPrice)

  stackPriceInput = CreateFrame("Frame", "Atr_BagSellStackPrice", headerPanel, "MoneyInputFrameTemplate")
  stackPriceInput:SetPoint("TOPLEFT", HEADER_LAYOUT.stackInput.x, HEADER_LAYOUT.stackInput.y)
  stackPriceInput:SetWidth(HEADER_LAYOUT.stackInput.width)
  MoneyInputFrame_SetCopper(stackPriceInput, 0)
  if MoneyInputFrame_SetOnValueChangedFunc then
    MoneyInputFrame_SetOnValueChangedFunc(stackPriceInput, function()
      if moneyUpdateDepth > 0 then
        return
      end
      priceDirty = true
      local stackSize = GetSellStackSize(GetQuantity())
      local stackPrice = MoneyInputFrame_GetCopper(stackPriceInput) or 0
      SetMoney(priceInput, math.floor(stackPrice / stackSize))
      UpdateTotals()
    end)
  end

  local itemLabel = headerPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  itemLabel:SetPoint("TOPLEFT", HEADER_LAYOUT.itemLabel.x, HEADER_LAYOUT.itemLabel.y)
  itemLabel:SetText(L.price)

  priceInput = CreateFrame("Frame", "Atr_BagSellPriceInput", headerPanel, "MoneyInputFrameTemplate")
  priceInput:SetPoint("TOPLEFT", HEADER_LAYOUT.itemInput.x, HEADER_LAYOUT.itemInput.y)
  priceInput:SetWidth(HEADER_LAYOUT.itemInput.width)
  MoneyInputFrame_SetCopper(priceInput, 0)
  if MoneyInputFrame_SetOnValueChangedFunc then
    MoneyInputFrame_SetOnValueChangedFunc(priceInput, function()
      if moneyUpdateDepth > 0 then
        return
      end
      priceDirty = true
      SetMoney(stackPriceInput, GetUnitPrice() * GetSellStackSize(GetQuantity()))
      UpdateTotals()
    end)
  end

  local durationLabel = headerPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  durationLabel:SetPoint("TOPLEFT", HEADER_LAYOUT.durationLabel.x, HEADER_LAYOUT.durationLabel.y)
  durationLabel:SetText(L.duration)

  durationDropDown = CreateFrame("Frame", "Atr_BagSellDuration", headerPanel, "UIDropDownMenuTemplate")
  durationDropDown:SetPoint("TOPLEFT", HEADER_LAYOUT.duration.x, HEADER_LAYOUT.duration.y)
  UIDropDownMenu_SetWidth(durationDropDown, 95)
  UIDropDownMenu_Initialize(durationDropDown, function()
    local values = { 12, 24, 48 }
    for _, value in ipairs(values) do
      local text = value == 12 and L.hours12 or (value == 24 and L.hours24 or L.hours48)
      local info = UIDropDownMenu_CreateInfo()
      info.text = text
      info.value = value
      info.func = function()
        selectedDuration = value
        UIDropDownMenu_SetSelectedValue(durationDropDown, value)
        UIDropDownMenu_SetText(durationDropDown, text)
        UpdateTotals()
      end
      UIDropDownMenu_AddButton(info)
    end
  end)
  selectedDuration = 24
  UIDropDownMenu_SetSelectedValue(durationDropDown, 24)
  UIDropDownMenu_SetText(durationDropDown, L.hours24)

  summaryText = headerPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  summaryText:SetPoint("TOPLEFT", HEADER_LAYOUT.commission.x, HEADER_LAYOUT.commission.y)
  summaryText:SetWidth(HEADER_LAYOUT.commission.width)
  summaryText:SetJustifyH("LEFT")
  summaryText:SetText("")

  postButton = CreateFrame("Button", nil, headerPanel, "UIPanelButtonTemplate")
  postButton:SetSize(HEADER_LAYOUT.post.width, HEADER_LAYOUT.post.height)
  postButton:SetPoint("TOPLEFT", HEADER_LAYOUT.post.x, HEADER_LAYOUT.post.y)
  postButton:SetText(L.post)
  postButton:SetScript("OnClick", function()
    PostSelected()
  end)
  postButton:Disable()

  ApplyHeaderLayout()
end

local function EnsureFrames()
  if initialized then
    return true
  end
  if not Atr_SellControls then
    return false
  end

  frame = CreateFrame("Frame", "Atr_BagSellFrame", Atr_SellControls)
  local listPanel = _G.AddonCompatAuctionatorListPanel
  if listPanel then
    frame:SetAllPoints(listPanel)
  else
    local anchorBase = GetContentBase()
    frame:SetPoint("TOPLEFT", anchorBase, "TOPLEFT", 24, -20)
    frame:SetPoint("BOTTOMLEFT", anchorBase, "BOTTOMLEFT", 24, 30)
    frame:SetWidth(196)
  end
  local levelBase = Atr_Main_Panel or Atr_SellControls
  frame:SetFrameStrata(levelBase:GetFrameStrata())
  frame:SetFrameLevel(levelBase:GetFrameLevel() + 20)
  frame:EnableMouse(true)

  BuildHeaderPanel()
  BuildBagPanel()
  UpdateCard()
  HideLegacySellUI()

  if Atr_SetMessage and not messageHookInstalled then
    messageHookInstalled = true
    pcall(function()
      hooksecurefunc("Atr_SetMessage", function(msg)
        if frame and frame:IsShown() then
          local dragText = "Drag an item you want to sell to this area."
          if _G.ZT then
            dragText = _G.ZT("Drag an item you want to sell to this area.")
          end
          if msg and (msg == dragText or msg == "Drag an item you want to sell to this area.") then
            if _G.AuctionatorMessageFrame then _G.AuctionatorMessageFrame:Hide() end
            if _G.AuctionatorMessage2Frame then _G.AuctionatorMessage2Frame:Hide() end
          else
            HideLegacySellUI()
          end
        end
      end)
    end)
  end

  if Atr_EntryOnClick and not stackPriceHookInstalled then
    stackPriceHookInstalled = true
    pcall(function()
      hooksecurefunc("Atr_EntryOnClick", function()
        if not (frame and frame:IsShown() and selectedEntry) then
          return
        end
        if Atr_IsTabSelected and not Atr_IsTabSelected(SELL_TAB_INDEX) then
          return
        end
        After(0.05, function()
          if not selectedEntry or not _G.Atr_StackPrice then
            return
          end
          local copper = MoneyInputFrame_GetCopper(_G.Atr_StackPrice)
          local stackSize = Atr_StackSize and Atr_StackSize() or 1
          if stackSize and stackSize > 0 and copper and copper > 0 then
            local unit = math.floor(copper / stackSize)
            if unit > 0 then
              SetMoney(priceInput, unit)
              SetMoney(stackPriceInput, unit * GetSellStackSize(GetQuantity()))
              UpdateTotals()
            end
          end
        end)
      end)
    end)
  end
  if Atr_ShowItemNameAndTexture and not showItemHookInstalled then
    showItemHookInstalled = true
    pcall(function()
      hooksecurefunc("Atr_ShowItemNameAndTexture", function()
        if frame and frame:IsShown() then
          ApplyHeaderLayout()
        end
      end)
    end)
  end
  if Atr_UpdateRecommendation and not recommendHookInstalled then
    recommendHookInstalled = true
    pcall(function()
      hooksecurefunc("Atr_UpdateRecommendation", function()
        if frame and frame:IsShown() then
          ApplyHeaderLayout()
        end
      end)
    end)
  end
  if Atr_ShowElems and not showElemsHookInstalled then
    showElemsHookInstalled = true
    pcall(function()
      hooksecurefunc("Atr_ShowElems", function()
        if frame and frame:IsShown() then
          ApplyHeaderLayout()
        end
      end)
    end)
  end
  if Atr_UpdateUI_SellPane and not updateUIHookInstalled then
    updateUIHookInstalled = true
    pcall(function()
      hooksecurefunc("Atr_UpdateUI_SellPane", function()
        if frame and frame:IsShown() then
          ApplyHeaderLayout()
        end
      end)
    end)
  end
  if Atr_SelectPane and not paneHookInstalled then
    paneHookInstalled = true
    pcall(function()
      hooksecurefunc("Atr_SelectPane", function(whichTab)
        if whichTab == 2 then
          RefreshOwnedAuctions()
        end
      end)
    end)
  end
  if Atr_OnSearchComplete and not searchCompleteHookInstalled then
    searchCompleteHookInstalled = true
    pcall(function()
      hooksecurefunc("Atr_OnSearchComplete", function()
        local pane = Atr_GetCurrentPane and Atr_GetCurrentPane()
        local scan = pane and pane.activeScan
        if not scan or type(scan.scanData) ~= "table" then
          return
        end

        local player = UnitName("player")
        local changed = false
        for _, data in ipairs(scan.scanData) do
          if data.owner == "player" then
            data.owner = player
            changed = true
          end
        end

        if changed then
          if scan.CondenseAndSort then
            pcall(scan.CondenseAndSort, scan)
          end
          pane.UINeedsUpdate = true
        end
      end)
    end)
  end

  if Atr_CancelAuction and not cancelHookInstalled then
    cancelHookInstalled = true
    pcall(function()
      hooksecurefunc("Atr_CancelAuction", function(index)
        if not (C_AuctionHouse and C_AuctionHouse.GetOwnedAuctionInfo and
                C_AuctionHouse.CancelAuction) then
          return
        end
        local ok, info = pcall(C_AuctionHouse.GetOwnedAuctionInfo, index)
        if ok and info and info.auctionID then
          CancelAuctionByID(info.auctionID)
        end
      end)
    end)
  end

  pcall(function()
    Atr_SellControls:HookScript("OnShow", function()
      HideLegacySellUI()
      ScheduleBagRefresh()
    end)
    Atr_SellControls:HookScript("OnHide", function()
      After(0.1, function()
        if not Atr_SellControls:IsShown() then
          RestoreLegacySellUI()
        end
      end)
    end)
  end)

  initialized = true
  ScheduleBagRefresh()
  return true
end

local function SelectSellPane()
  if selectingSellPane then
    return false
  end
  if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then
    return false
  end
  if not AuctionHouseFrameDisplayMode or AuctionHouseFrame.displayMode ~= AuctionHouseFrameDisplayMode.Auctionator then
    return false
  end
  if not Atr_SelectPane then
    return false
  end
  if Atr_IsModeCreateAuction then
    local ok, isSell = pcall(Atr_IsModeCreateAuction)
    if ok and isSell then
      return true
    end
  end
  selectingSellPane = true
  local ok = pcall(Atr_SelectPane, SELL_TAB_INDEX)
  selectingSellPane = false
  return ok
end

local function DefaultToSellOnce()
  if not pendingSellDefault then
    return
  end
  if SelectSellPane() then
    pendingSellDefault = false
  end
end

local function InstallOuterHooks()
  local tab = _G.AuctionHouseFrameAuctionatorTab
  if tab and not tab.__atrSellHook then
    tab.__atrSellHook = true
    outerHookDone = true
    pcall(function()
      tab:HookScript("OnClick", function()
        After(0, DefaultToSellOnce)
      end)
    end)
  end

  if AuctionHouseFrame and AuctionHouseFrame.SetDisplayMode and not AuctionHouseFrame.__atrSellModeHook then
    AuctionHouseFrame.__atrSellModeHook = true
    pcall(function()
      hooksecurefunc(AuctionHouseFrame, "SetDisplayMode", function(self)
        if AuctionHouseFrameDisplayMode and self.displayMode == AuctionHouseFrameDisplayMode.Auctionator then
          After(0, DefaultToSellOnce)
        end
      end)
    end)
  end
end

local eventFrame = CreateFrame("Frame")
local searchEvents = {
  "ITEM_SEARCH_RESULTS_UPDATED",
  "COMMODITY_SEARCH_RESULTS_UPDATED",
}

local function RegisterSearchEvents()
  for _, eventName in ipairs(searchEvents) do
    pcall(eventFrame.RegisterEvent, eventFrame, eventName)
    if eventFrame.RegisterCustomEvent then
      pcall(eventFrame.RegisterCustomEvent, eventFrame, eventName)
    end
  end
end

local function RegisterEvent(name)
  pcall(eventFrame.RegisterEvent, eventFrame, name)
end

RegisterEvent("PLAYER_LOGIN")
RegisterEvent("AUCTION_HOUSE_SHOW")
RegisterEvent("AUCTION_HOUSE_CLOSED")
RegisterEvent("BAG_UPDATE")
RegisterEvent("BAG_UPDATE_DELAYED")
RegisterEvent("AUCTION_HOUSE_POST_ERROR")
RegisterEvent("AUCTION_HOUSE_POST_WARNING")
RegisterSearchEvents()

eventFrame:SetScript("OnEvent", function(self, event, ...)
  if event == "PLAYER_LOGIN" then
    EnsureFrames()
    InstallOuterHooks()
  elseif event == "AUCTION_HOUSE_SHOW" then
    EnsureFrames()
    InstallOuterHooks()
    pendingSellDefault = true
    After(0.2, DefaultToSellOnce)
    After(1.0, DefaultToSellOnce)
    After(2.0, DefaultToSellOnce)
    ScheduleBagRefresh()
    After(1.0, RefreshOwnedAuctions)
  elseif event == "AUCTION_HOUSE_CLOSED" then
    pendingSellDefault = false
    postingInProgress = false
  elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
    if initialized and frame and frame:IsShown() then
      ScheduleBagRefresh()
    end
  elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
    local itemKey = ...
    if not itemKey and selectedEntry then
      itemKey = selectedEntry.itemKey
    end
    ProcessItemResults(itemKey)
  elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
    local itemID = ...
    if not itemID and selectedEntry and selectedEntry.itemKey then
      itemID = selectedEntry.itemKey.itemID
    end
    ProcessCommodityResults(itemID)
  elseif event == "AUCTION_HOUSE_POST_ERROR" or event == "AUCTION_HOUSE_POST_WARNING" then
    Say(L.postError .. ": " .. tostring((...)))
  end
end)

local initFrame = CreateFrame("Frame")
initFrame.elapsed = 0
initFrame:SetScript("OnUpdate", function(self, elapsed)
  self.elapsed = self.elapsed + elapsed
  if self.elapsed < 1 then
    return
  end
  self.elapsed = 0
  EnsureFrames()
  InstallOuterHooks()
  if initialized and AuctionHouseFrame and AuctionHouseFrame:IsShown() then
    DefaultToSellOnce()
  end
  if initialized and outerHookDone then
    self:SetScript("OnUpdate", nil)
  end
end)
