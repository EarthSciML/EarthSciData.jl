using NetCDF
using NCDatasets,ZfpCompression,BSON,Statistics



oldfile = "/Users/Minwoo/Desktop/emis/METDOT3D_160701.nc"

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
    bson("precision_" * string(prec)* "_METDOT3D_160701.bson", comp_list)
end

compress_netcdf(oldfile,100)
compress_netcdf(oldfile,10)




