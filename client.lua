local Keys = {
	["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57,
	["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177,
	["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
	["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
	["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
	["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70,
	["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
	["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
	["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
}

local PlayerData                = {}
local GUI                       = {}
local HasAlreadyEnteredMarker   = false
local LastZone                  = nil
local CurrentAction             = nil
local CurrentActionMsg          = ''
local CurrentActionData         = {}
local OnJob                     = false
local CurrentCustomer           = nil
local CurrentCustomerBlip       = nil
local DestinationBlip           = nil
local IsNearCustomer            = false
local CustomerIsEnteringVehicle = false
local CustomerEnteredVehicle    = false
local TargetCoords              = nil
local CurrentlyTowedVehicle   = nil
local Blips                   = {}
local NPCOnJob                = false
local NPCTargetTowable         = nil
local NPCTargetTowableZone     = nil
local NPCHasSpawnedTowable    = false
local NPCLastCancel           = GetGameTimer() - 5 * 60000
local NPCHasBeenNextToTowable = false
local NPCTargetDeleterZone    = false

ESX                           = nil
GUI.Time                      = 0

ESX                             = nil
GUI.Time                        = 0

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
end)

function DrawSub(msg, time)
	ClearPrints()
	SetTextEntry_2("STRING")
	AddTextComponentString(msg)
	DrawSubtitleTimed(time, 1)
end

function ShowLoadingPromt(msg, time, type)
	Citizen.CreateThread(function()
		Citizen.Wait(0)
		N_0xaba17d7ce615adbf("STRING")
		AddTextComponentString(msg)
		N_0xbd12f8228410d9b4(type)
		Citizen.Wait(time)
		N_0x10d373323e5b9c0d()
	end)
end

function GetRandomWalkingNPC()

	local search = {}
	local peds   = ESX.Game.GetPeds()

	for i=1, #peds, 1 do
		if IsPedHuman(peds[i]) and IsPedWalking(peds[i]) and not IsPedAPlayer(peds[i]) then
			table.insert(search, peds[i])
		end
	end

	if #search > 0 then
		return search[GetRandomIntInRange(1, #search)]
	end

	print('Using fallback code to find walking ped')

	for i=1, 250, 1 do

		local ped = GetRandomPedAtCoord(0.0,  0.0,  0.0,  math.huge + 0.0,  math.huge + 0.0,  math.huge + 0.0,  26)

		if DoesEntityExist(ped) and IsPedHuman(ped) and IsPedWalking(ped) and not IsPedAPlayer(ped) then
			table.insert(search, ped)
		end

	end

	if #search > 0 then
		return search[GetRandomIntInRange(1, #search)]
	end

end

function ClearCurrentMission()

	if DoesBlipExist(CurrentCustomerBlip) then
		RemoveBlip(CurrentCustomerBlip)
	end

	if DoesBlipExist(DestinationBlip) then
		RemoveBlip(DestinationBlip)
	end

	CurrentCustomer           = nil
	CurrentCustomerBlip       = nil
	DestinationBlip           = nil
	IsNearCustomer            = false
	CustomerIsEnteringVehicle = false
	CustomerEnteredVehicle    = false
	TargetCoords              = nil

end

function StartTaxiJob()

	ShowLoadingPromt(_U('taking_service') .. 'Taxi/Uber', 5000, 3)
	ClearCurrentMission()

	OnJob = true

end

function StopTaxiJob()

	local playerPed = GetPlayerPed(-1)

	if IsPedInAnyVehicle(playerPed, false) and CurrentCustomer ~= nil then
		local vehicle = GetVehiclePedIsIn(playerPed,  false)
		TaskLeaveVehicle(CurrentCustomer,  vehicle,  0)

		if CustomerEnteredVehicle then
			TaskGoStraightToCoord(CurrentCustomer,  TargetCoords.x,  TargetCoords.y,  TargetCoords.z,  1.0,  -1,  0.0,  0.0)
		end

	end

	ClearCurrentMission()

	OnJob = false

	DrawSub(_U('mission_complete'), 5000)

end

function OpenTaxiActionsMenu()

	local elements = {
		{label = _U('spawn_veh'), value = 'spawn_vehicle'},
		{label = _U('deposit_stock'), value = 'put_stock'},
		{label = _U('take_stock'), value = 'get_stock'}
	}

	if Config.EnablePlayerManagement and PlayerData.job ~= nil and PlayerData.job.grade_name == 'boss' then
		table.insert(elements, {label = _U('boss_actions'), value = 'boss_actions'})
	end

	ESX.UI.Menu.CloseAll()

	ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'taxi_actions',
		{
			title    = 'Taxi',
			elements = elements
		},
		function(data, menu)

			if data.current.value == 'put_stock' then
				OpenPutStocksMenu()
			end

			if data.current.value == 'get_stock' then
				OpenGetStocksMenu()
			end

			if data.current.value == 'spawn_vehicle' then

				if Config.EnableSocietyOwnedVehicles then

					local elements = {}

					ESX.TriggerServerCallback('esx_society:getVehiclesInGarage', function(vehicles)

							for i=1, #vehicles, 1 do
								table.insert(elements, {label = GetDisplayNameFromVehicleModel(vehicles[i].model) .. ' [' .. vehicles[i].plate .. ']', value = vehicles[i]})
							end

							ESX.UI.Menu.Open(
								'default', GetCurrentResourceName(), 'vehicle_spawner',
								{
									title    = _U('spawn_veh'),
									align    = 'top-left',
									elements = elements,
								},
								function(data, menu)

									menu.close()

									local vehicleProps = data.current.value

									ESX.Game.SpawnVehicle(vehicleProps.model, Config.Zones.VehicleSpawnPoint.Pos, 270.0, function(vehicle)
										ESX.Game.SetVehicleProperties(vehicle, vehicleProps)
										local playerPed = GetPlayerPed(-1)
										TaskWarpPedIntoVehicle(playerPed,  vehicle,  -1)
									end)

									TriggerServerEvent('esx_society:removeVehicleFromGarage', 'taxi', vehicleProps)

								end,
								function(data, menu)
									menu.close()
								end
							)

					end, 'taxi')

				else

					menu.close()

					if Config.MaxInService == -1 then

						local playerPed = GetPlayerPed(-1)
						local coords    = Config.Zones.VehicleSpawnPoint.Pos

						ESX.Game.SpawnVehicle('taxi', coords, 225.0, function(vehicle)
							TaskWarpPedIntoVehicle(playerPed,  vehicle, -1)
						end)

					else

						ESX.TriggerServerCallback('esx_service:enableService', function(canTakeService, maxInService, inServiceCount)

								if canTakeService then

									local playerPed = GetPlayerPed(-1)
									local coords    = Config.Zones.VehicleSpawnPoint.Pos

									ESX.Game.SpawnVehicle('taxi', coords, 225.0, function(vehicle)
										TaskWarpPedIntoVehicle(playerPed,  vehicle, -1)
									end)

								else

									ESX.ShowNotification(_U('full_service') .. inServiceCount .. '/' .. maxInService)

								end

						end, 'taxi')

					end

				end

			end

			if data.current.value == 'boss_actions' then
				TriggerEvent('esx_society:openBossMenu', 'taxi', function(data, menu)
					menu.close()
				end)
			end

		end,
		function(data, menu)

			menu.close()

			CurrentAction     = 'taxi_actions_menu'
			CurrentActionMsg  = _U('press_to_open')
			CurrentActionData = {}

		end
	)

end

function OpenMobileTaxiActionsMenu()

	ESX.UI.Menu.CloseAll()

	ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'mobile_taxi_actions',
		{
			title    = 'Taxi',
			elements = {
				{label = _U('billing'), value = 'billing'}
			}
		},
		function(data, menu)

			if data.current.value == 'billing' then

				ESX.UI.Menu.Open(
					'dialog', GetCurrentResourceName(), 'billing',
					{
						title = _U('invoice_amount')
					},
					function(data, menu)

						local amount = tonumber(data.value)

						if amount == nil then
							ESX.ShowNotification(_U('amount_invalid'))
						else

							menu.close()

							local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()

							if closestPlayer == -1 or closestDistance > 3.0 then
								ESX.ShowNotification(_U('no_players_near'))
							else
								TriggerServerEvent('esx_billing:sendBill', GetPlayerServerId(closestPlayer), 'society_taxi', 'Taxi', amount)
							end

						end

					end,
					function(data, menu)
						menu.close()
					end
				)

			end

		end,
		function(data, menu)
			menu.close()
		end
	)

end

function OpenGetStocksMenu()

	ESX.TriggerServerCallback('esx_taxijob:getStockItems', function(items)

			print(json.encode(items))

			local elements = {}

			for i=1, #items, 1 do
				table.insert(elements, {label = 'x' .. items[i].count .. ' ' .. items[i].label, value = items[i].name})
			end

			ESX.UI.Menu.Open(
				'default', GetCurrentResourceName(), 'stocks_menu',
				{
					title    = 'Taxi Stock',
					elements = elements
				},
				function(data, menu)

					local itemName = data.current.value

					ESX.UI.Menu.Open(
						'dialog', GetCurrentResourceName(), 'stocks_menu_get_item_count',
						{
							title = _U('quantity')
						},
						function(data2, menu2)

							local count = tonumber(data2.value)

							if count == nil then
								ESX.ShowNotification(_U('quantity_invalid'))
							else
								menu2.close()
								menu.close()
								OpenGetStocksMenu()

								TriggerServerEvent('esx_taxijob:getStockItem', itemName, count)
							end

						end,
						function(data2, menu2)
							menu2.close()
						end
					)

				end,
				function(data, menu)
					menu.close()
				end
			)

	end)

end

function OpenPutStocksMenu()

	ESX.TriggerServerCallback('esx_taxijob:getPlayerInventory', function(inventory)

			local elements = {}

			for i=1, #inventory.items, 1 do

				local item = inventory.items[i]

				if item.count > 0 then
					table.insert(elements, {label = item.label .. ' x' .. item.count, type = 'item_standard', value = item.name})
				end

			end

			ESX.UI.Menu.Open(
				'default', GetCurrentResourceName(), 'stocks_menu',
				{
					title    = _U('inventory'),
					elements = elements
				},
				function(data, menu)

					local itemName = data.current.value

					ESX.UI.Menu.Open(
						'dialog', GetCurrentResourceName(), 'stocks_menu_put_item_count',
						{
							title = _U('quantity')
						},
						function(data2, menu2)

							local count = tonumber(data2.value)

							if count == nil then
								ESX.ShowNotification(_U('quantity_invalid'))
							else
								menu2.close()
								menu.close()
								OpenPutStocksMenu()

								TriggerServerEvent('esx_taxijob:putStockItems', itemName, count)
							end

						end,
						function(data2, menu2)
							menu2.close()
						end
					)

				end,
				function(data, menu)
					menu.close()
				end
			)

	end)

end


RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
	PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	PlayerData.job = job
end)

AddEventHandler('esx_taxijob:hasEnteredMarker', function(zone)

		if zone == 'TaxiActions' then
			CurrentAction     = 'taxi_actions_menu'
			CurrentActionMsg  = _U('press_to_open')
			CurrentActionData = {}
		end

		if zone == 'VehicleDeleter' then

			local playerPed = GetPlayerPed(-1)
			local vehicle = GetVehiclePedIsIn(playerPed, false)

			if IsPedInAnyVehicle(playerPed,  false) then
				CurrentAction     = 'delete_vehicle'
				CurrentActionMsg  = _U('store_veh')
				CurrentActionData = { vehicle = vehicle }
			end

		end

end)

AddEventHandler('esx_taxijob:hasExitedMarker', function(zone)
	ESX.UI.Menu.CloseAll()
	CurrentAction = nil
end)

RegisterNetEvent('esx_phone:loaded')
AddEventHandler('esx_phone:loaded', function(phoneNumber, contacts)

		local specialContact = {
			name       = 'Taxi',
			number     = 'taxi',
			base64Icon = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAGGElEQVR4XsWWW2gd1xWGv7Vn5pyRj47ut8iOYlmyWxw1KSZN4riOW6eFuCYldaBtIL1Ag4NNmt5ICORCaNKXlF6oCy0hpSoJKW4bp7Sk6YNb01RuLq4d0pQ0kWQrshVJ1uX46HJ0zpy5rCKfQYgjCUs4kA+GtTd786+ftW8jqsqHibB6TLZn2zeq09ZTWAIWCxACoTI1E+6v+eSpXwHRqkVZPcmqlBzCApLQ8dk3IWVKMQlYcHG81OODNmD6D7d9VQrTSbwsH73lFKePtvOxXSfn48U+Xpb58fl5gPmgl6DiR19PZN4+G7iODY4liIAACqiCHyp+AFvb7ML3uot1QP5yDUim292RtIqfU6Lr8wFVDVV8AsPKRDAxzYkKm2kj5sSFuUT3+v2FXkDXakD6f+7c1NGS7Ml0Pkah6jq8mhvwUy7Cyijg5Aoks6/hTp+k7vRjDJ73dmw8WHxlJRM2y5Nsb3GPDuzsZURbGMsUmRkoUPByCMrKCG7SobJiO01X7OKq6utoe3XX34BaoLDaCljj3faTcu3j3z3T+iADwzNYEmKIWcGAIAtqqkKAxZa2Sja/tY+59/7y48aveQ8A4Woq4Fa3bj7Q1/EgwWRAZ52NMTYCWAZEwIhBUEQgUiVQ8IpKvqj4kVJCyGRCRrb+hvap+gPAo0DuUhWQfx2q29u+t/vPmarbCLwII7qQTEQRLbUtBJ2PAkZARBADqkLBV/I+BGrhpoSN577FWz3P3XbTvRMvAlpuwC4crv5jwtK9RAFSu46+G8cRwESxQ+K2gESAgCiIASHuA8YCBdSUohdCKGCF0H6iGc3MgrEphvKi+6Wp24HABioSjuxFARGobyJ5OMXEiGHW6iLR0EmifhPJDddj3CoqtuwEZSkCc73/RAvTeEOvU5w8gz/Zj2TfoLFFibZvQrI5EOFiPqgAZmzApTINKKgPiW20ffkXtPXfA9Ysmf5/kHn/T0z8e5rpCS5JVQNUN1ayfn2a+qvT2JWboOOXMPg0ms6C2IAAWTc2ACPeupdbm5yb8XNQczOM90DOB0uoa01Ttz5FZ6IL3Ctg9DUIg7Lto2DZ0HIDFEbAz4AaiBRyxZJe9U7kQg84KYbH/JeJESANXPXwXdWffvzu1p+x5VE4/ST4EyAOoEAI6WsAhdx/AYulhJDqAgRm/hPPEVAfnAboeAB6v88jTw/f98SzU8eAwbgC5IGRg3vsW3E7YewYzJwF4wAhikJURGqvBO8ouAFIxBI0gqgPEp9B86+ASSAIEEHhbEnX7eTgnrFbn3iW5+K82EAA+M2V+d2EeRj9K/izIBYgJZGwCO4Gzm/uRQOwDEsI41PSfPZ+xJsBKwFo6dOwpJvezMU84Md5sSmRCM51uacGbUKvHWEjAKIelXaGJqePyopjzFTdx6Ef/gDbjo3FKEoQKN+8/yEqRt8jf67IaNDBnF9FZFwERRGspMM20+XC64nym9AMhSE1G7fjbb0bCQsISi6vFCdPMPzuUwR9AcmOKQ7cew+WZcq3IGEYMZeb4p13sjjmU4TX7Cfdtp0oDAFBbZfk/37N0MALAKbcAKaY4yPeuwy3t2J8MAKDIxDVd1Lz8Ts599vb8Wameen532GspRWIQmXPHV8k0BquvPP3TOSgsRmiCFRAHWh9420Gi7nl34JaBen7O7UWRMD740AQ7yEf8nW78TIeN+7+PCIsOYaqMJHxqKtpJ++D+DA5ARsawEmASqzv1Cz7FjRpbt951tUAOcAHdNEUC7C5NAJo7Dws03CAFMxlkdSRZmCMxaq8ejKuVwSqIJfzA61LmyIgBoxZfgmYmQazKLGumHitRso0ZVkD0aE/FI7UrYv2WUYXjo0ihNhEatA1GBEUIxEWAcKCHhHCVMG8AETlda0ENn3hrm+/6Zh47RBCtXn+mZ/sAXzWjnPHV77zkiXBgl6gFkee+em1wBlgdnEF8sCF5moLI7KwlSIMwABwgbVT21htMNjleheAfPkShEBh/PzQccexdxBT9IPjQAYYZ+3o2OjQ8cQiPb+kVwBCliENXA3sAm6Zj3E/zaq4fD07HmwEmuKYXsUFcDl6Hz7/B1RGfEbPim/bAAAAAElFTkSuQmCC',
		}

		TriggerEvent('esx_phone:addSpecialContact', specialContact.name, specialContact.number, specialContact.base64Icon)

end)

-- Create Blips
Citizen.CreateThread(function()

		local blip = AddBlipForCoord(Config.Zones.TaxiActions.Pos.x, Config.Zones.TaxiActions.Pos.y, Config.Zones.TaxiActions.Pos.z)

		SetBlipSprite (blip, 198)
		SetBlipDisplay(blip, 4)
		SetBlipScale  (blip, 1.0)
		SetBlipColour (blip, 5)
		SetBlipAsShortRange(blip, true)

		BeginTextCommandSetBlipName("STRING")
		AddTextComponentString("Taxi")
		EndTextCommandSetBlipName(blip)

end)

-- Display markers
Citizen.CreateThread(function()
	while true do

		Wait(0)

		if PlayerData.job ~= nil and PlayerData.job.name == 'taxi' then

			local coords = GetEntityCoords(GetPlayerPed(-1))

			for k,v in pairs(Config.Zones) do
				if(v.Type ~= -1 and GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < Config.DrawDistance) then
					DrawMarker(v.Type, v.Pos.x, v.Pos.y, v.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, v.Size.x, v.Size.y, v.Size.z, v.Color.r, v.Color.g, v.Color.b, 100, false, true, 2, false, false, false, false)
				end
			end

		end

	end
end)

-- Enter / Exit marker events
Citizen.CreateThread(function()
	while true do

		Wait(0)

		if PlayerData.job ~= nil and PlayerData.job.name == 'taxi' then

			local coords      = GetEntityCoords(GetPlayerPed(-1))
			local isInMarker  = false
			local currentZone = nil

			for k,v in pairs(Config.Zones) do
				if(GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < v.Size.x) then
					isInMarker  = true
					currentZone = k
				end
			end

			if (isInMarker and not HasAlreadyEnteredMarker) or (isInMarker and LastZone ~= currentZone) then
				HasAlreadyEnteredMarker = true
				LastZone                = currentZone
				TriggerEvent('esx_taxijob:hasEnteredMarker', currentZone)
			end

			if not isInMarker and HasAlreadyEnteredMarker then
				HasAlreadyEnteredMarker = false
				TriggerEvent('esx_taxijob:hasExitedMarker', LastZone)
			end

		end

	end
end)

-- Taxi Job
Citizen.CreateThread(function()

		while true do

			Citizen.Wait(0)

			local playerPed = GetPlayerPed(-1)

			if OnJob then

				if CurrentCustomer == nil then

					DrawSub(_U('drive_search_pass'), 5000)

					if IsPedInAnyVehicle(playerPed,  false) and GetEntitySpeed(playerPed) > 0 then

						local waitUntil = GetGameTimer() + GetRandomIntInRange(30000,  45000)

						while OnJob and waitUntil > GetGameTimer() do
							Citizen.Wait(0)
						end

						if OnJob and IsPedInAnyVehicle(playerPed,  false) and GetEntitySpeed(playerPed) > 0 then

							CurrentCustomer = GetRandomWalkingNPC()

							if CurrentCustomer ~= nil then

								CurrentCustomerBlip = AddBlipForEntity(CurrentCustomer)

								SetBlipAsFriendly(CurrentCustomerBlip, 1)
								SetBlipColour(CurrentCustomerBlip, 2)
								SetBlipCategory(CurrentCustomerBlip, 3)
								SetBlipRoute(CurrentCustomerBlip,  true)

								SetEntityAsMissionEntity(CurrentCustomer,  true, false)
								ClearPedTasksImmediately(CurrentCustomer)
								SetBlockingOfNonTemporaryEvents(CurrentCustomer, 1)

								local standTime = GetRandomIntInRange(60000,  180000)

								TaskStandStill(CurrentCustomer, standTime)

								ESX.ShowNotification(_U('customer_found'))

							end

						end

					end

				else

					if IsPedFatallyInjured(CurrentCustomer) then

						ESX.ShowNotification(_U('client_unconcious'))

						if DoesBlipExist(CurrentCustomerBlip) then
							RemoveBlip(CurrentCustomerBlip)
						end

						if DoesBlipExist(DestinationBlip) then
							RemoveBlip(DestinationBlip)
						end

						SetEntityAsMissionEntity(CurrentCustomer,  false, true)

						CurrentCustomer           = nil
						CurrentCustomerBlip       = nil
						DestinationBlip           = nil
						IsNearCustomer            = false
						CustomerIsEnteringVehicle = false
						CustomerEnteredVehicle    = false
						TargetCoords              = nil

					end

					if IsPedInAnyVehicle(playerPed,  false) then

						local vehicle          = GetVehiclePedIsIn(playerPed,  false)
						local playerCoords     = GetEntityCoords(playerPed)
						local customerCoords   = GetEntityCoords(CurrentCustomer)
						local customerDistance = GetDistanceBetweenCoords(playerCoords.x,  playerCoords.y,  playerCoords.z,  customerCoords.x,  customerCoords.y,  customerCoords.z)

						if IsPedSittingInVehicle(CurrentCustomer,  vehicle) then

							if CustomerEnteredVehicle then

								local targetDistance = GetDistanceBetweenCoords(playerCoords.x,  playerCoords.y,  playerCoords.z,  TargetCoords.x,  TargetCoords.y,  TargetCoords.z)

								if targetDistance <= 10.0 then

									TaskLeaveVehicle(CurrentCustomer,  vehicle,  0)

									ESX.ShowNotification(_U('arrive_dest'))

									TaskGoStraightToCoord(CurrentCustomer,  TargetCoords.x,  TargetCoords.y,  TargetCoords.z,  1.0,  -1,  0.0,  0.0)
									SetEntityAsMissionEntity(CurrentCustomer,  false, true)

									TriggerServerEvent('esx_taxijob:success')

									RemoveBlip(DestinationBlip)

									local scope = function(customer)
										ESX.SetTimeout(60000, function()
											DeletePed(customer)
										end)
									end

									scope(CurrentCustomer)

									CurrentCustomer           = nil
									CurrentCustomerBlip       = nil
									DestinationBlip           = nil
									IsNearCustomer            = false
									CustomerIsEnteringVehicle = false
									CustomerEnteredVehicle    = false
									TargetCoords              = nil

								end

								if TargetCoords ~= nil then
									DrawMarker(1, TargetCoords.x, TargetCoords.y, TargetCoords.z - 1.0, 0, 0, 0, 0, 0, 0, 4.0, 4.0, 2.0, 178, 236, 93, 155, 0, 0, 2, 0, 0, 0, 0)
								end

							else

								RemoveBlip(CurrentCustomerBlip)

								CurrentCustomerBlip = nil

								TargetCoords = Config.JobLocations[GetRandomIntInRange(1,  #Config.JobLocations)]

								local street = table.pack(GetStreetNameAtCoord(TargetCoords.x, TargetCoords.y, TargetCoords.z))
								local msg    = nil

								if street[2] ~= 0 and street[2] ~= nil then
									msg = string.format(_U('take_me_to_near', GetStreetNameFromHashKey(street[1]),GetStreetNameFromHashKey(street[2])))
								else
									msg = string.format(_U('take_me_to', GetStreetNameFromHashKey(street[1])))
								end

								ESX.ShowNotification(msg)

								DestinationBlip = AddBlipForCoord(TargetCoords.x, TargetCoords.y, TargetCoords.z)

								BeginTextCommandSetBlipName("STRING")
								AddTextComponentString("Destination")
								EndTextCommandSetBlipName(blip)

								SetBlipRoute(DestinationBlip,  true)

								CustomerEnteredVehicle = true

							end

						else

							DrawMarker(1, customerCoords.x, customerCoords.y, customerCoords.z - 1.0, 0, 0, 0, 0, 0, 0, 4.0, 4.0, 2.0, 178, 236, 93, 155, 0, 0, 2, 0, 0, 0, 0)

							if not CustomerEnteredVehicle then

								if customerDistance <= 30.0 then

									if not IsNearCustomer then
										ESX.ShowNotification(_U('close_to_client'))
										IsNearCustomer = true
									end

								end

								if customerDistance <= 100.0 then

									if not CustomerIsEnteringVehicle then

										ClearPedTasksImmediately(CurrentCustomer)

										local seat = 0

										for i=4, 0, 1 do
											if IsVehicleSeatFree(vehicle,  seat) then
												seat = i
												break
											end
										end

										TaskEnterVehicle(CurrentCustomer,  vehicle,  -1,  seat,  2.0,  1)

										CustomerIsEnteringVehicle = true

									end

								end

							end

						end

					else

						DrawSub(_U('return_to_veh'), 5000)

					end

				end

			end

		end
end)

-- Key Controls
Citizen.CreateThread(function()
	while true do

		Citizen.Wait(0)

		if CurrentAction ~= nil then

			SetTextComponentFormat('STRING')
			AddTextComponentString(CurrentActionMsg)
			DisplayHelpTextFromStringLabel(0, 0, 1, -1)

			if IsControlPressed(0,  Keys['E']) and PlayerData.job ~= nil and PlayerData.job.name == 'taxi' and (GetGameTimer() - GUI.Time) > 300 then

				if CurrentAction == 'taxi_actions_menu' then
					OpenTaxiActionsMenu()
				end

				if CurrentAction == 'delete_vehicle' then

					local playerPed = GetPlayerPed(-1)

					if Config.EnableSocietyOwnedVehicles then
						local vehicleProps = ESX.Game.GetVehicleProperties(CurrentActionData.vehicle)
						TriggerServerEvent('esx_society:putVehicleInGarage', 'taxi', vehicleProps)
					else
						if GetEntityModel(CurrentActionData.vehicle) == GetHashKey('taxi') then
							if Config.MaxInService ~= -1 then
								TriggerServerEvent('esx_service:disableService', 'taxi')
							end
						end
					end

					ESX.Game.DeleteVehicle(CurrentActionData.vehicle)

				end

				CurrentAction = nil
				GUI.Time      = GetGameTimer()

			end

		end

		if IsControlPressed(0,  Keys['F6']) and Config.EnablePlayerManagement and PlayerData.job ~= nil and PlayerData.job.name == 'taxi' and (GetGameTimer() - GUI.Time) > 150 then
			OpenMobileTaxiActionsMenu()
			GUI.Time = GetGameTimer()
		end

		if IsControlPressed(0,  Keys['DELETE']) and (GetGameTimer() - GUI.Time) > 150 then

			if OnJob then
				StopTaxiJob()
			else

				if PlayerData.job ~= nil and PlayerData.job.name == 'taxi' then

					local playerPed = GetPlayerPed(-1)

					if IsPedInAnyVehicle(playerPed,  false) then

						local vehicle = GetVehiclePedIsIn(playerPed,  false)

						if PlayerData.job.grade >= 3 then
							StartTaxiJob()
						else
							if GetEntityModel(vehicle) == GetHashKey('taxi') then
								StartTaxiJob()
							else
								ESX.ShowNotification(_U('must_in_taxi'))
							end
						end

					else

						if PlayerData.job.grade >= 3 then
							ESX.ShowNotification(_U('must_in_vehicle'))
						else
							ESX.ShowNotification(_U('must_in_taxi'))
						end

					end

				end

			end

			GUI.Time = GetGameTimer()

		end

	end
end)

-------------------------
--MECHANIC SCRIPT BELOW--
-------------------------

function SelectRandomTowable()

	local index = GetRandomIntInRange(1,  #Config.Towables)

	for k,v in pairs(Config.Zones) do
		if v.Pos.x == Config.Towables[index].x and v.Pos.y == Config.Towables[index].y and v.Pos.z == Config.Towables[index].z then
			return k
		end
	end

end

function StartNPCJob()

	NPCOnJob = true

	NPCTargetTowableZone = SelectRandomTowable()
	local zone       = Config.Zones[NPCTargetTowableZone]

	Blips['NPCTargetTowableZone'] = AddBlipForCoord(zone.Pos.x,  zone.Pos.y,  zone.Pos.z)
	SetBlipRoute(Blips['NPCTargetTowableZone'], true)

	ESX.ShowNotification(_U('drive_to_indicated'))
end

function StopNPCJob(cancel)

	if Blips['NPCTargetTowableZone'] ~= nil then
		RemoveBlip(Blips['NPCTargetTowableZone'])
		Blips['NPCTargetTowableZone'] = nil
	end

	if Blips['NPCDelivery'] ~= nil then
		RemoveBlip(Blips['NPCDelivery'])
		Blips['NPCDelivery'] = nil
	end


	Config.Zones.VehicleDelivery.Type = -1

	NPCOnJob                = false
	NPCTargetTowable        = nil
	NPCTargetTowableZone    = nil
	NPCHasSpawnedTowable    = false
	NPCHasBeenNextToTowable = false

	if cancel then
		ESX.ShowNotification(_U('mission_canceled'))
	else
		TriggerServerEvent('esx_mecanojob:onNPCJobCompleted')
	end

end

function OpenMecanoActionsMenu()

	local elements = {
		{label = _U('vehicle_list'), value = 'vehicle_list'},
		{label = _U('work_wear'), value = 'cloakroom'},
		{label = _U('civ_wear'), value = 'cloakroom2'},
		{label = _U('deposit_stock'), value = 'put_stock'},
		{label = _U('withdraw_stock'), value = 'get_stock'}
	}
	if Config.EnablePlayerManagement and PlayerData.job ~= nil and PlayerData.job.grade_name == 'boss' then
		table.insert(elements, {label = _U('boss_actions'), value = 'boss_actions'})
	end

	ESX.UI.Menu.CloseAll()

	ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'mecano_actions',
		{
			title    = _U('mechanic'),
			elements = elements
		},
		function(data, menu)
			if data.current.value == 'vehicle_list' then

				if Config.EnableSocietyOwnedVehicles then

					local elements = {}

					ESX.TriggerServerCallback('esx_society:getVehiclesInGarage', function(vehicles)

							for i=1, #vehicles, 1 do
								table.insert(elements, {label = GetDisplayNameFromVehicleModel(vehicles[i].model) .. ' [' .. vehicles[i].plate .. ']', value = vehicles[i]})
							end

							ESX.UI.Menu.Open(
								'default', GetCurrentResourceName(), 'vehicle_spawner',
								{
									title    = _U('service_vehicle'),
									align    = 'top-left',
									elements = elements,
								},
								function(data, menu)

									menu.close()

									local vehicleProps = data.current.value

									ESX.Game.SpawnVehicle(vehicleProps.model, Config.Zones.VehicleSpawnPoint.Pos, 270.0, function(vehicle)
										ESX.Game.SetVehicleProperties(vehicle, vehicleProps)
										local playerPed = GetPlayerPed(-1)
										TaskWarpPedIntoVehicle(playerPed,  vehicle,  -1)
									end)

									TriggerServerEvent('esx_society:removeVehicleFromGarage', 'mecano', vehicleProps)

								end,
								function(data, menu)
									menu.close()
								end
							)

					end, 'mecano')

				else

					local elements = {
						{label = _U('flat_bed'), value = 'flatbed'},
						{label = _U('tow_truck'), value = 'towtruck2'}
					}

					if Config.EnablePlayerManagement and PlayerData.job ~= nil and
						(PlayerData.job.grade_name == 'boss' or PlayerData.job.grade_name == 'chef' or PlayerData.job.grade_name == 'experimente') then
						table.insert(elements, {label = 'SlamVan', value = 'slamvan3'})
					end

					ESX.UI.Menu.CloseAll()

					ESX.UI.Menu.Open(
						'default', GetCurrentResourceName(), 'spawn_vehicle',
						{
							title    = _U('service_vehicle'),
							elements = elements
						},
						function(data, menu)
							for i=1, #elements, 1 do
								if Config.MaxInService == -1 then
									ESX.Game.SpawnVehicle(data.current.value, Config.Zones.VehicleSpawnPoint.Pos, 90.0, function(vehicle)
										local playerPed = GetPlayerPed(-1)
										TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
									end)
									break
								else
									ESX.TriggerServerCallback('esx_service:enableService', function(canTakeService, maxInService, inServiceCount)
										if canTakeService then
											ESX.Game.SpawnVehicle(data.current.value, Config.Zones.VehicleSpawnPoint.Pos, 90.0, function(vehicle)
												local playerPed = GetPlayerPed(-1)
												TaskWarpPedIntoVehicle(playerPed,  vehicle, -1)
											end)
										else
											ESX.ShowNotification(_U('service_full') .. inServiceCount .. '/' .. maxInService)
										end
									end, 'mecano')
									break
								end
							end
							menu.close()
						end,
						function(data, menu)
							menu.close()
							OpenMecanoActionsMenu()
						end
					)

				end
			end

			if data.current.value == 'cloakroom' then
				menu.close()
				ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)

						if skin.sex == 0 then
							TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_male)
						else
							TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_female)
						end

				end)
			end

			if data.current.value == 'cloakroom2' then
				menu.close()
				ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)

						TriggerEvent('skinchanger:loadSkin', skin)

				end)
			end

			if data.current.value == 'put_stock' then
				OpenPutStocksMenu()
			end

			if data.current.value == 'get_stock' then
				OpenGetStocksMenu()
			end

			if data.current.value == 'boss_actions' then
				TriggerEvent('esx_society:openBossMenu', 'mecano', function(data, menu)
					menu.close()
				end)
			end

		end,
		function(data, menu)
			menu.close()
			CurrentAction     = 'mecano_actions_menu'
			CurrentActionMsg  = _U('open_actions')
			CurrentActionData = {}
		end
	)
end

function OpenMecanoHarvestMenu()

	if Config.EnablePlayerManagement and PlayerData.job ~= nil and PlayerData.job.grade_name ~= 'recrue' then
		local elements = {
			{label = _U('gas_can'), value = 'gaz_bottle'},
			{label = _U('repair_tools'), value = 'fix_tool'},
			{label = _U('body_work_tools'), value = 'caro_tool'}
		}

		ESX.UI.Menu.CloseAll()

		ESX.UI.Menu.Open(
			'default', GetCurrentResourceName(), 'mecano_harvest',
			{
				title    = _U('harvest'),
				elements = elements
			},
			function(data, menu)
				if data.current.value == 'gaz_bottle' then
					menu.close()
					TriggerServerEvent('esx_mecanojob:startHarvest')
				end

				if data.current.value == 'fix_tool' then
					menu.close()
					TriggerServerEvent('esx_mecanojob:startHarvest2')
				end

				if data.current.value == 'caro_tool' then
					menu.close()
					TriggerServerEvent('esx_mecanojob:startHarvest3')
				end

			end,
			function(data, menu)
				menu.close()
				CurrentAction     = 'mecano_harvest_menu'
				CurrentActionMsg  = _U('harvest_menu')
				CurrentActionData = {}
			end
		)
	else
		ESX.ShowNotification(_U('not_experienced_enough'))
	end
end

function OpenMecanoCraftMenu()
	if Config.EnablePlayerManagement and PlayerData.job ~= nil and PlayerData.job.grade_name ~= 'recrue' then

		local elements = {
			{label = _U('blowtorch'), value = 'blow_pipe'},
			{label = _U('repair_kit'), value = 'fix_kit'},
			{label = _U('body_kit'), value = 'caro_kit'}
		}

		ESX.UI.Menu.CloseAll()

		ESX.UI.Menu.Open(
			'default', GetCurrentResourceName(), 'mecano_craft',
			{
				title    = _U('craft'),
				elements = elements
			},
			function(data, menu)
				if data.current.value == 'blow_pipe' then
					menu.close()
					TriggerServerEvent('esx_mecanojob:startCraft')
				end

				if data.current.value == 'fix_kit' then
					menu.close()
					TriggerServerEvent('esx_mecanojob:startCraft2')
				end

				if data.current.value == 'caro_kit' then
					menu.close()
					TriggerServerEvent('esx_mecanojob:startCraft3')
				end

			end,
			function(data, menu)
				menu.close()
				CurrentAction     = 'mecano_craft_menu'
				CurrentActionMsg  = _U('craft_menu')
				CurrentActionData = {}
			end
		)
	else
		ESX.ShowNotification(_U('not_experienced_enough'))
	end
end

function OpenMobileMecanoActionsMenu()

	ESX.UI.Menu.CloseAll()

	ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'mobile_mecano_actions',
		{
			title    = _U('mechanic'),
			elements = {
				{label = _U('billing'),    value = 'billing'},
				{label = _U('hijack'),     value = 'hijack_vehicle'},
				{label = _U('repair'),       value = 'fix_vehicle'},
				{label = _U('clean'),      value = 'clean_vehicle'},
				{label = _U('imp_veh'),     value = 'del_vehicle'},
				{label = _U('flat_bed'),       value = 'dep_vehicle'},
				{label = _U('place_objects'), value = 'object_spawner'}
			}
		},
		function(data, menu)
			if data.current.value == 'billing' then
				ESX.UI.Menu.Open(
					'dialog', GetCurrentResourceName(), 'billing',
					{
						title = _U('invoice_amount')
					},
					function(data, menu)
						local amount = tonumber(data.value)
						if amount == nil or amount < 0 then
							ESX.ShowNotification(_U('amount_invalid'))
						else
							menu.close()
							local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()
							if closestPlayer == -1 or closestDistance > 3.0 then
								ESX.ShowNotification(_U('no_players_nearby'))
							else
								TriggerServerEvent('esx_billing:sendBill', GetPlayerServerId(closestPlayer), 'society_mecano', _U('mechanic'), amount)
							end
						end
					end,
					function(data, menu)
						menu.close()
					end
				)
			end

			if data.current.value == 'hijack_vehicle' then

				local playerPed = GetPlayerPed(-1)
				local coords    = GetEntityCoords(playerPed)

				if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 5.0) then

					local vehicle = nil

					if IsPedInAnyVehicle(playerPed, false) then
						vehicle = GetVehiclePedIsIn(playerPed, false)
					else
						vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
					end

					if DoesEntityExist(vehicle) then
						TaskStartScenarioInPlace(playerPed, "WORLD_HUMAN_WELDING", 0, true)
						Citizen.CreateThread(function()
							Citizen.Wait(10000)
							SetVehicleDoorsLocked(vehicle, 1)
							SetVehicleDoorsLockedForAllPlayers(vehicle, false)
							ClearPedTasksImmediately(playerPed)
							ESX.ShowNotification(_U('vehicle_unlocked'))
						end)
					end

				end

			end

			if data.current.value == 'fix_vehicle' then

				local playerPed = GetPlayerPed(-1)
				local coords    = GetEntityCoords(playerPed)

				if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 5.0) then

					local vehicle = nil

					if IsPedInAnyVehicle(playerPed, false) then
						vehicle = GetVehiclePedIsIn(playerPed, false)
					else
						vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
					end

					if DoesEntityExist(vehicle) then
						TaskStartScenarioInPlace(playerPed, "PROP_HUMAN_BUM_BIN", 0, true)
						Citizen.CreateThread(function()
							Citizen.Wait(20000)
							SetVehicleFixed(vehicle)
							SetVehicleDeformationFixed(vehicle)
							SetVehicleUndriveable(vehicle, false)
							SetVehicleEngineOn(vehicle,  true,  true)
							ClearPedTasksImmediately(playerPed)
							ESX.ShowNotification(_U('vehicle_repaired'))
						end)
					end
				end
			end

			if data.current.value == 'clean_vehicle' then

				local playerPed = GetPlayerPed(-1)
				local coords    = GetEntityCoords(playerPed)

				if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 5.0) then

					local vehicle = nil

					if IsPedInAnyVehicle(playerPed, false) then
						vehicle = GetVehiclePedIsIn(playerPed, false)
					else
						vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
					end

					if DoesEntityExist(vehicle) then
						TaskStartScenarioInPlace(playerPed, "WORLD_HUMAN_MAID_CLEAN", 0, true)
						Citizen.CreateThread(function()
							Citizen.Wait(10000)
							SetVehicleDirtLevel(vehicle, 0)
							ClearPedTasksImmediately(playerPed)
							ESX.ShowNotification(_U('vehicle_cleaned'))
						end)
					end
				end
			end

			if data.current.value == 'del_vehicle' then

				local ped = GetPlayerPed( -1 )

				if ( DoesEntityExist( ped ) and not IsEntityDead( ped ) ) then
					local pos = GetEntityCoords( ped )

					if ( IsPedSittingInAnyVehicle( ped ) ) then
						local vehicle = GetVehiclePedIsIn( ped, false )

						if ( GetPedInVehicleSeat( vehicle, -1 ) == ped ) then
							ESX.ShowNotification(_U('vehicle_impounded'))
							SetEntityAsMissionEntity( vehicle, true, true )
							deleteCar( vehicle )
						else
							ESX.ShowNotification(_U('must_seat_driver'))
						end
					else
						local playerPos = GetEntityCoords( ped, 1 )
						local inFrontOfPlayer = GetOffsetFromEntityInWorldCoords( ped, 0.0, distanceToCheck, 0.0 )
						local vehicle = GetVehicleInDirection( playerPos, inFrontOfPlayer )

						if ( DoesEntityExist( vehicle ) ) then
							ESX.ShowNotification(_U('vehicle_impounded'))
							SetEntityAsMissionEntity( vehicle, true, true )
							deleteCar( vehicle )
						else
							ESX.ShowNotification(_U('must_near'))
						end
					end
				end
			end

			if data.current.value == 'dep_vehicle' then

				local playerped = GetPlayerPed(-1)
				local vehicle = GetVehiclePedIsIn(playerped, true)

				local towmodel = GetHashKey('flatbed')
				local isVehicleTow = IsVehicleModel(vehicle, towmodel)

				if isVehicleTow then

					local coordA = GetEntityCoords(playerped, 1)
					local coordB = GetOffsetFromEntityInWorldCoords(playerped, 0.0, 5.0, 0.0)
					local targetVehicle = getVehicleInDirection(coordA, coordB)

					if CurrentlyTowedVehicle == nil then
						if targetVehicle ~= 0 then
							if not IsPedInAnyVehicle(playerped, true) then
								if vehicle ~= targetVehicle then
									AttachEntityToEntity(targetVehicle, vehicle, 20, -0.5, -5.0, 1.0, 0.0, 0.0, 0.0, false, false, false, false, 20, true)
									CurrentlyTowedVehicle = targetVehicle
									ESX.ShowNotification(_U('vehicle_success_attached'))

									if NPCOnJob then

										if NPCTargetTowable == targetVehicle then
											ESX.ShowNotification(_U('please_drop_off'))

											Config.Zones.VehicleDelivery.Type = 1

											if Blips['NPCTargetTowableZone'] ~= nil then
												RemoveBlip(Blips['NPCTargetTowableZone'])
												Blips['NPCTargetTowableZone'] = nil
											end

											Blips['NPCDelivery'] = AddBlipForCoord(Config.Zones.VehicleDelivery.Pos.x,  Config.Zones.VehicleDelivery.Pos.y,  Config.Zones.VehicleDelivery.Pos.z)

											SetBlipRoute(Blips['NPCDelivery'], true)

										end

									end

								else
									ESX.ShowNotification(_U('cant_attach_own_tt'))
								end
							end
						else
							ESX.ShowNotification(_U('no_veh_att'))
						end
					else

						AttachEntityToEntity(CurrentlyTowedVehicle, vehicle, 20, -0.5, -12.0, 1.0, 0.0, 0.0, 0.0, false, false, false, false, 20, true)
						DetachEntity(CurrentlyTowedVehicle, true, true)

						if NPCOnJob then

							if NPCTargetDeleterZone then

								if CurrentlyTowedVehicle == NPCTargetTowable then
									ESX.Game.DeleteVehicle(NPCTargetTowable)
									TriggerServerEvent('esx_mecanojob:onNPCJobMissionCompleted')
									StopNPCJob()
									NPCTargetDeleterZone = false

								else
									ESX.ShowNotification(_U('not_right_veh'))
								end

							else
								ESX.ShowNotification(_U('not_right_place'))
							end

						end

						CurrentlyTowedVehicle = nil

						ESX.ShowNotification(_U('veh_det_succ'))
					end
				else
					ESX.ShowNotification(_U('imp_flatbed'))
				end
			end

			if data.current.value == 'object_spawner' then

				ESX.UI.Menu.Open(
					'default', GetCurrentResourceName(), 'mobile_mecano_actions_spawn',
					{
						title    = _U('objects'),
						align    = 'top-left',
						elements = {
							{label = _U('roadcone'),     value = 'prop_roadcone02a'},
							{label = _U('toolbox'), value = 'prop_toolchest_01'},
						},
					},
					function(data2, menu2)


						local model     = data2.current.value
						local playerPed = GetPlayerPed(-1)
						local coords    = GetEntityCoords(playerPed)
						local forward   = GetEntityForwardVector(playerPed)
						local x, y, z   = table.unpack(coords + forward * 1.0)

						if model == 'prop_roadcone02a' then
							z = z - 2.0
						elseif model == 'prop_toolchest_01' then
							z = z - 2.0
						end

						ESX.Game.SpawnObject(model, {
							x = x,
							y = y,
							z = z
						}, function(obj)
							SetEntityHeading(obj, GetEntityHeading(playerPed))
							PlaceObjectOnGroundProperly(obj)
						end)

					end,
					function(data2, menu2)
						menu2.close()
					end
				)

			end

		end,
		function(data, menu)
			menu.close()
		end
	)
end

function OpenGetStocksMenu()

	ESX.TriggerServerCallback('esx_mecanojob:getStockItems', function(items)

			print(json.encode(items))

			local elements = {}

			for i=1, #items, 1 do
				table.insert(elements, {label = 'x' .. items[i].count .. ' ' .. items[i].label, value = items[i].name})
			end

			ESX.UI.Menu.Open(
				'default', GetCurrentResourceName(), 'stocks_menu',
				{
					title    = _U('mechanic_stock'),
					elements = elements
				},
				function(data, menu)

					local itemName = data.current.value

					ESX.UI.Menu.Open(
						'dialog', GetCurrentResourceName(), 'stocks_menu_get_item_count',
						{
							title = _U('quantity')
						},
						function(data2, menu2)

							local count = tonumber(data2.value)

							if count == nil then
								ESX.ShowNotification(_U('invalid_quantity'))
							else
								menu2.close()
								menu.close()
								OpenGetStocksMenu()

								TriggerServerEvent('esx_mecanojob:getStockItem', itemName, count)
							end

						end,
						function(data2, menu2)
							menu2.close()
						end
					)

				end,
				function(data, menu)
					menu.close()
				end
			)

	end)

end

function OpenPutStocksMenu()

	ESX.TriggerServerCallback('esx_mecanojob:getPlayerInventory', function(inventory)

			local elements = {}

			for i=1, #inventory.items, 1 do

				local item = inventory.items[i]

				if item.count > 0 then
					table.insert(elements, {label = item.label .. ' x' .. item.count, type = 'item_standard', value = item.name})
				end

			end

			ESX.UI.Menu.Open(
				'default', GetCurrentResourceName(), 'stocks_menu',
				{
					title    = _U('inventory'),
					elements = elements
				},
				function(data, menu)

					local itemName = data.current.value

					ESX.UI.Menu.Open(
						'dialog', GetCurrentResourceName(), 'stocks_menu_put_item_count',
						{
							title = _U('quantity')
						},
						function(data2, menu2)

							local count = tonumber(data2.value)

							if count == nil then
								ESX.ShowNotification(_U('invalid_quantity'))
							else
								menu2.close()
								menu.close()
								OpenPutStocksMenu()

								TriggerServerEvent('esx_mecanojob:putStockItems', itemName, count)
							end

						end,
						function(data2, menu2)
							menu2.close()
						end
					)

				end,
				function(data, menu)
					menu.close()
				end
			)

	end)

end


RegisterNetEvent('esx_mecanojob:onHijack')
AddEventHandler('esx_mecanojob:onHijack', function()
	local playerPed = GetPlayerPed(-1)
	local coords    = GetEntityCoords(playerPed)

	if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 5.0) then

		local vehicle = nil

		if IsPedInAnyVehicle(playerPed, false) then
			vehicle = GetVehiclePedIsIn(playerPed, false)
		else
			vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
		end

		local crochete = math.random(100)
		local alarm    = math.random(100)

		if DoesEntityExist(vehicle) then
			if alarm <= 33 then
				SetVehicleAlarm(vehicle, true)
				StartVehicleAlarm(vehicle)
			end
			TaskStartScenarioInPlace(playerPed, "WORLD_HUMAN_WELDING", 0, true)
			Citizen.CreateThread(function()
				Citizen.Wait(10000)
				if crochete <= 66 then
					SetVehicleDoorsLocked(vehicle, 1)
					SetVehicleDoorsLockedForAllPlayers(vehicle, false)
					ClearPedTasksImmediately(playerPed)
					ESX.ShowNotification(_U('veh_unlocked'))
				else
					ESX.ShowNotification(_U('hijack_failed'))
					ClearPedTasksImmediately(playerPed)
				end
			end)
		end

	end
end)

