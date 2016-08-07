library(ggplot2)
library(readr)
library(dplyr, warn.conflicts = FALSE)
library(Rtsne)
library(ggfortify, quietly = TRUE)
theme_set(theme_bw())
library(reshape2)
library(cluster)
library(networkD3)
library(countrycode)

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


dists = daisy(features)
distsm = as.matrix(dists)
distsm = as.data.frame(distsm)
distsm$id = row.names(distsm)

pairwise = distsm %>% 
  melt(id.vars = "id") %>% 
  filter(id != variable) %>% 
  group_by(id) %>% 
  arrange(value) %>%
  slice(1) # TOP most similar!
names(pairwise) = c("from", "to", "distance")

pairwise %>% 
  ggplot(aes(x = distance)) + 
  geom_freqpoly()

# ----------------
# NETWORK
# ----------------
make_nodesdf = function(ztoz_df){
  #' Creates df with nodes info for networkD3
  nodesdf = data_frame(id = unique(pairwise$from))
  nodesdf$index = 0:(NROW(nodesdf)-1)
  
  return(nodesdf)
}

nodes = make_nodesdf(pairwise)
metadata$id = as.character(1:NROW(metadata))
nodes = left_join(nodes, metadata) %>% rename(group = region)
p = ungroup(pairwise) %>% 
  left_join(nodes, by = c("from" = "id")) %>% 
  rename(from_index = index) %>% 
  left_join(nodes, by = c("to" = "id")) %>% 
  rename(to_index = index)
known = paste(p$from, p$to)
p = p %>% 
  filter(!(paste(to, from) %in% known))

fn = forceNetwork(Links = p, Nodes = nodes, Source = "from_index",
             Target = "to_index", Value = "distance", NodeID = "CatalogNumber", 
             fontFamily = "sans-serif", Group = "group", opacity = 0.8, zoom = TRUE, linkColour = "lightgrey", 
             fontSize = 21)
fn$x$nodes = left_join(fn$x$nodes, metadata, by = c("name" = "CatalogNumber"))
fn$x$options$clickAction = 'new Audio(d.SampleAudio).play()'
fn$x$nodes$name = paste0(fn$x$nodes$Country, ", ", fn$x$nodes$Year)
fn
write(fn, "folks-network.html")

# ----------------
# T-SNE
# ----------------
tsne_raw = Rtsne(features, 
                 perplexity = 30,
                 max_iter = 500,
                 verbose = TRUE,
                 check_duplicates = FALSE)

tsnedf = as.data.frame(tsne_raw$Y)
#tsnedf = as.data.frame(tsne_raw_long$Y)
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
library(jsonlite)
write(toJSON(to_export), "song_info.json")

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
                 perplexity = 10,
                 max_iter = 1000,
                 verbose = TRUE,
                 check_duplicates = FALSE)
