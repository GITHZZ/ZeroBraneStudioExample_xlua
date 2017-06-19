-- Copyright 2011-15 Paul Kulchenko, ZeroBrane LLC
-- authors: Luxinia Dev (Eike Decker & Christoph Kubisch)
---------------------------------------------------------

local ide = ide
--[[ single instance
open an UDP port - if it fails it is either because
- IDE is running already
- an application is already blocking that port
if it fails it tries to contact the running application
- if it confirms being the IDE we let that instance open it, finish our application
- otherwise we throw an error message on the user and start like normal

probably a pitfal: an instance is running but is not visible
  (because it was finished though the UDP thing still runs)
]]

local socket = require "socket"
local svr = socket.udp()

function ide:Restart(hotexit)
  self:AddPackage("core.restart", {
      onAppShutdown = function() wx.wxExecute(ide:GetLaunchPath(true), wx.wxEXEC_ASYNC) end
    })
  if self.timers.idle then self.timers.idle:Stop() end
  if svr then svr:close() end
  self:Exit(hotexit)
end

if not ide.config.singleinstance then return end

local port = ide.config.singleinstanceport
local delay = tonumber(ide.config.singleinstance) or 1000 -- in ms
local success = svr:setsockname("127.0.0.1",port) -- bind on local host
local protocol = {client = {}, server = {}}

protocol.client.greeting = "Is this you, my IDE? It's me, a new instance."
protocol.server.greeting = "Yes it is me, running as: %s"
protocol.client.requestloading = "Could you please load this file for me: %s"
protocol.server.answerok = "Sure. You may now leave."

if success then -- ok, server was started, we are solo
  svr:settimeout(0) -- don't block
  ide.timers.idle = ide:AddTimer(wx.wxGetApp(), function()
      if ide.exitingProgram then -- if exiting, terminate the timer loop
        wx.wxGetApp():Disconnect(wx.wxEVT_TIMER)
        return
      end

      local msg, ip, port = svr:receivefrom()
      if msg then
        if msg == protocol.client.greeting then
          svr:sendto(protocol.server.greeting:format(wx.wxGetUserName()),ip,port)
        elseif msg:match(protocol.client.requestloading:gsub("%%s",".+$")) then -- ok we need to open something
          svr:sendto(protocol.server.answerok,ip,port)
          local filename = msg:match(protocol.client.requestloading:gsub("%%s","(.+)$"))
          if filename then
            RequestAttention()
            ide:ActivateFile(filename)
          end
        end
      end
    end)
  ide.timers.idle:Start(delay,false)
else -- something different is running on our port
  local cln = socket.udp()
  cln:setpeername("127.0.0.1",port)
  cln:settimeout(2)
  cln:send(protocol.client.greeting)

  local msg = cln:receive()
  local arg = ide.arg
  if msg and msg:match(protocol.server.greeting:gsub("%%s",".+$")) then
    local username = msg:match(protocol.server.greeting:gsub("%%s","(.+)$"))
    if username ~= wx.wxGetUserName() then
      ide:Print(("Another instance is running under user '%s' and can't be activated. This instance will continue running, which may cause interference with the debugger."):format(username))
    else
      local failed = false
      for index = 2, #arg do
        local fileName = arg[index]
        if fileName ~= "--"
        -- on OSX, the command line includes -psn parameter, so ignore it
        and (ide.osname ~= 'Macintosh' or not fileName:find("^-psn")) then
          cln:send(protocol.client.requestloading:format(fileName))

          local msg, err = cln:receive()
          if msg ~= protocol.server.answerok then
            failed = true
            ide:Print(err,msg)
          end
        end
      end
      if failed then
        ide:Print("The server instance failed to open the files, this instance will continue running.")
      else -- done
        os.exit(0)
      end
    end
  else
    ide:Print("The single instance communication has failed; there may be another instance running, which may cause interference with the debugger.")
  end
end
