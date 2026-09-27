library(driftwatch)
ns <- asNamespace("driftwatch")

# 1. CUSUM mechanics -------------------------------------------------------------
Z <- rbind(c(0, 0, 0, 0), c(2, 2, 2, 2), c(-3, -3, NA, -3))
cs <- ns$cusum_paths(Z, k = 0.5)
stopifnot(all(cs$Sp[1, ] == 0), all.equal(cs$Sp[2, ], c(1.5, 3, 4.5, 6)),
          all.equal(cs$Sm[3, ], c(2.5, 5, 5, 7.5)))            # NA window carries over

# 2. Step vs ramp classifier on noise-free series ------------------------------------
w <- rep(1, 30)
step <- c(rep(0, 10), rep(0.8, 20)); ramp <- c(rep(0, 10), 0.05 * (1:20))
cs_step <- ns$classify_change(step, w, 30); cs_ramp <- ns$classify_change(ramp, w, 30)
stopifnot(cs_step$type == "abrupt", cs_step$tau == 11, abs(cs_step$magnitude - 0.8) < 1e-10,
          cs_ramp$type == "gradual", cs_ramp$tau == 11, abs(cs_ramp$rate - 0.05) < 1e-10)

# 3. Estimator: stable items give standardized deviations ---------------------------
sim <- dw_simulate(n_items = 150, n_windows = 30, onset_range = c(5, 15), seed = 21)
est <- dw_estimate(sim$responses, sim$bank)
st <- sim$truth$type == "stable"
zs <- est$z[st, ]
# Each item's z-scores share its bank error, so their mean over ~130 items
# varies by about +/-0.03 across seeds; 0.1 is a safe bound for bias.
stopifnot(abs(mean(zs, na.rm = TRUE)) < 0.1, abs(sd(zs, na.rm = TRUE) - 1) < 0.05)
final <- est$b_hat[, 30]
stopifnot(cor(final, sim$b_path[, 30]) > 0.95)

# 4. Tuned threshold controls false alarms; drift is detected --------------------------
tu <- dw_tune(est, target = 0.02, n_rep = 6, seed = 1)
tn <- dw_tune(est, target = 0.02, method = "normal", seed = 1)
stopifnot(tu$h > tn$h)        # shared reference error makes the naive null too optimistic
mon <- dw_monitor(est, h = tu$h)
tr <- sim$truth
it <- mon$items[match(tr$item, mon$items$item), ]
stopifnot(mean(it$alarm[st]) < 0.06,
          mean(it$alarm[tr$type == "abrupt"]) >= 0.8,
          mean(it$alarm[tr$type == "gradual"]) >= 0.5)
ab <- tr$type == "abrupt" & it$alarm
stopifnot(mean(abs(it$change_point[ab] - tr$onset[ab])) < 2,
          all(it$direction[ab] == ifelse(tr$size[ab] > 0, "harder", "easier")))

# 5. Impact: recalibration removes the bias that keeping drifted items causes ---------
cur <- stats::setNames(c(0.8, rep(0, 19)), paste0("q", 1:20))
bank <- data.frame(item = names(cur), b = 0)
imp <- dw_impact(names(cur), bank, cur, flagged = "q1", cut = 0)
stopifnot(imp$bias_at_cut[imp$scenario == "keep"] < -0.01,      # harder item, scored as old: under-reports
          abs(imp$pass_rate_error[imp$scenario == "recalibrate"]) < 1e-8,
          abs(imp$pass_rate_error[imp$scenario == "remove"]) < 1e-8)

# 6. Actions / audit log ----------------------------------------------------------------
log <- dw_actions(mon, anchors = tr$item[1:30], analyst = "test")
stopifnot(nrow(log) == sum(mon$items$alarm),
          all(grepl("retire", log$action) == (log$type == "abrupt" & abs(log$magnitude) >= 0.5)),
          all(grepl("anchor", log$action) == log$anchor))
cat("All driftwatch tests passed.\n")
