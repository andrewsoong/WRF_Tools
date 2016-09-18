function run_produce_periodic_yeary_bndry_conditions
close all; clear all

% nohup matlab -nojvm -nodesktop -nosplash < run_produce_periodic_yeary_bndry_conditions.m > out.txt&

% run all steps of WPS to convert CAM output to WRF initial and
% boundary conditions; see comments at header of fortran file in this
% directory for more info.  to run this, use crest, not swell, and the
% following command:
% cd ~/WRF_Mauricio/; \rm ~/WRF_Mauricio/Output/run_one_case.out; nohup run_one_case > Output/run_one_case.out&

run=2003;
system(['mkdir Output/',int2str(run)]);

for year=1:10
  display([' year=',int2str(year)]);
  display('===========');
  outdir=['/home/eli/WRF_Mauricio/Output/',int2str(run),'/',int2str(year)];
  logfile=[outdir,'/log'];
  system(['mkdir ',outdir]);
  yr=int2str(run+year-1);
  yrp1=int2str(run+year);
  yrp2=int2str(run+year+1);

  % prepare input file for fortran program:
  system(['cp Input/CAM2WRF-',yr,'.input Input/CAM2WRF.input.tmp']);
  system(['cat Input/CAM2WRF.input.tmp | sed "s/\"2004-/\"',yrp1,'-/g" | sed "s/\"2003-/\"',yr,'-/g" > Input/CAM2WRF.input']);
  
  % clean results of previous runs:
  system('cd ~/WRF_Mauricio/Output/; \rm CAM2WRF?.log metgrid.log FILE\:* met_em.* wrfbdy_d01 wrfinput_d01');

  % CAM to intermediate format:
  system('cd ~/WRF_Mauricio/; ifort -c -CB -par_report0 -vec_report0 -I/opt/netcdf-3.6.0-p1/include/ CAM_netcdf_to_WRF_intermediate.f90; ifort CAM_netcdf_to_WRF_intermediate.o -L/opt/netcdf-3.6.0-p1/lib/ -lnetcdf; ./a.out');

  % intermediate to netcdf:
  system('cd ~/WRF_Mauricio/Output/; ./metgrid.exe');

  % final step: produce initial and boundary condition files:
  % note that I copied real.exe and its namelist input file to the Output/ directory:
  system('cd ~/WRF_Mauricio/Output/; ./real.exe');

  % move output files:
  system(['\mv *.log wrfbdy_d01 wrflowinp_d01 wrfinput_d01 ',outdir ...
  ,'; \rm FILE\:*; \rm met_em*']);
end
