#!/usr/env python3

template = '''<!DOCTYPE html>
<html>
  <head>    
    <title>%s</title>
  </head>
<body>
<pre>%s</pre>
</body>
</html>
'''

from sys import stdout, stdin, argv
from html import escape

stdout.write(template % (escape(argv[1]), escape(stdin.read())))
