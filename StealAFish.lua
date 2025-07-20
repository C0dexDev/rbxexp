--//Variables
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesFolder = ReplicatedStorage:WaitForChild("voidSky"):WaitForChild("Remotes")

local Remotes = {
    BuyButton = RemotesFolder:WaitForChild("Server"):WaitForChild("Objects"):WaitForChild("BuyButton"),
    Steal = RemotesFolder:WaitForChild("Server"):WaitForChild("Objects"):WaitForChild("Trash"):WaitForChild("Steal"),
}

local Tycoons = workspace:WaitForChild("Map"):WaitForChild("Tycoons")

local LocalPlayer = Players.LocalPlayer

local Settings = {
    StealFilter = {
        MinPrice = 1000000,
        MinDrop = 3000,
    } 
}
--//Internal variables
local stealing = false
local safePlatform = nil
--//Functions
function GetLocalPlayerTycoon()
    local result = nil
    for _,tycoon in Tycoons:GetChildren() do
        if tycoon:GetAttribute("Owner") == LocalPlayer.Name then
            result = tycoon
        end
    end
    return result
end

function FindMostValueTrash()
    print("Finding most value trash.")
    local valuableList = {}
    for _,tycoon in Tycoons:GetChildren() do
        if tycoon == GetLocalPlayerTycoon() then continue end
        local TimeLabel = tycoon.Tycoon.ForcefieldFolder.Screen.Screen.SurfaceGui.Time
        if not TimeLabel then continue end
        if string.find(TimeLabel.Text, "h") then continue end
        for _,trash in tycoon.Temporary:GetChildren() do
            local Info = trash.Information
            local Price = Info.Price.Value
            local Drop = Info.Drop.Value
            if Price < Settings.StealFilter.MinPrice or Drop < Settings.StealFilter.MinDrop then
                print("Too poor: "..trash.Name..". Price: "..Price.."/"..Settings.StealFilter.MinPrice..", Drop: "..Drop.."/"..Settings.StealFilter.MinDrop)
                continue
            end
            if IsUnstealable(trash) then
                print("Unstealable: "..trash.Name)
                continue
            end
            table.insert(valuableList,trash)
        end
    end
    local best = nil
    local bestValue = 0
    for _,trash in valuableList do
        local value = trash.Information.Drop.Value + trash.Information.Price.Value
        if value > bestValue then
            best = trash
            bestValue = value
        end
    end
    return best
end

function SafePlatform()
    local Root = GetRoot()
    if not Root then return end
    if not safePlatform then
        safePlatform = Instance.new("Part",workspace)
        safePlatform.Size = Vector3.new(10,.1,10)
        safePlatform.CanCollide = true
        safePlatform.Anchored = true
        safePlatform.Position = Root.Position + Vector3.new(0,500,0)
    end
    Root.CFrame = CFrame.new(safePlatform.Position + Vector3.new(0,5,0))
end

function GetChar()
    local Char = LocalPlayer.Character
    if not Char then return nil end
    return Char
end

