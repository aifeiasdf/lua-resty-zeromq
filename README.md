Name  

lua-resty-zeromq 是在[openresty](openresty.com)框架下，用lua完成的和zeromq通信模块，采用纯异步的方式实现，目前只支持 Reponse and Reply 模型

Description

这个模块通过openresty项目中[ngx.socket.tcp](http://wiki.nginx.org/HttpLuaModule#ngx.socket.tcp)模型完成。


Synopsis
 # you do not need the following line if you are using
 # the ngx_openresty bundle:
    lua_package_path "/path/to/lua-resty-redis/lib/?.lua;;";

    server {
        location /test {
            content_by_lua '
                    llocal zmq = require "lua.zmq"

                    local msg_que, err = zmq:new()

						if err then
    						ngx.log(ngx.ERR, 'create zmq object failed')
						end


						local ok, err = msg_que:connect(1000, '172.16.255.143', '5555')

						if not ok then 
    						ngx.log(ngx.ERR, 'create zmq object failed, err = ' .. err)
						end


						local long_msg = [[you can set this string more than 256 bytes !]]

						local ok, err = msg_que:send(long_msg, 1)

						if not ok then 
    						ngx.log(ngx.ERR, 'send more long frame failed, err = ' .. err)
						end

						local final_msg = [[finally]]

						local ok, err = msg_que:send(final_msg, 0)

						if not ok then 
    						ngx.log(ngx.ERR, 'send final short frame failed, err = ' .. err)
						end

						local data, err = msg_que:recv()
						ngx.say(data)
            ';
        }
    }