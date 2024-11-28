### To deconvolute a hospitalization incidence curve into a case incidence
### curve
### Input 1: daily hospitalization number (HospitalIncidence)
### Input 2: PDF for hospitalization delay (starting from 0 day, 1 day increment) (HospitalDelay)
### Output: Deconvoluted incidence curve (starting from TypicalHospitalDelay days shifted back from the start of the HospitalIncidence curve)

DeconvolutionIncidence1 <- function(HospitalIncidence, HospitalDelay){
  #sizes
  Temp = length(HospitalIncidence);
  NumOfDays = Temp
  if (NumOfDays == 0){
    stop('Error in deconvolution: Empty hospitalization incidence vector');
  } 
  NumOfDelay = length(HospitalDelay);
  if (NumOfDelay == 0){
    stop('Error in deconvolution: Empty hospitalization delay vector');
  }
  HospitalDelayCDF = HospitalDelay;
  for (i in 1:length(HospitalDelay)){
    HospitalDelayCDF[i] = sum(HospitalDelay[1:i]);
  } 
  # time to hospitalization with highest prob
  TypicalHospitalDelay = which(HospitalDelay == max(HospitalDelay));
  
  # The initial guess for infection incidence (up to a multiple)
  IncidenceCurve = HospitalIncidence;
  
  # transition probability
  p = matrix(0,NumOfDays,NumOfDays);
  for (j in 1:NumOfDays){
    for (i in j : NumOfDays){
      if (i-j < NumOfDelay){
        p[i,j] = HospitalDelay[i-j+1]
       }
     }
   }
  
  # observation prob
  q = matrix(0,NumOfDays,1);
  for (j in 1:NumOfDays){
    q[j] = sum(p[,j])
    if ((q[j]>1) || (q[j]==0)){
      print('Error in deconvolution: q_j');
      print(q[j,1]);
      stop()
    }
  }
  
  p_hat = matrix(0,NumOfDays,NumOfDays);
  for (j in 1:NumOfDays){
    for (i in j : NumOfDays){
      p_hat[i,j] = p[i,j]/q[j];
    }
  }
  
  # initialize the intermediate parameters
  DelayTemp = matrix(0,NumOfDays,1);
  
  # routine
  for (k in 1:10){
    for (i in 1:NumOfDays){
      DelayTemp[i] = crossprod(p_hat[i,1:NumOfDays],IncidenceCurve);
    }
    for (j in 2:NumOfDays){
      itemp = 0;
      for (i in 2:NumOfDays){
        itemp = itemp + (p[i,j]*HospitalIncidence[i]/DelayTemp[i]);
      }
      IncidenceCurve[j] = IncidenceCurve[j]/q[j]*itemp;
    }
  }
  
  for (i in 0:(length(HospitalDelay)-1)){
    temp = IncidenceCurve[length(IncidenceCurve)-i]/HospitalDelayCDF[i+1];
    IncidenceCurve[length(IncidenceCurve)-i] = temp;
  }
  
  return(IncidenceCurve)
}
