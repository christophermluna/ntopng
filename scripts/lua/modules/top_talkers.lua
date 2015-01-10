--
-- (C) 2013-14 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "persistence"

-- #################################################

function getTop(stats, sort_field_key, max_num_entries, lastdump_dir)
   local _filtered_stats, filtered_stats, counter, total,
         threshold, low_threshold

   -- stats is a hash of hashes organized as follows:
   -- { "id1" : { "key1": "value1", "key2": "value2", ...}, "id2 : { ... } }
   -- filter out the needed values
   _filtered_stats = {}
   for id,content in pairs(stats) do
      _filtered_stats[id] = content[sort_field_key]
   end

   -- Read the lastdump; the name of the lastdump file has the following
   -- format: <lastdump_dir>/.<sort_field_key>_lastdump
   lastdump = lastdump_dir .. "/."..sort_field_key.."_lastdump"
   last = nil
   if(ntop.exists(lastdump)) then
      last = persistence.load(lastdump)
   end
   if(last == nil) then last = {} end

   persistence.store(lastdump, _filtered_stats);

   for key, value in pairs(_filtered_stats) do
      if(last[key] ~= nil) then
         v = _filtered_stats[key]-last[key]
         if(v < 0) then v = 0 end
         _filtered_stats[key] = v
      end
   end

   -- order the filtered stats by using the value (bytes sent/received during
   -- the last time interval) as key
   filtered_stats = {}
   for key, value in pairs(_filtered_stats) do
      filtered_stats[value] = key
   end

   -- Compute traffic
   total = 0
   for _value,_ in pairsByKeys(filtered_stats, rev) do
      total = total + _value
   end

   threshold = total / 10 -- 10 %
   low_threshold = total * 0.05  -- 5%

   -- build a new hashtable sorted by the required field
   top_stats = {}
   counter = 0
   for _value,_id in pairsByKeys(filtered_stats, rev) do
      if ((_value == 0) or (_value < low_threshold) or
          ((_value < threshold) and (counter > max_num_entries / 2))) then
         break
      end
      top_stats[_value] = _id -- still keep it in order
      counter = counter + 1
      if (counter == max_num_entries) then
        break
      end
   end

   return top_stats
end

function filterBy(stats, col, val)
  local filtered_by = {}

  if (col == "" or col == nil or val == nil) then
    return stats
  end

  for id,content in pairs(stats) do
    if (content[col] == val) then
      filtered_by[id] = content
    end
  end

  return filtered_by
end

-- #####################################################

function getActualTopTalkers(ifid, ifname, filter_col, filter_val, concat, mode)
   max_num_entries = 10
   rsp = ""

   interface.find(ifname)
   hosts_stats = interface.getHostsInfo()
   hosts_stats = filterBy(hosts_stats, filter_col, filter_val)

   talkers_dir = fixPath(dirs.workingdir .. "/" .. ifid .. "/top_talkers")
   if(not(ntop.exists(talkers_dir))) then
      ntop.mkdir(talkers_dir)
   end

   if(concat == false and mode == nil) then
      rsp = rsp.."{\n"
   end
   rsp = rsp..'\t"hosts": [\n'

   if(mode == nil) then
      rsp = rsp .. "{\n"
      rsp = rsp .. '\t"senders": ['
   end

   --print("Hello\n")
   if((mode == nil) or (mode == "senders")) then
      top_senders = getTop(hosts_stats, "bytes.sent", max_num_entries, talkers_dir)
      num = 0
      for value,id in pairsByKeys(top_senders, rev) do
	 if(num > 0) then rsp = rsp .. " }," end
	 rsp = rsp .. '\n\t\t { "label": "'..id.. '", "url": "'
               ..ntop.getHttpPrefix()..
               '/lua/host_details.lua?host='..id..'", "value": '..value
	 num = num + 1
      end
   end

   if(mode == nil) then
      if(num > 0) then rsp = rsp .. " }" end
      rsp = rsp .. "\n\t],\n"
      rsp = rsp .. '\t"receivers": ['
   end

   if((mode == nil) or (mode == "receivers")) then
      top_receivers = getTop(hosts_stats, "bytes.rcvd", max_num_entries, talkers_dir)
      num = 0
      for value,id in pairsByKeys(top_receivers, rev) do
	 if(num > 0) then rsp = rsp .. " }," end
	 rsp = rsp .. '\n\t\t { "label": "'..id.. '", "url": "'
               ..ntop.getHttpPrefix()..
               '/lua/host_details.lua?host='..id..'", "value": '..value
	 num = num + 1
      end
   end

   if(mode == nil) then
      if(num > 0) then rsp = rsp .. " }" end
      rsp = rsp .. "\n\t]\n"
      rsp = rsp .. "\n}\n"
   else
      if(num > 0) then rsp = rsp .. " }\n" end
   end

   rsp = rsp.."]"
   if(concat == false and mode == nil) then
      rsp = rsp.."\n}"
   end

   --print(rsp.."\n")
   return(rsp)
end

-- #####################################################

function groupStatsByColumn(ifid, ifname, col)
   local _group = {}
   local total = 0
   -- Group hosts info by the required column
   for _key, value in pairs(hosts_stats) do
      key = hosts_stats[_key][col]

      if (_group[key] == nil) then
         _group[key] = {}
         old = 0
      else
         assert(_group[key][col.."_bytes"] ~= nil)
         old = _group[key][col.."_bytes"]
      end

      if (col == "asn") then
         if(key == 0) then
            _group[key]["name"] = "[Local/Unknown]"
         else
            _group[key]["name"] = key .." ["..abbreviateString(hosts_stats[_key]["asname"], 10).."]"
         end
      elseif (col == "vlan") then
         if (key == 0) then
           _group[key]["name"] = "No VLAN"
         else
           _group[key]["name"] = "VLAN"..hosts_stats[_key]["vlan"]
         end
      end
      val = hosts_stats[_key]["bytes.sent"] + hosts_stats[_key]["bytes.rcvd"]
      total = total + val
      _group[key][col.."_bytes"] = old + val
   end
  return _group, total
end

function getActualTopGroups(ifid, ifname, max_num_entries, use_threshold,
                            use_delta, filter_col, filter_val, col, concat)
   rsp = ""

   --if(ifname == nil) then ifname = "any" end

   interface.find(ifname)
   hosts_stats = interface.getHostsInfo()
   hosts_stats = filterBy(hosts_stats, filter_col, filter_val)

   talkers_dir = fixPath(dirs.workingdir .. "/" .. ifid .. "/top_talkers")
   if(not(ntop.exists(talkers_dir))) then
      ntop.mkdir(talkers_dir)
   end

   _group, total = groupStatsByColumn(ifid, ifname, col)

   if(concat == true) then
      rsp = rsp..'"'..col..'": '
   end

   rsp = rsp .. "[\n"

   -- Get top groups
   top_groups = getTop(_group, col.."_bytes", max_num_entries, talkers_dir)

   num = 0
   for _value,_key in pairsByKeys(top_groups, rev) do
      if(num > 0) then rsp = rsp .. " }," end
      rsp = rsp .. '\n\t\t { "label": "'.._key..'", "url": "'
            ..ntop.getHttpPrefix()..
            '/lua/hosts_stats.lua?'..col..'='.._key..'", "name": "'
            .._group[_key]["name"]..'", "value": '.._value
      num = num + 1
   end

   if (num > 0) then
      rsp = rsp .. " }\n"
   end
   rsp = rsp .. "\n]"

   return(rsp)
end