RegisterNetEvent('esx_mecanojob:onCarokit')
AddEventHandler('esx_mecanojob:onCarokit', function()
	local playerPed = GetPlayerPed(-1)
	local coords    = GetEntityCoords(playerPed)

	if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 5.0) then

		local vehicle = nil

		if IsPedInAnyVehicle(playerPed, false) then
			vehicle = GetVehiclePedIsIn(playerPed, false)
		else
			vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
		end

		if DoesEntityExist(vehicle) then
			TaskStartScenarioInPlace(playerPed, "WORLD_HUMAN_HAMMERING", 0, true)
			Citizen.CreateThread(function()
				Citizen.Wait(10000)
				SetVehicleFixed(vehicle)
				SetVehicleDeformationFixed(vehicle)
				ClearPedTasksImmediately(playerPed)
				ESX.ShowNotification(_U('body_repaired'))
			end)
		end
	end
end)

RegisterNetEvent('esx_mecanojob:onFixkit')
AddEventHandler('esx_mecanojob:onFixkit', function()
	local playerPed = GetPlayerPed(-1)
	local coords    = GetEntityCoords(playerPed)

	if IsAnyVehicleNearPoint(coords.x, coords.y, coords.z, 5.0) then

		local vehicle = nil

		if IsPedInAnyVehicle(playerPed, false) then
			vehicle = GetVehiclePedIsIn(playerPed, false)
		else
			vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
		end

		if DoesEntityExist(vehicle) then
			TaskStartScenarioInPlace(playerPed, "PROP_HUMAN_BUM_BIN", 0, true)
			Citizen.CreateThread(function()
				Citizen.Wait(20000)
				SetVehicleFixed(vehicle)
				SetVehicleDeformationFixed(vehicle)
				SetVehicleUndriveable(vehicle, false)
				ClearPedTasksImmediately(playerPed)
				ESX.ShowNotification(_U('veh_repaired'))
			end)
		end
	end
end)

