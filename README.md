This shell file allows you to quickly find functions in a file and all files that call it via URL or direct instantiation on the server side of coldfusion, railo or lucee.

**Specific File**

An example of how to run it for a specific file is "./findFunctions.sh /path/to/project/www/assets/cfc/component.cfc /path/to/project/www/"

A report will be generated with all information that appears to be relevant. Please report any bugs or suggestions.

** Search an entire directory**

An example of how to do that is the following.

./bulkinize.sh /path/to/project/www/assets/cfc /path/to/project/www/

This will search every cfc in /www/assets/cfc against the www directory and output the data into a summary.csv file.

TODO
- Add back similar named functions