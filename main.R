# =============================================================================
# CROATIA FOREST CHANGE DETECTION - GEE World Dynamic Dataset V1
# =============================================================================


# 1. PACKAGE SETUP
# ================
library(rgee)
library(terra)
library(sf)
library(geodata)
library(elevatr)
library(ggplot2)
library(rayshader)
library(magick)
library(googledrive)

main_dir <- getwd()



# 2. INITIALIZE GOOGLE EARTH ENGINE
# =================================

ee_Initialize()

# Define country boundary
croatia <- ee$FeatureCollection("USDOS/LSIB_SIMPLE/2017")$
    filter(ee$Filter$eq("country_na", "Croatia"))


# 3. FOREST DATA EXTRACTION
# =====================================================
get_forest_data <- function(year) {
    start_date <- paste0(year, "-05-01")
    end_date <- paste0(year, "-09-30")

    cat("Processing", year, "growing season...\n")


    dw_collection <- ee$ImageCollection("GOOGLE/DYNAMICWORLD/V1")$
        filterDate(start_date, end_date)$
        filterBounds(croatia)

    image_count <- dw_collection$size()$getInfo()
    cat("Found", image_count, "images for", year, "\n")

    # Extract trees probability and convert to percentage
    trees_median <- dw_collection$select("trees")$median()
    trees_percent <- trees_median$multiply(100)$clip(croatia)

    return(trees_percent)
}

# 4. GET DATA FOR BOTH YEARS
# ==========================
baseline_year <- 2016
final_year <- 2024

forest_2016 <- get_forest_data(baseline_year)
forest_2024 <- get_forest_data(final_year)


# 5. CALCULATE CHANGE DETECTION
# =============================
forest_change_raw <- forest_2024$subtract(forest_2016)

# Create change classification
change_classification <- ee$Image(0)$
    where(forest_change_raw$gt(15), 1)$     # Forest Gain
    where(forest_change_raw$lt(-15), 2)$    # Forest Loss
    where(forest_2016$gt(70)$And(forest_2024$gt(70)), 3)$  # Stable Forest
    where(forest_2016$lt(30)$And(forest_2024$lt(30)), 4)   # Stable Non-Forest


# 6. EXPORT DATA
# ===========================
export_forest_data <- function() {

    # Export change classification
    task <- ee$batch$Export$image$toDrive(
        image = change_classification,
        description = "croatia_forest_change_2016_2024",
        folder = "Earth_Engine_Exports",
        fileNamePrefix = "croatia_change_final",
        scale = 100,
        region = croatia$geometry()$bounds(),
        maxPixels = 1e9
    )
    task$start()
    cat("Export started! Monitor at: https://code.earthengine.google.com/tasks\n")
}

# Run export
# export_forest_data()


# 7. LOAD AND PREPARE DATA (AFTER DOWNLOAD)
# =========================================
# Run this section after downloading from Google Drive

# Load the change classification
# drive_download(drive_get("croatia_change_final.tif"))
change_raster <- rast("croatia_change_final.tif")


# 8. ADMINISTRATIVE BOUNDARIES AND ELEVATION DATA
# =================================================================

# Get Croatia administrative boundaries
croatia_sf <- geodata::gadm(
    country = "HRV",
    level = 0,
    path = main_dir
) |> sf::st_as_sf()

# Use WGS84 geographic coordinate system
target_crs <- "EPSG:4326"

# Obtain high-resolution elevation data
dem_raw <- elevatr::get_elev_raster(
    locations = croatia_sf,
    z = 9,
    clip = "locations"
) |>
    terra::rast() |>
    terra::crop(croatia_sf, mask = TRUE) |>
    terra::project(target_crs)

# 9. ACHIEVING SPATIAL ALIGNMENT
# ========================================================

# Crop change data to Croatia boundaries first
change_croatia <- terra::crop(change_raster, croatia_sf, mask = TRUE)

