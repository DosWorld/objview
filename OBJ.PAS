{$G-,S-,R-,I-}
unit obj;

interface

const

OBJ_THEADER = $80;
OBJ_LHEADER = $F0;
OBJ_COMMENT = $88;
OBJ_PUBDEF = $90;
OBJ_LINNUM = $94;
OBJ_LNAMES = $96;
OBJ_SEGDEF = $98;
OBJ_GRPDEF = $9A;
OBJ_FIXUP = $9C;
OBJ_COMDEF = $B0;
OBJ_LEDATA = $A0;
OBJ_LIDATA = $A2;
OBJ_EXTDEF = $8C;
OBJ_MODEND = $8A;
OBJ_LIBEND = $F1;

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

type

PObj=^TObj;
TObj=record
	t	: byte;
	count	: word;
	mem	: pchar;
	ofs	: longint;
	module	: PObj;
	next	: PObj;
end;

function load(fname:string):PObj;
procedure save(obj:PObj; fname:string);
function lookup(obj:PObj; t:byte):PObj;
procedure free(obj:PObj);

function create(t:byte; count:word; parent:PObj):PObj;
function is_type(obj:PObj; t:byte):boolean;
procedure merge_fixup(obj:PObj);

function get_str(obj:PObj; ofs,len:word):string;
procedure set_str(obj:PObj; ofs:word; s:string);

procedure getFixupAttr(bval:char; var p:integer; var B:integer; var C:integer; var A:integer);
procedure setFixupAttr(p:integer; B:integer; C:integer; A:integer; var bval:char);
procedure getFixupLocat(b1, b2:char; var ofs:word; var location:integer; var m:integer; var one:integer);
procedure getFixupFixData(bval:char; var target:integer; var P:integer; var T:integer; var Frame:integer; var F:integer);
procedure getFixupTrDat(bval:char; var Thread:integer; var Method:integer; var D:integer; var Zero:integer);

implementation

function create(t:byte; count:word; parent:PObj):PObj;
var r:PObj;
begin
	getmem(r, sizeof(TObj));
	r^.t := t;
	r^.count := count;
	r^.next := nil;
	getmem(r^.mem, count);
	if parent <> nil then parent^.next := r;
	create := r;
end;

function load(fname:string):PObj;
var r, last : PObj;
	f : file;
	crc, b : byte;
	w : word;
        p : longint;
	islib : boolean;
	module	: PObj;
begin
	islib := false;
	r := nil; last := nil; module := nil;
	assign(f, fname);
        {$I-}
	reset(f, 1);
	while not eof(f) do begin
		p := filepos(f);
		blockread(f, b, 1);
		blockread(f, w, 2);
		dec(w, 1);
		last := create(b, w, last);
                last^.ofs := p;
                last^.module := module;
		blockread(f, last^.mem[0], w);
		if r = nil then r := last;
		blockread(f, crc, 1);
		if b = OBJ_THEADER then module := last;
		if b = OBJ_LHEADER then islib := true;
		if b = OBJ_MODEND then begin
			if not islib then break;
			p := filepos(f);
			if p and $0f <> 0 then seek(f, p + 16 - (p and $0F));
		end;
		if b = OBJ_LIBEND then break;
	end;
	close(f);
        {$I+}
	load := r;
end;

function crc(t:byte;count:word; mem:pchar; len:word):byte;
var i:word; r:byte;
begin
	r := t;
	inc(r, lo(count));
	inc(r, hi(count));
	for i := 0 to len do inc(r, ord(mem[i]));
	crc := (-r) and $FF;
end;

procedure save(obj:PObj; fname:string);
var f : file;
	b : byte;
	w : word;
	islib : boolean;
	m : array[1..16] of byte;
	p : longint;
