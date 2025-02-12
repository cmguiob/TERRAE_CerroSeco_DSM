
library(tidyverse)
library(aqp)
library(sp)
library(lattice)
library(colorspace)
library(showtext) #google fonts
library(soilDB)
library(latticeExtra)

knitr::opts_chunk$set(include = FALSE, echo = FALSE, warning = FALSE, message = FALSE, fig.align="center", fig.showtext = TRUE, fig.retina = 1, dpi = 300, out.width = "75%")

showtext_auto()



# Cargar datos de perfiles
hz <- readr::read_csv('https://raw.githubusercontent.com/cmguiob/TCI_CerroSeco_git/main/Datos/Suelos_CS_Horiz.csv')

sitio <- readr::read_csv('https://raw.githubusercontent.com/cmguiob/TCI_CerroSeco_git/main/Datos/Suelos_CS_Sitio.csv')

#Select four profiles and relevant properties for plot
hz4_temp1 <- hz[1:23,]


hz4_temp2 <- hz %>%
  dplyr::filter(ID %in% c("CS01", "CS02","CS03","CS04")) %>%
  dplyr::filter(!is.na(ARENA)) %>%  
  dplyr::select(ID, HZ, ARENA, LIMO, ARCILLA) 
  
vars_rosetta <- names(hz4_temp2)[3:5]

# ksat está en log10 de cm/dia
res_rosetta <- ROSETTA(hz4_temp2, vars = vars_rosetta, v = '3') 

hz4 <- left_join(hz4_temp1, 
                 res_rosetta %>%
                      select(-ARENA, -LIMO, -ARCILLA), 
                 by = c("ID", "HZ"))



# For loop, for each horizon
res <- lapply(1:nrow(res_rosetta), function(i) {
  
  # model bounds are given in kPA of suction
  vg <- KSSL_VG_model(VG_params = res_rosetta[i, ], phi_min = 10^-3, phi_max=10^6)
  
  # extract curve and add texture ID
  m <- vg$VG_curve
  m$HZ <- res_rosetta$HZ[i]
  m$ID <- res_rosetta$ID[i]
  
  return(m)
})

res <- do.call('rbind', res)



