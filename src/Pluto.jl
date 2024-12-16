"""
Start a notebook server using:

```julia
julia> Pluto.run()
```

Have a look at the FAQ:
https://github.com/fonsp/Pluto.jl/wiki
"""
module Pluto

if isdefined(Base, :Experimental) && isdefined(Base.Experimental, Symbol("@max_methods"))
    @eval Base.Experimental.@max_methods 1
end

import FuzzyCompletions
import RelocatableFolders: @path
const ROOT_DIR = normpath(joinpath(@__DIR__, ".."))
const FRONTEND_DIR = @path(joinpath(ROOT_DIR, "frontend"))
const FRONTEND_DIST_DIR = let dir = joinpath(ROOT_DIR, "frontend-dist")
    isdir(dir) ? @path(dir) : FRONTEND_DIR
end
const frontend_dist_exists = FRONTEND_DIR !== FRONTEND_DIST_DIR
const SAMPLE_DIR = @path(joinpath(ROOT_DIR, "sample"))
const RUNNER_DIR = @path(joinpath(ROOT_DIR, "src", "runner"))
function project_relative_path(root, xs...)
    root == joinpath("src", "runner") ? joinpath(RUNNER_DIR, xs...) :
    root == "frontend-dist" && frontend_dist_exists ? joinpath(FRONTEND_DIST_DIR, xs...) :
    root == "frontend" ? joinpath(FRONTEND_DIR, xs...) :
    root == "sample" ? joinpath(SAMPLE_DIR, xs...) :
        normpath(joinpath(pkgdir(Pluto), root, xs...))
end

import Pkg
import Scratch

include_dependency("../Project.toml")
const PLUTO_VERSION = VersionNumber(Pkg.TOML.parsefile(joinpath(ROOT_DIR, "Project.toml"))["version"])
const PLUTO_VERSION_STR = "v$(string(PLUTO_VERSION))"
const JULIA_VERSION_STR = "v$(string(VERSION))"

import PlutoDependencyExplorer: PlutoDependencyExplorer, TopologicalOrder, NotebookTopology, ExprAnalysisCache, ImmutableVector, ExpressionExplorerExtras, topological_order, all_cells, disjoint, where_assigned, where_referenced
using ExpressionExplorer

include("./notebook/path helpers.jl")
include("./notebook/Export.jl")
include("./Configuration.jl")

include("./evaluation/Tokens.jl")
include("./evaluation/Throttled.jl")
include("./runner/PlutoRunner/src/PlutoRunner.jl")
include("./packages/PkgCompat.jl")
include("./webserver/Status.jl")

include("./notebook/Cell.jl")
include("./notebook/Notebook.jl")
include("./notebook/saving and loading.jl")
include("./notebook/frontmatter.jl")
include("./notebook/Events.jl")
include("./webserver/Session.jl")
include("./webserver/PutUpdates.jl")

include("./analysis/Parse.jl")
include("./analysis/is_just_text.jl")
include("./analysis/DependencyCache.jl")
include("./analysis/MoreAnalysis.jl")

include("./evaluation/WorkspaceManager.jl")
include("./evaluation/MacroAnalysis.jl")
include("./packages/IOListener.jl")
include("./packages/precompile_isolated.jl")
include("./packages/Packages.jl")
include("./packages/PkgUtils.jl")
include("./evaluation/Run.jl")
include("./evaluation/RunBonds.jl")

module DownloadCool include("./webserver/data_url.jl") end
include("./webserver/MsgPack.jl")
include("./webserver/SessionActions.jl")
include("./webserver/Static.jl")
include("./webserver/Authentication.jl")
include("./webserver/Router.jl")
include("./webserver/Dynamic.jl")
include("./webserver/REPLTools.jl")
include("./webserver/WebServer.jl")

const reset_notebook_environment = PkgUtils.reset_notebook_environment
const update_notebook_environment = PkgUtils.update_notebook_environment
const activate_notebook_environment = PkgUtils.activate_notebook_environment
const will_use_pluto_pkg = PkgUtils.will_use_pluto_pkg
export reset_notebook_environment
export update_notebook_environment
export activate_notebook_environment
export will_use_pluto_pkg

include("./precompile.jl")

const pluto_boot_environment_path = Ref{String}()

function warn_julia_compat()
    if VERSION > v"1.11.9999"
        @warn("\nPluto ($(PLUTO_VERSION)) is running on a new version of Julia ($(VERSION)).\n\n$(
            # if using a regular Julia version, then that means that the new Julia version has been released and we released a new Pluto version that supports it, but the user is still using an old Pluto version.
            VERSION.prerelease === () && VERSION.build === () ?
            "You need to update Pluto to use this Julia version, see https://plutojl.org/en/docs/update/ to learn more." :
            # if using a build/prerelease, then the user is using a future Julia version that we don't support yet.
            "This (preview) version of Julia might not be fully supported by Pluto yet. Please check back later or use an older version of Julia."
        )")
    end
    
    bad_depots = filter(d -> !isabspath(expanduser(d)), DEPOT_PATH)
    if !isempty(bad_depots)
        @error """Pluto: The provided depot path is not an absolute path. Pluto will not be able to run correctly.
        
        Did you recently change the DEPOT path setting? Change your setting to use an absolute path.
        
        Do you not know what this means? Please get in touch! https://github.com/fonsp/Pluto.jl/issues
        """ bad_depots DEPOT_PATH
    end
end

function __init__()
    pluto_boot_environment_name = "pluto-boot-environment-$(VERSION)-$(PLUTO_VERSION)"
    pluto_boot_environment_path[] = Scratch.@get_scratch!(pluto_boot_environment_name)

    # Print a welcome banner
    if (get(ENV, "JULIA_PLUTO_SHOW_BANNER", "1") != "0" &&
        get(ENV, "CI", "🍄") != "true" && isinteractive())
        # Print the banner only once per version, if there isn't
        # yet a file for this version in banner_shown scratch space.
        # (Using the Pluto version as the filename enables later
        # version-specific "what's new" messages.)
        fn = joinpath(Scratch.@get_scratch!("banner_shown"), PLUTO_VERSION_STR)
        if !isfile(fn)
            @info """

              Welcome to Pluto $(PLUTO_VERSION_STR) 🎈
              Start a notebook server using:

            julia> Pluto.run()

              Have a look at the FAQ:
              https://github.com/fonsp/Pluto.jl/wiki

            """
            # create empty file to indicate that we've shown the banner
            write(fn, "");
        end
    end
    
    warn_julia_compat()
end

end
