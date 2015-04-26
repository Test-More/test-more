#run as "time perl ./profiling/fastprint.t > /dev/null"
#or win32 "timeit perl profiling/fastprint.t > NUL"
unshift(@INC, './profiling');
require GenTAP;
GenTAP(0, 0, 'print', 100000);
