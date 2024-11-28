# 2024-09-30
# MPOX DRC
# Estimation of Rt

rm(list = ls());

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

library(EpiEstim)
library(ggplot2)
library(MASS)
library(openxlsx)

# UK study: https://www.bmj.com/content/379/bmj-2022-073153
# Incubation period: 7.6 (95% CrI 6.5-9.9) or 7.8 (6.5-9.2)
# Serial interval: 8.0 (95% CrI 6.5-9.8) or 9.5 (7.4-12.3)

dateZero = as.Date("2024-01-01")

# read the epi curve for mpox (obtained using Matlab codes)
DRCEpiCurve = read.csv('../../output/DRC/deconvolInfection_DRC_R.csv',header = TRUE);
DRCEpiCurve$all_cases = DRCEpiCurve$all_cases;
DRCEpiCurve$date = dateZero+(1:length(DRCEpiCurve$all_cases));

# obtain the minimum and maximum dates of the epi curve
minDate = min(DRCEpiCurve$date,na.rm = TRUE);
maxDate = max(DRCEpiCurve$date,na.rm = TRUE);

# adjust the epi curve for future analysis (make it integers)
DRCEpiCurve$all_cases[DRCEpiCurve$all_cases<0.2] =  0; 
DRCEpiCurve$all_cases[DRCEpiCurve$all_cases>=0.2&DRCEpiCurve$all_cases<1] =  1;
rec = data.frame(dates = maxDate+(-(length(DRCEpiCurve$date)-1):0),
                 all_cases = round(DRCEpiCurve$all_cases));
minDate = min(rec$dates[rec$all_cases>=1]);
rec = rec[rec$dates>=minDate,];

# 6. Estimate Rt
# call function
## fixing the random seeds
MCMC_seed  = 1;
overall_seed  = 2;
mcmc_control = make_mcmc_control(seed = MCMC_seed,burnin = 1000,thin = 10);
# fitting a Gamma distribution for the SI
dist = "G";
maxT = length(rec$dates)
t_start = seq(2,(maxT-6));
t_end = t_start+6;
config <- make_config(list(mean_si = 9.7, 
                           std_si = 11.2,
                           mcmc_control = mcmc_control,
                           seed = overall_seed, 
                           t_start = t_start,
                           t_end=t_end,
                           n1 = 1000, 
                           n2 = 100));

# Excluding imported cases, start estimation
inputIncRev = rec[,c('dates','all_cases')];
colnames(inputIncRev) = c('dates','I');
minDate = rec$dates[1];
res_si_from_data <- estimate_R(inputIncRev,
                               method = "parametric_si",
                               config = config);

# record Rt estimated 
tempRec = res_si_from_data;
outputRec = tempRec$R;
# add dates
outputRec$t_start = outputRec$t_start+minDate-1;
outputRec$t_end = outputRec$t_end+minDate-1;
# create the file storing the Rt estimates
write.xlsx(outputRec,paste0('../../output/DRC/mpox_Rt_local_transmissibility_DRC.xlsx'),sheetName = 'Sheet1',rowNames = FALSE);
# do the same for the serial interval estimates
write.xlsx(tempRec$SI.Moments,'../../output/DRC/mpox_Rt_serial_interval_DRC.xlsx',sheetName = 'Sheet1',rowNames = FALSE)

