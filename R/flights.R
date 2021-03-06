## ---- load-pkgs
library(lubridate)
library(tidyverse)
library(tsibble)
library(forcats)
source("R/theme.R")

## ---- load-data
flights <- read_rds("data/flights.rds")

## ---- map-airlines
# devtools::install_github("heike/ggmapr")
library(ggmapr)
origin_dest <- flights %>% 
  distinct(origin, origin_state, dest, dest_state)
airports <- read_rds("data/airports.rds")
map_dat <- origin_dest %>% 
  left_join(airports, by = c("origin" = "faa")) %>% 
  rename(long = lon) %>% 
  shift(origin_state == "HI", shift_by = c(52.5, 5.5)) %>%
  scale(origin_state == "AK", scale = 0.3, set_to = c(-117, 27)) %>%
  rename(origin_lat = lat, origin_lon = long)  %>% 
  left_join(select(airports, faa, lon, lat), by = c("dest" = "faa")) %>% 
  rename(long = lon) %>% 
  shift(dest_state == "HI", shift_by = c(52.5, 5.5)) %>%
  scale(dest_state == "AK", scale = 0.3, set_to = c(-117, 27)) %>%
  rename(dest_lat = lat, dest_lon = long)

states <- states %>%
  shift(NAME == "Hawaii", shift_by = c(52.5, 5.5)) %>%
  scale(NAME == "Alaska", scale = 0.3, set_to = c(-117, 27)) %>%
  filter(lat > 20)

ggplot() +
  geom_polygon(data= states, aes(x = long, y = lat, group = group), 
    fill = "white", colour = "grey60") +
  geom_segment(data = map_dat, aes(
    x = origin_lon, y = origin_lat, xend = dest_lon, yend = dest_lat
  ), alpha = 0.2, size = 0.4, colour = "#762a83") +
  geom_point(data = map_dat, aes(x = origin_lon, y = origin_lat), 
    colour = "#f1a340", size  = 1.5) +
  coord_map("albers", parameters = c(30, 45)) +
  ggthemes::theme_map()

## ---- glimpse
glimpse(flights)

## ---- print
flights %>% select(flight, origin, sched_dep_datetime)

## ---- n938dn
n938dn <- flights %>% 
  filter(tailnum == "N938DN") %>% 
  left_join(map_dat) %>% 
  arrange(sched_dep_datetime) %>% 
  filter(sched_dep_datetime < as_date("20170102"))

ggplot() +
  geom_polygon(data= states, aes(x = long, y = lat, group = group), 
    fill = "white", colour = "grey60") +
  geom_segment(data = n938dn, aes(
    x = origin_lon, y = origin_lat, xend = dest_lon, yend = dest_lat
  ), colour = "#762a83", size = 1, alpha = 0.6, 
    arrow = arrow(length = unit(0.2, "inches"))
  ) +
  geom_point(data = n938dn, aes(x = origin_lon, y = origin_lat), 
    colour = "#f1a340", size  = 1.5) +
  geom_point(data = n938dn, aes(x = dest_lon, y = dest_lat), 
    colour = "#f1a340", size  = 1.5) +
  geom_label(data = n938dn, aes(x = origin_lon, y = origin_lat, label = origin_city_name), vjust = 1, hjust = 1.1) +
  geom_label(data = n938dn, aes(x = dest_lon, y = dest_lat, label = dest_city_name), vjust = 1, hjust = 1.1) +
  coord_map("albers", parameters = c(30, 45)) +
  ggthemes::theme_map()

## ---- dl771
dl771 <- flights %>% 
  filter(flight == "DL771") %>% 
  left_join(map_dat) %>% 
  arrange(sched_dep_datetime)

ggplot() +
  geom_polygon(data= states, aes(x = long, y = lat, group = group), 
    fill = "white", colour = "grey60") +
  geom_segment(data = dl771, aes(
    x = origin_lon, y = origin_lat, xend = dest_lon, yend = dest_lat
  ), colour = "#762a83", size = 1, alpha = 0.6, 
    arrow = arrow(length = unit(0.2, "inches"))
  ) +
  geom_point(data = dl771, aes(x = origin_lon, y = origin_lat), 
    colour = "#f1a340", size  = 1.5) +
  geom_point(data = dl771, aes(x = dest_lon, y = dest_lat), 
    colour = "#f1a340", size  = 1.5) +
  coord_map("albers", parameters = c(30, 45)) +
  ggthemes::theme_map()

## ---- tsibble
us_flights <- flights %>% 
  as_tsibble(
    index = sched_dep_datetime, key = id(flight, origin), 
    regular = FALSE
  )

