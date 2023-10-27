# macOS Securrity Compliance Project (mSCP) cnssi-1253 Baseline Creation

This project allows for the creation of cnssi-1253 Overlay Baseline in the [macOS Security Compliance Project](https://github.com/usnistgov/macos_security). A requirement is that you have cloned the macos_security and the macOS_Security_cnssi git repositories on your macOS System and they are located in the same directory.

## Index

1. Get The Latest cnssi-1253 PDF
2. Create a spreadsheet of the CNSSI Mapping table for cnssi1253_high, cnssi1253_moderate, and cnssi1253_low
3. Format correct csv (see [generate mapping wiki](https://github.com/usnistgov/macos_security/wiki/Generate-Mapping))
4. Run mapping script on each of the .csv files (see [generate mapping wiki](https://github.com/usnistgov/macos_security/wiki/Generate-Mapping))
5. Manually curate duplicate rules
6. Move build from macos_security to macOS_Security_cnssi
7. Run the [cnssi-merge](https://github.com/emkinter/macos_security_cnssi/blob/main/scripts/cnssi-merge.py) to create the correct baseline tags in all the rules.

## 1. Get The Latest cnssi-1253 PDF
As of October 22, 2022 this is the latest [CNSSi 123 PDF](https://www.cnss.gov/CNSS/openDoc.cfm?a=m2eKasT6FPJu7OE92KX1DA%3D%3D&b=A2B3BBBF0ACFA8DA5BC33EDE507C3C84F2AD53FB5EED194E664F4BC326C1706A112E6080918197754578D052B2DAA975).

## 2. Create a spreadsheet of the CNSSI Mapping table for cnssi1253_high, cnssi1253_moderate, and cnssi1253_low

Using Adobe Acrobat, convert the spreadsheet tables to an excel spreadsheet.
 
Create 9 spreadsheets containing the values for each baseline. Confidentiality (low, moderate, high), Integrity (low, moderate, high) & Availability  (low, moderate, high)

## 3. Format correct csv (see [generate mapping wiki](https://github.com/usnistgov/macos_security/wiki/Generate-Mapping))
Title the spreadsheet the cnssi basline for your data (i.e. cnssi-125_confidentiality_high.csv)
Format the data in csv format with the cnssi-1253 values in the first column and the matching 800-53r5 value in the second column

Here's an example:
        cnssi-1253_high,800-53r5
        IH,AC-1
        IH,AC-2
        IH,AC-2(1)
        IH,AC-2(2)

## 5. Run mapping script on each of the .csv files (see [generate mapping wiki](https://github.com/usnistgov/macos_security/wiki/Generate-Mapping))

The following commands Make sure you are in the macos_security directory and that the macos_security and the macos_security_cnssi are in the same directory.

        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.10.22_csv/cnssi-1253_confidentiality_high.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.10.22_csv/cnssi-1253_confidentiality_medium.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.10.22_csv/cnssi-1253_confidentiality_low.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.10.22_csv/cnssi-1253_integrity_high.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.10.22_csv/cnssi-1253_integrity_medium.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.10.22_csv/cnssi-1253_integrity_low.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.10.22_csv/cnssi-1253_availability_high.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.10.22_csv/cnssi-1253_availability_medium.csv 
        ./scripts/generate_mapping.py ../macos_security_cnssi/data/cnssi-1253_2022.10.22_csv/cnssi-1253_availability_low.csv 

## 6. Manually curate duplicate rules

Manually curate rules that are duplicates for cnssi-1253_high, cnssi-1253_moderate, and cnssi-1253_low. Most often you can identify them because they have high, moderate, or low in the rule name.

## 7. Move build from macos_security to macOS_Security_cnssi

Move the cnssi-1253_high, cnssi-1253_moderate, and cnssi-1253_low folders from the macos_security build folder to the newOS_cnssi1253 folder in build folder of the macos_security_cnssi project on your macOS System.

## 8. Run the [cnssi-merge](https://github.com/emkinter/macos_security_cnssi/blob/main/scripts/cnssi-merge.py) to create the correct baseline tags in all the rules.