local sha     = require('sha1')
local socket  = require('socket')
local only    = require('only')
local cutils  = require('cutils')
local cjson   = require('cjson')

local BASE = _G

module('utils', package.seeall)


--[[=================================LUA FUNCTION=======================================]]--
function shallowcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in pairs(orig) do
			copy[orig_key] = orig_value
		end
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

function get_sha_tab_count(ht)
	-->> get sha table count;we shoud use #tab when table members is common element.
	local n = 0
	if type(ht) ~= 'table' then
		return n
	end

	for _ in pairs(ht) do
		n = n + 1
	end
	return n
end

function tab_remove_ivalue( t, m )
	--[[
	if m == nil then
	local max = 1
	for i in pairs(t or {}) do
	if type(i) == "number" and i > max then
	max = i
	end
	end
	local i = 1
	while i <= max do
	while (t[i] == nil) and (i <= max) do
	-->|print( "remove:" .. i)
	table.remove(t, i)-->have bug,can't remove second
	max = max - 1
	end
	i = i + 1
	end
	else
	]]--
	for i,v in ipairs(t or {}) do
		while t[i] == m do
			-->|print( "remove:" .. t[i])
			table.remove(t, i)
		end
		-->|print( "retain:" .. t[i])
		-->|if i >= #abc then break end
	end
	--end
end

-->> split string into table
function str_split(s, c)
	if not s then return nil end

	local m = string.format("([^%s]+)", c)
	local t = {}
	local k = 1
	for v in string.gmatch(s, m) do
		t[k] = v
		k = k + 1
	end
	return t
end

function safe_sort( L, F )
	local isF = true
	for m=#L-1,1,-1 do
		isF = true
		for i=#L-1,1,-1 do
			local prior = false
			if F then
				prior = F( L[i], L[i+1] )
			else
				prior = L[i] > L[i+1]
			end
			if prior then
				L[i],L[i+1]=L[i+1],L[i]
				isF = false
			end
		end
		if isF then break end
	end
	-->|for k,v in ipairs(L) do
	-->|	print(k.." is "..v)
	-->|end
end

function safe_cntl_sort( L, M, F, ... )-->M : [false] ascending	[true] descending
	M = M and true or false
	local isF = true
	for m=#L-1,1,-1 do
		isF = true
		for i=#L-1,1,-1 do
			local prior = false
			if F then
				local cmp1,cmp2 = F( L[i], L[i+1], ... )
				prior = cmp1 > cmp2
			else
				prior = L[i] > L[i+1]
			end
			if M ~= prior then
				L[i],L[i+1]=L[i+1],L[i]
				isF = false
			end
		end
		if isF then break end
	end
	-->|for k,v in ipairs(L) do
	-->|	print(k.." is "..v)
	-->|end
end

------> method 1
function load_lua_string(S)
	local F,err = loadstring(S)
	if not F then
		only.log("E", err)
	end
	return F
end

function run_lua_function(F, ...)
	return pcall(F, ...)
end
------> method 2
function run_lua_string(S, ...)
	local F,err = loadstring(S)
	if not F then
		only.log("E", err)
	end
	return pcall(F, ...)
end
--[[
------> method 3
function safe_call(F, ...)
local info = { pcall(F, ...) }
if not info[1] then
only.log("E", info[2])
end
return unpack(info)
end
]]--

function json_decode(str)

	if not str then
		return false, nil
	end
	return pcall(cjson.decode, str)
end

function json_encode(tab)

	if not tab then
		return false, nil
	end

	local empty_tab = true
	for k in pairs(tab) do
		empty_tab = false
		do break end
	end

	if empty_tab then
		return true, '[ ]'
	else
		return pcall(cjson.encode, tab)
	end

end


--[[=================================HTTP FUNCTION=======================================]]--
function url_decode(str)
	if not str then return nil end
	--[[
	local ngx = require('ngx')
	local str = ngx.unescape_uri(str)
	return str
	]]--
	str = string.gsub (str, "+", " ")
	str = string.gsub (str, "%%(%x%x)",
	function(h) return string.char(tonumber(h,16)) end)
	str = string.gsub (str, "\r\n", "\n")
	return str
