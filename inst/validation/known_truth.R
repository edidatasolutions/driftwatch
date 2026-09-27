# Known-truth validation for driftwatch, 5 replications of a 300-item bank
# monitored over 40 windows (~80 responses per item per window).
# 10% of items drift gradually, 5% jump abruptly.
library(driftwatch)

reps <- 5
det <- list(); fa <- list(); imp <- list()
for (rep in seq_len(reps)) {
  sim <- dw_simulate(seed = 500 + rep)
  est <- dw_estimate(sim$responses, sim$bank)
  tu <- dw_tune(est, target = 0.01, n_rep = 10, seed = rep)
  tr <- sim$truth
  for (fu in c(3, Inf)) {
    mon <- dw_monitor(est, h = tu$h, followup = fu)
    it <- mon$items[match(tr$item, mon$items$item), ]
    fa[[length(fa) + 1]] <- data.frame(followup = fu, h = tu$h,
      false_alarm_rate = mean(it$alarm[tr$type == "stable"]))
    for (ty in c("gradual", "abrupt")) {
      s <- tr$type == ty; a <- s & it$alarm; dtm <- a & it$type != "undetermined"
      det[[length(det) + 1]] <- data.frame(followup = fu, type = ty,
        detected = mean(it$alarm[s]),
        median_delay = stats::median(it$alarm_window[a] - tr$onset[a]),
        cp_mae_model = mean(abs(it$change_point[a] - tr$onset[a])),
        cp_mae_cusum = mean(abs(it$cusum_change_point[a] - tr$onset[a])),
        share_typed = mean(it$type[a] != "undetermined"),
        type_accuracy = mean(it$type[dtm] == ty))
    }
  }
  tp <- dw_twopoint(est)
  tp <- tp[match(tr$item, tp$item), ]
  for (ty in c("gradual", "abrupt"))
    det[[length(det) + 1]] <- data.frame(followup = NA, type = paste0(ty, " (two-point)"),
      detected = mean(tp$flag[tr$type == ty]), median_delay = NA, cp_mae_model = NA,
      cp_mae_cusum = NA, share_typed = NA, type_accuracy = NA)
  fa[[length(fa) + 1]] <- data.frame(followup = NA, h = NA,
    false_alarm_rate = mean(tp$flag[tr$type == "stable"]))

  # Impact on a 60-item form containing drifted items, cut at theta = 0.5.
  mon <- dw_monitor(est, h = tu$h)
  flagged <- mon$items$item[mon$items$alarm]
  drifted <- tr$item[tr$type != "stable"]
  form <- c(sample(drifted, 12), sample(setdiff(sim$bank$item, drifted), 48))
  last <- est$b_hat[, ncol(est$b_hat)]
  imp[[rep]] <- dw_impact(form, sim$bank, sim$b_path[, ncol(sim$b_path)], flagged,
                          recalibrated = last[flagged], cut = 0.5)
}
agg <- function(df, by) stats::aggregate(df[setdiff(names(df), by)], df[by], mean, na.rm = TRUE)
cat("False alarms among stable items (target 1% per item over 40 windows):\n")
print(agg(do.call(rbind, fa), "followup"), digits = 3, row.names = FALSE)
cat("\nDetection, delay (windows), change-point error, drift-type classification:\n")
d <- do.call(rbind, det); d$followup[is.na(d$followup)] <- -1
print(agg(d, c("type", "followup")), digits = 3, row.names = FALSE)
cat("\nScore impact, 60-item form with 12 drifted items (mean over replications):\n")
i <- do.call(rbind, imp)
print(agg(i[c("scenario", "bias_at_cut", "mean_abs_bias", "pass_rate_error")], "scenario"),
      digits = 3, row.names = FALSE)
