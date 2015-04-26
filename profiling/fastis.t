#run as "time perl ./profiling/fastis.t > /dev/null"
#or win32 "timeit perl profiling/fastis.t > NUL"
unshift(@INC, './profiling');
require GenTAP;
GenTAP(0, 0, 'is', 100000);