function StealBest()
    if stealing then
        warn("Already stealing, please wait.")
        return
    end
    stealing = true
    local Root = GetRoot()
    local Char = GetChar()
    if not Root or not Char then
        warn("No root or no char. Cancelling.")
        return 
    end
    local OgPos = Root.Position
    local function Cancel()
        stealing = false
        Root.CFrame = CFrame.new(OgPos)
    end
    local BestTrash = FindMostValueTrash()
    if not BestTrash then
        warn("Couldnt find a valuable trash to steal. Cancelling.")
        Cancel()
        return
    end
    local TargetTycoon = BestTrash.Parent.Parent
    local OwnerName = TargetTycoon:GetAttribute("Owner")
    if not OwnerName then
        warn("Couldnt get target tycoon's owner name. Cancelling.")
        Cancel()
        return
    end
    local TargetPlayer = Players:FindFirstChild(OwnerName)
    if not TargetPlayer then
        warn("Failing getting target player. Cancelling.")
        Cancel()
        return
    end
    SafePlatform()
    repeat
        if(ExpiredForcefield(GetLocalPlayerTycoon())) then
            RenewForcefield()
            SafePlatform()
        end
        print("Waiting for perfect moment :)")
        task.wait()
    until ExpiredForcefield(TargetTycoon) or not BestTrash:IsDescendantOf(TargetTycoon)
    if not ExpiredForcefield(TargetTycoon) then
        warn("Something went wrong. The target tycoon's forcefield activated too fast or something else happened. Cancelling.")
        Cancel()
        return
    end
    if not BestTrash:IsDescendantOf(TargetTycoon) then
        warn("The target trash disappeared. Cancelling.")
        Cancel()
        return
    end
    local TrashRoot = BestTrash.PrimaryPart
    if not TrashRoot then
        warn("Couldnt get target trash's root part. Cancelling.")
        Cancel()
        return
    end
    local TrashPos = TrashRoot.Position
    repeat
        Root.CFrame = CFrame.new(TrashPos)
        local args = {
	        TargetPlayer,
	        BestTrash:GetAttribute("Trash_ID")
        }
        Remotes.Steal:FireServer(unpack(args))
        task.wait()
    until Char:FindFirstChild("StolenObject") or not Char:IsDescendantOf(workspace) or not BestTrash:IsDescendantOf(TargetTycoon)
    if not Char:IsDescendantOf(workspace) then
        warn("Local character was destroyed. Cancelling.")
        stealing = false
        return
    end
    if not Char:FindFirstChild("StolenObject") then
        warn("Something went wrong while bringing the trash to your base. Cancelling.")
        Cancel()
        return
    end
    SafePlatform()
    task.wait(10)
    Root.CFrame = CFrame.new(GetLocalPlayerTycoon():FindFirstChild("BaseDetector",true).Position)
    repeat
        task.wait()
        print("Waiting for stolen object to be added to your base...")
    until not Char:IsDescendantOf(workspace) or not Char:FindFirstChild("StolenObject")
    if not Char:IsDescendantOf(workspace) then
        warn("Your character was destroyed while trying to bring the stolen trash to your base. Cancelling.")
        stealing = false
        return
    end
    print("Stole the most valuable trash in the server! :)")
    Cancel()
end

function ExpiredForcefield(tycoon)
    local t = tycoon or GetLocalPlayerTycoon()
    if not t then return false end
    local TimeLabel = t.Tycoon.ForcefieldFolder.Screen.Screen.SurfaceGui.Time
    if not TimeLabel then return false end
    return TimeLabel.Text == "0s"
end

function GetRoot()
    local Char = LocalPlayer.Character
    if not Char then return nil end
    local Root = Char.PrimaryPart
    if not Root then return nil end
    local Hum = Char.Humanoid
    if not Hum or Hum.Health <= 0 then return nil end
    return Root
end

function IsUnstealable(TrashModel)
    for _,d in TrashModel:GetDescendants() do
        if d:IsA("TextLabel") and d.Text == "UNSTEALABE" then
            return true
        end
    end
    return false
end

function RenewForcefield()
    print("Renewing forcefield!")
    if not ExpiredForcefield() then return end
    local Root = GetRoot()
    if not Root then return end
    local t = GetLocalPlayerTycoon()
    if not t then return end
    local Base = t:FindFirstChild("BaseDetector",true)
    if not Base then return end
    local ForcefieldButton = t.Tycoon.ForcefieldFolder.Buttons.ForceFieldBuy
    if not ForcefieldButton then return nil end
    local OgPos = Root.Position
    for i = 0, 10 do
        Root.CFrame = CFrame.new(Base.Position)
        Remotes.BuyButton:FireServer(ForcefieldButton)
        task.wait(.1)
        if not ExpiredForcefield() then break end
    end
    Root.CFrame = CFrame.new(OgPos)
end
--//Main Code
print("EXECUTED!")
StealBest()
--//Async loops
--[[
while task.wait() do --Forcefield renew
    if stealing then continue end
    if ExpiredForcefield() then
        RenewForcefield()
    end
end
]]--
