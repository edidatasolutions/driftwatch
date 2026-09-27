# Recommended actions and audit log

Turns monitoring alarms into recommended actions with a written
rationale:

- abrupt change of at least \`retire_at\` logits: \`retire\` (consistent
  with exposure/compromise or a key or rendering error; review the key,
  exposure counts and any content change before reuse);

- other abrupt changes, gradual drift and undetermined changes:
  \`recalibrate\` (undetermined ones should be reclassified later);

- any alarm on an anchor item: additionally \`remove from anchor set\`.

## Usage

``` r
dw_actions(
  monitor,
  anchors = character(0),
  retire_at = 0.5,
  analyst = NA_character_
)
```

## Arguments

- monitor:

  A \`dw_monitor\`.

- anchors:

  Item ids used as equating anchors.

- retire_at:

  Abrupt magnitude (logits) that triggers retirement.

- analyst:

  Name recorded in the log.

## Value

Audit-log data frame, one row per alarmed item.

## Examples

``` r
sim <- dw_simulate(n_items = 60, n_windows = 20, mean_n = 60,
                   onset_range = c(5, 12), seed = 1)
mon <- dw_monitor(dw_estimate(sim$responses, sim$bank), h = 8)
log <- dw_actions(mon, anchors = sim$bank$item[1:10], analyst = "DE")
if (nrow(log)) log[, c("item", "type", "magnitude", "action")]
#>    item         type magnitude                               action
#> 1 I0001 undetermined     0.429 recalibrate + remove from anchor set
#> 2 I0019       abrupt    -0.609                               retire
#> 3 I0045      gradual     0.978                          recalibrate
```
