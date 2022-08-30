#Extracting wind data from MET file 
download("https://earthsciml.s3.amazonaws.com/compressed_Input/met/mcipv5/METDOT3D_160701.bson")

#Change the name after downloading the file from AWS. 
#The directories will vary by users. The exmaple is shown below. 
file = "/var/folders/s3/d0ks9vxn08dclbqqy0q3tgzw0000gn/T/jl_MRWMZx"
mv(file, "METDOT3D_160701.bson")

#Use decompress.jl
include("decompress.jl")

#Use decompress_netcdf and the change .bson file to .nc
decompress_netcdf(comp_file,output)


#Extracting emission data from emis file 
download("https://earthsciml.s3.amazonaws.com/compressed_Input/emis/gridded_area/gridded/emis_mole_all_20160701_cb6_bench.bson")

#Change the name after downloading the file from AWS. 
#The directories will vary by users. The exmaple is shown below. 
file = "/var/folders/s3/d0ks9vxn08dclbqqy0q3tgzw0000gn/T/jl_MRWMZx"
mv(file, "emis_mole_all_20160701_cb6_bench.bson")

#Use decompress_netcdf and the change .bson file to .nc
decompress_netcdf(comp_file,output)



