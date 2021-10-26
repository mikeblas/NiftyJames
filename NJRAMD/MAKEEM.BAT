masm njramd;
masm /DV286 njramd,njramdxp;
masm /DV286 /DPCL njramd,njramdpc;
link njramd;
link njramdxp;
link njramdpc;
exe2bin njramd njramd.sys;
exe2bin njramdxp njramdxp.sys;
exe2bin njramdpc njramdpc.sys;
