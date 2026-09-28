## Submission

This is the first submission of driftwatch.

## Test environments

* Local: Windows 11, R 4.6.0
* GitHub Actions: macOS (release), Windows (release), Ubuntu (devel, release, oldrel-1)
* win-builder: R-devel

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.
* Words flagged as possibly misspelled are author names of cited references
  (Veerkamp, Glas), the standard abbreviation CUSUM (cumulative sum), and
  "pre" from "pre-equated".

## Notes for the reviewer

* The design-based threshold tuning example (`dw_tune(method = "design")`) is wrapped in `\donttest{}` because it re-simulates the item bank several times.
* Longer known-truth validation scripts are in `inst/validation/` and are not run during checks.
