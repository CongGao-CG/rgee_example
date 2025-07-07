# =============================================================================
# china FOREST CHANGE DETECTION - GEE World Dynamic Dataset V1
# =============================================================================


# 1. PACKAGE SETUP
# ================
library(rgee)
library(googledrive)

main_dir <- getwd()



# 2. INITIALIZE GOOGLE EARTH ENGINE
# =================================

ee_Initialize()

# Define country boundary
china <- ee$FeatureCollection("USDOS/LSIB_SIMPLE/2017")$
    filter(ee$Filter$eq("country_na", "China"))


# 3. FOREST DATA EXTRACTION
# =====================================================
get_forest_data <- function(year) {
    start_date <- paste0(year, "-05-01")
    end_date <- paste0(year, "-09-30")

    cat("Processing", year, "growing season...\n")


    dw_collection <- ee$ImageCollection("GOOGLE/DYNAMICWORLD/V1")$
        filterDate(start_date, end_date)$
        filterBounds(china)

    image_count <- dw_collection$size()$getInfo()
    cat("Found", image_count, "images for", year, "\n")

    # Extract trees probability and convert to percentage
    trees_median <- dw_collection$select("trees")$median()
    trees_percent <- trees_median$multiply(100)$clip(china)

    return(trees_percent)
}

# 4. GET DATA FOR BOTH YEARS
# ==========================
baseline_year <- 2015
final_year <- 2024

forest_2015 <- get_forest_data(baseline_year)
forest_2024 <- get_forest_data(final_year)


# 5. CALCULATE CHANGE DETECTION
# =============================
forest_change_raw <- forest_2024$subtract(forest_2015)

# Create change classification
change_classification <- ee$Image(0)$
    where(forest_change_raw$gt(15), 1)$     # Forest Gain
    where(forest_change_raw$lt(-15), 2)$    # Forest Loss
    where(forest_2015$gt(70)$And(forest_2024$gt(70)), 3)$  # Stable Forest
    where(forest_2015$lt(30)$And(forest_2024$lt(30)), 4)   # Stable Non-Forest


# 6. EXPORT DATA
# ===========================
export_forest_data <- function() {

    # Export change classification
    task <- ee$batch$Export$image$toDrive(
        image = change_classification,
        description = "china_forest_change_2015_2024",
        folder = "Earth_Engine_Exports",
        fileNamePrefix = "china_change_final",
        scale = 1000,
        region = china$geometry()$bounds(),
        maxPixels = 1e9
    )
    task$start()
    cat("Export started! Monitor at: https://code.earthengine.google.com/tasks\n")
}

# Run export
export_forest_data()


# 7. LOAD AND PREPARE DATA (AFTER DOWNLOAD)
# =========================================
# Run this section after downloading from Google Drive

# Load the change classification
drive_download(drive_get("china_change_final.tif"))
change_raster <- rast("china_change_final.tif")