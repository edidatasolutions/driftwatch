# Simulate a continuously administered item bank with known drift

Each window, every item is answered by a Poisson number of examinees
whose abilities are known from operational scoring (the population mean
may trend over time; this is not drift). Items are stable, drift
gradually (linear from an onset window) or jump abruptly at an onset
window.

## Usage

``` r
dw_simulate(
  n_items = 300,
  n_windows = 40,
  mean_n = 80,
  p_gradual = 0.1,
  p_abrupt = 0.05,
  slope_range = c(0.02, 0.06),
  jump_range = c(0.4, 1),
  onset_range = c(5, 30),
  theta_trend = 0.01,
  ref_se = 0.05,
  seed = NULL
)
```

## Arguments

- n_items, n_windows:

  Bank size and number of windows.

- mean_n:

  Mean responses per item per window.

- p_gradual, p_abrupt:

  Share of items with each drift type.

- slope_range:

  Absolute gradual slope per window (logits).

- jump_range:

  Absolute abrupt jump (logits).

- onset_range:

  Windows in which drift can begin.

- theta_trend:

  Change in examinee mean ability per window.

- ref_se:

  Standard error of the banked (reference) difficulties.

- seed:

  Optional seed.

## Value

A \`dw_sim\`: \`\$responses\` (\`window\`, \`item\`, \`theta\`, \`x\`),
\`\$bank\` (\`item\`, \`b\`, \`se\`), \`\$truth\` (\`item\`, \`type\`,
\`onset\`, \`size\`, \`b_true_final\`) and \`\$b_path\` (items x windows
matrix of true difficulty).

## Examples

``` r
sim <- dw_simulate(n_items = 60, n_windows = 20, mean_n = 60,
                   onset_range = c(5, 12), seed = 1)
table(sim$truth$type)
#> 
#>  abrupt gradual  stable 
#>       2       7      51 
```
