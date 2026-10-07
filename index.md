# driftwatch

[![CRAN
status](https://www.r-pkg.org/badges/version/driftwatch)](https://CRAN.R-project.org/package=driftwatch)

**Not “did it drift?” but “when, how, and what should we do?”**

Most drift checks compare two calibrations at equating time. Continuous
testing programs and pre-equated banks need ongoing surveillance.
driftwatch borrows sequential change detection from statistical process
control.

``` r

library(driftwatch)

sim <- dw_simulate(seed = 1)                         # or your responses + bank
est <- dw_estimate(sim$responses, sim$bank)          # item x window estimates
tu  <- dw_tune(est, target = 0.01)                   # threshold for 1% false alarms/item
mon <- dw_monitor(est, h = tu$h)                     # CUSUM + change points + type
mon
dw_actions(mon, anchors = my_anchor_ids)             # recommendations + audit log
dw_impact(form_ids, sim$bank, current_b, flagged)    # score / pass-rate impact
```

## Installation

From CRAN:

``` r

install.packages("driftwatch")
```

Development version from GitHub:

``` r

install.packages("pak")
pak::pak("edidatasolutions/driftwatch")
```

## How it works

1.  **Window estimates.** Rasch difficulty per item per window, with
    examinee ability known from operational scoring. Standardized
    deviation from the bank:
    `z = (b_t - b_bank) / sqrt(SE_t^2 + SE_bank^2)`.
2.  **Two-sided CUSUM** on `z` (reference value `k`, threshold `h`).
3.  **Threshold tuning on your own design.**
    [`dw_tune()`](https://edidatasolutions.github.io/driftwatch/reference/dw_tune.md)
    regenerates responses under no drift for the program’s actual items,
    windows, sample sizes and examinees, then reruns estimation and
    CUSUM. This matters: each item’s bank error is shared by every
    window and accumulates in the CUSUM. The design-based threshold (h ≈
    9.5) is far above the iid-normal one (≈ 6.9), and only the former
    meets the false-alarm target.
4.  **Gradual vs abrupt.** Step and ramp models are fitted with a
    profiled change point, and the log likelihood ratio decides between
    them. With weak evidence the type is `undetermined` rather than
    guessed.
5.  **Impact and action.** True-score scoring impact of keeping,
    removing or recalibrating flagged items. Actions are retire,
    recalibrate or remove from the anchor set, each with a written
    rationale, threshold settings, analyst and timestamp.

## Validation (known truth, 100 replications)

300 items, 40 windows, ~80 responses per item per window. 10% of items
drift gradually (0.02–0.06 logits/window) and 5% jump (0.4–1.0 logits).

|  | continuous (driftwatch) | two-point (first vs last 5 windows) |
|----|----|----|
| false alarms, stable items (target 1%) | 0.86% (iid-normal threshold: 4.0%) | 0.27% |
| abrupt detected | 99%, median 4.1 windows after onset | 72%, at the end |
| gradual detected | 83%, median 12.5 windows after onset | 73%, at the end |
| abrupt onset error (windows) | 1.1 | — |

Drift-type classification:

| data used         | abrupt: typed / accuracy | gradual: typed / accuracy |
|-------------------|--------------------------|---------------------------|
| alarm + 3 windows | 78% / 94%                | 51% / 65%                 |
| all 40 windows    | 94% / 99%                | 78% / 89%                 |

Gradual drift is hard to type soon after an alarm, because a short ramp
looks like a step. Reclassify as windows accumulate.

Score impact (60-item form with 12 drifted items, cut at theta = 0.5):
keeping banked values mis-states the pass rate by -0.8 points; removing
or recalibrating the flagged items brings the error to about 0 (within
±0.01 points).

## Status and assumptions

Done: `dw_simulate`, `dw_estimate`, `dw_tune`, `dw_monitor`,
`dw_impact`, `dw_actions`, `dw_twopoint`. Rasch difficulty only;
examinee ability treated as known. Next: 2PL discrimination drift,
ability uncertainty, anchor-set re-linking after removals, and a
per-item run-length (ARL) view.

## Getting help and contributing

Questions and bug reports:
<https://github.com/edidatasolutions/driftwatch/issues>. See
[CONTRIBUTING.md](https://edidatasolutions.github.io/driftwatch/CONTRIBUTING.md)
for how to report problems, get help, or contribute code.
