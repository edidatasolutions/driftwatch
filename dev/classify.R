for (f in list.files("C:/Users/User/Documents/driftwatch/R", full.names = TRUE)) source(f)
sim <- dw_simulate(n_items = 600, p_gradual = 0.3, p_abrupt = 0.1, seed = 4)
est <- dw_estimate(sim$responses, sim$bank)
D <- est$b_hat - est$bank$b; W <- 1 / (est$se^2 + est$bank$se^2)
tr <- sim$truth
g <- which(tr$type == "gradual")
# Noise-free check: true path should classify as gradual.
nf <- sapply(g, function(i) classify_change(sim$b_path[i, ] - sim$bank$b[i], W[i, ], 40)$type)
cat("noise-free gradual classified gradual:", mean(nf == "gradual"), "\n")
# Full-horizon classification with noise
full <- sapply(g, function(i) classify_change(D[i, ], W[i, ], 40)$type)
cat("full-horizon gradual correct:", mean(full == "gradual"), "\n")
# by amount of post-onset data and slope
post <- 40 - tr$onset[g] + 1
print(tapply(full == "gradual", cut(post, c(0, 10, 20, 40)), mean))
print(tapply(full == "gradual", cut(abs(tr$size[g]), c(0.02, 0.035, 0.05, 0.06)), mean))
a <- which(tr$type == "abrupt")
fa <- sapply(a, function(i) classify_change(D[i, ], W[i, ], 40)$type)
cat("full-horizon abrupt correct:", mean(fa == "abrupt"), "\n")
