# Object file viewers

Here is MS-DOS tools for investigation object formats:

* omfview - OBJ/LIB files in OMF format.
* rdfview - OBJ files in RDOFF2 format (NASM version 0.98.39).

# Using

        omfview objfile.obj
        rdfview rdffile.rdf

or

        omfview "Long file name.obj"
        rdfview "Long file name.rdf"

# Screenshots

OMFView :

![Image Screenshot - OMFVIEW main screen](https://github.com/DosWorld/omfview/raw/main/OMFVIEW.PNG)

RDFView :

![Image Screenshot - RDFVIEW main screen](https://github.com/DosWorld/omfview/raw/main/RDFVIEW.PNG)

# Build

You need Turbo Pascal and my small make in path.
Just type:

        make

# License

MIT License