# Custom panel function (controls gridlines in panels)
panel.depth_function2 <- function (x, y, id, upper = NA, lower = NA, subscripts = NULL, 
          groups = NULL, sync.colors = FALSE, cf = NA, cf.col = NA, 
          cf.interval = 20, ...) 
{
  panel.grid(h = -1, v = -1, lty = 3, col = "#DAD7D6")
  superpose.line <- trellis.par.get("superpose.line")
  if (length(y) > length(x)) {
    if (missing(id)) {
      stop("must provide a profile id")
    }
    if (!missing(groups)) {
      d <- data.frame(prop = x, bnd = y, upper = upper[subscripts], 
                      lower = lower[subscripts], groups = groups[subscripts], 
                      id = id[subscripts])
    }
    else {
      d <- data.frame(prop = x, bnd = y, upper = upper[subscripts], 
                      lower = lower[subscripts], groups = factor(1), 
                      id = id[subscripts])
    }
    by(d, d$id, .make.segments, ...)
  }
  else {
    if (!missing(upper) & !missing(lower)) {
      if (!missing(groups) & !missing(subscripts)) {
        d <- data.frame(yhat = x, top = y, upper = upper[subscripts], 
                        lower = lower[subscripts], groups = groups[subscripts])
        ll <- levels(d$groups)
        n_groups <- length(ll)
      }
      if (missing(groups)) {
        fake.groups <- factor(1)
        d <- data.frame(yhat = x, top = y, upper = upper[subscripts], 
                        lower = lower[subscripts], groups = fake.groups)
        ll <- levels(d$groups)
        n_groups <- length(ll)
      }
      if (sync.colors) 
        region.col <- rep(superpose.line$col, length.out = n_groups)
      else region.col <- rep(grey(0.7), length.out = n_groups)
      by(d, d$groups, function(d_i) {
        m <- match(unique(d_i$group), ll)
        d_i <- d_i[which(!is.na(d_i$upper) & !is.na(d_i$lower)), 
        ]
        panel.polygon(x = c(d_i$lower, rev(d_i$upper)), 
                      y = c(d_i$top, rev(d_i$top)), col = region.col[m], 
                      border = NA, ...)
      })
    }
    else {
      if (missing(groups)) {
        fake.groups <- factor(1)
        d <- data.frame(yhat = x, top = y, groups = fake.groups)
      }
      else {
        d <- data.frame(yhat = x, top = y, groups = groups[subscripts])
      }
      ll <- levels(d$groups)
      n_groups <- length(ll)
    }
    line.col <- rep(superpose.line$col, length.out = n_groups)
    line.lty <- rep(superpose.line$lty, length.out = n_groups)
    line.lwd <- rep(superpose.line$lwd, length.out = n_groups)
    by(d, d$groups, function(d_i) {
      m <- match(unique(d_i$group), ll)
      panel.lines(d_i$yhat, d_i$top, lwd = line.lwd[m], 
                  col = line.col[m], lty = line.lty[m])
    })
  }
  if (!missing(cf)) {
    d$cf <- cf[subscripts]
    by(d, d$groups, function(d_i) {
      m <- match(unique(d_i$group), ll)
      if (is.na(cf.col)) {
        cf.col <- line.col[m]
      }
      cf.approx.fun <- approxfun(d_i$top, d_i$cf, method = "linear")
      y.q95 <- quantile(d_i$top, probs = c(0.95), na.rm = TRUE)
      a.seq <- seq(from = 2, to = y.q95, by = cf.interval)
      a.seq <- a.seq + ((m - 1) * cf.interval/4)
      a.CF <- cf.approx.fun(a.seq)
      a.text <- paste(round(a.CF * 100), "%")
      not.na.idx <- which(!is.na(a.CF))
      a.seq <- a.seq[not.na.idx]
      a.text <- a.text[not.na.idx]
      unit <- gpar <- NULL
      grid.text(a.text, x = unit(0.99, "npc"), y = unit(a.seq, 
                                                        "native"), just = "right", gp = gpar(font = 3, 
                                                                                             cex = 0.8, col = cf.col))
    })
  }
}

# Obtener fuentes
font_add_google(name = "Roboto Condensed", family= "robotoc")
font_add_google(name = "Roboto", family= "roboto")

# Other trellis parameters
# Use to explore: str(trellis.par.get(), max.level = 2)


#Style for curves plot
sty_c <- list()
sty_c$strip.border$col <- NA
sty_c$strip.background$col <- NA
sty_c$superpose.line$lwd <- 2
sty_c$superpose.line$col <- c("#D0CBC5", "#C9C4BE", "#c3beb8", "#AEA9A3", "#99958F", "#85817A", "#726D67")
sty_c$layout.heights$strip <-1.5
sty_c$grid.pars$fontfamily <- "roboto"
sty_c$axis.components$right$tck <- 0
sty_c$axis.components$left$tck <- 0.5
sty_c$axis.components$bottom$tck <- 0.5
sty_c$axis.components$top$tck <- 0
sty_c$axis.components$top$text <- NA
sty_c$axis.line$col <- darken("#F5F2F1", 0.3, space = "HCL")
sty_c$par.ylab.text$col = darken("#F5F2F1", 0.3, space = "HCL")
sty_c$par.ylab.text$fontfamily = "roboto"
sty_c$par.xlab.text$col = darken("#F5F2F1", 0.3, space = "HCL")
sty_c$par.xlab.text$fontfamily = "roboto"
sty_c$axis.text$col = darken("#F5F2F1", 0.3, space = "HCL")
sty_c$axis.text$fontfamily = "robotoc"


