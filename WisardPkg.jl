module WisardPkg
using StatsBase, Serialization, Images,Plots

struct Wisard
    input_size::Vector{Int}
    tuple_size::Int
    bleaching::Bool
    arch
    

    Wisard(isize::Vector{Int}, tsize::Int, classes::Vector, bleaching = false) = begin
        d = Dict(
            class => Dict{Vector{Int}, Dict{Vector{Bool}, Int}}(
                    tuple => Dict{Vector{Bool}, Int}() 
                    for tuple in generatearchtecture(isize[1]*isize[2], tsize)
                )
            for class in classes
        )
    
        new(isize, tsize, bleaching, d)
    end
end

struct Thermometer
   bins::Int
   min::Real
   max::Real
   
   delta::Real
   
   Thermometer(bins::Int, min::Real, max::Real) = new(bins, min, max, (max-min)/bins)
end

function encode(model::Thermometer, sample::Number)
    alpha = div((sample-model.min),model.delta)
    return [ x<= alpha ? 1 : 0 for x in 1:model.bins]
end

function encode(model::Thermometer, input_data::Vector)
    output = []
    for sample in input_data
        push!(output, encode(model,sample))
    end
    return output
end


function fit(model::Wisard, input_data::Vector, output_data::Vector)
    for (sample, output) in zip(input_data, output_data)
        tuples = collect(keys(model.arch[output]))
        for tuple in tuples
            vals = getindex(flatten(sample), tuple)
            if haskey(model.arch[output][tuple], vals)
                model.arch[output][tuple][vals] += 1
            else
                model.arch[output][tuple][vals] = 1
            end
        end
    end
end



function predict(model::Wisard, input_data::Vector)
    output = []
    classes = collect(keys(model.arch))
    csize = length(classes)
    isize = model.input_size[1] * model.input_size[2]
    n_rams = div(isize, model.tuple_size) + 1

    for sample in input_data
        score = zeros(csize)
        lim = 1

        if model.bleaching
            while true
                for (idx, class) in enumerate(classes)
                    tuples = collect(keys(model.arch[class]))
                    for tuple in tuples
                        vals = getindex(flatten(sample), tuple)
                        if haskey(model.arch[class][tuple], vals)
                            if model.arch[class][tuple][vals] >= lim
                                score[idx] +=1
                            end
                        end
                    end
                end
                
                (max_val, max_idx) = findmax(score)
                if (sum([x >= max_val for x in score]) == 1) | (sum([x > 0 for x in score]) == 0) 
                    # print(max_val, "\n")
                    push!(output, classes[max_idx])
                    break
                else
                    lim += 1
                end
            end
        else
            for (idx, class) in enumerate(classes)
                tuples = collect(keys(model.arch[class]))
                for tuple in tuples
                    vals = getindex(flatten(sample), tuple)
                    if haskey(model.arch[class][tuple], vals)
                        score[idx] +=1
                    end
                end
            end
            (max_val, max_idx) = findmax(score)
            push!(output, classes[max_idx])
        end
    end

    return output
end

function score(model::Wisard, input_data::Vector)
    output = []
    classes = collect(keys(model.arch))
    csize = length(classes)
    for sample in input_data
        score = zeros(csize)
        for (idx, class) in enumerate(classes)
            tuples = collect(keys(model.arch[class]))
            for tuple in tuples
                vals = getindex(flatten(sample), tuple)
                if haskey(model.arch[class][tuple], vals)
                    score[idx] +=1
                end
            end
        end
        max = maximum(score)
        push!(output, max)
    end

    return output
end

function store(model::Wisard, filename::String)
    open(filename, "w") do io
        serialize(io, model)
    end;
end

function use(filename::String)
    return deserialize(filename)
end

function tomatrix(data::Vector)
    return permutedims(hcat(data...))
end

function generatearchtecture(isize::Int, tsize::Int)
    a = collect(1:isize)
    b = []
    c = []
    while length(a)>0
        r = 1:length(a)
        i = sample(r)
        push!(b, a[i])
        deleteat!(a, i)

        if length(b) == tsize
            push!(c, b)
            b = []
        end
    end
    if length(b) > 0
        push!(c, b)
    end

    return c
end

function getmentalimages(model::Wisard)
    classes = collect(keys(model.arch))
    max = 0
    imgs = Dict()
    for class in classes
        output = zeros(Int, model.input_size[1] * model.input_size[2])
        tuples = collect(keys(model.arch[class]))

        for tuple in tuples
            vals = model.arch[class][tuple]
            rams = collect(keys(vals))
            a = zeros(length(tuple))
            for ram in rams
                a += ram*vals[ram]
            end
            
            for (idx, val) in zip(tuple, a)
                output[idx] =  output[idx] + val
            end
        end
        max = maximum(output)


        imgs[class] = WisardPkg.inflate(model.input_size, output)/max
    end
    return imgs
end

function plot(data::Matrix, palette = :grays)
    return heatmap(data, c = palette)
end

function flatten(input::Matrix)
    return collect(Iterators.flatten(input))
end

function inflate(shape::Vector{Int}, data::Vector{Int})
    return reshape(data, shape...)
end
end # module


# T = [
#   [1, 1, 1],
#   [0, 1, 0],
#   [0, 1, 0]
# ]

# H = [
#   [1, 0, 1],
#   [1, 1, 1],
#   [1, 0, 1]
# ]


# model = Wisard(9,3, ["H","T"])
# input = [flatten(H), flatten(T)]
# output = ["H","T"]

# fit(model, input, output)
# prediction = predict(model, input)

# print(H,"\n\n", model,"\n\n")
# print(output, prediction)



