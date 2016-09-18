FC=ifort
FCFLAGS=-g -O2 -shared-intel -I/home/yyao/lib4cam/include
LDFLAGS=-L/home/yyao/lib4cam/lib -lnetcdff -lnetcdf
waccm2wrf.exe:waccm.o
	$(FC) $(LDFLAGS) -o waccm2wrf.exe waccm.o
waccm.o:waccm.f90
	$(FC) $(FCFLAGS) -c waccm.f90
clean:
	rm -f waccm.o waccm2wrf.exe
