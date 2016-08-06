library(ggplot2)
library(readr)
library(dplyr, warn.conflicts = FALSE)
library(Rtsne)
library(ggfortify, quietly = TRUE)
theme_set(theme_bw())
# ----------------
# READ
# ----------------
metadata = read_csv("data/metadata.csv")
features = read_delim("data/features.csv", 
                      delim = " ", 
                      col_names = F)

metadata$Outlier = metadata$Distance > 1000
metadata$region = countrycode(metadata$Country, "country.name", "region")

# 1-30 : rythm
# -60 : melody
# -90 : timbre
# -120 : harmony
names(features) = c(paste0("rythm", 1:30), 
                    paste0("melody", 1:30), 
                    paste0("timbre", 1:30), 
                    paste0("harmony", 1:30))


dists = mahalanobis(features, colMeans(features), cov(features))

# ----------------
# T-SNE
# ----------------
tsne_raw = Rtsne(features, 
                 perplexity = 30,
                 max_iter = 400,
                 verbose = TRUE,
                 check_duplicates = FALSE)

tsnedf = as.data.frame(tsne_raw$Y)
ggplot(tsnedf, aes(x = V1, y = V2, color = metadata$region)) + 
  geom_point(alpha = 0.7, size = 2) + 
  theme_bw()

library(scatterD3)
scatterD3(tsnedf$V1, tsnedf$V2, 
          #lab = metadata$CatalogNumber,
          col_var = metadata$region,
          xlab = "PC1", ylab = "PC2", col_lab = "Region", 
          lasso = TRUE)

to_export = metadata
to_export$x = tsnedf$V1
to_export$y = tsnedf$V2


# ----------------
# PCA
# ----------------
# install_github("vqv/ggbiplot")
library(ggbiplot)

pr.out = prcomp(features) 

pr.out$rotation
biplot(pr.out, scale = 0)

autoplot(pr.out, label = TRUE, label.size = 3, shape = FALSE, alpha = .4)

autoplot(pr.out, label = FALSE, label.size = 3, shape = TRUE, 
         alpha = 0.5,loadings = TRUE, loadings.colour = 'blue',
         loadings.label = TRUE, loadings.label.size = 3)

ggbiplot(pr.out, obs.scale = 1, var.scale = 1,
         groups = metadata$Outlier, ellipse = FALSE, circle = TRUE, alpha = .3) +
  scale_color_discrete(name = '') +
  theme(legend.direction = 'horizontal', legend.position = 'top')

# Porcentagem da variância explicada: 
plot_pve <- function(prout){
  pr.var <- pr.out$sdev^2
  pve <- pr.var / sum(pr.var)
  df = data.frame(x = 1:NROW(pve), y = cumsum(pve))
  ggplot(df, aes(x = x, y = y)) + 
    geom_point(size = 3) + 
    geom_line() + 
    labs(x='Principal Component', y = 'Cumuative Proportion of Variance Explained')
}

plot_pve(pr.out)

tsne_raw_long = Rtsne(features, 
                 perplexity = 30,
                 max_iter = 1000,
                 verbose = TRUE,
                 check_duplicates = FALSE)
