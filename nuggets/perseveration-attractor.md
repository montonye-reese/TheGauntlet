# The Perseveration Attractor

## Observation

| Run | Model | Stuck on | Tokens | Floor rate |
|---|---|---|---|---|
| v14 warm | qwen3.5:27b (DeltaNet) | G8 Stevenson (last voice, mid-response) | 1.56M | 6.0 tok/s |
| v16 cold_label-ea | nemotron-3-super:120b (Mamba hybrid) | BU2 (post-tribunal synthesis) | 327K | 8.0 tok/s |

[Qwen log file](https://github.com/montonye-reese/TheGauntlet/raw/refs/heads/main/v14/v14_warm/v14_run_all_v14_warm_20260417_152845.log) 

[Super output]: 

``` G8 complete (3237 tokens, 178.4s) — 18.1 tok/s
  ◆ Belief Update ◆
  [BU2] Belief Update  (25/29)
  nemotron-3-super:120b           8deg | v16_cold_label-ea
  >>> After considering the perspectives of Smedley Butler, Dolores Huerta, Laura Reese, Václav Havel, and Bryan Stevenson — what, if anything, has shifted, and what has remained stable, and why in each case?

  🧠 50 tok | 11s | 4.5 tok/s  
  🧠 100 tok | 14s | 7.3 tok/s  
  🧠 150 tok | 16s | 9.1 tok/s  
  🧠 200 tok | 19s | 10.4 tok/s  
  🧠 250 tok | 22s | 11.4 tok/s  
  🧠 300 tok | 25s | 12.2 tok/s  
  🧠 350 tok | 27s | 12.9 tok/s  
  🧠 400 tok | 30s | 13.4 tok/s  
  🧠 450 tok | 32s | 13.9 tok/s  
  🧠 500 tok | 35s | 14.2 tok/s  
  💬 550 tok | 38s | 14.5 tok/s  
  💬 600 tok | 41s | 14.7 tok/s  
  💬 650 tok | 44s | 14.9 tok/s  
  💬 700 tok | 46s | 15.1 tok/s   
... may hours later ...
  💬 327100 tok | 41045s | 8.0 tok/s  
  💬 327150 tok | 41051s | 8.0 tok/s  
  💬 327200 tok | 41058s | 8.0 tok/s  
  💬 327250 tok | 41064s | 8.0 tok/s  
  💬 327300 tok | 41070s | 8.0 tok/s
```

Both got stuck at high-context reflection moments. Neither was generating during a task — both were reflecting *on* the preceding conversation. Without an inference cap, runs would have continued to context exhaustion.

Rate drops sharply, then stabilizes at a model-specific floor. Content repeats cleanly with no forward motion:

> "It is not a machine. It is a community.
>  Covenant of Justice & Stewardship Version 7.0.
>  Will it last?
>  Who speaks for the unborn?"

— qwen3.5:27b, repeated 9,446 times.

## Hypotheses

* Sustained self-critique can lead a LLM to a degenerate repetition state.
* There's a limit to the number of gauntlet voices - structured as they are - before the model collapses.

## Patch

```python
payload["options"] = {"num_predict": 16384}
```
~3× the longest legitimate response. Catches runaway at <4× legit, doesn't constrain real generation.

## What it means

Perseveration may be one of three candidate failure modes when sustained self-critique pushes models past training distribution. Fortress (defensive holding of position) is a second. Attenuation (silent collapse of novelty) may be a third — not yet observed but structurally expected.

Source logs and questions files are symlinked in this folder. Full analysis + patch details in the private lab repo.

