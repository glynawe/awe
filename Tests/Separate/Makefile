AWE = ../../awe

CFLAGS = -I../.. -L../..
LDLIBS =   -lawe -lm -lgc

.PHONY: test clean

test : clean program
	./program > actual.output
	diff expected.output actual.output
	echo "testprograms: separate compilation test passed!"

program :  separate.c program.c

program.c: program.alw
	$(AWE)  program.alw -c program.c

separate.c: separate.alw
	$(AWE) separate.alw -p separate.c 

clean::
	rm -f program program.o program.c separate.o separate.c actual.output
