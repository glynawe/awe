#!/usr/env python3
# man.py -- very simple markup preprocessor for man pages

import re, time, sys

def usage():
    print('''usage: python3 man.py manpage.1.src manpage.1 MACRO="value"...

    This is a rough preprocessor to convert a subset of Markdown to man pages.

    A summary of the markup commands you can use in your src file:

    # TITLE 1 / program name / short program description
    ## heading
    *itatics*
    **bold**
    `monospace`
    {{MACRO}}
    ```
    example code block
    ``` 
    ''')
    sys.exit(1)

if len(sys.argv) < 3: usage()

macros = {'DATE': time.strftime("%Y-%m-%d"),
          'YEAR': time.strftime("%Y")}
for arg in sys.argv[3:]:
    m = re.match(r'([A-Z][A-Za-z0-9_]+)=(.*)', arg)
    if m:
        macros[m.group(1)] = m.group(2)
    else: 
        usage()
        
repls = [
    (r'^###? +(.+?)$', r'.SH "\1"'),         # ## heading
    (r'\*\*(.+?)\*\*', r'\\fB\1\\fR'),       # **bold**
    (r'\*(.+?)\*',     r'\\fI\1\\fR'),       # *itatics*
    (r'`(.+?)`',       r'\\fI\1\\fR'),       # `monospace`
    (r'^(.+?) -$',     r'\n.TP\n.B \1'),     # definition -
    (r'^# +(.+?) */ *(.+?) */ *(.+?) *$',
        r'.TH \1 "{{DATE}}" "\2" "\3"'),     # man page heading
    (r'{{(.+?)}}', 
        lambda m: macros[m.group(1)])   ]    # {{macro}} substitution


with open(sys.argv[1], "r") as f:
    page = f.read()

# split into text and code example sections, 
# odd-numbered sections will be code:
sections = re.split('```[A-Za-z]*', page)

with open(sys.argv[2], "w") as f:
    for i, s in enumerate(sections):
        if i % 2 == 0:  # text section
            for pattern, repl in repls:
                s = re.sub(pattern, repl, s, flags=re.MULTILINE)
        else:  # code section
            s = s.replace('\n', '\n    ')
            s = '\n.nf\n' + s + '\n.fi\n'   
        f.write(s)
