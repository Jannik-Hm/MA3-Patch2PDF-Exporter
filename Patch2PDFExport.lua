function customExportJson(exportPath, table)
    local json = require "json";
    local encoded = json.encode(table);
    local file = io.open(exportPath,'w');
    file:write("{\"MA3Patch2PDF\":"..encoded.."}");
    file:close();
    return true;
end

local function createdir(path)
    local lfs = require("lfs");
	local f=io.open(path,"r")
	if f~=nil then
		io.close(f)
		return false;
	else
        lfs.mkdir(path);
		return true;
	end
end

local function intoreverseBinary(n)
	local binNum = ""
	if n ~= 0 then
		while n >= 1 do
			if n %2 == 0 then
				binNum = binNum .. "0"
				n = n / 2
			else
				binNum = binNum .. "1"
				n = (n-1)/2
			end
		end
	else
		binNum = "0"
	end
    local binNumLen = string.len(tostring(binNum));
    if(binNumLen < 10) then
        for i=0,9-binNumLen,1 do
            binNum = binNum.."0";
        end
        return binNum;
    else
        return binNum
    end
end

local function roundTo2Dec(num)
    return (math.floor(num * 100 + 0.5)/100);
end

local function checkIfGroup(fixture)
    if next(fixture:Children()) ~= nil then
        for _, child in pairs(fixture:Children()) do
            if(child.fixturetype ~= nil) then
                return true;
            end
        end
    end
    return false;
end

local function handleFixture(fixture)
    if(fixture.patch ~= "") then
        local temp = {};
        temp = {};
        temp.Name = fixture.name;
        temp.Type = "Fixture";
        local temppatch = {};
        for w in string.gmatch(fixture.patch, "%d+.") do
            local num = w:gsub("%.", "");
            table.insert(temppatch, num);
        end
        temp.Patch = fixture.patch;
        temp.DipPatch = intoreverseBinary(tonumber(temppatch[2]));
        temp.FixtureID = fixture.fid;
        temp.FixtureType = fixture.fixturetype.name;
        temp.Position = {
            Location = {
                x = roundTo2Dec(fixture.posx),
                y = roundTo2Dec(fixture.posy),
                z = roundTo2Dec(fixture.posz)
            },
            Rotation = {
                x = fixture.rotx,
                y = fixture.roty,
                z = fixture.rotz,
            }
        };
        return temp;
    end
end

local function handleGroup(group)
    if (group.fixturetype.name ~= "Universal") then
        local temp = {};
        temp.Type = "Group";
        temp.index = group.index;
        temp.FixtureType = group.fixturetype.name;
        temp.name = group.name;
        local fixtures = {};
        local groups = {};
        for _, fixture in pairs(group:Children()) do
            if(fixture ~= nil) then
                if(checkIfGroup(fixture)) then
                    table.insert(groups, handleGroup(fixture));
                else
                    table.insert(fixtures, handleFixture(fixture));
                end
            end
        end
        temp.subgroups = groups;
        temp.fixtures = fixtures;
        return temp;
    end
end

local function main()
    local data = {};
    local stagetable = {};

    for stagekey, stage in pairs(Patch().Stages:Children()) do
        stagetable[stage.name] = stagekey;
	end
    local drivetable = {};
    local drivelist = {};
    for drivekey, drive in pairs(Root().Temp.DriveCollect:Children()) do
        drivetable[drive.name] = drivekey;
        table.insert(drivelist, drive.name);
    end


    local defaultCommandButtons = {
        {value = 1, name = "OK"},
        {value = 0, name = "Cancel"}
    }
    local inputFields = {
        {name = "Showname", value = Root().manetsocket.showfile, blackFilter = "!?", vkPlugin = "TextInput"},
        {name = "Filename", value = Root().manetsocket.showfile, blackFilter = ".!?/", vkPlugin="TextInput"}
    }

    local selectorButtons = {
        { name="Drive", selectedValue=1, type=1, values=drivetable},
        { name="Stage", selectedValue=1, type=1, values=stagetable}
    }

    local messageTable = {
        icon = "file",
        title = "Patch2PDFExporter",
        commands = defaultCommandButtons,
        inputs = inputFields,
        selectors = selectorButtons
    }
    local inputTable = MessageBox(messageTable);

    if(inputTable.result == 1) then
        local stageindex = inputTable.selectors.Stage;
        local stage = Patch().Stages[stageindex];
        data.Version = "GMA3";
        data.stagename = stage.name;
        data.data = {};
        data.data.groups = {};
        data.data.fixtures = {};
        for _, group in pairs(stage.Fixtures:Children()) do
            if(group ~= nil) then
                if(checkIfGroup(group)) then
                    data.data.groups[group.name] = handleGroup(group);
                else
                    local fixture = handleFixture(group);
                    if(fixture ~= nil) then
                        table.insert(data.data.fixtures, fixture);
                    end
                end
            end
        end

        --Select Drive
        local driveindex = inputTable.selectors.Drive;
        Cmd("Select Drive " .. (driveindex));
        local exportPath = GetPath(Enums.PathType.Library) .. "/../Patch2PDFExport/";
        createdir(exportPath);

        local showname = inputTable.inputs.Showname;

        local filename = inputTable.inputs.Filename:gsub("[/.]", {["/"] = "", ["."] = ""});
        local filePath = exportPath .. filename .. ".json"

        data.showname = showname;
        data.exportTime = os.date("%Y-%m-%dT%H:%M:%S");
        data.HostOS = HostOS();

        --ExportJson(exportPath, data)
        if (customExportJson(filePath, data)) then
            MessageBox(
            {
                title = "Patch was exported to Drive: " .. drivelist[driveindex] .. "\nas: " .. filename .. ".json",
                commands = {{value = 1, name = "Confirm"}}
            }
        )
        end
    else
        Echo("aborted Patch2PDFExporter");
    end

end

return main