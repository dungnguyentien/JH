-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-11-30 23:39:29
local _L = JH.LoadLangPack
JH_AutoSetTeam = {
	bAppendMark     = true,
	bRequestList    = true,
	bTeamInfo       = true,
	bAutoCancelBuff = false,
	bWorldMark      = true,
}
JH.RegisterCustomData("JH_AutoSetTeam")

local AutoSetTeam = {
	bKeepMark = true,
	bKeepForm = true,
	Mark = {},
	tMarkName = { _L["Cloud"], _L["Sword"], _L["Ax"], _L["Hook"], _L["Drum"], _L["Shear"], _L["Stick"], _L["Jade"], _L["Dart"], _L["Fan"] },
	szDataFile = "AutoSetTeam.jx3dat",
	szMarkImage = PARTY_MARK_ICON_PATH,
	tMarkFrame = PARTY_MARK_ICON_FRAME_LIST,
}

AutoSetTeam.SaveList = JH.LoadLUAData(AutoSetTeam.szDataFile) or {}

function AutoSetTeam.Save(n)
	local tList, tList2, me, team = {}, {}, GetClientPlayer(), GetClientTeam()
	if not me or not me.IsInParty() then
		return JH.Sysmsg(_L["You are not in a team"])
	end
	AutoSetTeam.SaveList[n] = {}
	AutoSetTeam.SaveList[n].szLeader = team.GetClientTeamMemberName(team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER))
	AutoSetTeam.SaveList[n].szMark = team.GetClientTeamMemberName(team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK))
	AutoSetTeam.SaveList[n].szDistribute = team.GetClientTeamMemberName(team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE))
	AutoSetTeam.SaveList[n].nLootMode = team.nLootMode
	local tMark = team.GetTeamMark()

	for nGroup = 0, team.nGroupNum - 1 do
		local tGroupInfo = team.GetGroupInfo(nGroup)
		tList2[nGroup] = {}
		for _, dwID in ipairs(tGroupInfo.MemberList) do
			local szName = team.GetClientTeamMemberName(dwID)
			local info = team.GetMemberInfo(dwID)
			if szName then
				local item = {}
				item.nGroup = nGroup
				item.nMark = tMark[dwID]
				item.bForm = dwID == tGroupInfo.dwFormationLeader
				tList[szName] = item
				table.insert(tList2[nGroup],{dwMountKungfuID = info.dwMountKungfuID, nMark = tMark[dwID], bForm = dwID == tGroupInfo.dwFormationLeader,nGroup = nGroup } )
			end
		end
	end
	-- saved ok
	AutoSetTeam.SaveList[n].data = tList
	AutoSetTeam.SaveList[n].data2 = tList2
	JH.SaveLUAData(AutoSetTeam.szDataFile,AutoSetTeam.SaveList)
	JH.Sysmsg(_L["Team list data saved"])
end
function AutoSetTeam.Delete(n)
	AutoSetTeam.SaveList[n] = nil
	JH.SaveLUAData(AutoSetTeam.szDataFile,AutoSetTeam.SaveList)
end
function AutoSetTeam.SyncMember(team, dwID, szName, state)
	if AutoSetTeam.bKeepForm and state.bForm then --如果这货之前有阵眼
		team.SetTeamFormationLeader(dwID, state.nGroup) -- 阵眼给他
		JH.Sysmsg("restore formation of " .. string.format("%d", state.nGroup + 1) .. " group: " .. szName)
	end
	if AutoSetTeam.bKeepMark and state.nMark then -- 如果这货之前有标记
		team.SetTeamMark(state.nMark, dwID) -- 标记给他
		JH.Sysmsg("restore player marked as [" .. AutoSetTeam.tMarkName[state.nMark] .. "]: " .. szName)
	end
end

function AutoSetTeam.GetWrongIndex(tWrong, bState)
	for k, v in ipairs(tWrong) do
		if not bState or v.state then
			return k
		end
	end
end

