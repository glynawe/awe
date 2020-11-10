PROGRAM        = test-cords
ALGOLW_SOURCES = BEGIN file.alw cords.alw try-it.alw END
C_SOURCES      = file.c cords.c cords/cordbscs.c cords/cordxtra.c
C_INCLUDES     = cords/cord.h cords/private/cord_pos.h
EXTRA_FILES    = cords/README.txt cords/*.[hc]

CFLAGS = -Icord -I/usr/include/gc   # For the cords/* code.
LDLIBS =

include awe.mk

test : clean build
	./$(PROGRAM)
	echo "Success!"
