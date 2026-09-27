# Score and pass-rate impact of drifted items

For a pre-equated form scored by true-score conversion (the raw score is
mapped to theta through the test characteristic curve of the scoring
parameters), an examinee of ability theta is reported at
\`TCC_scoring^-1(TCC_current(theta))\`. The function compares scoring
scenarios against the current (true or best-estimate) difficulties:

- keep:

  Score with banked parameters for every item.

- remove:

  Drop flagged items from the form; score the rest with banked
  parameters.

- recalibrate:

  Score flagged items with their current estimates.

and reports reported-score bias at the cut and the pass rate in the
population against the correct pass rate.

## Usage

``` r
dw_impact(
  form,
  bank,
  current,
  flagged,
  recalibrated = NULL,
  cut = 0,
  theta_mean = 0,
  theta_sd = 1
)
```

## Arguments

- form:

  Item ids on the form.

- bank:

  Banked parameters (\`item\`, \`b\`).

- current:

  Named vector of current difficulties: the truth in a simulation, or
  the latest window estimates in practice.

- flagged:

  Item ids flagged by monitoring.

- recalibrated:

  Named vector of re-estimated difficulties for flagged items (default:
  \`current\[flagged\]\`).

- cut:

  Passing standard on the theta scale.

- theta_mean, theta_sd:

  Examinee population.

## Value

Data frame: \`scenario\`, \`n_items\`, \`bias_at_cut\`,
\`mean_abs_bias\`, \`pass_rate\`, \`pass_rate_error\` (vs the correct
rate).

## Examples

``` r
# A 20-item form where one item became 0.8 logits harder
current <- setNames(c(0.8, rep(0, 19)), paste0("q", 1:20))
bank <- data.frame(item = names(current), b = 0)
dw_impact(names(current), bank, current, flagged = "q1", cut = 0)
#>      scenario n_items   bias_at_cut mean_abs_bias pass_rate pass_rate_error
#> 1        keep      20 -3.799947e-02  3.890314e-02 0.4847387   -1.526130e-02
#> 2      remove      19  0.000000e+00  2.986416e-12 0.5000000    0.000000e+00
#> 3 recalibrate      20  1.906269e-13  3.052869e-12 0.5000000   -7.605028e-14
```
