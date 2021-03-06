#!/bin/sh
#
# Copyright (c) 2012 Felipe Contreras
#

test_description='test bash completion'

. ./lib-bash.sh

complete ()
{
	# do nothing
	return 0
}

. "$GIT_BUILD_DIR/contrib/completion/git-completion.bash"

# We don't need this function to actually join words or do anything special.
# Also, it's cleaner to avoid touching bash's internal completion variables.
# So let's override it with a minimal version for testing purposes.
_get_comp_words_by_ref ()
{
	while [ $# -gt 0 ]; do
		case "$1" in
		cur)
			cur=${_words[_cword]}
			;;
		prev)
			prev=${_words[_cword-1]}
			;;
		words)
			words=("${_words[@]}")
			;;
		cword)
			cword=$_cword
			;;
		esac
		shift
	done
}

print_comp ()
{
	local IFS=$'\n'
	echo "${COMPREPLY[*]}" > out
}

run_completion ()
{
	local -a COMPREPLY _words
	local _cword
	_words=( $1 )
	(( _cword = ${#_words[@]} - 1 ))
	__git_wrap__git_main && print_comp
}

test_completion ()
{
	test $# -gt 1 && echo "$2" > expected
	run_completion "$@" &&
	test_cmp expected out
}

# Like test_completion, but reads expectation from stdin,
# which is convenient when it is multiline. We also process "_" into
# spaces to make test vectors more readable.
test_completion_long ()
{
	tr _ " " >expected &&
	test_completion "$1"
}

newline=$'\n'

test_expect_success '__gitcomp - trailing space - options' '
	sed -e "s/Z$//" >expected <<-\EOF &&
	--reuse-message=Z
	--reedit-message=Z
	--reset-author Z
	EOF
	(
		local -a COMPREPLY &&
		cur="--re" &&
		__gitcomp "--dry-run --reuse-message= --reedit-message=
				--reset-author" &&
		IFS="$newline" &&
		echo "${COMPREPLY[*]}" > out
	) &&
	test_cmp expected out
'

test_expect_success '__gitcomp - trailing space - config keys' '
	sed -e "s/Z$//" >expected <<-\EOF &&
	branch.Z
	branch.autosetupmerge Z
	branch.autosetuprebase Z
	browser.Z
	EOF
	(
		local -a COMPREPLY &&
		cur="br" &&
		__gitcomp "branch. branch.autosetupmerge
				branch.autosetuprebase browser." &&
		IFS="$newline" &&
		echo "${COMPREPLY[*]}" > out
	) &&
	test_cmp expected out
'

test_expect_success '__gitcomp - option parameter' '
	sed -e "s/Z$//" >expected <<-\EOF &&
	recursive Z
	resolve Z
	EOF
	(
		local -a COMPREPLY &&
		cur="--strategy=re" &&
		__gitcomp "octopus ours recursive resolve subtree
			" "" "re" &&
		IFS="$newline" &&
		echo "${COMPREPLY[*]}" > out
	) &&
	test_cmp expected out
'

test_expect_success '__gitcomp - prefix' '
	sed -e "s/Z$//" >expected <<-\EOF &&
	branch.maint.merge Z
	branch.maint.mergeoptions Z
	EOF
	(
		local -a COMPREPLY &&
		cur="branch.me" &&
		__gitcomp "remote merge mergeoptions rebase
			" "branch.maint." "me" &&
		IFS="$newline" &&
		echo "${COMPREPLY[*]}" > out
	) &&
	test_cmp expected out
'

test_expect_success '__gitcomp - suffix' '
	sed -e "s/Z$//" >expected <<-\EOF &&
	branch.master.Z
	branch.maint.Z
	EOF
	(
		local -a COMPREPLY &&
		cur="branch.me" &&
		__gitcomp "master maint next pu
			" "branch." "ma" "." &&
		IFS="$newline" &&
		echo "${COMPREPLY[*]}" > out
	) &&
	test_cmp expected out
'

test_expect_success 'basic' '
	run_completion "git \"\"" &&
	# built-in
	grep -q "^add \$" out &&
	# script
	grep -q "^filter-branch \$" out &&
	# plumbing
	! grep -q "^ls-files \$" out &&

	run_completion "git f" &&
	! grep -q -v "^f" out
'

test_expect_success 'double dash "git" itself' '
	sed -e "s/Z$//" >expected <<-\EOF &&
	--paginate Z
	--no-pager Z
	--git-dir=
	--bare Z
	--version Z
	--exec-path Z
	--exec-path=
	--html-path Z
	--info-path Z
	--work-tree=
	--namespace=
	--no-replace-objects Z
	--help Z
	EOF
	test_completion "git --"
'

test_expect_success 'double dash "git checkout"' '
	sed -e "s/Z$//" >expected <<-\EOF &&
	--quiet Z
	--ours Z
	--theirs Z
	--track Z
	--no-track Z
	--merge Z
	--conflict=
	--orphan Z
	--patch Z
	EOF
	test_completion "git checkout --"
'

test_expect_success 'general options' '
	test_completion "git --ver" "--version " &&
	test_completion "git --hel" "--help " &&
	sed -e "s/Z$//" >expected <<-\EOF &&
	--exec-path Z
	--exec-path=
	EOF
	test_completion "git --exe" &&
	test_completion "git --htm" "--html-path " &&
	test_completion "git --pag" "--paginate " &&
	test_completion "git --no-p" "--no-pager " &&
	test_completion "git --git" "--git-dir=" &&
	test_completion "git --wor" "--work-tree=" &&
	test_completion "git --nam" "--namespace=" &&
	test_completion "git --bar" "--bare " &&
	test_completion "git --inf" "--info-path " &&
	test_completion "git --no-r" "--no-replace-objects "
'

test_expect_success 'general options plus command' '
	test_completion "git --version check" "checkout " &&
	test_completion "git --paginate check" "checkout " &&
	test_completion "git --git-dir=foo check" "checkout " &&
	test_completion "git --bare check" "checkout " &&
	test_completion "git --help des" "describe " &&
	test_completion "git --exec-path=foo check" "checkout " &&
	test_completion "git --html-path check" "checkout " &&
	test_completion "git --no-pager check" "checkout " &&
	test_completion "git --work-tree=foo check" "checkout " &&
	test_completion "git --namespace=foo check" "checkout " &&
	test_completion "git --paginate check" "checkout " &&
	test_completion "git --info-path check" "checkout " &&
	test_completion "git --no-replace-objects check" "checkout "
'

test_expect_success 'setup for ref completion' '
	echo content >file1 &&
	echo more >file2 &&
	git add . &&
	git commit -m one &&
	git branch mybranch &&
	git tag mytag
'

test_expect_success 'checkout completes ref names' '
	test_completion_long "git checkout m" <<-\EOF
	master_
	mybranch_
	mytag_
	EOF
'

test_expect_success 'show completes all refs' '
	test_completion_long "git show m" <<-\EOF
	master_
	mybranch_
	mytag_
	EOF
'

test_expect_success '<ref>: completes paths' '
	test_completion_long "git show mytag:f" <<-\EOF
	file1_
	file2_
	EOF
'

test_expect_success 'complete tree filename with spaces' '
	echo content >"name with spaces" &&
	git add . &&
	git commit -m spaces &&
	test_completion_long "git show HEAD:nam" <<-\EOF
	name with spaces_
	EOF
'

test_expect_failure 'complete tree filename with metacharacters' '
	echo content >"name with \${meta}" &&
	git add . &&
	git commit -m meta &&
	test_completion_long "git show HEAD:nam" <<-\EOF
	name with ${meta}_
	name with spaces_
	EOF
'

test_expect_success 'send-email' '
	test_completion "git send-email --cov" "--cover-letter " &&
	test_completion "git send-email ma" "master "
'

test_done
