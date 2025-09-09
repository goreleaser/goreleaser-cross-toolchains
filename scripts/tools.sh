#!/usr/bin/env bash

set -e

# in akash even minor part of the tag indicates release belongs to the MAINNET
# using it as scripts simplifies debugging as well as portability
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

SEMVER="${SCRIPT_DIR}/semver.sh"

short_opts=h
long_opts=help/latest   # those who take an arg END with :

latest=false

while getopts ":$short_opts-:" o; do
    case $o in
        :)
            echo >&2 "option -$OPTARG needs an argument"
            continue
            ;;
        '?')
            echo >&2 "bad option -$OPTARG"
            continue
            ;;
        -)
            o=${OPTARG%%=*}
            OPTARG=${OPTARG#"$o"}
            lo=/$long_opts/
            case $lo in
                *"/$o"[!/:]*"/$o"[!/:]*)
                    echo >&2 "ambiguous option --$o"
                    continue
                    ;;
                *"/$o"[:/]*)
                    ;;
                *)
                    o=$o${lo#*"/$o"};
                    o=${o%%[/:]*}
                    ;;
            esac

            case $lo in
                *"/$o/"*)
                    OPTARG=
                    ;;
                *"/$o:/"*)
                    case $OPTARG in
                        '='*)
                            OPTARG=${OPTARG#=}
                            ;;
                        *)
                            eval "OPTARG=\$$OPTIND"
                            if [ "$OPTIND" -le "$#" ] && [ "$OPTARG" != -- ]; then
                                OPTIND=$((OPTIND + 1))
                            else
                                echo >&2 "option --$o needs an argument"
                                continue
                            fi
                            ;;
                    esac
                    ;;
            *) echo >&2 "unknown option --$o"; continue;;
            esac
    esac
    case "$o" in
        latest)
            latest=true
            ;;
    esac
done
shift "$((OPTIND - 1))"

function is_prerelease {
	if [[ $# -ne 1 ]]; then
		echo "illegal number of parameters"
		exit 1
	fi

	[[ -n $($SEMVER get prerel "$1") ]] && echo -n true || echo -n false
}

function generate_tags {
	local pkg="goreleaser/$1"
	local tag=$2
	local tag_minor
	local registries

	# shellcheck disable=SC2206
	registries=($3)
	tag_minor=v$("$SEMVER" get major "$tag").$("$SEMVER" get minor "$tag")

	local images

	for registry in "${registries[@]}"; do
		image=$pkg
		if [[ "$registry" != "docker.io" ]]; then
			image=$registry/$image
		fi

		if [[ $(is_prerelease "$tag") == true ]]; then
			images="$image:$tag"
		else
			images="$image:$tag_minor"
			images+=$'\n'"$image:$tag"
			if [[ $latest == true ]]; then
				images+=$'\n'"$image:latest"
			fi
		fi
	done

	echo "$images"

	exit 0
}

function generate() {
	case $1 in
		tags)
			shift
			case $1 in
				cross-toolchains)
					name=$1
					shift
					generate_tags "goreleaser-$name" "$1" "$2"
					;;
			esac
			;;
	esac
}

case $1 in
	generate)
		shift
		generate "$@"
		;;
esac