function setEntityHeadingFromEntity ( vehicle, playerPed )
	local heading = GetEntityHeading(vehicle)
	SetEntityHeading( playerPed, heading )
end

function getVehicleInDirection(coordFrom, coordTo)
	local rayHandle = CastRayPointToPoint(coordFrom.x, coordFrom.y, coordFrom.z, coordTo.x, coordTo.y, coordTo.z, 10, GetPlayerPed(-1), 0)
	local a, b, c, d, vehicle = GetRaycastResult(rayHandle)
	return vehicle
end

function deleteCar( entity )
	Citizen.InvokeNative( 0xEA386986E786A54F, Citizen.PointerValueIntInitialized( entity ) )
end

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
	PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	PlayerData.job = job
end)

AddEventHandler('esx_mecanojob:hasEnteredMarker', function(zone)

		if zone == NPCJobTargetTowable then

		end

		if zone =='VehicleDelivery' then
			NPCTargetDeleterZone = true
		end

		if zone == 'MecanoActions' then
			CurrentAction     = 'mecano_actions_menu'
			CurrentActionMsg  = _U('open_actions')
			CurrentActionData = {}
		end

		if zone == 'Garage' then
			CurrentAction     = 'mecano_harvest_menu'
			CurrentActionMsg  = _U('harvest_menu')
			CurrentActionData = {}
		end

		if zone == 'Craft' then
			CurrentAction     = 'mecano_craft_menu'
			CurrentActionMsg  = _U('craft_menu')
			CurrentActionData = {}
		end

		if zone == 'VehicleDeleter' then

			local playerPed = GetPlayerPed(-1)

			if IsPedInAnyVehicle(playerPed,  false) then

				local vehicle = GetVehiclePedIsIn(playerPed,  false)

				CurrentAction     = 'delete_vehicle'
				CurrentActionMsg  = _U('veh_stored')
				CurrentActionData = {vehicle = vehicle}
			end
		end

end)

