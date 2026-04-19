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
dist_cutoff <- as.numeric(getArg("-dist"))
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

dist_values <- classify_sorted[,10]
prob_values <- classify_sorted[,4]

Dist_Greater_X <- classify_sorted[
  (!is.na(dist_values) & dist_values < dist_cutoff) |
    (is.na(dist_values) & prob_values > prob_cutoff),
]

Dist_Greater_X <- Dist_Greater_X[order(Dist_Greater_X[,10]), ]

Dist_Greater_X <- Dist_Greater_X[seq_len(min(nrow(Dist_Greater_X), max_repeats)), ]

out_filtered <- file.path(dirname(input_file),
                          paste0("Dist_", dist_cutoff, "_filtered_and_classified_repeats.csv"))
write.csv(Dist_Greater_X, 
          out_filtered, 
          row.names = FALSE)