end

function url_encode(str)
	if not str then return nil end
	--[[
	local ngx = require('ngx')
	local str = ngx.escape_uri(str)
	return str
	]]--
	if (str) then
		str = string.gsub (str, "\n", "\r\n")
		str = string.gsub (str, "([^%w])",
		function (c)
			return string.format ("%%%02x", string.byte(c))
		end
		)
		str = string.gsub (str, " ", "+")
	end
	return str
end

function gen_url(T)
	local url
	for k,v in pairs(T) do
		if url then
			url = string.format([[%s&%s=%s]], url, k, v)
		else
			url = k .. '=' .. v
		end
	end
	return url
end

function gen_sign(T, secret)
	if not secret then
		local redis_api = require('redis_pool_api')
		local ok, res = redis_api.cmd('public', "", 'hget', T['appKey'] .. ':appKeyInfo', 'secret')
		secret = res
	end

	local kv_table = {}
	for k,v in pairs(T) do
		if type(v) ~= "table" then
			if k ~= "sign" then
				table.insert(kv_table, k)
			end
		end
	end
	table.insert(kv_table, "secret")
	table.sort(kv_table)
	local sign_string = kv_table[1] .. T[kv_table[1]]
	for i = 2, #kv_table do
		if kv_table[i] ~= 'secret' then
			sign_string = sign_string .. kv_table[i] .. T[kv_table[i]]
		else
			sign_string = sign_string .. kv_table[i] .. secret
		end
	end
	only.log("D", sign_string)
	--local ngx = require('ngx')
	--local raw_sign_str = ngx.escape_uri(sign_string)
	--only.log("D", raw_sign_str)


	--local result = sha.sha1(raw_sign_str)
	local result = sha.sha1(sign_string)
	local sign_result = string.upper(result)
	only.log("D", sign_result)

	return sign_result
end

function get_data(url, info)
	return string.format('GET /%s HTTP/1.0\r\nHost: %s:%s\r\nContent-Type: application/x-www-form-urlencoded\r\nConnection: close\r\n\r\n', url, info["host"], info["port"])
end

