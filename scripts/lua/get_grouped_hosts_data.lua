--
-- (C) 2013-14 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

-- Table parameters
all = _GET["all"]
currentPage = _GET["currentPage"]
perPage     = _GET["perPage"]
sortColumn  = _GET["sortColumn"]
sortOrder   = _GET["sortOrder"]

group_col   = _GET["grouped_by"]
as_n        = _GET["as"]
vlan_n      = _GET["vlan"]
network_n   = _GET["network"]

if (group_col == nil) then
   group_col = "asn"
end

-- Get from redis the throughput type bps or pps
throughput_type = getThroughputType()

if ((sortColumn == nil) or (sortColumn == "column_"))then
  sortColumn = getDefaultTableSort(group_col)
else
  if ((aggregated == nil) and (sortColumn ~= "column_")
    and (sortColumn ~= "")) then
      tablePreferences("sort_"..group_col,sortColumn)
  end
end

if(sortOrder == nil) then
  sortOrder = getDefaultTableSortOrder(group_col)
else
  if ((aggregated == nil) and (sortColumn ~= "column_")
    and (sortColumn ~= "")) then
    tablePreferences("sort_order_"..group_col,sortOrder)
  end
end

if(currentPage == nil) then
   currentPage = 1
else
   currentPage = tonumber(currentPage)
end

if(perPage == nil) then
   perPage = getDefaultTableSize()
else
  perPage = tonumber(perPage)
  tablePreferences("rows_number",perPage)
end

interface.find(ifname)
hosts_stats = interface.getHostsInfo()

to_skip = (currentPage-1) * perPage

if (all ~= nil) then
  perPage = 0
  currentPage = 0
end

if (as_n == nil and vlan_n == nil and network_n == nil) then -- single group info requested
   print ("{ \"currentPage\" : " .. currentPage .. ",\n \"data\" : [\n")
end
num = 0
total = 0

now = os.time()
vals = {}

-- f = io.open("log.txt", "w")

stats_by_group_col = {}
for key,value in pairs(hosts_stats) do
   -- f:write("****************\n");
   -- Convert grouping identifier to string to avoid type mismatches if the
   -- value is 0 (which would mean that the AS is private)
   -- f:write(tostring(value["local_network_id"]).."\n")
   value[group_col] = tostring(value[group_col])

   id = value[group_col]
   existing = stats_by_group_col[id]
   if (existing == nil) then
      stats_by_group_col[id] = {}
      stats_by_group_col[id]["id"] = id
      if (group_col == "asn") then
         if (id ~= "0") then
            stats_by_group_col[id]["name"] = value["asname"]
         else
            stats_by_group_col[id]["name"] = "Private ASN"
         end
      elseif (group_col == "local_network_id") then
         stats_by_group_col[id]["name"] = value["local_network_name"]
         if (stats_by_group_col[id]["name"] == nil) then
            stats_by_group_col[id]["name"] = "Unknown network"
         end
         -- f:write(stats_by_group_col[id]["name"].."\n")
      else
         stats_by_group_col[id]["name"] = "VLAN"
      end
      stats_by_group_col[id]["seen.first"] = value["seen.first"]
      stats_by_group_col[id]["seen.last"] = value["seen.last"]
   else
      stats_by_group_col[id]["seen.first"] =
         math.min(stats_by_group_col[id]["seen.first"], value["seen.first"])
      stats_by_group_col[id]["seen.last"] =
         math.max(stats_by_group_col[id]["seen.last"], value["seen.last"])
   end
   stats_by_group_col[id]["num_hosts"] = 1 +
         ternary(existing, stats_by_group_col[id]["num_hosts"], 0)
   stats_by_group_col[id]["num_alerts"] = value["num_alerts"] +
         ternary(existing, stats_by_group_col[id]["num_alerts"], 0)
   stats_by_group_col[id]["throughput_bps"] = value["throughput_bps"] +
         ternary(existing, stats_by_group_col[id]["throughput_bps"], 0)
   stats_by_group_col[id]["throughput_pps"] = value["throughput_pps"] +
         ternary(existing, stats_by_group_col[id]["throughput_pps"], 0)
   stats_by_group_col[id]["throughput_trend_bps_diff"] =
         math.floor(value["throughput_trend_bps_diff"]) +
         ternary(existing,
                 stats_by_group_col[id]["throughput_trend_bps_diff"], 0)
   stats_by_group_col[id]["bytes.sent"] = value["bytes.sent"] +
         ternary(existing, stats_by_group_col[id]["bytes.sent"], 0)
   stats_by_group_col[id]["bytes.rcvd"] = value["bytes.rcvd"] +
         ternary(existing, stats_by_group_col[id]["bytes.rcvd"], 0)
   stats_by_group_col[id]["country"] = value["country"]
   -- f:write("****************\n");
end
-- f:close()

