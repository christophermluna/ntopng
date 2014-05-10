--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"


sendHTTPHeader('text/html')
local debug = debug_flow_data

flow_key = _GET["flow_key"]
if(flow_key == nil) then
   flow = nil
else
   interface.find(ifname)
   flow = interface.findFlowByKey(tonumber(flow_key))
end

if(flow == nil) then
   print('{}')
else
  print ("{ \"duration\" : \"" .. secondsToTime(flow["duration"]))
  print ("\", \"bytes\" : \"" .. bytesToSize(flow["bytes"]) .. "")

  if(flow["throughput_trend"] > 0) then 
      print ("\", \"thpt\" : \"" .. bitsToSize(8*flow["throughput"]).. " ")

      if(flow["throughput_trend"] == 1) then 
         print("<i class='fa fa-arrow-up'></i>")
         elseif(flow["throughput_trend"] == 2) then
         print("<i class='fa fa-arrow-down'></i>")
         elseif(flow["throughput_trend"] == 3) then
         print("<i class='fa fa-minus'></i>")
      end
      print("\"")
   else
      print ("\", \"thpt\" : \"NaN\"")
   end

   cli2srv = round((flow["cli2srv.bytes"] * 100) / flow["bytes"], 0)
   print (", \"breakdown\" : \"<div class='progress'><div class='bar bar-warning' style='width: " .. cli2srv .."%;'>Client</div><div class='bar bar-info' style='width: " .. (100-cli2srv) .. "%;'>Server</div></div>")

   print ("\" }")

end