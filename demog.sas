/*******************************************************************************
Program generating demographics summary
*******************************************************************************/

/* Set global options */
options validvarname=upcase 
        nodate 
        nonumber 
        center
;

/* Import demographics CSV file to sas dataset */
proc import datafile="~/demog.csv" 
            out=demog01 
            replace 
            dbms=csv;
run;

/* The Age variable is imported as character since there are few 'NA'
   Convert age to numeric excluding NAs
   Create a seperate record for 'Total'
*/
data demog02;
   set demog01;
   
   if not notdigit(strip(age)) then
      nage = input(age, best.);

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

/* Count number of subjects by age abd treatment */
proc summary data=demog02;
   class treatment gender;
   types treatment treatment*gender;
   output out=gender01;
run;


/* Calculate percentage by age and treatemnt */
proc sql;
   create table gender02 as
   select a.treatment
        , a.gender
        , case
             when missing(a.gender) then put(a._freq_,3.)
             else put(a._freq_,3.)||' ('||put(a._freq_/b._freq_*100, 5.1)||')'
          end as count length=25
     from gender01 as a
left join gender01(where=(missing(gender))) as b
       on a.treatment = b.treatment
 order by gender
   ;
quit;

proc transpose data=gender02 out=gender03(drop=_name_);
   var count;
   id treatment;
   by gender;
run;

/* Summarize age by treatment */
proc summary data=demog02 nway;
   var nage;
   class treatment;
   output out=age01 n=_n mean=_mean std=_sd median=_median min=_min max=_max;
run;

data age02;
   set age01;
   length n mean_sd median min_max $25;
   
   n = put(_n,3.);
   mean_sd = put(_mean,5.1)||' ('||put(_sd,5.2)||')';
   median = put(_median,5.1);
   min_max = put(_min,5.1)||' ; '||put(_max,5.1);

   drop _:;
run;

proc transpose data=age02 out=age03 name=stats;
   var n mean_sd median min_max;
   id treatment;
run;

proc format;
   value $gender
      'F' = 'Female'
      'M' = 'Male'
      'NA' = 'N/A'
      ' ' = 'N'
   ;

   value $stats
      'MEAN_SD' = 'Mean (SD)'
      'MIN_MAX' = 'Min ; Max'
      other = [propcase()]
   ;
run;

/* Combine all summaries and format as per output requirments */
data final;
   set nos02(in=a)
       gender03(in=b)
       age03
   ;

   length grouplabel rowlabel $25;

   if a then
      rowlabel = 'Number of subjects';
   else if b then
   do;
      grouplabel = 'Gender, n (%)';
      rowlabel = repeat(' ',3)||put(gender,$gender.);
   end;
   else
   do;
      grouplabel = 'Age';
      rowlabel = repeat(' ',3)||put(stats,$stats.);
   end;
run;


/* Print report to .docx file */
title j=center "Demographics - All Subjects";
ods rtf file='~/demog.rtf' bodytitle;
proc report data=final headline center;
   column grouplabel rowlabel treatment control total;

   define grouplabel / order order=data noprint missing;
   define rowlabel   / "" display style(column)={asis=on};
   define treatment  / "Treatment" display style(column)={just=c};
   define control    / "Control" display style(column)={just=c};
   define total      / "Total" display style(column)={just=c};

   compute before grouplabel;
      len=lengthn(grouplabel);
      line @1 grouplabel $varying25. len;
   endcomp;
run;
ods rtf close;