# Resample change data to match DEM grid exactly
# This ensures identical extent, resolution, and cell alignment
change_aligned <- terra::resample(
    x = change_croatia,
    y = dem_raw,
    method = "near"
) |> terra::project(target_crs)


# 10. TRANSFORM DATA FOR VISUALIZATION
# ======================================================

# Transform forest change data into dataframe
change_df <- as.data.frame(
    change_aligned,
    xy = TRUE,
    na.rm = TRUE
)
names(change_df)[3] <- "change_type"

# Create meaningful labels for change categories
change_df$change_label <- factor(
    change_df$change_type,
    levels = c(0, 1, 2, 3, 4),
    labels = c("Mixed Forest Cover", "Forest Gain", "Forest Loss",
               "Persistent Forest", "Non-Forest Areas")
)

# Prepare elevation data for height mapping
dem_df <- dem_raw |>
    as.data.frame(xy = TRUE, na.rm = TRUE)
names(dem_df)[3] <- "elevation"



# 11. DEFINE COLORS FOR CHANGE CATEGORIES
# ==========================================


change_colors <- c(
    "Mixed Forest Cover" = "#95A472",
    "Forest Gain" = "#00E676",
    "Forest Loss" = "#FF1744",
    "Persistent Forest" = "#1B5E20",
    "Non-Forest Areas" = "#D2B48C"
)


# 12. CREATE MAPS
# =========================================

# Main change map for 3D
main_map <- ggplot(change_df, aes(x = x, y = y, fill = change_label)) +
    geom_raster(interpolate = TRUE) +
    scale_fill_manual(values = change_colors, na.value = "transparent") +
    coord_sf(crs = target_crs, expand = FALSE) +
    theme_void() +
    theme(
        plot.background = element_rect(fill = "white", color = NA),
        panel.background = element_rect(fill = "white", color = NA),
        legend.position = "none",
        plot.margin = unit(c(0, 0, 0, 0), "lines")
    )

# Elevation map for height
dem_map <- ggplot(dem_df, aes(x = x, y = y, fill = elevation)) +
    geom_raster(interpolate = TRUE) +
    scale_fill_gradientn(colors = "white") +
    guides(fill = "none") +
    coord_sf(crs = target_crs, expand = FALSE) +
    theme_void() +
    theme(
        plot.background = element_rect(fill = "white", color = NA),
        panel.background = element_rect(fill = "white", color = NA),
        legend.position = "none"
    )

# 13. CREATE 3D VISUALIZATION
# =======================================================

# Download lighting
hdri_url <- "https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/4k/brown_photostudio_02_4k.hdr"
hdri_file <- "lighting.hdr"


if (!file.exists(hdri_file)) {
    try(download.file(
        url = hdri_url,
        destfile = hdri_file,
        mode = "wb"
    ))
}


options(rgl.useNULL = TRUE)
library(rgl)
rgl::rgl.init()

rayshader::plot_gg(
  ggobj = main_map,
  ggobj_height = dem_map,
  width = 9,
  height = 9,
  windowsize = c(600, 600),
  scale = 100,
  shadow = TRUE,
  shadow_intensity = 0.7,
  phi = 35,
  theta = 315,
  zoom = 0.6,
  multicore = FALSE,
  background = "white"
)

# Render
rayshader::render_highquality(
    filename = "croatia_forest_change.png",
    preview = FALSE,
    light = FALSE,
    environment_light = hdri_file,
    intensity = 1,
    rotate_env = 90,
    parallel = TRUE,
    width = 3200,
    height = 3200,
    samples = 200,
    interactive = FALSE
)

