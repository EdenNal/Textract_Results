- this week I will continue to work on the data generated in Week2/Varying Prompts
The goal is to find the "best" prompt, ie the most accurate prompts. Then testing their consistency later on by asking Chat to generate files for the same codes.
- I will begin by changing the file types to csv, and cleaning up the documents. Then I will attempt to automate the data checking process by writing a python script to compare the values, number of columns, etc. For the comparisions that are tricky, I'll review them manually and by hand. I'll add my results to an excel under Week3.
- If all goes well, I'll continue this process by taking the best prompts and generating more material from them to test consistency. If the results aren't favourable, I'll redo the experiment, this time asking chat gpt to fill in specific columns in a more rigid, given format.


- \eden\Week3\Varying Prompts with Consistent PNG\compare_csv_rows_stdlib.py
This path has the first script I wrote to compare file paths. The plan is to use this script to compare number of rows and mistakes. At first use, one common issue is that each prompt used a different placeholder for the data, so in the future I will either specify the placeholder or change the script to only consider numbers, etc.

I committed one script to compare the data between the csv files, but basically every file has a different number of columns / there is an entry without a character which leads to problems. I'll use the script to supplement analyzing the data, but its not homogenous enough to be super helpful without me going in and manually adjusting each CSV. In the future I'll make the prompts more specific in that way.