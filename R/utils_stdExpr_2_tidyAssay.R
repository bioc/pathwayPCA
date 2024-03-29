#' Tidy a SummarizedExperiment Assay
#'
#' @description Extract the assay information from a
#'    \code{\link[SummarizedExperiment]{SummarizedExperiment-class}}-object,
#'    transpose it, and and return it as a tidy data frame that contains assay
#'    measurements, feature names, and sample IDs
#'
#' @param summExperiment A
#'    \code{\link[SummarizedExperiment]{SummarizedExperiment-class}} object
#' @param whichAssay Because \code{SummarizedExperiment} objects can
#'    store multiple related assays, which assay will be paired with a given
#'    pathway collection to create an \code{Omics*}-class data container?
#'    Defaults to 1, for the first assay in the object.
#'
#' @details This function is designed to extract and transpose a "tall" assay
#'    data frames (where genes or proteins are the rows and patient or tumour
#'    samples are the columns) from a \code{SummarizedExperiment} object.
#'    This function also transposes the row (feature) names to column names and
#'    the column (sample) names to row names via the
#'    \code{\link{TransposeAssay}} function.
#'    
#'    NOTE: if this function stops working (again), please add a comment here:
#'    \url{https://github.com/gabrielodom/pathwayPCA/issues/83}
#'
#' @return The transposition of the assay in \code{summExperiment} to tidy form,
#'    with the column data (from the \code{colData} slot of the object) appended
#'    as the first columns of the data frame.
#'
#' @importFrom methods slot
#'
#' @export
#'
#' @examples
#'    # THIS REQUIRES THE SummarizedExperiment PACKAGE.
#'    library(SummarizedExperiment)
#'    data(airway, package = "airway")
#'    
#'    airway_df <- SE2Tidy(airway)
#'
SE2Tidy <- function(summExperiment, whichAssay = 1){
  # browser()
  
  ###  Assay  ###
  assay_mat <- slot(slot(summExperiment, "assays"), "data")[[whichAssay]]
  dimnames(assay_mat)[c(1,2)] <- dimnames(summExperiment)
  assay_df <- TransposeAssay(
    assay_df = data.frame(assay_mat),
    omeNames = "rowNames"
  )
  
  ###  Response  ###
  samps_df <- as.data.frame(
    slot(summExperiment, "colData")
  )
  
  ###  Return Joined Data Frame  ###
  merge(samps_df, assay_df, by = "row.names")
  
}
