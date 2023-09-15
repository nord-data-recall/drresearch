# drresearch
Data Recovery Research Tools
A collection of tools to generate patterns, manage XOR files, analyze dumps, visualize things to help for data recovery

# Windows
To use it on Windows you need to install Perl from https://strawberryperl.com/ and Python from https://www.python.org/ first

# LDPC Recovery
![image](https://github.com/thesourcerer8/drresearch/assets/6086693/0e9b1fd8-f90d-4430-9abe-d708bfd58b6f)


## Requirements:
A working donor with access to both the controller and to the flash wired up
Either PC3000-Flash, VNR, FE

## Task:
You have to use the initpattern.pl to generate a pattern for the donor into a file, and then write the pattern to the donor with a tool like dd, HxD, ...
After the pattern is fully written, dump the NAND flash.
Decode the XOR where necessary (the pattern contains hundreds of megabytes of 00, 77 and FF patterns which should help you there if you do not have the XOR keys available yet)
Run the dumpextractrelevant.pl over the pattern. It will tell you the percentage of the data that is required for the parameter extraction that was found. If it is below 100%, please look for XOR problems or other planes where the required data might be hidden, …
Then please submit the extracted pattern and the .xml file generated by the initpattern.pl, and the VNR .case file or equivalent which explains the geometry of your device.
You will then receive a file with the LDPC paramters to be used for decoding dumps with the dumpdecoder tool.


## Current Limitations:
* Unknown XOR pattern

This solution assumes a known and solved XOR pattern. The initpattern.pl provides 00, 77 and FF patterns for recovering the XOR pattern, but for LDPC parameter extraction you will have to provide a dump where the XOR is already solved. In case there is still a XOR pattern left, the dumpextractrelevant tool will tell you that the dump doesn't contain the necessary patterns.

* ECC coverage over SA

If the ECC is covering the DATA+SA area, the key extraction is more difficult and needs further research but it's believed to be doable. In this case, you will need to write a complete 77 pattern to the disk and provide access to a dump of that as well.


## Usage

### Creating the pattern

```
perl initpattern.pl <filename> <size in MB> <data area size in bytes>
perl initpattern.pl pattern4k.dump 11000 4096
```
Create a 11000MB (11GB) pattern image for a 4096 Byte data area. The data area size is most likely 4096, but it might also be 2048, 1024 or 8192. If you aren't sure, try 4096. If you enter a wrong data area size that is lower than the data area size the disk is using, then the LDPC parameters cannot be recovered from the dump of the pattern. If the pattern image size is too small for the given data area size, the tool will warn you right at the beginning. It is recommended to use a pattern size equal or slightly smaller to the target donor disk size.

When the pattern is ready you can use your favourite imaging tool like dd, "Win32 Disk Imager", HxD, balenaEtcher, ... to write the image to a disk/pendrive/SD/MicroSD card.

### Extracting the relevant parts from the dump
After the pattern is written, dump the NAND flash to a file using your favourite tool(3k/VNR/FE). Decode at least the data area with an XOR pattern, so that the tool can recognize the patterns again. The patterns generated by initpattern contain hundreds of megabytes of 00, 77 and FF patterns which should help you to create your own XOR pattern if you do not have XOR patterns for this disk yet. DECODE AT LEAST THE DATA AREA. Create a new file (export/shadow copy/physical image) which includes  SA DA AND ECC. Run the dumpextractrelevant.pl over the newly exported/shadow copy dump. Once dumpextractrelevant.pl is run, it will tell you the percentage of the required patterns that were found. If it is below 100%, please look for XOR problems or other planes where the required data might be hidden, or other geometry issues and fix them first and try again. When 100% of the patterns are found, please submit the extracted pattern and the .xml file that was previously generated by the initpattern.pl, and the VNR .case file or equivalent which explains the geometry of your device. After we have processed your extracted dump, we will send you a file with the LDPC parameters to be used for decoding dumps.

```
perl dumpextractrelevant.pl <dumpfromflash.dump> <upload.dump> <dump-xml-from-initpattern.xml>
perl dumpextractrelevant.pl "simulated(9156p).dump" "upload(9156p).dump" pattern4k.dump.xml
```
This extracts the relevant parts for recovering the XOR decoded dump file that you get from VNR/FE/PC3K. You have to provide the dump.xml file that was generated by the initpattern tool as an input, so that the tool knows the relevant parameters of the pattern file you have generated. At the end it will tell you whether all relevant parts were found, and whether you can upload the extracted dump.

### Decoding your patient dump

```
python3 dumpdecoder.py "simulated(9156p).dump" hmatrix_n36544_k32768_m3776.h 4k.case "corrected(9156p).dump"
```
After you have sent the pattern dump and received the LDPC parameters for your case, you can use the dumpdecoder to resolve the errors in your patient dumps, by providing a patient dump with errors, the LDPC parameters, and telling it where to put the corrected dump.
The dumpdecoder.py is a very simple version of the decoder, which primarily works as a proof-of-concept how it works, and can be used a golden master for the development of better decoders. We are already working on new decoders that will run much faster on CPU, GPU, FPGA and perhaps even ASICs.


# Filename conventions
During our research we came up with a filename convention that greatly eased research, development and debugging, that we encourage everyone to adopt:
For physical dump files, please put the page size in bytes into the filename, e.g. simulated(9156p).dump or upload(9156p).dump

# Contact
If you have any questions or problems that you want to discuss publically, you can use the Issue system from GitHub in the menu on the top, or discuss it on hddguru. If you want to reach me personally, feel free to send direct messages on hddguru.
