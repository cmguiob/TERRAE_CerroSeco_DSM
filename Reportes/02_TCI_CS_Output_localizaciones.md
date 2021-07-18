---
title: "TCI - Cerro Seco / Suelos"
subtitle: "Localizaciones y perfiles"
author: "Carlos Guio"
date: "5.7.2021"
output:
  html_document:
    theme: journal
    highlight: tango
    keep_md: true
---



```r
knitr::opts_chunk$set(echo = TRUE, warning = FALSE, fig.showtext = T, fig.retina = 1, fig.align = 'center', dpi = 300, out.width = "75%")

library(tidyverse)
library(rgdal) #leer polígono
library(sf) #manipular objetos espaciales tipo sf
library(raster) #manipular objetos raster
library(osmdata) #obtener datos de osm
library(ggplot2)
library(aqp) #Munsell to HEX colors
library(showtext) #fuentes de goolge
library(colorspace) #lighten or darken colors
library(ggrepel) #etiquetas 
library(ggsn) #escala gráfica
library(gggibbous) #moons with grain size %
library(patchwork) #plot + inset
```

\

## Los datos

El levantamiento de suelos se realizó con colaboración de  miembros de la comunidad local: en la medición de perfiles, registro del color y la estructura. La base de datos está compuesta por 62 perfiles con información en diferente detalle: 

* 4 perfiles con datos completos de campo y laboratorio
* 27 perfiles con datos de campo parciales, e.g. profundidad, nomenclatura de horizontes y color.
* 31 perfiles con registro fotográfico.

Los perfiles de suelo estudiados en detalle y en campo se utilizaron para interpretar los perfiles que solo contaban con registro fotográfico. De esta interpretación se generalizaron dos tipos de secuencias de horizontes de suelos y paleosuelos, las cuales tienen relevancia para la infiltración de agua, el soporte de la vegetación y los procesos erosivos que modelan el paisaje.



```r
# Cargar datos de perfiles
hz <- readr::read_csv('https://raw.githubusercontent.com/cmguiob/TCI_CerroSeco_git/main/Datos/Suelos_CS_Horiz.csv')
```

```
## 
## -- Column specification --------------------------------------------------------
## cols(
##   .default = col_double(),
##   ID = col_character(),
##   NOMBRE = col_character(),
##   HZ = col_character(),
##   HZ_DEF = col_character(),
##   HZ_FORM = col_character(),
##   PED_TIPO = col_character(),
##   PED2_TIPO = col_character(),
##   PED_SIZ = col_character(),
##   PED2_SIZ = col_character(),
##   PED_GRADE = col_character(),
##   PED2_GRADE = col_character(),
##   REC = col_character(),
##   MACROP1 = col_character(),
##   MACROP2 = col_character(),
##   MX_H = col_character(),
##   CON_H = col_character(),
##   CON_TIPO = col_character(),
##   CON_SIZ = col_character(),
##   FRAG_TIPO = col_character(),
##   CLASE_TXT = col_character()
## )
## i Use `spec()` for the full column specifications.
```

```r
sitio <- readr::read_csv('https://raw.githubusercontent.com/cmguiob/TCI_CerroSeco_git/main/Datos/Suelos_CS_Sitio.csv')
```

```
## 
## -- Column specification --------------------------------------------------------
## cols(
##   ID = col_character(),
##   Foto = col_character(),
##   lat = col_double(),
##   long = col_double(),
##   ESP_AFL = col_double(),
##   ESP_SUELO = col_double(),
##   PAREN_1 = col_character(),
##   PAREN_2 = col_character(),
##   ROCA = col_character(),
##   SECUENCIA = col_character(),
##   SECUENCIA_DES = col_character()
## )
```

```r
#Select four profiles and relevant properties for plot
hz4 <- hz %>%
  dplyr::filter(ID %in% c("CS01", "CS02","CS03","CS04")) %>%
  dplyr::select(ID, BASE, TOPE, ESP, HZ, CON_POR, MX_H, MX_V, MX_C, CON_H, CON_V, CON_C, ARENA, LIMO, ARCILLA )

#Cargar poligono CS como sf
url_limite <- "https://raw.githubusercontent.com/cmguiob/TCI_CerroSeco_git/main/Datos_GIS/Poligonos/limite_CS_WGS84.geojson"
CSsf84 <- st_read(url_limite)
```

