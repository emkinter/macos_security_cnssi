# macOS Security Compliance Project (mSCP) cnssi-1253 Baseline Creation

This project allows for the creation of cnssi-1253 Overlay Baseline in the [macOS Security Compliance Project](https://github.com/usnistgov/macos_security). A requirement is that you have cloned the macos_security and the macOS_Security_cnssi git repositories on your macOS System and they are located in the same directory.

This README file describes two part to creating a cnssi-1253 baseline for the macOS Security Compliance Project (mSCP). They are listed here in reverse cronological order as the creation of a cnssi-1253 baseline for a newOS is most common.
* [Creating a new cnssi-1253 baseline for a newOS](#creating-a-new-cnssi-1253-baseline-for-a-newos)
* [Create the mapping files from the original cnssi-1253 pdf](#create-the-mapping-files-from-the-original-cnssi-1253-pdf)
* [Project Implementation](#project-implementation)


------------------------------------------------------------------------------------------


## Creating a new cnssi-1253 baseline for a newOS

1. [Run the generate_mapping script on each of the .csv files](#1-run-mapping-script-on-each-of-the-csv-files)
2. [Manually curate duplicate rules](#2-manually-curate-duplicate-rules)
3. [Move build folder content (cnssi-1253_high, cnssi-1253_moderate, and cnssi-1253_low) from macos_security to macos_security_cnssi](#3-move-build-folder-content-cnssi-1253_high-cnssi-1253_moderate-and-cnssi-1253_low-from-macos_security-to-macos_security_cnssi)
4. [Run the cnssi-merge to create the correct baseline tags in all the rules.](#4-run-the-cnssi-merge-to-create-the-correct-baseline-tags-in-all-the-rules)

### 1. Run mapping script on each of the .csv files

For more information about the generate_mapping script refer to the [macos_security generate mapping wiki](https://github.com/usnistgov/macos_security/wiki/Generate-Mapping)

The following commands Make sure you are in the macos_security directory and that the macos_security and the macos_security_cnssi are in the same directory.

        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.10.06_csv/cnssi-1253_confidentiality_high.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.10.06_csv/cnssi-1253_confidentiality_moderate.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.10.06_csv/cnssi-1253_confidentiality_low.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.10.06_csv/cnssi-1253_integrity_high.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.10.06_csv/cnssi-1253_integrity_moderate.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.10.06_csv/cnssi-1253_integrity_low.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.10.06_csv/cnssi-1253_availability_high.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.10.06_csv/cnssi-1253_availability_moderate.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.10.06_csv/cnssi-1253_availability_low.csv 

### 2. Manually curate duplicate rules

Manually curate rules that are duplicates for cnssi-1253_high, cnssi-1253_moderate, and cnssi-1253_low. Most often you can identify them because they have high, moderate, or low in the rule name.

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

The lastest cnssi-1253 pdf was published on October 6, 2022. A copy is available [here](/data/cnssi-1253_2022.10.06_pdf/CNSSI_1253_Final_CORRECTED_COPY_6Oct22.pdf) and the original is [here](https://www.cnss.gov/CNSS/openDoc.cfm?a=m2eKasT6FPJu7OE92KX1DA%3D%3D&b=A2B3BBBF0ACFA8DA5BC33EDE507C3C84F2AD53FB5EED194E664F4BC326C1706A112E6080918197754578D052B2DAA975).

### 2. Create a spreadsheet of the cnssi-1253 pdf Mapping table for cnssi-1253_high, cnssi-1253_moderate, and cnssi-1253_low

Using Adobe Acrobat, convert the spreadsheet tables to an excel spreadsheet.
 
Create 9 spreadsheets containing the values for each baseline. Confidentiality (low, moderate, high), integrity (low, moderate, high) and availability  (low, moderate, high)

### 3. Convert the spreadsheet to the .csv format and move the columns to work with the generate_mapping script.

If you need to know how to format the .csv files look at the [macos_security generate_mapping wiki](https://github.com/usnistgov/macos_security/wiki/Generate-Mapping)

Title the spreadsheet the cnssi basline for your data (i.e. cnssi-1253_confidentiality_high.csv)
Format the data in csv format with the cnssi-1253 values in the first column and the matching 800-53r5 value in the second column

Here's an example:

        cnssi-1253_high,800-53r5
        IH,AC-1
        IH,AC-2
        IH,AC-2(1)
        IH,AC-2(2)
        
Here is a list of files generated from the [October 6, 2022 pdf](/data/cnssi-1253_2022.10.06_pdf/CNSSI_1253_Final_CORRECTED_COPY_6Oct22.pdf)
* [cnssi-1253_confidentiality_high.csv](/data/cnssi-1253_2022.10.06_csv/cnssi-1253_confidentiality_high.csv)
* [cnssi-1253_confidentiality_moderate.csv](/data/cnssi-1253_2022.10.06_csv/cnssi-1253_confidentiality_moderate.csv)
* [cnssi-1253_confidentiality_low.csv](/data/cnssi-1253_2022.10.06_csv/cnssi-1253_confidentiality_low.csv)
* [cnssi-1253_integrity_high.csv](/data/cnssi-1253_2022.10.06_csv/cnssi-1253_integrity_high.csv)
* [cnssi-1253_integrity_moderate.csv](/data/cnssi-1253_2022.10.06_csv/cnssi-1253_integrity_moderate.csv)
* [cnssi-1253_integrity_low.csv](/data/cnssi-1253_2022.10.06_csv/cnssi-1253_integrity_low.csv)
* [cnssi-1253_availability_high.csv](/data/cnssi-1253_2022.10.06_csv/cnssi-1253_availability_high.csv)
* [cnssi-1253_availability_moderate.csv](/data/cnssi-1253_2022.10.06_csv/cnssi-1253_availability_moderate.csv)
* [cnssi-1253_availability_low.csv](/data/cnssi-1253_2022.10.06_csv/cnssi-1253_availability_low.csv)


------------------------------------------------------------------------------------------


## Project Implementation

The repository has three main directories:
* [builds](/builds/) which contains all the cnssi-1253 baseline and rule information for each os
* [data](/data/) which contains all the data used to generate a cnssi-1253 baselines.
* [scripts](/scripts/) which houses any scripts needed for generating cnssi-1253 baselines

For the macOS Security Compliance Project (mSCP) we have chosen to only provide the following baselines:
* high confidentiality, integrity, and availability (cnssi-1253_high)
* moderate confidentiality, integrity, and availability (cnssi-1253_moderate)
* low confidentiality, integrity, and availability (cnssi-1253_low)

It is possible to provide other baselines by mixing other levels of confidentiality, integrity, and availability. This can be accomplished by updating the values in the [.csv files](/data/cnssi-1253_2022.10.06_csv/).