begin
	islib := false;
	assign(f, fname);
	rewrite(f, 1);
	while obj <> nil do begin
		if obj^.t = OBJ_LHEADER then islib := true;
		w := obj^.count + 1;
		blockwrite(f, obj^.t, 1);
		blockwrite(f, w, 2);
		blockwrite(f, obj^.mem[0], obj^.count);
		b := crc(obj^.t, w, obj^.mem, obj^.count);
		blockwrite(f, b, 1);
		if islib and (obj^.t = OBJ_MODEND) then begin
			p := filepos(f);
			if p and $0f <> 0 then blockwrite(f, m, 16 - (p and $0F));
		end;
		obj := obj^.next;
	end;
	close(f);
end;

function is_type(obj:PObj; t:byte):boolean;
begin
	if obj = nil then is_type:=false else is_type:=obj^.t=t;
end;

procedure merge_fixup(obj:PObj);
var cur, old : PObj;
	w : word;
	m : pchar;
begin
	cur := obj;
	while cur <> nil do begin
		if is_type(cur, OBJ_FIXUP) and is_type(cur^.next, OBJ_FIXUP) then begin
			old := cur^.next;
			cur^.next := cur^.next^.next;
			w := cur^.count + old^.count;
			getmem(m, w);
			move(cur^.mem^, m^, cur^.count);
			move(old^.mem^, m[cur^.count], old^.count);
			freemem(cur^.mem, cur^.count);
			cur^.count := w;
			cur^.mem := m;
			freemem(old^.mem, old^.count);
			freemem(old, sizeof(TObj));
		end else cur := cur^.next;
	end;
end;

procedure free(obj:PObj);
var next : PObj;
begin
	while obj <> nil do begin
		next := obj^.next;
		freemem(obj^.mem, obj^.count);
		freemem(obj, sizeof(TObj));
		obj := next;
	end;
end;

function lookup(obj:PObj; t:byte):PObj;
var r : PObj;
begin
	r := nil;
	while obj <> nil do begin
		if obj^.t = t then begin r := obj; break; end;
		obj := obj^.next;
	end;
	lookup := r;
end;

function get_str(obj:PObj; ofs, len:word):string;
var r:string;
	i : integer;
begin
	r := '';
	dec(len);
	for i := 0 to len do begin
		r := r + obj^.mem[ofs + i];
	end;
	get_str := r;
end;

procedure set_str(obj:PObj; ofs:word; s:string);
var i,l : integer;
begin
	l := length(s);
	for i := 1 to l do begin
		obj^.mem[ofs + i - 1] := s[i];
	end;
end;

procedure getFixupAttr(bval:char; var p:integer; var B:integer; var C:integer; var A:integer);
begin
	p := (ord(bval) shr 7) and 1;
	b := (ord(bval) shr 6) and 1;
	c := (ord(bval) shr 3) and $07;
	a := ord(bval) and $07;
end;

procedure setFixupAttr(p:integer; B:integer; C:integer; A:integer; var bval:char);
begin
	bval := #0;
	bval := chr(ord(bval) or (p and 1) shl 7);
	bval := chr(ord(bval) or (b and 1) shl 6);
	bval := chr(ord(bval) or (c and 7) shl 3);
	bval := chr(ord(bval) or (a and 7));
end;

procedure getFixupLocat(b1, b2:char; var ofs:word; var location:integer; var m:integer; var one:integer);
var w:word;
begin
	w := (ord(b1) and $ff) or ((ord(b2) and $ff) shl 8);
	ofs := (w shr 6) and $3f;
	location := (w shr 2) and $f;
	m := (w shr 1) and $1;
	one := w and $1;
end;

procedure getFixupFixData(bval:char; var target:integer; var P:integer; var T:integer; var Frame:integer; var F:integer);
begin
	target := (ord(bval) shr 6) and $03;
	P := (ord(bval) shr 5) and $01;
	T := (ord(bval) shr 4) and $01;
	Frame := (ord(bval) shr 1) and $07;
	F := ord(bval) and $01;
end;

procedure getFixupTrDat(bval:char; var Thread:integer; var Method:integer; var D:integer; var Zero:integer);
begin
	Thread := (ord(bval) shr 6) and $03;
	Method := (ord(bval) shr 3) and $07;
	D := (ord(bval) shr 1) and $01;
	Zero := ord(bval) and $01;
end;

end.
