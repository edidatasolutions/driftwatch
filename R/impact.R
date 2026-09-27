tcc <- function(theta, b) vapply(theta, function(t) sum(stats::plogis(t - b)), 0)

# Ability at which a test characteristic curve reaches a given expected score.
tcc_inv <- function(score, b) {
  vapply(score, function(s) {
    if (s <= 0) return(-Inf)
    if (s >= length(b)) return(Inf)
    stats::uniroot(function(t) sum(stats::plogis(t - b)) - s, c(-15, 15), tol = 1e-10)$root
  }, 0)
}

#' Score and pass-rate impact of drifted items
#'
#' For a pre-equated form scored by true-score conversion (the raw score is
#' mapped to theta through the test characteristic curve of the scoring
#' parameters), an examinee of ability theta is reported at
#' `TCC_scoring^-1(TCC_current(theta))`. The function compares scoring
#' scenarios against the current (true or best-estimate) difficulties:
#' \describe{
#'   \item{keep}{Score with banked parameters for every item.}
#'   \item{remove}{Drop flagged items from the form; score the rest with
#'     banked parameters.}
#'   \item{recalibrate}{Score flagged items with their current estimates.}
#' }
#' and reports reported-score bias at the cut and the pass rate in the
#' population against the correct pass rate.
#'
#' @param form Item ids on the form.
#' @param bank Banked parameters (`item`, `b`).
#' @param current Named vector of current difficulties: the truth in a
#'   simulation, or the latest window estimates in practice.
#' @param flagged Item ids flagged by monitoring.
#' @param recalibrated Named vector of re-estimated difficulties for flagged
#'   items (default: `current[flagged]`).
#' @param cut Passing standard on the theta scale.
#' @param theta_mean,theta_sd Examinee population.
#' @return Data frame: `scenario`, `n_items`, `bias_at_cut`, `mean_abs_bias`,
#'   `pass_rate`, `pass_rate_error` (vs the correct rate).
#' @examples
#' # A 20-item form where one item became 0.8 logits harder
#' current <- setNames(c(0.8, rep(0, 19)), paste0("q", 1:20))
#' bank <- data.frame(item = names(current), b = 0)
#' dw_impact(names(current), bank, current, flagged = "q1", cut = 0)
#' @export
dw_impact <- function(form, bank, current, flagged, recalibrated = NULL,
                      cut = 0, theta_mean = 0, theta_sd = 1) {
  bb <- stats::setNames(bank$b, bank$item)[form]
  cur <- current[form]
  if (anyNA(bb) || anyNA(cur)) stop("Every form item needs banked and current difficulties.")
  flagged <- intersect(flagged, form)
  if (is.null(recalibrated)) recalibrated <- current[flagged]
  th <- theta_mean + theta_sd * stats::qnorm(stats::ppoints(401))
  correct <- 1 - stats::pnorm(cut, theta_mean, theta_sd)
  scen <- list(
    keep = list(items = form, scoring = bb),
    remove = list(items = setdiff(form, flagged), scoring = bb[setdiff(form, flagged)]),
    recalibrate = list(items = form, scoring = replace(bb, flagged, recalibrated[flagged]))
  )
  do.call(rbind, lapply(names(scen), function(s) {
    it <- scen[[s]]$items; sb <- scen[[s]]$scoring[it]; cb <- cur[it]
    reported <- tcc_inv(tcc(th, cb), sb)
    # An examinee passes when reported >= cut, i.e. theta >= theta_star.
    theta_star <- tcc_inv(tcc(cut, sb), cb)
    data.frame(scenario = s, n_items = length(it),
               bias_at_cut = tcc_inv(tcc(cut, cb), sb) - cut,
               mean_abs_bias = mean(abs(reported - th)),
               pass_rate = 1 - stats::pnorm(theta_star, theta_mean, theta_sd),
               pass_rate_error = (1 - stats::pnorm(theta_star, theta_mean, theta_sd)) - correct,
               stringsAsFactors = FALSE)
  }))
}