function AutoSetTeam.Restore(n)
	-- 获取自己和团队操作对象
	local me, team = GetClientPlayer(), GetClientTeam()
	-- update之前保存的团队列表
	AutoSetTeam.SaveList = JH.LoadLUAData(AutoSetTeam.szDataFile) or {}

	if not me or not me.IsInParty() then
		return JH.Sysmsg(_L["You are not in a team"])
	elseif not AutoSetTeam.SaveList[n] then
		return JH.Sysmsg(_L["You have not saved team list data"])
	end
	-- get perm
	if team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER) ~= me.dwID then
		local nGroup = team.GetMemberGroupIndex(me.dwID) + 1
		local szLeader = team.GetClientTeamMemberName(team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER))
		return JH.Sysmsg(_L["You are not team leader, permission denied"])
	end

	if team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK) ~= me.dwID then
		team.SetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK, me.dwID)
	end

	--parse wrong member
	local tSaved, tWrong, dwLeader, dwMark = AutoSetTeam.SaveList[n].data, {}, 0, 0
	for nGroup = 0, team.nGroupNum - 1 do
		tWrong[nGroup] = {}
		local tGroupInfo = team.GetGroupInfo(nGroup)
		for _, dwID in pairs(tGroupInfo.MemberList) do
			local szName = team.GetClientTeamMemberName(dwID)
			if not szName then
				JH.Sysmsg("unable get player of " .. string.format("%d", nGroup + 1) .. " group: #" .. dwID)
			else
				if not tSaved[szName] then
					szName = string.gsub(szName, "@.*", "")
				end
				local state = tSaved[szName]
				if not state then
					table.insert(tWrong[nGroup], { dwID = dwID, szName = szName, state = nil })
					JH.Sysmsg("unknown status: " .. szName)
				elseif state.nGroup == nGroup then
					AutoSetTeam.SyncMember(team, dwID, szName, state)
					JH.Sysmsg("need not adjust: " .. szName)
				else
					table.insert(tWrong[nGroup], { dwID = dwID, szName = szName, state = state })
				end
				if szName == AutoSetTeam.SaveList[n].szLeader then
					dwLeader = dwID
				end
				if szName == AutoSetTeam.SaveList[n].szMark then
					dwMark = dwID
				end
				if szName == AutoSetTeam.SaveList[n].szDistribute and dwID ~= team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE) then
					team.SetAuthorityInfo(TEAM_AUTHORITY_TYPE.DISTRIBUTE,dwID)
					JH.Sysmsg("restore distributor: " .. szName)
				end
			end
		end
	end
	-- loop to restore
	for nGroup = 0, team.nGroupNum - 1 do
		local nIndex = AutoSetTeam.GetWrongIndex(tWrong[nGroup], true)
		while nIndex do
			-- wrong user to be adjusted
			local src = tWrong[nGroup][nIndex]
			local dIndex = AutoSetTeam.GetWrongIndex(tWrong[src.state.nGroup], false)
			table.remove(tWrong[nGroup], nIndex)
			-- do adjust
			if not dIndex then
				team.ChangeMemberGroup(src.dwID, src.state.nGroup, 0) -- 直接丢过去
			else
				local dst = tWrong[src.state.nGroup][dIndex]
				table.remove(tWrong[src.state.nGroup], dIndex)
				team.ChangeMemberGroup(src.dwID, src.state.nGroup, dst.dwID)
				if not dst.state or dst.state.nGroup ~= nGroup then
					table.insert(tWrong[nGroup], dst)
				else -- bingo
					JH.Sysmsg("change group of [" .. dst.szName .. "] to " .. string.format("%d", nGroup + 1))
					AutoSetTeam.SyncMember(team, dst.dwID, dst.szName, dst.state)
				end
			end
			JH.Sysmsg("change group of [" .. src.szName .. "] to " .. string.format("%d", src.state.nGroup + 1))
			AutoSetTeam.SyncMember(team, src.dwID, src.szName, src.state)
			nIndex = AutoSetTeam.GetWrongIndex(tWrong[nGroup], true) -- update nIndex
		end
	end
	-- restore others
	if team.nLootMode ~= AutoSetTeam.SaveList[n].nLootMode then
		team.SetTeamLootMode(AutoSetTeam.SaveList[n].nLootMode)
	end
	if dwLeader ~= 0 and dwLeader ~= me.dwID then
		team.SetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER, dwLeader)
		JH.Sysmsg("restore team leader: " .. AutoSetTeam.SaveList[n].szLeader)
	end
	if dwMark  ~= 0 and dwMark ~= me.dwID then
		team.SetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK, dwMark)
		JH.Sysmsg("restore team marker: " .. AutoSetTeam.SaveList[n].szMark)
	end
	JH.Sysmsg(_L["Team list restored"])
end

function AutoSetTeam.Restore2(n)
	local me, team = GetClientPlayer(), GetClientTeam()
	AutoSetTeam.SaveList = JH.LoadLUAData(AutoSetTeam.szDataFile) or {}
	if not me or not me.IsInParty() then
		return JH.Sysmsg(_L["You are not in a team"])
	elseif not AutoSetTeam.SaveList[n] then
		return JH.Sysmsg(_L["You have not saved team list data"])
	end
	-- get perm
	if team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER) ~= me.dwID then
		local nGroup = team.GetMemberGroupIndex(me.dwID) + 1
		local szLeader = team.GetClientTeamMemberName(team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER))
		return JH.Sysmsg(_L["You are not team leader, permission denied"])
	end

	if team.GetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK) ~= me.dwID then
		team.SetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK, me.dwID)
	end

	local tSaved, tWrong, dwLeader, dwMark = AutoSetTeam.SaveList[n].data2, {}, 0, 0
	for nGroup = 0, team.nGroupNum - 1 do
		local tGroupInfo = team.GetGroupInfo(nGroup)
		for k,v in pairs(tGroupInfo.MemberList) do
			local info = team.GetMemberInfo(v)
			tWrong[v] = { nGroup = nGroup, dwMountKungfuID = info.dwMountKungfuID }
		end
	end

	local fnAction = function(dwMountKungfuID,nGroup,dwID)
		for k,v in pairs(tWrong) do
			if dwMountKungfuID and v.dwMountKungfuID == dwMountKungfuID then -- 只要内功匹配的人
				return k,v
			elseif nGroup and v.nGroup == nGroup and k ~= dwID then -- 不是自己的同组人要一个
				return k,v
			end
		end
		return false,false
	end

	for nGroup,tGroup in pairs(tSaved) do
		for k,v in ipairs(tGroup) do
			local tGroupInfo = team.GetGroupInfo(nGroup)
			local dwID,tab = fnAction(v.dwMountKungfuID)
			if dwID then
				local info = team.GetMemberInfo(dwID)
				if nGroup == tab.nGroup then
					tWrong[dwID] = nil
					JH.Sysmsg("need not adjust: " .. info.szName)
					AutoSetTeam.SyncMember(team, dwID, info.szName, v)
				else
					if #tGroupInfo.MemberList < 5 then
						team.ChangeMemberGroup(dwID,nGroup,0)
						tWrong[dwID] = nil
						JH.Sysmsg("change group of [" .. info.szName .. "] to " .. string.format("%d", nGroup + 1))
						AutoSetTeam.SyncMember(team, dwID, info.szName, v)
					else
						local ddwID,dtab = fnAction(false,nGroup,dwID)
						if ddwID then
							team.ChangeMemberGroup(dwID,nGroup,ddwID)
							tWrong[ddwID].nGroup = tab.nGroup -- update
							tWrong[dwID] = nil
							JH.Sysmsg("change group of [" .. info.szName .. "] to " .. string.format("%d", nGroup + 1))
							AutoSetTeam.SyncMember(team, dwID, info.szName, v)
						end
					end
				end
			end
		end
	end
	-- restore others
	if team.nLootMode ~= AutoSetTeam.SaveList[n].nLootMode then
		team.SetTeamLootMode(AutoSetTeam.SaveList[n].nLootMode)
	end
	if dwLeader ~= 0 and dwLeader ~= me.dwID then
		team.SetAuthorityInfo(TEAM_AUTHORITY_TYPE.LEADER, dwLeader)
		JH.Sysmsg("restore team leader: " .. AutoSetTeam.SaveList[n].szLeader)
	end
	if dwMark  ~= 0 and dwMark ~= me.dwID then
		team.SetAuthorityInfo(TEAM_AUTHORITY_TYPE.MARK, dwMark)
		JH.Sysmsg("restore team marker: " .. AutoSetTeam.SaveList[n].szMark)
	end
	JH.Sysmsg(_L["Team list restored"])
