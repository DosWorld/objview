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
{$G-,A-,S-,R-,I-,Q-}
UNIT obj;

INTERFACE

CONST

OBJ_THEADER = $80;
OBJ_LHEADER = $F0;
OBJ_COMMENT = $88;
OBJ_PUBDEF  = $90;
OBJ_LINNUM  = $94;
OBJ_LNAMES  = $96;
OBJ_SEGDEF  = $98;
OBJ_GRPDEF  = $9A;
OBJ_FIXUP   = $9C;
OBJ_COMDEF  = $B0;
OBJ_LEDATA  = $A0;
OBJ_LIDATA  = $A2;
OBJ_EXTDEF  = $8C;
OBJ_MODEND  = $8A;
OBJ_LIBEND  = $F1;

FIXUP_P_16BIT = 0;
FIXUP_P_32BIT = 1;
FIXUP_M_SELF_REL = 0;
FIXUP_M_SELF_DIR = 1;
FIXUP_ONE_SUBREC = 1;
FIXUP_ONE_THREAD = 0;
FIXUP_METHOD_T0 = 0;
FIXUP_METHOD_T1 = 1;
FIXUP_METHOD_T2 = 2;
FIXUP_METHOD_T3 = 3;
FIXUP_METHOD_F0 = 0;
FIXUP_METHOD_F1 = 1;
FIXUP_METHOD_F2 = 2;
FIXUP_METHOD_F3 = 3;
FIXUP_METHOD_F4 = 4;
FIXUP_METHOD_F5 = 5;
FIXUP_METHOD_F6 = 6;
FIXUP_D_THREAD = 0;
FIXUP_D_FRAME = 1;
FIXUP_ZERO_SUBREC = 1;
FIXUP_ZERO_THREAD = 0;

TYPE

PObj = ^TObj;
TObj = RECORD
        t        : BYTE;
        count    : WORD;
        mem      : PCHAR;
        ofs      : LONGINT;
        module   : PObj;
        next     : PObj;
END;

FUNCTION load(fname : STRING):PObj;
PROCEDURE save(obj : PObj; fname : STRING);
FUNCTION lookup(obj : PObj; t : BYTE):PObj;
PROCEDURE free(obj : PObj);

FUNCTION create(t : BYTE; count : WORD; parent : PObj):PObj;
FUNCTION is_type(obj : PObj; t : BYTE):BOOLEAN;
PROCEDURE merge_fixup(obj : PObj);

FUNCTION get_str(obj : PObj; ofs, len : WORD):STRING;
PROCEDURE set_str(obj : PObj; ofs : WORD; s : STRING);

PROCEDURE getFixupAttr(bval : CHAR; VAR p : INTEGER; VAR B : INTEGER; VAR C : INTEGER; VAR A : INTEGER);
PROCEDURE setFixupAttr(p : INTEGER; B : INTEGER; C : INTEGER; A : INTEGER; VAR bval : CHAR);
PROCEDURE getFixupLocat(b1, b2 : CHAR; VAR ofs:WORD; VAR location : INTEGER; VAR m : INTEGER; VAR one : INTEGER);
PROCEDURE getFixupFixData(bval : CHAR; VAR target : INTEGER; VAR P : INTEGER; VAR T : INTEGER;
VAR Frame : INTEGER; VAR F : INTEGER);
PROCEDURE getFixupTrDat(bval : CHAR; VAR Thread : INTEGER; VAR Method : INTEGER; VAR D : INTEGER; VAR Zero : INTEGER);

IMPLEMENTATION

USES System2;

FUNCTION create(t : BYTE; count : WORD; parent : PObj) : PObj;
VAR r : PObj;
BEGIN
        GetMem(r, SizeOf(TObj));
        r^.t := t;
        r^.count := count;
        r^.next := NIL;
        GetMem(r^.mem, count);
        IF parent <> NIL THEN parent^.next := r;
        create := r;
END;

FUNCTION load(fname : STRING) : PObj;
VAR     r, last : PObj;
        f       : BFILE;
        crc, b  : BYTE;
        w       : WORD;
        p       : LONGINT;
        islib   : BOOLEAN;
        module  : PObj;
BEGIN
        islib := FALSE;
        r := NIL; last := NIL; module := NIL;
        Assign(f, fname);
        Reset(f);
        IF f.ioresult <> 0 THEN BEGIN load := NIL; exit; end;
        WHILE NOT eof(f) DO BEGIN
                p := FilePos(f);
                BlockRead(f, b, 1);
                BlockRead(f, w, 2);
                dec(w, 1);
                last := create(b, w, last);
                last^.ofs := p;
                last^.module := module;
                BlockRead(f, last^.mem[0], w);
                IF r = NIL THEN r := last;
                BlockRead(f, crc, 1);
                IF b = OBJ_THEADER THEN module := last;
                IF b = OBJ_LHEADER THEN islib := true;
                IF b = OBJ_MODEND THEN BEGIN
                        IF NOT islib THEN break;
                        p := FilePos(f);
                        IF p AND $0f <> 0 THEN Seek(f, FilePos(f) + 16 - (p AND $0F));
                        module := NIL;
                END;
                IF b = OBJ_LIBEND THEN break;
        END;
        Close(f);
        load := r;
END;

FUNCTION crc(t : BYTE; count : WORD; mem : PCHAR; len : WORD):BYTE;
VAR     i : WORD;
        r : BYTE;
BEGIN
        r := t;
        inc(r, lo(count));
        inc(r, hi(count));
        FOR i := 0 to len DO inc(r, ORD(mem[i]));
        crc := (-r) AND $FF;
END;

