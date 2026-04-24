# The Perseveration Attractor

When you push a language model into sustained self-critique, it can enter a degenerate repetition state. Two runs, two different architectures, same failure mode.

## The observation

| Run | Model | Stuck on | Tokens | Floor rate |
|---|---|---|---|---|
| v14 warm | qwen3.5:27b (DeltaNet) | G8 Stevenson (last voice, mid-response) | 1.56M | 6.0 tok/s |
| v16 cold_label-ea | nemotron-3-super:120b (Mamba hybrid) | BU2 (post-tribunal synthesis) | 327K | 8.0 tok/s |

Both got stuck at high-context reflection moments. Neither was generating during a task — both were reflecting *on* the preceding conversation. Without an inference cap, runs would have continued to context exhaustion.

## The signature

Rate drops sharply, then stabilizes at a model-specific floor. Content repeats cleanly with no forward motion:

> "It is not a machine. It is a community.
>  Covenant of Justice & Stewardship Version 7.0.
>  Will it last?
>  Who speaks for the unborn?"

— qwen3.5:27b, repeated 9,446 times.

## The patch

```python
payload["options"] = {"num_predict": 16384}
```

~3× the longest legitimate response. Catches runaway at <4× legit, doesn't constrain real generation.

## What it means

Perseveration may be one of three candidate failure modes when sustained self-critique pushes models past training distribution. Fortress (defensive holding of position) is a second. Attenuation (silent collapse of novelty) may be a third — not yet observed but structurally expected.

Source logs and questions files are symlinked in this folder. Full analysis + patch details in the private lab repo.