end

do
	for k,v in ipairs(AutoSetTeam.tMarkName) do
		JH.AddHotKey("AutoSetTeam" .. k,_L["Mark"] .. " [" .. v .. "]",function()
			local dwID = select(2, Target_GetTargetData())
			GetClientTeam().SetTeamMark(k, dwID)
		end)
	end
end

JH.RegisterEvent("ON_FRAME_CREATE", function()
	if JH_AutoSetTeam.bAppendMark then
		if arg0 and arg0:GetName() == "WorldMark" then
			local WorldMark = arg0
			local Wnd_WorldMark = WorldMark:Lookup("Wnd_WorldMark")
			local w,h = Wnd_WorldMark:Lookup("","Image_Bg"):GetSize()
			WorldMark:SetSize(w,h*2+22)
			Wnd_WorldMark:SetSize(w,h*2+22)
			local handle = Wnd_WorldMark:Lookup("","")
			handle:SetSize(w,h*2)
			Wnd_WorldMark:Lookup("","Image_Bg"):SetSize(w,h*2)
			handle:AppendItemFromString("<handle>w=195 h=82 name=\"Mark\"</handle>")
			local Mark = Wnd_WorldMark:Lookup("","Mark")
			Mark:SetHandleStyle(3)
			Mark:SetRelPos(5,82+22)
			handle:FormatAllItemPos()
			local tTeamMark,tMark = GetClientTeam().GetTeamMark() or {},{}
			for k,v in pairs(tTeamMark) do
				tMark[v] = true
			end
			for k,v in ipairs(AutoSetTeam.tMarkFrame) do
				Mark:AppendItemFromString(GetFormatImage(AutoSetTeam.szMarkImage,v,33,33,816,"Mark" ..k))
				local img = Mark:Lookup("Mark" ..k)
				if tMark[k] and tMark[k] ~= 0 then
					img:SetAlpha(50)
					img.alpha = 50
				else
					img:SetAlpha(180)
					img.alpha = 180
				end
				img.OnItemLButtonClick = function()
					local dwID = select(2, Target_GetTargetData())
					GetClientTeam().SetTeamMark(k, dwID)
				end
				img.OnItemRButtonClick = function()
					GetClientTeam().SetTeamMark(k, 0)
				end
				img.OnItemMouseEnter = function()
					this:SetAlpha(255)
				end
				img.OnItemMouseLeave = function()
					this:SetAlpha(this.alpha)
				end
				AutoSetTeam.Mark[k] = img
			end
			Mark:FormatAllItemPos()
			WorldMark.bAppend = true
		end
	end
end)


local function SetMark()
	if AutoSetTeam.Mark then
		local tTeamMark,tMark = GetClientTeam().GetTeamMark() or {},{}
		for k,v in pairs(tTeamMark) do
			tMark[v] = true
		end
		for k, v in ipairs(AutoSetTeam.Mark) do
			if v and v:IsValid() then
				if tMark[k] then
					v:SetAlpha(50)
					v.alpha = 50
				else
					v:SetAlpha(180)
					v.alpha = 180
				end
			end
		end
	end
end

local function GetEvent()
	if JH_AutoSetTeam.bAppendMark then
		return
			{ "PARTY_SET_MARK", SetMark }
	end
end


local PartyRequest = {
	tEquipRequest = {},
	tDetails      = {},
	szIniFile     = JH.GetAddonInfo().szRootPath .. "AutoSetTeam/ui/PartyRequest.ini",
}
PartyRequest.mt = { __call = function(me, szName)
	for k, v in ipairs(me) do
		if v.szName == szName then
			return true
		end
	end
end }
PartyRequest.tRequestList  = setmetatable({}, PartyRequest.mt)

function PartyRequest.GetFrame()
	return Station.Lookup("Normal2/PartyRequest")
end

