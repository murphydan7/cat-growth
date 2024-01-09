dm 'log;clear;out;clear;'; /*clears log and output window*/

%LET DIR=C:\tmp\git_cat_growth; * This points to the local directory where the csv datafiles are located;

PROC DATASETS KILL;
QUIT;

PROC IMPORT OUT= WORK.GROWTH 
            DATAFILE= "&DIR.\CATGROWTH_DATA.csv" 
            DBMS=CSV REPLACE;
     GETNAMES=YES;
     DATAROW=2; 
	 GUESSINGROWS=MAX;
RUN;

TITLE 'Observed Growth Performance';
PROC FREQ DATA=GROWTH;
	TABLE PERF_FIRST*PERF_LAST GROWTH_CATEGORY;
RUN;

*Output the joint distribution of the Test 1 and Test 2;
PROC FREQ DATA=GROWTH NOPRINT;
	TABLE SS_FIRST*SS_LAST/OUT=JOINTDIST;
RUN;

PROC IMPORT OUT= WORK.RSSS1 
            DATAFILE= "&DIR.\RSSS1.csv" 
            DBMS=CSV REPLACE;
     GETNAMES=YES;
     DATAROW=2; 
	 GUESSINGROWS=MAX;
RUN;

*Compute expected probability of classification into each category 
 given ability, cut scores, and measurement error on test 1;
DATA CLASS_PROB1;
	SET RSSS1;*Raw score to scale score table for first test including performance levels and cut scores;
	ARRAY CUTS(3) CUT1-CUT3;
	ARRAY PLS(3) PL1-PL3;
	DO I=1 TO 3;
	PLS(I)=CDF('NORMAL',((cuts(i)-theta)/csem));*converts z-score calculated from cut score, theta estimate, and CSEM to probability from the normal cumulative distribution function;
	END;
	PL1_1=PL1;
	PL2_1=PL2-PL1;
	PL3_1=PL3-PL2;
	PL4_1=1-PL3;
	DROP I;
RUN;

PROC IMPORT OUT= WORK.RSSS2 
            DATAFILE= "&DIR.\RSSS2.csv" 
            DBMS=CSV REPLACE;
     GETNAMES=YES;
     DATAROW=2; 
	 GUESSINGROWS=MAX;
RUN;

*Compute expected probability of classification into each category 
 given ability, cut scores, and measurement error on test 2;
DATA CLASS_PROB2;
	SET RSSS2;*Raw score to scale score table for second test including performance levels and cut scores;
	ARRAY CUTS(3) CUT1-CUT3;
	ARRAY PLS(3) PL1-PL3;
	DO I=1 TO 3;
	PLS(I)=CDF('NORMAL',((cuts(i)-theta_2)/csem_2));*converts z-score calculated from cut score, theta estimate, and CSEM to probability from the normal cumulative distribution function;
	END;
	PL1_2=PL1;
	PL2_2=PL2-PL1;
	PL3_2=PL3-PL2;
	PL4_2=1-PL3;
	DROP I;
RUN;

*Full join the Test1 and Test2 datasets;
PROC SQL;
	CREATE TABLE T1_T2 AS
	SELECT DISTINCT A.RAW_SCORE,
			        A.SCALE_SCORE,
					A.PERF_LEVEL,
		            A.PL1_1,
					A.PL2_1,
					A.PL3_1,
					A.PL4_1,
					B.RAW_SCORE_2,
					B.SCALE_SCORE_2,
					B.PERF_LEVEL_2,
		            B.PL1_2,
					B.PL2_2,
					B.PL3_2,
					B.PL4_2
	FROM CLASS_PROB1 A FULL JOIN CLASS_PROB2 B
	ON RAW_SCORE_2;
QUIT;

*This step computes joint probabilities representing the likelihood of being assigned to
 each of sixteen performance level combinations over the two tests given the joint distribution 
 of test scores across the two tests;
