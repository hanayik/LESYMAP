#' Lesion to Symptom Mapping
#'
#' Lesymap uses univariate and multivariate methods to map
#' functional regions of the brain that, when lesioned,
#' cause specific cognitive deficits. All is required is
#' a set of Nifti images with the lesion of each subject
#' and the vector of behavioral scores. Lesions must be
#' already registered in template space, use `antsRegistration`
#' or other ANTs tools to achieve this. Lesymap will check that
#' lesions are in the same space before running. By default, voxels
#' with identical lesion patterns are grouped together in
#' unique patches, and analysis are run on patches.
#' Patch-based mapping decreases the number of multiple
#' comparisons and speeds up the analyses. Multivariate mapping
#' is performed using an optimized version of sparse canonical
#' correlations (SCCAN).
#'
#' @param lesions.list list of antsImages, or a vector of
#' filenames, or a single antsImage with 4 dimensions.
#'
#' @param behavior vector of behavioral scores or filename
#' pointing to a file with a single column of numbers.
#'
#' @param method  what tests to run, one of 'BM' (default), 'BMfast', 'ttest',
#'  'welch', 'regres', 'regresfast', 'regresPerm', 'sccan', 'sccanRaw'.
#'
#'        \code{\link[=lsm_BM]{BM}} - Brunner-Munzel non parametric test, also
#'          called the Generalized Wilcoxon Test. The BM test is the
#'          same test used in the npm/Mricron software. See
#'          (see \href{https://www.ncbi.nlm.nih.gov/pubmed/17583985}{Rorden (2007)}).
#'
#'        \code{\link[=lsm_BMfast]{BMfast}} - ultrafast Brunner-Munzel with compiled code.
#'          BMfast can be
#'          combined with \code{multipleComparison='FWERperm'}
#'          to perform permutation based thresholding in a short time.
#'
#'        \code{\link[=lsm_ttest]{ttest}} - Regular single tailed t-test. Variances of groups
#'          are assumed to be equal. This is the test used in the voxbo
#'          software. Relies on \code{t.test} function in R. It is assumed
#'          that 0 voxels are healthy, i.e., higher behavioral scores.
#'          See the \code{alternative} parameter for inverted cases.
#'          (see \href{https://www.ncbi.nlm.nih.gov/pubmed/12704393}{Bates (2003)}).
#'
#'        \code{\link[=lsm_ttest]{welch}} - t-test that assumes unequal variance between
#'          groups. Relies on \code{t.test} function in R.
#'
#'        \code{\link[=lsm_regres]{regres}} - linear model between voxel values and behavior.
#'          Uses the \code{lm} function in R. This is equivalent to a
#'          t-test, but is useful when voxel values are continuous. To model
#'          the effect of covariates use the \code{"regresfast"} method
#'
#'        \code{\link[=lsm_regresfast]{regresfast}} - ultrafast linear regressions with compiled code.
#'          This method allows setting covariates. If covariates are specified
#'          the effect of each voxel will be estimated with the formula:\cr
#'          \code{behavior ~ voxel + covar1 + covar2 + ...}\cr
#'          This method allows multiple comparison correction with permutation based methods
#'          \code{"FWERperm"} and \code{"clusterPerm"}. If these corrections are required
#'          and covariates are specified, the effect of each voxel is established with
#'          the Freedman-Lane method
#'          (see \href{https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4010955/}{Winkler (2014)}).
#'
#'        \code{\link[=lsm_regresPerm]{regresPerm}} - linear model between voxel values and behavior.
#'          The p-value of each individual voxel us established by permuting voxel values. The
#'          lmPerm package is used for this purpose. Note, these permutations do not correct for
#'          multiple comparisons, they only establish voxel-wise p-values.
#'
#'        \code{\link[=lsm_chisq]{chisq}} - chi-square test between voxel values and behavior.
#'          The method is used when behavioral scores are binary (i.e. presence of absence
#'          of deficit). Relies on the \code{\link[stats]{chisq.test}}
#'          R function. By default this method corrects individual voxel p-values with the
#'          Yates method (the same approach offered in the Voxbo software).
#'
#'        \code{\link[=lsm_chisq]{chisqPerm}} - chi-square tests. P-values are established
#'          through permutation tests instead of regular statistics.
#'          Relies on the \code{\link[stats]{chisq.test}} R function.
#'
#'        \code{\link[=lsm_sccan]{sccan}} - sparse canonical correlations (NEW). Multivariate
#'          method that considers all voxels at once. By default,
#'          lesymap will run a lengthy procedure to determine the optimal
#'          sparseness value (how extensive the results should be). You
#'          can set \code{optimizeSparseness=FALSE} if you want to skip this
#'          optimization. The search for optimal sparsness provides
#'          a cross-validated correlation measure that shows how well the
#'          sparseness value can predict new patients. If this predicive correlation
#'          is below significance (i.e., below pThreshold), the entire solution will be ignored and a
#'          NULL result will be returned. Lesymap returns normalized (0-1)
#'          voxel weights converted to positive; you can use \code{rawStat=TRUE}
#'          to retain the original voxel weights. Note that both lesion and behavior
#'          data are scale and centered before running SCCAN (hardcoded in \link{lsm_sccan}).
#'          You must apply the same scaling if you were to predict behavioral scores with
#'          the obtained voxel weights.
#'
#' @param minSubjectPerVoxel (default='10\%') remove voxels/patches with lesions
#'  in less than X subjects. Value can
#'  be speficifed as percentage ('10\%')
#'  or exact number of subjects (10).
#'
#' @param correctByLesSize whether to correct for lesion size in the analysis.
#'  Options are "none", "voxel", "behavior":
#'  \itemize{
#'  \item\code{"none"}: (default) no correction
#'  \item\code{"voxel"}: divide voxel values by 1/sqrt(lesionsize).
#'     This is the method used in
#'     \href{https://www.ncbi.nlm.nih.gov/pubmed/25879574}{Mirman (2015)} and
#'     \href{https://www.ncbi.nlm.nih.gov/pubmed/25044213}{Zhang (2014)}.
#'     This correction works only with
#'     'regres' methods. Two sample comparisons
#'     (t-tests and Brunner-Munzel) use binary voxels
#'     and will ignore this correction.
#'  \item\code{"behavior"}: residualize behavioral scores by removing
#'     the effect of lesion size. This works on all methods,
#'     but is more agressive on results.
#'     }
#'
#' @param multipleComparison (default='fdr') method to adjust p-values.
#'  Standard methods include \code{"holm"}, \code{"hochberg"},
#'  \code{"hommel"}, \code{"bonferroni"}, \code{"BH"}, \code{"BY"}, \code{"fdr"}.
#'  (see \code{\link[stats]{p.adjust}} ) \cr
#'  Permutation methods include: \cr
#'  \code{"FWERperm"} (permutation based family-wise threshold) is enabled
#'    with methods 'BMfast' and 'regresfast'. In this
#'    case, many analysis are run with permuted behavioral
#'    scores, and the peak score is recorded each time (see
#'    Winkler 2014). The optimal threshold is established at
#'    95th percentile of this distribution (or whatever pThreshold
#'    you choose). You can choose to use as reference another
#'    voxel lower in the ranks by specifying another `v` value
#'    (i.e., lesymap(..., v=10) will record the 10th highest voxel). \cr
#'  \code{"clusterPerm"} (permutation based cluster correction) is enabled
#'    for 'regresfast'. It records the maximal
#'    cluster size from many random permutations of the behavior
#'    score and sets a cluster threshold based on that distribution.
#'    You must select pThreshold (voxel-wise, default=0.05) and
#'    clusterPermThreshold (cluster-wise, default 0.05) to achieve
#'    optimal with this method.
#'
#' @param pThreshold (default=0.05) threshold statistics at this p-value
#'  (after corrections or permutations)
#'
#' @param mask (default=NA) binary image to select the area
#'  where analysis will be performed. If
#'  not provided will be computed automatically
#'  by thresholding the average lesion map at
#'  minSubjectPerVoxel.
#'
#' @param patchinfo (default=NA) an object obtained with getUniqueLesionPatches or from
#'  a previous analyses. Useful for repetitive analysis to save time and
#'  avoid the computation of patches each time.
#'
#' @param nperm (default=1000) number of permutations to run when necessary.
#'
#' @param noPatch logical (default=FALSE), if True avoids using patch information and
#'  will analyze all voxels. It will take longer and results will be
#'  worse due to more multiple comparison corrections. This argument
#'  is ignored when performing SCCAN analyses.
#'
#' @param flipSign logical (default=FALSE), invert the sign in the statistics image.
#'
#' @param binaryCheck logical (default=FALSE), make sure the lesion matrix is 0/1.
#'
#' @param showInfo logical (default=TRUE), display time-stamped info messages
#'
#' @param saveDir (default=NA) save results in the specified folder.
#'
#' @param ... arguments that will be passed down to other functions
#' (i.e., sparsness=0.045)
#'
#'
#' @details
#' Several other parameters can be specified to lesymap()
#' which will be passed to other called fuctions. Here are
#' some examples:
#'
#' \code{permuteNthreshold}  - (default=9) for Brunner-Munzel tests only.
#'    Voxels lesioned in less than this number
#'    of subjects will undergo permutation-based
#'    p-value estimation. Useful because the BM test
#'    is not valid when comparing groups with N < 9.
#'    Note, permuted BM tests currently require the package
#'    'nparcomp'.
#'
#' \code{clusterPermThreshold} - threshold used to find the optimal cluster size when
#'    using 'clusterPerm' multiple comparison correction.
#'
#' \code{alternative} - (default='greater') for two sample tests (ttests and BM).
#'    By default LESYMAP computes single tailed p-values assuming
#'    that non-lesioned 0 voxels have higher behavioral scores.
#'    You can specify the opposite relationship with alternative='less'
#'    or compute two tailed p-values with alternative='two.sided'.
#'
#' \code{covariates} - (default=NA) enabled for method = 'regresfast'.
#'    This will allow to model the effect of each voxel
#'    in the context of other covariates, i.e., formula
#'    "behavior ~ voxel + covar1 + covar2 + ...". \cr
#'    I,.e., lesymap(lesions,behavior, method='regresfast',
#'            covariates=cbind(lesionsize, age)).\cr
#'    If you choose permutation based thresholding with covariates, lesymap
#'    will use the Freedman-Lane method for extracting the unique effect of
#'    each voxel (see Winkler 2014, Freedman 1983)
#'
#' \code{template} - antsImage or filename used for plotting the results if a saving
#'    directory is specified (see \code{saveDir})
#'
#' \code{v} - (default=1) which voxel to record for permutation based thresholding.
#'    Normally the peak voxel is used (1), but other voxels can be recorded.
#'    See Mirman 2017 for this approach.
#'
#'
#'
#' @return
#' The following objects are typically found in the returned list:
#' \itemize{
#' \item\code{stat.img}   - statistical map
#' \item\code{rawStat.img}   - (optional) raw SCCAN weights
#' \item\code{pval.img}   - (optional) p-values map
#' \item\code{zmap.img}   - (optional) zscore map
#' \item\code{mask.img}    - mask used for the analyses
#' \item\code{average.img} - map of all lesions averaged. Map is
#'            produced only if no mask is defined.
#' \item\code{callinfo} - list of details of how you called lesymap
#' \item\code{printedOutput} - terminal output in a character variable
#' \item\code{perm.vector} - the values obtained from each permutation
#' \item\code{perm.clusterThreshold} - threshold computed for cluster thresholding
#' \item\code{perm.FWERthresh} - threshold computed for FWERperm thresholding
#' \item\code{patchinfo}   - list of variables describing patch information:
#'     \itemize{
#'     \item\code{patchimg} - antsImage with the patch number each voxels belongs to
#'     \item\code{patchimg.samples} - antsImage mask with a single voxel per patch
#'     \item\code{patchimg.size} - antsImage with the patch size at each voxel
#'     \item\code{patchimg.mask} -  the mask within which the function will look for patches
#'     \item\code{npatches} - number of unique patches in the image
#'     \item\code{nvoxels} - total number of lesioned voxels in mask
#'     \item\code{patchvoxels} - vector of voxel count for each patch
#'     \item\code{patchvolumes} - vector of volume size for each patch
#'     \item\code{patchmatrix} - the lesional matrix, ready for use in analyses.
#'            Matrix has size NxP (N=number of subjects, P=number of
#'            patches)
#'            }
#' }
#'
#' @examples
#' lesydata = file.path(find.package('LESYMAP'),'extdata')
#' filenames = Sys.glob(file.path(lesydata, 'lesions', 'Subject*.nii.gz'))
#' behavior = Sys.glob(file.path(lesydata, 'behavior', 'behavior.txt'))
#' template = antsImageRead(
#'  Sys.glob(file.path(lesydata, 'template', 'ch2.nii.gz')))
#' lsm = lesymap(filenames, behavior, method = 'BMfast')
#' plot(template, lsm$stat.img, window.overlay = range(lsm$stat.img))
#'
#' \dontrun{
#' # Same analysis with SCCAN
#' lsm = lesymap(filenames, behavior, method = 'sccan',
#' sparseness=0.045, optimizeSparseness=FALSE)
#' plot(template, lsm$stat.img, window.overlay = range(lsm$stat.img))
#' save.lesymap(lsm, saveDir='/home/dp/Desktop/SCCANresults')
#' }
#'
#' @author Dorian Pustina
#'
#' @export
#' @useDynLib LESYMAP
#' @importFrom Rcpp sourceCpp
#' @import ANTsR
#' @import ANTsRCore
#' @importFrom stats chisq.test cor dt lm optimize
#' @importFrom stats p.adjust p.adjust.methods pt qchisq qnorm
#' @importFrom stats quantile residuals runif t.test
#' @importFrom utils find getSrcDirectory installed.packages
#' @importFrom utils packageVersion read.table



