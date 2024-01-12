# cat-growth
Expected Classification Accuracy for Categorical Growth Models example

The SAS code and accompanying datasets housed at this repository demonstrate an example of new approach to estimate the classification accuracy of categorical models, based on Rudner’s (2001, 2005) classification accuracy index.

To simulate data for a two-category growth model, three cut scores from an empirical assessment were selected to divide the simulated test into four categories (i.e., Basic, Developing, Proficient, Advancing). 

The simulated examinees take the test twice (i.e., T1 and T2), and their growth performance depends on the transition from their performance level on T1 (e.g., Developing) to T2 (e.g., Proficient). Two growth performance categories, N or Y, are assigned to 16 performance level transitions from T1 to T2. The N and Y performance categories represent not meeting and meeting growth expectations, respectively.

To run the example program, download the SAS code and csv files to a local folder, then specify the path to that folder at the top of the SAS program in the DIR macro variable. The DIR macro variable within the program is set to read from a folder located at C:\tmp\git_cat_growth. 

The program outputs three tables in the SAS listing output:
 
  •	A frequency crosstab showing the observed transitions from T1 to T2
 
  •	The observed growth frequency
 
  •	A 2x2 table showing true vs. expected classification accuracy percentages

The program also outputs SAS datasets into the Work library at each step of the calculation which can be opened and viewed by the user.

