# Clear the workspace
rm(list = ls())

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))


# Load necessary libraries
library(openxlsx)
library(ggplot2)

# assume that the mean and SD of the incubation period are 7.6 and 5.8
# respectively (gamma distributed)
incubationMean = 7.6;
incubationSD = 5.8;

# obtain the scale and shape parameters of incubation period
gammaScale = incubationSD*incubationSD/incubationMean;
gammaShape = incubationMean/gammaScale;

# obtain the convolution "pdf" (in terms of days) 
pdfConvolFG  = pgamma(1:31,shape=gammaShape,scale=gammaScale)-pgamma(0:30,shape=gammaShape,scale=gammaScale);
pdfConvolFG = c(pdfConvolFG,1-sum(pdfConvolFG));

# Read your data (assuming it's in CSV format)
us_data <- read.csv('~../../data/mpox_USA.csv')

# Convert the 'Day' column to Date format
us_data$Day <- as.Date(us_data$Day,  origin = "1899-12-30")

# Set the reference date (dateZero) as the earliest date in your data
dateZero <- min(us_data$Day)

# Create a numeric representation of the days since dateZero
us_data$Day_numeric <- as.numeric(us_data$Day - dateZero) + 1


# Now, use the 'Daily cases' column that represents confirmed cases
counts_per_day <- data.frame(date = us_data$Day_numeric, new_cases_onset = us_data$Daily.cases)

# Handle missing dates by creating a complete sequence of days
days_sequence <- data.frame(date = seq(1, max(us_data$Day_numeric)))
counts_per_day <- merge(days_sequence, counts_per_day, by = 'date', all.x = TRUE)
counts_per_day$new_cases_onset[is.na(counts_per_day$new_cases_onset)] <- 0

# Save the counts per day (optional)
write.csv(counts_per_day, '../../output/US/us_mpox_epi_curve_onset_R.csv', row.names = FALSE)

# obtain the time series of the infection dates of all cases
caseReport_US = counts_per_day$new_cases_onset;
caseReport_US[caseReport_US==0] = 1e-9; # to avoid calculation errors

source("DeconvolutionIncidence1.R")
deconvolInfection2 = DeconvolutionIncidence1(caseReport_US,pdfConvolFG);
deconvolInfection2 = as.data.frame(deconvolInfection2);
colnames(deconvolInfection2)= c('all_cases');

# plot both the time series of infection dates and reported dates 
library(ggplot2)

caseReport_US_table = as.data.frame(cbind(1:length(caseReport_US), caseReport_US));
colnames(caseReport_US_table) = c('date', 'number');
deconvol_table = as.data.frame(cbind(1:length(caseReport_US), deconvolInfection2));
deconvol_table = head(deconvol_table, -5);
colnames(deconvol_table) = c('date', 'number');

ggplot()+ geom_line(data= caseReport_US_table, aes(x=date, y=number),color = "red")+
  geom_line(data= deconvol_table, aes(x=date, y=number), color = 'blue')+theme_classic();

# save the result 
write.csv(deconvolInfection2, '../../output/US/deconvolInfection_US_R.csv',,row.names = FALSE)