lesymap <- function(lesions.list, behavior,
                    mask=NA,
                    patchinfo=NA,
                    method='BM',
                    correctByLesSize='none',
                    multipleComparison='fdr',
                    pThreshold=0.05,
                    flipSign=F,
                    minSubjectPerVoxel = '10%',
                    nperm=1000,
                    saveDir=NA,
                    binaryCheck=FALSE,
                    noPatch=FALSE, showInfo=TRUE,
                    ...) {
  ver = as.character(packageVersion('LESYMAP'))
  tstamp = "%H:%M:%S"
  toc = Sys.time()

  # start capturing window output to save later
  outputLog = capture.output({

  if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Running LESYMAP', ver, "\n"))
  if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Checking a few things...\n'))

  # make sure FWERperm is selected only for enabled methods
  FWERenabled = c('BMfast', 'regresfast')
  if (multipleComparison %in% c('FWERperm', 'clusterPerm') & ! method %in% FWERenabled)
    stop(paste0('FWERperm enabled only with ', paste(FWERenabled, collapse=', '),
                '. Please change your selection.'))

  # make sure multiple comparison is among accepted methods
  if (! multipleComparison %in% p.adjust.methods & ! multipleComparison %in% c('FWERperm', 'clusterPerm'))
    stop(paste0('Unknown multiple comparison correction: ', multipleComparison))

  # load behavior if filename
  if (checkAntsInput(behavior) == 'antsFiles') {
    if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Loading behavioral data...'))
    behavior = read.table(behavior, header = F)$V1
    if (showInfo) cat(paste(length(behavior), 'scores found.\n'))
  }

  inputtype = checkAntsInput(lesions.list, checkHeaders = T)

  # make sure input is a list or filenames
  if ( !(inputtype %in% c('antsImageList', 'antsFiles', 'antsImage')) ) {
    stop('Unrecognized input: lesions.list should be a 4D antsImage, a list of antsImages, or a vector of filenames')
  }

  ##############
  # single filename, check it's 4D, load it if filename, unpack it to list
  if (inputtype == 'antsFiles' & length(lesions.list) == 1) {
    temp = antsImageHeaderInfo(lesions.list[1])
    if (temp$nDimensions != 4) stop('File is not a 4D image. You must point to a 4D file when a single filename is defined.')
    if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Loading 4D image...'))
    lesions.list = antsImageRead(lesions.list[1])
    if (showInfo) cat(paste( dim(lesions.list)[4], 'images present.\n'))
    if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Converting 4D image into 3D image list...\n'))
    lesions.list = splitNDImageToList(lesions.list)
    invisible(gc()) # free some memory after conversion
    inputtype = 'antsImageList'
  } else if (inputtype == 'antsImage') {
    if (lesions.list@dimension != 4) stop('Input is a single image but is not 4D.')
    if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Single 4D image passed, converting to 3D image list...\n'))
    lesions.list = splitNDImageToList(lesions.list)
    invisible(gc()) # free some memory after conversion
    inputtype = 'antsImageList'
  }


  ##############
  # Few tests on images coming as filenames
  # check proper binarization and 255 values, maybe preload
  if (inputtype == 'antsFiles') {
    if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Filenames as input, checking lesion values on 1st image...\n'))

    temp = antsImageRead(lesions.list[1])
    voxvals = unique(c(as.numeric(temp)))

    if (length(voxvals) != 2) stop('Non binary image detected. Lesions should have only two values (0/1).')

    if (any(! voxvals %in% c(0,1) )) {
      if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Detected unusual lesion values, loading files into memory to fix...\n'))
      lesions.list = imageFileNames2ImageList(lesions.list)
      inputtype = 'antsImageList'
    }
  }


  ##############
  # image list might be from MRIcron, convert to binary
  # if input='antsFiles', it needs a binary check later on lesmat
  if (inputtype == 'antsImageList') {
    rebinarize = FALSE
    if (max(lesions.list[[1]]) > 1) rebinarize = TRUE # just check 1st, for is too long
    # for (i in 1:length(lesions.list)) {
    #   if (max(as.array(lesions.list[[i]])) > 1) {
    #     rebinarize = TRUE
    #     break
    #   }
    # }

    # perform binarization if needed
    if (rebinarize) {
      if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Detected lesion value above 1. Rebinarizing 0/1...\n'))
      for (i in 1:length(lesions.list)) lesions.list[[i]] = thresholdImage(lesions.list[[i]], 0.1, Inf)
      binaryCheck = FALSE # no need to check binarization anymore
    }
  }

  #########
  # check antsImageList is binary
  # for antsFiles, we checked only 1st, and
  # will check lesmat later
  if (binaryCheck & inputtype == 'antsImageList') {
    if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Verifying that lesions are binary 0/1...\n'))
    checkImageList(lesions.list, binaryCheck = T)
  }

  #########
  # check lesions and behavior have same length
  if (length(lesions.list) != length(behavior)) stop('Different lengths between lesions and behavior vector.')

  ########
  # check behavior is binary if needed
  if (method %in% c('chisq', 'chisqPerm')) {
    if (length(unique(behavior)) != 2) stop(paste0('The method "', method, '" requries binary behavioral scores.'))
  }

  ########
  # special case for SCCAN
  if (method %in% c('sccan', 'sccanRaw') ) {
    if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'SCCAN method: ignoring patch, nperm, and multiple comparison...\n'))
    multipleComparison = 'none'
    noPatch = T
    nperm=0
  }


  ## CHECK AND PREPARE MASK
  writeavgles = F
  if (!is.na(mask)) { # USER DEFINED

    if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Using predefined mask...\n'))

    # check mask and lesions have same headers
    checkMask(lesions.list, mask) # first, if mask is a file
    if (checkAntsInput(mask) == 'antsFiles') { # load the mask if file
      mask=antsImageRead(mask)
      if (class(mask) != 'antsImage') stop('Mask must be of class antsImage')
      checkMask(lesions.list, mask) # check again after loading in memory
    }

    # check mask is binary
    if (! checkImageList(list(mask), binaryCheck = T, showError = F))
      stop('Mask is not binary. Must have only 0 and 1 values')

  } else if (!is.na(patchinfo[1])) { # GET IT FROM patchinfo

    if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Using mask passed with patchinfo...\n'))
    mask = patchinfo$patchimg.mask
    checkMask(lesions.list, mask)

  } else { # DEFINE THE MASK
    if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Searching voxels lesioned >=',minSubjectPerVoxel,'subjects...'))
    # compute thresholdPercent based on minSubjectPerVoxel
    # it's used to remove voxels lesioned in few subjects
    if (!is.numeric(minSubjectPerVoxel) & is.character(minSubjectPerVoxel)) { # input is percentage
      thresholdPercent = as.numeric(gsub('%','', minSubjectPerVoxel)) / 100
    } else if (is.numeric(minSubjectPerVoxel)) { # user defined exact subject number
      thresholdPercent = minSubjectPerVoxel / length(lesions.list)
    }

    # compute average map
    avgles = antsAverageImages(lesions.list)

    # we remove voxels with too few, or too many, subjects
    mask = thresholdImage(avgles, thresholdPercent, 1 - thresholdPercent)
    # if user set minSubjectPerVoxel=0, mask is all 1, so fix it
    if (thresholdPercent == 0) mask[avgles==0] = 0
    writeavgles = T

    if (showInfo) cat(paste(sum(mask), 'found\n')) # voxels in mask
    # check mask is not empty
    if (max(mask) == 0) stop('Mask is empty. No voxels to run VLSM on.')
  }



  ##########
  # get patch information
  haslesmat = F
  if (noPatch) {
    if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'noPatch true - Patches will not be used...\n'))
    voxmask = mask
    voxindx = 1:sum(mask)
    patchinfo.derived = 'not computed'
  } else {
    if (is.na(patchinfo[1])) {

      if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Computing unique patches...\n'))
      patchinfo = getUniqueLesionPatches(lesions.list, mask=mask, showInfo = F, returnPatchMatrix = T)
      lesmat = patchinfo$patchmatrix
      haslesmat = T
      patchinfo.derived = 'Computed'

    } else {

      if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Using predefined patch information...\n'))
      if (!(checkImageList(list(patchinfo$patchimg, mask), showError = F)))
          stop('Patch image header is different from mask header.')

      if('patchmatrix' %in% names(patchinfo)) {
        lesmat = patchinfo$patchmatrix
        haslesmat = T
      }
      patchinfo.derived = 'Predefined'
    }

    voxindx = patchinfo$patchindx
    voxmask = patchinfo$patchimg.samples

    if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Found',patchinfo$npatches,'patches in', patchinfo$nvoxels, 'voxels -', round(patchinfo$nvoxels/patchinfo$npatches,1), 'times more voxels\n'))
  }


  # create matrix of lesions
  if (showInfo & !haslesmat) cat(paste(format(Sys.time(), tstamp) , 'Computing lesion matrix... '))
  if (showInfo & haslesmat) cat(paste(format(Sys.time(), tstamp) , 'Using existing lesion matrix... '))
  if (inputtype == 'antsImageList') { # list of antsImages
    if (!haslesmat) lesmat = imageListToMatrix(lesions.list, voxmask)
  } else if (inputtype == 'antsFiles') { # vector of filenames
    if (!haslesmat) lesmat = imagesToMatrix(lesions.list, voxmask)
  }

  if (showInfo) cat(paste0( paste(dim(lesmat), collapse='x'), '\n'))


  ###########
  # check the matrix is binary
  # at this point discrepancies come only from unchecked filenames
  if (binaryCheck) {
    if ( !all(lesmat %in% 0:1) )
      stop('Voxels other than 0/1 detected in lesion matrix.
           To find offending image, try:
           lesions=imageFileNames2ImageList(filenames)
           checkImageList(lesions,binaryCheck=T).')
  }


  # residualize by lesion size eventually
  if (correctByLesSize == 'behavior') {
    if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Correcting for lesion size:',correctByLesSize,'...\n'))
    behavior = residuals(lm(behavior ~ getLesionSize(lesions.list, showInfo)))
  } else if (correctByLesSize == 'voxel') {
    if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Correcting for lesion size:',correctByLesSize,'...\n'))
    lesvals = 1/sqrt(getLesionSize(lesions.list, showInfo))
    lesmat = apply(lesmat, 2, function(x) x*lesvals )
  }



  # run the analysis
  if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Running analysis:', method,'...'))
  if (method == 'BM') {
    lsm = lsm_BM(lesmat, behavior, nperm=nperm, ...)
  } else if (method == 'BMfast') {
    lsm = lsm_BMfast(lesmat, behavior, FWERperm = (multipleComparison=='FWERperm'),
                     pThreshold = pThreshold, nperm=nperm,
                     showInfo=showInfo, ...)
  } else if (method == 'regres') {
    lsm = lsm_regres(lesmat, behavior)
  } else if (method == 'regresPerm') {
    lsm = lsm_regresPerm(lesmat, behavior)
  } else if (method == 'regresfast') {
    lsm = lsm_regresfast(lesmat, behavior,
                         FWERperm = (multipleComparison=='FWERperm'), nperm=nperm, pThreshold=pThreshold,
                         clusterPerm=(multipleComparison=='clusterPerm'), mask=mask, voxindx=voxindx, samplemask=voxmask,
                         showInfo=showInfo, ...)
  } else if (method == 'ttest') {
    lsm = lsm_ttest(lesmat, behavior, ...)
  } else if (method == 'welch') {
    lsm = lsm_ttest(lesmat, behavior, var.equal = F, ...)
  } else if (method == 'chisq') {
    lsm = lsm_chisq(lesmat, behavior, runPermutations = F)
  } else if (method == 'chisqPerm') {
    lsm = lsm_chisq(lesmat, behavior, runPermutations = T, nperm=nperm)
  } else if (method == 'sccan') {
    lsm = lsm_sccan(lesmat, behavior, mask=mask, showInfo=showInfo, pThreshold=pThreshold, ...)
  } else {
    stop(paste0('Unrecognized method: "', method, '"'))
  }
  if (showInfo) cat('\n')


  # START POST PROCESSING THE OUTPUT
  statistic = lsm$statistic

  if ('zscore' %in% names(lsm)) {
    haszscore = T
    zscore = lsm$zscore
  } else { haszscore=F }

  if ('pvalue' %in% names(lsm)) {
    haspvalue = T
    pvalue = lsm$pvalue
  } else { haspvalue=F }


  # multiple comparison correction
  if (haspvalue) {
    if (multipleComparison %in% p.adjust.methods ) {
      if (showInfo & multipleComparison != 'none') cat(paste(format(Sys.time(), tstamp) , 'Correcting p-values:',multipleComparison,'...\n'))
      pvalue.adj = p.adjust(pvalue, method = multipleComparison)
      statistic[pvalue.adj>=pThreshold] = 0
      if (haszscore) zscore[pvalue.adj>pThreshold] = 0
    } else {
      pvalue.adj = pvalue
    }
  }

  # flip sign if asked
  if (flipSign) {
    if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Flipping statistics negative/positive...\n'))
    statistic = -(statistic)
    if (haszscore) zscore = -(zscore)
  }

  # a final check to make sure there are no
  # infinite, na, or nan values
  if (any(is.nan(statistic))) cat('WARNING: NaN values detected in statistic.\n')
  if (any(is.na(statistic))) cat('WARNING: NA values detected in statistic.\n')
  if (any(is.infinite(statistic))) cat('WARNING: Infinite values detected in statistic.\n')
  if (haspvalue && any(is.nan(pvalue.adj))) cat('WARNING: NaN values detected in pvalues.\n')
  if (haspvalue && any(is.na(pvalue.adj))) cat('WARNING: NA values detected in pvalues.v')
  if (haspvalue && any(is.infinite(pvalue.adj))) cat('WARNING: Infinite values detected in pvalues.\n')
  if (haszscore && any(is.nan(zscore))) cat('WARNING: NaN values detected in zscore\n')
  if (haszscore && any(is.na(zscore))) cat('WARNING: NA values detected in zscore\n')
  if (haszscore && any(is.infinite(zscore))) cat('WARNING: Infinite values detected in zscore\n')


  # put results in images
  if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Preparing images...\n'))
  vlsm.stat = makeImage(mask, voxval=statistic[voxindx])
  # optional outputs
  if (haspvalue) vlsm.pval = makeImage(mask, voxval=pvalue.adj[voxindx])
  if (haspvalue) vlsm.pval[mask==0] = 1
  if (haszscore) vlsm.zmap = makeImage(mask, voxval=zscore[voxindx])



  # call details
  if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Logging call details...\n'))
  noinfo = c('lesions.list', 'mask', 'patchinfo', 'behavior', '...') # skip info on these vars
  callinfo = mget(names(formals()),sys.frame(sys.nframe()))
  callinfo = callinfo[! names(callinfo) %in% noinfo]
  mcall = as.list(match.call())[-1]
  mcall = mcall[!names(mcall) %in% noinfo]
  addindx = (! names(mcall) %in% names(callinfo))
  callinfo = c(callinfo, mcall[addindx])
  callinfo$Subjects = length(behavior)
  callinfo$patchinfo = patchinfo.derived
  callinfo = c(LesymapVersion=ver,  callinfo)
  callinfo = c(Time=as.character(toc), callinfo)




  # return results
  output = list(stat.img=vlsm.stat)
  # optional
  if (exists('vlsm.zmap')) output$zmap.img=vlsm.zmap
  if (exists('vlsm.pval')) output$vlsm.pval=vlsm.pval

  output$mask.img=mask
  otherindx = (! names(lsm) %in% c('statistic', 'pvalue', 'zscore'))
  output = c(output, lsm[otherindx])
  if (writeavgles) output$average.img=avgles
  if (!noPatch) output$patchinfo = patchinfo
  output$callinfo = callinfo


  # save results
  if (!is.na(saveDir)) {
    if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Saving on disk...\n'))
    save.lesymap(lsm = output, saveDir = saveDir, callinfo = callinfo,  ...)
  }

  tic = Sys.time()
  runtime = paste(round(as.double(difftime(tic,toc)),1), units(difftime(tic,toc)))
  output$callinfo$Runtime = runtime
  if (showInfo) cat(paste(format(Sys.time(), tstamp) , 'Done!',runtime,'\n'))

  }, split = TRUE, type = "output") # end printedOutput

  output$outputLog = outputLog

  rm(lesions.list)
  invisible(gc())
  class(output) = c('lesymap', class(output))
  return(output)

}
