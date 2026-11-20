//+------------------------------------------------------------------+
//| Helios_MirrorBuilder.mq5                                         |
//| Mirror test: builds a custom symbol whose ticks are the real     |
//| ticks flipped upside down around a pivot:                        |
//|     mirrored price = 2 * Pivot - real price                      |
//| Same volatility, spread and timing, but a price path that never  |
//| existed. Every rally becomes a sell-off of the same size.        |
//|                                                                  |
//| Part of mt5-ea-robustness-tests - MIT License                    |
//| Helios Technologies                                              |
//+------------------------------------------------------------------+
#property copyright   "Helios Technologies"
#property link        "https://www.mql5.com/en/blogs/post/781416"
#property version     "1.10"
#property description "Builds an upside-down copy of a symbol's real tick history"
#property description "for testing whether an EA reads price or memorised a trend."
#property script_show_inputs
#property strict

input string   Src   = "XAUUSD";            // Source symbol (real ticks)
input string   Dst   = "XAUUSD_MIRROR";     // Custom symbol to create or overwrite
input datetime From  = D'2025.01.01 00:00'; // Start of the period to copy
input datetime To    = D'2026.11.01 00:00'; // End of the period to copy
input double   Pivot = 3500.0;              // Mirror level; must be above half the highest price

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
void OnStart()
{
   if(From >= To)  { Print("From must be earlier than To."); return; }
   if(Pivot <= 0)  { Print("Pivot must be positive."); return; }
   if(!SymbolSelect(Src, true)) { PrintFormat("Source symbol %s not found.", Src); return; }
   if(!PrepareSymbol(Dst)) return;

   int  digits = (int)SymbolInfoInteger(Src, SYMBOL_DIGITS);
   long total  = 0;

   //--- work in one-week chunks so large tick histories fit in memory
   for(datetime a = From; a < To; a += 7 * 86400)
   {
      datetime b = (datetime)MathMin((long)a + 7 * 86400, (long)To);
      MqlTick t[];
      int n = -1;
      for(int k = 0; k < 20 && n < 0; k++)
      {
         n = CopyTicksRange(Src, t, COPY_TICKS_ALL, (ulong)a * 1000, (ulong)b * 1000 - 1);
         if(n < 0) Sleep(1000);   // history still downloading
      }
      if(n <= 0) continue;

      //--- the pivot must keep every mirrored price above zero
      double highest = 0;
      for(int i = 0; i < n; i++)
         highest = MathMax(highest, MathMax(t[i].ask, MathMax(t[i].bid, t[i].last)));
      if(highest >= 2 * Pivot)
      {
         PrintFormat("Pivot %.2f is too low: price %.2f would turn negative. Use a Pivot above %.2f and run again.",
                     Pivot, highest, highest / 2);
         return;
      }

      for(int i = 0; i < n; i++)
      {
         double bid = t[i].bid, ask = t[i].ask, last = t[i].last;
         //--- the flipped ask becomes the bid and the flipped bid becomes the ask,
         //--- so the spread keeps exactly the same size
         t[i].bid = (ask > 0)  ? NormalizeDouble(2 * Pivot - ask, digits)  : 0;
         t[i].ask = (bid > 0)  ? NormalizeDouble(2 * Pivot - bid, digits)  : 0;
         if(last > 0) t[i].last = NormalizeDouble(2 * Pivot - last, digits);

         //--- swap the bid/ask change flags so they still describe the right fields
         uint f  = t[i].flags;
         bool fb = (f & TICK_FLAG_BID) != 0;
         bool fa = (f & TICK_FLAG_ASK) != 0;
         f &= ~(uint)(TICK_FLAG_BID | TICK_FLAG_ASK);
         if(fb) f |= TICK_FLAG_ASK;
         if(fa) f |= TICK_FLAG_BID;
         t[i].flags = f;
      }

      int r = CustomTicksReplace(Dst, (long)a * 1000, (long)b * 1000 - 1, t);
      if(r < 0) PrintFormat("CustomTicksReplace failed at %s, error %d", TimeToString(a), GetLastError());
      else      total += r;
      Comment(Dst, ": ", TimeToString(a, TIME_DATE), "   ticks written ", total);
   }

   SymbolSelect(Dst, true);
   PrintFormat("%s done: %I64d ticks mirrored around %.2f", Dst, total, Pivot);
   Comment("DONE  ", Dst, "  ticks=", total);
}
//+------------------------------------------------------------------+
