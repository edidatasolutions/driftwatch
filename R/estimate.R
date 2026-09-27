#' Window-level item difficulty estimates
#'
#' Rasch difficulty for every item x window, with examinee ability treated as
#' known (from operational scoring on the rest of the form). Estimation is
#' penalized maximum likelihood with a weak N(b_bank, `prior_sd`^2) penalty
#' that only matters for all-correct or all-incorrect windows. Newton steps
#' run for all item-windows at once.
#'
#' @param responses Long data frame: `window` (integer), `item`, `theta`, `x`.
#' @param bank Reference parameters: `item`, `b`, and optionally `se`.
#' @param prior_sd SD of the weak penalty.
#' @return A `dw_estimates` object: matrices `b_hat`, `se`, `n` and `z`
#'   (items x windows; `z` is the standardized deviation from the bank, NA
#'   where an item was not administered), plus `bank` and `responses`.
#' @examples
#' sim <- dw_simulate(n_items = 60, n_windows = 20, mean_n = 60,
#'                    onset_range = c(5, 12), seed = 1)
#' est <- dw_estimate(sim$responses, sim$bank)
#' round(est$z[1:5, 1:6], 2)
#' @export
dw_estimate <- function(responses, bank, prior_sd = 3) {
  bank <- as.data.frame(bank, stringsAsFactors = FALSE)
  bank$item <- as.character(bank$item)
  if (is.null(bank$se)) bank$se <- 0
  r <- responses
  r$item <- as.character(r$item)
  if (anyNA(match(r$item, bank$item))) stop("Responses to items not in the bank.")
  windows <- sort(unique(r$window))
  key <- paste(r$item, r$window, sep = "\r")
  g <- match(key, unique(key))
  gi <- r$item[!duplicated(g)]; gw <- r$window[!duplicated(g)]
  mu <- bank$b[match(gi, bank$item)]
  b <- mu
  for (it in 1:25) {
    P <- stats::plogis(r$theta - b[g])
    grad <- -drop(rowsum(r$x - P, g)) - (b - mu) / prior_sd^2
    info <- drop(rowsum(P * (1 - P), g)) + 1 / prior_sd^2
    step <- grad / info
    b <- b + pmax(pmin(step, 1), -1)
    if (max(abs(step)) < 1e-8) break
  }
  P <- stats::plogis(r$theta - b[g])
  se <- 1 / sqrt(drop(rowsum(P * (1 - P), g)) + 1 / prior_sd^2)
  nn <- tabulate(g)

  mk <- function(v) {
    M <- matrix(NA_real_, nrow(bank), length(windows),
                dimnames = list(bank$item, windows))
    M[cbind(match(gi, bank$item), match(gw, windows))] <- v
    M
  }
  B <- mk(b); S <- mk(se); N <- mk(nn); N[is.na(N)] <- 0
  Z <- (B - bank$b) / sqrt(S^2 + bank$se^2)
  structure(list(b_hat = B, se = S, n = N, z = Z, bank = bank,
                 windows = windows, responses = r), class = "dw_estimates")
}
