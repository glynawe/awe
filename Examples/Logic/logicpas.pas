{$MODE TP}  { FreePascal will compile this as a Turbo Pascal program. }
program logic;

function compile(predicate : string) : string;
{ Compiles a predicate (a boolean expression) into 'reverse Polish notation'.
  The RPN uses the one-character variants of the symbols }
var
   cursor : integer;
   position  : integer;
   next   : char;
   rpn    : string;

   procedure error(message : string);
   var i : integer;
   begin
      writeln(predicate);
      for i := 1 to position - 1 do write(' ');
      writeln('^ ', message);
      halt(1)
   end;

   procedure getnext;  { the lexer. }
      
      procedure expect (c : char);
      begin
         cursor := cursor + 1;
         if (cursor > Length(predicate)) or not (predicate[cursor] = c) then
         begin position := cursor; error('expected a ' + c) end
      end;
   
   begin      
      while (cursor <= Length(predicate)) and (predicate[cursor] in [' ', #8, #13]) do
         cursor := cursor + 1;
      position := cursor;
      if cursor > Length(predicate) then
         next := chr(0)
      else begin
         case predicate[cursor] of
           '-' : begin expect('>'); next := '>' end;
           '<' : begin expect('-'); expect('>'); next := '=' end;
           '\' : begin expect('/'); next := '+' end;
           '/' : begin expect('\'); next := '.' end;
           'F' : next := '0';
           'T' : next := '1';
           'A'..'E', 'G'..'S', 'U'..'Z', 'a'..'z',
           '@', '=', '~', ',': next := predicate[cursor]
           else error('unexpected character')
         end;
         cursor := cursor + 1
      end
   end; {getnext}

   function match(c : char) : boolean;
   begin
      match := (next = c);
      if next = c then getnext
   end;

   procedure add(c : char); begin rpn := rpn + c end;

   { The parser: }
   procedure l1; forward;
   procedure l6;
   begin
      case next of
        '~': begin getnext; l6; add('~') end;
        '(': begin getnext; l1; if not match(')') then error('expected a )') end;
        '0', '1', 'A'..'Z', 'a'..'z': begin add(next); getnext end
        else error('syntax error')
      end
   end;
   procedure l5; begin l6; while match('.') do begin l6; add('.') end end;
   procedure l4; begin l5; while match('+') do begin l5; add('+') end end;
   procedure l3; begin l4; while match('@') do begin l4; add('@') end end;
   procedure l2; begin l3; while match('>') do begin l3; add('>') end end;
   procedure l1; begin l2; while match('=') do begin l2; add('=') end end;
   procedure l0; begin l1; add(','); while match(',') do begin l1; add(',') end end;
                           {note ',' means 'print'}
begin
   rpn := '';
   cursor := 1;
   getnext;
   l0;
   if next <> chr(0) then error('syntax error');
   compile := rpn
end; {compile}


procedure printtable(predicate : string; rpn : string);
var
   truthvalues : array ['A'..'z'] of boolean;
   variables   : string;
   
   procedure setvariables(minterm : integer);
   { Set the variables' values to the bits of the binary number 'minterm' }
   var i : integer;
   begin
      for i := Length(variables) downto 1 do begin
         truthvalues[variables[i]] := odd(minterm);
         minterm := minterm div 2
      end
   end;

   procedure interpret;
   { Print the right hand side of a row of the table by
     interpreting the RPN rpn on a stack machine }
   var
      stack  : array [1..100] of boolean;
      top, i : integer;
   begin
      for i := 1 to 100 do stack[i] := false;
      top := 0; 
      for i := 1 to Length(rpn) do
         case rpn[i] of
           '.': begin stack[top-1] := stack[top-1] and stack[top]; top := top - 1 end;
           '+': begin stack[top-1] := stack[top-1] or stack[top]; top := top - 1 end;
           '@': begin stack[top-1] := stack[top-1] <> stack[top]; top := top - 1 end;
           '=': begin stack[top-1] := stack[top-1] = stack[top]; top := top - 1 end;
           '>': begin stack[top-1] := not stack[top-1] or stack[top]; top := top - 1 end;
           '~': begin stack[top] := not stack[top] end;
           '0': begin top := top + 1; stack[top] := false end;
           '1': begin top := top + 1; stack[top] := true end;
           'A'..'Z', 'a'..'z': begin top := top + 1; stack[top] := truthvalues[rpn[i]] end;
           ',': begin if stack[top] then write(' 1') else write(' 0'); top := top - 1 end
         end
   end;

var
   minterm, i : integer;
begin
   variables := '';
   for i := 1 to Length(rpn) do begin
      if (rpn[i] in ['A'..'Z', 'a'..'z']) and (Pos(rpn[i], variables) = 0) then
         variables := variables + rpn[i];
   end;
   
   writeln;
   for i := 1 to Length(variables) do write(' ', variables[i]);
   writeln(' | ', predicate);

   for minterm := 0 to (1 shl Length(variables)) - 1 do
   begin
      setvariables(minterm);
      for i := 1 to Length(variables) do
         if truthvalues[variables[i]] then write(' 1') else write(' 0');
      write(' |');
      interpret;
      writeln
   end;
   writeln
end; {printtable}


var
   predicate, rpn : string;
begin
   if ParamCount <> 1 then
      writeln('usage: logic ''predicate''')
   else begin
      predicate := ParamStr(1);
      rpn := compile(predicate);
      printtable(predicate, rpn)
   end
end.
