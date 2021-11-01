# koha-plugin-batch-search
This plugin searches a batch of terms to find resulting records. It uses a simple keyword search unless you are searching isbn variations and provide valid isbns.

To install:
Make sure plugins are enabled on your Koha system

Download the most recent .kpz from the [koha-plugin-unused-batch-search release page](https://github.com/bywatersolutions/koha-plugin-batch-search/releases)

Go to `More->Reports->Report Plugins`
Click 'Upload a plugin' and browse to the kpz file downloaded from the release page

To use:
1. - From the plugins page click 'Run report' for the Batch Search Report
2. - Enter a list of terms to check.
3. - Choose to display results as HTML or download in a CSV
4. - Choose whether or not to search all isbn variation
5. - Run the report and view your results

Results will be returned with unfound terms hidden by default unless no terms returned results.
You can toggle the view of found/unfound terms using buttons at the top.


