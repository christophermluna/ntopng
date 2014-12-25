--
-- (C) 2013-14 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "top_talkers"

sendHTTPHeader('text/html; charset=iso-8859-1')

ifid = getInterfaceId(ifname)
epoch = _GET["epoch"]
module = _GET["m"]
param = _GET["param"]


if (module == nil) then
  print("[ ]\n")
else
  if (param == nil) then param = "" end
  mod = require("top_scripts."..module)
  if (type(mod) == type(true)) then
    print("[ ]\n")
  else
    if (epoch ~= nil) then
      top = mod.getHistoricalTop(ifid, ifname, epoch)
    else
      top = mod.getTopClean(ifid, ifname, param)
    end
    print(top)
  end
end
