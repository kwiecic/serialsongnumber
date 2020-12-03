-- Interpretation des seriellen Signals des Liedanzeigers (St. Barabara Gelsenkirchen-Erle)
-- (c)2020 Michael Kwiatek
--
-- Test Values
-- AC1235689CCB		_123	5-8+9
-- ACCC95689C2BF	...9.	5-8+19
-- ACC683*13CCB		__68	3-13
-- ACCCCCCCCCCB		____	___
-- A12345667CCB		1234	5-6+7
-- A2C234*7C21B		G_23	4-7
-- ACC683493C2B		__68	3+9-13
-- A6C351#4C11B4	H_3.5	1-4
-- A1234CCCCCCB7	1.2.3.4	___

obs           = obslua
source_name   = ""

serial_string = ""
leertext      = ""
activated     = false

hotkey_id     = obs.OBS_INVALID_HOTKEY_ID

-- signalBytes
sB_Start = 1                --Stelle 01 - Immer "A"
sB_Lied1 = 2                --Stelle 02 - Lied 1. Stelle, Ziffer (T) oder Buchstabe
sB_Lied2 = 3                --Stelle 03 - Lied 2. Stelle, Ziffer (H)
sB_Lied3 = 4                --Stelle 04 - Lied 3. Stelle, Ziffer (Z)
sB_Lied4 = 5                --Stelle 05 - Lied 4. Stelle, Ziffer (E)
sB_Strophe1 = 6             --Stelle 06 - Strophe 1. Stelle, Ziffer (H)
sB_StropheVerbindung = 7    --Stelle 07 - Strophe +/-, Codierung in var "Verbindungssteuerzeichenzeichen"
sB_Strophe2 = 8             --Stelle 08 - Strophe 2. Stelle, Ziffer (Z)
sB_Strophe3 = 9             --Stelle 09 - Strophe 3. Stelle, Ziffer (E)
sB_Sonder1 = 10				--Stelle 10 - Sonderfunktion 1
sB_Sonder2 = 11             --Stelle 11 - Sonderfunktion 2
sB_Ende = 12                --Stelle 12 - Immer "B"
sB_Punktbyte = 13           --Stelle 13 - optional, Erweiterung Punktbyte

-- LookUp-Table für sB_StropheVerbindung
Verbindungssteuerzeichenzeichen = {}
Verbindungssteuerzeichenzeichen["C"] = {"",""}
Verbindungssteuerzeichenzeichen["#"] = {"+",""}
Verbindungssteuerzeichenzeichen["*" ]= {"-",""}
Verbindungssteuerzeichenzeichen["2"] = {"-",""}
Verbindungssteuerzeichenzeichen["4"] = {"+","-"}
Verbindungssteuerzeichenzeichen["5"] = {"+","+"}
Verbindungssteuerzeichenzeichen["6"] = {"-","+"}
-- LookUp-Table für Zeichen aus Sonderfunktionen
Zeichenliste = {{"0","1","A","C","E","F","H","J","L","P"},{"B","D","G","I","K","M","N","O","Q","R"},{"S","T","U","V","W","X","Y","Z","",""}}
-- LookUp-Table für erlaubte Zeichen
possibleValues = {"0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","*","#"}
-- LookUp-Table für Punkte in der Liednummer
pointsInSong = {}
pointsInSong["0"] = {"","","",""} 
pointsInSong["1"] = {".","","",""} 
pointsInSong["2"] = {"",".","",""} 
pointsInSong["3"] = {".",".","",""} 
pointsInSong["4"] = {"","",".",""} 
pointsInSong["5"] = {".","",".",""} 
pointsInSong["6"] = {"",".",".",""} 
pointsInSong["7"] = {".",".",".",""} 
pointsInSong["8"] = {"","","","."} 
pointsInSong["9"] = {".","","","."} 
pointsInSong["A"] = {"",".","","."} 
pointsInSong["B"] = {".",".","","."} 
pointsInSong["C"] = {"","",".","."} 
pointsInSong["D"] = {".","",".","."} 
pointsInSong["E"] = {"",".",".","."} 
pointsInSong["F"] = {".",".",".","."}

-- Some nice and helpful functions
function has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

function print_r(arr, indentLevel)
    local str = ""
    local indentStr = "#"
    if(indentLevel == nil) then
        print(print_r(arr, 0))
        return
    end
    for i = 0, indentLevel do
        indentStr = indentStr.."\t"
    end
    for index,value in pairs(arr) do
        if type(value) == "table" then
            str = str..indentStr..index..": \n"..print_r(value, (indentLevel + 1))
        else 
            str = str..indentStr..index..": "..value.."\n"
        end
    end
    return str
end

function listToString(arr)
	local output = ""
	for k, v in pairs(arr) do
		output = output ..  v -- concatenate values
	end
	return output
end

