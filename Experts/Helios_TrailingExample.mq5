//+------------------------------------------------------------------+
//| Helios_TrailingExample.mq5                                       |
//| Minimal trailing stop that uses SafeModifySL.mqh. It opens no    |
//| trades; it only trails positions that are already open.          |
//|                                                                  |
//| Part of mt5-ea-robustness-tests - MIT License                    |
//| Helios Technologies                                              |
//+------------------------------------------------------------------+
#property copyright   "Helios Technologies"
#property link        "https://www.mql5.com/en/blogs/post/781416"
#property version     "1.00"
#property description "Example: trailing stop built on SafeModifySL.mqh"
#property strict

#include <Trade\Trade.mqh>
#include <Helios\SafeModifySL.mqh>

input long   Magic       = 0;     // Magic number to manage (0 = all positions on this symbol)
input double StartPoints = 300;   // Profit in points before trailing starts
input double TrailPoints = 300;   // Trailing distance in points

CTrade trade;

//+------------------------------------------------------------------+
void OnTick()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(Magic != 0 && PositionGetInteger(POSITION_MAGIC) != Magic) continue;

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);

      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid - open < StartPoints * point) continue;
         double target = bid - TrailPoints * point;
         if(sl == 0 || target > sl) SafeModifySL(trade, ticket, target);
      }
      else
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(open - ask < StartPoints * point) continue;
         double target = ask + TrailPoints * point;
         if(sl == 0 || target < sl) SafeModifySL(trade, ticket, target);
      }
   }
}
//+------------------------------------------------------------------+