```
## Reading layer `limite_CS_WGS84' from data source `https://raw.githubusercontent.com/cmguiob/TCI_CerroSeco_git/main/Datos_GIS/Poligonos/limite_CS_WGS84.geojson' using driver `GeoJSON'
## Simple feature collection with 1 feature and 4 fields
## Geometry type: POLYGON
## Dimension:     XY
## Bounding box:  xmin: -74.17942 ymin: 4.543404 xmax: -74.15856 ymax: 4.571987
## Geodetic CRS:  WGS 84
```

```r
#Poligons were loaded first from local pc as .shp and then transformed to .geojson
#writeOGR(CS_limite, "limite_CS_WGS84.geojson", layer = "limite_CS_WGS84" driver = )

# Cargar poligonos mineria 2019 como sf
url_mineria <- ("https://raw.githubusercontent.com/cmguiob/TCI_CerroSeco_git/main/Datos_GIS/Poligonos/mineria_2019_CS_WGS84.geojson")
min2019sf <- st_read(url_mineria)
```

```
## Reading layer `mineria_2019_CS_WGS84' from data source `https://raw.githubusercontent.com/cmguiob/TCI_CerroSeco_git/main/Datos_GIS/Poligonos/mineria_2019_CS_WGS84.geojson' using driver `GeoJSON'
## Simple feature collection with 14 features and 12 fields
## Geometry type: POLYGON
## Dimension:     XY
## Bounding box:  xmin: -74.17826 ymin: 4.548972 xmax: -74.15194 ymax: 4.569002
## Geodetic CRS:  WGS 84
```

```r
# Cargar DEM y transformar a data frame para manipular con ggplot
url_DEM <- "https://github.com/cmguiob/TCI_CerroSeco_git/blob/main/Datos_GIS/DEM_derivados/DEM_CS_Clip_4326.tif?raw=true"
DEM_ras84 <- raster(url_DEM)
DEM_clip <- mask(DEM_ras84, min2019sf, inverse = TRUE)
DEM_df_clip <- as.data.frame(DEM_clip, xy = TRUE)
names(DEM_df_clip) <- c("long", "lat", "altitude")

#Crear objeto espacial sf de sitio 
sitio_sp84 <- sitio
if(is.data.frame(sitio_sp84) == TRUE)coordinates(sitio_sp84) <- ~  long + lat
proj4string(sitio_sp84) <- "+proj=longlat +datum=WGS84 +no_defs"
sitio_sf84 <- st_as_sf(sitio_sp84, coords = c("long", "lat"),crs = 4326)

#Extraer datos de elevacion y pegarlos a sf
alt <- raster::extract(DEM_clip, sitio_sp84)
sitio = cbind(sitio, alt)
sitio_sf84 = cbind(sitio_sf84, alt)

#Get osm data
calles <- getbb("Bogotá")%>% 
  opq()%>% 
  add_osm_feature(key = "highway", 
                  value = c("motorway", "primary", 
                            "secondary", "tertiary",
                            "residential", "living_street",
                            "footway")) %>%  osmdata_sf()
```




```r
# Calcular centroide
centro_sf <- st_centroid(CSsf84)

# Función para círculo
circleFun <- function(center=c(0,0), diameter=1, npoints=100, start=0, end=2, filled=TRUE){
  tt <- seq(start*pi, end*pi, length.out=npoints)
  dfc <- data.frame(
    x = center[1] + diameter / 2 * cos(tt),
    y = center[2] + diameter / 2 * sin(tt)
  )
  if(filled==TRUE) { 
    dfc <- rbind(df, center)
  }
  return(dfc)
}

# Aplicar función
circle <- circleFun(center = c(as.vector(centro_sf$geometry[[1]])), npoints = 1000,diameter = 0.039, filled = FALSE)
circle_sf <- SpatialPolygons(list(Polygons(list(Polygon(circle[,])), ID=1))) %>% st_as_sfc()
st_crs(circle_sf) = 4326

# Clip calles OSM 
cutout <- st_intersection(calles$osm_lines, circle_sf)
```

```
## although coordinates are longitude/latitude, st_intersection assumes that they are planar
```

## La distribución de los perfiles

