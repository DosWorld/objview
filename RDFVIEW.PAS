{
 MIT License

Copyright (c) 2022 Viacheslav Komenda

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
}
{$G-,A-,D-,L-,R-,S-,Q-}
{$M 32000, 128000, 650000}

USES scr, kbd, strutil, System2;

TYPE

PViewItem = ^TViewItem;
TViewItem = RECORD
        next     : PViewItem;
        name     : STRING[80];
END;

CONST

BGCOLOR = $17;

VAR

h, w : WORD;
vroot, vlast : PViewItem;

PROCEDURE freeall(root : PViewItem);
VAR item : PViewItem;
BEGIN
        WHILE root <> NIL DO BEGIN
                item := root;
                root := root^.next;
                FreeMem(item, SizeOf(TViewItem));
        END;
END;

PROCEDURE Append(s : STRING);
VAR item : PViewItem;
BEGIN
        GetMem(item, SizeOf(TViewItem));
        item^.name := s;
        item^.next := NIL;
        IF vlast <> NIL THEN vlast^.next := item;
        IF vroot = NIL THEN vroot := item;
        vlast := item;
END;

FUNCTION getc(hl : BOOLEAN; cur : PViewItem) : BYTE;
VAR c : BYTE;
BEGIN
        c := BGCOLOR;
        IF hl THEN c:=$20 ELSE BEGIN
                IF Length(cur^.name) > 0 THEN BEGIN
                        IF cur^.name[1] = ' ' THEN c := $13
                        ELSE IF cur^.name[1] = '*' THEN c := $14
                        ELSE IF cur^.name[1] = '-' THEN c := $12;
                END;
        END;
        getc := c;
END;

FUNCTION view_list(title       : STRING;
                   vroot       : PViewItem;
                   VAR current : PViewItem;
                   total       : WORD;
                   VAR scr_start, scr_pos : WORD) : WORD;
VAR vcur : PViewItem;
        k, i   : WORD;
        c      : BYTE;
        needredraw : BOOLEAN;
        s1, s2 : STRING;
BEGIN
        needredraw := TRUE;
        str(total, s2);
        WHILE TRUE DO BEGIN
                IF needredraw THEN BEGIN
                        scr.cls(BGCOLOR);
                        current := NIL;
                        str(scr_pos + scr_start + 1, s1);
                        vcur := vroot; i := 0;
                        WHILE (vcur <> NIL) AND (i < scr_start) DO BEGIN
                                inc(i);
                                vcur := vcur^.next;
                        END;
                        WHILE (vcur <> NIL) AND (i <= scr_start + h - 2) DO BEGIN
                                c := getc(i = (scr_start + scr_pos), vcur);
                                IF i = (scr_start + scr_pos) THEN current := vcur;
                                IF i = (scr_start + scr_pos) THEN scr.cln(0, i - scr_start + 1, c);
                                scr.print(0, i - scr_start + 1, c, vcur^.name);
                                inc(i);
                                vcur := vcur^.next;
                        END;
                        scr.cln(0, 0, $70);
                        printhl(0, 0, $70, $74, title + ' ' + lpad(s1, 5) + ' / ' + s2);
                END;
                scr.show;
                k := getkey;
                CASE hi(k) OF
                SCAN_HOME: BEGIN
                                scr_pos := 0;
                                scr_start := 0;
                                needredraw := TRUE;
                        END;
                SCAN_END: BEGIN
                                IF total < h - 1 THEN BEGIN
                                        scr_pos := total - 1;
                                END ELSE BEGIN
                                        scr_start := total - h + 1;
                                        scr_pos := h - 2;
                                END;
                                needredraw := TRUE;
                        END;
                SCAN_PGUP: BEGIN
                                IF scr_pos <> 0 THEN scr_pos := 0
                                ELSE IF scr_start + scr_pos < h-1 THEN BEGIN
                                        scr_start := 0;
                                END ELSE BEGIN
                                        dec(scr_start, h - 1);
                                END;
                                needredraw := TRUE;
                        END;
                SCAN_PGDN: BEGIN
                                IF (scr_pos <> h - 2) THEN BEGIN
                                        IF scr_start + h - 2 < total THEN scr_pos := h - 2
                                        ELSE scr_pos := total - scr_start - 1;
                                END ELSE IF scr_start + (h - 1) * 2 < total THEN BEGIN
                                        inc(scr_start, h - 1);
                                END ELSE BEGIN
                                        scr_start := total - h + 1;
                                        scr_pos := h - 2;
                                END;
                                needredraw := TRUE;
                        END;
                SCAN_UP: IF scr_start+scr_pos <> 0 THEN BEGIN
                                IF scr_pos<>0 THEN dec(scr_pos) ELSE dec(scr_start);
                                needredraw := TRUE;
                        END;
                SCAN_DOWN: IF scr_pos + scr_start + 1 < total THEN BEGIN
                                IF scr_pos + 2 < h THEN inc(scr_pos) ELSE inc(scr_start);
                                needredraw := TRUE;
                        END;
                ELSE BREAK;
                END;
        END;
        view_list := k;
