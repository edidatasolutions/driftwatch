# Two-sided CUSUM over the columns (windows) of Z, vectorized over items.
# Missing windows leave the statistics unchanged. Returns the statistic
# paths and, per item, the maximum statistic.
cusum_paths <- function(Z, k) {
  n <- nrow(Z); Tn <- ncol(Z)
  Sp <- Sm <- matrix(0, n, Tn)
  sp <- sm <- numeric(n)
  for (t in seq_len(Tn)) {
    z <- Z[, t]; ok <- !is.na(z)
    sp[ok] <- pmax(0, sp[ok] + z[ok] - k)
    sm[ok] <- pmax(0, sm[ok] - z[ok] - k)
    Sp[, t] <- sp; Sm[, t] <- sm
  }
  list(Sp = Sp, Sm = Sm, max = pmax(apply(Sp, 1, max), apply(Sm, 1, max)))
}

# Step vs ramp fit to deviations d (weights w) over windows 1..t_end,
# profiling the change point. Both models have one change point and one
# magnitude parameter, so their weighted SSEs are compared directly: with
# inverse-variance weights, (SSE_other - SSE_best) / 2 is the log likelihood
# ratio of the better model.
classify_change <- function(d, w, t_end) {
  idx <- which(!is.na(d[seq_len(t_end)]))
  d <- d[idx]; w <- w[idx]
  best <- list(abrupt = list(sse = Inf), gradual = list(sse = Inf))
  for (tau in unique(idx)) {
    after <- idx >= tau
    if (sum(after) < 2) next
    base <- sum(w[!after] * d[!after]^2)
    delta <- sum(w[after] * d[after]) / sum(w[after])
    sse_step <- base + sum(w[after] * (d[after] - delta)^2)
    u <- idx[after] - tau + 1
    gamma <- sum(w[after] * u * d[after]) / sum(w[after] * u^2)
    sse_ramp <- base + sum(w[after] * (d[after] - gamma * u)^2)
    if (sse_step < best$abrupt$sse)
      best$abrupt <- list(sse = sse_step, tau = tau, magnitude = delta, rate = NA_real_)
    if (sse_ramp < best$gradual$sse)
      best$gradual <- list(sse = sse_ramp, tau = tau, magnitude = gamma * (t_end - tau + 1),
                           rate = gamma)
  }
  if (!is.finite(best$abrupt$sse)) return(list(sse = Inf))
  type <- if (best$gradual$sse < best$abrupt$sse) "gradual" else "abrupt"
  out <- best[[type]]
  out$type <- type
  out$log_lr <- abs(best$gradual$sse - best$abrupt$sse) / 2
  out
}

#' Sequential drift monitoring
#'
#' Runs a two-sided CUSUM on each item's standardized deviations
#' `z_t = (b_t - b_bank) / SE`:
#' `S+[t] = max(0, S+[t-1] + z[t] - k)` and likewise downward. An alarm is
#' raised the first window either statistic exceeds `h`. Drift type is then
#' classified by comparing step and ramp fits to the difficulty series
#' (profiling the change point), using data up to `followup` windows after
#' the alarm. `change_point` is the onset under the better-fitting model;
#' `cusum_change_point` is the standard CUSUM estimator (the window after the
#' statistic last left zero), which locates abrupt changes well but lags
#' gradual onsets.
#'
#' @param estimates A `dw_estimates` object.
#' @param h Alarm threshold, ideally from [dw_tune()].
#' @param k Reference value (half the shift, in SE units, the chart is tuned
#'   to detect).
#' @param followup Windows after the alarm used to classify the change
#'   (`Inf` = all data to date).
#' @param min_log_lr Minimum log likelihood ratio between the step and ramp
#'   models for a type to be assigned; weaker evidence gives
#'   `"undetermined"`. Soon after an alarm a ramp and a step often cannot be
#'   told apart; rerun with more windows to resolve them.
#' @return A `dw_monitor` object; `$items` has one row per item: `alarm`
#'   (logical), `alarm_window`, `direction` (`harder` / `easier`),
#'   `change_point`, `type` (`abrupt` / `gradual` / `undetermined`),
#'   `type_log_lr` (evidence for the better model), `magnitude` (current
#'   displacement under the better model, logits), `rate` (logits per window,
#'   gradual only).
#' @examples
#' sim <- dw_simulate(n_items = 60, n_windows = 20, mean_n = 60,
#'                    onset_range = c(5, 12), seed = 1)
#' est <- dw_estimate(sim$responses, sim$bank)
#' mon <- dw_monitor(est, h = 8)
#' mon
#' table(alarm = mon$items$alarm, truth = sim$truth$type)
#' @export
dw_monitor <- function(estimates, h, k = 0.5, followup = 3, min_log_lr = 1) {
  Z <- estimates$z; Tn <- ncol(Z); wins <- estimates$windows
  cs <- cusum_paths(Z, k)
  first <- function(S) apply(S > h, 1, function(v) if (any(v)) which(v)[1] else NA_integer_)
  up <- first(cs$Sp); dn <- first(cs$Sm)
  alarm_t <- pmin(up, dn, na.rm = TRUE)
  dir <- ifelse(is.na(alarm_t), NA_character_,
                ifelse(!is.na(up) & (is.na(dn) | up <= dn), "harder", "easier"))
  items <- data.frame(item = rownames(Z), alarm = !is.na(alarm_t),
                      alarm_window = wins[alarm_t], direction = dir,
                      change_point = NA_real_, cusum_change_point = NA_real_,
                      type = NA_character_, type_log_lr = NA_real_,
                      magnitude = NA_real_, rate = NA_real_, stringsAsFactors = FALSE)
  D <- estimates$b_hat - estimates$bank$b
  W <- 1 / (estimates$se^2 + estimates$bank$se^2)
  for (i in which(items$alarm)) {
    S <- if (dir[i] == "harder") cs$Sp[i, ] else cs$Sm[i, ]
    zeros <- which(S[seq_len(alarm_t[i])] == 0)
    cp <- if (length(zeros)) max(zeros) + 1 else 1
    t_end <- if (is.infinite(followup)) Tn else min(Tn, alarm_t[i] + followup)
    fit <- classify_change(D[i, ], W[i, ], t_end)
    items$cusum_change_point[i] <- wins[cp]
    items$change_point[i] <- if (is.finite(fit$sse)) wins[fit$tau] else wins[cp]
    if (is.finite(fit$sse)) {
      items$type[i] <- if (fit$log_lr >= min_log_lr) fit$type else "undetermined"
      items$type_log_lr[i] <- fit$log_lr
      items$magnitude[i] <- fit$magnitude
      items$rate[i] <- fit$rate
    }
  }
  structure(list(items = items, h = h, k = k, followup = followup, min_log_lr = min_log_lr,
                 Sp = cs$Sp, Sm = cs$Sm, estimates = estimates), class = "dw_monitor")
}

#' @export
print.dw_monitor <- function(x, ...) {
  it <- x$items
  cat("<dw_monitor>", nrow(it), "items |", length(x$estimates$windows), "windows | h =",
      round(x$h, 3), "| k =", x$k, "\n")
  cat(sum(it$alarm), "alarms:", sum(it$type %in% "abrupt"), "abrupt,",
      sum(it$type %in% "gradual"), "gradual,", sum(it$type %in% "undetermined"),
      "undetermined\n\n")
  a <- it[it$alarm, ]
  if (nrow(a)) print(utils::head(a[order(a$alarm_window), ], 15), row.names = FALSE, digits = 3)
  invisible(x)
}
