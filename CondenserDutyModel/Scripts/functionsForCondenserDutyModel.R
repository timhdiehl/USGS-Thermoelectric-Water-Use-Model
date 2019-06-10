####Required Libraries
library(dplyr)
library(qdapTools)
library(igraph)
library(sjmisc)


#helper function for merge tracking. This function comes from a larger package, but for the sake of simplicity only the function
#needed to do work in the model is included. More info can be found at the link below:
#devtools::install_github("adamMaier/reviewr", build_opts = c("--no-resave-data", "--no-manual"))

#If libraries are already installed comment out theese two lines:
#install.packages("dplyr")
#install.packages("qdapTools")


####The following functions are used to import the necceary files for the non-nuclear condenser duty model.
#Import bogen association table as provided by EIA
importBogenData<-function(bogen.file.path){
  if(!file.exists(bogen.file.path)) {
    stop("enter valid file path")
  }
  path<-bogen.file.path
  bogen.file.data.header<-read.csv(path,header=T,stringsAsFactors = F,nrows=5)
  bogen.file.data<-read.csv(path,header=T,stringsAsFactors = F,skip=5)
  if(!is.data.frame(bogen.file.data) || any(!c('Utility.ID','Utility.Name','Plant.Code','Plant.Name','Boiler.ID','Generator.ID') %in% names(bogen.file.data))) {
    stop("data must be a data.frame with columns 'Utility.ID','Utility.Name','Plant.Code','Plant.Name','Boiler.ID','Generator.ID' for this function to continue")
  }
  return(bogen.file.data)
}

#Import bocoo association table as provided by EIA
importBocooData<-function(bocoo.file.path){
  if(!file.exists(bocoo.file.path)) {
    stop("enter valid file path")
  }
  path<-bocoo.file.path
  bocoo.file.data.header<-read.csv(path,header=T,stringsAsFactors = F,nrows=5)
  bocoo.file.data<-read.csv(path,header=T,stringsAsFactors = F,skip=5)
  if(!is.data.frame(bocoo.file.data) || any(!c('Utility.ID','Utility.Name','Plant.Code','Plant.Name','Boiler.ID','Cooling.ID') %in% names(bocoo.file.data))) {
    stop("data must be a data.frame with columns 'Utility.ID','Utility.Name','Plant.Code','Plant.Name','Boiler.ID','Cooling.ID' for this function to continue")
  }
  return(bocoo.file.data)
}

#Import generator info as provided by EIA
importGeneratorData<-function(generator.data.file.path){
  if(!file.exists(generator.data.file.path)) {
    stop("enter valid file path")
  }
  path<-generator.data.file.path
  generator.data.header<-read.csv(path,header=T,stringsAsFactors = F,nrows=5)
  generator.data<-read.csv(path,header=T,stringsAsFactors = F,skip=5)
  if(!is.data.frame(generator.data) || any(!c('Utility.ID','Utility.Name','Plant.Code','Plant.Name','Generator.ID','Prime.Mover','Unit.Code') %in% names(generator.data))) {
    stop("data must be a data.frame with columns 'Utility.ID','Utility.Name','Plant.Code','Plant.Name','Generator.ID','Prime.Mover','Unit.Code' for this function to continue")
  }
  return(generator.data)
}