DATA T1_T2;
	SET T1_T2;
	GROWTH=COMPRESS(LEFT(PERF_LEVEL||'|'||PERF_LEVEL_2));
	SELECT (GROWTH);
		WHEN('Level1|Level2','Level1|Level3','Level1|Level4',
			 'Level2|Level3','Level2|Level4',
			 'Level3|Level3','Level3|Level4',
			 'Level4|Level4') GROWTH_CAT='Y';
		OTHERWISE GROWTH_CAT='N';
	END;
	*This section computes joint probabilities given Level 1 on the first test;
	ARRAY POSS(4) PL1_2 PL2_2 PL3_2 PL4_2;
	ARRAY CONS(4) PL_11 PL_12 PL_13 PL_14;
	DO I=1 TO 4;
	  CONS(I)=PL1_1*POSS(I);
	END;
	*This section computes joint probabilities given Level 2 on the first test;
	ARRAY CONS2(4) PL_21 PL_22 PL_23 PL_24;
	DO I=1 TO 4;
	  CONS2(I)=PL2_1*POSS(I);
	END;
	*This section computes joint probabilities given Level 3 on the first test;
	ARRAY CONS3(4) PL_31 PL_32 PL_33 PL_34;
	DO I=1 TO 4;
	  CONS3(I)=PL3_1*POSS(I);
	END;
	*This section computes joint probabilities given Level 4 on the first test;
	ARRAY CONS4(4) PL_41 PL_42 PL_43 PL_44;
	DO i=1 TO 4;
	  CONS4(I)=PL4_1*POSS(I);
	END;
	DROP RAW_SCORE RAW_SCORE_2 I;
RUN;

* Merge in the population observed score joint distribution;
PROC SQL;
	CREATE TABLE T1_T2_POP AS
	SELECT DISTINCT A.*,
		   B.PERCENT/100 as POP
	FROM T1_T2 A, JOINTDIST B
	WHERE A.SCALE_SCORE=B.SS_FIRST and A.SCALE_SCORE_2=B.SS_LAST;
QUIT;

DATA T1_T2_POP;
	SET T1_T2_POP;
	ARRAY PS(16) PL_11 PL_12 PL_13 PL_14 PL_21 PL_22 PL_23 PL_24 
				 PL_31 PL_32 PL_33 PL_34 PL_41 PL_42 PL_43 PL_44; *Joint probabilities calculated previously;
	ARRAY POPS(16) POPPL_11 POPPL_12 POPPL_13 POPPL_14 POPPL_21 POPPL_22 POPPL_23 POPPL_24 
				   POPPL_31 POPPL_32 POPPL_33 POPPL_34 POPPL_41 POPPL_42 POPPL_43 POPPL_44; *Joint probabilities multiplied by the observed population frequencies;
	DO I=1 TO 16;
	  POPS(I)=PS(I)*POP; *This step multiplies each joint probability by the frequency seen in the observed populations;
	END;
run;

* This step outputs a dataset named ON_CUT2_AND_CUT3 that shows joint probabilities over the two tests 
for an examinee scoring at the category 2 cut score on the first test and the category 3 cut score on the second test;
PROC SQL;
	CREATE TABLE ON_CUT2_AND_CUT3 AS
	SELECT SCALE_SCORE,
	       PERF_LEVEL,
		   PL1_1 LABEL='Probability Level 1 Test 1',
		   PL2_1 LABEL='Probability Level 2 Test 1',
		   PL3_1 LABEL='Probability Level 3 Test 1',
		   PL4_1 LABEL='Probability Level 4 Test 1',
		   SCALE_SCORE_2,
	       PERF_LEVEL_2,
		   PL1_2 LABEL='Probability Level 1 Test 2',
		   PL2_2 LABEL='Probability Level 2 Test 2',
		   PL3_2 LABEL='Probability Level 3 Test 2',
		   PL4_2 LABEL='Probability Level 4 Test 2',
		   PL_11 LABEL='Probability Level 1 and Level 1',
		   PL_12 LABEL='Probability Level 1 and Level 2',
		   PL_13 LABEL='Probability Level 1 and Level 3',
		   PL_14 LABEL='Probability Level 1 and Level 4',
		   PL_21 LABEL='Probability Level 2 and Level 1',
		   PL_22 LABEL='Probability Level 2 and Level 2',
		   PL_23 LABEL='Probability Level 2 and Level 3',
		   PL_24 LABEL='Probability Level 2 and Level 4',
		   PL_31 LABEL='Probability Level 3 and Level 1',
		   PL_32 LABEL='Probability Level 3 and Level 2',
		   PL_33 LABEL='Probability Level 3 and Level 3',
		   PL_34 LABEL='Probability Level 3 and Level 4',
		   PL_41 LABEL='Probability Level 4 and Level 1',
		   PL_42 LABEL='Probability Level 4 and Level 2',
		   PL_43 LABEL='Probability Level 4 and Level 3',
		   PL_44 LABEL='Probability Level 4 and Level 4'
	FROM T1_T2_POP
	WHERE SCALE_SCORE=1124 AND SCALE_SCORE_2=1364;
QUIT;

