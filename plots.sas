/*******************************************************************************
Program generating box plot for primary endpoint and panelled bar chart for
secondary endpoint
*******************************************************************************/

/* Set global options */
options validvarname=upcase 
        nodate 
        nonumber 
        center
;

/* Import CSV visit1.csv and visit2.csv file to sas dataset */
data visit01;
   length column1 8 ssid vas visit_date $25 visit 8 primary_endpoint secondary_endpoint $25;

   do mname = 'visit1.csv', 'visit2.csv';
      infile "~" memvar=mname firstobs=2 dlm=';' dsd end=done;
      
      do while (not done);
         input column1 ssid $ vas $ visit_date $ visit primary_endpoint $ secondary_endpoint $;

         if primary_endpoint ne 'NA' then
            primend = input(primary_endpoint, best.);
         else
            call missing(primend);
         output;
      end;
   end;
   stop;
run;

/* Import demographics CSV data */
proc import datafile="~/demog.csv" 
            out=demog01 
            replace 
            dbms=csv;
run;

/* Get treatment from demographics data */
proc sql;
   create table visit02 as
   select a.*
        , b.treatment
     from visit01 as a
left join demog01 as b
       on a.ssid = b.ssid
   ;
quit;

/* Dataset to control graph attributes */
data attrmap;
   length id value linecolor fillcolor markercolor markersymbol $ 15;
   input id $ value $ linecolor $ fillcolor $ markercolor $ markersymbol $;
datalines;
trt Treatment Blue LightBlue Blue circle
trt Control Green LightGreen Green triangle
visit 1 LightBlue LightBlue LightBlue LightBlue
visit 2 LightGreen LightGreen LightGreen LightGreen
;

ods listing gpath="~" image_dpi=300;

/* Plot box plot for primary endpoint */
ods graphics on / reset=all 
                  imagename="boxplot" 
                  outputfmt=png 
                  width=15cm
                  height=10cm
;
title "Primary Endpoint - Box Plot";
proc sgplot data=visit02 dattrmap=attrmap;
   vbox primend / category=visit group=treatment attrid=trt;
   xaxis label="Visits";
   yaxis label="Primary Endpoint";
   keylegend / title="Treatment";
run;


/* Plot panelled bar chart for secondary endpoint */
ods graphics on / reset=all 
                  imagename="barchart" 
                  outputfmt=png 
                  width=15cm
                  height=10cm
;
title "Secondary Endpoint - Bar Plot";
proc sgpanel data=visit02 dattrmap=attrmap;
   where secondary_endpoint ne 'NA';
   panelby treatment / sort=descending;
   vbar secondary_endpoint / group=visit groupdisplay=cluster datalabel attrid=visit;
   colaxis label="Secondary Endpoint";
   rowaxis label="Count";
   keylegend / title="Visits";
run;

ods listing close;