//+------------------------------------------------------------------+
//| PeriodSeparatorCalendar.mqh                                      |
//+------------------------------------------------------------------+
#ifndef PERIOD_SEPARATOR_CALENDAR_MQH
#define PERIOD_SEPARATOR_CALENDAR_MQH

#include <TimeZoneInfo.mqh>

class CPeriodSeparatorCalendar
  {
private:
   static datetime DateAt(const int year,const int mon,const int day,const int hour=0,const int minute=0,const int sec=0)
     {
      MqlDateTime dt;
      ZeroMemory(dt);
      dt.year = year;
      dt.mon  = mon;
      dt.day  = day;
      dt.hour = hour;
      dt.min  = minute;
      dt.sec  = sec;
      return StructToTime(dt);
     }

   static datetime StartOfDay(const datetime value)
     {
      MqlDateTime dt;
      TimeToStruct(value,dt);
      return DateAt(dt.year,dt.mon,dt.day);
     }

   static int DayOfWeek(const datetime value)
     {
      MqlDateTime dt;
      TimeToStruct(value,dt);
      return dt.day_of_week;
     }

   static int YearOf(const datetime value)
     {
      MqlDateTime dt;
      TimeToStruct(value,dt);
      return dt.year;
     }

   static int MonthOf(const datetime value)
     {
      MqlDateTime dt;
      TimeToStruct(value,dt);
      return dt.mon;
     }

   static void Append(datetime &items[],const datetime value)
     {
      const int size = ArraySize(items);
      ArrayResize(items,size+1);
      items[size] = value;
     }

   static bool IsDuplicate(datetime &items[],const datetime value)
     {
      const int size = ArraySize(items);
      for(int i=0;i<size;i++)
        {
         if(items[i] == value)
            return true;
        }
      return false;
     }

   static void AppendUnique(datetime &items[],const datetime value)
     {
      if(!IsDuplicate(items,value))
         Append(items,value);
     }

   static void Reverse(datetime &items[])
     {
      const int size = ArraySize(items);
      for(int left=0,right=size-1; left<right; left++,right--)
        {
         const datetime tmp = items[left];
         items[left] = items[right];
         items[right] = tmp;
        }
     }

public:
   static int BuildNewYorkDaily(const datetime oldest_broker,
                                const datetime newest_broker,
                                const int max_count,
                                const bool skip_weekends,
                                datetime &separators[])
     {
      ArrayResize(separators,0);
      if(oldest_broker <= 0 || newest_broker <= 0 || oldest_broker > newest_broker)
         return 0;

      const datetime oldest_ny = CTimeZoneInfo::ConvertTimeForPlace(oldest_broker,ZONE_ID_BROKER,ZONE_ID_NEWYORK);
      const datetime newest_ny = CTimeZoneInfo::ConvertTimeForPlace(newest_broker,ZONE_ID_BROKER,ZONE_ID_NEWYORK);

      datetime start_ny = StartOfDay(oldest_ny) - 86400;
      if(max_count > 0)
        {
         const datetime limited_start = StartOfDay(newest_ny) - (datetime)(max_count * 86400);
         if(limited_start > start_ny)
            start_ny = limited_start;
        }

      const datetime end_ny = StartOfDay(newest_ny) + 86400;
      for(datetime day_ny=start_ny; day_ny<=end_ny; day_ny+=86400)
        {
         const int dow = DayOfWeek(day_ny);
         if(skip_weekends && (dow == 0 || dow == 6))
            continue;

         const datetime broker_time = CTimeZoneInfo::ConvertTimeForPlace(day_ny,ZONE_ID_NEWYORK,ZONE_ID_BROKER);
         if(broker_time >= oldest_broker && broker_time <= newest_broker)
            AppendUnique(separators,broker_time);
        }

      return ArraySize(separators);
     }

   static int BuildWeeklyServer(const string symbol,
                                const datetime oldest_broker,
                                const datetime newest_broker,
                                const int max_count,
                                datetime &separators[])
     {
      ArrayResize(separators,0);
      const int limit = (max_count > 0 ? max_count : 500);

      for(int shift=0; shift<limit; shift++)
        {
         const datetime open_time = iTime(symbol,PERIOD_W1,shift);
         if(open_time <= 0)
            break;
         if(open_time > newest_broker)
            continue;
         if(open_time < oldest_broker)
            break;

         Append(separators,open_time);
        }

      Reverse(separators);
      return ArraySize(separators);
     }

   static int BuildYearlyServer(const string symbol,
                                const datetime oldest_broker,
                                const datetime newest_broker,
                                const int max_count,
                                datetime &separators[])
     {
      ArrayResize(separators,0);
      const int limit = (max_count > 0 ? max_count * 14 : 1200);

      for(int shift=0; shift<limit; shift++)
        {
         const datetime open_time = iTime(symbol,PERIOD_MN1,shift);
         if(open_time <= 0)
            break;
         if(open_time > newest_broker)
            continue;
         if(open_time < oldest_broker)
            break;
         if(MonthOf(open_time) == 1)
            Append(separators,open_time);
        }

      Reverse(separators);
      return ArraySize(separators);
     }

   static int BuildTriYearlyServer(const string symbol,
                                   const datetime oldest_broker,
                                   const datetime newest_broker,
                                   const int max_count,
                                   const int anchor_year,
                                   datetime &separators[])
     {
      ArrayResize(separators,0);
      const int years_needed = (max_count > 0 ? max_count * 3 : 300);
      const int limit = years_needed * 14;

      for(int shift=0; shift<limit; shift++)
        {
         const datetime open_time = iTime(symbol,PERIOD_MN1,shift);
         if(open_time <= 0)
            break;
         if(open_time > newest_broker)
            continue;
         if(open_time < oldest_broker)
            break;
         if(MonthOf(open_time) != 1)
            continue;

         const int year = YearOf(open_time);
         if(MathMod(year - anchor_year,3) == 0)
            Append(separators,open_time);
        }

      Reverse(separators);
      return ArraySize(separators);
     }
  };

#endif
