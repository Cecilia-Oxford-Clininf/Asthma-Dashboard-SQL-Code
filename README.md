# Asthma-Dashboard-SQL-Code
Near-real time primary care data for quality improvement in asthma: use of visual analytics dashboard.
To run this code in sequential order from script 1 to script 4, background knowledge of the database is required.
The code provides details of the methods used.

Data were extracted from the Oxford-Royal College of General Practitioners (RCGP) Research and Surveillance Centre (RSC) databases.  UK general practice is a registration-based system where all citizens can register with a single GP of their choice. Practices are computerised, and data entered into computerised medical record systems either as coded data,  or free text. We extracted the coded data, and our results are based on this element of the record.    We extract all coded data, pseudonymising as close to sources as possible.  Where patients have a range of codes inserted in their suggesting they opt out of record sharing we do not analyse their data.  

The data sources was Oxford-Royal College of General Practitioners Clinical Information Digital Hub (ORCHID) Trusted Research Environment (TRE). This database contains continuous data from 1st April 2004; with retrospective data going back to the start of computerisation of the practice. 

Primary care sentinel cohort RCGPP RSC practices have twice-weekly incremental and quarterly bulk data extracts of coded data.   The incremental extraction takes the last six weeks data.  This is because event and recording data don’t always match; a diagnosis may not be recorded on the same date as the event (e.g. Pneumonia might be diagnosed when the X-ray result arrives some days after the presentation to general practice).  

Ethical considerations:
Patients and practices are informed of this study and the option available to them to ‘opt-out’ of sharing data. All current research activities using pseudonymised data from the RCGP RSC network of general practices are listed on the RCGP RSC webpage (http://www.rcgp.org.uk/rsc) and practices are informed via the monthly newsletter.

Contributors:
1.	Simon de Lusignan – Director, guarantor for these data, assisted with clinical knowledge, system design and problem solving.
2.	Cecilia Okusi – Produced the base data tables and summary counts.
3.	Rachel Byford – Designed and developed much of the database structure.
4.	Gavin Jamie – Curation of clinical variables.
5.	Filipa Ferreira – Project and contract management.

Acknowledgements:
Patients who consented to virology specimens to be collected and for allowing their data to be used for surveillance and research.  Practices who have agreed to be part of the RCGP RSC and allow us to extract and used health data for surveillance and research. The practice liaison team and other members of the Clinical Informatics and Health Outcomes Research Group at Oxford University. Apollo Medical Systems for data extraction. Collaboration with EMIS, TPP, In-Practice and Micro-test CMR supplier for facilitating data extraction.  Colleagues at UKHSA.  