# Create legend
create_forest_legend <- function() {

    dummy_data <- data.frame(
        x = 1:5,
        y = 1,
        category = factor(c("Forest Gain", "Forest Loss", "Persistent Forest",
                            "Mixed Forest Cover", "Non-Forest Areas"),
                          levels = c("Forest Gain", "Forest Loss", "Persistent Forest",
                                     "Mixed Forest Cover", "Non-Forest Areas"))
    )

    ggplot(dummy_data, aes(x = x, y = y, fill = category)) +
        geom_tile() +
        scale_fill_manual(
            values = change_colors,
            name = "Forest Change"
        ) +
        theme_void() +
        theme(
            legend.position = "left",
            legend.title = element_text(size = 50, face = "bold"),
            legend.text = element_text(size = 30),
            legend.key.size = unit(1.5, "cm"),
            plot.background = element_rect(fill = NA, color = NA),
            panel.background = element_rect(fill = NA, color = NA),
            legend.background = element_rect(fill = NA, color = NA),
            plot.margin = margin(20, 20, 20, 20)
        ) +
        guides(fill = guide_legend(
            title.position = "top",
            title.hjust = 0.5,
            ncol = 1
        )) +
        xlim(0, 0) + ylim(0, 0)
}

# Save legend
legend_plot <- create_forest_legend()
ggsave("legend.png", plot = legend_plot, width = 6, height = 8, dpi = 300, bg = "transparent")


# Create title
title_plot <- ggplot() +
    theme_void() +
    theme(
        plot.background = element_rect(fill = "white", color = NA),
        panel.background = element_rect(fill = "white", color = NA),
        plot.margin = margin(20, 20, 20, 20)
    ) +
    annotate(
        "text", x = 0.5, y = 0.7,
        label = "Croatia Forest Change Detection (2016-2024)",
        size = 20,
        fontface = "bold",
        color = "grey15",
        hjust = 0.5
    ) +
    annotate(
        "text", x = 0.5, y = 0.3,
        label = "Google Earth Engine • Dynamic World V1 ",
        size = 17,
        color = "grey35",
        hjust = 0.5
    ) +
    xlim(0, 1) + ylim(0, 1)

# Save title
ggsave("title.png", plot = title_plot, width = 10.67, height = 1.33, dpi = 300, bg = "white")


# 17. FINAL COMPOSITION
# ==============================================

# Load all components
main_img <- magick::image_read("croatia_forest_change.png")
legend_img <- magick::image_read("legend.png")
title_img <- magick::image_read("title.png")


title_resized <- magick::image_resize(title_img, "3200x400^")
legend_resized <- magick::image_resize(legend_img, "1500x1800")

# Combine title with main image
img_with_title <- magick::image_append(c(title_img, main_img), stack = TRUE)

# Calculate positioning
total_height <- 3200
legend_x <- 3200 - 1200
legend_y <- (total_height - 1000) / 2 + 100

# Create final composite
final_composite <- magick::image_composite(
    img_with_title,
    legend_resized,
    offset = paste0("+", legend_x, "+", legend_y),
    operator = "over"
)

# Save final result
magick::image_write(final_composite, "croatia_forest_change_map.png", quality = 200)



# 18. CALCULATE STATISTICS
# ========================
change_values <- terra::values(change_aligned, na.rm = TRUE)
change_counts <- table(change_values)
total_pixels <- length(change_values)
change_percentages <- round((change_counts / total_pixels) * 100, 2)

cat("\n=== FOREST CHANGE STATISTICS ===\n")
if("1" %in% names(change_percentages)) cat("Forest Gain:", change_percentages["1"], "% of total area\n")
if("2" %in% names(change_percentages)) cat("Forest Loss:", change_percentages["2"], "% of total area\n")
if("3" %in% names(change_percentages)) cat("Stable Forest:", change_percentages["3"], "% of total area\n")
if("4" %in% names(change_percentages)) cat("Stable Non-Forest:", change_percentages["4"], "% of total area\n")

# Calculate net change if both gain and loss exist
if("1" %in% names(change_percentages) && "2" %in% names(change_percentages)) {
    net_change <- change_percentages["1"] - change_percentages["2"]
    cat("Net Change:", round(net_change, 2), "percentage points\n")
}