AddEventHandler('esx_mecanojob:hasExitedMarker', function(zone)

		if zone =='VehicleDelivery' then
			NPCTargetDeleterZone = false
		end

		if zone == 'Craft' then
			TriggerServerEvent('esx_mecanojob:stopCraft')
			TriggerServerEvent('esx_mecanojob:stopCraft2')
			TriggerServerEvent('esx_mecanojob:stopCraft3')
		end

		if zone == 'Garage' then
			TriggerServerEvent('esx_mecanojob:stopHarvest')
			TriggerServerEvent('esx_mecanojob:stopHarvest2')
			TriggerServerEvent('esx_mecanojob:stopHarvest3')
		end

		CurrentAction = nil
		ESX.UI.Menu.CloseAll()
end)

AddEventHandler('esx_mecanojob:hasEnteredEntityZone', function(entity)

		local playerPed = GetPlayerPed(-1)

		if PlayerData.job ~= nil and PlayerData.job.name == 'mecano' and not IsPedInAnyVehicle(playerPed, false) then
			CurrentAction     = 'remove_entity'
			CurrentActionMsg  = _U('press_remove_obj')
			CurrentActionData = {entity = entity}
		end

end)

AddEventHandler('esx_mecanojob:hasExitedEntityZone', function(entity)

		if CurrentAction == 'remove_entity' then
			CurrentAction = nil
		end

end)