-- Functions for the textsignal interpretation
function readInSerialSignal()
    --hier muss der später der serielle Einlesevorgang hin,erstmal Testwerte
    readInData = serial_string
    --Signal auf Plausibilität prüfen
    errorOccured = false
    errorType = ""
    errorMsg = "Das Standardsignal für AUS 'ACCCCCCCCCCB' wurde stattdessen gesetzt."
    signallist = {}
    for i = 1, #readInData do
		signallist[i] = readInData:sub(i, i)
	end
	--print(string.len(readInData))	--DEBUG--
	--print_r(signallist)	--DEBUG--
	--print(signallist[sB_Start])	--DEBUG--
    --Länge prüfen
    if (string.len(readInData) ~= 12) and (string.len(readInData) ~= 13) then
        errorOccured = true
        errorType = "Signallänge falsch! (Es wurden " .. string.len(readInData) .. " Zeichen gefunden.)"
    --Prüfen ob Signalanfang und -ende stimmen
    elseif signallist[sB_Start] ~= "A" then
        errorOccured = true
        errorType = "Signalanfang (Signalbyte 1) ist falsch."
    elseif signallist[sB_Ende] ~= "B" then
        errorOccured = true
        errorType = "Signalende (Signalbyte 12) ist falsch."
    --Signalinhalt prüfen
    else
        i=1
        while (i <= string.len(readInData)) do
        	--print(i)
        	--print(signallist[i]) --DEBUG--
            if not has_value(possibleValues, signallist[i]) then
                errorOccured = true
                errorType = "Nicht erlaubtes Zeichen an Signalbyte " .. (i)
            end
            i = i+1
        end
    end           
    if errorOccured then
        print("Der FEHLER '" .. errorType .. "' ist aufgetreten!") --DEBUG
        print(errorMsg) --DEBUG
        readInData = "ACCCCCCCCCCB"
        signallist = {}
        for i = 1, #readInData do
			signallist[i] = readInData:sub(i, i)
		end
    end
    return signallist
end

function getSongNumber(signallist)
    local outputlist = {}
    local workinglist = {}
    --Liste mit benötigte Zeichen aus dem Signal zusammenbauen
    table.insert(workinglist, signallist[sB_Lied1])
	table.insert(workinglist, signallist[sB_Lied2])
	table.insert(workinglist, signallist[sB_Lied3])
	table.insert(workinglist, signallist[sB_Lied4])
    --Mögliche Punkte zwischen den Ziffern ermitteln
    points = getPointsInSong(signallist)
    i = 1
    while i <= table.getn(workinglist) do
        if workinglist[i] == "C" then
            table.insert(outputlist, " ")
        elseif i==1 and signallist[sB_Sonder2] == "1" then --Sonderfall Buchstabe an erster Stelle berücksichtigen  
        	print(Zeichenliste[ tonumber( signallist[sB_Sonder1] )][tonumber( workinglist[i] ) ])
            table.insert(outputlist, Zeichenliste[ tonumber( signallist[sB_Sonder1] )][tonumber( workinglist[i] )+1 ])
        else
            table.insert(outputlist, workinglist[i])
        end
        table.insert(outputlist, points[i])
        i = i+1
    end
    print_r(outputlist) -- DEBUG
    --Entferne führende Leerzeichen in der Liednummer ###TODO###
    local i = table.getn(outputlist)
    while i > 0 do
    	if outputlist[i] == " " then
    		table.remove(outputlist,i)
    	end
    	i = i-1
    end
    
	print_r(outputlist) -- DEBUG
    --Liste in String zurückwandlen
    output = listToString(outputlist)
    return output
end

function getVerseNumber(signallist)
    local outputlist = {}
    local workinglist = {}
    --Liste mit benötigte Zeichen aus dem Signal zusammenbauen
    table.insert(workinglist, signallist[sB_Strophe1])
    table.insert(workinglist, signallist[sB_Strophe2])
	table.insert(workinglist, signallist[sB_Strophe3])
    i = 1
    while i <= table.getn(workinglist) do
        if workinglist[i] == "C" then
            table.insert(outputlist, "")
        else
            if i==3 and signallist[sB_Sonder2] == "2" then   --Sonderfall "1" vor 3. Strophenzahl
                table.insert(outputlist, "1")
            end
            table.insert(outputlist, workinglist[i])
        end
        
        --Mögliche Verbindungszeichen hinzufügen
        if i == 1 then
            table.insert(outputlist, Verbindungssteuerzeichenzeichen[signallist[sB_StropheVerbindung]][1] )
        elseif i == 2 then
            table.insert(outputlist, Verbindungssteuerzeichenzeichen[ signallist[sB_StropheVerbindung]][2] )
        end
        i = i + 1
    end
    --Liste in String zurückwandlen
    output = listToString(outputlist)
    return output
end