#Import plant generation and fuel data, sheet 1 - EIA923
importsheet1GenandFuelData<-function(plantDatafilepath){
  if(!file.exists(plantDatafilepath)) {
    stop("enter valid file path")
  }
  path<-plantDatafilepath
  sheet1.Gen.Fuel.data.header<-read.csv(path,header=T,stringsAsFactors = F,nrows=5)
  sheet1.Gen.Fuel.data<-read.csv(path,header=T,stringsAsFactors = F,skip=5)
  if(!is.data.frame(sheet1.Gen.Fuel.data) || any(!c('Plant.Id', 'Netgen.January','Netgen.February','Netgen.March',
                                                    'Netgen.April','Netgen.May','Netgen.June','Netgen.July',
                                                    'Netgen.August','Netgen.September','Netgen.October','Netgen.November','Netgen.December') %in% names(sheet1.Gen.Fuel.data))) {
    stop("data must be a data.frame with columns 'Plant.Id', 'Netgen.January','Netgen.February','Netgen.March',
         'Netgen.April','Netgen.May','Netgen.June','Netgen.July',
         'Netgen.August','Netgen.September','Netgen.October','Netgen.November','Netgen.December' for this function to continue")
  }
  names(sheet1.Gen.Fuel.data)[names(sheet1.Gen.Fuel.data)=='Plant.Id']<-"Plant.Code"
  sheet1.Gen.Fuel.data[c(20:96)][sheet1.Gen.Fuel.data[c(20:96)]=="."]<-NA
  sheet1.Gen.Fuel.data[c(20:96)]<-sapply(sheet1.Gen.Fuel.data[c(20:96)], function(x){gsub("\\,","",x)})
  sheet1.Gen.Fuel.data[c(20:96)]<-sapply(sheet1.Gen.Fuel.data[c(20:96)],as.numeric)
  return(sheet1.Gen.Fuel.data)
  }


#Import plant generation and fuel data, sheet 4 - EIA923
importsheet4GenandFuelData<-function(plantDatafilepath,boogencoo_table){
  if(!file.exists(plantDatafilepath)) {
    stop("enter valid file path")
  }
  
  path<-plantDatafilepath
  sheet4.Gen.Fuel.data.header<-sheet4.Gen.Fuel.data<-read.csv(path,header=T,stringsAsFactors = F,nrow=5)
  sheet4.Gen.Fuel.data<-read.csv(path,header=T,stringsAsFactors = F,skip=5)
  if(!is.data.frame(sheet4.Gen.Fuel.data) || any(!c('Plant.Id',
                                                    'Net.Generation.February','Net.Generation.March','Net.Generation.April','Net.Generation.May',
                                                    'Net.Generation.June','Net.Generation.July','Net.Generation.August','Net.Generation.October',
                                                    'Net.Generation.November','Net.Generation.December') %in% names(sheet4.Gen.Fuel.data))) {
    stop("data must be a data.frame with columns 'Plant.Id',
         'Net.Generation.February','Net.Generation.March','Net.Generation.April','Net.Generation.May',
         'Net.Generation.June','Net.Generation.July','Net.Generation.August','Net.Generation.October',
         'Net.Generation.November','Net.Generation.December' for this function to continue")
  }
  #sheet4.Gen.Fuel.data.bogencoo<-left_join(sheet4.Gen.Fuel.data,boogencoo_table,by=c("Plant.Code"="Plant.Code","Generator.Id"="Generator.ID"))
  names(sheet4.Gen.Fuel.data)[names(sheet4.Gen.Fuel.data)=='Plant.Id']<-"Plant.Code"
  names(sheet4.Gen.Fuel.data)[names(sheet4.Gen.Fuel.data)=='Generator.Id']<-"Generator.ID"
  sheet4.Gen.Fuel.data[c(14:26)][sheet4.Gen.Fuel.data[c(14:26)]=="."]<-NA
  sheet4.Gen.Fuel.data[c(14:26)]<-sapply(sheet4.Gen.Fuel.data[c(14:26)], function(x){gsub("\\,","",x)})
  sheet4.Gen.Fuel.data[c(14:26)]<-sapply(sheet4.Gen.Fuel.data[c(14:26)],as.numeric)
  return(sheet4.Gen.Fuel.data)
}

#This function accepts 
masterlistfilter<-function(plantDB,TEplants.primemovers,indComTEfac,geo_solarTEplants){
  heads<-names(plantDB)
  #Filter by prime mover
  TEplants<-plantDB %>% subset(.,Reported.Prime.Mover %in% TEplants.primemovers)
  #Filter Plants with plant ID 99999
  TEplants<-TEplants %>% subset(.,Plant.Code!=99999)
  #Filter out non-nuclear TE plants
  if("Nuclear.Unit.Id" %in% heads){
    TEplants<-TEplants %>% filter(.,is.na(Nuclear.Unit.Id))
  }
  
  #Filter Industrial and Commercial facility plants
  if("EIA.Sector.Number" %in% heads){
    p<-which(heads=="EIA.Sector.Number")
    colnames(TEplants)[p]<-"Sector.Number"
  }
  TEplants<-TEplants %>% filter(.,!Sector.Number %in% indComTEfac)
  
  #Filter out geothermal and solar-thermal plants
  if("Reported.Fuel.Type.Code" %in% heads){
    TEplants<-TEplants %>% filter(.,!Reported.Fuel.Type.Code %in% geo_solarTEplants)
  }
  
  return(TEplants)
}

#Import boiler design data. Requires boiler design data path, and bogencoo_table
#return boiler data bogencoo
importBoilerdesignData<-function(boilerdesigndata.file.path){
  if(!file.exists(boilerdesigndata.file.path)) {
    stop("enter valid file path")
  }
  path<-boilerdesigndata.file.path
  boiler.data.header<-read.csv(path,header=T,stringsAsFactors = F,nrow=5)
  boiler.data<-read.csv(path,header=T,stringsAsFactors = F,skip=5)
  if(!is.data.frame(boiler.data) || any(!c('Plant.Code','Boiler.ID') %in% names(boiler.data))) {
    stop("data must be a data.frame with columns 'Plant.Code', 'Boiler.ID' for this function to continue")
  }
  #names(boiler.data)[names(boiler.data)=='Boiler.Id']<-"Boiler.ID"
  boiler.data[,c(27,28)][boiler.data[,c(27,28)]==""]<-NA
  boiler.data[c(27:28)]<-sapply(boiler.data[c(27:28)], function(x){as.numeric(gsub("%","",as.character(x)))})
  boiler.data[c(27:28)]<-sapply(boiler.data[c(27:28)], function(x){x/100})
  
  #boiler.data.bogencoo<-merge(boiler.data,boogencoo_table,by.x=c("Plant.Code","Boiler.ID"),by.y=c("Plant.Code","Boiler.ID.y"))
  return(boiler.data)
}

#Import boiler fuel data for fuel summary, requires boile design data path, and bogencoo_table
#return boiler.data.bogencoo
importBoilerFuelData<-function(boiler.fuel.data.file.path){
  if(!file.exists(boiler.fuel.data.file.path)) {
    stop("enter valid file path")
  }
  path<-boiler.fuel.data.file.path
  boiler.fuel.data.header<-read.csv(path,header=T,stringsAsFactors = F,nrow=5)
  boiler.fuel.data<-read.csv(path,header=T,stringsAsFactors = F,skip=5)
  if(!is.data.frame(boiler.fuel.data) || any(!c('Plant.Id', 'Boiler.Id') %in% names(boiler.fuel.data))) {
    stop("data must be a data.frame with columns 'Plant.Id', 'Boiler.Id' for this function to continue")
  }
  names(boiler.fuel.data)[names(boiler.fuel.data)=='Plant.Id']<-"Plant.Code"
  names(boiler.fuel.data)[names(boiler.fuel.data)=='Boiler.Id']<-"Boiler.ID"
  
  boiler.fuel.data[boiler.fuel.data=="."]<-NA
  boiler.fuel.data[c(16:64)]<-sapply(boiler.fuel.data[c(16:64)], function(x){gsub("\\,","",x)})
  boiler.fuel.data[c(16:64)]<-sapply(boiler.fuel.data[c(16:64)],as.numeric)
 
  #boiler.fuel.data.bogencoo<-merge(boiler.fuel.data,boogencoo_table,by.x=c("Plant.Code","Boiler.ID"),by.y=c("Plant.Code","Boiler.ID.y"))
  return(boiler.fuel.data)
}

#Function for unit mapping
associate <- function(data,save_image=FALSE){
  
  # test: Check that data provided by user is correct
  if(!is.data.frame(data) || any(!c('Plant.Code', 'Generator.ID','Boiler.ID') %in% names(data))) {
    stop("data must be a data.frame with columns 'Plant.Code', 'Generator.ID', and 'Boiler.ID' for this function to continue")
  }
  
  # extract vector of unique plant IDs
  plants <- unique(data$Plant.Code)
  
  # preallocated dataframe for output
  d_out <- data.frame()
  
  # for-loop that does the work
  for(i in 1:length(plants)){
    
    # grab plant[i]
    plant_i <- plants[i]
    
    # subset data by plant_i
    dsub <- dplyr::filter(data, Plant.Code==plant_i)
    
    # prepare 'edges' to pass to graph function
    edges <- cbind(dsub$Generator.ID,dsub$Boiler.ID)
    
    # build graph from edges
    g <- graph_from_edgelist(edges)
    
    # extract 'groups' from graph
    groups <- clusters(g)$membership
    
    # put everything together for plant_i
    d <- data.frame(Boiler.ID=names(groups), 
                    Bogen=paste0(plant_i,"^",groups), 
                    Plant.Code=plant_i,
                    row.names=NULL,
                    stringsAsFactors = F)
    
    # interatively append rows
    d_out <- rbind(d_out,d)
    
    # if save_image==TRUE, then save images
    if(save_image) { 
      
      png(file = paste("C:\\Users\\vroland\\Documents\\R\\ThermoElectric\\figures\\bogen\\","plant",plant_i, '.png', sep = ''))
      
      plot(g, vertex.size=5,
           vertex.label.dist=0.5,
           vertex.color="red",
           edge.arrow.size=0.7,
           main=paste0("plant ", plant_i))
      dev.off()
      
    }
    
  } 
  
  # return output data
  #return(d_out)
  return(d_out)
}

#This function associates boiler and generators, and receives input of: EIA860:boiler association, boiler design data, EIA923:boiler fuel data, boiler generation data(sheet4)
#vis_out = variable saves to home directory network charts of bogen associations
bogen_assocv.v2<-function(bogen,generator.data,generation.data,boilerFuelData,vis_out=F){
  #These first few lines are only cleaning up the datasets and preparing them for the association process
  #Bogen table, set generator.id and boiler.id variables to character strings
  bogen$Generator.ID<-as.character(bogen$Generator.ID)
  bogen$Boiler.ID<-as.character(bogen$Boiler.ID)
  #Drop utlity id variable from bogen table
  bogen<-select(bogen,-c(Utility.ID))
  
  #Generator data
  gen_860<-generator.data
  gen_860$Generator.ID<-as.character(gen_860$Generator.ID)
  #Boiler generation data, set generator.id variable to character strings
  generation.data<-sheet4GenFuelData
  generation.data$Generator.ID<-as.character(generation.data$Generator.ID)
  
  #Aggregate total net generation by plant and generator.id
  generation.data.gb<-generation.data %>% group_by(.,Plant.Code,Generator.ID)
  gen_923<-generation.data.gb %>% summarise(Net.Generation.mwh=sum(Net.Generation.Year.To.Date))
  #Create a variable to track which boilers are missing from the 923 report
  gen_923$missing.from.923<-FALSE
  
  #Helper Function, Full join function that tracks the results of full joins
  full_join_track <- function(x, y, by = NULL, suffix = c(".x", ".y"),
                              .merge = FALSE, ...){
    
    # Checking to make sure used variable names are not already in use
    if(".x_tracker" %in% names(x)){
      message("Warning: variable .x_tracker in left data was dropped")
    }
    if(".y_tracker" %in% names(y)){
      message("Warning: variable .y_tracker in right data was dropped")
    }
    if(.merge & (".merge" %in% names(x) | ".merge" %in% names(y))){
      stop("Variable .merge already exists; change name before proceeding")
    }
    
    # Adding simple merge tracker variables to data frames
    x[, ".x_tracker"] <- 1
    y[, ".y_tracker"] <- 1
    
    # Doing full join
    joined <- full_join(x, y, by = by, suffix = suffix,  ...)
    
    # Calculating merge diagnoses 
    matched <- joined %>%
      filter(!is.na(.x_tracker) & !is.na(.y_tracker)) %>%
      NROW()
    unmatched_x <- joined %>%
      filter(!is.na(.x_tracker) & is.na(.y_tracker)) %>%
      NROW()
    unmatched_y <- joined %>%
      filter(is.na(.x_tracker) & !is.na(.y_tracker)) %>%
      NROW()
    
    # Print merge diagnoses
    message(
      unmatched_x, " Rows ONLY from left data frame", "\n",
      unmatched_y, " Rows ONLY from right data frame", "\n",
      matched, " Rows matched"
    )
    
    # Create .merge variable if specified
    if(.merge){
      joined <- joined %>%
        mutate(.merge = 
                 case_when(
                   !is.na(.$.x_tracker) & is.na(.$.y_tracker) ~ "left_only",
                   is.na(.$.x_tracker) & !is.na(.$.y_tracker) ~ "right_only",
                   TRUE ~ "matched"
                 )
        )
    }
    
    # Dropping tracker variables and returning data frame
    joined <- joined %>%
      select(-.x_tracker, -.y_tracker)
    return(joined)
  }
  
  #Merge generator data and generation data 
  merged<-full_join_track(gen_860,gen_923,by=c("Plant.Code","Generator.ID"),.merge=T)
  missing.from.860<-merged[merged$.merge=='right_only',]
  
  #Compile list of all generators
  gens<-full_join_track(gen_923,gen_860,by=c("Plant.Code","Generator.ID"),.merge=F)
  
  #Select columns to keep after merge
  gens<-select(gens,c("Plant.Code","Generator.ID","Unit.Code","Net.Generation.mwh","missing.from.923"))
  gens$Generator.ID<-as.character(gens$Generator.ID)
  
  #Linked bogen associations
  
  bga.1<-full_join_track(gens,bogen,by=c("Plant.Code","Generator.ID"),.merge=F)
  bga.1<-select(bga.1,-c(Utility.Name,Plant.Name,Steam.Plant.Type))
  bga_assn<-bga.1[!is.na(bga.1$Boiler.ID),]
  bga_assn$bga.source<-'eia860.org'
  
  #Unlinked bogen associations
  bga_unassn<-bga.1[is.na(bga.1$Boiler.ID),]
  bga_unassn<-select(bga_unassn,-c(Boiler.ID))
  
  #String Matching unassigned boilers based on fuel data
  bf.923<-boilerFuelData
  bf.923$Boiler.ID<-as.character(bf.923$Boiler.ID)
  #Sum monthly fuel heat
  bf.923$total.fuel.mmbtu.per.unit<-rowSums(bf.923[,c(28:39)])
  #Calculate total fuel heat
  bf.923$Total.Heat.Content.MMBTU<-bf.923$Total.Fuel.Consumption.Quantity*bf.923$total.fuel.mmbtu.per.unit
  #Summarize heat content by plant and boiler id
  bfd.gb<-bf.923 %>% group_by(Plant.Code,Boiler.ID) %>% summarize(Boiler.Total.Heat.Content.MMBTU=sum(Total.Heat.Content.MMBTU,na.rm=F))
  bfd.gb<-select(bfd.gb,c(Plant.Code,Boiler.ID))
  #bfd.gb<-unique(bfd.gb[c("Plant.Code","Boiler.ID")])
  #bga.1<-select(bga.1,-c(.merge))
  bfd.923<-ungroup(bfd.gb)
  bfd.923<-unique(bfd.923)
  
  #Create list of boilers not in bogen associations(bga) table
  bga.2<-full_join_track(bfd.923,bga.1,by=c("Plant.Code","Boiler.ID"),.merge=T)
  
  bfd.not.in.bga<-bga.2[bga.2$.merge=="left_only",]
  bfd.not.in.bga<-select(bfd.not.in.bga,-c(.merge))
  bfd.not.in.bga<-as.data.frame(bfd.not.in.bga)
  bfd.not.in.bga$Generator.ID.2<-bfd.not.in.bga$Boiler.ID
  bga_unassn<-ungroup(bga_unassn)
  
  #bfd.not.in.bga$Boiler.ID.2<-bfd.not.in.bga$Boiler.ID
  #Match unassociated generators and boilers
  
  bga_unassn.2<-left_join(bga_unassn,bfd.not.in.bga[,c("Plant.Code","Boiler.ID","Generator.ID.2")],by=c("Plant.Code","Generator.ID"="Boiler.ID"))
  #bga_unassn.2$Boiler.ID<-bga_unassn.2$Generator.ID
  bga_unassn.2$Boiler.ID<-bga_unassn.2$Generator.ID.2
  bga_unassn.2<-select(bga_unassn.2,-c(Generator.ID.2))
  bga_unassn.2<-bga_unassn.2[order(bga_unassn.2$Plant.Code),]
  bga_unassn.2$bga.source<-"None"
  bga_unassn.2$bga.source[!is.na(bga_unassn.2$Generator.ID)]<-"string_assn"
  #bga_unassn.2$Boiler.ID<-bga_unassn.2$Generator.ID
  #colnames(bga_unassn.2)[colnames(bga_unassn.2)=="Boiler.ID.2"]<-"Boiler.ID"
  #Collection of all Bogens assigned and unassigned with their sources and assignment method
  bga_assn<-ungroup(bga_assn)
  
  bga.2<-rbind(bga_assn,bga_unassn.2)
  bga.2<-bga.2[order(bga.2$Plant.Code),]
  #bga.2$Boiler.ID<-ifelse(is.na(bga.2$Boiler.ID) && !is.na(bga.2$Unit.Code),bga.2$Generator.ID,bga.2$Boiler.ID)
  bga.2$missing.from.923[is.na(bga.2$missing.from.923)]<-T
  
  
  #Connecting Bogens with Unit.Codes
  bga.2$Unit.Code<-na_if(bga.2$Unit.Code,"")
  bga.2.units<-bga.2[!is.na(bga.2$Unit.Code),]
  bga.2.gen.units<-select(bga.2.units,-c(Boiler.ID))
  bga.2.boil.units<-select(bga.2.units,c(Plant.Code,Boiler.ID,Unit.Code))
  bga.2.boil.units<-subset(bga.2.boil.units,!is.na(Boiler.ID))
  
  
  #Merge the boilers with units
  bga.unit.compilation<-merge(bga.2.gen.units,bga.2.boil.units,by=c("Plant.Code","Unit.Code"),all=T)
  
  bga.unit.compilation$bga.source[is.na(bga.unit.compilation$bga.source)]<-'unit_connection'
  #List of boilers with no unit code
  bga2.non.units<-bga.2 %>% subset(is.na(Unit.Code))
  
  bga.3<-rbind(bga2.non.units,bga.unit.compilation)
  bga.3<-bga.3[order(bga.3$Plant.Code),]
  
  bga.3.1<-bga.3 %>% select(c(Plant.Code,Generator.ID,Boiler.ID,Unit.Code,bga.source,Net.Generation.mwh,missing.from.923))
  
  #Cleanup
  #Identify Plants with generation but no associated boilers
  bad.plants<-bga.3.1 %>% subset(c(is.na(Boiler.ID)&Net.Generation.mwh>0)) %>% select(Plant.Code) 
  bad.plants.out<-bga.3.1 %>% subset(c(is.na(Boiler.ID)&Net.Generation.mwh>0))
  
  bga.3.1<-ungroup(bga.3.1)
  bad.plants<-ungroup(bad.plants)
  bga.3.2<-full_join_track(bga.3.1,bad.plants,by="Plant.Code",.merge=T)
  
  
  #bga.3.2$merge<-apply(bga.3.2[c("source.x","source.y")],1,function(x) paste(na.omit(x),collapse=""))
  
  # bga.3.2<-inner_join(bga.3.1,bad.plants,by="Plant.Code") %>% mutate(merge="both")
  # bga.3.3<-bind_rows(bga.3.2,anti_join(bga.3.1,bad.plants,by="Plant.Code") %>% mutate(merge="left_only"))
  bga.3.2$Plant.w.bad.generator<-ifelse(bga.3.2$.merge=="matched",T,F)
  
  bga.3.3<-bga.3.2 %>% select(-c(.merge))
  
  bga.3.3$unmapped.but.in.923<-ifelse(is.na(bga.3.3$Boiler.ID) && bga.3.3$missing.from.923==T && bga.3.3$Net.Generation.mwh==0,T,F)
  bga.3.3$unmapped<-ifelse(is.na(bga.3.3$Boiler.ID),T,F)
  
  bga.3.4<-select(bga.3.3,-c(Net.Generation.mwh))
  bga.3.4$Unit.Code[is.na(bga.3.4$Unit.Code)]<-"none"
  
  bga.out<-bga.3.4[order(bga.3.4$Plant.Code,bga.3.4$Generator.ID),]
  
  bga.out<-unique(bga.out)
  
  
  bga.for.multigrph<-bga.out %>% select(Plant.Code,Generator.ID,Boiler.ID,Unit.Code)
  bga.for.multigrph.1<-bga.for.multigrph %>% subset(Boiler.ID!="none") %>% na.omit() %>% unique()
  
  bga.for.multigrph.1$generators<-paste("p",bga.for.multigrph.1$Plant.Code,"_g",bga.for.multigrph.1$Generator.ID,sep="_")
  bga.for.multigrph.1$boilers<-paste("p",bga.for.multigrph.1$Plant.Code,"_b",bga.for.multigrph.1$Boiler.ID,sep="_")
  
  p.sub<-as.data.frame(select(bga.for.multigrph.1,c(Plant.Code,Generator.ID,Boiler.ID)))
  p.sub<-p.sub[with(p.sub,order(Plant.Code,Generator.ID)),]
  vis_out=F
  out<-associate(bga.for.multigrph.1,save_image = vis_out)
  data.out<-merge(out,bga.out,by=c("Plant.Code","Boiler.ID"),all.x=T)
  data.out$Generator.ID<-ifelse(is.na(data.out$Generator.ID),data.out$Boiler.ID,data.out$Generator.ID)
  data.out.list<-list(bogen.key=data.out,bad.plants=bad.plants.out)
  return(data.out.list)
}

#Establish bogencoo associations
#return bogencoo table. Bogen and Bocoo are the keys provided EPA923 Database
# boogencoo_table<-function(bogen,generator.data,generation.data,boiler.fuel.data){
#   # test: Check that data provided by user is correct
#   if(!is.data.frame(bogen) || any(!c('Plant.Code', 'Boiler.ID','Generator.ID') %in% names(bogen))) {
#     stop("data must be a data.frame with columns 'Plant.Code', 'Boiler.ID', and 'Generator.ID' for this function to continue")
#   }
#   if(!is.data.frame(boiler.fuel.data) || any(!c('Plant.Code', 'Boiler.ID','Cooling.ID') %in% names(boiler.fuel.data))) {
#     stop("data must be a data.frame with columns 'Plant.Code', 'Boiler.ID', and 'Cooling.ID' for this function to continue")
#   }
#   if(!is.data.frame(generator.data) || any(!c('Plant.Code','Plant.Name','Generator.ID','Prime.Mover','Unit.Code') %in% names(generator.data))){
#     stop("data must be a data.frame with the columns 'Plant.Code','Plant.Name','Generator.ID','Prime.Mover','Unit.Code' for this function to continue")
#   }
#   if(!is.data.frame(generation.data) || any(!c('Plant.Code','Plant.Name','Generator.ID','Prime.Mover','Unit.Code') %in% names(generator.data))){
#     stop("data must be a data.frame with the columns 'Plant.Code','Plant.Name','Generator.ID','Prime.Mover','Unit.Code' for this function to continue")
#   }
#   
#   bogen$Generator.ID<-as.character(bogen$Generator.ID)
#   bogen$Boiler.ID<-as.character(bogen$Boiler.ID)
#   
#   generation.data$Generator.ID<-as.character(generation.data$Generator.ID)
#   
#   generation.data.gb<-generation.data %>% group_by(.,Plant.Code,Generator.ID) %>% 
#     summarise(.,TotNetGen=sum(Net.Generation.Year.To.Date))
#   
#   
#   
#   #bogen<-bogen %>% select(.,c("Plant.Code","Boiler.ID","Generator.ID"))
#   for(plant in 1:nrow(generator.data)){ 
#   generator.data$Boiler.ID[plant][generator.data$Prime.Mover[plant]=="CA"||generator.data$Prime.Mover[plant]=="CT"]<-generator.data$Generator.ID[plant]
#   }
#   generator.data.out<-merge(generator.data,bogen,by=c("Plant.Code","Generator.ID","Utility.Name","Plant.Name","Utility.ID"),all=T)
#   
#   generator.data.out<-merge(generator.data.out,sheet4GenFuelData,by.x=c("Plant.Code","Generator.ID","Plant.Name","State","Prime.Mover"),by.y=c("Plant.Code","Generator.ID","Plant.Name","Plant.State","Reported.Prime.Mover"),all.y=T)
#   # for(plant in 1:nrow(generator.data.out)){ 
#   #   if(is.na(generator.data.out$Prime.Mover[plant])){
#   #     generator.data.out$Prime.Mover[plant]<-generator.data$Prime.Mover[c(generator.data.out$Plant.Code[plant]==generator.data$Plant.Code & generator.data.out$Boiler.ID.y[plant]==generator.data$Boiler.ID)]
#   #   }
#   # }
#   #generator.data.out$Boiler.ID.x[is.na(generator.data.out$Boiler.ID.x)]<-generator.data.out$Boiler.ID.y[is.na(generator.data.out$Boiler.ID.x)]
#   generator.data.out$Boiler.ID.y[is.na(generator.data.out$Boiler.ID.y)]<-generator.data.out$Boiler.ID.x[is.na(generator.data.out$Boiler.ID.y)]
#   
#   
#   #generator.data.out$Bogen<-paste(generator.data.out$Plant.Code,generator.data.out$Boiler.ID.y,sep="^") #generator.data.out$Generator.ID,
#   
#   generator.data.out$Boiler.ID.y[generator.data.out$Boiler.ID.y==""]<-NA
#   # unit.code.lookup<-generator.data.out %>% 
#   #                   subset(.,!is.na(Boiler.ID.y)) %>% 
#   #                   select(.,c("Plant.Code","Generator.ID","Prime.Mover","Unit.Code","Boiler.ID.y")) %>% 
#   #                   unique()
#   gen.units.comp<-select(generator.data.out,-Boiler.ID.y)
#   boil.units.comp<-select(generator.data.out,-Generator.ID)
#   cc.merge<-merge(gen.units.comp,boil.units.comp,by=c("Plant.Code","Unit.Code","Prime.Mover"),all=T)
#   
#   cc.merge.v2<-cc.merge %>% select(.,c(Plant.Code,Unit.Code,Generator.ID,Utility.ID.x,
#                                     Utility.Name.x,Plant.Name.x,State.x,County.x,Prime.Mover,
#                                     Boiler.ID.y))
#   colnames(cc.merge.v2)<-c("Plant.Code","Unit.Code","Generator.ID","Utility.ID",
#                            "Utility.Name","Plant.Name","State","County","Prime.Mover",
#                            "Boiler.ID")
#   cc.merge.v3<-na.omit(cc.merge.v2$Boiler.ID)
#   cc.merge.v4<-unique(cc.merge.v2)
#   cc.merge.v4$Boiler.ID[is.na(cc.merge.v4$Boiler.ID)]<-cc.merge.v4$Generator.ID[is.na(cc.merge.v4$Boiler.ID)]
#   
#   d_out<-associate(cc.merge.v4,save_image = F)
#   result<-left_join(cc.merge.v4,d_out,by=c("Plant.Code","Generator.ID"))
#     
#   }
#   cc.merge.v4$
#   
#   bogen.key<-x_allv2 %>% select(.,c("Plant.Code","Generator.ID","Boiler.ID.x","Boiler.ID.y","Bogen"))
#   return(bogen.key)
#   }

bogenMerge<-function(bogen.key,boiler.fuel.data,boiler.design.data,sheet.4.gen.data){
  boiler.fuel.data$Boiler.ID<-as.character(boiler.fuel.data$Boiler.ID)
  bogen.key$Boiler.ID<-as.character(bogen.key$Plant.Code)
  boiler.design.data$Boiler.ID<-as.character(boiler.design.data$Boiler.ID)
  sheet.4.gen.data$Generator.ID<-as.character(sheet.4.gen.data$Generator.ID)
  
  boiler.fuel.data.bogen<-merge(boiler.fuel.data,bogen.key,by.x=c("Plant.Code","Boiler.ID"),by.y=c("Plant.Code","Boiler.ID"),all.x=T)
  boiler.data.bogen<-merge(boiler.design.data,bogen.key,by.x=c("Plant.Code","Boiler.ID"),by.y=c("Plant.Code","Boiler.ID"),all=T)
  sheet4.Gen.Fuel.data.bogen<-left_join(sheet.4.gen.data,bogen.key,by=c("Plant.Code"="Plant.Code","Generator.ID"))
  fuel.design.gen.bogencoo<-list(Boiler.Fuel.Bogen=boiler.fuel.data.bogen,Boiler.Data.Bogen=boiler.data.bogen,Sheet4.Gen.Fuel.Bogen=sheet4.Gen.Fuel.data.bogen)
  return(fuel.design.gen.bogencoo)
}



#Compute boiler fuel summary, requires Plant.Code and Boiler Fuel Data Table
#returns plant bogencoo fuel summary
boilerFuelsummary<-function(usrPlantCode,Boiler.Fuel.Data){
  # test: Check that data provided by user is correct
  fuel.data.heads<-c('Quantity.Of.Fuel.Consumed.January','Quantity.Of.Fuel.Consumed.February', 'Quantity.Of.Fuel.Consumed.March', 
  'Quantity.Of.Fuel.Consumed.April','Quantity.Of.Fuel.Consumed.May', 
  'Quantity.Of.Fuel.Consumed.June', 'Quantity.Of.Fuel.Consumed.July',
  'Quantity.Of.Fuel.Consumed.August', 'Quantity.Of.Fuel.Consumed.September',
  'Quantity.Of.Fuel.Consumed.October', 'Quantity.Of.Fuel.Consumed.November',
  'Quantity.Of.Fuel.Consumed.December','MMbtu.Per.Unit.January','MMbtu.Per.Unit.February','MMbtu.Per.Unit.March', 
  'MMbtu.Per.Unit.April','MMbtu.Per.Unit.May', 'MMbtu.Per.Unit.June',  
  'MMbtu.Per.Unit.July','MMbtu.Per.Unit.August','MMbtu.Per.Unit.September',
  'MMbtu.Per.Unit.October','MMbtu.Per.Unit.November','MMbtu.Per.Unit.December')
  
  if(!is.data.frame(Boiler.Fuel.Data) || any(!fuel.data.heads %in% names(Boiler.Fuel.Data))) {
    stop("fuel data must be a data frame with names: 'Quantity.Of.Fuel.Consumed.January','Quantity.Of.Fuel.Consumed.February', 'Quantity.Of.Fuel.Consumed.March', 
         'Quantity.Of.Fuel.Consumed.April',	'Quantity.Of.Fuel.Consumed.May', 
         'Quantity.Of.Fuel.Consumed.June', 'Quantity.Of.Fuel.Consumed.July',
         'Quantity.Of.Fuel.Consumed.August', 'Quantity.Of.Fuel.Consumed.September',
         'Quantity.Of.Fuel.Consumed.October', 'Quantity.Of.Fuel.Consumed.November',
         'Quantity.Of.Fuel.Consumed.December','MMbtu.Per.Unit.January','MMbtu.Per.Unit.February','MMbtu.Per.Unit.March', 
         'MMbtu.Per.Unit.April','MMbtu.Per.Unit.May', 'MMbtu.Per.Unit.June',  
         'MMbtu.Per.Unit.July','MMbtu.Per.Unit.August','MMbtu.Per.Unit.September',
         'MMbtu.Per.Unit.October','MMbtu.Per.Unit.November','MMbtu.Per.Unit.December' for this function to continue")
  }
    
  if(!usrPlantCode %in% unique(Boiler.Fuel.Data$Plant.Code )){
    stop("enter valid Plant.Code for this function to continue")
  }
  
  x<-Boiler.Fuel.Data %>% subset(.,Plant.Code==usrPlantCode) %>% select(.,c(Plant.Code,Bogen,Reported.Fuel.Type.Code,Reported.Prime.Mover,fuel.data.heads,Total.Fuel.Consumption.Quantity))
  
  plant.fuel.summary<-x %>% 
                      group_by(Plant.Code,Bogen,Reported.Fuel.Type.Code) %>% 
                      summarise_if(is.numeric,funs(sum))
  
  fuel.dominance.summary<-plant.fuel.summary %>% 
                          group_by(Plant.Code,Bogen) %>%
                          mutate(.,Bogen.Total.Consumption=sum(Total.Fuel.Consumption.Quantity)) 
  fuel.dominance.summary<-fuel.dominance.summary %>%   
                          mutate(.,Percent.of.Fuel.Consumption=Total.Fuel.Consumption.Quantity/Bogen.Total.Consumption*100)
  fuel.dominance.summary$Dominant.Fuel[fuel.dominance.summary$Percent.of.Fuel.Consumption>=95]<-fuel.dominance.summary$Reported.Fuel.Type.Code[fuel.dominance.summary$Percent.of.Fuel.Consumption>=95]
    
  
  plant.fuel.summary.list<-list(PlantFuelSummary=plant.fuel.summary,FuelDominance=fuel.dominance.summary)
  return(plant.fuel.summary.list)
}

#DataChecks:
#Check that boiler efficiency has been reported, 1-yes, 2-no
#Check that boiler has reported fuel data, 1-yes, 0-no
#Check that boiler has reported fuel heat data, 1-yes, 0-no
reportedFuelDataChecks<-function(usrPlantCode,boiler.design.data.bogencoo,plant.fuel.summary){
  if(!usrPlantCode %in% unique(boiler.design.data.bogencoo$Plant.Code )){
    stop("enter valid Plant.Code for this function to continue")
  }
  
  x<-boiler.design.data.bogencoo %>% subset(.,Plant.Code==usrPlantCode) %>% select(.,c(Plant.Code,Bogen,Primary.Fuel.1,Efficiency.100..Load,Efficiency.50..Load))
  x<-left_join(x,plant.fuel.summary)  
  x$eff.reported[!is.na(x$Efficiency.100..Load)]<-1
  x$eff.reported[is.na(x$eff.reported)]<-0
  
  #Check that boiler has reported fuel data, 1-yes, 0-no
  x$fuel.reported[!is.na(x$Total.Fuel.Consumption.Quantity)]<-1
  x$fuel.reported[is.na(x$Total.Fuel.Consumption.Quantity)]<-0
  
  x$heat.reported<-ifelse(x$Total.Fuel.Consumption.Quantity>0 & !is.na(x$Reported.Fuel.Type.Code),1,0)
  #x$heat.reported[is.na(x$Total.Fuel.Consumption.Quantity)||x$Total.Fuel.Consumption.Quantity==0]<-0
 
  
  fuel.codes<-list(
    biomass=c("AB","BLQ","MSB","OBL","OBS","SLW","TDF","WDS"),
    coal=c("ANT","BIT","LOG","PC","SUB","WC"),
    gas=c("BFG","LFG","NG","OBG","OG","PG","SGC","SGP"),
    oil=c("DFO","JF","KER","RFO","WO"),
    other=c("OTH"))
  
  #Assign primary fuel type from EPA_860_Schedule 6C
  x$PrimeFuel_6_2<-lookup(x$Primary.Fuel.1,fuel.codes)
  
  
  #Assign primary fuel type from EPA_923_Bogen Primary fuel type data
  lookuptable_923<-data.frame(a=x$Bogen,b=x$Reported.Fuel.Type.Code)
  
  inter_x<-left_join(x,lookuptable_923,by=c("Bogen"="a","Reported.Fuel.Type.Code"="b"))
  
  
  inter_x$PrimeFuel_923<-lookup(inter_x$Reported.Fuel.Type.Code,fuel.codes)
  #x<-x %>% select(.,-c(42))
  
  inter_x$PrimeFuel_6_2[is.na(inter_x$PrimeFuel_6_2)]<-"blank"
  inter_x$PrimeFuel_923[is.na(inter_x$PrimeFuel_923)]<-"blank"
  
  plant.boiler.fuel.data.bogencoo<-inter_x
  
  return(unique(plant.boiler.fuel.data.bogencoo))
}

#Calcualte monthly fuel heat
MonthlyFuelHeatCalculation<-function(plant.fuel.summary){
  if(!is.data.frame(plant.fuel.summary)){
    stop("There is an error in the plant fuel summary, check plant fuel data. ")
  }
  
  plant.fuel.heat.table<-plant.fuel.summary %>% group_by(Bogen)%>% mutate(January.Fuel.Heat = Quantity.Of.Fuel.Consumed.January * MMbtu.Per.Unit.January,
                                                            February.Fuel.Heat = Quantity.Of.Fuel.Consumed.February * MMbtu.Per.Unit.February,
                                                            March.Fuel.Heat=Quantity.Of.Fuel.Consumed.March * MMbtu.Per.Unit.March,
                                                            April.Fuel.Heat=Quantity.Of.Fuel.Consumed.April * MMbtu.Per.Unit.April,
                                                            May.Fuel.Heat=Quantity.Of.Fuel.Consumed.May * MMbtu.Per.Unit.May,
                                                            June.Fuel.Heat=Quantity.Of.Fuel.Consumed.June * MMbtu.Per.Unit.June,
                                                            July.Fuel.Heat=Quantity.Of.Fuel.Consumed.July * MMbtu.Per.Unit.July,
                                                            August.Fuel.Heat=Quantity.Of.Fuel.Consumed.August * MMbtu.Per.Unit.August,
                                                            September.Fuel.Heat=Quantity.Of.Fuel.Consumed.September * MMbtu.Per.Unit.September,
                                                            October.Fuel.Heat=Quantity.Of.Fuel.Consumed.October * MMbtu.Per.Unit.October,
                                                            November.Fuel.Heat=Quantity.Of.Fuel.Consumed.November * MMbtu.Per.Unit.November,
                                                            December.Fuel.Heat=Quantity.Of.Fuel.Consumed.December * MMbtu.Per.Unit.December)
  plant.fuel.heat.table.v2<-round(plant.fuel.heat.table[c(29:40)],0)
  plant.fuel.heat.table.v3<-cbind(plant.fuel.summary$Plant.Code,plant.fuel.heat.table$Bogen,plant.fuel.heat.table.v2)
  names(plant.fuel.heat.table.v3)[c(1:2)]<-c("Plant.Code","Bogen")
  
  zero.fuel.heat<-c()
  for(month.col in 2:ncol(plant.fuel.heat.table.v3)){
    zero.fuel.heat[month.col]<-which(plant.fuel.heat.table.v3[month.col]==0)
  }
  # plant.fuel.heat.table.by.bogencoo<-plant.fuel.heat.table.v3 %>% group_by(plant.fuel.heat.table$Bogen) %>% summarise_all(funs(sum))
  # plant.fuel.heat.table.by.bogencoo$Plant.Code<-plant.fuel.heat.table$Plant.Code[1:nrow(plant.fuel.heat.table.by.bogencoo)]
  # plant.fuel.heat.table.by.bogencoo<-plant.fuel.heat.table.by.bogencoo[c(14,1:13)]
  # 
  #out<-list(Plant.Fuel.Heat.Table=plant.fuel.heat.table,FuelHeatOnly=plant.fuel.heat.table.by.bogencoo)
   return(plant.fuel.heat.table.v3)
  
}

#Import plant generation and fuel data, sheet 1 - EIA923
# plantDatafilepath<-"C:\\Users\\vroland\\Documents\\R\\ThermoElectric\\data\\EIA923_Schedules_2_3_4_5_M_12_2015_Final_Revision.csv"
# plantDB<-read.csv(plantDatafilepath,header=T,stringsAsFactors = FALSE)
# 
# 
# 
# 
# #Import plant Generator Data, sheet 4 - EIA923
# plantGenDatafilepath<-"C:\\Users\\vroland\\Documents\\R\\ThermoElectric\\f923_2015\\EIA923_Schedules_2_3_4_5_M_12_2015_GeneratorData.csv"
# plantGenData<-read.csv(plantGenDatafilepath,header = T,stringsAsFactors = FALSE)
# 

#Calculate fuel consumption from electricity generation and check with generator data sheet 1 verus sheet 3 comparison
MonthlyFuelConsumptionGeneration<-function(mo.fuel.heat,plantDB,plantGenDB){
  data_sheet3<-mo.fuel.heat %>% ungroup() %>% mutate(Total.Fuel.Heat=rowSums(.[3:14]))
  
  data_sheet1<-plantDB %>% subset(.,Plant.Code==mo.fuel.heat$Plant.Code)
  
  data_sheet1_v2<-data_sheet1 %>% mutate(January.Fuel.Heat.Elec = Elec_Quantity.January * Elec_MMBtu.January,
                                         February.Fuel.Heat.Elec = Elec_Quantity.February * Elec_MMBtu.February,
                                         March.Fuel.Heat.Elec=Elec_Quantity.March * Elec_MMBtu.March,
                                         April.Fuel.Heat.Elec=Elec_Quantity.April * Elec_MMBtu.April,
                                         May.Fuel.Heat.Elec=Elec_Quantity.May * Elec_MMBtu.May,
                                         June.Fuel.Heat.Elec=Elec_Quantity.June * Elec_MMBtu.June,
                                         July.Fuel.Heat.Elec=Elec_Quantity.July * Elec_MMBtu.July,
                                         August.Fuel.Heat.Elec=Elec_Quantity.August * Elec_MMBtu.August,
                                         September.Fuel.Heat.Elec=Elec_Quantity.September * Elec_MMBtu.September,
                                         October.Fuel.Heat.Elec=Elec_Quantity.October * Elec_MMBtu.October,
                                         November.Fuel.Heat.Elec=Elec_Quantity.November * Elec_MMBtu.November,
                                         December.Fuel.Heat.Elec=Elec_Quantity.December * Elec_MMBtu.December)
  
  data_sheet1_v2<-data_sheet1_v2 %>% ungroup() %>% mutate(Total.Electric.MMBtu=rowSums(.[98:109]))
  
  #Compare and select net generation data (sheet 1 and sheet 4)
  sheet4.Gen.data<-plantGenDB %>% subset(.,Plant.Code==mo.fuel.heat$Plant.Code)
  
  sheet1.plant.total.elec<-sum(data_sheet1_v2$Elec.Fuel.Consumption.MMBtu)
  sheet1.plant.total<-sum(data_sheet1_v2$Total.Fuel.Consumption.MMBtu)
  sheet3.plant.total<-sum(data_sheet3$Total.Fuel.Heat)
  
  
  if(sheet1.plant.total.elec!= sheet3.plant.total){
    exported.heat<-sheet3.plant.total-sheet1.plant.total.elec
  }else{
    exported.heat<-0
  }
  
  #reported_sheet3<-sum(data_sheet3$Total.Fuel.Consumption.MMBtu)
  
  if(sheet1.plant.total==sheet3.plant.total){
    final.fuel.heat.consumption<-sheet1.plant.total
    discrepancy<-0
    discrepancy.percent<-0
  }else{
    final.fuel.heat.consumption<-sheet3.plant.total
    discrepancy<-abs(sheet3.plant.total-sheet1.plant.total)
    discrepancy.percent<-abs(discrepancy/sheet1.plant.total*100)
  }
  
  if(data_sheet1_v2$Reported.Prime.Mover=='ST' & data_sheet1_v2$Net.Generation..Megawatthours.!=sheet4.Gen.data$Net.Generation.Year.To.Date){
    net.gen.data<-sheet4.Gen.data[c(14:26)]
  }else{
    net.gen.data<-data_sheet1_v2[c(80:91,96)]
  }
    net.gen.data2<-cbind(net.gen.data,as.character(data_sheet1$Reported.Prime.Mover[data_sheet1$Net.Generation..Megawatthours.>0]),stringsAsFactors=F)
    names(net.gen.data2)[14]<-"Reported.Prime.Mover"
  sheet1_sheet3.discrepancy.table<-c()
  sheet1_sheet3.discrepancy.table<-cbind(mo.fuel.heat$Plant.Code,sum(data_sheet1_v2$Total.Fuel.Consumption.MMBtu),sheet1.plant.total,sheet3.plant.total,exported.heat,discrepancy,discrepancy.percent)
  colnames(sheet1_sheet3.discrepancy.table)<-c("Plant.Code","Page.1.Total.MMBtu","Total.MMBtu.Elec","Sheet3.Plant.Total","Exported Heat","Discrepency.MMBtu","Percent.of.Page.1")
  
  data.out<-list(Discrepancy.Table=as.data.frame(unique(sheet1_sheet3.discrepancy.table)),Net.Gen.Data=net.gen.data2)
  return(data.out)
  #return(as.data.frame(sheet1_sheet3.discrepancy.table))
  
}

#Calculate monthly condenser duty
CalCondenserDuty<-function(Net.Generation.Data,Mo.Fuel.Heat,boiler.Fuel.Eff.data){
  steam.heat<-as_data_frame()
  nominal.losses<-as_data_frame()
  condenser.duty<-as_data_frame()
  Mo.Fuel.Heat<-Mo.Fuel.Heat %>% group_by(Plant.Code,Bogen) %>% summarize_all(sum)
  
 
  Mo.Fuel.Heat.v2<-Mo.Fuel.Heat[-c(1,2)]
  Net.Generation.Data.v2<-as_data_frame(lapply(Net.Generation.Data,function(x){ifelse(x<0,NA,x)}))
  Prime.Mover<-rep(Net.Generation.Data.v2$Reported.Prime.Mover,nrow(Mo.Fuel.Heat.v2))
  Net.Generation.Data.v2<-Net.Generation.Data.v2[-c(13,14)]
  steam.heat.all.bogen<-c()
  nominal.losses.all.bogen<-c()
  condenser.duty.all.bogen<-c()
  for(i in 1:nrow(Net.Generation.Data.v2)){
    steam.heat<-Mo.Fuel.Heat.v2[i,]*boiler.Fuel.Eff.data$Efficiency.100..Load[i]
    steam.heat.all.bogen<-rbind(steam.heat.all.bogen,steam.heat)
    if(Prime.Mover[i]=="ST"){
      nominal.losses<-Mo.Fuel.Heat.v2[i,]*0.02
      nominal.losses.all.bogen<-rbind(nominal.losses.all.bogen,nominal.losses)
    }else{
      nominal.losses<-Mo.Fuel.Heat.v2[i,]*0.22
      nominal.losses.all.bogen<-rbind(nominal.losses.all.bogen,nominal.losses)
    }
    condenser.duty<-steam.heat.all.bogen[i,]-nominal.losses.all.bogen[i,]-Net.Generation.Data.v2[i,]*3.412
    condenser.duty.all.bogen<-rbind(condenser.duty.all.bogen,condenser.duty)
    }
    #condenser.duty<-steam.heat-nominal.losses-Net.Generation.Data.v2*3.412
  
    #condenser.duty<-steam.heat.all.bogen-nominal.losses.all.bogen-Net.Generation.Data.v2*3.412
    
  # for(col in 1:ncol(Mo.Fuel.Heat.v2)){
  #   for(row in 1:nrow(Mo.Fuel.Heat.v2)){
  #     steam.heat[row,col]<-Mo.Fuel.Heat.v2[row,col]*boiler.Fuel.Eff.data$Efficiency.100..Load[row]
  #     if(Prime.Mover[row]=="ST"){
  #       nominal.losses[row,col]<-Mo.Fuel.Heat.v2[row,col]*0.02
  #     }else{
  #       nominal.losses[row,col]<-Mo.Fuel.Heat.v2[row,col]*0.22
  #     }
  #     condenser.duty[row,col]<-steam.heat[row,col]-nominal.losses[row,col]-Net.Generation.Data.v2[row,col]*3.412
  #     }
  # }
    condenser.duty<-as.data.frame(round(condenser.duty.all.bogen,0))
    nominal.losses.duty<-round(nominal.losses.all.bogen,0)
    steam.heat<-round(steam.heat.all.bogen,0)
    condenser.duty.out<-cbind(as.character(unlist(Mo.Fuel.Heat[,1])),as.character(unlist(Mo.Fuel.Heat[2])),condenser.duty)
    steam.heat.out<-cbind(Mo.Fuel.Heat[c(1:2)],steam.heat)
    nominal.losses.out<-cbind(Mo.Fuel.Heat[c(1:2)],nominal.losses.duty)
    
  # condenser.duty<-round(condenser.duty,0)
  # nominal.losses.duty<-round(nominal.losses,0)
  # steam.heat<-round(steam.heat,0)
  # condenser.duty.out<-cbind(Mo.Fuel.Heat[c(1:2)],condenser.duty)
  # steam.heat.out<-cbind(Mo.Fuel.Heat[c(1:2)],steam.heat)
  # nominal.losses.out<-cbind(Mo.Fuel.Heat[c(1:2)],nominal.losses.duty)
  # 
  #steam.heat<-Mo.Fuel.Heat*boiler.Fuel.Eff.data$Efficiency.100..Load[row]
  names(condenser.duty.out)<-c("Plant.Code","Bogen","January.Duty","February.Duty","March.Duty","April.Duty","May.Duty","June.Duty",
                          "July.Duty","August.Duty","September.Duty","October.Duty","November.Duty","December.Duty")
  names(steam.heat.out)<-c("Plant.Code","Bogen","January.Steam.Heat","February.Steam.Heat","March.Steam.Heat","April.Steam.Heat","May.Steam.Heat","June.Steam.Heat",
                           "July.Steam.Heat","August.Steam.Heat","September.Steam.Heat","October.Steam.Heat","November.Steam.Heat","December.Steam.Heat")
  names(nominal.losses.out)<-c("Plant.Code","Bogen","January.Losses","February.Losses","March.Losses","April.Losses","May.Losses","June.Losses",
                                                 "July.Losses","August.Losses","September.Losses","October.Losses","November.Losses","December.Losses")
  
  condenser.duty.cal.list<-list(Monthly.Condenser.Duty=condenser.duty.out,Steam.Heat=steam.heat.out,Nominal.Losses=nominal.losses.out)
  return(condenser.duty.cal.list)
}
  



  
  
    
                      
  
