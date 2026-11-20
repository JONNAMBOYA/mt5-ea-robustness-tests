//+------------------------------------------------------------------+
//| Helios_DateShiftBuilder.mq5                                      |
//| Date-shift test: builds two custom symbols from real ticks:      |
//|   <Src>_COPY  = same ticks, same dates      (control)            |
//|   <Src>_SHIFT = same ticks, dates moved by ShiftDays             |
//| An EA that reads price trades both the same way. An EA that      |
//| depends on calendar dates, seasonal rules or hard-coded days     |
//| does not.                                                        |
//|                                                                  |
//| Part of mt5-ea-robustness-tests - MIT License                    |
//| Helios Technologies                                              |
//+------------------------------------------------------------------+
#property copyright   "Helios Technologies"
#property link        "https://www.mql5.com/en/blogs/post/781416"
#property version     "1.10"
#property description "Builds a control copy and a date-shifted copy of a symbol's real ticks"
#property description "for testing whether an EA reacts to price or to the calendar."
#property script_show_inputs
#property strict

input string   Src       = "XAUUSD";            // Source symbol (real ticks)
input string   DstCopy   = "XAUUSD_COPY";       // Control: same ticks, same dates
input string   DstShift  = "XAUUSD_SHIFT";      // Same ticks, dates moved
input datetime From      = D'2025.01.01 00:00'; // Start of the period to copy
input datetime To        = D'2026.11.01 00:00'; // End of the period to copy
input int      ShiftDays = -364;                // -364 = 52 weeks earlier, weekdays stay aligned

//+------------------------------------------------------------------+
//| Create the custom symbol, or reuse it if it is already custom    |
//+------------------------------------------------------------------+
bool PrepareSymbol(const string name)
{
   bool custom = false;
   if(SymbolExist(name, custom))
   {
      if(!custom)
      {
         PrintFormat("%s already exists and is not a custom symbol. Choose another name.", name);
         return false;
      }
      return true;
   }
   if(!CustomSymbolCreate(name, "Helios", Src))
   {
      PrintFormat("CustomSymbolCreate(%s) failed, error %d", name, GetLastError());
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Copy the ticks into `name`, moving every timestamp by shiftSec   |
//+------------------------------------------------------------------+
long Build(const string name, const long shiftSec)
{
   long total = 0;
   for(datetime a = From; a < To; a += 7 * 86400)
   {
      datetime b = (datetime)MathMin((long)a + 7 * 86400, (long)To);
      MqlTick t[];
      int n = -1;
      for(int tries = 0; tries < 20 && n < 0; tries++)
      {
         n = CopyTicksRange(Src, t, COPY_TICKS_ALL, (ulong)a * 1000, (ulong)b * 1000 - 1);
         if(n < 0) Sleep(1000);   // history still downloading
      }
      if(n <= 0) continue;

      for(int i = 0; i < n; i++)
      {
         t[i].time     += (datetime)shiftSec;
         t[i].time_msc += shiftSec * 1000;
      }

      int r = CustomTicksReplace(name, ((long)a + shiftSec) * 1000, ((long)b + shiftSec) * 1000 - 1, t);
      if(r < 0) PrintFormat("%s: CustomTicksReplace failed at %s, error %d", name, TimeToString(a), GetLastError());
      else      total += r;
      Comment(name, ": ", TimeToString(a, TIME_DATE), "   ticks written ", total);
   }
   SymbolSelect(name, true);
   return total;
}

//+------------------------------------------------------------------+
void OnStart()
{
   if(From >= To) { Print("From must be earlier than To."); return; }
   if(!SymbolSelect(Src, true)) { PrintFormat("Source symbol %s not found.", Src); return; }
   if(!PrepareSymbol(DstCopy) || !PrepareSymbol(DstShift)) return;

   long c = Build(DstCopy, 0);
   PrintFormat("%s done: %I64d ticks", DstCopy, c);

   long s = Build(DstShift, (long)ShiftDays * 86400);
   PrintFormat("%s done: %I64d ticks (dates moved %d days)", DstShift, s, ShiftDays);

   Comment("DONE  copy=", c, "  shift=", s);
}
//+------------------------------------------------------------------+
