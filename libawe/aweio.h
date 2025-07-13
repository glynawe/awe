/* aweio.h -- this exposes the aweio module's Printer and Scanner types

If you understand these then you can write external procedures that redirect I/O to files.

--

This file is part of Awe. Copyright 2012 Glyn Webster.

This file is free software: you can redistribute it and/or modify it
under the terms of the GNU Limited General Public License as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Awe is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU Limited General Public
License along with Awe.  If not, see <http://www.gnu.org/licenses/>.

*/

#include <stdio.h>
#include <stdbool.h>


#define Scanner_BUFSIZE 512


typedef struct {
    FILE *input;
    char *input_name;
    bool eof;
    int state;
    int line;
    int column;
    int start_line;
    char buffer[Scanner_BUFSIZE];
    int buflen;
} _awe_Scanner;


typedef struct {
    FILE *output;
    int page;                /* The page in the printer, first page = 1 */
    int line;                /* The line the virtual printhead is in, first line = 1 */
    int column;              /* The column the virtual printhead should be in, first column = 1 */
    int true_column;         /* The column the printhead is really in, the printhead stops short when
                                printing string columns and the spaces after fields, those will not be
                                printed if they appear at the end of a line. */
    int  page_estimate;      /* The maximum number of pages that may be printed.
                                 A page estimate of 0 means you don't expect to see any output. */
    int  page_width;         /* The width of a page, in columns */
    int  page_height;        /* The height of a page, in lines */
    bool hard_page_breaks;   /* Whether there should be a page break every 60 lines.  */
                             /* (In this library virtual page breaks happen anyway, */
                             /* so this flag means "insert linefeed characters".)   */
    bool pretty_page_breaks; /* don't use linefeed characters, draw a page break of ~~~~~'s   */
    bool strict_line_breaks; /* Do not allow over-long WRITE fields to overflow the line. */
    bool trim_lines;         /* Do not print spaces at the ends of lines. */
    bool eject_last_page;    /* Perform a page break at the end of the program. */

} _awe_Printer;


extern _awe_Scanner _awe_stdin_scanner;   /* Input scanner reading from the standard input */
extern _awe_Scanner *_awe_active_scanner; /* The scanner in use. */

extern _awe_Printer _awe_stdout_printer;  /* Printer writing to the standard output */
extern _awe_Printer *_awe_active_printer; /* The printer in use. */


/* Note, 'input_name' should be NULL or point to a string that will remain
   allocated until the scanner is no longer in use. */

void _awe_Scanner_initialize (_awe_Scanner *scanner, FILE *file, char *input_name);


void _awe_Printer_initialize (_awe_Printer *printer, FILE *file);

void _awe_Printer_finalize (_awe_loc loc, _awe_Printer *printer);  /* Note: does not close the file. */


/* end */