function print_single_group(value)
   print ('{ ')
   print ('\"key\" : \"'..value["id"]..'\",')

   print ("\"column_id\" : \"<A HREF='"..ntop.getHttpPrefix().."/lua/")
   if (group_col == "asn" or as_n ~= nil) then
      print("hosts_stats.lua?asn=" ..value["id"] .. "'>")
   elseif (group_col == "vlan" or vlan_n ~= nil) then
      print("hosts_stats.lua?vlan="..value["id"].."'>")
   elseif (group_col == "local_network_id" or network_n ~= nil) then
      print("hosts_stats.lua?network="..value["id"].."'>")
   else
      print("hosts_stats.lua'>")
   end
   if (group_col == "local_network_id" or network_n ~= nil) then
      print(value["name"]..'</A>", ')
   else
      print(value["id"]..'</A>", ')
   end

   print('"column_hosts" : "' .. formatValue(value["num_hosts"]) ..'",')

   print ("\"column_alerts\" : \"")
   if((value["num_alerts"] ~= nil) and (value["num_alerts"] > 0)) then
      print("<font color=#B94A48>"..formatValue(value["num_alerts"]).."</font>")
   else
      print("0")
   end
   print('", ')

   --- TODO: name for VLANs?
   if (group_col == "asn" or as_n ~= nil) then
      print("\"column_name\" : \""..printASN(tonumber(value["id"]), value["name"]))
   else
      print("\"column_name\" : \""..value["name"])
   end
   if((value["country"] ~= nil) and (value["country"] ~= "")) then
      print("&nbsp;<img src='/img/blank.gif' class='flag flag-".. string.lower(value["country"]) .."'>")
   end
   print('", ')

   print("\"column_since\" : \"" .. secondsToTime(now-value["seen.first"]+1) .. "\", ")

   sent2rcvd = round((value["bytes.sent"] * 100) / (value["bytes.sent"]+value["bytes.rcvd"]), 0)
   print ("\"column_breakdown\" : \"<div class='progress'><div class='progress-bar progress-bar-warning' style='width: "
          .. sent2rcvd .."%;'>Sent</div><div class='progress-bar progress-bar-info' style='width: "
          .. (100-sent2rcvd) .. "%;'>Rcvd</div></div>")
   print('", ')

   if (throughput_type == "pps") then
      print ("\"column_thpt\" : \"" .. pktsToSize(value["throughput_bps"]).. " ")
   else
      print ("\"column_thpt\" : \"" .. bitsToSize(8*value["throughput_bps"]).. " ")
   end
   if(value["throughput_trend_bps_diff"] > 0) then
      print("<i class='fa fa-arrow-up'></i>")
   elseif(value["throughput_trend_bps_diff"] < 0) then
      print("<i class='fa fa-arrow-down'></i>")
   else
      print("<i class='fa fa-minus'></i>")
   end
   print('", ')

   print("\"column_traffic\" : \"" .. bytesToSize(value["bytes.sent"]+value["bytes.rcvd"]))

   print("\" } ")
end

if (as_n ~= nil) then
   as_val = stats_by_group_col[as_n]
   if (as_val == nil) then
      print('{}')
   else
      print_single_group(as_val)
   end
   stats_by_group_col = {}
elseif (vlan_n ~= nil) then
   vlan_val = stats_by_group_col[vlan_n]
   if (vlan_val == nil) then
      print('{}')
   else
      print_single_group(vlan_val)
   end
   stats_by_group_col = {}
elseif (network_n ~= nil) then
   network_val = stats_by_group_col[network_n]
   if (network_val == nil) then
      print('{}')
   else
      print_single_group(network_val)
   end
   stats_by_group_col = {}
end

for key,value in pairs(stats_by_group_col) do
   if(sortColumn == "column_id") then
      vals[key] = key
   elseif(sortColumn == "column_name") then
      vals[stats_by_group_col[key]["name"]] = key
   elseif(sortColumn == "column_since") then
      vals[(now-stats_by_group_col[key]["seen.first"])] = key
   elseif(sortColumn == "column_alerts") then
      vals[(now-stats_by_group_col[key]["num_alerts"])] = key
   elseif(sortColumn == "column_last") then
      vals[(now-stats_by_group_col[key]["seen.last"]+1)] = key
   elseif(sortColumn == "column_thpt") then
      vals[stats_by_group_col[key]["throughput_"..throughput_type]] = key
   elseif(sortColumn == "column_queries") then
      vals[stats_by_group_col[key]["queries.rcvd"]] = key
   else
      vals[(stats_by_group_col[key]["bytes.sent"] +
            stats_by_group_col[key]["bytes.rcvd"])] = key
   end
end

table.sort(vals)

if(sortOrder == "asc") then
   funct = asc
else
   funct = rev
end

num = 0
for _key, _value in pairsByKeys(vals, funct) do
   key = vals[_key]

   if((key ~= nil) and (not(key == ""))) then
      value = stats_by_group_col[key]

      if(to_skip > 0) then
         to_skip = to_skip-1
      else
         if((num < perPage) or (all ~= nil))then
            if(num > 0) then
               print ",\n"
            end
            print_single_group(value)
            num = num + 1
         end
      end
      total = total + 1
   end
end -- for

if (as_n == nil and vlan_n == nil and network_n == nil) then -- single group info requested
   print ("\n], \"perPage\" : " .. perPage .. ",\n")
end

if(sortColumn == nil) then
   sortColumn = ""
end

if(sortOrder == nil) then
   sortOrder = ""
end

if (as_n == nil and vlan_n == nil and network_n == nil) then -- single group info requested
   print ("\"sort\" : [ [ \"" .. sortColumn .. "\", \"" .. sortOrder .."\" ] ],\n")
   print ("\"totalRows\" : " .. total .. " \n}")
end
