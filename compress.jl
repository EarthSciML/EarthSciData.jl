using NetCDF,ZfpCompression,BSON

"""
    compress_netcdf(oldfile,prec)

Compress the NetCDF file with the desired precision number from the ZfpCompression function
and create a new bson file with the compressed values.

#Arguments
- `oldfile::string`: the name of the file to be compressed.
- `prec::Integer`: the precision number to perform compression.
"""
#Compress function
function compress_netcdf(oldfile, prec)
    comp_list = Dict()
    ds = NetCDF.open(oldfile)
    comp_list[:global_att] = ds.gatts
    comp_list[:variables] = Dict()
    for (varname, var) in NetCDF.open(oldfile).vars
        r = ncread(oldfile,varname)
        comp_list[:variables][varname] = Dict()

        comp_list[:variables][varname][:data] = zfp_compress(r,precision = prec)

        dimens = []
        dimlen = []
        for i in 1:size(ds[varname].dim)[1]
            dimens = push!(dimens,ds[varname].dim[i].name)
            dimlen = push!(dimlen,Int(ds.dim[ds[varname].dim[i].name].dimlen))
        end
        
        comp_list[:variables][varname][:dims] = dimens
        comp_list[:variables][varname][:dimlen] = dimlen
       
        comp_list[:variables][varname][:atts] = ds[varname].atts
        println(keys(comp_list))
    
    end
    #New file name can be different
    bson("precision_" * string(prec)* "_METDOT3D_160702.bson", comp_list)
end



