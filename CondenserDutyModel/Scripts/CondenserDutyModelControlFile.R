####Step 1. Import input data####
#The input data is imported to 
setwd('C:/Users/vroland/Documents/R/ThermoElectric/data/CondenserDutyModel')
bogen<-importBogenData('Test CSV files/2015_bogen.csv')
bocoo<-importBocooData('Test CSV files/2015_bocoo.csv')
generator.data<-importGeneratorData('Test CSV files/2015_GeneratorData.csv')
sheet1GenFuelData<-importsheet1GenandFuelData('Test CSV files/2015_GenerationAndFuel.csv')
sheet4GenFuelData<-importsheet4GenandFuelData('Test CSV files/2015_GenerationData.csv')
boilerDesignData<-importBoilerdesignData('Test CSV files/2015_BoilerDesignInfo.csv')
boilerFuelData<-importBoilerFuelData('Test CSV files/2015_BoilerFuelData.csv')

#Generate Bogen Asscoiations
master.bogen.table<-boogencoo_table(bogen,bocoo,generator.data,sheet4GenFuelData)

#Merge Bogen Table with boiler level design, fuel, and generation datasets
#The data franes with the suffix *.bogen are returned 
BoilerDataBogen<-bogenMerge(data.out,boilerFuelData,boilerDesignData,sheet4GenFuelData)
list2env(BoilerDataBogen,.GlobalEnv)

#####Filter Qualifying Thermoelectric plants####
#This function filters EIA923_Schedules spreadsheet based on the following criteria: 
#CA (combined cycle steam part), CS (combined cycle single shaft), 
#CT (combined cycle combustion turbine part), and ST (steam turbine)
TEplants.primemovers<-c("CA","CS","CT","ST")
#Filter Industrial and Commercial facility plants
#Remove sectors Commercial NAICS Non-cogen, 
#Commercial NAICS Cogen, Industrial NAICS Non-cogen, Industrial NAICS Cogen, or numbers 4 – 7.
indComTEfac<-c(4,5,6,7)
#Filter out geothermal and solar-thermal plants
#Remove geothermal "GEO" and solar plants "SUn" codes in the reported fuel type
geo_solarTEplants<-c("SUN","GEO")
#Exclude nuclear plants 
#The lists 'TEplants.primemovers','indComTEfac', 'geo_solarTEplants' serce as input to the function
#and can be changed to user preference. Plantdb is the raw database of gernerator and fueld data
#or generator data.

masterlist<-masterlistfilter(sheet1GenFuelData,TEplants.primemovers,indComTEfac,geo_solarTEplants)
for(plant in masterlist$Plant.Code){
  
  usrPlantcode<-3
  fuel_summary<-boilerFuelsummary(usrPlantcode,Boiler.Fuel.Bogen)
  all_plants_fuel_summary<-rbind(all_plants_fuel_summary,fuel_summary)
  
  mo_fuel_heat<-MonthlyFuelHeatCalculation(fuel_summary)
  all_plants_monthly_fuel_heat<-rbind(all_plants_monthly_fuel_heat,mo_fuel_heat$FuelHeatOnly)
  
  
  mo.Fuel.Consumption.check<-MonthlyFuelConsumptionGeneration(mo_fuel_heat,plantDB,plantGenData)
  all_plants_discrepancy.table<-rbind(all_plants_discrepancy.table,mo.Fuel.Consumption.check$Discrepancy.Table)
  all_plants_Net.Gen.Data.For.Model<-rbind(all_plants_Net.Gen.Data.For.Model,mo.Fuel.Consumption.check$Net.Gen.Data)
  
  plant.boiler.fuel.data.bogencoo.withflags<-reportedFuelDataChecks(usrPlantcode,boiler.design.data,fuel_summary)
  #if(plant.boiler.fuel.data.bogencoo.withflags$heat.reported)
  all_plants_data.check<-rbind(all_plants_data.check,plant.boiler.fuel.data.bogencoo.withflags)
  
  
  Condenser.Duty.Output<-CalCondenserDuty(mo.Fuel.Consumption.check$Net.Gen.Data,mo_fuel_heat,plant.boiler.fuel.data.bogencoo.withflags)
  all_plants_Condenser.Duty<-rbind(all_plants_Condenser.Duty,Condenser.Duty.Output$Monthly.Condenser.Duty)
  all_plants_steam.heat<-rbind(all_plants_steam.heat,Condenser.Duty.Output$Steam.Heat)
  all_plants_nominal.losses<-rbind(all_plants_nominal.losses,Condenser.Duty.Output$Nominal.Losses)
  
}
