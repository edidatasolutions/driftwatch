# Two-point drift check (the conventional baseline)

Pools the first and last blocks of windows, estimates each item's
difficulty in both, and flags items whose robust z of the difference
(median/MAD standardized) exceeds \`crit\`: the usual displacement check
at equating time.

## Usage

``` r
dw_twopoint(estimates, early = 1:5, late = NULL, crit = 2.7)
```

## Arguments

- estimates:

  A \`dw_estimates\` object.

- early, late:

  Window indices forming the two calibrations.

- crit:

  Robust-z criterion.

## Value

Data frame: \`item\`, \`d\`, \`robust_z\`, \`flag\`.

## Examples

``` r
sim <- dw_simulate(n_items = 60, n_windows = 20, mean_n = 60,
                   onset_range = c(5, 12), seed = 1)
tp <- dw_twopoint(dw_estimate(sim$responses, sim$bank))
table(flag = tp$flag, truth = sim$truth$type)
#>        truth
#> flag    abrupt gradual stable
#>   FALSE      2       6     51
#>   TRUE       0       1      0
```
