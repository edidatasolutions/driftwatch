for (f in list.files("C:/Users/User/Documents/driftwatch/R", full.names = TRUE)) source(f)
t0 <- Sys.time()
sim <- dw_simulate(seed = 4)
est <- dw_estimate(sim$responses, sim$bank)
cat("estimate:", format(Sys.time() - t0), "\n")
# estimator check: stable items z ~ N(0,1)?
st <- sim$truth$type == "stable"
cat("stable z mean/sd:", mean(est$z[st, ], na.rm = TRUE), sd(est$z[st, ], na.rm = TRUE), "\n")
t0 <- Sys.time(); tu <- dw_tune(est, target = 0.01, n_rep = 10, seed = 1); cat("tune:", format(Sys.time() - t0), " h =", tu$h, "\n")
tn <- dw_tune(est, target = 0.01, method = "normal", seed = 1); cat("normal h =", tn$h, "\n")
mon <- dw_monitor(est, h = tu$h)
it <- merge(mon$items, sim$truth, by = "item")
cat("false alarms among stable:", sum(it$alarm & it$type.y == "stable"), "of", sum(it$type.y == "stable"), "\n")
for (ty in c("gradual", "abrupt")) {
  s <- it$type.y == ty
  cat(ty, ": detected", mean(it$alarm[s]), " delay median", median((it$alarm_window - it$onset)[s & it$alarm]),
      " cp MAE", mean(abs(it$change_point - it$onset)[s & it$alarm]),
      " type correct", mean((it$type.x == ty)[s & it$alarm]), "\n")
}
tp <- dw_twopoint(est)
tp <- merge(tp, sim$truth, by = "item")
cat("two-point: gradual det", mean(tp$flag[tp$type == "gradual"]), " abrupt det", mean(tp$flag[tp$type == "abrupt"]),
    " stable FA", sum(tp$flag[tp$type == "stable"]), "\n")
form <- sample(sim$bank$item, 60)
cur <- sim$b_path[, ncol(sim$b_path)]
flagged <- it$item[it$alarm]
last <- est$b_hat[, ncol(est$b_hat)]
print(dw_impact(form, sim$bank, cur, flagged, recalibrated = last[flagged], cut = 0.5))
print(head(dw_actions(mon, anchors = form[1:20])[, c("item", "type", "magnitude", "action")]))