*Summing the joint probabilities by growth categories gives each estimated true growth probability for each
 of the sixteen performance level combinations over the two tests;
PROC SQL;
	CREATE TABLE PROBS AS
	SELECT GROWTH_CAT FORMAT $5.,
		   SUM(POPPL_11) AS POPPL_11,
		   SUM(POPPL_12) AS POPPL_12,
		   SUM(POPPL_13) AS POPPL_13,
		   SUM(POPPL_14) AS POPPL_14,
		   SUM(POPPL_21) AS POPPL_21,
		   SUM(POPPL_22) AS POPPL_22,
		   SUM(POPPL_23) AS POPPL_23,
		   SUM(POPPL_24) AS POPPL_24,
		   SUM(POPPL_31) AS POPPL_31,
		   SUM(POPPL_32) AS POPPL_32,
		   SUM(POPPL_33) AS POPPL_33,
		   SUM(POPPL_34) AS POPPL_34,
		   SUM(POPPL_41) AS POPPL_41,
		   SUM(POPPL_42) AS POPPL_42,
		   SUM(POPPL_43) AS POPPL_43,
		   SUM(POPPL_44) AS POPPL_44
	FROM T1_T2_POP
	GROUP BY GROWTH_CAT;
QUIT;

*Calculate expected categorical growth model classification accuracy by summing joint probabilities over the appropriate growth categories;
DATA GPROBS_GROWTH;
	LENGTH GROWTH_CAT $5.;
	SET PROBS;
	TRUE=100*ROUND(SUM(OF POPPL_11--POPPL_44),.001); *summing over all columns gives the true growth estimates for each growth category;
	CAT_N=0;
	CAT_Y=100*ROUND(SUM(POPPL_12,POPPL_13,POPPL_14,POPPL_23,POPPL_24,POPPL_33,POPPL_34,POPPL_44),.001);*summing over the observed growth columns gives the expected growth estimates for each category;
	CAT_N=100*ROUND(SUM(POPPL_11,POPPL_21,POPPL_22,POPPL_31,POPPL_32,POPPL_41,POPPL_42,POPPL_43),.001);
	IF GROWTH_CAT='Y' THEN CLACC=CAT_Y;
	 ELSE CLACC=CAT_N;
	KEEP GROWTH_CAT TRUE--CLACC;
RUN;

*Calculate marginal expected classification accuracy rates by summing the expected categorical growth classification accuracy columns;
PROC SQL;
	CREATE TABLE EXACC AS
	SELECT 'Total' AS GROWTH_CAT FORMAT $5. LABEL='True Growth',
	SUM(CLACC) AS EXACC FORMAT 5.1 LABEL='Expected Classification Accuracy',
	SUM(CAT_Y) AS CAT_Y label='Y',
	SUM(CAT_N) AS CAT_N label='N',
	(CALCULATED CAT_Y)+(CALCULATED CAT_N) AS TRUE
	FROM GPROBS_GROWTH;
QUIT;

*Classification accuracy is selected into a macro variable named CA;
PROC SQL NOPRINT;
   SELECT EXACC INTO :CA  
   FROM EXACC;
QUIT;

*Set the categorical growth expected classification accuracy rate with the marginal expected classification accuracy rates; 
DATA CLASS_ACC;
	SET GPROBS_GROWTH (KEEP=GROWTH_CAT TRUE CAT_N CAT_Y)
	    EXACC (DROP=EXACC);
RUN;

TITLE1 F='Arial' H=11PT BOLD "Classification Accuracy = &CA.%";
OPTIONS NODATE NONUMBER;
PROC REPORT NOWD DATA=CLASS_ACC split='*' STYLE(HEADER)={JUST=CENTER}   ; 
COLUMNS GROWTH_CAT ('Expected Growth Category' CAT_N CAT_Y) True;
	DEFINE GROWTH_CAT / FORMAT=$25. DISPLAY 'True Growth Category' STYLE={FONT_FACE=Arial  FONT_SIZE=9PT} ; 
	DEFINE CAT_N / FORMAT=12.1 DISPLAY 'N %' STYLE={FONT_FACE=Arial  FONT_SIZE=9PT} ; 
	DEFINE CAT_Y / FORMAT=12.1 DISPLAY 'Y %' STYLE={FONT_FACE=Arial  FONT_SIZE=9PT} ;
	DEFINE TRUE / FORMAT=8.1 DISPLAY 'Total %' STYLE={FONT_FACE=Arial  FONT_SIZE=9PT} ;
RUN ; 