END;

PROCEDURE view(fname : STRING; vroot : PViewItem);
VAR     vcur : PViewItem;
        s              : STRING;
        i, total, key  : WORD;
        scr_start, scr_pos : WORD;
        title          : STRING;
        name           : STRING;
BEGIN
        scr_start := 0;
        scr_pos := 0;
        vcur := vroot;
        title := ' ' + fname + ' ';
        total := 0;
        vlast := vroot;
        WHILE vlast <> NIL DO BEGIN
                Inc(total);
                vlast := vlast^.next;
        END;

        WHILE TRUE DO BEGIN
                key := hi(view_list(title, vroot, vcur, total, scr_start, scr_pos));
                case key of
                SCAN_ESC: break;
                SCAN_F3:  break;
                SCAN_F4:  break;
                END;
        END;
        freeall(vroot);
END;

TYPE
PLONGINT = ^LONGINT;
PWORD    = ^WORD;

FUNCTION WriteRelo(VAR rdata:STRING):STRING;
VAR
        r : STRING;
BEGIN
        r := 'SEG: ' + hexb(ORD(rdata[1]));
        r := r + ', OFS: ' + hexdw(PLONGINT(@rdata[2])^);
        r := r + ', LEN: ' + hexb(ORD(rdata[6]));
        r := r + ', RSEG: ' + hexw(PWORD(@rdata[7])^);
        WriteRelo := r;
END;

FUNCTION WriteImport(VAR rdata:STRING):STRING;
VAR
        i : INTEGER;
        r : STRING;