RegisterNetEvent('esx_phone:loaded')
AddEventHandler('esx_phone:loaded', function(phoneNumber, contacts)
	local specialContact = {
		name       = _U('mechanic'),
		number     = 'mecano',
		base64Icon = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAALEwAACxMBAJqcGAAAA4BJREFUWIXtll9oU3cUx7/nJA02aSSlFouWMnXVB0ejU3wcRteHjv1puoc9rA978cUi2IqgRYWIZkMwrahUGfgkFMEZUdg6C+u21z1o3fbgqigVi7NzUtNcmsac40Npltz7S3rvUHzxQODec87vfD+/e0/O/QFv7Q0beV3QeXqmgV74/7H7fZJvuLwv8q/Xeux1gUrNBpN/nmtavdaqDqBK8VT2RDyV2VHmF1lvLERSBtCVynzYmcp+A9WqT9kcVKX4gHUehF0CEVY+1jYTTIwvt7YSIQnCTvsSUYz6gX5uDt7MP7KOKuQAgxmqQ+neUA+I1B1AiXi5X6ZAvKrabirmVYFwAMRT2RMg7F9SyKspvk73hfrtbkMPyIhA5FVqi0iBiEZMMQdAui/8E4GPv0oAJkpc6Q3+6goAAGpWBxNQmTLFmgL3jSJNgQdGv4pMts2EKm7ICJB/aG0xNdz74VEk13UYCx1/twPR8JjDT8wttyLZtkoAxSb8ZDCz0gdfKxWkFURf2v9qTYH7SK7rQIDn0P3nA0ehixvfwZwE0X9vBE/mW8piohhl1WH18UQBhYnre8N/L8b8xQvlx4ACbB4NnzaeRYDnKm0EALCMLXy84hwuTCXL/ExoB1E7qcK/8NCLIq5HcTT0i6u8TYbXUM1cAyyveVq8Xls7XhYrvY/4n3gC8C+dsmAzL1YUiyfWxvHzsy/w/dNd+KjhW2yvv/RfXr7x9QDcmo1he2RBiCCI1Q8jVj9szPNixVfgz+UiIGyDSrcoRu2J16d3I6e1VYvNSQjXpnucAcEPUOkGYZs/l4uUhowt/3kqu1UIv9n90fAY9jT3YBlbRvFTD4fw++wHjhiTRL/bG75t0jI2ITcHb5om4Xgmhv57xpGOg3d/NIqryOR7z+r+MC6qBJB/ZB2t9Om1D5lFm843G/3E3HI7Yh1xDRAfzLQr5EClBf/HBHK462TG2J0OABXeyWDPZ8VqxmBWYscpyghwtTd4EKpDTjCZdCNmzFM9k+4LHXIFACJN94Z6FiFEpKDQw9HndWsEuhnADVMhAUaYJBp9XrcGQKJ4qFE9k+6r2+MG3k5N8VQ22TVglbX2ZwOzX2VvNKr91zmY6S7N6zqZicVT2WNLyVSehESaBhxnOALfMeYX+K/S2yv7wmMAlvwyuR7FxQUyf0fgc/jztfkJr7XeGgC8BJJgWNV8ImT+AAAAAElFTkSuQmCC'
	}
	TriggerEvent('esx_phone:addSpecialContact', specialContact.name, specialContact.number, specialContact.base64Icon)
end)

