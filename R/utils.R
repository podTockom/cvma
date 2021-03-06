#' Print the output of \code{cvma}. Only prints 
#' the cross-validated summary measures. To print more
#' see \code{?summary.cvma}.
#' 
#' @param x An object of class \code{cvma}
#' @param ... Other options (not currently used)
#' 
#' @export
print.cvma <- function(x, ...){
	print(data.frame(x$cv_assoc[c("cv_measure","ci_low","ci_high","p_value")]))
}


#' Summarize results of \code{cvma} fit. Can be used to summarize
#' the weights obtained for each outcome (in both outer and inner
#' layers of cross-validation), the super learner fit for each outcome
#' (with learners fit on all the data), or the cross-validated associations
#' with each outcome. 
#' 
#' @param object An object of class \code{cvma}
#' @param aspect Can be \code{"weights"}, \code{"superlearner"},
#' \code{"outcomes"}, or \code{"learners"}
#' @param ... Other options (not currently used)
#' 
#' @export
#' 
#' @return A list summarizing relevant aspects of the \code{cvma} object
#' 
summary.cvma <- function(object, aspect = "outcomes", ...){
	if(aspect == "outcomes"){
		if(is.null(object$cv_assoc_all_y)){
			stop("To summarize associations with each outcome, return_all_y must be TRUE in call to cvma.")
		}
		out <- lapply(object$cv_assoc_all_y, function(cva){
			tmp <- data.frame(cva[c("cv_measure","ci_low","ci_high","p_value")])
		})
		names(out) <- object$y_names
		return(out)
	}else if(aspect == "weights"){
		out <- list()
		if(!is.null(object$outer_weight)){
			out$outer_weights <- data.frame(matrix(NA, nrow = 1,
		                                       ncol = length(object$y_names) + 1))
			colnames(out$outer_weights) <- c("training_folds", object$y_names)
			out$outer_weights$training_folds <- list(object$outer_weight$training_folds)
			out$outer_weights[,2:ncol(out$outer_weights)] <- object$outer_weight$weight
		}
		out$inner_weights <- data.frame(matrix(NA, nrow = length(object$inner_weight),
		                                       ncol = length(object$y_names) + 1))
		colnames(out$inner_weights) <- c("training_folds", object$y_names)
		out$inner_weights$training_folds <- lapply(object$inner_weight, "[[", "training_folds")
		out$inner_weights[,2:ncol(out$inner_weights)] <- Reduce(rbind, lapply(object$inner_weight, "[[", "weight"))
		return(out)
	}else if(aspect == "superlearner"){
		if(is.null(object$cv_assoc_all_y)){
			stop("To summarize super learner, return_outer_sl must be TRUE in call to cvma.")
		}
		out <- lapply(object$sl_fits, function(fit){
			tmp <- data.frame(fit[c("learner_names","learner_risks","sl_weight")])
		})
		names(out) <- object$y_names
		return(out)
	}else if(aspect == "learners"){
		if(is.null(object$cv_assoc_all_learners)){
			stop("To summarize learners, return_all_learners must be TRUE in call to cvma.")
		}
		n_learners <- length(object$cv_assoc_all_learners) / length(object$y_names)
		tmp_out <- split(object$cv_assoc_all_learners, sort(rep(1:length(object$y_names), n_learners)))
		names(tmp_out) <- object$y_names
		out <- lapply(tmp_out, function(tmpo){
			tmp <- lapply(tmpo, function(cva){
				data.frame(cva[c("SL_wrap","cv_measure","ci_low","ci_high","p_value")])
			})
			tmp2 <- Reduce(rbind, tmp)
			tmp2 <- tmp2[order(-tmp2$cv_measure),]
			row.names(tmp2) <- NULL
			tmp2
		})
		return(out)
	}
}


