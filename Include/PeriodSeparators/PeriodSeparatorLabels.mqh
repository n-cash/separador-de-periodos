//+------------------------------------------------------------------+
//| PeriodSeparatorLabels.mqh                                        |
//+------------------------------------------------------------------+
#ifndef PERIOD_SEPARATOR_LABELS_MQH
#define PERIOD_SEPARATOR_LABELS_MQH

#include <TimeZoneInfo.mqh>
#include "PeriodSeparatorTypes.mqh"

class CPeriodSeparatorLabels
  {
private:
   static string WeekdayName(const int day_of_week)
     {
      switch(day_of_week)
        {
         case 0: return "Dom";
         case 1: return "Lun";
         case 2: return "Mar";
         case 3: return "Mie";
         case 4: return "Jue";
         case 5: return "Vie";
         case 6: return "Sab";
        }

      return "";
     }

   static string MonthName(const int month)
     {
      switch(month)
        {
         case 1:  return "Ene";
         case 2:  return "Feb";
         case 3:  return "Mar";
         case 4:  return "Abr";
         case 5:  return "May";
         case 6:  return "Jun";
         case 7:  return "Jul";
         case 8:  return "Ago";
         case 9:  return "Sep";
         case 10: return "Oct";
         case 11: return "Nov";
         case 12: return "Dic";
        }

      return "";
     }

   static string TwoDigits(const int value)
     {
      if(value < 10)
         return "0" + IntegerToString(value);
      return IntegerToString(value);
     }

   static void Append(string &items[],const string value)
     {
      const int size = ArraySize(items);
      ArrayResize(items,size+1);
      items[size] = value;
     }

   static string LabelForTime(const ENUM_PERIOD_SEPARATOR_MODE mode,
                              const datetime broker_time,
                              const bool show_month_in_daily_labels)
     {
      datetime label_time = broker_time;
      if(mode == PERIOD_SEPARATOR_DAILY_NY)
         label_time = CTimeZoneInfo::ConvertTimeForPlace(broker_time,ZONE_ID_BROKER,ZONE_ID_NEWYORK);

      MqlDateTime dt;
      TimeToStruct(label_time,dt);

      switch(mode)
        {
         case PERIOD_SEPARATOR_DAILY_NY:
            if(show_month_in_daily_labels)
               return WeekdayName(dt.day_of_week) + " " + TwoDigits(dt.day) + " " + MonthName(dt.mon);
            return WeekdayName(dt.day_of_week);

         case PERIOD_SEPARATOR_WEEKLY_SERVER:
            return MonthName(dt.mon) + " " + TwoDigits(dt.day);

         case PERIOD_SEPARATOR_YEARLY_SERVER:
            return MonthName(dt.mon) + " " + IntegerToString(dt.year);

         case PERIOD_SEPARATOR_TRIYEARLY_SERVER:
            return IntegerToString(dt.year);
        }

      return "";
     }

public:
   static int Build(const ENUM_PERIOD_SEPARATOR_MODE mode,
                    datetime &times[],
                    const bool show_month_in_daily_labels,
                    string &labels[])
     {
      ArrayResize(labels,0);
      const int total = ArraySize(times);

      for(int i=0;i<total;i++)
         Append(labels,LabelForTime(mode,times[i],show_month_in_daily_labels));

      return ArraySize(labels);
     }
  };

#endif