Debido a la accesibilidad a diferentes zonas, los perfiles de suelo estudiados corresponden a exposiciones naturales, en cárcavas, a lo largo de una franja orientada SO-NE. En la figura se descatan cuatro perfiles, los cuales se estudiaron mediante técnicas de campo y laboratorio.

\ 


```r
# Posibles escalas de color
col_scp <- c('#6AB6AA', '#4B6E8E', '#F9C93C', '#DA7543')
col_ito <- c('#56B4E9', '#009E73',"#E69F00", "#D55E00")

# Obtener fuentes
font_add_google(name = "Roboto Condensed", family= "robotoc")
font_add_google(name = "Roboto", family= "roboto")


# Definir theme
theme_set(theme_minimal(base_family = "roboto"))

theme_update(panel.grid = element_blank(),
             axis.text = element_text(family = "robotoc",
                                        color = "#c3beb8"),
             axis.title = element_blank(),
             axis.ticks.x =  element_line(color = "#c3beb8", size = .7),
             axis.ticks.y.right =  element_line(color = "#c3beb8", size = .7),
             legend.position = c(0,0.85),
             legend.direction = "vertical", 
             legend.box = "horizontal",
             legend.title = element_text(size = 13, 
                                         face = "bold", 
                                         color = "grey20", 
                                         family = "roboto"),
             legend.text = element_text(size = 10, 
                                        color = "#c3beb8", 
                                        family = "robotoc",
                                        face = "bold"),
             legend.key.size = unit(0.8, "cm"))
```



```r
ggplot() +
  geom_sf(data = cutout,
          color = "#e2ddd6",
          size = .4)+
  geom_raster(data = DEM_df_clip, 
              aes(fill = altitude, 
                  x=long, 
                  y=lat))+
  scale_fill_gradient2(high= '#f2d29b', 
                       mid='#faf7ef', 
                       low= 'white', 
                       midpoint = 2820, 
                       na.value=NA,
                       guide = F) +
  geom_sf(data = CSsf84, 
          fill = NA,
          color = "#c3beb8",
          size = 0.7) +
  geom_sf(data = min2019sf, 
          fill = "grey30",
          col = "grey30") +
  geom_sf(data=sitio_sf84, 
          aes(col = SECUENCIA), 
          size = 1.5) +
  scale_color_manual(values= col_scp, 
                     name = "Secuencia tipo")+
  # Etiquetas de puntos
  geom_text_repel( data = sitio_sf84[1:4,],   
                   aes(label = ID, geometry = geometry, col = SECUENCIA),
                   size = 3.5,
                   family = "robotoc",
                   fontface = "bold",
                   force_pull  = -0.2,
                   nudge_x = -0.1,
                   direction = "y",
                   box.padding = 0.5,
                   stat = "sf_coordinates",
                   segment.square = FALSE,
                   segment.curvature = -0.3,
                   segment.angle = 30, 
                   segment.ncp = 10,
                   show.legend = FALSE) +
  # Escala gráfica
  ggsn::scalebar(data = CSsf84, 
           dist = 0.5, 
           dist_unit = "km",
           transform = TRUE,
           st.size = 3,
           height=0.015,
           border.size = 0.05,
           box.color = "#e2ddd6",
           box.fill = c("grey20","#e2ddd6"),
           family = "robotoc")+
  # Notas de texto
  annotate(geom = "text", 
           x = -74.168, y = 4.57, 
           label = "Bogotá \n(Ciudad Bolivar)", 
           hjust = "left", 
           size = 4.5,
           family = "roboto",
           fontface = "bold",
           col = "#c3beb8") +
  annotate(geom = "text", 
           x = -74.163, y = 4.548, 
           label = "Minería", 
           size = 3.5,
           family = "roboto",
           fontface = "bold",
           col = "grey30") +
  annotate(geom = "curve", 
           x = -74.163, 
           y = 4.549,
           xend = -74.156, 
           yend = 4.552, 
           curvature = -.3,
           col = "grey30",
           size = 0.5) +
  # Modificación ejes
  scale_x_continuous(breaks=c(-74.18, -74.17, -74.16))+
  scale_y_continuous(breaks=c(4.55,4.56,4.57))+
  # Eje de coordenadas y a la derecha
  coord_sf(label_axes = list(bottom = "E", right = "N", left = NA, top = NA),
           clip = "off") + 
  # Tamaño de ícono color
  guides(color = guide_legend(override.aes = list(size = 3.5))) 
```

