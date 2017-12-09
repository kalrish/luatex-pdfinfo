local string_format = string.format
local string_utfvalues = string.utfvalues
local table_concat = table.concat


local module_name = "pdfinfo"

local warn
if luatexbase then
	luatexbase.provides_module{
		name=module_name,
		date="2017/04/23"
	}
	
	warn = function(s)
		luatexbase.module_warning(module_name, s)
	end
else
	warn = function(s)
		texio.write_nl("pdfinfo: warning: " .. s)
	end
end

if status.ini_version == true then
	warn("document information dictionary is not dumped in the format, i.e. is to be set in the typesetting run")
end

local utf16be_text_encoder = function( s )
	local t = { "<FEFF" }
	local n = 2
	
	for code_point in string_utfvalues(s) do
		if code_point < 0x10000 then
			t[n] = string_format("%02X%02X", code_point/256, code_point%256)
		else
			code_point = code_point - 0x10000
			local high_surrogate = code_point / 1024 + 0xD800
			local low_surrogate = code_point % 1024 + 0xDC00
			t[n] = string_format("%02X%02X%02X%02X", high_surrogate/256, high_surrogate%256, low_surrogate/256, low_surrogate%256)
		end
		n = n + 1
	end
	
	t[n] = ">"
	
	return table_concat(t)
end

local date_handler = function( args )
	return string_format("(D:%04i%02i%02i%02i%02i%02i%02i%02i%02i)", args.year, args.month, args.day, args.hour, args.minute, args.second, args.relationship_to_ut, args.offset_hours, args.offset_minutes)
end

local argument_translation_table = {
	title = {
		key="Title",
		pdfversion={
			major=1,
			minor=1
		},
		handler=utf16be_text_encoder
	},
	author = {
		key="Author",
		handler=utf16be_text_encoder
	},
	subject = {
		key="Subject",
		pdfversion={
			major=1,
			minor=1
		},
		handler=utf16be_text_encoder
	},
	keywords = {
		key="Keywords",
		pdfversion={
			major=1,
			minor=1
		},
		handler=utf16be_text_encoder
	},
	creator = {
		key="Creator",
		handler=utf16be_text_encoder
	},
	producer = {
		key="Producer",
		handler=utf16be_text_encoder
	},
	creation_date = {
		key="CreationDate",
		handler=date_handler
	},
	mod_date = {
		key="ModDate",
		handler=date_handler,
		pdfversion={
			major=1,
			minor=1
		}
	},
	trapped = {
		key="Trapped",
		handler = function( v )
			if v == true then
				return " True"
			elseif v == false then
				return " False"
			elseif v == "unknown" then
				return " Unknown"
			else
				warn("wrong value passed for 'Trapped'")
			end
		end
	}
}


local compute_metadata = function( t )
	local s = ""
	
	for key, value in pairs(t) do
		local entry = argument_translation_table[key]
		if entry then
			local doable = false
			
			if entry.pdfversion then
				if pdf.getversion() >= entry.pdfversion.major then
					if pdf.getminorversion() < entry.pdfversion.minor then
						warn("entry '" .. entry.key .. "' requires PDF minor version " .. entry.pdfversion.minor .. "; setting it")
						
						pdf.setminorversion(entry.pdfversion.minor)
					end
					
					doable = true
				else
					warn("entry '" .. entry.key .. "' requires PDF major version " .. entry.pdfversion.major)
				end
			else
				doable = true
			end
			
			if doable then
				s = s .. "/" .. entry.key .. entry.handler(value)
			end
		else
			warn("entry '" .. key .. "' unknown")
		end
	end
	
	return s
end

return {
	getmetadata = function()
		return assert(false)
	end,
	computemetadata = compute_metadata,
	setmetadata = function( t )
		if tex.outputmode == 1 or status.ini_version == true then
			pdf.setinfo(compute_metadata(t))
		else
			warn("output format is not PDF")
		end
	end
}