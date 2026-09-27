# Continuous drift monitoring for an item bank

Most drift checks compare two calibrations at equating time. driftwatch
monitors every calibration window and asks *when* an item started
drifting, *how* (gradual trend or abrupt jump), and *what to do about
it*.

## Data

A bank of 120 items is administered over 30 windows. In the simulation,
some items drift gradually and some jump abruptly.

``` r

library(driftwatch)
sim <- dw_simulate(n_items = 120, n_windows = 30, mean_n = 70,
                   onset_range = c(5, 18), seed = 7)
table(sim$truth$type)
#> 
#>  abrupt gradual  stable 
#>       1      12     107
```

## Window estimates

``` r

est <- dw_estimate(sim$responses, sim$bank)
round(est$z[1:4, 1:8], 2)
#>           1     2     3     4    5    6     7     8
#> I0001 -0.10  1.28 -0.64 -0.57 1.30 0.58 -0.14  0.60
#> I0002  0.93 -0.26 -0.54  0.54 1.06 1.11 -0.84 -0.60
#> I0003  0.38 -0.17 -0.88  0.00 0.38 1.13 -0.31  1.55
#> I0004  1.01  0.21  0.90 -0.73 0.50 0.45 -1.03 -0.22
```

## Set the alarm threshold for your bank

[`dw_tune()`](https://edidatasolutions.github.io/driftwatch/reference/dw_tune.md)
regenerates your own design under no drift and picks the CUSUM threshold
that gives the target false-alarm probability per item over the horizon.

``` r

tu <- dw_tune(est, target = 0.02, n_rep = 4, seed = 1)
tu$h
#> [1] 7.04806
```

## Monitor

``` r

mon <- dw_monitor(est, h = tu$h)
mon
#> <dw_monitor> 120 items | 30 windows | h = 7.048 | k = 0.5 
#> 13 alarms: 2 abrupt, 3 gradual, 8 undetermined
#> 
#>   item alarm alarm_window direction change_point cusum_change_point
#>  I0011  TRUE           18    harder           10                 10
#>  I0082  TRUE           18    harder           10                 13
#>  I0115  TRUE           22    harder            2                  5
#>  I0092  TRUE           25    harder           15                 15
#>  I0029  TRUE           27    harder           10                 14
#>  I0063  TRUE           27    easier           16                 17
#>  I0090  TRUE           28    harder           20                 17
#>  I0105  TRUE           28    harder           18                 18
#>  I0003  TRUE           29    harder           20                 21
#>  I0036  TRUE           29    easier           20                 20
#>  I0061  TRUE           29    easier            6                  6
#>  I0086  TRUE           29    harder            6                 15
#>  I0089  TRUE           30    easier           10                 17
#>          type type_log_lr magnitude    rate
#>        abrupt      1.1122     0.429      NA
#>  undetermined      0.7529     0.965  0.0804
#>  undetermined      0.5219     0.554  0.0231
#>       gradual      2.1497     0.771  0.0550
#>  undetermined      0.0434     0.479  0.0228
#>       gradual      1.5131    -0.662 -0.0441
#>  undetermined      0.7580     0.321      NA
#>        abrupt      1.6238     0.322      NA
#>       gradual      1.5209     0.751  0.0683
#>  undetermined      0.2021    -0.398      NA
#>  undetermined      0.8107    -0.226      NA
#>  undetermined      0.2332     0.420  0.0168
#>  undetermined      0.6948    -0.533 -0.0254
table(alarm = mon$items$alarm, truth = sim$truth$type)
#>        truth
#> alarm   abrupt gradual stable
#>   FALSE      0       2    105
#>   TRUE       1      10      2
```

Soon after an alarm, a short ramp can look like a step; such items are
marked `undetermined` until more windows arrive.

## Act, and record why

``` r

log <- dw_actions(mon, anchors = sim$bank$item[1:20], analyst = "psychometrics")
head(log[c("item", "alarm_window", "type", "magnitude", "action")])
#>    item alarm_window         type magnitude
#> 1 I0003           29      gradual     0.751
#> 2 I0011           18       abrupt     0.429
#> 3 I0029           27 undetermined     0.479
#> 4 I0036           29 undetermined    -0.398
#> 5 I0061           29 undetermined    -0.226
#> 6 I0063           27      gradual    -0.662
#>                                 action
#> 1 recalibrate + remove from anchor set
#> 2 recalibrate + remove from anchor set
#> 3                          recalibrate
#> 4                          recalibrate
#> 5                          recalibrate
#> 6                          recalibrate
```

## What does drift do to scores?

``` r

flagged <- mon$items$item[mon$items$alarm]
drifted <- sim$truth$item[sim$truth$type != "stable"]
form <- c(head(drifted, 8), head(setdiff(sim$bank$item, drifted), 32))
last <- est$b_hat[, ncol(est$b_hat)]
dw_impact(form, sim$bank, sim$b_path[, ncol(sim$b_path)], flagged,
          recalibrated = last[flagged], cut = 0.5)
#>      scenario n_items  bias_at_cut mean_abs_bias pass_rate pass_rate_error
#> 1        keep      40 -0.045402190   0.038222856 0.2926962   -0.0158413074
#> 2      remove      34 -0.009231614   0.008099270 0.3052879   -0.0032495925
#> 3 recalibrate      40  0.001075524   0.002991237 0.3089148    0.0003772897
```