function PartyRequest.OpenPanel()
	if not PartyRequest.GetFrame() then
		local frame = Wnd.OpenWindow(PartyRequest.szIniFile, "PartyRequest")
		PartyRequest.bg = frame:Lookup("", "Image_Bg")
		GUI(frame):Point():Title(g_tStrings.STR_ARENA_INVITE):RegisterClose(PartyRequest.ClosePanel, false, true)
	end
end

function PartyRequest.ClosePanel(bCompulsory)
	local fnAction = function()
		Wnd.CloseWindow(PartyRequest.GetFrame())
		PartyRequest.tRequestList = setmetatable({}, PartyRequest.mt)
	end
	if bCompulsory then
		fnAction()
	else
		JH.Confirm(_L["Clear list and close?"], fnAction)
	end
end
function PartyRequest.OnPeekPlayer()
	if PartyRequest.tEquipRequest[arg1] then
		if arg0 == PEEK_OTHER_PLAYER_RESPOND.SUCCESS then
			local me = GetClientPlayer()
			local dwType, dwID = me.GetTarget()
			JH.SetTarget(arg1)
			JH.SetTarget(dwType, dwID)
			local p = GetPlayer(arg1)
			if p then
				local mnt = p.GetKungfuMount()
				local data = { nil, arg1, mnt and mnt.dwSkillID or nil, false }
				PartyRequest.Feedback(p.szName, data)
			end
		end
		PartyRequest.tEquipRequest[arg1] = nil
	end
end
function PartyRequest.OnApplyRequest()
	if not JH_AutoSetTeam.bRequestList then
		return
	end
	local hMsgBox = Station.Lookup("Topmost/MB_ATMP_" .. arg0) or Station.Lookup("Topmost/MB_IMTP_" .. arg0)
	if hMsgBox then
		local btn  = hMsgBox:Lookup("Wnd_All/Btn_Option1")
		local btn2 = hMsgBox:Lookup("Wnd_All/Btn_Option2")
		if btn and btn:IsEnabled() then
			if not PartyRequest.tRequestList(arg0) then
				local tab = {
					szName  = arg0,
					nCamp   = arg1,
					dwForce = arg2,
					nLevel  = arg3,
					fnAction = function()
						pcall(btn.fnAction)
					end,
					fnCancelAction = function()
						pcall(btn2.fnAction)
					end
				}
				table.insert(PartyRequest.tRequestList, tab)
			end
			local data
			local fnGetEqueip = function(dwID)
				PartyRequest.tEquipRequest[dwID] = true
				ViewInviteToPlayer(dwID, true)
			end
			if MY_Farbnamen and MY_Farbnamen.Get then
				data = MY_Farbnamen.Get(arg0)
				if data then
					fnGetEqueip(data.dwID)
				end
			end
			if not data then
				for k, v in pairs(JH.GetAllPlayer()) do
					if v.szName == arg0 then
						fnGetEqueip(v.dwID)
						break
					end
				end
			end
			hMsgBox.fnAutoClose = nil
			hMsgBox.fnCancelAction = nil
			hMsgBox.szCloseSound = nil
			Wnd.CloseWindow(hMsgBox)
			PartyRequest.UpdateFrame()
		end
	end
end