#' Recommended actions and audit log
#'
#' Turns monitoring alarms into recommended actions with a written rationale:
#' \itemize{
#'   \item abrupt change of at least `retire_at` logits: `retire` (consistent
#'     with exposure/compromise or a key or rendering error; review the key,
#'     exposure counts and any content change before reuse);
#'   \item other abrupt changes, gradual drift and undetermined changes:
#'     `recalibrate` (undetermined ones should be reclassified later);
#'   \item any alarm on an anchor item: additionally `remove from anchor set`.
#' }
#' @param monitor A `dw_monitor`.
#' @param anchors Item ids used as equating anchors.
#' @param retire_at Abrupt magnitude (logits) that triggers retirement.
#' @param analyst Name recorded in the log.
#' @return Audit-log data frame, one row per alarmed item.
#' @examples
#' sim <- dw_simulate(n_items = 60, n_windows = 20, mean_n = 60,
#'                    onset_range = c(5, 12), seed = 1)
#' mon <- dw_monitor(dw_estimate(sim$responses, sim$bank), h = 8)
#' log <- dw_actions(mon, anchors = sim$bank$item[1:10], analyst = "DE")
#' if (nrow(log)) log[, c("item", "type", "magnitude", "action")]
#' @export
dw_actions <- function(monitor, anchors = character(0), retire_at = 0.5, analyst = NA_character_) {
  a <- monitor$items[monitor$items$alarm, ]
  if (!nrow(a)) return(data.frame())
  big <- a$type %in% "abrupt" & abs(a$magnitude) >= retire_at
  action <- ifelse(big, "retire", "recalibrate")
  anchor <- a$item %in% anchors
  action[anchor] <- paste(action[anchor], "+ remove from anchor set")
  why <- ifelse(a$type %in% "undetermined",
    sprintf("Shift of about %+.2f logits (item became %s) near window %s; too soon to tell a jump from a trend. Recalibrate and reclassify after more windows",
            a$magnitude, a$direction, a$change_point),
    ifelse(a$type %in% "abrupt",
    sprintf("Abrupt shift of %+.2f logits (item became %s) beginning window %s; %s",
            a$magnitude, a$direction, a$change_point,
            ifelse(big, "size is consistent with exposure/compromise or a key/rendering error; review before reuse",
                   "moderate shift; re-estimate from post-change data")),
    sprintf("Gradual drift of %+.3f logits/window since window %s (now %+.2f logits, item %s); consistent with content aging or curriculum change",
            a$rate, a$change_point, a$magnitude, a$direction)))
  data.frame(item = a$item, alarm_window = a$alarm_window, change_point = a$change_point,
             type = a$type, magnitude = round(a$magnitude, 3), direction = a$direction,
             anchor = anchor, action = action, rationale = why,
             h = monitor$h, k = monitor$k, analyst = analyst,
             logged_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
             stringsAsFactors = FALSE)
}

#' Two-point drift check (the conventional baseline)
#'
#' Pools the first and last blocks of windows, estimates each item's
#' difficulty in both, and flags items whose robust z of the difference
#' (median/MAD standardized) exceeds `crit`: the usual displacement check at
#' equating time.
#'
#' @param estimates A `dw_estimates` object.
#' @param early,late Window indices forming the two calibrations.
#' @param crit Robust-z criterion.
#' @return Data frame: `item`, `d`, `robust_z`, `flag`.
#' @examples
#' sim <- dw_simulate(n_items = 60, n_windows = 20, mean_n = 60,
#'                    onset_range = c(5, 12), seed = 1)
#' tp <- dw_twopoint(dw_estimate(sim$responses, sim$bank))
#' table(flag = tp$flag, truth = sim$truth$type)
#' @export
dw_twopoint <- function(estimates, early = 1:5, late = NULL, crit = 2.7) {
  Tn <- length(estimates$windows)
  if (is.null(late)) late <- (Tn - 4):Tn
  pool <- function(cols) {
    W <- 1 / estimates$se[, cols, drop = FALSE]^2
    rowSums(W * estimates$b_hat[, cols, drop = FALSE], na.rm = TRUE) / rowSums(W, na.rm = TRUE)
  }
  d <- pool(late) - pool(early)
  rz <- (d - stats::median(d, na.rm = TRUE)) / stats::mad(d, na.rm = TRUE)
  data.frame(item = rownames(estimates$b_hat), d = d, robust_z = rz, flag = abs(rz) > crit,
             stringsAsFactors = FALSE)
}
