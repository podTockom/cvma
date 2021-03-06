% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_input.R
\name{get_risk_input}
\alias{get_risk_input}
\title{Create input list for \code{get_risk}}
\usage{
get_risk_input(split_Y, Ynames, all_fits, V, learners, all_sl, all_fit_tasks,
  all_weight, sl_control)
}
\arguments{
\item{split_Y}{The outcome matrix split by relevant validation folds.}

\item{Ynames}{The names of the outcomes. Used to search \code{all_fits}
and \code{all_sl}.}

\item{all_fits}{List of all learner fits.}

\item{V}{Number of folds.}

\item{learners}{Vector of super learner vectors.}

\item{all_sl}{List of all super learner weight fits.}

\item{all_fit_tasks}{List of all learner fit tasks (faster to search over than
search over all_fits).}

\item{all_weight}{List of all outcome weight fits.}

\item{sl_control}{List of super learner controls.}
}
\value{
List with each entry a list with entries: valid_fold (the number of the
corresponding fold), Y (outcome matrix in this outer-most validation fold), 
pred (matrix of outcome predictions for this validation fold from super learner 
fit in V-1 training folds), and y_weight (vector of outcome weights computed by 
minimizing V-2 cross-validated risk of composite super learner). 
\code{get_risk_input} is only used to compute the cross-validated risk of 
composite super learner on the composite outcome 
and so is only used in the outer most cross-validation layer.
}
\description{
\code{get_risk} computes the cross-validated risk of the entire 
procedure by calling \code{y_weight_control$cv_risk_fn} with this
input list.
}
