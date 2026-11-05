# COROBS is pure: no runtime dependency, so no database, network or LLM client can be reached from it.
@testset "Purity" begin
    root = joinpath(@__DIR__, "..")

    @testset "Project.toml has no [deps]" begin
        lines = readlines(joinpath(root, "Project.toml"))
        start = findfirst(l -> strip(l) == "[deps]", lines)
        if start !== nothing
            stop = something(findnext(l -> startswith(strip(l), "["), lines, start + 1), length(lines) + 1)
            entries = filter(l -> !isempty(strip(l)) && !startswith(strip(l), "#"), lines[start+1:stop-1])
            @test isempty(entries)
        end
    end

    @testset "src loads nothing outside Base and its own submodules" begin
        for file in readdir(joinpath(root, "src"); join = true)
            endswith(file, ".jl") || continue
            for line in readlines(file)
                m = match(r"^\s*(?:using|import)\s+([^\s:,]+)", line)
                m === nothing && continue
                target = m.captures[1]
                @test startswith(target, ".") || target == "Base"
            end
        end
    end
end
