% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/getLesionLoad.R
\name{getLesionLoad}
\alias{getLesionLoad}
\title{getLesionLoad}
\usage{
getLesionLoad(lesions.list, parcellation, label = NA, mask = NA,
  binaryCheck = F, keepAllLabels = F, minSubjectPerLabel = "10\%")
}
\arguments{
\item{lesions.list}{list of antsImages or filenames.
Must be binary (0 and 1 values).}

\item{parcellation}{ansImage or filename of the parcellated volumes. A
parcellation is an image brain regions showned as with integer values
(i.e. ,1,2,3,...).}

\item{label}{(default=NA) you can ask to get output for a specific label
in the parcellation volume (i.e., label=122).}

\item{mask}{(default=NA) if this mask is specified (antsImage or filename)
lesioned voxels outside the mask are ignored. This is not a
good choice, but in case you need it its there.}

\item{binaryCheck}{(default=FALSE) check whether lesion maps are binary (0/1).
Will output an error if lesion files are not binary.}

\item{keepAllLabels}{(default=FALSE) by default labels are removed if affected
in just few subjects. Setting this to TRUE will keep all labels.}

\item{minSubjectPerLabel}{minimum number of subjects a parcel
must be lesioned to keep and return it.}
}
\value{
\itemize{
 \item{output}{Matrix of lesion loads between 0 and 1. 1 means 100\% lesioned.
 Each column is a single parcel and each row a single subject. Parcel
 numbers are placed as column names.}
 }
}
\description{
Computes lesion loads from a series of images. A parcellation
image (or simple mask) is required to define the regions from
which to compute the lesion load.
}
\examples{
lesydata = file.path(find.package('LESYMAP'),'extdata')
filenames = Sys.glob(file.path(lesydata, 'lesions', '*.nii.gz'))
lesions = imageFileNames2ImageList(filenames[1:10])
parcellation = antsImageRead(
file.path(lesydata,'template', 'Parcellation_403areas.nii.gz'))
lesload = getLesionLoad(lesions, parcellation)

}
\author{
Dorian Pustina
}
