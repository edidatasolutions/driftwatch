# Replication study for the driftwatch manuscript: the design of known_truth.R
# over independent seeds (means with Monte Carlo SEs).
# Usage: Rscript inst/validation/replication_study.R [n_reps] [n_workers]
args <- commandArgs(trailingOnly = TRUE)
n_reps <- if (length(args) >= 1) as.integer(args[1]) else 100
n_workers <- if (length(args) >= 2) as.integer(args[2]) else max(1, parallel::detectCores() - 2)

one_rep <- function(seed) {
  suppressPackageStartupMessages(library(driftwatch))
  sim <- dw_simulate(seed = seed)
  est <- dw_estimate(sim$responses, sim$bank)
  tu <- dw_tune(est, target = 0.01, n_rep = 10, seed = seed)
  tn <- dw_tune(est, target = 0.01, method = "normal", seed = seed)
  tr <- sim$truth
  out <- list(seed = seed, h_design = tu$h, h_normal = tn$h)
  mon_n <- dw_monitor(est, h = tn$h)
  out$far_normal <- mean(mon_n$items$alarm[tr$type == "stable"])
  for (fu in c(3, Inf)) {
    tag <- if (is.infinite(fu)) "all" else "fu3"
    mon <- dw_monitor(est, h = tu$h, followup = fu)
    it <- mon$items[match(tr$item, mon$items$item), ]
    out[[paste0("far_", tag)]] <- mean(it$alarm[tr$type == "stable"])
    for (ty in c("gradual", "abrupt")) {
      s <- tr$type == ty; a <- s & it$alarm; d <- a & it$type != "undetermined"
      out[[sprintf("%s_%s_detected", tag, ty)]] <- mean(it$alarm[s])
      out[[sprintf("%s_%s_delay", tag, ty)]] <- if (any(a)) stats::median(it$alarm_window[a] - tr$onset[a]) else NA
      out[[sprintf("%s_%s_cp_model", tag, ty)]] <- if (any(a)) mean(abs(it$change_point[a] - tr$onset[a])) else NA
      out[[sprintf("%s_%s_cp_cusum", tag, ty)]] <- if (any(a)) mean(abs(it$cusum_change_point[a] - tr$onset[a])) else NA
      out[[sprintf("%s_%s_typed", tag, ty)]] <- if (any(a)) mean(it$type[a] != "undetermined") else NA
      out[[sprintf("%s_%s_type_acc", tag, ty)]] <- if (any(d)) mean(it$type[d] == ty) else NA
    }
  }
  tp <- dw_twopoint(est); tp <- tp[match(tr$item, tp$item), ]
  out$tp_gradual <- mean(tp$flag[tr$type == "gradual"])
  out$tp_abrupt <- mean(tp$flag[tr$type == "abrupt"])
  out$tp_far <- mean(tp$flag[tr$type == "stable"])
  mon <- dw_monitor(est, h = tu$h)
  flagged <- mon$items$item[mon$items$alarm]
  drifted <- tr$item[tr$type != "stable"]
  set.seed(seed)
  form <- c(sample(drifted, 12), sample(setdiff(sim$bank$item, drifted), 48))
  last <- est$b_hat[, ncol(est$b_hat)]
  imp <- dw_impact(form, sim$bank, sim$b_path[, ncol(sim$b_path)], flagged,
                   recalibrated = last[flagged], cut = 0.5)
  for (sc in imp$scenario) {
    out[[paste0("imp_", sc, "_bias")]] <- imp$bias_at_cut[imp$scenario == sc]
    out[[paste0("imp_", sc, "_pass_err")]] <- imp$pass_rate_error[imp$scenario == sc]
  }
  as.data.frame(out)
}

t0 <- Sys.time()
cl <- parallel::makeCluster(n_workers)
invisible(parallel::clusterCall(cl, function(p) .libPaths(c(p, .libPaths())), .libPaths()[1]))
res <- do.call(rbind, parallel::parLapply(cl, 40000 + seq_len(n_reps), one_rep))
parallel::stopCluster(cl)
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
out_dir <- if (dir.exists("inst/validation")) "inst/validation" else "."
saveRDS(res, file.path(out_dir, "replication_results.rds"))

mse <- function(v) { v <- v[!is.na(v)]; c(mean(v), stats::sd(v) / sqrt(length(v))) }
fmt <- function(v, d = 3) { m <- mse(v); sprintf(paste0("%.", d, "f (%.", d, "f)"), m[1], m[2]) }
cat(sprintf("Replications: %d | workers: %d | %.1f minutes\nValues: mean (Monte Carlo SE)\n\n", nrow(res), n_workers, elapsed))
cat("Threshold h: design", fmt(res$h_design, 2), "| iid-normal", fmt(res$h_normal, 2), "\n")
cat("False alarms among stable items (target 0.01): design h", fmt(res$far_fu3, 4),
    "| iid-normal h", fmt(res$far_normal, 4), "| two-point", fmt(res$tp_far, 4), "\n\n")
cat("Table 1. Detection\n")
for (ty in c("abrupt", "gradual"))
  cat(sprintf("  %-8s CUSUM detected %s, median delay %s, change-point error model %s / CUSUM %s | two-point %s\n", ty,
              fmt(res[[paste0("fu3_", ty, "_detected")]]), fmt(res[[paste0("fu3_", ty, "_delay")]], 2),
              fmt(res[[paste0("fu3_", ty, "_cp_model")]], 2), fmt(res[[paste0("fu3_", ty, "_cp_cusum")]], 2),
              fmt(res[[paste0("tp_", ty)]])))
cat("\nTable 2. Share typed / accuracy among typed\n")
for (tag in c("fu3", "all"))
  cat(sprintf("  %-4s abrupt %s / %s | gradual %s / %s\n", tag,
              fmt(res[[paste0(tag, "_abrupt_typed")]]), fmt(res[[paste0(tag, "_abrupt_type_acc")]]),
              fmt(res[[paste0(tag, "_gradual_typed")]]), fmt(res[[paste0(tag, "_gradual_type_acc")]])))
cat("\nImpact (60-item form, 12 drifted items, cut 0.5): pass-rate error and bias at cut\n")
for (sc in c("keep", "remove", "recalibrate"))
  cat(sprintf("  %-12s pass-rate error %s | bias at cut %s\n", sc,
              fmt(res[[paste0("imp_", sc, "_pass_err")]], 4), fmt(res[[paste0("imp_", sc, "_bias")]], 4)))
