/*
 *
 * (C) 2013-14 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#ifndef _STATS_MANAGER_H_
#define _STATS_MANAGER_H_

#include "ntop_includes.h"
#include <map>

class StatsManager {
public:
    StatsManager(int ifid, const char *dbname);
    ~StatsManager();
    int insertMinuteSampling(time_t epoch, char *sampling);
    int insertHourSampling(time_t epoch, char *sampling);
    int insertDaySampling(time_t epoch, char *sampling);
    int getMinuteSampling(time_t epoch, string *sampling);
    int openCache(const char *cache_name);
    int retrieveMinuteStatsInterval(time_t epoch_start, time_t epoch_end,
			            char ***vals, int *num_vals);
    int retrieveHourStatsInterval(time_t epoch_start, time_t epoch_end,
			          char ***vals, int *num_vals);
    int retrieveDayStatsInterval(time_t epoch_start, time_t epoch_end,
			         char ***vals, int *num_vals);
    int deleteMinuteStatsOlderThan(unsigned num_days);
    int deleteHourStatsOlderThan(unsigned num_days);
    int deleteDayStatsOlderThan(unsigned num_days);
private:
    static const int MAX_QUERY = 10000;
    static const int MAX_KEY = 20;
    const char *MINUTE_CACHE_NAME,
	       *HOUR_CACHE_NAME, *DAY_CACHE_NAME; // see constructor for initialization
    int ifid;
    /*
     * map has O(log(n)) access time, but we suppose the number
     * of caches is not huge
     */
    std::map<string, bool> caches;
    Mutex m;
    sqlite3 *db;
    int exec_query(char *db_query,
                   int (*callback)(void *, int, char **, char **),
                   void *payload);
    int insertSampling(char *sampling, const char *cache_name, const int key);
    int getSampling(string *sampling, const char *cache_name, const int key);
    int deleteStatsOlderThan(const char *cache_name, const int key);
    int retrieveStatsInterval(char ***vals, int *num_vals, const char *cache_name,
                              const int key_start, const int key_end);
};

#endif /* _STATS_MANAGER_H_ */
