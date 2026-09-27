# Sequential drift monitoring

Runs a two-sided CUSUM on each item's standardized deviations \`z_t =
(b_t - b_bank) / SE\`: \`S+\[t\] = max(0, S+\[t-1\] + z\[t\] - k)\` and
likewise downward. An alarm is raised the first window either statistic
exceeds \`h\`. Drift type is then classified by comparing step and ramp
fits to the difficulty series (profiling the change point), using data
up to \`followup\` windows after the alarm. \`change_point\` is the
onset under the better-fitting model; \`cusum_change_point\` is the
standard CUSUM estimator (the window after the statistic last left
zero), which locates abrupt changes well but lags gradual onsets.

## Usage

``` r
dw_monitor(estimates, h, k = 0.5, followup = 3, min_log_lr = 1)
```

## Arguments

- estimates:

  A \`dw_estimates\` object.

- h:

  Alarm threshold, ideally from \[dw_tune()\].

- k:

  Reference value (half the shift, in SE units, the chart is tuned to
  detect).

- followup:

  Windows after the alarm used to classify the change (\`Inf\` = all
  data to date).

- min_log_lr:

  Minimum log likelihood ratio between the step and ramp models for a
  type to be assigned; weaker evidence gives \`"undetermined"\`. Soon
  after an alarm a ramp and a step often cannot be told apart; rerun
  with more windows to resolve them.

## Value

A \`dw_monitor\` object; \`\$items\` has one row per item: \`alarm\`
(logical), \`alarm_window\`, \`direction\` (\`harder\` / \`easier\`),
\`change_point\`, \`type\` (\`abrupt\` / \`gradual\` /
\`undetermined\`), \`type_log_lr\` (evidence for the better model),
\`magnitude\` (current displacement under the better model, logits),
\`rate\` (logits per window, gradual only).

## Examples

``` r
sim <- dw_simulate(n_items = 60, n_windows = 20, mean_n = 60,
                   onset_range = c(5, 12), seed = 1)
est <- dw_estimate(sim$responses, sim$bank)
mon <- dw_monitor(est, h = 8)
mon
#> <dw_monitor> 60 items | 20 windows | h = 8 | k = 0.5 
#> 3 alarms: 1 abrupt, 1 gradual, 1 undetermined
#> 
#>   item alarm alarm_window direction change_point cusum_change_point
#>  I0001  TRUE           14    harder            6                  6
#>  I0019  TRUE           15    easier           11                 11
#>  I0045  TRUE           17    harder            7                  9
#>          type type_log_lr magnitude   rate
#>  undetermined       0.596     0.429     NA
#>        abrupt       3.756    -0.609     NA
#>       gradual       3.679     0.978 0.0699
table(alarm = mon$items$alarm, truth = sim$truth$type)
#>        truth
#> alarm   abrupt gradual stable
#>   FALSE      0       6     51
#>   TRUE       2       1      0
```
