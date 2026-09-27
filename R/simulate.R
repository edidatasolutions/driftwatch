#' Simulate a continuously administered item bank with known drift
#'
#' Each window, every item is answered by a Poisson number of examinees whose
#' abilities are known from operational scoring (the population mean may
#' trend over time; this is not drift). Items are stable, drift gradually
#' (linear from an onset window) or jump abruptly at an onset window.
#'
#' @param n_items,n_windows Bank size and number of windows.
#' @param mean_n Mean responses per item per window.
#' @param p_gradual,p_abrupt Share of items with each drift type.
#' @param slope_range Absolute gradual slope per window (logits).
#' @param jump_range Absolute abrupt jump (logits).
#' @param onset_range Windows in which drift can begin.
#' @param theta_trend Change in examinee mean ability per window.
#' @param ref_se Standard error of the banked (reference) difficulties.
#' @param seed Optional seed.
#' @return A `dw_sim`: `$responses` (`window`, `item`, `theta`, `x`), `$bank`
#'   (`item`, `b`, `se`), `$truth` (`item`, `type`, `onset`, `size`,
#'   `b_true_final`) and `$b_path` (items x windows matrix of true difficulty).
#' @examples
#' sim <- dw_simulate(n_items = 60, n_windows = 20, mean_n = 60,
#'                    onset_range = c(5, 12), seed = 1)
#' table(sim$truth$type)
#' @export
dw_simulate <- function(n_items = 300, n_windows = 40, mean_n = 80,
                        p_gradual = 0.1, p_abrupt = 0.05,
                        slope_range = c(0.02, 0.06), jump_range = c(0.4, 1.0),
                        onset_range = c(5, 30), theta_trend = 0.01,
                        ref_se = 0.05, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  ids <- sprintf("I%04d", seq_len(n_items))
  b0 <- stats::rnorm(n_items, 0, 1)
  type <- sample(c("stable", "gradual", "abrupt"), n_items, replace = TRUE,
                 prob = c(1 - p_gradual - p_abrupt, p_gradual, p_abrupt))
  onset <- ifelse(type == "stable", NA,
                  sample(onset_range[1]:onset_range[2], n_items, replace = TRUE))
  sgn <- sample(c(-1, 1), n_items, replace = TRUE)
  size <- ifelse(type == "gradual", sgn * stats::runif(n_items, slope_range[1], slope_range[2]),
          ifelse(type == "abrupt", sgn * stats::runif(n_items, jump_range[1], jump_range[2]), 0))
  path <- matrix(b0, n_items, n_windows)
  for (t in seq_len(n_windows)) {
    on <- !is.na(onset) & t >= onset
    path[on & type == "gradual", t] <- b0[on & type == "gradual"] +
      size[on & type == "gradual"] * (t - onset[on & type == "gradual"] + 1)
    path[on & type == "abrupt", t] <- b0[on & type == "abrupt"] + size[on & type == "abrupt"]
  }
  dimnames(path) <- list(ids, seq_len(n_windows))

  n <- matrix(stats::rpois(n_items * n_windows, mean_n), n_items, n_windows)
  ii <- rep(rep(seq_len(n_items), n_windows), as.vector(n))
  tt <- rep(rep(seq_len(n_windows), each = n_items), as.vector(n))
  theta <- stats::rnorm(length(ii), theta_trend * (tt - 1), 1)
  x <- stats::rbinom(length(ii), 1, stats::plogis(theta - path[cbind(ii, tt)]))

  structure(list(
    responses = data.frame(window = tt, item = ids[ii], theta = theta, x = x,
                           stringsAsFactors = FALSE),
    bank = data.frame(item = ids, b = b0 + stats::rnorm(n_items, 0, ref_se),
                      se = ref_se, stringsAsFactors = FALSE),
    truth = data.frame(item = ids, type = type, onset = onset, size = size,
                       b_true_final = path[, n_windows], stringsAsFactors = FALSE),
    b_path = path
  ), class = "dw_sim")
}
