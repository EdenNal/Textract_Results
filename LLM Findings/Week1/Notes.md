## Week 1 Notes

### 1. Objective  
- Load the provided data pair (PDF + blank Excel template) into ChatGPT.  
- Extract weekly case-counts by region and disease, and populate them into the Excel sheet.

### 2. Initial Challenge  
- Large inputs dramatically slow down response time—even simple extraction tasks can take >10 minutes.
- o3 struggles with very long context windows; accuracy dips when the model must handle both PDF text and formatting instructions.
- The template approach (isolating one week at a time) reduces scope, but performance is still suboptimal.

### 3. First Experiment (Attempt 1)  
- **Model:** ChatGPT-o3  
- **Average runtime:** ~13 minutes per prompt  
- Prompt used:
  > Take a look at this data. It’s separated into different weeks. Each page corresponds to a different week. 
  Each row is numbered for each disease, and contains data for each province. At the bottom of each page 
  is the situation for the United States. The goal is to populate an Excel sheet with the correct case counts. 
  I have added an empty template—complete the table for the first page of the PDF (week of January 7, 1956).
- ChatGPT returned a filled template, but the output was slow, occasionally inaccurate, and lacked consistency with the source PDF.
- Nothing “impressive” in terms of speed

### 4. Next week's plan
1. Research Focus
- Testing different input sizes (e.g., varying the number of columns and column widths) to identify optimal prompt boundaries.
- Keeping record of different results (outputs will be in a .txt format... Chat's not great with Excel)
- Maintaining and formalizing standard prompts:
“Please convert the attached file into clean text.”
“Export to PNG at 600 pixels/inch resolution.”

2. Technical Enhancements
- Experimenting with image exports at 600 dpi to improve OCR accuracy.
- Adjusting column configurations in the template to test model performance at different table densities.

3. Further Reading
- Surveying layout detection methods and libraries such as PDFPlumber or Tesseract’s layout analysis.
- Investigating research papers on table extraction and document layout analysis.
