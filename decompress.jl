using NetCDF,ZfpCompression,BSON

"""
    decompress_netcdf(oldfile,output)

Decompress the bson file and create a new netcdf file with the given values and variables.
The function is the reverse of what we do in compress.jl
    
"comp_file" is the path of the compressed .bson file.
"output" is the desired path and name of a new .nc file and is recommended to name after comp_file

retruns : decompressed .nc file in pwd()
"""
function decompress_netcdf(comp_file,output)
    #Gloabal Attributes
    attribs = BSON.load(comp_file)[:global_att]
    nccreate(output, "global", atts=attribs, mode=NC_NETCDF4)

    data = BSON.load(comp_file)
    varname = keys(data[:variables])
    for var in varname
        dims = data[:variables][var][:dims]
        dimlen = data[:variables][var][:dimlen]
        if size(dims)[1] == 1
            vardata = zfp_decompress(data[:variables][var][:data])
            nccreate(output, var, dims[1], dimlen[1], 
                atts=data[:variables][var][:atts],
                t=NC_FLOAT)
        elseif size(dims)[1] == 2
            vardata = zfp_decompress(data[:variables][var][:data])
            nccreate(output, var, dims[1], dimlen[1], dims[2], dimlen[2], 
                atts=data[:variables][var][:atts],
                t=NC_FLOAT)
        elseif size(dims)[1] == 3
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
    return output
end

