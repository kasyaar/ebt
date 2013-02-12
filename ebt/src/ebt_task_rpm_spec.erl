%% Copyright
-module(ebt_task_rpm_spec).
-author("volodymyr.kyrychenko@strikead.com").

-compile({parse_transform, do}).

%% API
-export([perform/3, generate_spec_for_build/4, spec_file_path/2, info_spec_file_path/2]).

perform(Target, Dir, Config) ->
    case ebt_config:find_value(Target, Config, spec) of
        {ok, Spec} ->
            do([error_m ||
                Version <- ebt_config:version(Config),
                Template <- prepare_spec(Dir, Config, Spec, Version),
                SpecFile <- info_spec_file_path(Dir, Config),
                ebt_xl_file:write_file(SpecFile, Template)
            ]);
        {error, E} -> io:format("ignore: ~p~n", [E])
    end.


info_spec_file_path(Dir, Config) ->
    do([error_m ||
        InfoDir <- ebt_config:info_outdir(Dir, Config),
        return(InfoDir ++ "/rpm.spec")
    ]).

prepare_spec(Dir, Config, Spec, Version) ->
    SpecPath = ebt_xl_string:format("priv/rpmbuild/~s.spec", [ebt_config:value(spec, Config, template, otpapp)]),
    do([error_m ||
        SpecTemplate <- ebt_xl_escript:read_file(SpecPath),
        Template <- return(ebt_xl_string:substitute(binary_to_list(SpecTemplate), [
            {'DESCRIPTION', ebt_xl_lists:kvfind(description, Spec, "")}
        ], {$@, $@})),
        RPMSDir <- ebt_config:outdir(rpmbuild, Config, "RPMS"),
        AppName <- ebt_config:appname(Dir),
        Build <- ebt_config:build_number(Config),
        Header <- ebt_rpmlib:spec_header(AppName, Version, Build, ebt_xl_lists:kvfind(header, Spec, []), RPMSDir),
        return(iolist_to_binary([Header, Template]))
    ]).

generate_spec_for_build(Config, SpecTemplatePath, SpecName, BuildDir) ->
    do([error_m ||
        RPMBuildDir <- ebt_config:outdir(rpmbuild, Config),
        SpecTemplate <- ebt_xl_file:read_file(SpecTemplatePath),
        SpecFile <- spec_file_path(Config, SpecName),
        ebt_xl_file:write_file(SpecFile, iolist_to_binary([
            "#Spec generated by Erlang Build Tool\n\n",
            "%define _topdir " ++ RPMBuildDir ++ "\n",
            "%define _builddir " ++ BuildDir ++ "\n",
            SpecTemplate
        ]))
    ]).

spec_file_path(Config, SpecName) ->
    do([error_m ||
        SpecsDir <- ebt_config:outdir(rpmbuild, Config, "SPECS"),
        return(SpecsDir ++ "/" ++ SpecName ++ ".spec")
    ]).

