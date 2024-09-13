# macOS Security Compliance Project (mSCP) cnssi-1253 Baseline Creation

This project allows for creating cnssi-1253 Overlay Baseline in the [macOS Security Compliance Project (mSCP)](https://github.com/usnistgov/macos_security). A requirement is that you have cloned the [macos_security](https://github.com/usnistgov/macos_security) and the [macos_security_cnssi](https://github.com/emkinter/macos_security_cnssi) git repositories on your macOS System, and locate them in the same directory.

This README file has three sections, listed from most to least common.
* [Creating a new cnssi-1253 baseline for a new OS](#creating-a-new-cnssi-1253-baseline-for-a-newos)
* [Create the mapping files from the original cnssi-1253 pdf](#create-the-mapping-files-from-the-original-cnssi-1253-pdf)
* [Project Implementation](#project-implementation)


------------------------------------------------------------------------------------------


## Creating a new cnssi-1253 baseline for a new OS

1. [Run the generate_mapping script on each of the .csv files](#1-run-mapping-script-on-each-of-the-csv-files)
2. [Manually curate duplicate rules](#2-manually-curate-duplicate-rules)
3. [Move build folder content (cnssi-1253_high, cnssi-1253_moderate, and cnssi-1253_low) from macos_security to macos_security_cnssi](#3-move-build-folder-content-cnssi-1253_high-cnssi-1253_moderate-and-cnssi-1253_low-from-macos_security-to-macos_security_cnssi)
4. [Run the cnssi-merge to create the correct baseline tags in all the rules.](#4-run-the-cnssi-merge-to-create-the-correct-baseline-tags-in-all-the-rules)

### 1. Run mapping script on each of the .csv files

For more information about the generate_mapping script refer to the [macos_security generate mapping wiki](https://github.com/usnistgov/macos_security/wiki/Generate-Mapping)

The following commands Make sure you are in the macos_security directory and that the macos_security and the macos_security_cnssi are in the same directory.

        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.12.22_csv/cnssi-1253_confidentiality_high.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.12.22_csv/cnssi-1253_confidentiality_moderate.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.12.22_csv/cnssi-1253_confidentiality_low.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.12.22_csv/cnssi-1253_integrity_high.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.12.22_csv/cnssi-1253_integrity_moderate.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.12.22_csv/cnssi-1253_integrity_low.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.12.22_csv/cnssi-1253_availability_high.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.12.22_csv/cnssi-1253_availability_moderate.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.12.22_csv/cnssi-1253_availability_low.csv 

### 2. Manually curate duplicate rules

Manually curate rules to eliminate duplicates for cnssi-1253_high, cnssi-1253_moderate, and cnssi-1253_low. You can often identify them because they have high, moderate, or low in the rule name.

### 3. Move build folder content (cnssi-1253_high, cnssi-1253_moderate, and cnssi-1253_low) from macos_security to macos_security_cnssi

Move the cnssi-1253_high, cnssi-1253_moderate, and cnssi-1253_low folders from the macos_security build folder to the newOS_cnssi1253 folder into [builds](/builds/) folder of the macos_security_cnssi project on your macOS System.

### 4. Run the cnssi-merge to create the correct baseline tags in all the rules.

Here is the script for [cnssi-merge](/scripts/cnssi-merge.py)


------------------------------------------------------------------------------------------


## Create the mapping files from the original cnssi-1253 pdf

1. [Get The Latest cnssi-1253 PDF](#1-get-the-latest-cnssi-1253-pdf)
2. [Create a spreadsheet of the cnssi-1253 pdf Mapping table for cnssi-1253_high, cnssi-1253_moderate, and cnssi-1253_low](#2-create-a-spreadsheet-of-the-cnssi-1253-pdf-mapping-table-for-cnssi-1253_high-cnssi-1253_moderate-and-cnssi-1253_low)
3. [Convert the spreadsheet to the .csv format and move the columns to work with the generate_mapping script.](#3-convert-the-spreadsheet-to-the-csv-format-and-move-the-columns-to-work-with-the-generate_mapping-script)

### 1. Get The Latest cnssi-1253 PDF

The publishing date for the latest cnssi-1253 pdf we found is December 22, 2022. A copy is available [here](/data/cnssi-1253_2022.12.22_pdf/cnssi-1253_2022.12.22.pdf) and the original is [here](https://www.cnss.gov/CNSS/openDoc.cfm?a=SZHyltj%2BEoyvvdQxXXWdzg%3D%3D&b=9C06944A56B509BC53F8266316807AFC1A109C22611F471958A471C18604E0FE0C556DAEB64DE53C957F786C80E60F5E).

### 2. Create a spreadsheet of the cnssi-1253 pdf Mapping table for cnssi-1253_high, cnssi-1253_moderate, and cnssi-1253_low

Using Adobe Acrobat, convert the spreadsheet tables to an Excel spreadsheet.
 
Create nine spreadsheets containing the values for each baseline. Confidentiality (low, moderate, high), integrity (low, moderate, high), and availability  (low, moderate, high)

### 3. Convert the spreadsheet to the .csv format and move the columns to work with the generate_mapping script.

If you need to know how to format the .csv files, look at the [macos_security generate_mapping wiki](https://github.com/usnistgov/macos_security/wiki/Generate-Mapping)

Title the spreadsheet the cnssi baseline for your data (i.e. cnssi-1253_confidentiality_high.csv)
Format the data in .csv format with the cnssi-1253 values in the first column and the matching 800-53r5 value in the second column

Here's an example:

        cnssi-1253_high,800-53r5
        IH,AC-1
        IH,AC-2
        IH,AC-2(1)
        IH,AC-2(2)
        
Here is a list of files generated from the [cnssi-1253_2022.12.22 pdf](/data/cnssi-1253_2022.12.22_pdf/cnssi-1253_2022.12.22.pdf)
* [cnssi-1253_confidentiality_high.csv](/data/cnssi-1253_2022.12.22_csv/cnssi-1253_confidentiality_high.csv)
* [cnssi-1253_confidentiality_moderate.csv](/data/cnssi-1253_2022.12.22_csv/cnssi-1253_confidentiality_moderate.csv)
* [cnssi-1253_confidentiality_low.csv](/data/cnssi-1253_2022.12.22_csv/cnssi-1253_confidentiality_low.csv)
* [cnssi-1253_integrity_high.csv](/data/cnssi-1253_2022.12.22_csv/cnssi-1253_integrity_high.csv)
* [cnssi-1253_integrity_moderate.csv](/data/cnssi-1253_2022.12.22_csv/cnssi-1253_integrity_moderate.csv)
* [cnssi-1253_integrity_low.csv](/data/cnssi-1253_2022.12.22_csv/cnssi-1253_integrity_low.csv)
* [cnssi-1253_availability_high.csv](/data/cnssi-1253_2022.12.22_csv/cnssi-1253_availability_high.csv)
* [cnssi-1253_availability_moderate.csv](/data/cnssi-1253_2022.12.22_csv/cnssi-1253_availability_moderate.csv)
* [cnssi-1253_availability_low.csv](/data/cnssi-1253_2022.12.22_csv/cnssi-1253_availability_low.csv)


------------------------------------------------------------------------------------------


## Project Implementation

The repository has three main directories:
* [builds](/builds/) which contains all the cnssi-1253 baseline and rule information for each os
* [data](/data/) which contains all the data used to generate a cnssi-1253 baselines.
* [scripts](/scripts/) which houses any scripts needed for generating cnssi-1253 baselines

For the [macOS Security Compliance Project (mSCP)](https://github.com/usnistgov/macos_security), we have chosen only to provide the following baselines:
* high confidentiality, integrity, and availability (cnssi-1253_high)
* moderate confidentiality, integrity, and availability (cnssi-1253_moderate)
* low confidentiality, integrity, and availability (cnssi-1253_low)

It is possible to provide other baselines by mixing different levels of confidentiality, integrity, and availability in the [.csv files](/data/cnssi-1253_2022.10.06_csv/).
