//+------------------------------------------------------------------+
//|                                                 TimeZoneInfo.mqh |
//|                                        Copyright \C2\A9 2018, Amr Ali |
//|                             https://www.mql5.com/en/users/amrali |
//+------------------------------------------------------------------+
#ifndef TIMEZONEINFO_UNIQUE_HEADER_ID_H
#define TIMEZONEINFO_UNIQUE_HEADER_ID_H
#property version "2.17"

// Updates:
// 2024.03.01 - v.1.40 : Removed redundant code in CTimeZoneInfo class (used during testing), added more methods to CSessionHours class, updated TestIndi.mq5 to reflect the new changes.
// 2024.03.03 - v.1.45 : Updated the example code for "Working with Local Session Hours - CTimeZoneInfo Class".
// 2024.03.08 - v.1.50 : Added two internal methods HistoryBrokerOffset() and FirstBarOfWeek() to CTimeZoneInfo class. Handling of server time in the past (UTC offset, text formatting, conversions, etc..).
// 2024.03.15 - v.1.56 : Added script "SydneySession_Script.mq5" to to show how the session hours in Sydney are fluctuating throughout the year.
// 2024.03.30 - v.1.65 : Fixed broker GMT offset. Currently, the library scans H1 bars only on the GOLD chart as it has the most accurate start times on all brokers that I have tested.
// 2024.04.01 - v.1.67 : Fixed potential issue in the calculation of the broker GMT offset during the first hour of the trading week.
// 2024.04.03 - v.1.70 : Caching of broker GMT offsets into a hash map for faster retrieval (e.g., from indicators). The broker offset cache will contain one entry per trading week.
// 2024.04.08 - v.1.72 : Improved the performance of the library by at least 2-3x times. Now using StructToTime instead of StringToTime inside the GetNthSunday method.
// 2024.04.09 - v.1.75 : Fixed potential issue in the calculation of the broker GMT offset during the Christmas holidays on GMT+0 brokers.
// 2024.04.11 - v.1.77 : Speed-up of the GetDaylightSwitchTimes mehod. Now using a static array to memorize the switch times for the current year.
// 2024.04.12 - v.1.80 : Fixed issue in the calculation of the broker GMT offset on brokers that do not provide gold trading.
// 2024.04.15 - v.1.82 : Added SetCustomTimeZone method to CTimeZoneInfo class, which you can use to configure the built-in custom time zone with a specified name, GMT offset and DST identifier. The custom time zone can be accessed via ZONE_ID_CUSTOM.
// 2024.04.16 - v.1.85 : Replaced the GetNthSunday internal method with the more optimized GetMonthTime method.
// 2024.04.17 - v.1.87 : Replaced the TimeYear internal method with the more optimized GetYear method.
// 2024.04.18 - v.1.88 : Added the CreateDateTime internal method to construct datetime values from date components (year, month and day). This is 100-120x times faster than calling the StructToTime function.
// 2024.10.21 - v.1.90 : Improved detection of the GOLD symbol with fallback to EURUSD symbol.
// 2024.10.22 - v.1.93 : Faster determination of the server's GMT offset during weekend in the live trading.
// 2024.10.26 - v.1.95 : Added two new static methods: TimeGMTOffset() and TimeDaylightSavings(). Renamed the HistoryBrokerOffset() method to TimeServerGMTOffset().
// 2024.10.28 - v.1.97 : Converted all macros for dealing with time to functions to avoid double evaluation of parameters inside macro body. More code clean-up in other lines.
// 2024.10.30 - v.1.98 : Fixed issue of wrong estimation of GMT offset from XAUEUR quotes on some brokers.
// 2024.11.01 - v.1.99 : Added an option to switch off the default loading of Gold symbol for estimation of the server's TZ/DST. Call CTimeZoneInfo::SetUsingGoldSymbol() with 'false' to use the current chart's symbol, instead.
// 2024.11.13 - v.2.00 : Improved estimation of online server tz/dst and in the strategy strategy (TimeGMT library is no longer needed). Constructor accepts place and time parameters. New public methods for working with data of datetime type. Improved error handling and debugging support.
// 2024.11.14 - v.2.02 : Fixed error ERR_HISTORY_NOT_FOUND (4401) when trying to access the XAUUSD,H1 quotes history by the server timezone object.
// 2024.11.17 - v.2.03 : Minor bug fixes.
// 2024.11.23 - v.2.04 : Minor improvements and bug fixes.
// 2024.12.05 - v.2.05 : Added new static method DaylightSavingsSupported(placeId).
// 2024.12.12 - v.2.10 : Improved performance of HistoryServerGMTOffset() and HistoryServerDaylightSavings() functions, and other minor code changes.
// 2024.12.14 - v.2.11 : Improved performance of FindSymbol() function.
// 2024.12.17 - v.2.12 : Further optimization of HistoryServerGMTOffset() and HistoryServerDaylightSavings() functions.
// 2024.12.24 - v.2.13 : Fixed potential issue in HistoryServerGMTOffset() and HistoryServerDaylightSavings() functions.
// 2025.01.12 - v.2.15 : Fixed issue in HistoryServerDaylightSavings() of searching for quotes history earlier than the loaded history in the strategy tester.
// 2025.10.13 - v.2.17 : Minor improvements and bug fixes.

#include <Generic\HashMap.mqh>

//+------------------------------------------------------------------+
//| Time zone identifiers                                            |
//+------------------------------------------------------------------+
enum ENUM_ZONE_ID
  {
   /* caution: lookup tables depends on the order of enum */
   ZONE_ID_SYDNEY,     // Sydney
   ZONE_ID_TOKYO,      // Tokyo
   ZONE_ID_FRANKFURT,  // Frankfurt
   ZONE_ID_LONDON,     // London
   ZONE_ID_NEWYORK,    // New York
   ZONE_ID_UTC,        // UTC
   ZONE_ID_LOCAL,      // LOCAL
   ZONE_ID_BROKER,     // BROKER
   ZONE_ID_CUSTOM      // CUSTOM
  };
//+------------------------------------------------------------------+
//| User-defined errors                                              |
//+------------------------------------------------------------------+
enum ENUM_ERR_USER_TIMEZONE
  {
   ERR_USER_TIME_OK = 0,
   ERR_USER_TIME_INVALID = 1,
   ERR_USER_WRONG_ZONEID = 2,
   ERR_USER_WRONG_PARAMETERS = 3
  };
//+------------------------------------------------------------------+
//| Structure to keep the times.                                     |
//+------------------------------------------------------------------+
struct Time
  {
   datetime          localtime;
   datetime          utctime;
  };
//+------------------------------------------------------------------+
//| Structure to keep the time zone offset information.              |
//+------------------------------------------------------------------+
struct TimeZone
  {
   int               offset;       // base utc offset
   int               dst;          // dst adjustment
   int               totaloffset;  // total utc offset (includes dst)
  };
//+------------------------------------------------------------------+
//| Structure to keep the time zone daylight saving times.           |
//+------------------------------------------------------------------+
struct TimeChange
  {
   int               dstbias;
   int               timedelta;
   datetime          oldlocaltime;
   datetime          newlocaltime;
  };
//+------------------------------------------------------------------+
//| Macros                                                           |
//+------------------------------------------------------------------+
#define TIME_NOW  (0)
#define WRAP24(H) ((H + 24) % 24)     // wrap value around 24 hours
#define Debug(message)  PrintFormat("    <%s> %s(){ line %d: %s }", __FILE__, __FUNCTION__, __LINE__, message)

