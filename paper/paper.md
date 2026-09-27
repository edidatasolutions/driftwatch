---
title: 'driftwatch: Sequential monitoring of item parameter drift'
tags:
  - R
  - psychometrics
  - item parameter drift
  - CUSUM
  - change-point detection
authors:
  - name: Daniel Edi
    affiliation: 1
affiliations:
  - name: Independent Researcher
    index: 1
date: 27 September 2026
bibliography: paper.bib
---

<!-- DRAFT. Verify every reference and number before submission. Add your ORCID under the author (orcid: 0000-...) once you have one. Check the
journal's policy on disclosing AI-assisted software and writing. -->

# Summary

Continuous-testing programs and pre-equated item banks need ongoing
surveillance of item parameter drift, not just a comparison of two
calibrations at equating time. `driftwatch` estimates Rasch difficulties in
rolling windows and monitors each item with a two-sided CUSUM chart
[@page1954; @montgomery2009]. It estimates when the change began and
classifies it as a gradual trend or an abrupt jump, reporting "undetermined"
when the evidence cannot yet tell them apart. Thresholds are set for a
bank-wide false-alarm target by simulating the program's own design under no
drift. The package also quantifies score and pass-rate impact, and writes
recommended actions with rationales to an audit log.

# Statement of need

Statistical process control has been applied to testing before, for example
to detect known items in adaptive testing [@veerkamp2000], but psychometric
drift checks in practice remain two-point comparisons. `driftwatch` answers
the operational questions: when did an item start drifting, how, and what
should be done about it? It also shows why thresholds must be tuned on the
actual design. The banked parameter's own error is shared by every window and
accumulates in the CUSUM, so iid-normal thresholds give far too many false
alarms.

# Validation

Across five known-truth replications (300 items, 40 windows), the tuned
chart gave 1.3% false alarms per item against a 1% target. It detected all
abrupt drift a median of 3.4 windows after onset, and 89% of gradual drift.
A first-versus-last two-point check caught 74% and 78%, and only at the end
of the period. Recalibrating flagged items reduced the pass-rate error on a
60-item form from 1.3 to 0.2 percentage points.

# Acknowledgements

Software development and drafting were assisted by Claude (Anthropic). The author designed the methods, reviewed and validated all code and results, and takes full responsibility for the content.

# References