function post_data(url, info, data, req_type)
	req_type = req_type or 'application/x-www-form-urlencoded'
	return string.format('POST /%s HTTP/1.0\r\nHost: %s:%s\r\nContent-Type: %s\r\nContent-Length: %s\r\nConnection: close\r\n\r\n%s', url, info["host"], info["port"], req_type, tostring(#data), data)
end

function say_data( body )
	return string.format('HTTP/1.1 200 OK\r\nServer: nginx/1.4.2\r\nContent-Type: text/html\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s', #body, body)
end

function get_http11_body(info)
	local _st,_ed = string.find(info, "Content%-Length%:%s-%d+%\r%\n")
	if _st then
		local content_length= string.sub(info, _st, _ed)
		_st,_ed = string.find(content_length, "%d+")
		local len = string.sub(content_length, _st, _ed)

		_st,_ed = string.find(info, "%\r%\n%\r%\n")
		if not _st then return nil end
		local body = string.sub(info, _ed + 1 , _ed + len)
		return body
	else
		local body = ""
		local next_info = info
		_st,_ed = string.find(info, "%\r%\n%\r%\n%x+%\r%\n")
		repeat
			if not _st then return nil end
			local body_st = _ed
			local content_length= string.sub(next_info, _st, _ed)
			_st,_ed = string.find(content_length, "%x+")
			local len_H = string.sub(content_length, _st, _ed)
			local len = 0
			local H_string = "0123456789abcdef"
			for i=1,string.len(len_H) do
				--because find result start from 1
				--but number is start from 0
				local add = string.find(H_string, string.sub(len_H, i, i)) - 1
				only.log('D', "H = " .. tostring(add))
				for j=1,(string.len(len_H) - i) do
					add = add * 16
					only.log('D', "ADD = " .. tostring(add))
				end
				len = len + add
			end
			only.log('D', "len = " .. len)
			body = body .. string.sub(next_info, body_st + 1 , body_st + len)
			only.log('D', body)

			next_info = string.sub(next_info, body_st + len + 1)
			_st,_ed = string.find(next_info, "%\r%\n%x+%\r%\n")
		until len == 0
		return body

	end
end

function parse_url(s)
	if not s then return nil end

	local t = {}
	for k, v in string.gmatch(s, "([^=&]+)=([^=&]*)") do
		t[k] = url_decode(v)
	end
	return t
end

function parse_api_result(ret, api_name)
	if not ret then
		only.log('E', "no return back from call api " .. (api_name or "") )
		return nil
	end

	local info = string.match(ret, '.-\r\n\r\n(.+)')

	local ok,data = pcall(cjson.decode, info)
	if (not ok) or (tonumber(data["ERRORCODE"]) ~= 0) then
		only.log('E', info)
		return nil
	end
	--only.log('D', info)
	return data["RESULT"]
end

--[[=================================RANDOM FUNCTION=======================================]]--
local random_table = {
	'0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
	'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J',
	'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T',
	'U', 'V', 'W', 'X', 'Y', 'Z',
	'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j',
	'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't',
	'u', 'v', 'w', 'x', 'y', 'z'
} --62


function random_singly()
	local t = socket.gettime()
	local st = string.format("%f", t)
	local d = string.sub(st, -2, -1)
	local n = tonumber(d) % 10
	return n
end

function random_number(nub)
	local val = ''
	for i=1,nub do
		local rad = random_singly()
		val = val .. rad
	end
	return val
end

function random_among(_st, _ed)
	local btw = tostring(_ed - _st)
	local fld =  string.find(btw, '%.')

	local src = {}
	local nb, sv
	local rt = ""
	local step = 1
	local is_little = false
	local newbits = 0
	local allbits = 0
	if not fld then
		src[1] = btw
	else
		src[1] = string.sub(btw, 1, fld - 1)
		src[2] = string.sub(btw, fld + 1, -1)
	end
	repeat
		allbits = #src[step]
		newbits = (random_number(allbits) % allbits) + 1
		if newbits ~= allbits then
			rt = random_number(newbits)
		else
			for i=1, allbits do
				if is_little then
					sv = random_singly()
				else
					nb = tonumber(string.sub(src[step], i, i))
					sv = random_singly() % (nb + 1)
					if sv < nb then
						is_little = true
					end
				end
				rt = rt .. sv
			end
		end
		if not fld then
			--goto EXIT
			break
		else
			if step == 1 then
				rt = rt .. '.'
			end
			step = step + 1
		end
	until step == 2
	--::EXIT::
	return (tonumber(rt) + _st)
end


function random_string(nub)
	local var = ''
	for i=1,nub do
		local ret = random_among(1111111111, 9999999999999)
		local rad1 = tonumber(string.format("%d", ret / 62))
		local rad2 = rad1 % 62 +1		--#random_table  <----->  62

		var = var .. random_table[rad2]
	end
	return var
end

--[[=================================CHECK FUNCTION=======================================]]--
function is_number(str)
	if type(str) == "number" then return true end
	if (not str) or (type(str) ~= "string") then return nil end
	local ret = string.find(tostring(str), '^%d+$')--'^[0-9]+$'
	return ret
end

function is_word(str)
	if not str then return nil end
	local ret = string.find(tostring(str), '^%w+$')
	return ret
end

function is_float(str)
	str = tonumber(str)
	if not str then return false end
	local ret = string.find(tostring(str), '^[-+]?%d*%.?%d+$')
	return ret
end

function is_integer(str)
	str = tonumber(str)
	if not str then return false end
	local ret = string.find(tostring(str), '^[-+]?%d+$')
	return ret
end


function check_accountID(accountID)
	if accountID == nil or (not is_word(accountID)) or #accountID ~= 10 then
		return false
	end

	return true
end

function check_imei(imei)
	if not imei or (not is_number(imei)) or (#imei~=15) or (string.sub(imei, 1, 1)=='0') then
		return false
	end

	return true
end

-- create uuid, and escape the '-'
function create_uuid()
	local uuid = cutils.uuid()
	return string.gsub(uuid, '-', '')
end

-- escape some special character
function escape_redis_text(text)

	if not text then return nil end

	local str = string.gsub(text, '%%', '%%%%')
	return str
end

function escape_mysql_text(text)

	if not text then return nil end

	local str = string.gsub(text, "'", "''")
	str = string.gsub(str, '\\', '\\\\')
	return str
end

local function get_file_type(fileName)
        local fileType = nil 
        for a in string.gfind(fileName or '','%.(%w+)') do
                fileType = a 
        end 
        return fileType
end


function parse_form_data(head, body)
	-- keep compatibility
	local low_head = string.lower(head)
	local check_boundary = string.match(low_head, "content%-type:%s?multipart/form%-data;%s?boundary=(..-)\r\n")
	if not check_boundary then
		return nil
	end
	---- http的body第一个字节不是回车换行开始
	local first_pos = string.find(body,"\r\n")
	if not first_pos then
		return nil
	end
	
	------------------------------------------------------------------------------------------------------------------------
	local head_boundary = string.match(head, 'boundary=(..-)\r\n')
	head_boundary = string.gsub(head_boundary, '[%^%$%(%)%%%.%[%]%*%+%-%?%)]', '%%%1')
	local body_boundary = string.sub(body, 1, first_pos - 1)
	body_boundary = string.gsub(body_boundary, '[%^%$%(%)%%%.%[%]%*%+%-%?%)]', '%%%1')
	------------------------------------------------------------------------------------------------------------------------
	local form_kv = head_boundary .. '\r\nContent%-Disposition:%s?form%-data;%s?name="([%w_]+)".-\r\n\r\n(.-)\r\n'
	local form_fv = body_boundary .. '\r\nContent%-Disposition:%s?form%-data;%s?name="([%w_]+)";%s?filename="(.-)"\r\n.-Content%-Type:%s?([%w/-]+).-\r\n\r\n(.-)\r\n' .. body_boundary
	if head_boundary ~= body_boundary then
		form_kv = '%-' .. form_kv .. '%-'
	end
	------------------------------------------------------------------------------------------------------------------------
	--local form_fv = '%-' .. boundary .. '\r\nContent%-Disposition:%s?form%-data;%s?name="([%w_]+)";%s?filename="([%w%._]+)"\r\nContent%-Type:%s?([%w/-]+).-\r\n\r\n(.-)\r\n%-'
	--如果存在Content-Transfer-Encoding: binary,需要修改表达式,添加.-   \r\n.-Content
	--2014-05-12 jiang z.s.   
	--2014-05-13 jiang z.s. filename 可能为中文名
	------------------------------------------------------------------------------------------------------------------------

	-- the single chunk in http body's content-type may have more value, but we don't care them, so we should use '.-' to escape it, the exactly content is after the '\r\n\r\n'
	local tab = {}
	for key,val in string.gfind(body, form_kv) do
		tab[ key ] = val
	end

	---- jiang z.s. 2014-06-24
	---- 分割符号,严格使用body内的内容
	---- 分割方式首位都添加分割符号,避免二进制文件存在%-,导致无法解析
	if not body or #body < 20 then
		return tab
	end

	-->dfsapi save multi file
	-->lipengwei add 2015.1.13
	----------------------------------------------------------------------
	--Content-Disposition: form-data; name="scene"; filename="2.png"
	--Content-Type: image/png
	local gsub_fv = '\r\nContent%-Disposition:%s?form%-data;%s?name="([%w_]+)";%s?filename="(.-)"\r\n.-Content%-Type:%s?([%w/-]+).-\r\n\r\n(.-)\r\n'
	------------------------------------------------------------------------
	if tab['fileCount'] and tonumber(tab['fileCount']) and tab['fileTotalSize'] and tonumber(tab['fileTotalSize'])then
                for a=1,tab['fileCount'] do
                        local temp_tab = {}
                        local name,file,dtype,data = string.match(body, form_fv)
         	        if not file or #file == 0 or not data or #data == 0 then
                        	break
                        end
	                temp_tab = {file_name = file, data_type = get_file_type(file), data = data}
                        table.insert(tab,temp_tab)
                        for l,m in pairs(temp_tab) do
                                only.log("D",'---->>>---%s:---%s',l,string.sub(m,0,100))
                        end
                        body = string.gsub(body, gsub_fv,'',1)
                end
	else
		for name,file,dtype,data in string.gfind(body, form_fv) do
			tab[ name ] = {file_name = file, data_type = dtype, data = data}
		end
	end
	
	return tab
end

function parse_http_body_data(head, body)
	--local t1 = 'Content-Type: multipart/form-data; boundary=%s\r\n'
	--local t2 = 'Content-Type: application/x-www-form-urlencoded\r\n'
	--local t3 = 'Content-Type: application/json; charset=utf-8\r\n'
	if not body or not head then return nil end

	local low_head = string.lower(head)
	local data_type = string.match(low_head, "content%-type:%s?([^;\r]+)")
	if not data_type then
		only.log('W', "can't find ontent-Type from |->" .. head)
		data_type = "application/x-www-form-urlencoded"
	end
	local type_list = {
		["multipart/form-data"] = function(head, body)
			return parse_form_data(head, body)
		end,
		["application/json"] = function(head, body)
			local ok,jo = pcall(cjson.decode, body)
			if not ok then
				only.log('E', "error json body <--> " .. body)
				return nil
			end
			return jo
		end,
		["application/x-www-form-urlencoded"] = function(head, body)
			return parse_url(body)
		end,
	}
	local entry_fcb = type_list[ data_type ]
	if not entry_fcb then
		only.log('E', "can't find Content-Type from |->" .. head)
		return nil
	end
	return entry_fcb(head, body)
end

function split_http_data(msg)
	local str = string.match(msg,"(%a+) /")
	if not str then
		return nil
	end

	local method = string.upper(str)
	local head = nil
	local body = nil
	if method == "GET" then
		head = msg
	elseif method == "POST" then
		local head_end = string.find(msg,"\r\n\r\n")
		if head_end then
			head = string.sub(msg,1,head_end)
			body = string.sub(msg,head_end + 4 , #msg)
		end
	end

	local uri = string.match(msg," /(%w.+) HTTP")
	local find_path = string.find(uri,"%?")
	local path = ""
	local uri_arg = nil
	if uri then
		if find_path then
			path = string.sub(uri,1, find_path - 1 )
			uri_arg = string.sub(uri,find_path + 1 , #uri)
		else
			path = uri
			uri_arg = nil
		end
	end
	only.log('D',string.format("method:%s \r\npath:%s \r\nuri_arg:%s \r\nhead:[%s] \r\nbody:[%s]" , method, path , uri_arg, head , body ))
	return method , head , body , path , uri_arg
end


function format_http_form_data(body_tab, boundary)
	local http_body = ''

	for k, v in pairs(body_tab) do
		http_body = http_body .. string.format('--%s\r\nContent-Disposition:form-data;name="%s"\r\n\r\n%s\r\n', boundary, k, v)
	end
	http_body = string.format('%s--%s--', http_body, boundary)
	return http_body
end

function compose_http_form_request(serv, path, header, args, name, file)
	local boundary = string.format("----WebKitFormBoundaryDcO1SS%dMTDfpuu%skkU", socket.gettime() * 10000000, os.time())
	local http_format = 'POST /%s HTTP/1.0\r\n' ..
	'Host: %s%s\r\n' ..
	'%s' .. 
	'Content-Type: multipart/form-data; boundary=%s\r\n' .. 
	'Content-Length: %d\r\n\r\n%s'
	-->set headers
	local str_headers
	local tab_headers = {}
	if type(header) == "table" then
		if header["Content-Type"] then
			header["Content-Type"] = nil
		end
		for k,v in pairs(header) do
			table.insert(tab_headers, k .. ": " .. v .. "\r\n")
		end
		if #tab_headers > 0 then
			str_headers = table.concat(tab_headers)
		end
	end
	-->set body
	local prefix = '--%s\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n'
	local binary = '--%s\r\nContent-Disposition: form-data; name="%s"; filename="%s"\r\nContent-Type: %s\r\n\r\n%s\r\n'

	local store = {}
	for key, val in pairs(args) do
		table.insert(store, string.format(prefix, boundary, key, val))
	end
	if name then
		table.insert(store, string.format(binary, boundary, name, file["file_name"], file["data_type"], file["data"]))
	end
	table.insert(store, "--" .. boundary .. '--')
	local body = table.concat(store, "")

	return string.format(http_format, path, serv["host"], serv["port"] and (":" .. serv["port"]) or "", str_headers or "", boundary, #body, body)
end

function compose_http_kvps_request(serv, path, header, args, method)
	-->set headers
	local str_headers
	local def_headers = 'Content-Type: application/x-www-form-urlencoded\r\n'
	local tab_headers = {}
	if type(header) == "table" then
		if not header["Content-Type"] then
			header["Content-Type"] = "application/x-www-form-urlencoded"
		end
		for k,v in pairs(header) do
			table.insert(tab_headers, k .. ": " .. v .. "\r\n")
		end
		if #tab_headers > 0 then
			str_headers = table.concat(tab_headers)
		end
	end

	-->set request
	if method == "GET" then
		local http_format = 'GET /%s?%s HTTP/1.0\r\n' ..
		'Host: %s%s\r\n' ..
		'%s\r\n'

		local uri = gen_url(args)

		return string.format(http_format, path, uri, serv["host"], serv["port"] and (":" .. serv["port"]) or "", str_headers or def_headers)
	else
		local http_format = 'POST /%s HTTP/1.0\r\n' ..
		'Host: %s%s\r\n' ..
		'%s' .. 
		'Content-Length: %d\r\n\r\n%s'

		local body = gen_url(args)

		return string.format(http_format, path, serv["host"], serv["port"] and (":" .. serv["port"]) or "", str_headers or def_headers, #body, body)
	end
end

function compose_http_json_request(serv, path, header, args)
	-->set headers
	local str_headers
	local def_headers = 'Content-Type: application/json; charset=utf-8\r\n'
	local tab_headers = {}
	if type(header) == "table" then
		if not header["Content-Type"] then
			header["Content-Type"] = "application/json; charset=utf-8"
		end
		for k,v in pairs(header) do
			table.insert(tab_headers, k .. ": " .. v .. "\r\n")
		end
		if #tab_headers > 0 then
			str_headers = table.concat(tab_headers)
		end
	end

	-->set request
	local http_format = 'POST /%s HTTP/1.0\r\n' ..
	'Host: %s%s\r\n' ..
	'%s' .. 
	'Content-Length: %d\r\n\r\n%s'

	if type(args) == "table" then
		local ok, info = pcall(cjson.encode, args)
		if not ok then
			only.log('E', info)
			return nil
		end

		return string.format(http_format, path, serv["host"], serv["port"] and (":" .. serv["port"]) or "", str_headers or def_headers, #info, info)
	else
		return string.format(http_format, path, serv["host"], serv["port"] and (":" .. serv["port"]) or "", str_headers or def_headers, #args, args)
	end
end

function compose_http_json_request2(serv, path, header, args)
	-->set headers
	local str_headers
	local def_headers = 'Content-Type: application/json; charset=utf-8\r\n'
	local tab_headers = {}
	if type(header) == "table" then
		if not header["Content-Type"] then
			header["Content-Type"] = "application/json; charset=utf-8"
		end
		for k,v in pairs(header) do
			table.insert(tab_headers, k .. ": " .. v .. "\r\n")
		end
		if #tab_headers > 0 then
			str_headers = table.concat(tab_headers)
		end
	end

	-->set request
	local http_format = 'POST /%s HTTP/1.1\r\n' ..
	'Host: %s%s\r\n' ..
	'%s' .. 
	'Content-Length: %d\r\n\r\n%s'

	if type(args) == "table" then
		local ok, info = pcall(cjson.encode, args)
		if not ok then
			only.log('E', info)
			return nil
		end

		return string.format(http_format, path, serv["host"], serv["port"] and (":" .. serv["port"]) or "", str_headers or def_headers, #info, info)
	else
		return string.format(http_format, path, serv["host"], serv["port"] and (":" .. serv["port"]) or "", str_headers or def_headers, #args, args)
	end
end

---===============================================================================


----GMTTime转换时间戳
----2014-04-03 jiang z.s.
function gmttime_to_timestamp(GMTtime)
	if GMTtime == nil  then return 0 end
	if #GMTtime ~= 12  then return 0 end
	if tonumber(GMTtime) == nil then return 0 end
	local time_stamp = os.time({day=tonumber(string.sub(GMTtime, 1, 2)), month=tonumber(string.sub(GMTtime, 3, 4)), year=2000 + tonumber(string.sub(GMTtime, 5, 6)), hour=tonumber(string.sub(GMTtime, 7, 8)), min=tonumber(string.sub(GMTtime, 9, 10)), sec=tonumber(string.sub(GMTtime, 11, 12))})
	return time_stamp + 8*60*60
end

---- table to key-value
function table_to_kv(tab)
	if not tab then return '' end
	local str_tab = {} 
	for i,v in pairs(tab) do
		table.insert(str_tab,string.format("%s=%s",i,v))
	end
	return table.concat(str_tab, "&")
end

---- 判断是否为多媒体文件
function check_is_voice(binary, length)

end

---- 0X23 0X21 0X41 0X4D 0X52 0X0A
---- 所有AMR文件头标志是6个字节。
---- http://blog.csdn.net/dinggo/article/details/1966444
function check_is_amr(binary, length)
	if not binary then return false end
	if not length  or tonumber(length) < 15 then return false end
	local file_title = { [1] = "#!AMR\n", [2] = "#!AMR-WB\n",[3] = "#AMR_MC1.0\n", [4] = "#AMR-WB_MC1.0\n" }
	local is_amr = false
	for i, v in pairs(file_title) do
		if string.sub(binary,1,#v) == v then
			is_amr = true
			break
		end
	end
	return is_amr
end

function check_is_wav(binary , length )
	if not binary then return false end
	if not length  or tonumber(length) < 15 then return false end

	local file_title = { [1] = "RIFF"}
	local is_wav = false
	for i, v in pairs(file_title) do
		if string.sub(binary,1,#v) == v then
			is_wav = true
			break
		end
	end
	return is_wav
end

function check_is_mp3( binary , length )
	if not binary then return false end
	if not length  or tonumber(length) < 1 then return false end
end




---- 发送个人微博接口
---- req 拼接好的字符串
---- return  1: true ok
----          2: bizid 
function really_send_multi_personal_weibo(host_name, host_port , req)
	local supex   = require('supex')
	local ok,ret = supex.http(host_name, host_port , req, #req)
	if not ok then
		only.log('D',req)
		only.log('E',"HTTP send failed!")
		return false ,nil
	end
	if ret then
		local ret_str = string.match(ret,'{.+}')
		if ret_str then
			local ok_status,ok_tab = pcall(cjson.decode , ret_str )
			if ok_status and ok_tab then
				if ok_tab['ERRORCODE'] == "0" then
					return true , ok_tab['RESULT']['bizid']
				end
			end
		end
	end
	----添加错误详细日志信息
	only.log('D',req)
	only.log('D',"===============multi post succed,but return failed!==========")
	only.log('D',ret)
	return false ,nil
end

---- return value
---- 1: true / false  
---- 2: if true ,the value is file url

function txt_2_voice(dfsServer_v, appKey_v, secret_v,text_v, speed_v , announcer_v , volume_v )
	local supex   = require('supex')

	if not text_v then return false,nil end
	if #text_v < 1 then return false,nil end


	only.log('D',string.format("utils: appkey:%s  secret:%s  text: %s ", appKey_v , secret_v , text_v ))

	local  tab = {
		appKey = appKey_v,
		text   = text_v,
	}

	if speed_v then
		tab['speechRate'] = speed_v
	end

	if announcer_v then
		tab['speechAnnouncer'] = announcer_v
	end

	if volume_v and (tonumber(volume_v) or 0 ) ~= 0  then
		tab['speechVolume'] = tonumber(volume_v)
	end

	tab['sign'] = gen_sign(tab, secret_v)
	tab['text'] = url_encode(text_v)
	local body = table_to_kv(tab)
	local post_data = 'POST /spx_txt_to_voice HTTP/1.0\r\n' ..
	'Host:%s:%s\r\n' ..
	'Content-Length:%d\r\n' ..
	'Content-Type:application/x-www-form-urlencoded\r\n\r\n%s'
	--'Content-Type:text/plain\r\n\r\n%s'

	local req = string.format(post_data,dfsServer_v.host, tostring(dfsServer_v.port) , #body , body )
	local ok,ret = supex.http(dfsServer_v.host, dfsServer_v.port, req, #req)
	if not ok or ret == nil then
		only.log('E',"txt to voice post txt data failed!")
		return false,nil,nil
	end

	if ret then
		local ret_str = string.match(ret,'{.+}')
		if ret_str then
			local ok_status,ok_tab = pcall(cjson.decode , ret_str )
			if ok_status and ok_tab then
				if tostring(ok_tab['ERRORCODE']) == "0" then
					return true , ok_tab['RESULT']['url'],ok_tab['RESULT']['fileID']
				end
			end
		end
	end
	----添加错误详细日志信息
	only.log('E',req)
	only.log('E',"===============txt_2_voice post succed,but return  failed!==========")
	only.log('E',ret)
	return false ,nil,nil
end





---- 发送个人多媒体微博 
function send_multi_personal_weibo(personalWeibo, wb )
	local split_str = string.format("----WebKitFormBouDcO1SS%dMTDfpuu%skkU", socket.gettime() * 10000000, os.time())
	local data_multi_personal_head = 'POST /weiboapi/v2/sendMultimediaPersonalWeibo HTTP/1.0\r\nHost:%s:%d\r\nContent-Length:%d\r\nContent-Type:content-type:multipart/form-data;boundary=' .. split_str .. '\r\n\r\n%s'
	local data_format_normal       = '--%s\r\nContent-Disposition:form-data;name="%s"\r\n\r\n%s\r\n'
	local data_tab = {}
	for i,v in pairs(wb) do
		table.insert(data_tab,string.format(data_format_normal,split_str,i,v))
	end
	local data = string.format("%s--%s--",table.concat( data_tab, "") , split_str )
	local req = string.format(data_multi_personal_head,personalWeibo.host,personalWeibo.port,#data,data)
	return really_send_multi_personal_weibo(personalWeibo.host,personalWeibo.port,req)
end


---- table 包含检查
function is_in_table(value,table)
	local match = false
	if type(table) == "table" then
		for k,v in pairs(table) do
			if v == value then
				match = true
				break
			end
		end
	end
	return match
end

--功  能：封装mfpt body头和body数据
--参  数：data 为table
--返回值：封装后的数据
function compose_mfptp_json_request(data)
	local body_lenth = 0
	local bodyData
	local more = data[1]
	local oldlen = 0
	-->> 封装body头
        local headString,dst= mfptp_pack.data_head(1,2,1)
	if not more or more < 1 then
		return nil
	end
	-->>封装body数据
	for i=2 ,#data do
		more = more -1
		-->> 封装body前几贞数据
		if more > 0 then
			oldlen ,bodyData= mfptp_pack.data_body(data[i], #data[i], more, body_lenth,dst)
			body_lenth = oldlen +body_lenth
			only.log("D","bodyData" .. bodyData)
		end
	
		-->>封装最后一贞数据数据
		if more == 0 then
			body_lenth = body_lenth+#data[i]+i
			bodyData = mfptp_pack.data_body(data[i], #data[i], more, body_lenth,dst)
			only.log("D","bodyData" .. bodyData)
			return true,bodyData
		end
	end
end
