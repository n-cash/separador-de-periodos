//+------------------------------------------------------------------+
//| PeriodSeparatorRenderer.mqh                                      |
//+------------------------------------------------------------------+
#ifndef PERIOD_SEPARATOR_RENDERER_MQH
#define PERIOD_SEPARATOR_RENDERER_MQH

#include "PeriodSeparatorTypes.mqh"

class CPeriodSeparatorRenderer
  {
private:
   long                 m_chart_id;
   string               m_prefix;
   PeriodSeparatorStyle m_style;
   int                  m_timeframe_mask;

   bool IsExpected(const string name,string &expected_names[])
     {
      const int total = ArraySize(expected_names);
      for(int i=0;i<total;i++)
        {
         if(expected_names[i] == name)
            return true;
        }
      return false;
     }

   void AppendName(string &items[],const string value)
     {
      const int size = ArraySize(items);
      ArrayResize(items,size+1);
      items[size] = value;
     }

public:
   CPeriodSeparatorRenderer(void)
     {
      m_chart_id = 0;
      m_prefix = "NYPS_";
      m_timeframe_mask = OBJ_ALL_PERIODS;
      ZeroMemory(m_style);
      m_style.line_color = clrSilver;
      m_style.line_style = STYLE_DOT;
      m_style.line_width = 1;
      m_style.draw_in_background = true;
      m_style.selectable = false;
      m_style.hidden = true;
      m_style.show_labels = true;
      m_style.label_color = clrSilver;
      m_style.label_font = "Arial";
      m_style.label_font_size = 8;
      m_style.label_top_percent = 5.0;
     }

   void Configure(const long chart_id,
                  const string prefix,
                  const PeriodSeparatorStyle &style,
                  const int timeframe_mask)
     {
      m_chart_id = chart_id;
      m_prefix = prefix;
      m_style = style;
      m_timeframe_mask = timeframe_mask;
     }

   string BuildObjectName(const string mode_name,const datetime time_value)
     {
      return m_prefix + mode_name + "_" + IntegerToString((long)time_value);
     }

   string BuildLabelName(const string mode_name,const datetime time_value)
     {
      return m_prefix + mode_name + "_LBL_" + IntegerToString((long)time_value);
     }

   double LabelPrice(void)
     {
      double price_max = 0.0;
      double price_min = 0.0;
      if(!ChartGetDouble(m_chart_id,CHART_PRICE_MAX,0,price_max) ||
         !ChartGetDouble(m_chart_id,CHART_PRICE_MIN,0,price_min) ||
         price_max <= price_min)
         return 0.0;

      const double pct = MathMax(0.0,MathMin(100.0,m_style.label_top_percent));
      return price_max - ((price_max - price_min) * pct / 100.0);
     }

   bool DrawLine(const string name,const datetime time_value)
     {
      if(ObjectFind(m_chart_id,name) < 0)
        {
         if(!ObjectCreate(m_chart_id,name,OBJ_VLINE,0,time_value,0.0))
            return false;
        }
      else
        {
         ObjectMove(m_chart_id,name,0,time_value,0.0);
        }

      ObjectSetInteger(m_chart_id,name,OBJPROP_COLOR,m_style.line_color);
      ObjectSetInteger(m_chart_id,name,OBJPROP_STYLE,m_style.line_style);
      ObjectSetInteger(m_chart_id,name,OBJPROP_WIDTH,m_style.line_width);
      ObjectSetInteger(m_chart_id,name,OBJPROP_BACK,m_style.draw_in_background);
      ObjectSetInteger(m_chart_id,name,OBJPROP_SELECTABLE,m_style.selectable);
      ObjectSetInteger(m_chart_id,name,OBJPROP_SELECTED,false);
      ObjectSetInteger(m_chart_id,name,OBJPROP_HIDDEN,m_style.hidden);
      ObjectSetInteger(m_chart_id,name,OBJPROP_TIMEFRAMES,m_timeframe_mask);
      return true;
     }

   bool DrawLabel(const string name,const datetime time_value,const double price,const string text)
     {
      if(text == "" || price <= 0.0)
         return false;

      if(ObjectFind(m_chart_id,name) < 0)
        {
         if(!ObjectCreate(m_chart_id,name,OBJ_TEXT,0,time_value,price))
            return false;
        }
      else
        {
         ObjectMove(m_chart_id,name,0,time_value,price);
        }

      ObjectSetString(m_chart_id,name,OBJPROP_TEXT,text);
      ObjectSetString(m_chart_id,name,OBJPROP_FONT,m_style.label_font);
      ObjectSetInteger(m_chart_id,name,OBJPROP_FONTSIZE,m_style.label_font_size);
      ObjectSetInteger(m_chart_id,name,OBJPROP_COLOR,m_style.label_color);
      ObjectSetInteger(m_chart_id,name,OBJPROP_ANCHOR,ANCHOR_CENTER);
      ObjectSetInteger(m_chart_id,name,OBJPROP_BACK,m_style.draw_in_background);
      ObjectSetInteger(m_chart_id,name,OBJPROP_SELECTABLE,m_style.selectable);
      ObjectSetInteger(m_chart_id,name,OBJPROP_SELECTED,false);
      ObjectSetInteger(m_chart_id,name,OBJPROP_HIDDEN,m_style.hidden);
      ObjectSetInteger(m_chart_id,name,OBJPROP_TIMEFRAMES,m_timeframe_mask);
      return true;
     }

   int Render(const string mode_name,datetime &times[],string &labels[],const bool delete_obsolete)
     {
      string expected[];
      int rendered = 0;
      const int total = ArraySize(times);
      const double label_price = LabelPrice();

      for(int i=0;i<total;i++)
        {
         const string name = BuildObjectName(mode_name,times[i]);
         AppendName(expected,name);
         if(DrawLine(name,times[i]))
            rendered++;

         if(m_style.show_labels)
           {
            if(i < ArraySize(labels) && labels[i] != "")
              {
               const string label_name = BuildLabelName(mode_name,times[i]);
               AppendName(expected,label_name);
               DrawLabel(label_name,times[i],label_price,labels[i]);
              }
           }
        }

      if(delete_obsolete)
         DeleteObsolete(expected);
      ChartRedraw(m_chart_id);
      return rendered;
     }

   int DeleteObsolete(string &expected_names[])
     {
      int deleted = 0;
      for(int i=ObjectsTotal(m_chart_id,0,-1)-1;i>=0;i--)
        {
         const string name = ::ObjectName(m_chart_id,i,0,-1);
         if(StringFind(name,m_prefix) != 0)
            continue;
         if(IsExpected(name,expected_names))
            continue;

         if(ObjectDelete(m_chart_id,name))
            deleted++;
        }
      return deleted;
     }

   int DeleteAll(void)
     {
      int deleted = 0;
      for(int i=ObjectsTotal(m_chart_id,0,-1)-1;i>=0;i--)
        {
         const string name = ::ObjectName(m_chart_id,i,0,-1);
         if(StringFind(name,m_prefix) == 0 && ObjectDelete(m_chart_id,name))
            deleted++;
        }

      ChartRedraw(m_chart_id);
      return deleted;
     }
  };

#endif