function PartyRequest.UpdateFrame()
	if not PartyRequest.GetFrame() then
		PartyRequest.OpenPanel()
	end
	local frame = PartyRequest.GetFrame()
	-- update
	if #PartyRequest.tRequestList == 0 then
		return PartyRequest.ClosePanel(true)
	end
	local hContainer = frame:Lookup("WndContainer_Request")
	hContainer:Clear()
	local cover = "ui/Image/Common/CoverShadow.UITex"
	for k, v in ipairs(PartyRequest.tRequestList) do
		local wnd = hContainer:AppendContentFromIni(PartyRequest.szIniFile, "WndWindow_Item", k)
		local ui = GUI(wnd)
		local dat = PartyRequest.tDetails[v.szName]
		if dat and dat.dwKungfuID then
			ui:Append("Image", { x = 5, y = 5, w = 40, h = 40 }):File(Table_GetSkillIconID(dat.dwKungfuID, 1))
			if dat.nGongZhan == 1 then
				ui:Append("Image", { x = 25, y = 30, w = 15, h = 15 }):File(Table_GetBuffIconID(3219, 1))
			end
		else
			ui:Append("Image", { x = 5, y = 5, w = 40, h = 40 }):File(GetForceImage(v.dwForce))
		end
		ui:Append("Image", { x = 215, y = 15, w = 20, h = 20 }):File("ui/Image/UICommon/CommonPanel2.UITex", GetCampImageFrame(v.nCamp) or -1)
		ui:Append("Image", { x = 0, y = 42, w = 420, h = 8 }):File("ui/Image/UICommon/CommonPanel.UITex", 45)
		ui:Append("Image", "Cover", { x = 0, y = 0, w = 420, h = 50 }):File(cover, 2):Toggle(false)
		ui:Hover(function(bHover)
			if bHover then
				ui:Fetch("Cover"):File(cover, 2):Toggle(true)
			else
				ui:Fetch("Cover"):Toggle(false)
			end
		end):Raw().OnRButtonDown = function()
			local menu = {}
			InsertPlayerCommonMenu(menu, 0, v.szName)
			menu[4] = nil
			PopupMenu(menu)
		end
		if dat and dat.bEx == "Author" then
			ui:Append("Text",{ x = 47, y = 8, txt = v.szName, font = 15, color = { 255, 255, 0 } })
		else
			ui:Append("Text",{ x = 47, y = 8, txt = v.szName, font = 15  })
		end
		ui:Append("Text",{ x = 5, y = 25, txt = v.nLevel, font = 215 })
		wnd.OnLButtonDown = function()
			if IsCtrlKeyDown() then
				EditBox_AppendLinkPlayer(v.szName)
			end
		end
		ui:Append("WndButton2", { x = 240, y = 10, w = 60, h = 34, txt = g_tStrings.STR_ACCEPT }):Click(function()
			v.fnAction()
			table.remove(PartyRequest.tRequestList, k)
			PartyRequest.UpdateFrame()
		end):Hover(function(bHover)
			if bHover then
				ui:Fetch("Cover"):File(cover, 3):Toggle(true)
			else
				ui:Fetch("Cover"):Toggle(false)
			end
		end)
		ui:Append("WndButton2", { x = 305, y = 10, w = 60, h = 34, txt = g_tStrings.STR_REFUSE }):Click(function()
			v.fnCancelAction()
			table.remove(PartyRequest.tRequestList, k)
			PartyRequest.UpdateFrame()
		end):Hover(function(bHover)
			if bHover then
				ui:Fetch("Cover"):File(cover, 4):Toggle(true)
			else
				ui:Fetch("Cover"):Toggle(false)
			end
		end)
		if dat then
			ui:Append("WndButton2", "Details",{ x = 370, y = 10, w = 90, h = 34, txt = g_tStrings.STR_LOOKUP, color = { 255, 255, 0 } }):Click(function()
				ViewInviteToPlayer(dat.dwID)
			end):Hover(function(bHover)
				if bHover then
					ui:Fetch("Cover"):File(cover, 1):Toggle(true)
				else
					ui:Fetch("Cover"):Toggle(false)
				end
			end)
		else
			ui:Append("WndButton2", "Details",{ x = 370, y = 10,w = 90, h = 34, txt = _L["Details"] }):Click(function()
				JH.BgTalk(v.szName, "RL", "ASK")
				ui:Fetch("Details"):Enable(false):Text(_L["loading..."])
				JH.Sysmsg(_L["If it is always loading, the target may not install plugin or refuse."])
			end):Hover(function(bHover)
				if bHover then
					ui:Fetch("Cover"):File(cover,1):Toggle(true)
				else
					ui:Fetch("Cover"):Toggle(false)
				end
			end)
		end
	end
	local w, h = 470, 50
	local n = hContainer:GetAllContentCount()
	hContainer:SetH(h * n)
	frame:SetH(h * n + 30)
	frame:SetDragArea(0, 0, w, h * n + 30)
	PartyRequest.bg:SetH(h * n + 30)
	hContainer:FormatAllContentPos()
end

function PartyRequest.Feedback(szName, data)
	local dat = {
		dwID       = data[2],
		dwKungfuID = data[3],
		nGongZhan  = data[4],
		bEx        = data[5],
	}
	PartyRequest.tDetails[szName] = dat
	PartyRequest.UpdateFrame()
end

function PartyRequest.GetEvent()
	if JH_AutoSetTeam.bRequestList then
		return
			{ "PEEK_OTHER_PLAYER"   , PartyRequest.OnPeekPlayer   },
			{ "PARTY_INVITE_REQUEST", PartyRequest.OnApplyRequest },
			{ "PARTY_APPLY_REQUEST" , PartyRequest.OnApplyRequest }
	end
end

JH.RegisterBgMsg("RL", function(nChannel, dwID, szName, data, bIsSelf)
	if not bIsSelf then
		if data[1] == "ASK" then
			JH.Confirm(_L("[%s] want to see your info, OK?", szName), function()
				local me, nGongZhan = GetClientPlayer(), 0
				if JH.GetBuff(3219) then nGongZhan = 1 end
				if JH.bDebugClient then
					JH.BgTalk(szName, "RL", "Feedback", me.dwID, UI_GetPlayerMountKungfuID(), nGongZhan, "Author")
				else
					JH.BgTalk(szName, "RL", "Feedback", me.dwID, UI_GetPlayerMountKungfuID(), nGongZhan, "Player")
				end
			end)
		elseif data[1] == "Feedback" then
			PartyRequest.Feedback(szName, data)
		end
	end
end)
-- TI 面板部分
local TI = {}
function TI.SaveList()
	JH.SaveLUAData("TI/YY.jx3dat", TI.tList, "\t", false)
end

function TI.GetList()
	if not TI.tList then
		TI.tList = JH.LoadLUAData("TI/YY.jx3dat") or {}
	end
	return TI.tList
end

function TI.GetEvent()
	if JH_AutoSetTeam.bTeamInfo then
		return
			{ "PARTY_LEVEL_UP_RAID", function()
				if JH.IsLeader() then
					JH.Confirm(_L["Edit team info?"], function()
						TI.CreateFrame()
					end)
				end
			end },
			{ "FIRST_LOADING_END", function()
				-- 不存在队长不队长的问题了
				local me = GetClientPlayer()
				if me.IsInRaid() then
					JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "TI", "ASK")
				end
			end }
	end
end

function TI.GetFrame()
	return Station.Lookup("Normal/JH_TeamInfo")
end

JH.RegisterBgMsg("TI", function(nChannel, dwID, szName, data, bIsSelf)
	if not bIsSelf then
		local me = GetClientPlayer()
		local team = GetClientTeam()
		if team then
			if data[1] == "ASK" and JH.IsLeader() then
				if TI.GetFrame() then
					JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "TI", "reply", szName, TI.szYY, TI.szNote)
				end
			elseif data[1] == "Edit" then
				TI.CreateFrame(data[2], data[3])
			elseif data[1] == "reply" and (tonumber(data[2]) == UI_GetClientPlayerID() or data[2] == me.szName) then
				if JH.Trim(data[3]) ~= "" or JH.Trim(data[4]) ~= "" then
					TI.CreateFrame(data[3], data[4])
				end
			end
		end
	end
