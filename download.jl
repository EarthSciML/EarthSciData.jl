#Extracting wind data from MET file 
download("https://earthsciml.s3.amazonaws.com/compressed_Input/met/mcipv5/METDOT3D_160701.bson")

#Change the name after downloading the file from AWS. 
#The directories will vary by users 

file = "/var/folders/s3/d0ks9vxn08dclbqqy0q3tgzw0000gn/T/jl_MRWMZx"
mv(file, "METDOT3D_160701.bson")

#Use decompress_netcdf and the change .bson file to .nc
#The function is defined below
#The directories will vary by users 
comp_file = "/Users/Minwoo/Desktop/METDOT3D_160701.bson"
output = "/Users/Minwoo/Desktop/METDOT3D_160701.nc"

#Running a function
decompress_netcdf(comp_file,output)



#Extracting emission data from emis file 
download("https://earthsciml.s3.amazonaws.com/compressed_Input/emis/gridded_area/gridded/emis_mole_all_20160701_cb6_bench.bson")

#Change the name after downloading the file from AWS. 
#The directories will vary by users
file = "/var/folders/s3/d0ks9vxn08dclbqqy0q3tgzw0000gn/T/jl_MRWMZx"
mv(file, "emis_mole_all_20160701_cb6_bench.bson")

#Use decompress_netcdf and the change .bson file to .nc
#The function is defined below
#The directories will vary by users 
comp_file = "/Users/Minwoo/Desktop/emis_mole_all_20160701_cb6_bench.bson"
output = "/Users/Minwoo/Desktop/emis_mole_all_20160701_cb6_bench.nc"

#Running a function
decompress_netcdf(comp_file,output)



using NetCDF,ZfpCompression,BSON

"""
    decompress_netcdf(oldfile,output)

Decompress the bson file and create a new netcdf file withthe given values and variables.

#Arguments
- `comp_file::string`: the name of the compressed bson file.
- `output::string`: the name of the new NetCDF file.
"""

#Decompression function
function decompress_netcdf(comp_file,output)
    #Gloabla Attributes
    attribs = BSON.load(comp_file)[:global_att]
    nccreate(output, "global", atts=attribs, mode=NC_NETCDF4)

    data = BSON.load(comp_file)
    varname = keys(data[:variables])
    for var in varname
        dims = data[:variables][var][:dims]
        dimlen = data[:variables][var][:dimlen]
        if size(dims)[1] == 3
            vardata = zfp_decompress(data[:variables][var][:data])
            nccreate(output, var, dims[1], dimlen[1], dims[2], dimlen[2], dims[3], dimlen[3], 
                atts=data[:variables][var][:atts],
                t=NC_FLOAT)
        elseif size(dims)[1] == 4
            vardata = zfp_decompress(data[:variables][var][:data])
            nccreate(output, var, dims[1], dimlen[1], dims[2], dimlen[2], dims[3], dimlen[3], dims[4], dimlen[4], 
            atts=data[:variables][var][:atts],
            t=NC_FLOAT)
        end
        ncwrite(vardata,output,var)
    end
end






