#run as "time perl ./profiling/fastok.t > /dev/null"
#or win32 "timeit perl profiling/fastok.t > NUL"
unshift(@INC, './profiling');
require GenTAP;
GenTAP(0, 0, 'ok', 100000);
