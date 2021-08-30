/*******************************************************************************
Program generating primary endpoint and secondary endpoint summaries
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

/* Convert promary endpoint to numeric and create extra records for 'Total' */
data visit03;
   set visit02;

   if primary_endpoint ne 'NA' then
      primend = input(primary_endpoint, best32.);
   output;

   treatment = 'Total';
   output;
run;

/* Summarize primary endpoint */
proc summary data=visit03 nway;
   var primend;
   class visit treatment;
   output out=primend01 n=_n mean=_mean std=_sd median=_median min=_min max=_max;
run;

data primend02;
   set primend01;
   length n mean_sd median min_max $25;
   
   n = put(_n,3.);
   mean_sd = put(_mean,5.1)||' ('||put(_sd,5.2)||')';
   median = put(_median,5.1);
   min_max = put(_min,5.1)||' ; '||put(_max,5.1);

   drop _:;
run;

proc transpose data=primend02 out=primend03 name=stats;
   var n mean_sd median min_max;
   by visit;
   id treatment;
run;

/* Summarize secondary endpoint */
proc summary data=visit03;
   class treatment visit secondary_endpoint;
   types treatment*visit treatment*visit*secondary_endpoint;
   output out=secondend01;
run;

proc sql;
   create table secondend02 as
   select a.treatment
        , a.visit
        , a.secondary_endpoint
        , case
             when missing(a.secondary_endpoint) then put(a._freq_,3.)
             else put(a._freq_,3.)||' ('||put(a._freq_/b._freq_*100, 5.1)||')'
          end as count length=25
     from secondend01 as a
left join secondend01(where=(missing(secondary_endpoint))) as b
       on a.treatment = b.treatment
      and a.visit = b.visit
 order by visit
        , secondary_endpoint
   ;
quit;

proc transpose data=secondend02 out=secondend03(drop=_name_);
   var count;
   id treatment;
   by visit secondary_endpoint;
run;

data demog02;
   set demog01;
   output;

   treatment = 'Total';
   output;
run;

/*Calculate number of subjects per treatment */
proc sql;
   create table nos01 as
   select treatment
        , count(ssid) as nos
        , put(calculated nos,3.) as cnos length=25
     from demog02
 group by treatment
   ;
quit;

proc transpose data=nos01 out=nos02(drop=_name_);
   var cnos;
   id treatment;
run;

proc format;
   value $stats
      'MEAN_SD' = 'Mean (SD)'
      'MIN_MAX' = 'Min ; Max'
      other = [propcase()]
   ;

   invalue statsord
      'N' = 1
      'MEAN_SD' = 2
      'MEDIAN' = 3
      'MIN_MAX' = 4
   ;

   value $secondend
      ' ' = 'N'
      'NA' = 'N/A'
      other = [$25.]
   ;

   invalue secondendord
      Mild = 1
      Moderate = 2
      Severe = 3
      NA = 4
   ;
run;

/* Combine all summaries and format as per output requirments */
data final;
   set nos02(in=a)
       primend03(in=b)
       secondend03
   ;

   length group01label group02label rowlabel $25;

   if a then
   do;
      rowlabel = 'Number of subjects';
      group01ord = 1;
   end;
   else if b then
   do;
      group01label = 'Primary Endpoint';
      group02label = '   Visit '||strip(put(visit,best.));
      rowlabel = repeat(' ',7)||put(stats,$stats.);

      group01ord = 2;
      roword = input(primend,statsord.);
   end;
   else
   do;
      group01label = 'Secondary Endpoint, n (%)';
      group02label = '   Visit '||strip(put(visit,best.));
      rowlabel = repeat(' ',7)||put(secondary_endpoint,$secondend.);
      
      group01ord = 3;
      roword = input(secondary_endpoint,secondendord.);
   end;
   drop visit stats secondary_endpoint;
run;

/* Print report to .docx file */
title j=center "Efficacy endpoints summary - All Subjects";
ods rtf file='~/efficacy.rtf' bodytitle;
proc report data=final headline center;
   column group01ord group01label group02label roword rowlabel treatment control total;

   define group01ord   / order order=internal noprint missing;
   define group01label / order order=internal noprint missing;
   define group02label / order order=internal noprint missing;
   define roword       / order order=internal noprint missing;
   define rowlabel     / "" display style(column)={asis=on};
   define treatment    / "Treatment" display style(column)={just=c};
   define control      / "Control" display style(column)={just=c};
   define total        / "Total" display style(column)={just=c};

   compute before group01label;
      len=lengthn(group01label);
      line @1 group01label $varying25. len;
   endcomp;

   compute before group02label / style={asis=on};
      len=lengthn(group02label);
      line @1 group02label $varying25. len;
   endcomp;
run;
ods rtf close;