PROGRAM        = roman
ALGOLW_SOURCES = BEGIN argv.alw number.alw roman.alw END
C_SOURCES      = argv-library.c
EXTRA_FILES    = README expected.output

test : build
	./$(PROGRAM) 1 3999 849 '  + 83 ' 4890 -1 lolwut > actual.output
	diff expected.output actual.output
	rm actual.output

clean::
	rm -f actual.output

include awe.mk