#' Get predictions on cvma object
#' 
#' @param object Object of class \code{cvma}
#' @param newdata A \code{data.frame} of predictors on which to obtain predictions
#' @param outer Return a vector of predictions from outer super learner (i.e., the one
#' fit on all V folds, default) or a matrix of predictions from inner super learners
#' fit on V-1 folds. 
#' @param ... Other options (not currently used)
#' @export
#' @importFrom stats predict
#' @return A list of predictions with named entries \code{y_weight} and \code{object$y_names}.
#' The former contains predictions of the weighted outcome, while the latter contains predictions of
#' the respective univariate outcome. Each entry in the outputted list is itself a list with two entries. 
#' The first is a vector of super learner predictions for the particular outcome, while the second
#' is a matrix with columns corresponding the the various learners predictions of the particular outcome. 
#' TO DO: Rethink formatting of output when outer = TRUE to be more like the format
#' when outer = FALSE? 
#' @examples
#' 
#' 
#' 
#' # TO DO: Add examples here

predict.cvma <- function(object, newdata, outer = TRUE, ...){
	if(outer){
		# loop over outcomes
		outcome_pred_list <- lapply(object$sl_fits, function(f){
			# loop over learners
			learner_pred <- Reduce(cbind, lapply(f$learner_fits, function(l){
				stats::predict(l$fit, newdata = newdata)
			}))
			colnames(learner_pred) <- object$learners
			sl_weight <- matrix(f$sl_weight)
			sl_pred <- learner_pred %*% sl_weight
			list(sl_pred = sl_pred, learner_pred = learner_pred)
		})
		names(outcome_pred_list) <- object$y_names
		# combined outcome predictions for superlearner
		sl_pred_mat <- Reduce(cbind, lapply(outcome_pred_list, "[[", "sl_pred"))
		y_weight <- matrix(object$outer_weight$weight)
		sl_pred_weight <- sl_pred_mat %*% y_weight
		# combined outcome predictions for learners
		learner_pred_weight <- sapply(1:length(object$learners), function(i){
			learner_pred_mat <- Reduce(cbind, lapply(outcome_pred_list, function(l){
				l$learner_pred[,i]
			}))
			learner_pred_mat %*% y_weight
		})
		colnames(learner_pred_weight) <- object$learners
		y_weight_out <- list(sl_pred = sl_pred_weight, learner_pred = learner_pred_weight)
		out <- c(list(y_weight = y_weight_out), outcome_pred_list)
	}else{
		if(is.null(object$inner_sl_fits)){
			stop("inner_sl_fits not returned in call to cvma")
		}
		# loop over outcomes
		outcome_pred_list <- lapply(object$inner_sl_fits, function(f){
			# loop over learners
			learner_pred <- Reduce(cbind, lapply(f$learner_fits, function(l){
				stats::predict(l$fit, newdata = newdata)
			}))
			colnames(learner_pred) <- object$learners
			sl_weight <- matrix(f$sl_weight)
			sl_pred <- learner_pred %*% sl_weight
			list(Yname = f$Yname, training_folds = f$training_folds, 
			     sl_pred = sl_pred, learner_pred = learner_pred)
		})
		# combined outcome predictions for superlearner
		# first split outcome_pred_list
		split_list <- split(outcome_pred_list, rep(1:object$V, length(object$y_names)))
		# now lapply over that list
		y_weight_out <- mapply(sl = split_list, w = object$inner_weight, function(sl, w){
			sl_pred_mat <- Reduce(cbind, lapply(sl, "[[", "sl_pred"))
			y_weight <- matrix(w$weight)
			sl_pred_weight <- sl_pred_mat %*% y_weight
			# and for learners
			learner_pred_mat <- sapply(1:length(object$learners), function(i){
				learner_pred <- Reduce(cbind, lapply(sl, function(l){ l$learner_pred[,i] }))
				learner_pred %*% y_weight
			})
			colnames(learner_pred_mat) <- object$learners
			list(Yname = "combined outcome", training_folds = sl[[1]]$training_folds, sl_pred = sl_pred_weight, learner_pred = learner_pred_mat)
		}, SIMPLIFY = FALSE)
		names(y_weight_out) <- NULL
		out <- c(y_weight_out, outcome_pred_list)
	}
	return(out)
}