## ---- print-tsibble
us_flights

## ---- filter
us_flights %>% 
  filter(sched_dep_datetime < yearmonth("201703"))

## ---- select
us_flights %>% 
  select(flight, origin, dep_delay)

## ---- summarise
us_flights %>% 
  summarise(avg_delay = mean(dep_delay))

## ---- index-by
us_flights %>% 
  index_by(dep_date = as_date(sched_dep_datetime))

## ----- index-sum
us_flights %>% 
  index_by(dep_date = as_date(sched_dep_datetime)) %>% 
  summarise(avg_delay = mean(dep_delay))

## ---- carrier-delayed
delayed_carrier <- us_flights %>% 
  mutate(delayed = dep_delay > 15) %>%
  group_by(carrier) %>% 
  index_by(year = year(sched_dep_datetime)) %>% 
  summarise(
    Ontime = sum(delayed == 0),
    Delayed = sum(delayed)
  ) %>% 
  gather(delayed, n_flights, Ontime:Delayed) %>% 
  print()

## ----- carrier-mosaic-bg
library(ggmosaic)
delayed_carrier %>% 
  mutate(carrier = fct_reorder(carrier, -n_flights)) %>% 
  ggplot() +
    geom_mosaic(
      aes(x = product(carrier), fill = delayed, weight = n_flights),
      alpha = 0.2
    ) +
    scale_fill_brewer(palette = "Dark2", name = "Delayed") +
    scale_x_productlist(name = "Carrier") +
    scale_y_productlist(name = "Delayed") +
    theme(legend.position = "bottom") +
    theme_remark()

## ----- carrier-mosaic
delayed_carrier %>% 
  mutate(carrier = fct_reorder(carrier, -n_flights)) %>% 
  ggplot() +
    geom_mosaic(aes(x = product(carrier), fill = delayed, weight = n_flights)) +
    scale_fill_brewer(palette = "Dark2", name = "Delayed") +
    scale_x_productlist(name = "Carrier") +
    scale_y_productlist(name = "Delayed") +
    theme(legend.position = "bottom") +
    theme_remark()

## ---- carrier1
us_flights %>% 
  mutate(delayed = dep_delay > 15) #<<

## ---- carrier2
us_flights %>% 
  mutate(delayed = dep_delay > 15) %>% 
  group_by(carrier) %>%  #<<
  index_by(year = year(sched_dep_datetime)) %>%  #<<
  summarise( #<<
    Ontime = sum(delayed == 0), #<<
    Delayed = sum(delayed) #<<
  ) #<<

## ---- carrier3
us_flights %>% 
  mutate(delayed = dep_delay > 15) %>% 
  group_by(carrier) %>% 
  index_by(year = year(sched_dep_datetime)) %>% 
  summarise(
    Ontime = sum(delayed == 0),
    Delayed = sum(delayed)
  ) %>% 
  gather(delayed, n_flights, Ontime:Delayed) #<<

## ---- nyc-flights
nyc_flights <- us_flights %>% 
  filter(origin %in% c("JFK", "LGA", "EWR"))

## ---- nyc-delay
nyc_delay <- nyc_flights %>% 
  mutate(delayed = dep_delay > 15) %>% 
  group_by(origin) %>% 
  index_by(sched_dep_date = as_date(sched_dep_datetime)) %>% 
  summarise(
    n_flights = n(),
    n_delayed = sum(delayed)
  ) %>% 
  mutate(pct_delay = n_delayed / n_flights) %>% 
  print()

## ---- nyc-delay-plot
nyc_delay %>% 
  ggplot(aes(x = sched_dep_date, y = pct_delay, colour = origin)) +
  geom_line() +
  facet_grid(origin ~ .) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  scale_colour_brewer(palette = "Dark2") +
  xlab("Departure date") +
  ylab("% of flight delay") +
  theme(legend.position = "bottom") +
  theme_remark()

## ----- nyc-weekly-ma
nyc_weekly <- nyc_delay %>% 
  group_by(origin) %>% 
  mutate(ma_delay = slide_dbl( #<<
    pct_delay, mean, .size = 7, .align = "center" #<<
  ))  #<<
nyc_weekly %>% select(origin, ma_delay)
  
## ----- nyc-weekly-plot
nyc_weekly %>% 
  ggplot(aes(x = sched_dep_date)) +
  geom_line(aes(y = pct_delay), colour = "grey80", size = 0.8) +
  geom_line(aes(y = ma_delay, colour = origin), size = 1) +
  facet_grid(origin ~ .) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  scale_colour_brewer(palette = "Dark2") +
  theme(legend.position = "bottom") +
  theme_remark() +
  xlab("Date") +
  ylab("Departure delay")

