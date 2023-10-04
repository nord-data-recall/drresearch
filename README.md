# drresearch
Data Recovery Research Tools
A collection of tools to generate patterns, manage XOR files, analyze dumps, visualize things to help for data recovery

# LDPC Recovery
![image](https://github.com/thesourcerer8/drresearch/assets/6086693/0e9b1fd8-f90d-4430-9abe-d708bfd58b6f)

## Requirements:
A working donor with access to both the controller and to the NAND flash wired up
Either PC3000-Flash, VNR or Flash-Extractor

## Task:
You have to use the initpattern tool to write a pattern on a donor.
After the pattern is fully written, dump the NAND flash.
Run the dumpextractrelevant.pl over the pattern. It will search for the pattern and tell you whether all parts of the pattern were found, and will tell you how to proceed.
Then please submit the extracted pattern and the .xml file generated by the initpattern.pl, and the VNR .case file or equivalent which explains the geometry of your device.
You will then receive a file with the LDPC paramters to be used for decoding dumps with the dumpdecoder tool.

## Current Limitations:
* Dynamic XOR pattern

These tools try to automatically recover the XOR key from the NAND flash dump, but this doesnt work yet for Dynamic XOR patterns. The initpattern tool generates 00, 77 and FF patterns which should help you for recovering the XOR pattern. In case of dynamic XOR you have to decode the XOR yourself before feeding it to the dumpextractrelevant tool. If there is still a XOR pattern left that covers the pattern, the dumpextractrelevant tool will tell you that it can't find the necessary patterns.

* ECC coverage over SA

If the ECC is covering the DATA+SA area, the key extraction is more difficult and needs further research but it's believed to be doable. In this case, you will need to write a complete 77 pattern to the disk and provide access to a dump of that as well.

## Usage

### Creating the pattern
Open a Command Prompt or Powershell with Admin Privileges
Run the initpattern.exe, it will show you the list of disks:
```
initpattern.exe
Usage: initpattern.exe \\.\PhysicalDrive1 [size in MB] [data area size in Byte]
Caption                         DeviceID            Model                           Partitions  Size
WDC PC SN730 SDBQNTY-512G-1016  \\.\PHYSICALDRIVE0  WDC PC SN730 SDBQNTY-512G-1016  4           512105932800
SMI USB DISK USB Device         \\.\PHYSICALDRIVE1  SMI USB DISK USB Device         1           8052549120
```
Choose the correct device carefully to avoid overwriting the wrong device!
Then run initpattern.exe with the DeviceID of the pendrive/SD-Card/MicroSD-card/...
```
initpattern.exe \\.\PHYSICALDRIVE4
```
This writes the pattern directly on the disk.
Alternatively you can write the pattern to an image file and use your favourite imaging tool like dd, balenaEtcher, ... to write the image to a disk/pendrive/SD/MicroSD card.
On Linux and OSX you can use the initpattern.pl script which does the same.

### Extracting the relevant parts from the dump
After the pattern is written, dump the NAND flash to a file (export/shadow copy/physical image)  using your favourite tool(3k/VNR/FE).
In case you the device has several planes and the tool writes the dumps to seperate files, you can concatenate them first with
```
type plane1.dmp plane2.dmp >full.dmp
```
For the next steps you will need Perl installed, on Windows you can get it from https://strawberryperl.com/.

Run the dumpextractrelevant.pl over the newly exported/shadow copy dump. Once dumpextractrelevant.pl is run, it will tell you the percentage of the required patterns that were found. If it is below 100%, please look for XOR problems or other planes where the required data might be hidden, or other geometry issues and fix them first and try again. When 100% of the patterns are found, please submit the extracted pattern and the .xml file that was previously generated by the initpattern.pl, and the VNR .case file or equivalent which explains the geometry of your device.

```
perl dumpextractrelevant.pl <dumpfromflash.dump> <upload.dump> <dump-xml-from-initpattern.xml>
perl dumpextractrelevant.pl "simulated(9156p).dump" "upload(9156p).dump" pattern4k.dump.xml
```
This extracts the relevant parts for recovering the XOR decoded dump file that you get from VNR/FE/PC3K. You have to provide the pattern.xml file that was generated by the initpattern tool, so that the tool knows the relevant parameters of the pattern file you have generated. At the end it will tell you whether all relevant parts were found, and whether you can upload the extracted dump.

### Decoding your patient dump
After you have sent the pattern dump and received the LDPC parameters for your case, you can use the dumpdecoder to resolve the errors in your patient dumps, by providing a patient dump with errors, the LDPC parameters, and telling it where to put the corrected dump. If you have not installed Python already you can get it from http://www.python.org/
```
python3 dumpdecoder.py "simulated(9156p).dump" hmatrix_n36544_k32768_m3776.h 4k.case "corrected(9156p).dump"
```
The dumpdecoder.py is a very simple version of the decoder, which primarily works as a reference implementation. We are already working on new decoders that will run much faster on CPU, GPU, FPGA and perhaps even ASICs.

# Filename conventions
During our research we came up with a filename convention that greatly eased research, development and debugging, that we encourage everyone to adopt:
For physical dump files, please put the page size in bytes into the filename, e.g. simulated(9156p).dump or upload(9156p).dump

# Contact
If you have any questions or problems that you want to discuss publically, you can use the Issue system from GitHub in the menu on the top, or discuss it on hddguru. If you want to reach me personally, feel free to send direct messages on hddguru.
