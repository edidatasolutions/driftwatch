# Window-level item difficulty estimates

Rasch difficulty for every item x window, with examinee ability treated
as known (from operational scoring on the rest of the form). Estimation
is penalized maximum likelihood with a weak N(b_bank, \`prior_sd\`^2)
penalty that only matters for all-correct or all-incorrect windows.
Newton steps run for all item-windows at once.

## Usage

``` r
dw_estimate(responses, bank, prior_sd = 3)
```

## Arguments

- responses:

  Long data frame: \`window\` (integer), \`item\`, \`theta\`, \`x\`.

- bank:

  Reference parameters: \`item\`, \`b\`, and optionally \`se\`.

- prior_sd:

  SD of the weak penalty.

## Value

A \`dw_estimates\` object: matrices \`b_hat\`, \`se\`, \`n\` and \`z\`
(items x windows; \`z\` is the standardized deviation from the bank, NA
where an item was not administered), plus \`bank\` and \`responses\`.

## Examples

``` r
sim <- dw_simulate(n_items = 60, n_windows = 20, mean_n = 60,
                   onset_range = c(5, 12), seed = 1)
est <- dw_estimate(sim$responses, sim$bank)
round(est$z[1:5, 1:6], 2)
#>           1     2     3     4     5    6
#> I0001  1.55 -0.29 -0.04  0.86 -0.66 1.70
#> I0002  0.30 -0.10  0.43  0.00 -1.84 1.18
#> I0003 -1.92  1.88  0.36  1.00 -0.52 1.20
#> I0004  1.62  0.74  1.23  1.37 -2.28 0.05
#> I0005 -1.71  1.51 -0.09 -1.50  1.95 0.54
```
