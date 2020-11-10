# OldParse test one of Hendrik Boom's 1970's source files. 

PROGRAM        = parse
ALGOLW_SOURCES = parse.alw
OTHER_FILES    = original-parse.alw expected.output

test: clean parse
	./parse < GRAMMAR > actual.output
	diff expected.output actual.output
	echo "testprograms: run of PARSE passed!"

parse.alw: original-parse.alw
#	The timing is different every run, so to compare the actual output
#	with our expected one, we cheap a little and remove the timing 
#	statements from the program
	sed -e 's/WRITE("Time:.*;//g' < original-parse.alw > parse.alw

clean ::
	rm -f parse.alw actual.output

include awe.mk
