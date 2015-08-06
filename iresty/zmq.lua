local byte = string.byte
local tcp = ngx.socket.tcp
local char = string.char

local ok, new_tab = pcall(require, "table.new")
if not ok then
	new_tab = function ( narr, nrec ) return {}	end
end

local _M = new_tab(0, 155)
_M._VERSION = '1.0'
_M._FLAG    = nil

local mt = { __index = _M }

function _M.new( self )
	local sock, err = tcp()
	if not sock then
		return nil, err
	end
	return setmetatable( {sock = sock}, mt)
end

function _M.connect( self, timeout, ... )  -- bug: if connect to zmq server with zmq1.0 may be wrong
	-- body
	local sock = self.sock
	if not sock then
		return nil, "not initialized"
	end

	local ok, err = sock:connect( ... )
	
	if not ok then
		return nil, err
	else
		sock:settimeout(timeout)

		local line, err = sock:receive(10)  -- 10 bytes return after connected
	
		if err then
			return nil, err
		end

		if 255 ~= byte(line, 1) or 127 ~= byte(line, 10) then
			return nil, "protocol not supported"
		end

		local req = line .. char(1) .. char(3)	-- revision(x01) .. socket-type(REQ=x03)
		
		local cnt, err = sock:send(req)
		
		if err then 
			return nil, err
		end

		_, err = sock:receive(4)

		if err then
			return nil, err
		end

		local identify = char(0) .. char(0)
		cnt, err = sock:send(identify)
	end

	return true, nil
end

function _M.set_timeout( self, timeout )
	local sock = self.sock
	if not sock then
		return nil, "not initialized"
	end

	return sock:settimeout(timeout)
end

function _M.set_keepalive(self, ...)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:setkeepalive(...)
end

function _M.send( self, msg, sndmore )
	-- body
	local _FLAG = self._FLAG

	if _FLAG then 
		return nil, 'recv after send under request-reply model'
	end

	local message  = ''
	local msg_size = #msg
	local header 
	local size

	if sndmore ~= 1 and sndmore ~= 0 then
		return nil, 'sndmore flag error'
	end

	if msg_size < 256 then
		header = table.concat({char(1), char(0), char(0 + sndmore)}, "")
		size   = char(msg_size)
	else
		header = table.concat( {char(1), char(0), char(2 + sndmore)}, "" )
		
		local len = {}
		local base= 256
		for index = 8, 1, -1 do  -- zmq 消息协议用8个byte来表示长度 应该能链接一个非常非常大的数据了
			if msg_size/base > 1 then
				table.insert(len, 1, char(msg_size%base))
			elseif msg_size/base > 0 then
				table.insert(len, 1, char(msg_size))
				msg_size = 0
			else
				table.insert(len, 1, char(0))
			end
			msg_size, _ = math.modf(msg_size/base)
		end
		
		size = table.concat( len, "" )
	end

	local message = header .. size .. msg

	if sndmore == 0 then
		self._FLAG = 'SEND'
	end

	return self.sock:send(message)
end


function _M.recv( self )
	local sock = self.sock
	local header, err = sock:receive(3) -- 得到协议头 从这里判断是短消息还是长消息
	
	self._FLAG = nil

	if err then
		return nil, 'read 0mq header failed'
	end

	if 0 == byte(header, 3) then -- short msg
		
		local len_octets, err = sock:receive(1)
		if err then
			return nil, 'read 0mq msg length error'
		end

		return sock:receive(byte(len_octets))

    elseif 2 == byte(header, 3) then -- long msg
    	
    	local len_octets,err = sock:receive(8) -- long msg use 8 octets to specify msg length
    	if err then
    		return nil, ''
    	end
    	-- translate string to lenth
    	local size = 0
    	for index = 1, 8, 1 do
    		size = size*256 + byte(len_octets, index)
    	end
    	
    	return sock:receive(size)

    else 
    	return nil, 'protocol error'	
	end

end

return _M