<img src="02_TCI_CS_Output_localizaciones_files/figure-html/map-1.png" width="75%" style="display: block; margin: auto;" />

\

## Los perfiles

Los cuatro perfiles estudiados en detalle se presentan como modelos con propiedades de campo. En ellos se observan dos secuencias de suelos contrastantes en el paisaje.


```r
# Create color variables
hz4$RGBmx <- munsell2rgb(hz4$MX_H, hz4$MX_V, hz4$MX_C)
hz4$RGBco <-munsell2rgb(hz4$CON_H,hz4$CON_V , hz4$CON_C)

#Factor horizons to order
hz_bdf <- hz4 %>%
  dplyr::mutate(ID_HZ = paste(ID, HZ), #this orders by rownumber
         ID_HZ2 = factor(ID_HZ, ID_HZ)) %>%
  rowwise() %>%
  dplyr::mutate(GRUESOS = sum(ARENA,LIMO))%>%
  dplyr::mutate(GRANU_TOT = sum(ARENA + LIMO + ARCILLA))
  
hz_jdf <-  hz4 %>%
  dplyr::mutate(ID = factor(ID),
         ID_HZ = paste(ID, HZ), 
         ID_HZ2 = factor(ID_HZ, ID_HZ))%>% #order by rwonumber
  dplyr::mutate(CON_POR = ifelse(CON_POR == 0, 1, CON_POR), #handle 0% concen.
         n = 5*ESP*CON_POR / 100, #n for random number generation
         mean = 0.5*(BASE - TOPE), # mean for random number generation
         sd = 0.1*ESP)%>% #standard deviation for random number geneartion
  dplyr::mutate(samples = pmap(.[c("n","mean","sd")], rnorm))%>%
  unnest(samples)

# Points for jitter:
# mean: BASE - TOPE/2, sd = x*ESP, n = 5*CON_POR*ESP/100
# The problem with n: calculated with a multiple three rule, assuming that 1cm 
# which is 100% saturated has 5 concentrations, i.e. the size of concentrations is 2mm

head(hz_bdf, 10)
```

```
## # A tibble: 10 x 21
## # Rowwise: 
##    ID     BASE  TOPE   ESP HZ    CON_POR MX_H   MX_V  MX_C CON_H CON_V CON_C
##    <chr> <dbl> <dbl> <dbl> <chr>   <dbl> <chr> <dbl> <dbl> <chr> <dbl> <dbl>
##  1 CS01     35     0    35 A           0 10YR      4     2 2.5Y      5     8
##  2 CS01     80    35    45 E           2 10YR      5     1 2.5Y      5     8
##  3 CS01     90    80    10 Bt         80 10YR      4     1 10YR      2     1
##  4 CS01    140    90    50 B/C        10 10YR      5     1 10YR      2     1
##  5 CS01    170   140    30 Bn1         5 10YR      5     1 10YR      2     1
##  6 CS01    177   170     7 Bt1        80 2.5Y      4     1 10YR      2     1
##  7 CS01    250   177    73 C1          5 10YR      7     8 7.5YR     5     8
##  8 CS01    280   250    30 R           0 10YR      8     3 7.5YR     5     8
##  9 CS02     25     0    25 A           0 7.5YR     4     2 10YR      7     8
## 10 CS02     50    25    25 R           0 7.5YR     8     2 7.5YR     5     8
## # ... with 9 more variables: ARENA <dbl>, LIMO <dbl>, ARCILLA <dbl>,
## #   RGBmx <chr>, RGBco <chr>, ID_HZ <chr>, ID_HZ2 <fct>, GRUESOS <dbl>,
## #   GRANU_TOT <dbl>
```
 
\