#Style for profile plots
sty_p <- list()
sty_p$strip.border$col <- NA
sty_p$strip.background$col <- NA
sty_p$superpose.line$col <- c('#6AB6AA', '#4B6E8E', '#DA7543', '#DA7543')
sty_p$superpose.line$lty <- c(1,1,1,2) #property lines
sty_p$superpose.line$lwd <- 2.5
sty_p$layout.heights$strip <-1.5
sty_p$grid.pars$fontfamily <- "roboto"
sty_p$axis.components$right$tck <- 0
sty_p$axis.components$left$tck <- 0.5
sty_p$axis.components$bottom$tck <- 0.5
sty_p$axis.line$col <- darken("#F5F2F1", 0.3, space = "HCL")
sty_p$par.ylab.text$col = darken("#F5F2F1", 0.3, space = "HCL")
sty_p$par.ylab.text$fontfamily = "roboto"
sty_p$axis.text$col = darken("#F5F2F1", 0.3, space = "HCL")
sty_p$axis.text$fontfamily = "robotoc"





plot_curvas<- xyplot(
  phi ~ theta | ID, data = res, groups = HZ,
    type = c('l'),
  panel = function(...) {panel.xyplot(...)
                         panel.grid(lty = 3, col = "#DAD7D6")},
  scales = list(alternating=1, 
                x=list(tick.number=3), 
                y=list(log=10, tick.number=5), 
                cex = 0.8), 
  yscale.components = yscale.components.logpower, 
  ylab = list(label = 'Potencial matricial (-kPa)', fontsize = 9.5), 
  xlab = list(label = expression(Contenido~volumétrico~agua~~(cm^3/cm^3)), fontsize = 9.5), 
  par.settings = sty_c, 
  strip=strip.custom(bg= NA, 
                          par.strip.text=list(font=2, 
                                              cex=1, 
                                              col= darken("#F5F2F1", 
                                                          0.5, 
                                                          space = "HCL"))), 
  as.table = TRUE,
    layout = c(4,1))

plot_curvas



#Crear colección
depths(hz4) <- ID ~ TOPE + BASE 
site(hz4) <- sitio

#Inicializar coordenadas
coordinates(hz4) <- ~  long + lat
aqp::proj4string(hz4) <- '+init=epsg:4326 +proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0'

#Crear grupos para perfiles hidro
CShidro <- slab(hz4, fm= ID ~ ARENA + LIMO + ARCILLA + DENS_AP + KSmedia_cmd + ksat)

CShg <- make.groups(CS01 = CShidro[CShidro$ID == "CS01",], CS02 = CShidro[CShidro$ID == "CS02",], CS03 = CShidro[CShidro$ID== "CS03",], CS04 = CShidro[CShidro$ID== "CS04",])

#Crear grupos para perfiles bio
CSbio <- slab(hz4, fm= ID ~ pH + CO + BT + P + Si_OAA + CIC)

CSbg <- make.groups(CS01 = CSbio[CSbio$ID == "CS01",], CS02 = CSbio[CSbio$ID == "CS02",], CS03 = CSbio[CSbio$ID== "CS03",], CS04 = CSbio[CSbio$ID== "CS04",])


#Crear grupos para perfiles
CSero <- slab(hz4, fm= ID ~ LIMO + CO + Na + Ca_Mg + CE + pH)

CSeg <- make.groups(CS01 = CSero[CSero$ID == "CS01",], CS02 = CSero[CSero$ID == "CS02",], CS03 = CSero[CSero$ID== "CS03",], CS04 = CSero[CSero$ID== "CS04",])





# Nombres para paneles
strip_names <-c( "Arena %", "Limo %","Arcilla %","Densidad", "Ks cm/día", "Ks ROSETTA")

