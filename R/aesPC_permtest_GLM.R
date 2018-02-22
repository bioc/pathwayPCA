#' Permutation Test for Pathway PCs for Classification Response
#'
#' @description Given an \code{OmicsCateg} object and a list of pathway PCs from
#'   the \code{\link{extract_aesPCs}} function, test if each expressed pathway
#'   in the MS design matrix is significantly related to the classification
#'   output.
#'
#' @param OmicsCateg A data object of class \code{OmicsCateg}, created by the
#'   \code{\link{create_OmicsCateg}} function.
#' @param pathwayPCs_ls A list of pathway PC matrices returned by the
#'   \code{\link{extract_aesPCs}} function.
#' @param numReps How many permuted models to fit? Defaults to 1000
#' @param parallel Should the comuptation be completed in parallel? Defaults to
#'   \code{FALSE}.
#' @param numCores If \code{parallel = TRUE}, how many cores should be used for
#'   computation?
#' @param ... Dots for additional internal arguments (currently unused)
#'
#' @return A named vector of pathway permutation \eqn{p}-values.
#'
#' @details This function takes in a list of the first principal components
#'   from each pathway and an object of class `OmicsCateg`. This function will
#'   then calculate the AIC of a multivariate generalized linear model (via the
#'   \code{\link[stats]{glm}} function) with the original observations as
#'   response and the pathway principal components as the predictor matrix.
#'
#'   Then, this function will create \code{numReps} permutations of the
#'   classification response, fit models to each of these premuted responses
#'   (holding the path predictor matrix fixed), and calculate the AIC of each
#'   model. This function will return a named vector of permutation
#'   \eqn{p}-values, where the value for each pathway is the proportion of
#'   models for which the AIC of the permuted response model is less than the
#'   AIC of the original model.
#'
#'   In future versions, this function will also be able to calculate permuted
#'   \eqn{p}-values for multinomial logistic regression and proportional odds
#'   logistic regression models, for n-ary and ordered categorical responses,
#'   respectively.
#'
#' @seealso \code{\link{create_OmicsCateg}}; \code{\link{extract_aesPCs}};
#'   \code{\link[stats]{glm}}; \code{\link{sample_Classifresp}}
#'
#' @export
#'
#' @include createClass_validOmics.R
#' @include createClass_OmicsCateg.R
#' @include aesPC_extract_OmicsPath_PCs.R
#'
#' @importFrom methods setGeneric
#'
#' @rdname permTest_OmicsCateg
setGeneric("permTest_OmicsCateg",
           function(OmicsCateg,
                    pathwayPCs_ls,
                    numReps = 1000,
                    parallel = FALSE,
                    numCores = NULL,
                    ...){
             standardGeneric("permTest_OmicsCateg")
           }
)

#' @importFrom stats glm
#' @importFrom stats AIC
#' @importFrom stats binomial
#' @importFrom parallel makeCluster
#' @importFrom parallel clusterExport
#' @importFrom parallel clusterEvalQ
#' @importFrom parallel parSapply
#' @importFrom parallel stopCluster
#'
#' @rdname permTest_OmicsCateg
setMethod(f = "permTest_OmicsCateg", signature = "OmicsCateg",
          definition = function(OmicsCateg,
                                pathwayPCs_ls,
                                numReps = 1000,
                                parallel = FALSE,
                                numCores = NULL,
                                ...){

            ###  Function Setup  ###
            # The distribution object will be passed in either indirectly or
            #   directly through the OmicsCateg object. I will probably put some
            #   sort of class / ordering check in the create_OmicsCateg()
            #   function to add a slot or attribute for "binary", "n_ary" or
            #   "ordered" responses. Then, all I need is a switch here to define
            #   the "dist" object.
            # Now that I think about it, this should probably be three seperate
            #   functions. Nope, because then I'd have to have a switch around
            #   the apply statements. No thanks. I don't like how inneficient
            #   this is.
            permute_CategFit <- function(pathwayPCs_mat,
                                         obj_OmicsCateg,
                                         numReps_int = numReps,
                                         parametric = FALSE){
              # browser()

              ###  True Model  ###
              response <- obj_OmicsCateg@response
              trueAIC <- AIC(glm(response ~ pathwayPCs_mat, family = binomial))


              ###  Permuted Model  ###
              permuteAIC_fun <- function(){

                perm_resp <- sample_Classifresp(obj_OmicsCateg@response,
                                            parametric = parametric)
                AIC(glm(perm_resp ~ pathwayPCs_mat, family = binomial))

              }

              permAIC <- replicate(n = numReps_int, expr = permuteAIC_fun())

              ###  Return  ###
              mean(permAIC < trueAIC)

            }

            ###  Computation  ###
            # browser()

            if(parallel){
              # browser()

              ###  Parallel Computing Setup  ###
              message("Initializing Cluster")
              # require(parallel)
              clust <- makeCluster(numCores)
              clustVars_vec <- c(deparse(quote(OmicsCateg)),
                                 deparse(quote(numReps)))
              clusterExport(cl = clust,
                            varlist = clustVars_vec,
                            envir = environment())
              invisible(clusterEvalQ(cl = clust, library(pathwayPCA)))
              message("DONE")

              ###  Extract PCs  ###
              message("Extracting Pathway p-Values in Parallel")
              pValues_vec <- parSapply(cl = clust,
                                       pathwayPCs_ls,
                                       permute_CategFit,
                                       obj_OmicsCateg = OmicsCateg,
                                       numReps_int = numReps)
              stopCluster(clust)
              message("DONE")

            } else {

              message("Extracting Pathway p-Values Serially")
              pValues_vec <- sapply(pathwayPCs_ls,
                                    permute_CategFit,
                                    obj_OmicsCateg = OmicsCateg,
                                    numReps_int = numReps)
              message("DONE")

            }

            pValues_vec

          })