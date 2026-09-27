#' Tune the alarm threshold for a bank-wide false-alarm target
#'
#' An item raises a false alarm over the monitoring horizon exactly when the
#' maximum of its CUSUM statistics exceeds `h`. So `h` is the
#' `1 - target` quantile of that maximum under no drift. With
#' `method = "design"`, the null is simulated on the program's own design:
#' the same items, windows, examinee abilities and sample sizes, with
#' responses regenerated from the banked difficulties, then re-estimated and
#' re-standardized exactly as in monitoring. This captures small-sample
#' non-normality of `z` and sparse windows. `method = "normal"` treats `z` as
#' iid N(0, 1), which is fast and useful for planning a bank that does not
#' exist yet.
#'
#' @param estimates A `dw_estimates` object (required for `"design"`).
#' @param target Probability that a non-drifting item alarms at least once
#'   over the horizon. Expected false alarms for the bank =
#'   `target * n_items`.
#' @param k Reference value (as in [dw_monitor()]).
#' @param method `"design"` or `"normal"`.
#' @param n_rep Null replicates of the whole bank (`"design"`) or simulated
#'   item series (`"normal"`).
#' @param n_windows Horizon for `"normal"` (default: the estimates' windows).
#' @param seed Optional seed.
#' @return A list: `h`, `target`, `k`, `method`, `expected_false_alarms`
#'   (per bank, when estimates are given), and `null_max` (the simulated
#'   maxima).
#' @examples
#' sim <- dw_simulate(n_items = 60, n_windows = 20, mean_n = 60,
#'                    onset_range = c(5, 12), seed = 1)
#' est <- dw_estimate(sim$responses, sim$bank)
#' dw_tune(est, target = 0.02, method = "normal", seed = 1)$h
#' \donttest{
#' # Design-based tuning (recommended) simulates the whole bank n_rep times.
#' dw_tune(est, target = 0.02, n_rep = 5, seed = 1)$h
#' }
#' @export
dw_tune <- function(estimates = NULL, target = 0.01, k = 0.5,
                    method = c("design", "normal"), n_rep = 20, n_windows = NULL,
                    seed = NULL) {
  method <- match.arg(method)
  if (!is.null(seed)) set.seed(seed)
  if (method == "normal") {
    if (is.null(n_windows)) n_windows <- length(estimates$windows)
    Z <- matrix(stats::rnorm(n_rep * 1000 * n_windows), n_rep * 1000, n_windows)
    mx <- cusum_paths(Z, k)$max
  } else {
    if (is.null(estimates)) stop("method = 'design' needs `estimates`.")
    r <- estimates$responses
    b <- estimates$bank$b[match(r$item, estimates$bank$item)]
    se_ref <- estimates$bank$se
    mx <- unlist(lapply(seq_len(n_rep), function(i) {
      r$x <- stats::rbinom(nrow(r), 1, stats::plogis(r$theta - b))
      # The banked value is itself an estimate with error se_ref.
      bank <- estimates$bank
      bank$b <- bank$b + stats::rnorm(nrow(bank), 0, se_ref)
      e <- dw_estimate(r, bank)
      cusum_paths(e$z, k)$max
    }))
  }
  h <- unname(stats::quantile(mx, 1 - target, type = 8))
  list(h = h, target = target, k = k, method = method,
       expected_false_alarms = if (is.null(estimates)) NA else target * nrow(estimates$bank),
       null_max = mx)
}
