%% Copyright
-module(ebt_task_rpm).
-author("Volodymyr Kyrychenko <vladimirk.kirichenko@gmail.com>").

-compile({parse_transform, do}).

-behaviour(ebt_task).

%% API
-export([perform/3, prepare_environment/1, prepare_spec/5, rpmbuild/2]).

perform(Target, Dir, Config) ->
    do([error_m ||
        prepare_environment(Config),
        Spec <- ebt_config:find_value(Target, Config, spec),
        AppProdDir <- ebt_config:app_outdir(production, Dir, Config),
        AppName <- ebt_config:appname(Dir),
        Version <- ebt_config:version(Config),
        prepare_spec(Config, Spec, AppProdDir, AppName, Version),
        rpmbuild(Config, AppName)
    ]).


prepare_environment(Config) ->
    do([error_m ||
        RPMBuildDir <- ebt_config:outdir(rpmbuild, Config),
        ebt_xl_file:mkdirs(RPMBuildDir ++ "/BUILD"),
        ebt_xl_file:mkdirs(RPMBuildDir ++ "/BUILDROOT"),
        ebt_xl_file:mkdirs(RPMBuildDir ++ "/RPMS"),
        ebt_xl_file:mkdirs(RPMBuildDir ++ "/SOURCES"),
        ebt_xl_file:mkdirs(RPMBuildDir ++ "/SPECS"),
        ebt_xl_file:mkdirs(RPMBuildDir ++ "/SRPMS")
    ]).

prepare_spec(Config, Spec, BuildDir, AppName, Version) ->
    do([error_m ||
        RPMBuildDir <- ebt_config:outdir(rpmbuild, Config),
        SpecTemplate <- ebt_xl_escript:read_file("priv/rpmbuild/otpapp.spec"),
        Template <- return(ebt_xl_string:substitute(binary_to_list(SpecTemplate), [
            {'APPNAME', AppName},
            {'DESCRIPTION', ebt_xl_lists:kvfind(description, Spec, "")}
        ], {$@, $@})),
        Header <- header(Config, Spec, AppName, Version),
        SpecFile <- spec_file(Config, AppName),
        ebt_xl_file:write_file(SpecFile, iolist_to_binary([
            "#Spec generated by Erlang Build Tool\n\n",
            "%define _topdir " ++ RPMBuildDir ++ "\n",
            "%define _builddir " ++ BuildDir ++ "\n",
            Header,
            Template
        ]))
    ]).

spec_file(Config, AppName) ->
    do([error_m ||
        SpecsDir <- ebt_config:outdir(rpmbuild, Config, "SPECS"),
        return(SpecsDir ++ "/" ++ AppName ++ ".spec")
    ]).


header(Config, Spec, AppName, Version) ->
    do([error_m ||
        Build <- ebt_config:build_number(Config),
        RPMSDir <- ebt_config:outdir(rpmbuild, Config, "RPMS"),
        Values <- return([
            {'Name', AppName},
            {'Release', Build ++ "%{?dist}"},
            {'Version', Version} | resolve_requires(ebt_xl_lists:kvfind(header, Spec, []), RPMSDir)
        ]),
        return(ebt_xl_string:join([ebt_xl_string:format("~s: ~s~n", [N, V]) || {N, V} <- Values]))
    ]).

rpmbuild(Config, AppName) ->
    do([error_m ||
        SpecFile <- spec_file(Config, AppName),
        case ebt_xl_shell:command(ebt_xl_string:format("rpmbuild -v -bb ~p", [SpecFile])) of
            {ok, Stdout} ->
                io:format("~s", [Stdout]);
            {error, {_, Stdout}} ->
                io:format("~s", [Stdout]),
                {error, "rpmbuild failed"}

        end
    ]).

resolve_requires(Headers, RPMSDir) when is_list(Headers) ->
    [resolve_requires(H, RPMSDir) || H <- Headers];
resolve_requires(H = {'Requires', Package}, RPMSDir) ->
    case try_detect(ebt_xl_string:format("rpm -q ~s --qf '%{version}-%{release}'", [Package]), Package) of
        {ok, Header} -> Header;
        undefined ->
            case lists:reverse(lists:sort(filelib:wildcard(ebt_xl_string:join([RPMSDir, "/*/", Package, "*"])))) of
                [File | _] ->
                    case try_detect(ebt_xl_string:format("rpm -q -p '~s' --qf '%{version}-%{release}'", [File]), Package) of
                        {ok, Header} -> Header;
                        undefined -> H
                    end;
                _ -> H
            end
    end;
resolve_requires(X, _RRPMDir) -> X.

try_detect(Command, Package) ->
    io:format("detect version: ~s~n", [Command]),
    case ebt_xl_shell:command(Command) of
        {ok, Version} ->
            io:format("detected ~s-~s~n", [Package, Version]),
            {ok, {'Requires', ebt_xl_string:join([Package, "=", Version], " ")}};
        {error, Stdout} ->
            io:format("failed detection ~s: ~s", [Package, Stdout]),
            undefined
    end.