end)

function TI.CreateFrame(a, b)
	local an = { s = "CENTER", r = "CENTER", x = 0, y = 0 }
	if TI.GetFrame() then
		an = GetFrameAnchor(TI.GetFrame())
	end
	local ui = GUI.CreateFrame("JH_TeamInfo", { w = 320, h = 195, close = true, title = _L["Team Message"], nStyle = 2 }):Point(an.s, 0, 0, an.r, an.x, an.y)
	local nX, nY = ui:Append("Text", { x = 10, y = 5, txt = _L["YY:"], font = 48 }):Pos_()
	nX = ui:Append("WndEdit", "YY", { w = 160, h = 26, x = nX + 5, y = 5, font = 48, color = { 128, 255, 0 }, txt = a }):Autocomplete(function()
		TI.tList = TI.GetList()
		local tList = {}
		for k, v in pairs(TI.tList) do
			table.insert(tList, k)
		end
		return tList
	end, nil, function(szText)
		TI.tList[tonumber(szText)] = nil
		TI.SaveList()
	end):Change(function(szText)
		if JH.IsLeader() then
			TI.szYY = szText
			JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "TI", "Edit", szText, ui:Fetch("Message"):Text())
		else
			ui:Fetch("YY"):Text(TI.szYY, true)
		end
	end):Pos_()
	nX, nY = ui:Append("WndButton2", { x = nX + 5, y = 5, txt = _L["Paste YY"]}):Click(function()
		local yy = ui:Fetch("YY"):Text()
		if tonumber(yy) then
			TI.tList = TI.GetList()
			if not TI.tList[tonumber(yy)] then
				TI.tList[tonumber(yy)] = true
				TI.SaveList()
			end
		end
		if yy ~= "" then
			for i = 0, 2 do -- 发三次
				JH.Talk(yy)
			end
		end
	end):Pos_()
	ui:Append("WndEdit", "Message", { w = 300, h = 80, x = 10, y = nY + 5, multi = true, limit = 512, txt = b}):Change(function(szText)
		if JH.IsLeader() then
			TI.szNote = szText
			JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "TI", "Edit", ui:Fetch("YY"):Text(), szText)
		else
			ui:Fetch("Message"):Text(TI.szNote, true)
		end
	end)
	nX, nY = 5, 130
	if RaidTools then
		nX = ui:Append("WndButton2", { x = nX, y = nY, txt = _L["Raid Tools"] }):Click(RaidTools.TogglePanel):Pos_()
	end
	if GKP then
		nX = ui:Append("WndButton2", { x = nX + 5, y = nY, txt = _L["GKP Golden Team Record"] }):Click(GKP.TogglePanel):Pos_()
	end
	if DBM_RemoteRequest then
		nX = ui:Append("WndButton2", { x = nX + 5, y = nY, txt = _L["Import Data"] }):Click(DBM_RemoteRequest.TogglePanel):Pos_()
	end
	TI.szYY   = ui:Fetch("YY"):Text()
	TI.szNote = ui:Fetch("Message"):Text()
	ui:Setting(function() JH.OpenPanel(_L["AutoSetTeam"]) end)
	-- 注册事件
	local frame = TI.GetFrame()
	frame.OnFrameKeyDown = nil -- esc close --> nil
	frame:RegisterEvent("PARTY_DISBAND")
	frame:RegisterEvent("PARTY_DELETE_MEMBER")
	frame:RegisterEvent("PARTY_ADD_MEMBER")
	frame.OnEvent = function(szEvent)
		if szEvent == "PARTY_DISBAND" then
			ui:Remove()
		elseif szEvent == "PARTY_DELETE_MEMBER" then
			if arg1 == UI_GetClientPlayerID() then
				ui:Remove()
			end
		elseif szEvent == "PARTY_ADD_MEMBER" then
			if JH.IsLeader() then
				JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "TI", "reply", arg1, TI.szYY, TI.szNote)
			end
		end
	end
end

JH.AddonMenu(function()
	return {
		szOption = _L["Team Message"], fnDisable = function() local me = GetClientPlayer(); return not me.IsInRaid() end, fnAction = function()
			local me = GetClientPlayer()
			JH_AutoSetTeam.bTeamInfo = true
			JH.RegisterInit("TI", TI.GetEvent())
			if me.IsInRaid() then
				if JH.IsLeader() then
					TI.CreateFrame()
				else
					JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "TI", "ASK")
					JH.Sysmsg(_L["Asking..., If no response in longtime, team leader not enable plug-in."])
				end
			end
		end
	}
end)
-------------------------------------------------------------------------
local AutoCancelBuff = {}

local KUNGFU = {
	[10062] = true,
	[10002] = true,
	[10243] = true,
	[10389] = true,
}

local BUFF = {
	-- [103] = true,
	[8422] = true,
	[4487] = true,
	[4101] = true,
	[3098] = true,
	[917] =  true,
	[926] =  true,
}

function AutoCancelBuff.CheckKungFu()
	if KUNGFU[UI_GetPlayerMountKungfuID()] then
		return true
	end
end

function AutoCancelBuff.GetEvent()
	if JH_AutoSetTeam.bAutoCancelBuff then
		if AutoCancelBuff.CheckKungFu() then
			return { "BUFF_UPDATE", AutoCancelBuff.OnBuff }
		end
	end
