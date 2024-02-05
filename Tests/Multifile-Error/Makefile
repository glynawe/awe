AWE=../../awe
LIBAWE=../../libawe.a
AWEH_PATH=../..

CFLAGS=-I$(AWEH_PATH)
LDLIBS=-lm -lgc $(LIBAWE)

.SUFFIXES: .alw
.PHONY: test clean

test : clean
	$(AWE) begin.alw argv-headers.alw program.alw end.alw 2> actual.output || diff --strip-trailing-cr expected.output actual.output
	echo "testprograms: argv test passed!"

clean:
	rm -f *.c actual.output
