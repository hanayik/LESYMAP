#' @rdname createFolds
#' @title createFolds
#'
#' @description Used to create folds for k-fold validation
#'
#' @param y split sample by balancing y
#' @param k number of folds
#' @param list logical whether to return folds in a list
#' @param returnTrain logical whether to return training indices (T)
#' or the test samples (F)
#'
#' @author Caret Package
#'
.createFolds <- function(y, k = 10, list = TRUE, returnTrain = FALSE) {
  if(class(y)[1] == "Surv") y <- y[,"time"]
  if(is.numeric(y)) {
    ## Group the numeric data based on their magnitudes
    ## and sample within those groups.

    ## When the number of samples is low, we may have
    ## issues further slicing the numeric data into
    ## groups. The number of groups will depend on the
    ## ratio of the number of folds to the sample size.
    ## At most, we will use quantiles. If the sample
    ## is too small, we just do regular unstratified
    ## CV
    cuts <- floor(length(y)/k)
    if(cuts < 2) cuts <- 2
    if(cuts > 5) cuts <- 5
    breaks <- unique(quantile(y, probs = seq(0, 1, length = cuts)))
    y <- cut(y, breaks, include.lowest = TRUE)
  }

  if(k < length(y)) {
    ## reset levels so that the possible levels and
    ## the levels in the vector are the same
    y <- factor(as.character(y))
    numInClass <- table(y)
    foldVector <- vector(mode = "integer", length(y))

    ## For each class, balance the fold allocation as far
    ## as possible, then resample the remainder.
    ## The final assignment of folds is also randomized.
    for(i in 1:length(numInClass)) {
      ## create a vector of integers from 1:k as many times as possible without
      ## going over the number of samples in the class. Note that if the number
      ## of samples in a class is less than k, nothing is producd here.
      min_reps <- numInClass[i] %/% k
      if(min_reps > 0) {
        spares <- numInClass[i] %% k
        seqVector <- rep(1:k, min_reps)
        ## add enough random integers to get  length(seqVector) == numInClass[i]
        if(spares > 0) seqVector <- c(seqVector, sample(1:k, spares))
        ## shuffle the integers for fold assignment and assign to this classes's data
        foldVector[which(y == names(numInClass)[i])] <- sample(seqVector)
      } else {
        ## Here there are less records in the class than unique folds so
        ## randomly sprinkle them into folds.
        foldVector[which(y == names(numInClass)[i])] <- sample(1:k, size = numInClass[i])
      }
    }
  } else foldVector <- seq(along = y)

  if(list) {
    out <- split(seq(along = y), foldVector)
    names(out) <- paste("Fold", gsub(" ", "0", format(seq(along = out))), sep = "")
    if(returnTrain) out <- lapply(out, function(data, y) y[-data], y = seq(along = y))
  } else out <- foldVector
  out
}
