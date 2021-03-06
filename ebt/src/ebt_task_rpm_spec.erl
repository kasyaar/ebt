%%  Copyright (c) 2012-2013
%%  StrikeAd LLC http://www.strikead.com
%%
%%  All rights reserved.
%%
%%  Redistribution and use in source and binary forms, with or without
%%  modification, are permitted provided that the following conditions are met:
%%
%%      Redistributions of source code must retain the above copyright
%%  notice, this list of conditions and the following disclaimer.
%%      Redistributions in binary form must reproduce the above copyright
%%  notice, this list of conditions and the following disclaimer in the
%%  documentation and/or other materials provided with the distribution.
%%      Neither the name of the StrikeAd LLC nor the names of its
%%  contributors may be used to endorse or promote products derived from
%%  this software without specific prior written permission.
%%
%%  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
%%  IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
%%  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
%%  PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
%%  HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
%%  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
%%  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
%%  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
%%  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
%%  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
%%  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-module(ebt_task_rpm_spec).
-author("volodymyr.kyrychenko@strikead.com").

-compile({parse_transform, ebt__do}).

%% API
-export([perform/3, generate_spec_for_build/4, spec_file_path/2, info_spec_file_path/2]).

perform(Target, Dir, Config) ->
    case ebt_config:find_value(Target, Config, spec) of
        {ok, Spec} ->
            ebt__do([ebt__error_m ||
                Version <- ebt_config:version(Config),
                Template <- prepare_spec(Dir, Config, Spec, Version),
                SpecFile <- info_spec_file_path(Dir, Config),
                ebt__xl_file:write_file(SpecFile, Template)
            ]);
        {error, E} -> io:format("ignore: ~p~n", [E])
    end.


info_spec_file_path(Dir, Config) ->
    ebt__do([ebt__error_m ||
        InfoDir <- ebt_config:info_outdir(Dir, Config),
        return(InfoDir ++ "/rpm.spec")
    ]).

prepare_spec(Dir, Config, Spec, Version) ->
    SpecPath = ebt__xl_string:format("priv/rpmbuild/~s.spec", [ebt_config:value(spec, Config, template, otpapp)]),
    ebt__do([ebt__error_m ||
        SpecTemplate <- ebt__xl_escript:read_file(SpecPath),
        Template <- return(ebt__xl_string:substitute(binary_to_list(SpecTemplate), [
            {'DESCRIPTION', ebt__xl_lists:kvfind(description, Spec, "")}
        ], {$@, $@})),
        RPMSDir <- ebt_config:outdir(rpmbuild, Config, "RPMS"),
        AppName <- ebt_config:appname(Dir),
        Build <- ebt_config:build_number(Config),
        Header <- ebt_rpmlib:spec_header(AppName, Version, Build, ebt__xl_lists:kvfind(header, Spec, []), RPMSDir),
        return(iolist_to_binary([Header, Template]))
    ]).

generate_spec_for_build(Config, SpecTemplatePath, SpecName, BuildDir) ->
    ebt__do([ebt__error_m ||
        RPMBuildDir <- ebt_config:outdir(rpmbuild, Config),
        SpecTemplate <- ebt__xl_file:read_file(SpecTemplatePath),
        SpecFile <- spec_file_path(Config, SpecName),
        ebt__xl_file:write_file(SpecFile, iolist_to_binary([
            "#Spec generated by Erlang Build Tool\n\n",
            "%define _topdir " ++ RPMBuildDir ++ "\n",
            "%define _builddir " ++ BuildDir ++ "\n",
            SpecTemplate
        ]))
    ]).

spec_file_path(Config, SpecName) ->
    ebt__do([ebt__error_m ||
        SpecsDir <- ebt_config:outdir(rpmbuild, Config, "SPECS"),
        return(SpecsDir ++ "/" ++ SpecName ++ ".spec")
    ]).

