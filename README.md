# MT5 EA robustness tests

Free MQL5 tools that check whether an Expert Advisor really reads price or has only memorised one market trend. The repo also includes a small helper that fixes the stop-modification errors that make EAs fail the MQL5 Market automatic validation.

Built by Helios Technologies while testing our gold EA, [GoldRush Pro Xauusd](https://www.mql5.com/en/market/product/209961). The full method is written up on the MQL5 blog: [Mirror Test for Gold EAs](https://www.mql5.com/en/blogs/post/781416).

## What's inside

| File | What it does |
|---|---|
| `Scripts/Helios_MirrorBuilder.mq5` | Builds `XAUUSD_MIRROR`, the real tick history flipped upside down around a pivot |
| `Scripts/Helios_DateShiftBuilder.mq5` | Builds `XAUUSD_COPY` (control) and `XAUUSD_SHIFT` (the same ticks with dates moved 364 days) |
| `Include/Helios/SafeModifySL.mqh` | Modifies SL/TP only when the broker will accept it, avoiding "Invalid stops" and "Frozen" errors |
| `Experts/Helios_TrailingExample.mq5` | A short trailing-stop EA showing how to use `SafeModifySL` |

All defaults use XAUUSD, but the scripts work on any symbol your broker provides real tick history for.

## Install

1. In MetaTrader 5, open **File → Open Data Folder**, then the `MQL5` folder.
2. Copy the `Scripts`, `Include` and `Experts` folders from this repo into it, merging with the existing folders.
3. In MetaEditor, open each `.mq5` file and press **Compile** (F7).

## Test 1: the mirror test

Gold climbed almost without a break through 2024 and 2025, set a record near 5,600 USD in January 2026, then fell about 30%. Many gold EAs were built and backtested during that rally. An EA that mostly buys looks brilliant on a rising chart without knowing anything about the market, and it struggles when the trend turns.

The mirror test turns the chart upside down:

```
mirrored price = 2 × pivot − real price
```

Every rally becomes a sell-off of exactly the same size and speed. Volatility, gaps, timing and spread stay identical, because bid and ask swap places. It produces a chart that never existed. A robust EA trades it the other way round and gets a broadly similar result. An EA fitted to the uptrend falls apart.

**Steps**

1. Run `Helios_DateShiftBuilder` first. It creates `XAUUSD_COPY`, the control, so every run uses a custom symbol with the same contract settings.
2. Run `Helios_MirrorBuilder`. Set `From`/`To` and a `Pivot` above half of the highest price in your period. For gold up to 5,600, any pivot above 2,800 works; 3,500 is the default. The script stops and tells you if the pivot is too low.
3. In the Strategy Tester, use the same EA, inputs, deposit, dates and **Every tick based on real ticks**. Run once on `XAUUSD_COPY` and once on `XAUUSD_MIRROR`.
4. Switch off any filter that reads another symbol, such as a US dollar filter on EURUSD. That symbol is not mirrored, so the filter would fight the flipped chart.

**How to read it**

- **Robust:** profit factor stays above 1 in both directions, and the number of trades, win rate and drawdown stay in the same range.
- **Red flags:** the profit factor drops below 1 on the mirror, the trade count changes a lot (rules tied to fixed price levels), or the EA barely trades the flipped direction.

## Test 2: the date-shift test

`XAUUSD_SHIFT` holds the same real prices with every timestamp moved by `ShiftDays`. The default is −364 days, 52 full weeks, so weekdays still line up. Run the tester on it with your test dates moved by the same amount; for example, 2025.01.01–2026.11.01 becomes 2024.01.03–2025.11.02.

- **Robust:** the result is practically identical to `XAUUSD_COPY`.
- **Red flag:** a big difference means the EA reacts to the calendar (hard-coded dates, seasonal or month rules) rather than to price. Small differences are normal, because daylight-saving changes and holidays fall on different days.

## Example: GoldRush Pro Xauusd

GoldRush Pro Xauusd v12.3, Balanced preset, 15,000 USD deposit, XAUUSD H4, every tick based on real ticks, 1 Jan 2025 to 20 Nov 2026. The US dollar filter was off in every run.

| | Real gold | Mirrored gold | Dates shifted 364 days |
|---|---|---|---|
| Final balance (USD) | 21,779 | 26,257 | 21,914 |
| Profit factor | 1.49 | 1.70 | 1.50 |
| Positions | 282 | 291 | 283 |
| Win rate | 49.6% | 51.2% | 49.8% |
| Worst equity drawdown | 10.90% | 9.96% | 10.90% |

The mirrored run made more money, but that isn't the point. A mirrored chart is a different market, and this sequence of swings happened to suit the EA. What matters is that the profit factor stayed above 1 both ways, while trade count, win rate and drawdown barely moved. The date-shifted run was practically identical to the real one.

*Backtest results, not live trading. Past results do not guarantee future results.*

## What these tests don't prove

Passing removes two common failures: an EA that only works because the market went one way, and one tied to the calendar. Passing doesn't prove future profit. Before trusting any EA, also check:

- **Costs:** add extra slippage or commission and see if it survives.
- **Drawdown spread:** run a Monte Carlo resample of the trade list.
- **Minimum-lot risk:** whether the broker's minimum lot risks too much on your account size.
- **Forward results:** a live or forward-tested track record.

## SafeModifySL: fixing "Invalid stops" and "Frozen" validation errors

The MQL5 Market tests every EA automatically before it can be published. Trailing-stop and break-even code that sends a modification on every tick often produces:

- **`Invalid stops`:** the new stop is closer to the market than the stops level, or equals the current stop after rounding
- **`No changes in request`:** nothing actually changed
- **`Modification failed due to order or position being close to market`** (`TRADE_RETCODE_FROZEN`): the current SL or TP is inside the freeze level

GoldRush failed validation with 21 of these errors. After switching to this helper, the same EA passed with 0 errors.

`SafeModifySL`:

- rounds the new levels to the symbol's tick size;
- skips the request when nothing changes;
- respects the stops level and freeze level;
- returns `false` without sending anything when the broker would reject the request.

```mql5
#include <Trade\Trade.mqh>
#include <Helios\SafeModifySL.mqh>

CTrade trade;

// move the stop, keep the take profit
SafeModifySL(trade, ticket, newSL);

// change both (0 removes a level, -1 keeps the current one)
SafeModifySL(trade, ticket, newSL, newTP);
```

See `Experts/Helios_TrailingExample.mq5` for a complete trailing stop.

## About

Helios Technologies builds and tests trading robots for MetaTrader 5. Check before you trust.

- [GoldRush Pro Xauusd on the MQL5 Market](https://www.mql5.com/en/market/product/209961)
- [Mirror test write-up on the MQL5 blog](https://www.mql5.com/en/blogs/post/781416)
- [MQL5 profile](https://www.mql5.com/en/users/jonathan254)
- [Telegram, TikTok and more](https://linktr.ee/Helios)

Issues and pull requests are welcome, for example results from other symbols or brokers.

## Disclaimer

These are educational tools, not financial advice. Trading on margin carries a high level of risk, and backtests do not guarantee future results.

## License

[MIT](LICENSE)
