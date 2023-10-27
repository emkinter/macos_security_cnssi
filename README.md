# macOS Securrity Compliance Project (mSCP) CNSSI Baseline Creation

This project allows for the creation of CNSSI 1253 Overlay Baseline in the [macOS Security Compliance Project] (https://github.com/usnistgov/macos_security).

## Index

1. Get The Latest CNSSi 1235 PDF
2. Create a spreadsheet of the CNSSI Mapping table for cnssi1253_high, cnssi1253_moderate, and cnssi1253_low
3. Format correct csv (see [generate mapping wiki] (https://github.com/usnistgov/macos_security/wiki/Generate-Mapping))
4. Create baseline name (ie cnssi1253_high, cnssi1253_moderate, and cnssi1253_low) in the correct csv 
5. Run mapping script on each of the .csv files (see [generate mapping wiki] (https://github.com/usnistgov/macos_security/wiki/Generate-Mapping))
6. Manually curate duplicate rules
7. Create a dev_newOS_cnssi1253 branch in the [macOS Security Compliance Project] (https://github.com/usnistgov/macos_security).
8. Run the [cnssi-merge] (https://github.com/emkinter/macos_security_cnssi/blob/main/scripts/cnssi-merge.py) to create the correct baseline tags in all the rules.

## 1. Get The Latest CNSSi 123 PDF
As of October 22, 2022 this is the latest [CNSSi 123 PDF] (https://www.cnss.gov/CNSS/openDoc.cfm?a=m2eKasT6FPJu7OE92KX1DA%3D%3D&b=A2B3BBBF0ACFA8DA5BC33EDE507C3C84F2AD53FB5EED194E664F4BC326C1706A112E6080918197754578D052B2DAA975).

## 2. Create a spreadsheet of the CNSSI Mapping table for cnssi1253_high, cnssi1253_moderate, and cnssi1253_low
Using Adobe Acrobat, convert the spreadsheet tables to an excel spreadsheet. 
Create 9 spreadsheets containing the values for each baseline. Confidentiality (low, medium, high), Integrity (low, medium, high) & Availability  (low, medium, high)


## 3. Format correct csv (see [generate mapping wiki] (https://github.com/usnistgov/macos_security/wiki/Generate-Mapping))
Title the spreadsheet the cnssi basline for your data (i.e. cnssi-125_confidentiality_high.csv)
Format the data in csv format with the cnssi-1253 values in the first column and the matching 800-53r5 value in the second column

Here's an example:
cnssi-1253_high,800-53r5
IH,AC-1
IH,AC-2
IH,AC-2(1)
IH,AC-2(2)


## 4. Create baseline name (ie cnssi1253_high, cnssi1253_moderate, and cnssi1253_low) in the correct csv


## 5. Run mapping script on each of the .csv files (see [generate mapping wiki] (https://github.com/usnistgov/macos_security/wiki/Generate-Mapping))
 ./scripts/generate_mapping.py ~/Projects/macos_security_cnssi/data/cnssi-1253_2022.10.22_csv/cnssi-1253_confidentiality_high.csv 
 ./scripts/generate_mapping.py ~/Projects/macos_security_cnssi/data/cnssi-1253_2022.10.22_csv/cnssi-1253_confidentiality_medium.csv 
 ./scripts/generate_mapping.py ~/Projects/macos_security_cnssi/data/cnssi-1253_2022.10.22_csv/cnssi-1253_confidentiality_low.csv 
 ./scripts/generate_mapping.py ~/Projects/macos_security_cnssi/data/cnssi-1253_2022.10.22_csv/cnssi-1253_integrity_high.csv 
 ./scripts/generate_mapping.py ~/Projects/macos_security_cnssi/data/cnssi-1253_2022.10.22_csv/cnssi-1253_integrity_medium.csv 
 ./scripts/generate_mapping.py ~/Projects/macos_security_cnssi/data/cnssi-1253_2022.10.22_csv/cnssi-1253_integrity_low.csv 
 ./scripts/generate_mapping.py ~/Projects/macos_security_cnssi/data/cnssi-1253_2022.10.22_csv/cnssi-1253_availability_high.csv 
 ./scripts/generate_mapping.py ~/Projects/macos_security_cnssi/data/cnssi-1253_2022.10.22_csv/cnssi-1253_availability_medium.csv 
 ./scripts/generate_mapping.py ~/Projects/macos_security_cnssi/data/cnssi-1253_2022.10.22_csv/cnssi-1253_availability_low.csv 

 
## 6. Manually curate duplicate rules
err on the side of the more restrictive setting

## 7. Create a dev_newOS_cnssi1253 folder in the [macOS_Security_cnssi roject] (https://github.com/emkinter/macos_security_cnssi).

## 8. Run the [cnssi-merge] (https://github.com/emkinter/macos_security_cnssi/blob/main/scripts/cnssi-merge.py) to create the correct baseline tags in all the rules.

