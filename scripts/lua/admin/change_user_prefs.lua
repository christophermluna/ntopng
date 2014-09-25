--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

username = _GET["username"]
host_role = _GET["host_role"]
allowed_networks = _GET["allowed_networks"]

-- TODO: parser networks

if( username == nil) then   
    print ("{ \"result\" : -1, \"message\" : \"Error in username\" }")
    return
end

if( host_role ~= nil) then
  if(not ntop.changeUserRole(username, host_role)) then
    print ("{ \"result\" : -1, \"message\" : \"Error in changing host type\" }")
    return
  end
end

if( allowed_networks ~= nil) then
  if(not ntop.changeAllowedNets(username, allowed_networks)) then
    print ("{ \"result\" : -1, \"message\" : \"Error in changing allowed networks\" }")
    return 
  end
end

print ("{ \"result\" : 0, \"message\" : \"Parameters Updated\" }")