end

function AutoCancelBuff.Init()
	JH.RegisterInit("AutoCancelBuff", AutoCancelBuff.GetEvent())
end

-- buff update
-- arg0：dwPlayerID，arg1：bDelete，arg2：nIndex，arg3：bCanCancel
-- arg4：dwBuffID，arg5：nStackNum，arg6：nEndFrame，arg7：update all?
-- arg8：nLevel，arg9：dwSkillSrcID
function AutoCancelBuff.OnBuff()
	if BUFF[arg4] and not arg1 then
		if AutoCancelBuff.CheckKungFu() then -- 命中后再次判断
			GetClientPlayer().CancelBuff(arg2)
		end
	end
end
-------------------------------------------------------------------------
-- 工资结算
local TEAM_VOTE_REQUEST = {}
JH.RegisterEvent("TEAM_VOTE_REQUEST", function()
	if arg0 == 1 then
		TEAM_VOTE_REQUEST = {}
		local team = GetClientTeam()
		for k, v in ipairs(team.GetTeamMemberList()) do
			TEAM_VOTE_REQUEST[v] = false
		end
	end
end)

JH.RegisterEvent("TEAM_VOTE_RESPOND", function()
	if arg0 == 1 and not IsEmpty(TEAM_VOTE_REQUEST) then
		if arg2 == 1 then
			TEAM_VOTE_REQUEST[arg1] = true
		end
		local team  = GetClientTeam()
		local num   = team.GetTeamSize()
		local agree = 0
		for k, v in pairs(TEAM_VOTE_REQUEST) do
			if v then
				agree = agree + 1
			end
		end
		JH.Topmsg(_L("Team Members: %d, %d agree %d%%", num, agree, agree / num * 100))
	end
end)

JH.RegisterEvent("TEAM_INCOMEMONEY_CHANGE_NOTIFY", function()
	local nTotalRaidMoney = GetClientTeam().nInComeMoney
	if nTotalRaidMoney and nTotalRaidMoney == 0 then
		TEAM_VOTE_REQUEST = {}
	end
end)

-------------------------------------------------------------------------
local WorldMark = {
	tMark = {
		[20107] = { id = 1,  col = { 255, 255, 255 } },
		[20108] = { id = 2,  col = { 255, 128, 0   } },
		[20109] = { id = 3,  col = { 0  , 0  , 255 } },
		[20110] = { id = 4,  col = { 0  , 255, 0   } },
		[20111] = { id = 5,  col = { 255, 0  , 0   } },
		[36781] = { id = 6,  col = { 50 , 220, 255 } },
		[36782] = { id = 7,  col = { 255, 100, 220 } },
		[36783] = { id = 8,  col = { 255, 255, 0   } },
		[36784] = { id = 9,  col = { 200, 40,  255 } },
		[36785] = { id = 10, col = { 30,  255, 180 } },
	},
	tPoint = {},
	hShadow = JH.GetAddonInfo().szShadowIni,
}

function WorldMark.GetEvent()
	if JH_AutoSetTeam.bWorldMark then
		return
			{ "DO_SKILL_CAST", function()
				WorldMark.OnCast(arg1)
			end },
			{ "NPC_LEAVE_SCENE", WorldMark.OnNpcLeave },
			{ "NPC_ENTER_SCENE", WorldMark.OnNpcEvent },
			{ "LOADING_END", function()
				WorldMark.tPoint = {}
				JH.GetShadowHandle("Handle_World_Mark"):Clear()
			end }
	else
		WorldMark.OnCast(4906)
	end
end

function WorldMark.OnNpcEvent()
	local npc = GetNpc(arg0)
	if npc then
		local mark = WorldMark.tMark[npc.dwTemplateID]
		if mark then
			local tPoint = { npc.nX, npc.nY, npc.nZ }
			local handle = JH.GetShadowHandle("Handle_World_Mark")
			local szName = "w_" .. mark.id
			if handle:Lookup(szName) then
				handle:RemoveItem(szName)
			end
			WorldMark.tPoint[mark.id] = tPoint
		end
	end
end

function WorldMark.OnNpcLeave()
	local npc = GetNpc(arg0)
	if npc then
		local mark = WorldMark.tMark[npc.dwTemplateID]
		if mark then
			local tPoint = WorldMark.tPoint[mark.id]
			if tPoint then
				local handle = JH.GetShadowHandle("Handle_World_Mark")
				local szName = "w_" .. mark.id
				local sha = handle:Lookup(szName) or handle:AppendItemFromIni(WorldMark.hShadow, "shadow", szName)
				WorldMark.Draw(tPoint, sha, mark.col)
			end
		end
	end
end

function WorldMark.OnCast(dwSkillID)
	if dwSkillID == 4906 then
		WorldMark.tPoint = {}
		JH.GetShadowHandle("Handle_World_Mark"):Clear()
	end
end

function WorldMark.Draw(Point, sha, col)
	local nRadius = 64
	local nFace = 128
	local dwRad1 = math.pi
	local dwRad2 = 3 * math.pi + math.pi / 20
	local r, g, b = unpack(col)
	local nX, nY, nZ = unpack(Point)
	sha:SetTriangleFan(GEOMETRY_TYPE.TRIANGLE)
	sha:SetD3DPT(D3DPT.TRIANGLEFAN)
	sha:ClearTriangleFanPoint()
	sha:AppendTriangleFan3DPoint(nX ,nY, nZ, r, g, b, 80)
	sha:Show()
	local sX, sZ = Scene_PlaneGameWorldPosToScene(nX, nY)
	repeat
		local sX_, sZ_ = Scene_PlaneGameWorldPosToScene(nX + math.cos(dwRad1) * nRadius, nY + math.sin(dwRad1) * nRadius)
		sha:AppendTriangleFan3DPoint(nX ,nY, nZ, r, g, b, 80, { sX_ - sX, 0, sZ_ - sZ })
		dwRad1 = dwRad1 + math.pi / 16
	until dwRad1 > dwRad2
