{
 MIT License

Copyright (c) 2020 Viacheslav Komenda

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
{$G-,A-,D+,L+,R+,S+,Q+}
{$M 32000, 128000, 640000}

uses strutil, obj, scr, kbd;

const
BGCOLOR = $17;

type

PViewItem=^TViewItem;
TViewItem=record
        name     : string[80];
        o        : PObj;
        next     : PViewItem;
end;

var h,w:word;

function type2name(t:byte):string;
var s:string;
begin
        case t of
        OBJ_THEADER: s := 'THEADER';
        OBJ_LHEADER: s := 'LHEADER';
        OBJ_COMMENT: s := 'COMMENT';
        OBJ_PUBDEF:  s := 'PUBDEF';
        OBJ_LNAMES:  s := 'LNAMES';
        OBJ_LINNUM:  s := 'LINNUM';
        OBJ_SEGDEF:  s := 'SEGDEF';
        OBJ_GRPDEF:  s := 'GRPDEF';
        OBJ_FIXUP:   s := 'FIXUP';
        OBJ_LEDATA:  s := 'LEDATA';
        OBJ_LIDATA:  s := 'LIDATA';
        OBJ_COMDEF:  s := 'COMDEF';
        OBJ_EXTDEF:  s := 'EXTDEF';
        OBJ_MODEND:  s := 'MODEND';
        OBJ_LIBEND:  s := 'LIBEND';
        else s := 'UNKNOWN'
        end;
        type2name := hexb(t) + '-' + s;
end;

procedure freeall(root:PViewItem);
var item:PViewItem;
begin
        while root <> nil do begin
                item := root;
                root := root^.next;
                freemem(item, sizeof(TViewItem));
        end;
end;

function getc(hl:boolean;cur : PViewItem):byte;
var c : byte;
begin
        c := BGCOLOR;
        if hl then c:=$20
        else if cur^.o <> nil then begin
                case cur^.o^.t of
                OBJ_LHEADER: c := $12;
                OBJ_THEADER: c := $12;
                OBJ_LEDATA:  c := $13;
                OBJ_MODEND:  c := $16;
                OBJ_LIBEND:  c := $16;
                end;
        end;
        getc := c;
end;

function mem2str(ofs:longint;m:pchar;len:byte):string;
var s2, s3 : string;
         i : byte;
begin
        s2 := ''; s3 := '';
        for i:= 0 to len-1 do begin
                s2 := s2 + ' '+hexb(ord(m[i]));
                s3 := s3 + m[i];
                if (i and $3) = 3 then s2 := s2 + ' ';
        end;
        mem2str := ' ' + hexdw(ofs) + ' ' + rpad(s2, 17*3) + '  ' + s3;
end;

function view_list(title:string; vroot:PViewItem; var current:PViewItem; total:word; var scr_start, scr_pos : word):word;
var vcur : PViewItem;
        k, i   : word;
        c      : byte;
        needredraw : boolean;
        s1, s2 :string;
begin
        needredraw := true;
        str(total, s2);
        while true do begin
                if needredraw then begin
                        scr.cls(BGCOLOR);
                        current := nil;
                        str(scr_pos + scr_start + 1, s1);
                        vcur := vroot; i := 0;
                        while (vcur <> nil) and (i < scr_start) do begin
                                inc(i);
                                vcur := vcur^.next;
                        end;
                        while (vcur <> nil) and (i <= scr_start + h - 2) do begin
                                c := getc(i = (scr_start + scr_pos), vcur);
                                if i = (scr_start + scr_pos) then current := vcur;
                                scr.print(0, i - scr_start + 1, c, vcur^.name);
                                inc(i);
                                vcur := vcur^.next;
                        end;
                        print(0, 0, $70, rpad(title + ' ' + lpad(s1, 5) + ' / ' + s2, w));
                end;
                scr.show;
                k := getkey;
                case hi(k) of
                SCAN_HOME: begin
                                scr_pos := 0;
                                scr_start := 0;
                                needredraw := true;
                        end;
                SCAN_END: begin
                                if total < h - 1 then begin
                                        scr_pos := total - 1;
                                end else begin
                                        scr_start := total - h + 1;
                                        scr_pos := h - 2;
                                end;
                                needredraw := true;
                        end;
                SCAN_PGUP: begin
                                if scr_pos <> 0 then scr_pos := 0
                                else if scr_start + scr_pos < h-1 then begin
                                        scr_start := 0;
                                end else begin
                                        dec(scr_start, h - 1);
                                end;
                                needredraw := true;
                        end;
                SCAN_PGDN: begin
                                if (scr_pos <> h - 2) then begin
                                        if scr_start + h - 2 < total then scr_pos := h - 2
                                        else scr_pos := total - scr_start - 1;
                                end else if scr_start + (h - 1) * 2 < total then begin
                                        inc(scr_start, h - 1);
                                end else begin
                                        scr_start := total - h + 1;
                                        scr_pos := h - 2;
                                end;
                                needredraw := true;
                        end;
                SCAN_UP: if scr_start+scr_pos <> 0 then begin
                                if scr_pos<>0 then dec(scr_pos) else dec(scr_start);
                                needredraw := true;
                        end;
                SCAN_DOWN: if scr_pos + scr_start + 1 < total then begin
                                if scr_pos + 2 < h then inc(scr_pos) else inc(scr_start);
                                needredraw := true;
                        end;
                else break;
                end;
        end;
        view_list := k;
end;

procedure view_entry(title:string; o:PObj);
var vroot, vlast, vcur : PViewItem;
        ofs                : longint;
        key, i, l, total   : word;
        scr_start, scr_pos : word;
        s, s1              : string;
begin
        vroot := nil; vlast := nil;
        total := 0;

        if o^.t = OBJ_LNAMES then begin
                i := 1;
                while i < o^.count do begin
                        inc(total, 1);
                        getmem(vcur, sizeof(TViewItem));
                        s := obj.get_str(o, i + 1, ord(o^.mem[i]));
                        vcur^.name := ' ' + lpad(wtoa(total), 8) + ': ' + s + '(' + wtoa(ord(o^.mem[i])) + ')';
                        vcur^.o := nil;
                        vcur^.next := nil;
                        if vroot = nil then vroot := vcur;
                        if vlast <> nil then vlast^.next := vcur;
                        vlast := vcur;
                        inc(i, length(s)+1);
                end;
        end;

        i := 0;
        ofs := o^.ofs;
        title := title + ' ' + type2name(o^.t);
        while i < o^.count do begin
                l := o^.count - i;
                if l > 16 then l := 16;
                getmem(vcur, sizeof(TViewItem));
                vcur^.name := mem2str(ofs, o^.mem + i, l);
                vcur^.o := nil;
                vcur^.next := nil;
                if vroot = nil then vroot := vcur;
                if vlast <> nil then vlast^.next := vcur;
                vlast := vcur;
                inc(i, l);
                inc(total, 1);
                inc(ofs, l);
        end;
        scr_start := 0;
        scr_pos := 0;
        while true do begin
                key := hi(view_list(title, vroot, vcur, total, scr_start, scr_pos));
                if key = SCAN_ESC then break;
                if key = SCAN_LEFT then break;
                if key = SCAN_BS then break;
                if key = SCAN_ENTER then break;
        end;
        freeall(vroot);
end;

procedure view(fname:string; o:PObj);
var vroot, vlast, vcur : PViewItem;
        selected, k    : PObj;
        s              : string;
        i, total, key  : word;
        scr_start, scr_pos : word;
        c              : byte;
        s1, s2         : string[10];
        title          : string;
begin
        vroot := nil; vlast := nil;
        k := o; total := 0;
        while k <> nil do begin
                getmem(vcur, sizeof(TViewItem));
                vcur^.name := ' '+hexdw(k^.ofs)+' | '+hexw(k^.count)+' | '+type2name(k^.t);
                if k^.t = OBJ_THEADER then begin
                        if k^.count > 1 then begin
                                title := obj.get_str(k, 1, ord(k^.mem[0]));
                                vcur^.name := vcur^.name + ' ' + title;
                        end;
                end;
                vcur^.name := rpad(vcur^.name, w);
                vcur^.next := nil;
                vcur^.o := k;
                if vroot = nil then vroot := vcur;
                if vlast <> nil then vlast^.next := vcur;
                vlast := vcur;
                inc(total);
                k := k^.next;
        end;
        scr_start := 0;
        scr_pos := 0;
        title := ' ' + fname + ' ';

        while true do begin
                key := hi(view_list(title, vroot, vcur, total, scr_start, scr_pos));
                case key of
                SCAN_ESC: break;
                SCAN_RIGHT, SCAN_ENTER: view_entry(title, vcur^.o);
                end;
        end;
        freeall(vroot);
end;

var o:PObj; fname:string;
begin
        writeln('OmfView (c) 2020 by DosWorld.  MIT License');
        writeln;
        if paramcount<>1 then begin
                writeln('Usage:');
                writeln(chr(9)+upstr(basename(paramstr(0)))+' file.obj');
                halt(1);
        end;
        fname := paramstr(1);
        o:=obj.load(fname);
        if o = nil then begin
                writeln('Could not load ', fname);
                halt(1);
        end;
        h := getheight;
        w := getwidth;
        scr.push;
        view(upstr(basename(fname)), o);
        scr.pop;
        obj.free(o);
        halt(0);
end.
