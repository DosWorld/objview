{  MIT License

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
{$A+,I+,S-,R-,D-,L-,Q-,F-,G-}

UNIT System2;

{ =========================================================================
  Hi !

  This unit is designed to replace some function from system unit.
  It has support for:

  1. long file names
  2. buffered I/O.
  3. Long command line parameters (quoted)

  ========================================================================= }

INTERFACE

TYPE

DWORD = LONGINT;
BFILE_BUF = ARRAY[0..4095] OF CHAR;

BFILE = RECORD
        f          : WORD;
        filename   : STRING;
        ioresult   : INTEGER;
        is_open    : BOOLEAN;
        buf        : BFILE_BUF;
        buf_page   : DWORD;
        buf_update : BOOLEAN;
        buf_count  : WORD;
        buf_pos    : WORD;
        fsize      : DWORD;
END;

PROCEDURE Assign (VAR f : BFILE; fname : STRING);
PROCEDURE Reset (VAR f : BFILE);
PROCEDURE ReWrite (VAR f : BFILE);
FUNCTION Eof (VAR f : BFILE) : BOOLEAN;
PROCEDURE Close (VAR f : BFILE);

PROCEDURE ReadLn (VAR f : BFILE; VAR s : STRING);
FUNCTION BlockRead (VAR f : BFILE; VAR d; count : WORD) : WORD;

PROCEDURE Write (VAR f : BFILE; s : STRING);
PROCEDURE WriteLn (VAR f : BFILE; s : STRING);
PROCEDURE BlockWrite (VAR f : BFILE; VAR d; count : WORD);

PROCEDURE BlockCopy (VAR src, dst : BFILE; count : DWORD);

PROCEDURE Seek (VAR f : BFILE; pos : DWORD);
FUNCTION FilePos (VAR f : BFILE) : DWORD;
FUNCTION FileSize (VAR f : BFILE) : DWORD;
PROCEDURE Truncate (VAR f : BFILE);

PROCEDURE Erase (VAR f : BFILE);
PROCEDURE Rename (VAR f : BFILE; newName : STRING);
PROCEDURE GetDir(d : BYTE; VAR s : STRING);
PROCEDURE ChDir(s : STRING);
PROCEDURE MkDir(s : STRING);
PROCEDURE RmDir(s : STRING);

PROCEDURE WriteLnErr (s : STRING);

FUNCTION ParamCount : INTEGER;
FUNCTION ParamStr(i : INTEGER) : STRING;

IMPLEMENTATION

CONST
        LN_STR : STRING[2] = #$0D + #$0A;
        
        SEEK_BEG = 0;
        SEEK_CUR = 1;
        SEEK_END = 2;

        SELFNAME : PCHAR = NIL;
TYPE
PSTRING = ^STRING;
PWORD   = ^WORD;

VAR     fname  : STRING;
        fname2 : STRING;
        res    : WORD;

FUNCTION lReWrite : WORD;ASSEMBLER;
ASM
        PUSH DS
        MOV  SI, offset fname + 1
        MOV  BX, $22
        XOR  CX, CX
        MOV  RES, CX
        MOV  DX, $12
        MOV  AX, seg fname
        MOV  DS, AX
        XOR  DI, DI
        STC
        MOV  AX, $716C
        INT  $21
        JNC  @end

        MOV  DX, offset fname + 1
        MOV  AX, seg fname
        MOV  DS, AX
        MOV  AH, $3C
        XOR  CX, CX
        INT  $21
        JNC  @end
        MOV  RES, AX
        XOR  AX, AX
@end:
        POP  DS
END;

FUNCTION lReset:WORD;ASSEMBLER;
ASM
        PUSH DS
        XOR  AX, AX
        MOV  RES, AX
        MOV  SI, offset fname + 1
        MOV  BX, $22 { access attr}
        XOR  CX, CX
        MOV  DX, $1
        MOV  AX, seg fname
        MOV  DS, AX
        XOR  DI, DI
        STC
        MOV  AX, $716C
        INT  $21
        JNC  @end

        MOV  DX, offset fname + 1
        MOV  AX, seg fname
        MOV  DS, AX
        MOV  AX, $3D02
        INT  $21
        JNC  @end

        MOV  RES, AX
        XOR  AX, AX
@end:
        POP  DS
END;

FUNCTION lRead(handl : WORD; VAR dest; count : WORD) : WORD;ASSEMBLER;
ASM
        PUSH DS
        XOR  AX, AX
        MOV  RES, AX
        MOV  BX, handl
        MOV  CX, count
        LDS  DX, dest
        MOV  AH, $3F
        INT  $21
        POP  DS
        JNC  @ok
        MOV  RES, AX
        XOR  AX, AX
@ok:
END;

FUNCTION lWrite(handl : WORD; VAR dest; count : WORD) : WORD;ASSEMBLER;
ASM
        PUSH DS
        XOR  AX, AX
        MOV  RES, AX
        MOV  BX, handl
        MOV  CX, count
        LDS  DX, dest
        MOV  AH, $40
        INT  $21
        POP  DS
        JNC  @ok
        MOV  RES, AX
        XOR  AX, AX
@ok:
END;

PROCEDURE lTruncate(handl : WORD);ASSEMBLER;
ASM
        MOV  BX, handl
        XOR  CX, CX
        MOV  AH, $40
        INT  $21
END;

PROCEDURE lSeek(handl : WORD; seek_typ : BYTE; pos : DWORD);ASSEMBLER;
ASM
        MOV  BX, handl
        MOV  DX, word ptr [pos]
        MOV  CX, word ptr [pos + 2]
        MOV  AH, $42
        MOV  AL, seek_typ
        INT  $21
END;

FUNCTION lTell(handl : word) : DWORD;ASSEMBLER;
ASM
        MOV  BX, handl
        MOV  DX, DX
        MOV  CX, DX
        MOV  AX, $4201
        INT  $21
END;

PROCEDURE lClose(handl : WORD);ASSEMBLER;
ASM
        MOV  BX, handl
        MOV  AH, $3E
        INT  $21
END;

PROCEDURE lErase;ASSEMBLER;
ASM
        XOR  AX, AX
        MOV  RES, AX
        PUSH DS
        MOV  DI, offset fname + 1
        XOR  CX, CX
        MOV  AX, seg fname
        MOV  DS, AX
        XOR  SI, SI
        STC
        MOV  AX, $7141
        INT  $21
        MOV  AL, 1
        JC   @cont
        DEC  AL
@cont:
        OR   AL, AL
        JZ   @end
        XOR  CX, CX
        MOV  DX, offset fname + 1
        MOV  AX, seg fname
        MOV  DS, AX
        STC
        MOV  AH, $41
        INT  $21
        MOV  AL, 1
        JC   @end
        DEC  AL
@end:
        POP  DS
        XOR  AH, AH
        MOV  RES, AX
END;

FUNCTION lRename:BOOLEAN;ASSEMBLER;
ASM
        PUSH DS
        MOV  AX, seg fname
        MOV  DS, AX
        MOV  ES, AX
        MOV  DX, offset fname + 1
        MOV  DI, offset fname2 + 1
        STC
        MOV  AX, $7156
        INT  $21
        MOV  AX, 1
        JNC  @ok
        
        MOV  AX, seg fname
        MOV  DS, AX
        MOV  ES, AX
        MOV  DX, offset fname + 1
        MOV  DI, offset fname2 + 1
        MOV  AH, $56
        STC
        INT  $21
        MOV  AX, 1
        JNC  @ok
        XOR  AX, AX
@ok:
        POP  DS
END;

PROCEDURE Assign(VAR f : BFILE; fname : STRING);
BEGIN
        FillChar(f, SizeOf(BFILE), #0);
        f.filename := fname;
END;

PROCEDURE ReWrite(VAR f : BFILE);
BEGIN
        IF f.is_open THEN EXIT;
        fname := f.filename + #0;
        f.ioresult := 0;
        f.f := lReWrite;
        IF f.f = 0 THEN f.ioresult := 5;
        f.is_open := f.ioresult = 0;
        f.buf_count := 0;
        f.buf_pos := 0;
        f.buf_page := 0;
        f.fsize := 0;
END;

PROCEDURE Reset(VAR f : BFILE);
BEGIN
        IF f.is_open THEN EXIT;
        f.ioresult := 0;
        fname := f.filename + #0;
        f.f := lReset;
        IF f.f = 0 THEN f.ioresult := 2;
        f.is_open := f.ioresult = 0;
        f.buf_count := 0;
        f.buf_pos := 0;
        f.buf_page := 0;
        IF f.is_open THEN BEGIN
                lSeek(f.f, SEEK_END, 0);
                f.fsize := lTell(f.f);
                lSeek(f.f, SEEK_BEG, 0);
                f.buf_count := lRead(f.f, f.buf, SizeOf(BFILE_BUF));
                if res <> 0 THEN f.ioresult := 100;
        END;
END;

FUNCTION Eof(VAR f : BFILE) : BOOLEAN;
BEGIN
        IF NOT f.is_open THEN BEGIN
                f.ioresult := 103;
                EXIT;
        END;
        f.ioresult := 0;
        Eof := (f.buf_page * SizeOf(BFILE_BUF) + f.buf_pos) = f.fsize;
END;

PROCEDURE switch_page(VAR f : BFILE; new_page : DWORD);
VAR     ns : DWORD;
BEGIN
        f.ioresult := 0;
        IF f.buf_page = new_page THEN EXIT;
        IF f.buf_update THEN BEGIN
                lSeek(f.f, SEEK_BEG, f.buf_page * SizeOf(BFILE_BUF));
                IF f.ioresult <> 0 THEN EXIT;
                lWrite(f.f, f.buf, f.buf_count);
                f.ioresult := res;
                IF f.ioresult <> 0 THEN BEGIN
                        f.ioresult := 101;
                        EXIT;
                END;
                ns := f.buf_page * SizeOf(BFILE_BUF) + f.buf_count;
                IF f.fsize < ns THEN f.fsize := ns;
                f.buf_update := FALSE;
        END;
        lSeek(f.f, SEEK_BEG, new_page * SizeOf(BFILE_BUF));
        IF f.ioresult <> 0 THEN EXIT;
        f.buf_page := new_page;
        f.buf_count := lRead(f.f, f.buf, SizeOf(BFILE_BUF));
        f.ioresult := res;
        IF f.ioresult <> 0 THEN BEGIN
                f.ioresult := 100;
                EXIT;
        END;
END;

PROCEDURE BlockWrite(VAR f : BFILE; VAR d; count : WORD);
VAR     p     : PCHAR;
        delta : WORD;
BEGIN
        IF NOT f.is_open THEN BEGIN
                f.ioresult := 105;
                EXIT;
        END;
        f.ioresult := 0;
        res := 0;
        p := @d;
        WHILE count <> 0 DO BEGIN
                delta := SizeOf(BFILE_BUF) - f.buf_pos;
                IF delta = 0 THEN BEGIN
                        switch_page(f, f.buf_page + 1);
                        IF f.ioresult <> 0 THEN BREAK;
                        f.buf_pos := 0;
                        delta := SizeOf(BFILE_BUF);
                END;
                IF delta > count THEN delta := count;
                Move(p[0], f.buf[f.buf_pos], delta);
                f.buf_update := TRUE;
                Inc(f.buf_pos, delta);
                Inc(p, delta);
                Dec(count, delta);
                IF f.buf_pos > f.buf_count THEN f.buf_count := f.buf_pos;
        END;
END;

FUNCTION BlockRead(VAR f : BFILE; VAR d; count : WORD) : WORD;
VAR     p     : PCHAR;
        delta : WORD;
        r     : WORD;
BEGIN
        IF NOT f.is_open THEN BEGIN
                f.ioresult := 104;
                EXIT;
        END;
        f.ioresult := 0;
        res := 0;
        p := @d;
        WHILE count <> 0 DO BEGIN
                delta := f.buf_count - f.buf_pos;
                IF delta = 0 THEN BEGIN
                        switch_page(f, f.buf_page + 1);
                        IF f.ioresult <> 0 THEN BREAK;
                        f.buf_pos := 0;
                        delta := f.buf_count;
                END;
                IF delta > count THEN delta := count;
                Move(f.buf[f.buf_pos], p[0], delta);
                Inc(f.buf_pos, delta);
                Inc(r, delta);
                Dec(count, delta);
                Inc(p, delta);
        END;
        BlockRead := r;
END;

PROCEDURE Seek(VAR f : BFILE; pos : DWORD);
BEGIN
        IF NOT f.is_open THEN BEGIN
                f.ioresult := 103;
                EXIT;
        END;
        f.ioresult := 0;
        res := 0;
        switch_page(f, pos DIV SizeOf(BFILE_BUF));
        IF f.ioresult = 0 THEN BEGIN
                f.buf_pos := pos MOD SizeOf(BFILE_BUF);
                IF f.buf_count < f.buf_pos THEN f.buf_pos := f.buf_count;
        END;
END;

FUNCTION FilePos(VAR f : BFILE) : DWORD;
BEGIN
        f.ioresult := 0;
        IF NOT f.is_open THEN BEGIN
                f.ioresult := 103;
                FilePos := 0;
        END ELSE FilePos := f.buf_page * SizeOf(BFILE_BUF) + f.buf_pos;
END;

FUNCTION FileSize(VAR f : BFILE) : DWORD;
BEGIN
        f.ioresult := 0;
        IF NOT f.is_open THEN BEGIN
                f.ioresult := 103;
                FileSize := 0;
        END ELSE FileSize := f.fsize;
END;

PROCEDURE Close(VAR f : BFILE);
BEGIN
        IF NOT f.is_open THEN EXIT;
        f.ioresult := 0;
        res := 0;
        IF f.buf_update THEN BEGIN
                lSeek(f.f, SEEK_BEG, f.buf_page * SizeOf(BFILE_BUF));
                lWrite(f.f, f.buf, f.buf_count);
                f.ioresult := res;
                IF f.ioresult <> 0 THEN f.ioresult := 101;
        END;
        lClose(f.f);
        f.is_open := FALSE;
        f.buf_count := 0;
        f.buf_pos := 0;
        f.buf_page := 0;
        f.fsize := 0;
        FillChar(f, SizeOf(BFILE), #0);
END;

PROCEDURE Write(VAR f : BFILE; s : STRING);
BEGIN
        System2.BlockWrite(f, s[1], ORD(s[0]));
END;

PROCEDURE WriteLn(VAR f : BFILE; s : STRING);
BEGIN
        System2.BlockWrite(f, s[1], ORD(s[0]));
        IF f.ioresult = 0 THEN System2.BlockWrite(f, LN_STR[1], ORD(LN_STR[0]));
END;

PROCEDURE WriteLnErr (s : STRING);
BEGIN
        lWrite(2, s[1], ORD(s[0]));
        lWrite(2, LN_STR[1], ORD(LN_STR[0]));
END;

PROCEDURE ReadLn(VAR f : BFILE; VAR s : STRING);
VAR     c   : CHAR;
BEGIN
        c := #0;
        s[0] := #0;
        WHILE s[0] <> #255 DO BEGIN 
                WHILE f.buf_pos < f.buf_count DO BEGIN
                        c := f.buf[f.buf_pos];
                        Inc(f.buf_pos);
                        IF c <> #$0D THEN BEGIN
                                IF c = #$0A THEN BREAK;
                                Inc(s[0]);
                                s[ORD(s[0])] := c;
                        END;
                END;
                IF (c = #$0A) OR (s[0] = #255) THEN BREAK;
                IF f.buf_pos = f.buf_count THEN BEGIN
                        switch_page(f, f.buf_page + 1);
                        IF f.ioresult <> 0 THEN BREAK;
                        f.buf_pos := 0;
                        IF f.buf_count = 0 THEN BREAK;
                END;
        END;
END;

PROCEDURE Truncate (VAR f : BFILE);
VAR     ns : DWORD;
BEGIN
        IF NOT f.is_open THEN BEGIN
                f.ioresult := 105;
                EXIT;
        END;
        ns := f.buf_page * SizeOf(BFILE_BUF) + f.buf_pos;
        res := 0;
        lSeek(f.f, SEEK_BEG, ns);
        lTruncate(f.f);
        f.ioresult := res;
        IF f.ioresult <> 0 THEN BEGIN
                f.ioresult := 101;
                EXIT;
        END;
        f.buf_count := f.buf_pos;
        f.fsize := ns;
END;

PROCEDURE Erase (VAR f : BFILE);
BEGIN
        IF f.is_open THEN EXIT;
        fname := f.filename + #0;
        lErase;
        f.ioresult := res;
        IF f.ioresult = 0 THEN f.ioresult := 2 ELSE f.ioresult := 0;
END;

PROCEDURE BlockCopy (VAR src, dst : BFILE; count : DWORD);
VAR     delta : WORD;
BEGIN
        WHILE count <> 0 DO BEGIN
                delta := src.buf_count - src.buf_pos;
                IF delta = 0 THEN BEGIN
                        switch_page(src, src.buf_page + 1);
                        IF src.ioresult <> 0 THEN BREAK;
                        src.buf_pos := 0;
                        delta := src.buf_count;
                END;
                IF delta > count THEN delta := count;
                BlockWrite(dst, src.buf[src.buf_pos], delta);
                IF dst.ioresult <> 0 THEN BREAK;
                Inc(src.buf_pos, delta);
                Dec(count, delta);
        END;
END;

PROCEDURE Rename (VAR f : BFILE; newName : STRING);
BEGIN
        f.ioresult := 0;
        IF f.is_open THEN EXIT;
        fname := f.filename + #0;
        fname2 := newName + #0;
        IF lRename THEN f.filename := newName ELSE f.ioresult := 5;
END;

PROCEDURE GetDir(d : BYTE; VAR s : STRING);
VAR
        res : INTEGER;
BEGIN
        res := 0;
        s[0] := #0;
        ASM
                PUSH DS
                LDS  SI, s
                INC  SI
                MOV  AX, $7147
                STC
                MOV  DL, d
                PUSH DX
                PUSH DS
                PUSH SI
                INT  $21
                POP  SI
                POP  DS
                POP  DX
                MOV  AX, 1
                JNC  @end

                MOV  AH, $47
                STC
                INT  $21
                MOV  AX, 1
                JNC  @end
                XOR  AX, AX
        @end:
                POP  DS
                MOV  res, AX
        END;
        IF res = 0 THEN BEGIN
                WHILE s[0] <> #255 DO BEGIN
                        IF s[ORD(s[0])+1] = #0 THEN BREAK;
                        Inc(s[0]);
                END;
        END;
END;

PROCEDURE ChDir(s : STRING);
BEGIN
        fname := s + #0;
        ASM
                PUSH DS
                MOV  AX, seg fname
                MOV  DS, AX
                MOV  DX, offset fname + 1
                MOV  AX, $713B
                PUSH DS
                PUSH DX
                STC
                INT  $21
                POP  DX
                POP  DS
                JNC  @end
                MOV  AH, $3b
                INT  $21
        @end:
                POP  DS
        END;
END;

PROCEDURE MkDir(s : STRING);
BEGIN
        fname := s + #0;
        ASM
                PUSH DS
                MOV  AX, seg fname
                MOV  DS, AX
                MOV  DX, offset fname + 1
                MOV  AX, $7139
                PUSH DS
                PUSH DX
                STC
                INT  $21
                POP  DX
                POP  DS
                JNC  @end
                MOV  AH, $39
                INT  $21
        @end:
                POP  DS
        END;
END;

PROCEDURE RmDir(s : STRING);
BEGIN
        fname := s + #0;
        ASM
                PUSH DS
                MOV  AX, seg fname
                MOV  DS, AX
                MOV  DX, offset fname + 1
                MOV  AX, $713A
                PUSH DS
                PUSH DX
                STC
                INT  $21
                POP  DX
                POP  DS
                JNC  @end
                MOV  AH, $3A
                INT  $21
        @end:
                POP  DS
        END;
END;

FUNCTION ParamCount : INTEGER;
VAR     r, len : INTEGER;
        str    : PSTRING;
        pos    : INTEGER;
BEGIN
        r := 0;
        str := PString(ptr(PrefixSeg, $80));
        pos := 1;
        len := ORD(str^[0]);
        WHILE pos <= ORD(str^[0]) DO BEGIN
                WHILE (str^[pos] <= ' ') AND (pos <= len) DO Inc(pos);
                IF pos > len THEN BREAK;
                IF str^[pos] = '"' THEN BEGIN
                        Inc(pos);
                        WHILE (str^[pos] <> '"') AND (pos <= len) DO BEGIN
                                Inc(pos);
                        END;
                        Inc(pos);
                        Inc(r);
                END ELSE BEGIN
                        WHILE (str^[pos] > ' ') AND (pos <= len) DO BEGIN
                                Inc(pos);
                        END;
                        Inc(r);
                END;
        END;
        ParamCount := r;
END;


FUNCTION ParamStr(i : INTEGER) : STRING;
VAR     r   : STRING;
        str : PSTRING;
        pos : INTEGER;
        len : INTEGER;
        c   : CHAR;
        p   : PCHAR;
BEGIN
        r[0] := #0;
        IF i <> 0 THEN BEGIN
                str := PString(ptr(PrefixSeg, $80));
                len := ORD(str^[0]);
                pos := 1;
                Dec(i);
                WHILE pos <= len DO BEGIN
                        WHILE (str^[pos] <= ' ') AND (pos <= len) DO Inc(pos);
                        IF pos > len THEN BREAK;
                        IF str^[pos] = '"' THEN BEGIN
                                Inc(pos);
                                WHILE (str^[pos] <> '"') AND (pos <= len) DO BEGIN
                                        IF i = 0 THEN BEGIN
                                                Inc(r[0]);
                                                r[ORD(r[0])] := str^[pos];
                                        END;
                                        Inc(pos);
                                END;
                                Inc(pos);
                                Dec(i);
                        END ELSE BEGIN
                                WHILE (str^[pos] > ' ') AND (pos <= len) DO BEGIN
                                        IF i = 0 THEN BEGIN
                                                Inc(r[0]);
                                                r[ORD(r[0])] := str^[pos];
                                        END;
                                        Inc(pos);
                                END;
                                Dec(i);
                        END;
                END;
        END ELSE BEGIN
                IF SELFNAME = NIL THEN BEGIN
                        SELFNAME := ptr(PWORD(ptr(PrefixSeg, $2C))^, 0);
                        c := #0;
                        WHILE NOT ((SELFNAME[0] = #0) AND (c = #0)) DO BEGIN
                                c := SELFNAME[0];
                                Inc(SELFNAME, 1);
                        END;
                        Inc(SELFNAME, 3);
                END;
                IF SELFNAME <> NIL THEN BEGIN
                        p := SELFNAME;
                        WHILE r[0] <> #255 DO BEGIN
                                IF p[0] = #0 THEN BREAK;
                                Inc(r[0]);
                                r[ORD(r[0])] := p[0];
                                Inc(p);
                        END;
                END;
        END;
        ParamStr := r;
END;

END.