```r
df_moon <- data.frame(x = 0, y = 0, ratio = c(0.25, 0.75), right = c(TRUE, FALSE))  

p_moon <-  ggplot() +
  geom_moon(data = df_moon[1,], 
            aes(x = x , y = y ,ratio = ratio, right = right), 
            size = 10, 
            fill = darken("#c3beb8", 0.3, space = "HCL"),
            color = darken("#c3beb8", 0.3, space = "HCL"))+
  geom_text(data = df_moon[1,],
            aes(x = x, y = y + 0.3, label = "25% arcilla"),
            size = 3.5,
            family = "roboto",
            fontface = "bold",
            col = darken("#c3beb8", 0.3, space = "HCL"))+
    annotate(geom = "curve", 
             x = 0.06, 
             y = 0,
             xend = 0.1, 
             yend = 0.2, 
             curvature = 0.4,
             col = darken("#c3beb8", 0.3, space = "HCL"),
             size = 0.5)+
    geom_moon(data = df_moon[2,], 
            aes(x = x , y = y ,ratio = ratio, right = right), 
            size = 10, 
            fill = lighten("#c3beb8", 0.1, space = "HCL"),
            color = lighten("#c3beb8", 0.1, space = "HCL"))+
  geom_text(data = df_moon[2,],
            aes(x = x, y = y - 0.3, label = "75% arena & limo"),
            size = 3.5,
            family = "roboto",
            fontface = "bold",
            col = lighten("#c3beb8", 0.1, space = "HCL")) +
    annotate(geom = "curve", 
             x = -0.06, 
             y = 0,
             xend = -0.1, 
             yend = -0.2, 
             curvature = 0.4,
             col = lighten("#c3beb8", 0.1, space = "HCL"),
             size = 0.5)+
    lims(x = c(-0.5,0.5), y = c(-1, 1))+
  theme_void()
```

 

```r
p_perfiles <- ggplot(hz_bdf, aes(x = reorder(ID, desc(ID)), y = ESP, fill = forcats::fct_rev(ID_HZ2))) + 
  geom_bar(position="stack", stat="identity", width = 0.35) +
  scale_fill_manual(values = rev(hz_bdf$RGBmx),
                    guide = FALSE) +
  geom_text_repel( data = hz_bdf,   
                   aes(y = BASE - (ESP/3), label = HZ),
                   color = darken(hz_bdf$RGBmx, .2, space = "HCL"),
                   size = 3,
                   face = "bold",
                   family = "robotoc",
                   hjust = 0,
                   direction = "y",
                   nudge_x = 0.3,
                   nudge_y = -3,
                   segment.size = .5,
                   segment.square = TRUE,
                   segment.curvature = 0.1,
                   segment.angle = 40,
                   segment.alpha = 0.5,
                   box.padding = 0.3)+
  #y: location from where jitter spreads out vertically, i,e. from the base minus half the tickness
  geom_jitter(data = hz_jdf, aes(x = ID, y = BASE - (ESP/2)),  
              width = 0.15, 
              # height: how far jitter spreads out to each side, i.e. half the tickness
              height = hz_jdf$ESP*0.5,
              size = 0.3,
              col = hz_jdf$RGBco,
              shape = 16)+
  geom_moon(data = hz_bdf %>% dplyr::filter(!is.na(ARCILLA)), aes(x = ID, 
                               y = BASE - (ESP/2), 
                               ratio = ARCILLA/100), 
             size = 4,
             right = TRUE,
             fill = darken("#c3beb8", 0.3, space = "HCL"),
             color = darken("#c3beb8", 0.3, space = "HCL"),
             position = position_nudge(x = -0.3))+
  geom_moon(data = hz_bdf %>% dplyr::filter(!is.na(ARENA)), aes(x = ID, 
                               y = BASE - (ESP/2), 
                               ratio = GRUESOS/100), 
             size = 4,
             right = FALSE,
             fill = lighten("#c3beb8", 0.1, space = "HCL"),
             color = lighten("#c3beb8", 0.1, space = "HCL"),
             position = position_nudge(x = -0.3))+
  geom_hline(yintercept = 0, col = '#f2d29b')+
  scale_y_reverse(breaks = c(0,100,200,300,400,500), 
                  labels=c("0", "100", "200", "300", "400", "500\ncm"))+
  scale_x_discrete(position = "top") +
  theme(axis.text.x = element_text(family = "robotoc",
                           colour = c('#DA7543','#DA7543','#4B6E8E', '#6AB6AA'),
                           face = "bold"),
               axis.ticks.x =  element_blank(),
        panel.grid.major.y = element_line(color = "#c3beb8", size = .4, linetype = c("13"))) +
  coord_cartesian(clip = "off")
```


```r
p_perfiles + inset_element(p_moon, 0.62, -0.17, 1.12, 0.53) # l, b, r, t
```

<img src="02_TCI_CS_Output_localizaciones_files/figure-html/layout_perfiles-1.png" width="75%" style="display: block; margin: auto;" />