-- Pop NPC mission vehicle when inside area
Citizen.CreateThread(function()
	while true do

		Wait(0)

		if NPCTargetTowableZone ~= nil and not NPCHasSpawnedTowable then

			local coords = GetEntityCoords(GetPlayerPed(-1))
			local zone   = Config.Zones[NPCTargetTowableZone]

			if GetDistanceBetweenCoords(coords, zone.Pos.x, zone.Pos.y, zone.Pos.z, true) < Config.NPCSpawnDistance then

				local model = Config.Vehicles[GetRandomIntInRange(1,  #Config.Vehicles)]

				ESX.Game.SpawnVehicle(model, zone.Pos, 0, function(vehicle)
					NPCTargetTowable = vehicle
				end)

				NPCHasSpawnedTowable = true

			end

		end

		if NPCTargetTowableZone ~= nil and NPCHasSpawnedTowable and not NPCHasBeenNextToTowable then

			local coords = GetEntityCoords(GetPlayerPed(-1))
			local zone   = Config.Zones[NPCTargetTowableZone]

			if(GetDistanceBetweenCoords(coords, zone.Pos.x, zone.Pos.y, zone.Pos.z, true) < Config.NPCNextToDistance) then
				ESX.ShowNotification(_U('please_tow'))
				NPCHasBeenNextToTowable = true
			end

		end

	end
end)

-- Create Blips
Citizen.CreateThread(function()
	local blip = AddBlipForCoord(Config.Zones.MecanoActions.Pos.x, Config.Zones.MecanoActions.Pos.y, Config.Zones.MecanoActions.Pos.z)
	SetBlipSprite (blip, 446)
	SetBlipDisplay(blip, 4)
	SetBlipScale  (blip, 1.8)
	SetBlipColour (blip, 5)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(_U('mechanic'))
	EndTextCommandSetBlipName(blip)
end)

-- Display markers
Citizen.CreateThread(function()
	while true do
		Wait(0)
		if PlayerData.job ~= nil and PlayerData.job.name == 'mecano' then

			local coords = GetEntityCoords(GetPlayerPed(-1))

			for k,v in pairs(Config.Zones) do
				if(v.Type ~= -1 and GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < Config.DrawDistance) then
					DrawMarker(v.Type, v.Pos.x, v.Pos.y, v.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, v.Size.x, v.Size.y, v.Size.z, v.Color.r, v.Color.g, v.Color.b, 100, false, true, 2, false, false, false, false)
				end
			end
		end
	end
end)

-- Enter / Exit marker events
Citizen.CreateThread(function()
	while true do
		Wait(0)
		if PlayerData.job ~= nil and PlayerData.job.name == 'mecano' then
			local coords      = GetEntityCoords(GetPlayerPed(-1))
			local isInMarker  = false
			local currentZone = nil
			for k,v in pairs(Config.Zones) do
				if(GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < v.Size.x) then
					isInMarker  = true
					currentZone = k
				end
			end
			if (isInMarker and not HasAlreadyEnteredMarker) or (isInMarker and LastZone ~= currentZone) then
				HasAlreadyEnteredMarker = true
				LastZone                = currentZone
				TriggerEvent('esx_mecanojob:hasEnteredMarker', currentZone)
			end
			if not isInMarker and HasAlreadyEnteredMarker then
				HasAlreadyEnteredMarker = false
				TriggerEvent('esx_mecanojob:hasExitedMarker', LastZone)
			end
		end
	end
end)

Citizen.CreateThread(function()
	while true do

		Citizen.Wait(0)

		local playerPed = GetPlayerPed(-1)
		local coords    = GetEntityCoords(playerPed)

		local entity, distance = ESX.Game.GetClosestObject({
			'prop_roadcone02a',
			'prop_toolchest_01'
		})

		if distance ~= -1 and distance <= 3.0 then

			if LastEntity ~= entity then
				TriggerEvent('esx_mecanojob:hasEnteredEntityZone', entity)
				LastEntity = entity
			end

		else

			if LastEntity ~= nil then
				TriggerEvent('esx_mecanojob:hasExitedEntityZone', LastEntity)
				LastEntity = nil
			end

		end

	end
end)


-- Key Controls
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		if CurrentAction ~= nil then

			SetTextComponentFormat('STRING')
			AddTextComponentString(CurrentActionMsg)
			DisplayHelpTextFromStringLabel(0, 0, 1, -1)

			if IsControlJustReleased(0, 38) and PlayerData.job ~= nil and PlayerData.job.name == 'mecano' then

				if CurrentAction == 'mecano_actions_menu' then
					OpenMecanoActionsMenu()
				end

				if CurrentAction == 'mecano_harvest_menu' then
					OpenMecanoHarvestMenu()
				end

				if CurrentAction == 'mecano_craft_menu' then
					OpenMecanoCraftMenu()
				end

				if CurrentAction == 'delete_vehicle' then

					if Config.EnableSocietyOwnedVehicles then

						local vehicleProps = ESX.Game.GetVehicleProperties(CurrentActionData.vehicle)
						TriggerServerEvent('esx_society:putVehicleInGarage', 'mecano', vehicleProps)

					else

						if
							GetEntityModel(vehicle) == GetHashKey('flatbed')   or
							GetEntityModel(vehicle) == GetHashKey('towtruck2') or
							GetEntityModel(vehicle) == GetHashKey('slamvan3')
						then
							TriggerServerEvent('esx_service:disableService', 'mecano')
						end

					end

					ESX.Game.DeleteVehicle(CurrentActionData.vehicle)
				end

				if CurrentAction == 'remove_entity' then
					DeleteEntity(CurrentActionData.entity)
				end

				CurrentAction = nil
			end
		end

		if IsControlJustReleased(0, Keys['F6']) and PlayerData.job ~= nil and PlayerData.job.name == 'mecano' then
			OpenMobileMecanoActionsMenu()
		end

		if IsControlJustReleased(0, Keys['DELETE']) and PlayerData.job ~= nil and PlayerData.job.name == 'mecano' then

			if NPCOnJob then

				if GetGameTimer() - NPCLastCancel > 5 * 60000 then
					StopNPCJob(true)
					NPCLastCancel = GetGameTimer()
				else
					ESX.ShowNotification(_U('wait_five'))
				end

			else

				local playerPed = GetPlayerPed(-1)

				if IsPedInAnyVehicle(playerPed,  false) and IsVehicleModel(GetVehiclePedIsIn(playerPed,  false), GetHashKey("flatbed")) then
					StartNPCJob()
				else
					ESX.ShowNotification(_U('must_in_flatbed'))
				end

			end

		end

	end
end)
