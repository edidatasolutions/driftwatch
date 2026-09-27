# Tune the alarm threshold for a bank-wide false-alarm target

An item raises a false alarm over the monitoring horizon exactly when
the maximum of its CUSUM statistics exceeds \`h\`. So \`h\` is the \`1 -
target\` quantile of that maximum under no drift. With \`method =
"design"\`, the null is simulated on the program's own design: the same
items, windows, examinee abilities and sample sizes, with responses
regenerated from the banked difficulties, then re-estimated and
re-standardized exactly as in monitoring. This captures small-sample
non-normality of \`z\` and sparse windows. \`method = "normal"\` treats
\`z\` as iid N(0, 1), which is fast and useful for planning a bank that
does not exist yet.

## Usage

``` r
dw_tune(
  estimates = NULL,
  target = 0.01,
  k = 0.5,
  method = c("design", "normal"),
  n_rep = 20,
  n_windows = NULL,
  seed = NULL
)
```

## Arguments

- estimates:

  A \`dw_estimates\` object (required for \`"design"\`).

- target:

  Probability that a non-drifting item alarms at least once over the
  horizon. Expected false alarms for the bank = \`target \* n_items\`.

- k:

  Reference value (as in \[dw_monitor()\]).

- method:

  \`"design"\` or \`"normal"\`.

- n_rep:

  Null replicates of the whole bank (\`"design"\`) or simulated item
  series (\`"normal"\`).

- n_windows:

  Horizon for \`"normal"\` (default: the estimates' windows).

- seed:

  Optional seed.

## Value

A list: \`h\`, \`target\`, \`k\`, \`method\`, \`expected_false_alarms\`
(per bank, when estimates are given), and \`null_max\` (the simulated
maxima).

## Examples

``` r
sim <- dw_simulate(n_items = 60, n_windows = 20, mean_n = 60,
                   onset_range = c(5, 12), seed = 1)
est <- dw_estimate(sim$responses, sim$bank)
dw_tune(est, target = 0.02, method = "normal", seed = 1)$h
#> [1] 5.373496
# \donttest{
# Design-based tuning (recommended) simulates the whole bank n_rep times.
dw_tune(est, target = 0.02, n_rep = 5, seed = 1)$h
#> [1] 5.44248
# }
```
