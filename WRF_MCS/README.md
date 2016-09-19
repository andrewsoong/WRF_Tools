# WRF_MCS

These scripts are almost the final version for my WRF MCS simulation postprocess.

Multiple bulk microphysics schemes are used in my study, the scripts in each folder is similar:

horizontal.ncl: the horizontal slice of the MCS, including the dBZ, surface temperature variation, total precipitation during target period, houlry precipitation and wind 

ice.ncl: the vertical slice of ice-phase particles (ice, snow and graupel)

warm.ncl: the warm cloud vertical slice (cloud droplet and the rain)

some simple shell scripts are just used to run these ncl scripts 

DSD.ncl: used to extract the parameters relating to the particle size distribution in the MCS

ENERGY.ncl: extract the latent cooling of each scheme

microphysics.ncl: extract the particle mass and number concentration of each scheme

microphysics_profile.ncl: calculate the pertical profile of particles and draw a distribution durve

micro_budget: show the vertical distribution of average and total latent cooling in the squall line

VT.ncl/VT_GH.ncl: the terminal velocity vertical profile

rain_eval: interpolate the simulated rain to the radar post-process grid and compare it with the observation

rain_dsd.ncl: show the rain size distribution of the observation and each scheme

Notice: These scripts are not refined, some code are redundant, if you have enough time, you could refine them. Please note that most of my scripts are not refined and have many repetitions, as I just want to finish the work...But some are actually designed and organzed well. When you use it, please notice this.
