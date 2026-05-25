Tuesday Oct 28:
Weekly meeting recap. I am going to take a look at some transkribus tutorials online to at least get a proof of concept and discuss further if I should go ahead and leave AWS behind.
I will also contact the math department for uploading the Stewart work.

Thursday Oct 30:
I looked through some tutorials but nothing has worked so far. I think there is a problem with my free trial, and I am going to send a support form via the Transkribus website to see if they can help me. In the meantime I will read through some AWS documentation to see if I can start automating the translations.

Monday Nov 3:
Met with Steve to exchange AWS keys and starting to work with AWS in R. Discovred the paws library which will allow us to access AWS APIs via R. Got a crude ChatGPT generated implementation to work to see if we can connect to the console, and it did work.
Next steps is to start coding a connection with paws to find where the information on the table is stored. Maybe analyze_document(). Looking into playing with this and testing output. Current problem is it only takes in byte values and not PNG files like we could use with the UI.

Tuesday Nov 4:
I understand the textract output better now, and have a python example from the documentation that runs with a 2 column example. The output is a bit wonky so I'm going to explore why that is. Met with Steve for weekly meeting. Goals for the next few days is to use ModernCSV, change the python example to put the score values on a different csv file, and compare the ui output with the code I have to see if they differ and figure out why, if that is the case.

Thursday Nov 6:
I'm using the Transkribus free trial. It's been loading for about two hours saying: "1 in Queue. Your job priority: low (using free credits)" So I think it's time to move on from Transkribus.
I also updated the python script to remove the redundant lines between rows, and compared it to the csv produced by the Textract UI. It's pretty close! The issues with the output that I thought came from the python extraction script are actually from textract. This is promising. There was some differences in the cell contents, but nothing major. The numeric values were the same.

Friday Nov 7:
Updated the AWS code to seperate the confidence scores and table contents into two seperate csv files. This should make it easier to compare the tables with the manual entry data.

Sunday Nov 9 and Monday Nov 10:
We can access AWS via a python script now. I also modified the script to apply to multiple files in an input folder. I have begun processesing them in the compare folder using code from the summer. I need to take time to organize this repository as well and better describe the pipeline process.

Tuesday Nov 11:
During the weekly meeting we discussed progress on applying the API script on multiple files in a common folder. The next step is to compile this generated data and process its accuracy against the manually entered data along with the confidence scores from AWS per cell. To do this, I will need to trim both the manually entered and AWS produced CSV files to remove readers and column titles (essentially just leaving the float data) from the tables and confidence scores. I will use the UI generated tables to be careful to remove the same number of rows and columns. Then I will combine this information in csv files with the following columns: file_name, row index, col index, machine value, manual value, 0/1, confidence score. I also need to better organize the code repository.

Wednesday Nov 12:
Cleaned the files for the AWS generated data by removing the rows with the headers -- this was tricky because the files varied with the number of lines. I also wrote a code to remove blank rows. Next steps will be to continue cleaning the files before combining the information together.

Thursday Nov 13:
Lots of progress! I finalized cleaning both types of files. In attempting to combine the information from aws, manual, and confidence, I found issues merging because different rows had a different number of elements. I padded all of these cleaned files with the input "FILLER". Then I combined each week's info into a csv, then combined the csv files into Final_Combined_Output.csv
There was a problem I found while merging, in the week32 files had no information. I traced back this problem to a cleaning step which removed headers. I told the script to remove rows until it reached a stopword that I manually input after viewing examples, but week32 didn't contain this information, so I went back and cleaned that week separatley before merging.
I also added up all of the true values and found that 74% of cells were the same between manual and aws! This could be slightly inflated from FILLER values. But more likely than not this values is under represented because very very close values like 1234 and 1,234 returned false.

Wednesday Nov 19:
After the weekly meeting yesterday, I worked on creating different types of equality. Each level was more liberal than the last. The highest percentage is about 96%. Though this only considers cell with numerical values, stripped of commas and spaces, and accounting for shifting.

Wednesday Nov 26:
Weekly discussion with David and Steve. The goal for this week and the weeks to come is to find a none boolean measurment of similarity between outputs. Though we got 97% accuracy, what makes the incorrect values incorrect? One idea is to calculate the Levenshtein distance and its normalization, and also find similar metrics for calculating differences in strings.

Tuesday Dec 2:
Weekly meeting discussing the results from L distance. The level of errors is pretty uniform. The next step should be to seperate the data between strings and numerical entries to see if there is a difference. I also want to investigate why the errors are so large between numbers, and if I filtered the data correctly of if I didn't consider some cases.

Friday Dec 5:
I split the data into the string vs numerical entries. I also plotted these results in multiple different ways. For the numerical I graphed the L distance and relative / log error and for the strings I plotted the L distance.

Wednesday Dec 10:
Weekly meeting results: change the formula for relative error to be m-a/m, add another quantity to the bar graphs, ie split the bars by L distance, and use a LOESS curve to model disease values and their outliers to see if I can detect errors.

Monday Dec 29:
Changed the formula for relative error to be m-a/m, i also tried the created stacked bar graphs but can't seem to get around the issues with numeric vs string issues... next I will look at LOESS curves.