#define CHKERR(expression, action) \
   ResetLastError(); \
   expression; \
   if(_LastError) { \
      Debug(StringFormat("Error in %s.  Error code = %d", #expression, _LastError)); \
      action; \
   }
//+------------------------------------------------------------------+
//| Class CTimeZoneInfo.                                             |
//| Purpose: Class to access to the local time for the specified     |
//|          location, as well as time zone information, time        |
//|          changes for the current year.                           |
//|                                                                  |
//| Offset notation used in the library:                             |
//|          Please note, that the library denotes positive time     |
//|          zones by positive offsets, and negative time zones      |
//|          by negative offsets.                                    |
//|          This is opposite of built-in TimeGMTOffset() function   |
//|          which denotes positive time zones, such as GMT+3, by    |
//|          negative offsets, such as -10800, and vice versa.       |
//|                                                                  |
//| Symbol for Estimation of The Server TZ/DST:                      |
//|          By default, library uses XAUUSD as it provides reliable |
//|          results (esp., brokers that follow EU DST schedule).    |
//|          To use the current chart's symbol instead of XAUUSD,    |
//|          call CTimeZoneInfo::SetUsingGoldSymbol() with 'false'.  |
//|                                                                  |
//| Compatibility with The Strategy Tester:                          |
//|          The library estimates the proper times in time zones    |
//|          based on "true" GMT by analysis of H1 quotes history,   |
//|          and not based on the time returned by calling built-in  |
//|          TimeGMT() function.                                     |
//|          If the XAUUSD symbol is used for estimation of the      |
//|          server's TZ/DST then dst switches will occur one hour   |
//|          later in the strategy tester.                           |
//+------------------------------------------------------------------+
class CTimeZoneInfo
  {
protected:
   string            m_name;       // timezone name
   ENUM_ZONE_ID      m_id;         // timezone integer id
   Time              time;         // timezone local time and utc time
   TimeZone          timezone;     // timezone offset information
   TimeChange        dststart;     // daylight savings time start
   TimeChange        dstend;       // daylight savings time end

public:
                     CTimeZoneInfo(const ENUM_ZONE_ID placeId, const datetime pLocalTime = TIME_NOW);
                    ~CTimeZoneInfo(void) { }

   //--- methods to access to protected data
   string            Name(void) const { return(m_name); }                                   // Returns the name of time zone
   string            ToString(bool secs = true, bool tzname = true) const;                  // Returns a string of local time formatted with TZ/DST offset and tzname

   //--- methods to populate timezone information
   bool              RefreshTime(void);                                                     // Refresh the current local time and populate timezone information
   bool              SetLocalTime(const datetime pLocalTime = TIME_NOW);                    // Set the local time for this location to the specified time

   //--- methods to access time zone time (each object has 2 times + 2 offsets)
   datetime          TimeLocal(void)           const { return(time.localtime);       }      // Returns the local time in timezone
   datetime          TimeUTC(void)             const { return(time.utctime);         }      // Returns the UTC time (the same in all time zones)
   int               TimeGMTOffset(void)       const { return(timezone.totaloffset); }      // Positive value for positive timezones (eg, GMT+3), otherwise negative. (includes DST)
   int               TimeDaylightSavings(void) const { return(timezone.dst);         }      // Returns DST correction (in seconds) for timezone, at the set local time.

   //--- methods to access other services
   datetime          ConvertLocalTime(const ENUM_ZONE_ID destinationId) const;              // Convert local time in this time zone to a different time zone
   bool              GetDaylightSwitchTimes(datetime &dst_start, datetime &dst_end) const;  // Get the Daylight Savings Time start and end times for the year
   datetime          GetDaylightNextSwitch(void) const;                                     // Get the local time of the next Daylight Savings Time switch
   void              PrintObject(void) const;

public:
   //--- static methods that do not require the creation of an object.
   static datetime   GetCurrentTimeForPlace ( const ENUM_ZONE_ID placeId );                 // Get the current local time for the specified time zone
   static string     FormatTimeForPlace     ( const datetime time, const ENUM_ZONE_ID placeId, bool secs = true, bool tzname = true );
   static datetime   ConvertTimeForPlace    ( const datetime time, const ENUM_ZONE_ID placeId, const ENUM_ZONE_ID destinationId );
   static int        TimeGMTOffset          ( const ENUM_ZONE_ID placeId, const datetime time = TIME_NOW );   // Returns total tz offset (UTC+DST) from GMT, for a timezone at given local time
   static int        TimeDaylightSavings    ( const ENUM_ZONE_ID placeId, const datetime time = TIME_NOW );   // Returns dst correction in seconds, for a timezone at given local time

   static bool       IsDaylightSavingsTime  ( const ENUM_ZONE_ID placeId, const datetime time = TIME_NOW );   // Checks if a specified time falls in the Daylight Savings Time
   static bool       DaylightSavingsSupported( const ENUM_ZONE_ID placeId);                                   // Checks if the given timezone supports the Daylight Savings Time policy
   static bool       GetDaylightSwitchTimes ( const ENUM_ZONE_ID placeId, const int iYear, datetime &dst_start, datetime &dst_end );
   static bool       GetDaylightSwitchDeltas( const ENUM_ZONE_ID placeId, const int iYear, int &delta_start, int &delta_end );

   static bool       SetCustomTimeZone(const string name, const int baseGMTOffset = 0,      // Defines a time zone that is not found in the library.
                                       const ENUM_ZONE_ID dstSchedule = ZONE_ID_UTC);
   static void       SetUsingGoldSymbol(const bool enabled = true);                         // Sets the option to use Gold symbol for estimation of server TZ/DST

protected:
   //--- internal methods
   static int        HistoryServerGMTOffset(const datetime srvtime);                        // estimate server TZ offset (UTC+DST) from GMT at a given time
   static int        HistoryServerDaylightSavings(const datetime srvtime);                  // estimate server time DST correction from H1 quotes history
   static datetime   FirstBarOfWeek(datetime &weekend, int depthLimit = 8);                 // Returns the time of the first H1 bar after a given weekend (skips abnormal weeks)
   static string     FindSymbol(string symbol);
   static bool       CheckLoadHistory(const string symbol, const ENUM_TIMEFRAMES period);   // Checks presence of the history for symbol and timeframe
   //--- static variables
   static            CHashMap<datetime,int>m_serveroffset;                                  // hashmap of server tz offset
   static            CHashMap<datetime,int>m_serverdst;                                     // hashmap of server dst correction

protected:
   //--- methods for working with data of datetime type
   static datetime   Date(const int year, const int mon, const int day,                     // Create a datetime value from date/time components
                          const int hour = 0, const int min = 0, const int sec = 0);
   static datetime   StartOfWeek(const datetime time, const bool StartsOnMonday = false);   // Return the start of a week for the given date
   static int        WeekIndex(const datetime time, const bool StartsOnMonday = false);     // Returns the zero-based absolute week number since 1 Jan 1970
   static int        DayOfWeek(const datetime time);                                        // Day of week as integer (0-Sunday, 1-Monday, ... ,6-Saturday)
   static int        GetYear(const datetime time);                                          // Returns year as integer of the given date (e.g., 2019)
   static int        GetHour(const datetime time);                                          // Return hour of day as integer (0..23) of the given date
   static string     t2s(const datetime time, const int mode = TIME_DATE | TIME_MINUTES);   // Formats time with the weekday name => "Wed, 2023.02.14 01:59"

   //--- time unit constants
   enum ENUM_TIME_UNITS
     {
      MINSECS  = 60,
      HOURSECS = 3600,     // = 60 * 60,
      DAYSECS  = 86400,    // = 60 * 60 * 24,
      WEEKSECS = 604800,   // = 60 * 60 * 24 * 7,
      YEARSECS = 31536000  // = 60 * 60 * 24 * 365
     };

private:
   static string     m_symbol;
   static bool       m_using_xauusd;
   static bool       m_suspend_errors;
   //--- variables for the custom timezone
   static string     m_custom_name;
   static int        m_custom_offset;
   static ENUM_ZONE_ID m_custom_rule_id;
   //---
   static string     m_tbl_city_names[];
   static int        m_tbl_utc_offset[];
   static int        m_tbl_dst_start[];
   static int        m_tbl_dst_end[];
  };
//--- Initialize static variables
CHashMap<datetime,int> CTimeZoneInfo::m_serveroffset;
CHashMap<datetime,int> CTimeZoneInfo::m_serverdst;
string               CTimeZoneInfo::m_symbol=NULL;
bool                 CTimeZoneInfo::m_using_xauusd=true; // search for and load Gold symbol (default)
bool                 CTimeZoneInfo::m_suspend_errors=false;
string               CTimeZoneInfo::m_custom_name="Custom";
int                  CTimeZoneInfo::m_custom_offset=0; // base tz offset in seconds
ENUM_ZONE_ID         CTimeZoneInfo::m_custom_rule_id=ZONE_ID_UTC;
string               CTimeZoneInfo::m_tbl_city_names[] = { "Sydney", "Tokyo", "Frankfurt", "London", "New York", "UTC" };
int                  CTimeZoneInfo::m_tbl_utc_offset[] = {  10,       9,       1,           0,        -5,         0    }; // base utc offsets in hours
int                  CTimeZoneInfo::m_tbl_dst_start[]  = {   0,       0,       1,           1,         1,         0    }; // dst bias during spring
int                  CTimeZoneInfo::m_tbl_dst_end[]    = {   1,       0,       0,           0,         0,         0    }; // dst bias during autumn
//+------------------------------------------------------------------+
//| Constructor.                                                     |
//| CTimeZoneInfo objects, by default, instantiate with the current  |
//| local time and time zone information for the specified location. |
//+------------------------------------------------------------------+
CTimeZoneInfo::CTimeZoneInfo(const ENUM_ZONE_ID placeId, const datetime pLocalTime = TIME_NOW) :  m_name(NULL), m_id(WRONG_VALUE)
  {
   ZeroMemory(time);
   ZeroMemory(timezone);
   ZeroMemory(dststart);
   ZeroMemory(dstend);
//--- fill zone id, name, UTC offset and DST bias.
   m_id = placeId;
   switch(m_id)
     {
      case ZONE_ID_SYDNEY:
      case ZONE_ID_TOKYO:
      case ZONE_ID_FRANKFURT:
      case ZONE_ID_LONDON:
      case ZONE_ID_NEWYORK:
      case ZONE_ID_UTC:
         m_name             = m_tbl_city_names[m_id];
         timezone.offset    = m_tbl_utc_offset[m_id] * HOURSECS; // convert utc offsets to seconds
         dststart.dstbias   = m_tbl_dst_start[m_id] * HOURSECS;  // convert dst bias to seconds
         dstend.dstbias     = m_tbl_dst_end[m_id] * HOURSECS;
         dststart.timedelta = dststart.dstbias - dstend.dstbias;
         dstend.timedelta   = dstend.dstbias - dststart.dstbias;
         break;

      case ZONE_ID_LOCAL:
         m_name = "Local-PC";
         break;

      case ZONE_ID_BROKER:
         m_name = ::AccountInfoString(ACCOUNT_SERVER);
         break;

      case ZONE_ID_CUSTOM:
         m_name             = m_custom_name;
         timezone.offset    = m_custom_offset;
         dststart.dstbias   = m_tbl_dst_start[m_custom_rule_id] * HOURSECS;
         dstend.dstbias     = m_tbl_dst_end[m_custom_rule_id] * HOURSECS;
         dststart.timedelta = dststart.dstbias - dstend.dstbias;
         dstend.timedelta   = dstend.dstbias - dststart.dstbias;
         break;

      default:
         Print(">>Error: CTimeZoneInfo constructor cannot properly instantiate an object with placeId = ", placeId);
         SetUserError(ERR_USER_WRONG_ZONEID);
         return;
     }
//--- instantiate with the specified local time
   SetLocalTime(pLocalTime);
  }
//+------------------------------------------------------------------+
//| Refresh the current local time and populate timezone information |
//+------------------------------------------------------------------+
bool CTimeZoneInfo::RefreshTime(void)
  {
   return(SetLocalTime(TIME_NOW));
  }
//+------------------------------------------------------------------+
//| Sets the local time for this location to the specified time,     |
//| and populates other timezone information, accordingly.           |
//+------------------------------------------------------------------+
//| Returns FALSE, if the specified time local falls into a non-     |
//| existing hour during the transition to Daylight Savings Time.    |
//|                                                                  |
//| NB: LocalTime = 0 means the "current" moment in time zone now,   |
//| based on the current GMT: tLOC = TimeGMT() + OFF_LOC + DST_LOC   |
//+------------------------------------------------------------------+
bool CTimeZoneInfo::SetLocalTime(const datetime  pLocalTime = TIME_NOW)
  {
   datetime tts  = ::TimeTradeServer();
   datetime tGMT = ::TimeGMT();

//--- In the strategy tester, TimeGMT() is always equal to TimeTradeServer() simulated server time.
//--- However, the "true" GMT can be estimated by analysis of H1 quotes history to get the server
//--- timezone offset. The server GMT offset is subtracted from server time to get the true GMT.
//--- (e.g., TimeTradeServer() = 23:00, and offset from H1 bars = GMT+3, then true GMT = 20:00).

   #ifndef TIMEGMT_UNIQUE_HEADER_ID_H     // apply fix only in tester (update v2.00: 'TimeGMT library' is no longer needed.)
   if(MQLInfoInteger(MQL_TESTER) && pLocalTime == TIME_NOW)
     {
      tGMT = tts - HistoryServerGMTOffset(tts);
     }
   #endif

   switch(m_id)
     {
      case ZONE_ID_LOCAL:
         timezone.dst    = -(int)(::TimeDaylightSavings());
         timezone.offset = -(int)(::TimeGMTOffset());
         //--- the dst correction has to subtracted from the "timezone.offset"
         //--- so that, the field holds the "base" utc offset (excluding dst)
         timezone.offset -= timezone.dst;
         break;

      case ZONE_ID_BROKER:
        {
         datetime srvtime = pLocalTime;
         if(srvtime == TIME_NOW || srvtime > fmax(tts, TimeCurrent()))
           {
            srvtime = fmax(tts, TimeCurrent());
           }

         ResetLastError();

         //--- determine the server's TZ/DST from H1 quotes history
         int DST = HistoryServerDaylightSavings(srvtime);
         int utc = HistoryServerGMTOffset(srvtime);  // tz offset from bars

         if(DST == INT_MIN || utc == INT_MIN)
           {
            Debug(StringFormat("Error in int DST = HistoryServerDaylightSavings(%s).  Error code = %d", t2s(srvtime), _LastError));  // ERR_HISTORY_NOT_FOUND (4401)
            timezone.offset = timezone.dst = INT_MIN;
            time.localtime = time.utctime = WRONG_VALUE;
            return(false);
           }

         #ifdef PRINT_TZ_DETAILS
         Debug(StringFormat("Server time offset: UTC%+g %s", utc/(double)HOURSECS, DST ? "DST" : "STD"));
         #endif

         //--- if called for online time, we can check against built-in functions for refinement
         const int OnlineServerGMTOffset = (int)(tts - tGMT);  // online tz offset

         if(WeekIndex(tts) == WeekIndex(srvtime) && OnlineServerGMTOffset != utc
            && TerminalInfoInteger(TERMINAL_CONNECTED) && !MQLInfoInteger(MQL_TESTER))
           {
            if(DST && OnlineServerGMTOffset == utc - 1*HOURSECS)
              {
               utc  = OnlineServerGMTOffset;
               DST  = 0; // switch to winter
               #ifdef PRINT_TZ_DETAILS
               Debug(StringFormat("[Online time zone change: UTC%+g STD", utc/(double)HOURSECS));
               #endif
               //--- update current week's tz/dst in the cache
               m_serveroffset.TrySetValue(StartOfWeek(srvtime), utc);
               m_serverdst.TrySetValue(StartOfWeek(srvtime), DST);
              }
            else
            if(!DST && OnlineServerGMTOffset == utc + 1*HOURSECS)
              {
               utc  = OnlineServerGMTOffset;
               DST  = 1*HOURSECS; // summer
               #ifdef PRINT_TZ_DETAILS
               Debug(StringFormat("Online time zone change: UTC%+g DST", utc/(double)HOURSECS));
               #endif
               //--- update current week's tz/dst in the cache
               m_serveroffset.TrySetValue(StartOfWeek(srvtime), utc);
               m_serverdst.TrySetValue(StartOfWeek(srvtime), DST);
              }
           }

         timezone.dst    = DST;
         timezone.offset = utc;
         //--- the dst correction has to subtracted from the "timezone.offset"
         //--- so that, the field holds the "base" tz offset (excluding dst)
         timezone.offset -= timezone.dst;
        }

      break;
     }

   time.localtime = pLocalTime == TIME_NOW ? tGMT + timezone.offset : pLocalTime;

   #ifdef PRINT_TZ_DETAILS
   Debug(StringFormat("%s: Setting timezone's local time to %s.", m_name, t2s(time.localtime)));
   #endif

//--- determine the daylight savings switch times for this year
   if(GetDaylightSwitchTimes(dststart.oldlocaltime, dstend.oldlocaltime))
     {
      //--- only for time zones that observe daylight time
      #ifdef PRINT_TZ_DETAILS
      Debug(StringFormat("%s: DST starts on %s (%+d) and ends on %s (%+d).",
                         m_name, t2s(dststart.oldlocaltime), dststart.timedelta/HOURSECS,
                         t2s(dstend.oldlocaltime), dstend.timedelta/HOURSECS));
      #endif

      //--- dst struct
      dststart.newlocaltime = dststart.oldlocaltime + dststart.timedelta;
      dstend.newlocaltime = dstend.oldlocaltime + dstend.timedelta;

      /**
       * DST Transitions:
       * https://www.timeanddate.com/time/dst/transition.html
       *
       * ("Summer Skip", "Winter Wind-back")
       * Switch to summer time (DST+1): clock skips the switch hour (non-existing).
       * Switch to winter time (DST+0): clock repeats the hour before the switch again.
       */

      //--- Switch to summer time in the northern hemisphere of earth
      //--- if the time does not exist in timezone, because DST skipped 1 hour
      if(pLocalTime>=dststart.oldlocaltime && pLocalTime<dststart.newlocaltime)
        {
         if(!m_suspend_errors)
           {
            PrintFormat(">>Error: The time %s does not exist in %s. This is because Daylight Savings Time skipped one hour.", t2s(pLocalTime), m_name);
            SetUserError(ERR_USER_TIME_INVALID);
           }
         time.localtime = time.utctime = WRONG_VALUE;
         return(false);
        }

      //--- Switch to summer time in the southern hemisphere of earth
      if(pLocalTime>=dstend.oldlocaltime && pLocalTime<dstend.newlocaltime)
        {
         if(!m_suspend_errors)
           {
            PrintFormat(">>Error: The time %s does not exist in %s. This is because Daylight Savings Time skipped one hour.", t2s(pLocalTime), m_name);
            SetUserError(ERR_USER_TIME_INVALID);
           }
         time.localtime = time.utctime = WRONG_VALUE;
         return(false);
        }

      timezone.dst = ( time.localtime >= MathMin(dststart.oldlocaltime, dststart.newlocaltime)
                    && time.localtime  < MathMin(dstend.oldlocaltime, dstend.newlocaltime) ) ? dststart.dstbias : dstend.dstbias;
     }

//--- timezone struct
   timezone.totaloffset = timezone.offset + timezone.dst;

   #ifdef PRINT_TZ_DETAILS
   Debug(StringFormat("%s: Time zone base offset UTC%+g hours | DST %+g hours"+
                      " | Total offset UTC%+g hours.", m_name, timezone.offset/(double)HOURSECS,  // double div as tz could be (GMT+5.5)
                      timezone.dst/(double)HOURSECS, timezone.totaloffset/(double)HOURSECS));
   #endif

//--- time struct
   time.localtime = pLocalTime == TIME_NOW ? tGMT + timezone.totaloffset : pLocalTime;
   time.utctime = time.localtime - timezone.totaloffset;

   #ifdef PRINT_TZ_DETAILS
   Debug(StringFormat("%s: Local time is %s | corresponding UTC Time is %s.",
                      m_name, this.ToString(true,false), t2s(time.utctime, TIME_DATE|TIME_SECONDS)));
   #endif

   return(true);
  }
//+------------------------------------------------------------------+
//| Get the Daylight Savings Time start and end times for the year.  |
//| Returns FALSE, if the given time zone does not observe DST.      |
//+------------------------------------------------------------------+
bool CTimeZoneInfo::GetDaylightSwitchTimes(datetime &dst_start, datetime &dst_end) const
  {
//--- formulae from https://www.webexhibits.org/daylightsaving/i.html
   const int iYear = GetYear(time.localtime);
   const int Y = 5 * iYear / 4;

   switch(m_id)
     {
      case ZONE_ID_SYDNEY:
         ///
         /// Sydney: https://www.timeanddate.com/time/change/australia/sydney
         /// DST begins at 03:00 local time on the first Sunday of April (-1),
         /// and ending at 02:00 local time on the first Sunday of October (+1)
         ///
         dst_start = Date(iYear, 04, (7 - (4 + Y) % 7), 03, 00);
         dst_end   = Date(iYear, 10, (7 - (5 + Y) % 7), 02, 00);
         break;

      case ZONE_ID_FRANKFURT:
         ///
         /// Frankfurt: https://www.timeanddate.com/time/change/germany/frankfurt
         /// DST begins at 02:00 local time on the last Sunday of March (+1),
         /// and ending at 03:00 local time on the last Sunday of October (-1)
         ///
         dst_start = Date(iYear, 03, (31 - (4 + Y) % 7), 02, 00);
         dst_end   = Date(iYear, 10, (31 - (1 + Y) % 7), 03, 00);
         break;

      case ZONE_ID_LONDON:
         ///
         /// London: https://www.timeanddate.com/time/change/uk/london
         /// DST begins at 01:00 local time on the last Sunday of March (+1),
         /// and ending at 02:00 local time on the last Sunday of October (-1)
         ///
         dst_start = Date(iYear, 03, (31 - (4 + Y) % 7), 01, 00);
         dst_end   = Date(iYear, 10, (31 - (1 + Y) % 7), 02, 00);
         break;

      case ZONE_ID_NEWYORK:
         ///
         /// New York: https://www.timeanddate.com/time/change/usa/new-york
         /// DST begins at 02:00 local time on the second Sunday of March (+1),
         /// and ending at 02:00 local time on the first Sunday of November (-1)
         ///
         dst_start = Date(iYear, 03, (14 - (1 + Y) % 7), 02, 00);
         dst_end   = Date(iYear, 11, (07 - (1 + Y) % 7), 02, 00);
         break;

      case ZONE_ID_CUSTOM:

         return(CTimeZoneInfo::GetDaylightSwitchTimes(m_custom_rule_id, iYear, dst_start, dst_end));

      case ZONE_ID_TOKYO:  // no DST
      case ZONE_ID_UTC:    // no DST
      case ZONE_ID_LOCAL:
      case ZONE_ID_BROKER:
         dst_start = 0;
         dst_end   = 0;

      default:
         return(false);
     }

   return(true);
  }
//+------------------------------------------------------------------+
//| Get the local time of the next Daylight Savings Time switch.     |
//+------------------------------------------------------------------+
datetime CTimeZoneInfo::GetDaylightNextSwitch(void) const
  {
   if(dststart.oldlocaltime == 0)
      return(0);

   if(time.localtime < dststart.oldlocaltime)
      return(dststart.oldlocaltime);

   if(time.localtime < dstend.oldlocaltime)
      return(dstend.oldlocaltime);

//--- past the end of the current year
   datetime dst_start, dst_end;
   int y = GetYear(time.localtime);
   GetDaylightSwitchTimes(m_id, ++y, dst_start, dst_end);

   return(dst_start);
  }
//+------------------------------------------------------------------+
//| Get the Daylight Savings Time start and end times for the year.  |
//| Returns FALSE, if the given time zone does not observe DST.      |
//+------------------------------------------------------------------+
bool CTimeZoneInfo::GetDaylightSwitchTimes(const ENUM_ZONE_ID placeId, const int iYear, datetime &dst_start, datetime &dst_end)
  {
//--- populate DST switch times for the current year
   CHKERR(CTimeZoneInfo timezone(placeId, Date(iYear,1,1)),
          return(false));
   return(timezone.GetDaylightSwitchTimes(dst_start, dst_end));
  }
//+------------------------------------------------------------------+
//| Get the Daylight Savings Time clock changes in sec for the year. |
//+------------------------------------------------------------------+
bool CTimeZoneInfo::GetDaylightSwitchDeltas(const ENUM_ZONE_ID placeId, const int iYear, int &delta_start, int &delta_end)
  {
   CHKERR(CTimeZoneInfo timezone(placeId),
          return(false));
   delta_start = timezone.dststart.timedelta;
   delta_end = timezone.dstend.timedelta;
   return(true);
  }
//+------------------------------------------------------------------+
//| Checks if a specified time falls in the Daylight Savings Time.   |
//+------------------------------------------------------------------+
bool CTimeZoneInfo::IsDaylightSavingsTime(const ENUM_ZONE_ID placeId,const datetime time = TIME_NOW)
  {
   CHKERR(CTimeZoneInfo timezone(placeId, time),
          return(false));
   return(timezone.TimeDaylightSavings() != 0);
  }
//+------------------------------------------------------------------+
//| Checks if the given timezone supports the Daylight Savings Time. |
//+------------------------------------------------------------------+
bool CTimeZoneInfo::DaylightSavingsSupported(const ENUM_ZONE_ID placeId)
  {
   CHKERR(CTimeZoneInfo timezone(placeId, TIME_NOW),
          return(false));
   const int lastYear = GetYear(timezone.TimeLocal()) - 1;
   CHKERR(CTimeZoneInfo winter(placeId, Date(lastYear,1,1)),
          return(false));
   CHKERR(CTimeZoneInfo summer(placeId, Date(lastYear,7,1)),
          return(false));
   return(summer.TimeDaylightSavings() != winter.TimeDaylightSavings());
  }
//+------------------------------------------------------------------+
//| Get the current local time for the specified time zone.          |
//+------------------------------------------------------------------+
datetime CTimeZoneInfo::GetCurrentTimeForPlace(const ENUM_ZONE_ID placeId)
  {
   CHKERR(CTimeZoneInfo place(placeId, TIME_NOW),
          return(INT_MIN));
   return(place.TimeLocal());
  }
//+------------------------------------------------------------------+
//| Return a string of the local time with TZ/DST and timezone name, |
//| formatted like "Mon, 2024.02.26 20:24:17 GMT+11 DST [Sydney]".   |
//| If 'secs' is FALSE time seconds will not be added to the result. |
//| If 'tzname' is FALSE timezone name is not added to the result.   |
//+------------------------------------------------------------------+
string CTimeZoneInfo::FormatTimeForPlace(const datetime time, const ENUM_ZONE_ID placeId, bool secs = true, bool tzname = true)
  {
   CHKERR(CTimeZoneInfo place(placeId, time),
          return(NULL));
   return(place.ToString(secs, tzname));
  }
//+------------------------------------------------------------------+
//| Returns the total tz offset (UTC+DST) from GMT, for the given    |
//| timezone, at the specified local time in timezone.               |
//| Note: time = 0, means the "current" local time in timezone, now. |
//+------------------------------------------------------------------+
int CTimeZoneInfo::TimeGMTOffset(const ENUM_ZONE_ID placeId, const datetime time = TIME_NOW)
  {
//--- the given local time may be invalid and does not correspond to
//--- any existing time in this place e.g., due to DST transitions.
   CHKERR(CTimeZoneInfo place(placeId, time),
          return(INT_MIN));
   return(place.TimeGMTOffset());
  }
//+------------------------------------------------------------------+
//| Returns correction for Daylight Savings Time in seconds, for the |
//| specified timezone at the specified local time, if the switch    |
//| to summer time has been made. It depends on the time settings    |
//| of that timezone. If switch to winter (standard) time has been   |
//| made, or if the timezone does not observe DST, it returns 0.     |
//+------------------------------------------------------------------+
int CTimeZoneInfo::TimeDaylightSavings(const ENUM_ZONE_ID placeId, const datetime time = TIME_NOW)
  {
   CHKERR(CTimeZoneInfo place(placeId, time),
          return(INT_MIN));
   return(place.TimeDaylightSavings());
  }
//+------------------------------------------------------------------+
//| Convert local time from one time zone to another time zone.      |
//+------------------------------------------------------------------+
datetime CTimeZoneInfo::ConvertTimeForPlace(const datetime time, const ENUM_ZONE_ID placeId, const ENUM_ZONE_ID destinationId)
  {
   CHKERR(CTimeZoneInfo place(placeId, time),
          return(INT_MIN));
   return(place.ConvertLocalTime(destinationId));
  }
//+------------------------------------------------------------------+
//| Convert local time in this time zone to a different time zone.   |
//+------------------------------------------------------------------+
datetime CTimeZoneInfo::ConvertLocalTime(const ENUM_ZONE_ID destinationId) const
  {
   /**
    * To convert time in New York to corresponding time in London:
    * tGMT = tNYC - (OFF_NYC + DST_NYC);
    * tLON = tGMT + (OFF_LON + DST_LON);
    */
   const datetime tGMT = this.TimeUTC();

   CHKERR(CTimeZoneInfo dest(destinationId),
          return(INT_MIN));

//--- objects automatically instantiated with UTC offsets
   datetime tDest = tGMT + dest.timezone.offset;

//--- suspend errors before SetLocalTime() call
   m_suspend_errors = true;

//--- populate utc and dst offsets in destination for this local time
   if(!dest.SetLocalTime(tDest))
     {
      //--- forward invalid time if falls within a DST+1 skipped hour
      dest.SetLocalTime(tDest + 1*HOURSECS);
     }

//--- resume errors after SetLocalTime() call
   m_suspend_errors = false;

//--- add utc + dst offsets to get the adjusted local time for destination
   tDest = tGMT + dest.timezone.totaloffset;
//---
   return(tDest);
  }
//+------------------------------------------------------------------+
//| Defines a time zone that is not found in the library, and sets   |
//| its name, an offset from GMT and a daylight schedule identifier. |
//| baseGMTOffset  :  must be a whole multiple of 30 minutes.        |
//| dstSchedule :  must be less than or equal to ZONE_ID_UTC         |
//| NB: dstSchedule = ZONE_ID_UTC means the custom timezone does     |
//| not observe Daylight Savings Time, i.e., DST isn't not applied.  |
//|                                                                  |
//| The custom timezone can be useful for certain time conversions,  |
//| in which ZONE_ID_CUSTOM is passed as parameter to class methods. |
//+------------------------------------------------------------------+
bool CTimeZoneInfo::SetCustomTimeZone(
   const string        name = "Custom",
   const int           baseGMTOffset = 0,
   const ENUM_ZONE_ID  dstSchedule = ZONE_ID_UTC
   )
  {
//--- fails if the baseGMTOffset parameter is greater than 14 hours or less
//--- than -14 hours, or does not represent a whole multiple of 30 minutes.
   if(!StringLen(name)
      || (MathAbs(baseGMTOffset) > 14 * HOURSECS)
      || (baseGMTOffset % 1800 != 0)
      || (dstSchedule > ZONE_ID_UTC))
     {
      PrintFormat(">>Error: SetCustomTimeZone cannot properly set custom timezone with baseGMTOffset"+
                  " = %i and dstSchedule = %s", baseGMTOffset, EnumToString(dstSchedule));
      SetUserError(ERR_USER_WRONG_PARAMETERS);
      return(false);
     }
//---
   m_custom_name = name;
   m_custom_offset = baseGMTOffset;
   m_custom_rule_id = dstSchedule;
   return(true);
  }
//+------------------------------------------------------------------+
//| Sets the option of using XAUUSD (Gold) symbol to estimate the    |
//| server's TZ/DST by analysis of H1 quotes history.                |
//| TRUE  : search for and load Gold symbol (default behavior).      |
//| FALSE : use the symbol of the current chart.                     |
//|                                                                  |
//| XAUUSD can provide more reliable results (esp., for brokers      |
//| that follow EU DST schedule) on weeks during US DST and EU       |
//| DST schedules are out of sync (March and late October).          |
//| if your broker follows the US DST schedule, or no schedule       |
//| at all, then using the chart symbol is Ok.                       |
//|                                                                  |
//| Note: as a side effect that XAUUSD starts an hour after Forex,   |
//| dst switches occur one hour later (only in the strategy tester). |
//+------------------------------------------------------------------+
void CTimeZoneInfo::SetUsingGoldSymbol(const bool enabled = true)
  {
   m_using_xauusd = enabled;
//--- removes all keys and values from the map.
   m_serveroffset.Clear();
   m_serverdst.Clear();
//--- force a new search for the symbol
   m_symbol = enabled ? FindSymbol("XAUUSD") : _Symbol;
//--- Check the H1 history is loaded
   CheckLoadHistory(m_symbol, PERIOD_H1);
//---
   Print("CTimeZoneInfo >> Using Gold symbol option: ", m_using_xauusd);
   Print("CTimeZoneInfo >> Loaded symbol: ", m_symbol, ",H1");
  }
//+------------------------------------------------------------------+
//| Return a string of the local time with TZ/DST and timezone name, |
//| formatted like "Mon, 2024.02.26 20:24:17 GMT+11 DST [Sydney]".   |
//| If 'secs' is FALSE time seconds will not be added to the result. |
//| If 'tzname' is FALSE timezone name is not added to the result.   |
//+------------------------------------------------------------------+
string CTimeZoneInfo::ToString(bool secs = true, bool tzname = true) const
  {
   return(StringFormat("%s GMT%+g %s%s", t2s(time.localtime, TIME_DATE + (secs ? TIME_SECONDS : TIME_MINUTES)),
                       timezone.totaloffset / (double)HOURSECS,
                       timezone.dst ? "DST" : "STD",
                       tzname ? " ["+m_name+"]" : ""));
  }
//+------------------------------------------------------------------+
//| Estimates server TZ offset (UTC+DST) from GMT at a given time.   |
//| see https://www.mql5.com/en/code/48291                           |
//+------------------------------------------------------------------+
int CTimeZoneInfo::HistoryServerGMTOffset(const datetime srvtime)
  {
   static datetime last_sunday = -1;
   static int last_result = INT_MIN;

   #ifdef PRINT_TZ_DETAILS
   Debug(StringFormat("** Estimating server GMT offset of '%s' server for %s from %s,H1 quotes", AccountInfoString(ACCOUNT_SERVER), t2s(srvtime), m_symbol));
   #endif

   if(StartOfWeek(srvtime) == last_sunday && m_serveroffset.Count() > 0)
     {
      #ifdef PRINT_TZ_DETAILS
      Debug(StringFormat("last_sunday: %s -> %d (GMT%+g)", t2s(last_sunday), last_result, last_result/(double)HOURSECS));
      #endif

      return(last_result);
     }

//--- start at the last bar if 'srvtime' falls in the last weekend or holidays (no FstBarWk yet)
   const datetime lastbar = (datetime)SeriesInfoInteger(m_symbol, PERIOD_H1, SERIES_LASTBAR_DATE);

   datetime curtime = srvtime;
   if(curtime == 0 || curtime > lastbar)
     {
      curtime = lastbar;
     }

   const datetime sunday = StartOfWeek(curtime);  // the weekend "Sunday 00:00" before this time

//--- search this week in the broker gmt offset cache
   int serveroffset = INT_MIN;
   if(!m_serveroffset.TryGetValue(sunday, serveroffset))
     {
      const datetime firstbar = (datetime) SeriesInfoInteger(m_symbol, PERIOD_H1, SERIES_FIRSTDATE);

      //--- weekend could be modified, if recursion had skipped to previous Sundays
      datetime weekend = sunday;

      if(weekend >= firstbar)
        {
         //--- find the time of the first hourly bar after this weekend "Sunday 00:00"
         const datetime FstBarWk = FirstBarOfWeek(weekend);
         if(FstBarWk == WRONG_VALUE)
           {
            Debug(StringFormat("Error in FirstBarOfWeek(%s) = WRONG_VALUE, srvtime = %s", t2s(weekend), t2s(srvtime)));
            last_result = serveroffset = INT_MIN;
            last_sunday = -1;
           }
         else
           {
            //--- Forex pairs start Sun 17:00 NY. Gold starts an hour later.
            int beginNYC = 17 * HOURSECS;
            if(StringFind(m_symbol, "XAU") == 0 || StringFind(m_symbol, "GOLD") == 0)
              {
               beginNYC = 18 * HOURSECS;
              }
            //--- US summer starts on the second Sunday of March (GMT-4),
            //--- and ends on the first Sunday of November (GMT-5).
            int iYear = GetYear(weekend);
            datetime dst_start = Date(iYear, 03, 08);  // the second Sunday of March for the US switch
            datetime dst_end   = Date(iYear, 11, 01);  // the first Sunday of November for the US switch
            datetime tNYC      = weekend + beginNYC;   // Sun, 18:00 NYC should co-incide with broker's 'FstBarWk' on GOLD chart.
            datetime tGMT      = tNYC - ((weekend>=dst_start && weekend<dst_end) ? -4 : -5) * HOURSECS;
            serveroffset       = (int)(FstBarWk - tGMT);
            serveroffset       = (int) MathRound(serveroffset/1800.)*1800;  // round offset to multiples of 30-minutes

            #ifdef PRINT_TZ_DETAILS
            Debug(StringFormat("FstBarWk = %s", t2s(FstBarWk)));
            Debug(StringFormat("tNYC = %s (GMT%+d)", t2s(tNYC), (tNYC>=dst_start && tNYC<dst_end) ? -4 : -5));
            Debug(StringFormat("tGMT = %s", t2s(tGMT)));
            Debug(StringFormat("m_serveroffset.Add(%s, %d (GMT%+g))", t2s(sunday), serveroffset, serveroffset/(double)HOURSECS));
            #endif

            //--- add this week to the server gmt offset cache
            m_serveroffset.Add(sunday, serveroffset);
           }
        }
     }
   #ifdef PRINT_TZ_DETAILS
   else
     {
      Debug(StringFormat("m_serveroffset.TryGetValue(%s) -> %d (GMT%+g)", t2s(sunday), serveroffset, serveroffset/(double)HOURSECS));
     }
   #endif

//--- remember the server gmt offset of this week
   if(serveroffset != INT_MIN)
     {
      last_sunday = sunday;
      last_result = serveroffset;
     }

   return(serveroffset);
  }
//+------------------------------------------------------------------+
//| Estimate server time DST mode correction from H1 quotes history  |
//| Courtesy of Stanislav Korotky https://www.mql5.com/en/code/52557 |
//+------------------------------------------------------------------+
int CTimeZoneInfo::HistoryServerDaylightSavings(const datetime srvtime)
  {
   static datetime last_sunday = -1;
   static int last_result = INT_MIN;

   #ifdef PRINT_TZ_DETAILS
   Debug(StringFormat("** Estimating DST adjustment of '%s' server for %s from %s,H1 quotes", AccountInfoString(ACCOUNT_SERVER), t2s(srvtime), m_symbol));
   #endif

   if(StartOfWeek(srvtime) == last_sunday && m_serverdst.Count() > 0)
     {
      #ifdef PRINT_TZ_DETAILS
      Debug(StringFormat("last_sunday: %s -> %d (%s)", t2s(last_sunday), last_result, last_result ? "DST" : "STD"));
      #endif

      return(last_result);
     }

//--- start at the last bar if 'srvtime' falls in the last weekend or holidays (no FstBarWk yet)
   const datetime lastbar = (datetime)SeriesInfoInteger(m_symbol, PERIOD_H1, SERIES_LASTBAR_DATE);

   datetime curtime = srvtime;
   if(curtime == 0 || curtime > lastbar)
     {
      curtime = lastbar;
     }

   const datetime sunday = StartOfWeek(curtime);  // the weekend "Sunday 00:00" before this time

//--- search this week in the broker dst correction cache
   int serverDST = INT_MIN;
   if(!m_serverdst.TryGetValue(sunday, serverDST))
     {
      const datetime firstbar = (datetime) SeriesInfoInteger(m_symbol, PERIOD_H1, SERIES_FIRSTDATE);
      const datetime firstdate = (datetime) fmax(firstbar, (sunday - 1 * YEARSECS));
      const int threshold = 52 / 4; // a quarter of weeks in a year
      int hours[24] = {};
      int current = INT_MIN;

      //--- for each weekend "Sunday 00:00" starting at last Sunday and going one year back.
      for(datetime weekend = sunday; weekend >= firstdate; weekend -= WEEKSECS)
        {
         //--- find the time of the first hourly bar after that weekend "Sunday 00:00"
         datetime FstBarWk = FirstBarOfWeek(weekend);
         if(FstBarWk == WRONG_VALUE)
           {
            Debug(StringFormat("Error in FirstBarOfWeek(%s) = WRONG_VALUE, srvtime = %s", t2s(weekend), t2s(srvtime)));

            last_result = serverDST = INT_MIN;
            last_sunday = -1;
            return(INT_MIN);
           }

         //--- lets analyze the first H1 bar of the trading week (the first bar after weekend)
         //--- now, check if the server time falls in the US Daylight Savings Time
         if(CTimeZoneInfo::IsDaylightSavingsTime(ZONE_ID_NEWYORK, FstBarWk))
           {
            //--- compensate the effect of US switch on the server time by adding +1 hour
            FstBarWk += 1*HOURSECS;
           }

         //--- find out an open hour for the first bar after weekend
         const int open_hour = GetHour(FstBarWk);

         //--- collect stats for opening hours
         hours[open_hour]++;

         //--- save the opening hour of the current week only
         if(current == INT_MIN)
           {
            current = open_hour;
           }
        }

      #ifdef PRINT_TZ_DETAILS
      Debug(StringFormat("Week opening hours stats [%s - %s]:", t2s(firstdate), t2s(sunday)));
      ArrayPrint(hours);
      #endif

      if(current != INT_MIN)
        {
         serverDST = 0;
         if(hours[current] > threshold && hours[WRAP24(current - 1)] > threshold)
           {
            //--- DST is probably enabled for current week
            serverDST = 1*HOURSECS;
           }

         #ifdef PRINT_TZ_DETAILS
         Debug(StringFormat("Current week opening hour: %d", current));
         Debug(StringFormat("m_serverdst.Add(%s, %d (%s))", t2s(sunday), serverDST, serverDST ? "DST" : "STD"));
         #endif

         //--- add this week to the server dst correction cache
         m_serverdst.Add(sunday, serverDST);
        }
     }
   #ifdef PRINT_TZ_DETAILS
   else
     {
      Debug(StringFormat("m_serverdst.TryGetValue(%s) -> %d (%s)", t2s(sunday), serverDST, serverDST ? "DST" : "STD"));
     }
   #endif

//--- remember the server dst correction of this week
   if(serverDST != INT_MIN)
     {
      last_sunday = sunday;
      last_result = serverDST;
     }

   return(serverDST);
  }
//+------------------------------------------------------------------+
//| Returns the time of the first H1 bar after the given weekend.    |
//| The function skips abnormal trading weeks around holidays.       |
//+------------------------------------------------------------------+
datetime CTimeZoneInfo::FirstBarOfWeek(datetime &weekend, int depthLimit = 8)
  {
   if(m_symbol==NULL)
     {
      //--- Gold has accurate start of trading weeks (esp. EU DST brokers)
      m_symbol = m_using_xauusd ? FindSymbol("XAUUSD") : _Symbol;
      //--- Check the H1 history is loaded
      CheckLoadHistory(m_symbol, PERIOD_H1);

      #ifdef PRINT_TZ_DETAILS
      Print("CTimeZoneInfo >> Using Gold symbol option: ", m_using_xauusd);
      Print("CTimeZoneInfo >> Loaded symbol: ", m_symbol, ",H1");
      #endif
     }

//--- find the first hourly bar after the specified weekend "Sunday 00:00"
   const int barindex = iBarShift(m_symbol, PERIOD_H1, weekend, false);
   const datetime bartime = iTime(m_symbol, PERIOD_H1, barindex - 1);

   #ifdef PRINT_TZ_DETAILS
   Debug(StringFormat("iBarShift(%s, %s)=%d, iTime(%d) = %s", m_symbol, t2s(weekend), barindex, barindex-1, t2s(bartime)));
   #endif

   if(barindex < 0 || depthLimit < 0)
     {
      if(MQLInfoInteger(MQL_PROGRAM_TYPE)!=PROGRAM_INDICATOR)
        {
         PrintFormat(">> iBarShift() FAILED: The requested date %s for %s,H1 is not found in the available history", t2s(weekend), m_symbol);
        }
      return(WRONG_VALUE);
     }

//--- Skip long weekends or holidays (bartime > Monday 12:00 PM)
   if(barindex == 0 || bartime > weekend + 36 * HOURSECS)
     {
      #ifdef PRINT_TZ_DETAILS
      Debug(StringFormat("bartime = %s", t2s(bartime)));
      Debug(StringFormat("weekend = %s", t2s(weekend)));
      Debug("Detected long weekend / Christmas holidays, skip to previous weekend:");
      #endif
      weekend -= WEEKSECS;  // change 'weekend' to the previous Sunday 00:00
      return(FirstBarOfWeek(weekend, depthLimit - 1));
     }
//---
   return(bartime);
  }
//+------------------------------------------------------------------+
//| Find and select a symbol for further working with information.   |
//+------------------------------------------------------------------+
string CTimeZoneInfo::FindSymbol(string symbol)
  {
   bool symbol_found = false; // Store if we have found a valid symbol or not yet

//--- if the symbol is found in the list of standard symbols on the server
   bool custom = false;
   if(SymbolExist(symbol, custom) && !custom)
     {
      symbol_found = true;
     }

//--- First try to find if the passed symbol exists
   if(symbol_found == false)
      for(int i=0; i < SymbolsTotal(0); i++)
         if(StringFind(SymbolName(i,0),symbol)==0)
           {
            symbol = SymbolName(i,0); // symbol may have suffix
            symbol_found = true;
            break;
           }
//--- Then try to find a symbol equal to "GOLD"
   if(symbol_found == false)
      for(int i=0; i < SymbolsTotal(0); i++)
         if(SymbolName(i,0)=="GOLD")
           {
            symbol = SymbolName(i,0); // symbol may have suffix
            symbol_found = true;
            break;
           }
//--- Then try to find a symbol that starts with GOLD
   if(symbol_found == false)
      for(int i=0; i < SymbolsTotal(0); i++)
         if(StringFind(SymbolName(i,0),"GOLD")==0)
           {
            symbol = SymbolName(i,0); // symbol may have suffix
            symbol_found = true;
            break;
           }
//--- And finally use the current chart's symbol for brokers that do not provide gold
   if(symbol_found == false)
     {
      symbol = Symbol();
     }

//--- we have found a valid symbol
   SymbolSelect(symbol, true);

   return(symbol);
  }
//+------------------------------------------------------------------+
//| Checks presence of the history for symbol and timeframe.         |
//| http://www.mql5.com/en/docs/series/timeseries_access             |
//+------------------------------------------------------------------+
bool CTimeZoneInfo::CheckLoadHistory(const string symbol, const ENUM_TIMEFRAMES period)
  {
//--- indicator shouldn't load its own symbol and timeframe
   if(MQLInfoInteger(MQL_PROGRAM_TYPE)==PROGRAM_INDICATOR && Period()==period && Symbol()==symbol)
      return(false);
//---
   datetime times[];
   datetime first_date=0;
   int copied=0;
   uint tick=GetTickCount();
//--- wait for timeseries build
   while(!SeriesInfoInteger(symbol,period,SERIES_SYNCHRONIZED) && !IsStopped() && (GetTickCount()-tick<=6000))
      //Sleep(5);
      ;
//--- second attempt
   return(SeriesInfoInteger(symbol,period,SERIES_FIRSTDATE,first_date)
          && first_date>0
          && CopyTime(symbol,period,first_date+PeriodSeconds(period),1,times));
  }
//+------------------------------------------------------------------+
//| Create a datetime value from the given year, month and day.      |
//| https://www.mql5.com/en/forum/393227/page254#comment_53104384    |
//| Limit: Year must be <= 2100                                      |
//+------------------------------------------------------------------+
datetime CTimeZoneInfo::Date(
   const int year,           // Year
   const int mon,            // Month
   const int day,            // Day
   const int hour = 0,       // Hour
   const int min = 0,        // Minutes
   const int sec = 0         // Seconds
   )
  {
// MqlDateTime dt = {year, mon, day, hour, min, sec}
// return StructToTime(dt);

   static const uint Months[] = {0, 11512676, 11512180, 11511728, 11511232, 11510750, 11510256,
                                    11509774, 11509280, 11508781, 11508302, 11507806, 11507326
                                };
   return (((year * 5844 - Months[mon]) >> 4) + day - 1) * DAYSECS + (hour * HOURSECS + min * MINSECS + sec);
  }
//+------------------------------------------------------------------+
//| Return the start of a week for the given date.                   |
//| By default, the week starts on Sunday, unless superseded.        |
//|                                                                  |
//| StartOfWeek (D'2017.08.03 11:30') => 2017.07.30 00:00:00         |
//+------------------------------------------------------------------+
datetime CTimeZoneInfo::StartOfWeek(const datetime t, const bool StartsOnMonday = false)
  {
   return (t - (t + (4 - StartsOnMonday) * DAYSECS) % WEEKSECS);
  }
//+------------------------------------------------------------------+
//| Returns the zero-based absolute week number since 1 Jan 1970     |
//| By default, the week starts on Sunday, unless superseded.        |
//+------------------------------------------------------------------+
int CTimeZoneInfo::WeekIndex(const datetime t, const bool StartsOnMonday = false)
  {
   return (int)((t +  (4 - StartsOnMonday) * DAYSECS) / WEEKSECS); // adding duration of 4 days to get weeks aligned by Sundays
  }
//+------------------------------------------------------------------+
//| Day of the week as integer (0-Sunday, 1-Monday, ... ,6-Saturday) |
//+------------------------------------------------------------------+
int CTimeZoneInfo::DayOfWeek(const datetime t)
  {
// MqlDateTime st;
// TimeToStruct(t, st);
// return(st.day_of_week);
   return ((int)((uint)t / DAYSECS + 4) % 7);
  }
//+------------------------------------------------------------------+
//| Returns year as integer of the given date (e.g., 2019)           |
//| https://www.mql5.com/ru/forum/170952/page251#comment_53071746    |
//+------------------------------------------------------------------+
int CTimeZoneInfo::GetYear(const datetime t)
  {
// MqlDateTime st;
// TimeToStruct(t, st);
// return(st.year);
   return ((int)(((uint)t / DAYSECS * 4 + 2) / 1461) + 1970);
  }
//+------------------------------------------------------------------+
//| Return hour of day as integer (0..23)                            |
//+------------------------------------------------------------------+
int CTimeZoneInfo::GetHour(const datetime t)
  {
// MqlDateTime st;
// TimeToStruct(t, st);
// return(st.hour);
   return (int)((uint)t / HOURSECS) % 24;
  }
//+------------------------------------------------------------------+
//| Formats time with the weekday name => "Wed, 2023.02.14 01:59"    |
//+------------------------------------------------------------------+
string CTimeZoneInfo::t2s(const datetime t, const int mode = TIME_DATE | TIME_MINUTES)
  {
   const string days[] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
   const int i = DayOfWeek(t);
   return days[i % 7] + ", " + TimeToString(t, mode);
  }
//+------------------------------------------------------------------+
//| Debugging support                                                |
//+------------------------------------------------------------------+
void CTimeZoneInfo::PrintObject(void) const
  {
#define PRINT(A) Print(#A + " = ", (A), " ["+typename(A)+"]")

   PRINT(m_name);
   PRINT(m_id);
//--- time struct
   PRINT(time.utctime);
   PRINT(time.localtime);
//--- timezone struct
   PRINT(timezone.offset);
   PRINT(timezone.dst);
   PRINT(timezone.totaloffset);
//--- dststart struct
   PRINT(dststart.dstbias);
   PRINT(dststart.timedelta);
   PRINT(dststart.oldlocaltime);
   PRINT(dststart.newlocaltime);
//--- dstend struct
   PRINT(dstend.dstbias);
   PRINT(dstend.timedelta);
   PRINT(dstend.oldlocaltime);
   PRINT(dstend.newlocaltime);

#undef PRINT
  }
//+------------------------------------------------------------------+

#undef TIME_NOW
#undef WRAP24
#undef Debug
#undef CHKERR


#endif // #ifndef TIMEZONEINFO_UNIQUE_HEADER_ID_H
