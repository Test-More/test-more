#run as "time perl ./profiling/fasttinyok.t > /dev/null"
#or win32 "timeit perl profiling/fasttinyok.t > NUL"
unshift(@INC, './profiling');
require GenTAP;
GenTAP(0, 0, 'tinyok', 100000);