BEGIN
        r := 'FLG: ' + hexb(ORD(rdata[1]));
        r := r + ', SEG: ' + hexw(ORD(rdata[2]));
        r := r + ', ';
        i := 4;
        WHILE (i < 256) AND (rdata[i] <> #0) DO BEGIN
                r := r + rdata[i];
                Inc(i);
        END;
        WriteImport := r;
END;

FUNCTION WriteGlobal(VAR rdata:STRING):STRING;
VAR
        i : INTEGER;
        r : STRING;
BEGIN
        r := '';
        r := 'FLG: ' + hexb(ORD(rdata[1]));
        r := r + ', SEG: ' + hexb(ORD(rdata[2]));
        r := r + ', OFS: ' + hexdw(PLONGINT(@rdata[3])^);
        r := r + ', ';
        i := 7;
        WHILE (i < 256) AND (rdata[i] <> #0) DO BEGIN
                r := r + rdata[i];
                Inc(i);
        END;
        WriteGlobal := r;
END;

FUNCTION WriteBSS(VAR rdata:STRING):STRING;
BEGIN
        WriteBSS := hexdw(PLONGINT(@rdata[1])^);
END;

FUNCTION WriteDefault(VAR rdata:STRING):STRING;
VAR
        i, l : INTEGER;
        r    : STRING;
BEGIN
        r := '';
        l := Length(rdata);
        IF l > 16 THEN l := 16;
        FOR i := 1 TO l DO r := r + hexb(ORD(rdata[i])) + ' ';
        WriteDefault := r;
END;

FUNCTION DumpRec(rtype : BYTE; VAR rdata : STRING) : STRING;
VAR r : STRING;
BEGIN
        CASE rtype OF
        1: BEGIN
                { reloc }
                r := 'RELO      ' + WriteRelo(rdata);
        END;
        2: BEGIN
                { import }
                r := 'IMPORT    ' + WriteImport(rdata);
        END;
        3: BEGIN
                { global }
                r := 'GLOBAL    ' + WriteGlobal(rdata);
        END;
        4: BEGIN
                { dll }
                r := 'DLL       ' + rdata;
        END;
        5: BEGIN
                { bss }
                r := 'BSS       ' + WriteBSS(rdata);
        END;
        6: BEGIN
                { seg relo }
                r := 'SEGRELO   ' + WriteRelo(rdata);
        END;
        7: BEGIN
                { far import }
                r := 'FARIMPORT ' + WriteImport(rdata);
        END;
        8: BEGIN
                { mod name }
                r := 'MODNAME   ' + rdata;
        END ELSE BEGIN
                r := '???    ' + WriteDefault(rdata);
        END;
        END;
        DumpRec := r;
END;

PROCEDURE DumpSegs(VAR f : BFILE; modlen : LONGINT);
VAR
        segtype  : WORD;
        segnum   : WORD;
        reserv   : WORD;
        seglen   : LONGINT;
        s        : STRING;
        havesegs : BOOLEAN;
BEGIN
        havesegs := FALSE;
        WHILE NOT eof(f) DO BEGIN
                havesegs := TRUE;
                BlockRead(f, segtype, SizeOf(segtype));
                BlockRead(f, segnum, SizeOf(segnum));
                BlockRead(f, reserv, SizeOf(reserv));
                BlockRead(f, seglen, SizeOf(seglen));
                s := '';
                s := s + hexdw(FilePos(f)) + ' ';
                s := s + hexdw(seglen) + ' ';
                s := s + hexb(segtype) + '-';
                IF segtype = 1 THEN s := s + 'CODE     '
                ELSE IF segtype = 2 THEN s := s + 'DATA     '
                ELSE s := s + '??       ';
                s := s + ' NUM: ' + hexw(segnum) + ' ';
                s := s + ' RES: ' + hexw(reserv);
                Append(s);
                IF segtype = 0 THEN BREAK;
                Seek(f, FilePos(f) + seglen);
        END;
        IF not havesegs THEN Append('*** Here is no any segments ***');
END;

VAR
        f : BFILE;
        sign    : STRING;
        fullen  : LONGINT;
        modlen  : LONGINT;
        hdrlen  : LONGINT;
        hdrrecs : BOOLEAN;
        rtype   : BYTE;
        rdata   : STRING;
        i       : INTEGER;
        fname   : STRING;
        str     : STRING;
BEGIN
        System.WriteLn('RDFVIEW for NASM-0.98.39  (c) 2022 by DosWorld.  MIT License');
        IF ParamCount <> 1 THEN BEGIN
                System.WriteLn;
                System.WriteLn('Usage:');
                System.WriteLn(#9, upstr(basename(paramstr(0))), ' file.rdf');
                Halt(1);
        END;
        fname := ParamStr(1);
        vroot := NIL;
        vlast := NIL;
        Assign(f, fname);
        Reset(f);
        i := f.ioResult;
        IF i <> 0 THEN BEGIN
                WriteLnErr('Could not read ' + fname);
                Halt(1);
        END;

        fullen := FileSize(f);
        BlockRead(f, sign[1], 6);
        modlen := ReadDWord(f, modlen, SizeOf(LONGINT));
        hdrlen := ReadDWord(f, hdrlen, SizeOf(LONGINT));
        sign[0] := #6;
        Append(' File size:   ' + hexdw(fullen) + ' ' + itoa(fullen));
        Append(' Signature:   ' + sign);
        Append(' Module size: ' + hexdw(modlen) + ' ' + itoa(modlen));
        Append(' Header size: ' + hexdw(hdrlen) + ' ' + itoa(hdrlen));
        Append('');
        IF sign = 'RDOFF2' THEN BEGIN
                Append('- Header records');
                hdrrecs := FALSE;
                WHILE hdrlen <> 0 DO BEGIN
                        str := hexdw(FilePos(f)) + ' ';
                        BlockRead(f, rtype, 1);
                        BlockRead(f, rdata[0], 1);
                        Dec(hdrlen, 2);
                        BlockRead(f, rdata[1], ORD(rdata[0]));
                        Dec(hdrlen, ORD(rdata[0]));
                        Append(str + hexb(ORD(rdata[0])) + ' ' + hexb(rtype) + '-' + DumpRec(rtype, rdata));
                        hdrrecs := TRUE;
                END;
                IF not hdrrecs THEN Append('*** Here is no any records ***');
                Append('') ;
                Append('- Segments');
                DumpSegs(f, modlen);
                Append('');
        END ELSE BEGIN
                Append('*** File have no RDOFF2 signature, so it seems like not a RDF. ***');
        END;
        Close(f);
        h := getheight;
        w := getwidth;

        scr.push;
        view(upstr(upstr(basename(fname))), vroot);
        scr.pop;
        scr.show;
        kbd.reset;
        Halt(0);
END.