function getPointsInSong(inputlist)
    local outputlist = {}
    local inputstring
    if table.getn(inputlist) == sB_Punktbyte then -- es existiert ein 13. Signalbyte
	-- inputlist[sB_Punktbyte] kann nur von 0-F sein, der Rest wird auf 0 gesetzt
        inputstring = inputlist[sB_Punktbyte]
        if not has_value({"0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F"}, inputstring) then
            errorOccured = true
            errorType = "Nicht erlaubtes Zeichen an Signalbyte " .. sB_Punktbyte
            inputstring = "0"
        end
        outputlist = pointsInSong[inputstring]
    end 
    -- 1 und 0 in "." und "" umwandeln
    i=1
    while i <= table.getn(outputlist) do
        if outputlist[i] == 1 then
           outputlist[i] = "."
        elseif outputlist[i] == 0 then
           outputlist[i] = ""
        end
        i = i+1
    end
    return outputlist
end

-- Function to set the time text
function set_text()
	local text
	
	--print_r(readInSerialSignal())
	--print(getSongNumber(readInSerialSignal()))
	
	text = "Song: " .. getSongNumber(readInSerialSignal()) .. "\n" .. "Str.: " .. getVerseNumber(readInSerialSignal())
	
	if text ~= last_text then
		local source = obs.obs_get_source_by_name(source_name)
		if source ~= nil then
			local settings = obs.obs_data_create()
			obs.obs_data_set_string(settings, "text", text)
			obs.obs_source_update(source, settings)
			obs.obs_data_release(settings)
			obs.obs_source_release(source)
		end
	end
	last_text = text
end

function activate(activating)
	if activated == activating then
		return
	end

	activated = activating

	if activating then
		set_text()
    end
end

-- Called when a source is activated/deactivated
function activate_signal(cd, activating)
	local source = obs.calldata_source(cd, "source")
	if source ~= nil then
		local name = obs.obs_source_get_name(source)
		if (name == source_name) then
			activate(activating)
		end
	end
end

function source_activated(cd)
	activate_signal(cd, true)
end

function source_deactivated(cd)
	activate_signal(cd, false)
end

function reset(pressed)
	if not pressed then
		return
	end

	activate(false)
	local source = obs.obs_get_source_by_name(source_name)
	if source ~= nil then
		local active = obs.obs_source_active(source)
		obs.obs_source_release(source)
		activate(active)
	end
end

function reset_button_clicked(props, p)
	reset(true)
	return false
end

----------------------------------------------------------
-- A function named script_properties defines the properties that the user
-- can change for the entire script module itself
function script_properties()
	local props = obs.obs_properties_create()
	obs.obs_properties_add_text(props, "serial_string", "Serieller String (Test)", obs.OBS_TEXT_DEFAULT)
	obs.obs_properties_add_text(props, "leertext", "Platzhalter", obs.OBS_TEXT_DEFAULT)
			
	local p = obs.obs_properties_add_list(props, "source", "Text Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_id(source)
			if source_id == "text_gdiplus" or source_id == "text_ft2_source" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(p, name, name)
			end
		end
	end
	obs.source_list_release(sources)

	obs.obs_properties_add_button(props, "reset_button", "Reset", reset_button_clicked)
	return props
end

-- A function named script_description returns the description shown to
-- the user
function script_description()
	return "Reads the serial input of the songnumber display in St. Barbara, Gelsenkirchen-Erle.\n\nMade by Michael Kwiatek"
end

-- A function named script_update will be called when settings are changed
function script_update(settings)
	activate(false)
	serial_string = obs.obs_data_get_string(settings, "serial_string")
	leertext = obs.obs_data_get_string(settings, "leertext") 
	source_name = obs.obs_data_get_string(settings, "source")
	reset(true)
end

-- A function named script_defaults will be called to set the default settings
function script_defaults(settings)
	obs.obs_data_set_default_string(settings, "serial_string", "AC1235689CCB")
	obs.obs_data_set_default_string(settings, "leertext", "####")
	obs.obs_data_set_default_string(settings, "source", "Liednummer")
end

-- A function named script_save will be called when the script is saved
-- NOTE: This function is usually used for saving extra data (such as in this case, a hotkey's save data). Settings set via the properties are saved automatically.
function script_save(settings)
	local hotkey_save_array = obs.obs_hotkey_save(hotkey_id)
	obs.obs_data_set_array(settings, "reset_hotkey", hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
end

-- A function named script_load will be called on startup
function script_load(settings)
	-- Connect hotkey and activation/deactivation signal callbacks
	-- NOTE: These particular script callbacks do not necessarily have to be disconnected, as callbacks will automatically destroy themselves if the script is unloaded.  So there's no real need to manually disconnect callbacks that are intended to last until the script is unloaded.
	local sh = obs.obs_get_signal_handler()
	obs.signal_handler_connect(sh, "source_activate", source_activated)
	obs.signal_handler_connect(sh, "source_deactivate", source_deactivated)

	hotkey_id = obs.obs_hotkey_register_frontend("reset_timer_thingy", "Reset Timer", reset)
	local hotkey_save_array = obs.obs_data_get_array(settings, "reset_hotkey")
	obs.obs_hotkey_load(hotkey_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
end
