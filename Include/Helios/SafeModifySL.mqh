//+------------------------------------------------------------------+
//| SafeModifySL.mqh                                                 |
//| Stop-loss / take-profit modification that respects the broker's  |
//| limits, so trailing and break-even code stops producing the      |
//| errors that make EAs fail the MQL5 Market automatic validation:  |
//|   10016 TRADE_RETCODE_INVALID_STOPS  ("Invalid stops")           |
//|   10025 TRADE_RETCODE_NO_CHANGES     ("No changes in request")   |
//|   10029 TRADE_RETCODE_FROZEN         ("Modification failed due   |
//|         to order or position being close to market")             |
//|                                                                  |
//| Usage:                                                           |
//|   #include <Trade\Trade.mqh>                                     |
//|   #include <Helios\SafeModifySL.mqh>                             |
//|   CTrade trade;                                                  |
//|   SafeModifySL(trade, ticket, newSL);          // keep TP        |
//|   SafeModifySL(trade, ticket, newSL, newTP);   // change both    |
//|                                                                  |
//| Part of mt5-ea-robustness-tests - MIT License                    |
//| Helios Technologies                                              |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Round a price to the symbol's tick size                          |
//+------------------------------------------------------------------+
double HeliosNormalizePrice(const string symbol, const double price)
{
   double tick = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0) tick = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return NormalizeDouble(MathRound(price / tick) * tick, digits);
}

//+------------------------------------------------------------------+
//| Modify the SL (and optionally the TP) of an open position.       |
//|   newSL, newTP: a price, 0 = remove the stop, -1 = keep current. |
//| Returns false WITHOUT sending a request when the change would be |
//| rejected anyway: no real change after rounding, the new level is |
//| too close to the market (stops level), or the current SL/TP is   |
//| inside the freeze level. Otherwise returns the result of         |
//| CTrade::PositionModify (see ResultRetcode() for details).        |
//+------------------------------------------------------------------+
bool SafeModifySL(CTrade &trader, const ulong ticket, double newSL, double newTP = -1.0)
{
   if(!PositionSelectByTicket(ticket)) return false;

   string symbol = PositionGetString(POSITION_SYMBOL);
   bool   isBuy  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double curSL  = PositionGetDouble(POSITION_SL);
   double curTP  = PositionGetDouble(POSITION_TP);
   double point  = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tick   = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0) tick = point;

   if(newSL < 0) newSL = curSL;
   if(newTP < 0) newTP = curTP;
   if(newSL > 0) newSL = HeliosNormalizePrice(symbol, newSL);
   if(newTP > 0) newTP = HeliosNormalizePrice(symbol, newTP);

   //--- nothing really changes after rounding: skip ("No changes" / "Invalid stops")
   if(MathAbs(newSL - curSL) < tick * 0.5 && MathAbs(newTP - curTP) < tick * 0.5)
      return false;

   //--- a buy closes at Bid, a sell closes at Ask
   double price = isBuy ? SymbolInfoDouble(symbol, SYMBOL_BID)
                        : SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(price <= 0) return false;

   double stops  = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL)  * point;
   double freeze = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;

   //--- while the current SL or TP is inside the freeze level, the broker
   //--- accepts no modification at all ("Frozen")
   if(freeze > 0)
   {
      if(curSL > 0 && MathAbs(price - curSL) <= freeze) return false;
      if(curTP > 0 && MathAbs(price - curTP) <= freeze) return false;
   }

   //--- the new levels must keep the minimum distance from the market ("Invalid stops")
   double minDist = MathMax(stops, freeze) + point;
   if(isBuy)
   {
      if(newSL > 0 && price - newSL < minDist) return false;
      if(newTP > 0 && newTP - price < minDist) return false;
   }
   else
   {
      if(newSL > 0 && newSL - price < minDist) return false;
      if(newTP > 0 && price - newTP < minDist) return false;
   }

   return trader.PositionModify(ticket, newSL, newTP);
}
//+------------------------------------------------------------------+
