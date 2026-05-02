args <- commandArgs(trailingOnly = TRUE)

getArg <- function(flag) {
  idx <- which(args == flag)
  if(length(idx) == 0) stop(paste("Missing argument:", flag))
  args[idx + 1]
}
getArgOptional <- function(flag, default = NA) {
  idx <- which(args == flag)
  if(length(idx) == 0) return(default)
  args[idx + 1]
}
input_file <- getArg("-input")
prob_cutoff <- as.numeric(getArg("-prob"))
max_repeats <- as.numeric(getArgOptional("-max_repeats", Inf))


Vorlage <- read.table(input_file, 
                      stringsAsFactors=FALSE) 
colnames(Vorlage) <- "Repeat" 

classified <- read.table(paste0(input_file, ".crclass"), 
                         header=TRUE, 
                         sep=',') 

classify_sorted <- classified[match(Vorlage$Repeat, classified$Repeat), ] 

rownames(classify_sorted) <- NULL 






fasta_file <- file.path(dirname(input_file), "repeats_R1_und_R2.fasta")

fasta_lines <- readLines(fasta_file)
headers <- fasta_lines[grepl("^>", fasta_lines)]

groups <- sub("^>DR\\|Group\\|([0-9]+)\\|.*", "\\1", headers)

classify_sorted <- cbind(Group = groups, classify_sorted)








#------------ Filtern ------------ 

Prob_Greater_X <- classify_sorted[classify_sorted[,4] > prob_cutoff, ] 

Prob_Greater_X <- Prob_Greater_X[order(-Prob_Greater_X[,4]), ]

Prob_Greater_X <- Prob_Greater_X[seq_len(min(nrow(Prob_Greater_X), max_repeats)), ]

prob_str <- sprintf("%.3f", prob_cutoff)

out_filtered <- file.path(dirname(input_file),
                          paste0("Prob_", prob_str, "_filtered_and_classified_repeats.csv"))

write.csv(Prob_Greater_X, 
          out_filtered, 
          row.names = FALSE)