plot_hidro <- xyplot(top ~ p.q50 | variable, 
       groups = which,
       data=CShg,
       ylab=list(label ='Profundidad (cm)', fontsize = 9.5),
       xlab=list(label = ""),
       lower=CShg$p.q25, upper=CShg$p.q75, ylim=c(400,-2),
       panel=panel.depth_function2,
       sync.colors=TRUE,
       par.settings= sty_p,
       prepanel=prepanel.depth_function,
       layout=c(6,1), 
       strip=strip.custom(bg= NA, 
                          par.strip.text=list(font=2, 
                                              cex=0.7, 
                                              col= darken("#F5F2F1", 
                                                          0.5, 
                                                          space = "HCL")),
                          factor.levels=strip_names),
       scales=list(x=list(tick.number=3, alternating=1, relation='free', cex = 0.6), 
                   y = list(tick.number=6)),
       auto.key=list(columns=4, 
                     lines=TRUE, 
                     points=FALSE, 
                     col = darken("#F5F2F1", 0.3, space = "HCL"),
                     size = 2.5,
                     font = 2)) #legend

plot_hidro



# Nombres para paneles
strip_names <-c( "pH", "CO %","Bases cmol/kg","P ppm","Si -ox % ", "CIC")

plot_bio <- xyplot(top ~ p.q50 | variable, 
       groups = which,
       data=CSbg,
       ylab=list(label ='Profundidad (cm)', fontsize = 9.5),
       xlab=list(label = ""),
       lower=CSbg$p.q25, upper=CSbg$p.q75, ylim=c(200,-2),
       panel=panel.depth_function2,
       sync.colors=TRUE,
       par.settings= sty_p,
       prepanel=prepanel.depth_function,
       layout=c(6,1), 
       strip=strip.custom(bg= NA, 
                          par.strip.text=list(font=2, 
                                              cex=0.7, 
                                              col= darken("#F5F2F1", 
                                                          0.5, 
                                                          space = "HCL")),
                          factor.levels=strip_names),
       scales=list(x=list(tick.number=3, alternating=1, relation='free', cex = 0.6), 
                   y = list(tick.number=6)),
       auto.key=list(columns=4, 
                     lines=TRUE, 
                     points=FALSE, 
                     col = darken("#F5F2F1", 0.3, space = "HCL"),
                     size = 2.5,
                     font = 2)) #legend
plot_bio



strip_names <-c( "Limo %","CO %" ,"Na cmol/Kg", "Ca:Mg","CE dS/m","pH")

plot_ero <- xyplot(top ~ p.q50 | variable, 
       groups = which,
       data=CSeg,
       ylab=list(label ='Profundidad (cm)', fontsize = 9.5),
       xlab=list(label = ""),
       lower=CSeg$p.q25, upper=CSeg$p.q75, ylim=c(400,-2),
       panel=panel.depth_function2,
       sync.colors=TRUE,
       par.settings= sty_p,
       prepanel=prepanel.depth_function,
       layout=c(6,1), 
       strip=strip.custom(bg= NA, 
                          par.strip.text=list(font=2, 
                                              cex=0.7, 
                                              col= darken("#F5F2F1", 
                                                          0.5, 
                                                          space = "HCL")),
                          factor.levels=strip_names),
       scales=list(x=list(tick.number=3, alternating=1, relation='free', cex = 0.6), 
                   y = list(tick.number=6)),
       auto.key=list(columns=4, 
                     lines=TRUE, 
                     points=FALSE, 
                     col = darken("#F5F2F1", 0.3, space = "HCL"),
                     size = 2.5,
                     font = 2)) #legend

plot_ero


png(filename= here::here("Graficas","propiedades_hidro.png"),
    type="cairo",
    width = 8,
    height = 5.5,
    units = "in",
    pointsize=1, 
    res=300)
 
print(plot_hidro)

dev.off()

png(filename= here::here("Graficas","propiedades_bio.png"),
    type="cairo",
    width = 8,
    height = 5.5,
    units = "in",
    pointsize=1, 
    res=300)
 
print(plot_bio)

dev.off()

png(filename= here::here("Graficas","propiedades_erosion.png"),
    type="cairo",
    width = 8,
    height = 5.5,
    units = "in",
    pointsize=1, 
    res=300)
 
print(plot_ero)

dev.off()

png(filename= here::here("Graficas","curvas_retencion.png"),
    type="cairo",
    width = 7,
    height = 5.5,
    units = "in",
    pointsize=1, 
    res=300)
 
print(plot_curvas)

dev.off()



