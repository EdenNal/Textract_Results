- Steve uploaded a screenshot of a historical typewritten data table (6 columns, rows delimited by dotted lines). He wanted to extract the table into CSV format, preserving each row exactly as-is — no rows should be added or skipped.
- Like our other trials we tried using GPT or OCR directly on the image. The result included skipped rows, added rows, and failure to distinguish dash (-) and two-dot (..) data
- Initial extraction, row by row, like specified over previous trials:
  - misidentified headers and mistakenly added a "disease" column
  - merged rows
  - failed to distinguish dash from dot missing-value types
Response to initial attempt:
  - asked for exact row-by-row alignment
  - clarified that each row consists of 6 values, with no "disease name" column.
- Tried to diagnose the issue by asking ChatGPT how it worked. Asked “How are you keeping track of vertical position?”
  - chat addmitted not keeping track. Suggested three strategies. Steve asked it to use the third: aligning row positions based on consistent pixel distances and local pixel patterns.
  - Gave chat a smaller screenshot of just the dotted line delimeters. Explicitly said there's variance and patterns in the image. Asked chat to simply return / describe the screenshot of the dotted lines
Historgram detection:
- Chat created a vertical darkness histogram to try to locate row delimiters
- (solid lines and visual noise could also show up as peaks)
- (just using intensity ignores the horizontal structure of dotted lines)
Template matching strategy:
- Use a template matching similarity method using a cropped dotted line image
- Find matching regions in the main image via sliding window correlation.
- Adjust detected peak positions based on the center of the template.
- Chat returned:
    - A red-line plot overlaid on the image showing row detections.
    - A histogram showing similarity scores and the detected peaks.
  - encouraged combining spacing constraints (~28px) with TMS score.
  - emphasized that headers should not be misidentified as data rows.

Finally Chat: 
- Started detection at the first true row (~148px).
- Weight both TMS peaks and approximate row spacing.
- Excluded header rows.
- Improved alignment by adjusting TMS peaks based on the vertical center of the template.

Now that rows are "reliably" detected, onto inputting the numerical data:
- i asked chat to number each row, it between the red lines it produced, and return the image to me
- I asked for chat to return a cropped image of a specific row, row 2. this is the first row with numerical data
- it returned row 3, which is the second row of data, but not row 2 that it labelled. i corrected it
- chat returned a cropped image of row 2
- I asked chat to return the images shown on this photo
    - "can you please return the numbers in this screenshot, separated with commas?"
    - it was totally incorrect. I asked it to return the image + numbers. It returned the correct screenshot, with -,-,-,..,..,..
 as the data
    - chat returned the correct data after i told it there were 6 values total
 
Why did chat have such difficulty with reading the numbers?
- 1. Poor Character Segmentation
  2. 2. Unreliable Layout Detection (which we already attempted to fix with the rows... maybe look at doing the same thing for the columns?)
   3. Noise from Dotted Borders 
  

