//+------------------------------------------------------------------+
//| PeriodSeparatorTypes.mqh                                         |
//+------------------------------------------------------------------+
#ifndef PERIOD_SEPARATOR_TYPES_MQH
#define PERIOD_SEPARATOR_TYPES_MQH

#define TF_DAILY   (OBJ_PERIOD_M1|OBJ_PERIOD_M2|OBJ_PERIOD_M3|OBJ_PERIOD_M4|OBJ_PERIOD_M5|OBJ_PERIOD_M6|OBJ_PERIOD_M10|OBJ_PERIOD_M12|OBJ_PERIOD_M15|OBJ_PERIOD_M20|OBJ_PERIOD_M30|OBJ_PERIOD_H1|OBJ_PERIOD_H2)
#define TF_H3PLUS  (OBJ_PERIOD_H3|OBJ_PERIOD_H4|OBJ_PERIOD_H6|OBJ_PERIOD_H8|OBJ_PERIOD_H12)
#define TF_MONTHLY (OBJ_PERIOD_D1)
#define TF_YEARLY  (OBJ_PERIOD_W1|OBJ_PERIOD_MN1)

enum ENUM_PERIOD_SEPARATOR_MODE
  {
   PERIOD_SEPARATOR_NONE = 0,
   PERIOD_SEPARATOR_DAILY_NY,
   PERIOD_SEPARATOR_WEEKLY_SERVER,
   PERIOD_SEPARATOR_YEARLY_SERVER,
   PERIOD_SEPARATOR_TRIYEARLY_SERVER
  };

struct PeriodSeparatorStyle
  {
   color             line_color;
   ENUM_LINE_STYLE   line_style;
   int               line_width;
   bool              draw_in_background;
   bool              selectable;
   bool              hidden;
   bool              show_labels;
   color             label_color;
   string            label_font;
   int               label_font_size;
   double            label_top_percent;
  };

int PeriodMaskForTimeframe(const ENUM_TIMEFRAMES period)
  {
   switch(period)
     {
      case PERIOD_M1:  return OBJ_PERIOD_M1;
      case PERIOD_M2:  return OBJ_PERIOD_M2;
      case PERIOD_M3:  return OBJ_PERIOD_M3;
      case PERIOD_M4:  return OBJ_PERIOD_M4;
      case PERIOD_M5:  return OBJ_PERIOD_M5;
      case PERIOD_M6:  return OBJ_PERIOD_M6;
      case PERIOD_M10: return OBJ_PERIOD_M10;
      case PERIOD_M12: return OBJ_PERIOD_M12;
      case PERIOD_M15: return OBJ_PERIOD_M15;
      case PERIOD_M20: return OBJ_PERIOD_M20;
      case PERIOD_M30: return OBJ_PERIOD_M30;
      case PERIOD_H1:  return OBJ_PERIOD_H1;
      case PERIOD_H2:  return OBJ_PERIOD_H2;
      case PERIOD_H3:  return OBJ_PERIOD_H3;
      case PERIOD_H4:  return OBJ_PERIOD_H4;
      case PERIOD_H6:  return OBJ_PERIOD_H6;
      case PERIOD_H8:  return OBJ_PERIOD_H8;
      case PERIOD_H12: return OBJ_PERIOD_H12;
      case PERIOD_D1:  return OBJ_PERIOD_D1;
      case PERIOD_W1:  return OBJ_PERIOD_W1;
      case PERIOD_MN1: return OBJ_PERIOD_MN1;
     }

   return 0;
  }

ENUM_PERIOD_SEPARATOR_MODE SeparatorModeForTimeframe(const ENUM_TIMEFRAMES period)
  {
   const int mask = PeriodMaskForTimeframe(period);

   if((mask & TF_DAILY) != 0)
      return PERIOD_SEPARATOR_DAILY_NY;
   if((mask & TF_H3PLUS) != 0)
      return PERIOD_SEPARATOR_WEEKLY_SERVER;
   if((mask & TF_MONTHLY) != 0)
      return PERIOD_SEPARATOR_YEARLY_SERVER;
   if((mask & TF_YEARLY) != 0)
      return PERIOD_SEPARATOR_TRIYEARLY_SERVER;

   return PERIOD_SEPARATOR_NONE;
  }

int SeparatorVisibilityMask(const ENUM_PERIOD_SEPARATOR_MODE mode)
  {
   switch(mode)
     {
      case PERIOD_SEPARATOR_DAILY_NY:         return TF_DAILY;
      case PERIOD_SEPARATOR_WEEKLY_SERVER:   return TF_H3PLUS;
      case PERIOD_SEPARATOR_YEARLY_SERVER:   return TF_MONTHLY;
      case PERIOD_SEPARATOR_TRIYEARLY_SERVER:return TF_YEARLY;
     }

   return OBJ_ALL_PERIODS;
  }

string SeparatorModeName(const ENUM_PERIOD_SEPARATOR_MODE mode)
  {
   switch(mode)
     {
      case PERIOD_SEPARATOR_DAILY_NY:          return "DNY";
      case PERIOD_SEPARATOR_WEEKLY_SERVER:    return "WSRV";
      case PERIOD_SEPARATOR_YEARLY_SERVER:    return "YSRV";
      case PERIOD_SEPARATOR_TRIYEARLY_SERVER: return "TYSRV";
     }

   return "NONE";
  }

#endif