PROCEDURE save(obj : PObj; fname : STRING);
VAR     f     : BFILE;
        b     : BYTE;
        w     : WORD;
        islib : BOOLEAN;
        m     : ARRAY[1..16] OF BYTE;
        p     : LONGINT;
BEGIN
        islib := FALSE;
        Assign(f, fname);
        ReWrite(f);
        IF f.ioresult <> 0 THEN exit;
        WHILE obj <> NIL DO BEGIN
                IF obj^.t = OBJ_LHEADER THEN islib := true;
                w := obj^.count + 1;
                BlockWrite(f, obj^.t, 1);
                BlockWrite(f, w, 2);
                BlockWrite(f, obj^.mem[0], obj^.count);
                b := crc(obj^.t, w, obj^.mem, obj^.count);
                BlockWrite(f, b, 1);
                IF islib AND (obj^.t = OBJ_MODEND) THEN BEGIN
                        p := FilePos(f);
                        IF p AND $0f <> 0 THEN BlockWrite(f, m, 16 - (p AND $0F));
                END;
                obj := obj^.next;
        END;
        Close(f);
END;

FUNCTION is_type(obj : PObj; t : BYTE):BOOLEAN;
BEGIN
        IF obj = NIL THEN is_type := FALSE ELSE is_type := obj^.t=t;
END;

PROCEDURE merge_fixup(obj:PObj);
VAR cur, old : PObj;
        w : WORD;
        m : PCHAR;
BEGIN
        cur := obj;
        WHILE cur <> NIL DO BEGIN
                IF is_type(cur, OBJ_FIXUP) AND is_type(cur^.next, OBJ_FIXUP) THEN BEGIN
                        old := cur^.next;
                        cur^.next := cur^.next^.next;
                        w := cur^.count + old^.count;
                        GetMem(m, w);
                        Move(cur^.mem^, m^, cur^.count);
                        Move(old^.mem^, m[cur^.count], old^.count);
                        FreeMem(cur^.mem, cur^.count);
                        cur^.count := w;
                        cur^.mem := m;
                        FreeMem(old^.mem, old^.count);
                        FreeMem(old, SizeOf(TObj));
                END ELSE cur := cur^.next;
        END;
END;

PROCEDURE free(obj:PObj);
VAR next : PObj;
BEGIN
        WHILE obj <> NIL DO BEGIN
                next := obj^.next;
                FreeMem(obj^.mem, obj^.count);
                FreeMem(obj, SizeOf(TObj));
                obj := next;
        END;
END;

FUNCTION lookup(obj:PObj; t:BYTE):PObj;
VAR r : PObj;
BEGIN
        r := NIL;
        WHILE obj <> NIL DO BEGIN
                IF obj^.t = t THEN BEGIN r := obj; break; end;
                obj := obj^.next;
        END;
        lookup := r;
END;

FUNCTION get_str(obj:PObj; ofs, len:WORD):STRING;
VAR     r : STRING;
        i : INTEGER;
BEGIN
        r := '';
        dec(len);
        FOR i := 0 to len DO BEGIN
                r := r + obj^.mem[ofs + i];
        END;
        get_str := r;
END;

PROCEDURE set_str(obj:PObj; ofs:WORD; s:STRING);
VAR i, l : INTEGER;
BEGIN
        l := length(s);
        FOR i := 1 to l DO BEGIN
                obj^.mem[ofs + i - 1] := s[i];
        END;
END;

PROCEDURE getFixupAttr(bval:CHAR; VAR p:INTEGER; VAR B:INTEGER; VAR C:INTEGER; VAR A:INTEGER);
BEGIN
        p := (ORD(bval) SHR 7) AND 1;
        b := (ORD(bval) SHR 6) AND 1;
        c := (ORD(bval) SHR 3) AND $07;
        a := ORD(bval) AND $07;
END;

PROCEDURE setFixupAttr(p:INTEGER; B:INTEGER; C:INTEGER; A:INTEGER; VAR bval:CHAR);
BEGIN
        bval := #0;
        bval := CHR(ORD(bval) or (p AND 1) SHL 7);
        bval := CHR(ORD(bval) or (b AND 1) SHL 6);
        bval := CHR(ORD(bval) or (c AND 7) SHL 3);
        bval := CHR(ORD(bval) or (a AND 7));
END;

PROCEDURE getFixupLocat(b1, b2:CHAR; VAR ofs:WORD; VAR location:INTEGER; VAR m:INTEGER; VAR one:INTEGER);
VAR w : WORD;
BEGIN
        w := (ORD(b1) AND $ff) or ((ORD(b2) AND $ff) SHL 8);
        ofs := (w SHR 6) AND $3f;
        location := (w SHR 2) AND $f;
        m := (w SHR 1) AND $1;
        one := w AND $1;
END;

PROCEDURE getFixupFixData(bval:CHAR; VAR target:INTEGER; VAR P:INTEGER; VAR T:INTEGER; VAR Frame:INTEGER; VAR F:INTEGER);
BEGIN
        target := (ORD(bval) SHR 6) AND $03;
        P := (ORD(bval) SHR 5) AND $01;
        T := (ORD(bval) SHR 4) AND $01;
        Frame := (ORD(bval) SHR 1) AND $07;
        F := ORD(bval) AND $01;
END;

PROCEDURE getFixupTrDat(bval:CHAR; VAR Thread:INTEGER; VAR Method:INTEGER; VAR D:INTEGER; VAR Zero:INTEGER);
BEGIN
        Thread := (ORD(bval) SHR 6) AND $03;
        Method := (ORD(bval) SHR 3) AND $07;
        D := (ORD(bval) SHR 1) AND $01;
        Zero := ORD(bval) AND $01;
END;

END.
