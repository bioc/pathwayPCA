#' Test Pathways with AES-PCA
#'
#' @description Given a supervised \code{OmicsPath} object (one of
#'   \code{OmicsSurv}, \code{OmicsReg}, or \code{OmicsCateg}), extract the first
#'   adaptive, elastic-net, sparse principal components from each expressed
#'   pathway in the MS design matrix, test their association with the response
#'   matrix, and return a data frame of the adjusted \eqn{p}-values for each
#'   pathway.
#'
#' @param object An object of class \code{OmicsPathway} with a response matrix
#' @param numPCs The number of PCs to extract from each pathway. Defaults to 1.
#' @param min.features What is the smallest number of genes allowed in each
#'   pathway? This argument must be kept constant across all calls to this
#'   function which use the same pathway list. Defaults to 3.
#' @param numReps The number of permutations to take of the data to calculate a
#'   \eqn{p}-value for each pathway. Defaults to 1000.
#' @param parallel Should the comuptation be completed in parallel? Defaults to
#'   \code{FALSE}.
#' @param numCores If \code{parallel = TRUE}, how many cores should be used for
#'   computation?
#' @param adjustpValues Should you adjust the \eqn{p}-values for multiple
#'   comparisons? Defaults to TRUE.
#' @param adjustment Character vector of procedures. The returned data frame
#'   will be sorted in ascending order by the first procedure in this vector,
#'   with ties broken by the unadjusted \eqn{p}-value. If only one procedure is
#'   selected, then it is necessarily the first procedure. See the documentation
#'   for the \code{\link{adjustRaw_pVals}} function for the adjustment procedure
#'   definitions and citations.
#' @param ... Dots for additional internal arguments
#'
#' @return A data frame with columns
#' \itemize{
#'   \item{\code{pathways} : }{The names of the pathways in the \code{Omics*}}
#'     object (stored in \code{object@@pathwaySet$pathways})
#'   \item{\code{setsize} : }{The number of genes in each of the original
#'     pathways (as stored in the \code{object@@pathwaySet$setsize} object)}
#'   \item{\code{terms} : }{The pathway description, as stored in the
#'     \code{object@@pathwaySet$TERMS} object}
#'   \item{\code{rawp} : }{The unadjusted \eqn{p}-values of each pathway}
#'   \item{\code{...} : }{Additional columns as specified through the
#'     \code{adjustment} argument}
#' }
#'
#' The data frame will be sorted in ascending order by the method specified
#'   first in the \code{adjustment} argument. If \code{adjustpValues = FALSE},
#'   then the data frame will be sorted by the raw \eqn{p}-values. If you have
#'   the suggested \code{tidyverse::} package suite loaded, then this data frame
#'   will print as a \code{\link[tibble]{tibble}}. Otherwise, it will stay a
#'   simple data frame.
#'
#' @details This is a wrapper function for the \code{\link{expressedOmes}},
#'   \code{\link{extract_aesPCs}}, \code{\link{permTest_OmicsSurv}},
#'   \code{\link{permTest_OmicsReg}}, and \code{\link{permTest_OmicsCateg}}
#'   functions.
#'
#' @seealso \code{\link{expressedOmes}}; \code{\link{create_OmicsPath}};
#'   \code{\link{create_OmicsSurv}}; \code{\link{create_OmicsReg}};
#'   \code{\link{create_OmicsCateg}}; \code{\link{extract_aesPCs}};
#'   \code{\link{permTest_OmicsSurv}}; \code{\link{permTest_OmicsReg}};
#'   \code{\link{permTest_OmicsCateg}}; \code{\link{adjust_and_sort}}
#'
#' @export
#'
#' @include createClass_validOmics.R
#' @include createClass_OmicsPath.R
#' @include createClass_OmicsSurv.R
#' @include createClass_OmicsReg.R
#' @include createClass_OmicsCateg.R
#' @include subsetExpressed-omes.R
#' @include aesPC_permtest_CoxPH.R
#' @include aesPC_permtest_LS.R
#' @include aesPC_permtest_GLM.R
#'
#' @importFrom methods setGeneric
#'
#' @rdname AESPCA_pVals
setGeneric("AESPCA_pVals",
           function(object,
                    numPCs = 1,
                    min.features = 3,
                    numReps = 1000,
                    parallel = FALSE,
                    numCores = NULL,
                    adjustpValues = TRUE,
                    adjustment = c("Bonferroni",
                                   "Holm",
                                   "Hochberg",
                                   "SidakSS",
                                   "SidakSD",
                                   "BH",
                                   "BY",
                                   "ABH",
                                   "TSBH"),
                    ...){
             standardGeneric("AESPCA_pVals")
           }
)

#' @importFrom parallel makeCluster
#' @importFrom parallel clusterExport
#' @importFrom parallel clusterEvalQ
#' @importFrom parallel parSapply
#' @importFrom parallel stopCluster
#'
#' @rdname AESPCA_pVals
setMethod(f = "AESPCA_pVals", signature = "OmicsPathway",
          definition = function(object,
                                numPCs = 1,
                                min.features = 3,
                                numReps = 1000,
                                parallel = FALSE,
                                numCores = NULL,
                                adjustpValues = TRUE,
                                adjustment = c("Bonferroni",
                                               "Holm",
                                               "Hochberg",
                                               "SidakSS",
                                               "SidakSD",
                                               "BH",
                                               "BY",
                                               "ABH",
                                               "TSBH"),
                                ...){
            # browser()

            ###  Remove Unexpressed Genes from the Pathway Set  ###
            object <- expressedOmes(object, trim = min.features)
            pathwayGeneSets_ls <- object@pathwaySet


            ###  Calculate AES-PCs  ###
            message(" Part 1: Calculate Pathway AES-PCs\n")
            pcs_ls <- extract_aesPCs(object = object,
                                     trim = min.features,
                                     numPCs = numPCs,
                                     parallel = parallel,
                                     numCores = numCores)


            ###  Permutation Pathway p-Values  ###
            message("\n Part 2: Calculate Permuted Pathway p-Values\n")
            obj_class <- class(object)
            switch(obj_class,
                   OmicsSurv = {
                     pVals_vec <- permTest_OmicsSurv(OmicsSurv = object,
                                                     pathwayPCs_ls = pcs_ls,
                                                     numReps = numReps,
                                                     parallel = parallel,
                                                     numCores = numCores)
                   },
                   OmicsReg = {
                     pVals_vec <- permTest_OmicsReg(OmicsReg = object,
                                                    pathwayPCs_ls = pcs_ls,
                                                    numReps = numReps,
                                                    parallel = parallel,
                                                    numCores = numCores)
                   },
                   OmicsCateg = {
                     pVals_vec <- permTest_OmicsCateg(OmicsCateg = object,
                                                      pathwayPCs_ls = pcs_ls,
                                                      numReps = numReps,
                                                      parallel = parallel,
                                                      numCores = numCores)
                   }
            )


            ###  Adjust Pathway p-Values  ###
            if(adjustpValues){

              message("\n Part 3: Adjusting p-Values and Sorting Pathway p-Value Data Frame\n")
              adjustment <- match.arg(adjustment, several.ok = TRUE)

            } else {
              message("\n Part 3: Sorting Pathway p-Value Data Frame\n")
            }

            out_df <- adjust_and_sort(pVals_vec = pVals_vec,
                                      genesets_ls = pathwayGeneSets_ls,
                                      adjust = adjustpValues,
                                      proc_vec = adjustment,
                                      ...)
            message("DONE")

            ###  Return  ###
            out_df

          })