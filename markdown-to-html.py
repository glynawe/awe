''' markdown-to-html.py -- convert a Markdown file to an HTML page'''

# The HTML page will require 'github-markdown.css' from
# https://github.com/sindresorhus/github-markdown-css
#
# The Markdown file must contain a top-level heading

from pathlib import Path
from sys import argv
from markdown import markdown
from html import escape
import re

markdown_text = Path(argv[1]).read_text()
html_file = Path(argv[2])

html = markdown(markdown_text, extensions=['extra', 'toc'])
title = escape(re.search(r'^# +(.+) *$', markdown_text, re.MULTILINE).group(1))

html_file.write_text('''<!DOCTYPE html>
<html>
    <head>
        <meta charset="utf-8">
        <meta name="language" content="en">
        
        <title>%s</title>

        <!-- See https://github.com/sindresorhus/github-markdown-css -->
        <meta name="viewport" content="width=device-width, initial-scale=1, minimal-ui">
        <link rel="stylesheet" href="github-markdown.css">
        <style>
             body {
                 box-sizing: border-box;
                 min-width: 200px;
                 max-width: 980px;
                 margin: 0 auto;
                 padding: 45px;
             }
        </style>
    </head>
    <body>
        <article class="markdown-body">
%s
        </article>
    </body>
</html>''' % (title, html))