## ----- nyc-monthly-1
nyc_lst <- nyc_delay %>% 
  mutate(yrmth = yearmonth(sched_dep_date)) %>% 
  group_by(origin, yrmth) %>% 
  nest() %>% 
  print()

## ---- nyc-monthly-2
nyc_monthly <- nyc_lst %>% 
  group_by(origin) %>% 
  mutate(monthly_ma = slide_dbl(data, #<<
    ~ mean(.$pct_delay), .size = 2, .bind = TRUE#<<
  )) %>% #<<
  unnest(key = id(origin)) %>% 
  print()

## ----- nyc-monthly-plot-bg
nyc_monthly %>% 
  ggplot() +
  geom_line(aes(x = sched_dep_date, y = pct_delay), colour = "grey80", size = 0.8) +
  geom_line(aes(x = yrmth, y = monthly_ma, colour = origin), size = 1, alpha = 0.8) +
  facet_grid(origin ~ .) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  scale_colour_brewer(palette = "Dark2") +
  theme(legend.position = "bottom") +
  theme_remark() +
  xlab("Date") +
  ylab("Departure delay")

## ----- nyc-monthly-plot
nyc_monthly %>% 
  ggplot() +
  geom_line(aes(x = sched_dep_date, y = pct_delay), colour = "grey80", size = 0.8) +
  geom_line(aes(x = yrmth, y = monthly_ma, colour = origin), size = 1) +
  facet_grid(origin ~ .) +
  scale_y_continuous(labels = scales::percent, limits = c(0, 1)) +
  scale_colour_brewer(palette = "Dark2") +
  theme(legend.position = "bottom") +
  theme_remark() +
  xlab("Date") +
  ylab("Departure delay")

## ---- quantile
hr_qtl <- us_flights %>% 
  index_by(dep_datehour = floor_date(sched_dep_datetime, "hour")) %>% 
  summarise(    
    qtl50 = quantile(dep_delay, 0.5),
    qtl80 = quantile(dep_delay, 0.8),
    qtl95 = quantile(dep_delay, 0.95)
  ) %>% 
  mutate(
    hour = hour(dep_datehour), 
    wday = wday(dep_datehour, label = TRUE, week_start = 1),
    date = as_date(dep_datehour)
  ) %>% 
  gather(key = qtl, value = dep_delay, qtl50:qtl95) %>% 
  print()

## ---- draw-qtl-prep
break_cols <- c(
  "qtl95" = "#d7301f", 
  "qtl80" = "#fc8d59", 
  "qtl50" = "#fdcc8a"
)

qtl_label <- c(
  "qtl50" = "50%",
  "qtl80" = "80%", 
  "qtl95" = "95%" 
)

min_y <- hr_qtl %>% 
  filter(hour(dep_datehour) > 4) %>% 
  pull(dep_delay) %>%
  min()

## ---- draw-qtl-bg
hr_qtl %>% 
  filter(hour(dep_datehour) > 4) %>% 
  ggplot(aes(x = hour, y = dep_delay, group = date, colour = qtl)) +
  geom_hline(yintercept = 15, colour = "#9ecae1", size = 2) +
  geom_line(alpha = 0.1) +
  facet_grid(
    qtl ~ wday, scales = "free_y", 
    labeller = labeller(qtl = as_labeller(qtl_label))
  ) +
  xlab("Time of day") +
  ylab("Depature delay") + 
  scale_x_continuous(limits = c(0, 23), breaks = seq(6, 23, by = 6)) +
  scale_colour_manual(values = break_cols, guide = FALSE) +
  expand_limits(y = min_y) +
  theme_remark()

## ---- draw-qtl
hr_qtl %>% 
  filter(hour(dep_datehour) > 4) %>% 
  ggplot(aes(x = hour, y = dep_delay, group = date, colour = qtl)) +
  geom_hline(yintercept = 15, colour = "#9ecae1", size = 2) +
  geom_line(alpha = 0.8) +
  facet_grid(
    qtl ~ wday, scales = "free_y", 
    labeller = labeller(qtl = as_labeller(qtl_label))
  ) +
  xlab("Time of day") +
  ylab("Depature delay") + 
  scale_x_continuous(limits = c(0, 23), breaks = seq(6, 23, by = 6)) +
  scale_colour_manual(values = break_cols, guide = FALSE) +
  expand_limits(y = min_y) +
  theme_remark()