end
-------------------------------------------------------------------------

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["AutoSetTeam"], font = 27 }):Pos_()
	ui:Append("WndCheckBox", { x = 10, y = nY + 10, checked = JH_AutoSetTeam.bAppendMark, txt = _L["Append Mark"] }):Click(function(bChecked)
		JH_AutoSetTeam.bAppendMark = bChecked
		JH.RegisterInit("Append_Mark", GetEvent())
	end)
	nX, nY = ui:Append("WndCheckBox", { x = 230, y = nY + 10, checked = JH_AutoSetTeam.bRequestList, txt = _L["RequestList"] }):Click(function(bChecked)
		JH_AutoSetTeam.bRequestList = bChecked
		JH.RegisterInit("RequestList", PartyRequest.GetEvent())
	end):Pos_()
	ui:Append("WndCheckBox", { x = 10, y = nY, checked = JH_AutoSetTeam.bTeamInfo, txt = _L["Team Message"] }):Click(function(bChecked)
		JH_AutoSetTeam.bTeamInfo = bChecked
		JH.RegisterInit("TI", TI.GetEvent())
	end)
	-- nX, nY = ui:Append("WndCheckBox", { x = 230, y = nY, checked = JH_AutoSetTeam.bAutoCancelBuff, txt = _L["AutoCancelBuff"] }):Click(function(bChecked)
		-- JH_AutoSetTeam.bAutoCancelBuff = bChecked
		-- AutoCancelBuff.Init()
	-- end):Pos_()
	nX, nY = ui:Append("WndCheckBox", { x = 230, y = nY, checked = JH_AutoSetTeam.bWorldMark, txt = _L["WorkMark Enhance"] }):Click(function(bChecked)
		JH_AutoSetTeam.bWorldMark = bChecked
		JH.RegisterInit("WorldMark", WorldMark.GetEvent())
	end):Pos_()

	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Mark Target"], font = 27 }):Pos_()
	nX,nY = ui:Append("WndButton2", { x = 10, y = nY + 15, txt = _L["Hotkey"] }):Click(JH.SetHotKey):Pos_()
	nX,nY = ui:Append("Text", { x = 0, y = nY, txt = _L["SetTeam"], font = 27 }):Pos_()
	nY = nY + 10
	for i = 1,5 do
		local bEnable = false
		if AutoSetTeam.SaveList[i] then
			bEnable = true
		end
		nX = ui:Append("Text", { x = 0, y = nY, txt = _L("Team %d:",i)}):Pos_()
		nX = ui:Append("WndButton2", { x = nX + 5, y = nY, txt = _L["Save Team"]})
		:Enable(not bEnable):Click(function()
			AutoSetTeam.Save(i)
			JH.OpenPanel(_L["AutoSetTeam"])
		end):Pos_()
		local _nY = nY

		nX,nY = ui:Append("WndButton2", { x = nX + 5, y = nY, txt = _L["Recovery Team"]})
		:Enable(bEnable):Click(function()
			if IsCtrlKeyDown() then
				AutoSetTeam.Restore2(i)
			else
				AutoSetTeam.Restore(i)
			end
		end):Pos_()
		if bEnable then
			nX = ui:Append("WndComboBox", { x = nX + 5, y = _nY,w = 130, h = 30 , txt = _L["View Team"]})
			:Menu(function()
				local menu = {}
				local t = AutoSetTeam.SaveList[i]
				table.insert(menu,{szOption = _L("Leader:%s",t["szLeader"])})
				table.insert(menu,{szOption = _L("Distribute:%s",t["szDistribute"])})
				table.insert(menu,{szOption = _L("Mark:%s",t["szMark"])})
				table.insert(menu,{bDevide = true})
				for i = 1,5 do
					table.insert(menu,{szOption = _L("Party %d",i)})
				end
				for kk,vv in pairs(t["data"]) do
					table.insert(menu[5 + vv.nGroup],{szOption = kk})
				end
				return menu
			end):Pos_()
			ui:Append("WndButton2", { x = nX + 5, y = _nY, txt = g_tStrings.STR_FRIEND_DEL})
			:Enable(bEnable):Click(function()
				AutoSetTeam.Delete(i)
				JH.OpenPanel(_L["AutoSetTeam"])
			end)

		end
	end
end

GUI.RegisterPanel(_L["AutoSetTeam"], 5962, g_tStrings.CHANNEL_CHANNEL, PS)

JH.RegisterEvent("LOGIN_GAME", function()
	JH.RegisterInit("RequestList", PartyRequest.GetEvent())
	JH.RegisterInit("Append_Mark", GetEvent())
	JH.RegisterInit("TI", TI.GetEvent())
	JH.RegisterInit("WorldMark", WorldMark.GetEvent())
end)

-- 注销了代码就懒得删了
-- JH.RegisterEvent("LOADING_END", AutoCancelBuff.Init)
-- JH.RegisterEvent("SKILL_MOUNT_KUNG_FU", AutoCancelBuff.Init)
