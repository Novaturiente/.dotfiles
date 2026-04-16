# Print an optspec for argparse to handle cmd's options that are independent of any subcommand.
function __fish_novarch_global_optspecs
	string join \n dry-run v/verbose q/quiet h/help V/version
end

function __fish_novarch_needs_command
	# Figure out if the current invocation already has a command.
	set -l cmd (commandline -opc)
	set -e cmd[1]
	argparse -s (__fish_novarch_global_optspecs) -- $cmd 2>/dev/null
	or return
	if set -q argv[1]
		# Also print the command, so this can be used to figure out what it is.
		echo $argv[1]
		return 1
	end
	return 0
end

function __fish_novarch_using_subcommand
	set -l cmd (__fish_novarch_needs_command)
	test -z "$cmd"
	and return 1
	contains -- $cmd[1] $argv
end

complete -c novarch -n "__fish_novarch_needs_command" -l dry-run -d 'Show what would be done without making changes'
complete -c novarch -n "__fish_novarch_needs_command" -s v -l verbose -d 'Increase output detail'
complete -c novarch -n "__fish_novarch_needs_command" -s q -l quiet -d 'Suppress non-error output'
complete -c novarch -n "__fish_novarch_needs_command" -s h -l help -d 'Print help (see more with \'--help\')'
complete -c novarch -n "__fish_novarch_needs_command" -s V -l version -d 'Print version'
complete -c novarch -n "__fish_novarch_needs_command" -f -a "init" -d 'First-time setup: configure packages folder, AUR helper, and system repos'
complete -c novarch -n "__fish_novarch_needs_command" -f -a "install" -d 'Sync packages: install declared packages, remove undeclared ones'
complete -c novarch -n "__fish_novarch_needs_command" -f -a "update" -d 'Update system: refresh mirrors, upgrade packages, sync, clean orphans'
complete -c novarch -n "__fish_novarch_needs_command" -f -a "info" -d 'Show current configuration and package counts'
complete -c novarch -n "__fish_novarch_needs_command" -f -a "add" -d 'Install and track new packages'
complete -c novarch -n "__fish_novarch_needs_command" -f -a "remove" -d 'Uninstall and untrack packages'
complete -c novarch -n "__fish_novarch_needs_command" -f -a "search" -d 'Search for packages in repositories with YAML cross-reference'
complete -c novarch -n "__fish_novarch_needs_command" -f -a "diff" -d 'Preview what would be installed or removed (no changes made)'
complete -c novarch -n "__fish_novarch_needs_command" -f -a "list" -d 'List all declared packages grouped by YAML file'
complete -c novarch -n "__fish_novarch_needs_command" -f -a "which" -d 'Find which YAML file(s) contain a package'
complete -c novarch -n "__fish_novarch_needs_command" -f -a "export" -d 'Export currently installed packages to YAML files'
complete -c novarch -n "__fish_novarch_needs_command" -f -a "completions" -d 'Generate shell completions'
complete -c novarch -n "__fish_novarch_needs_command" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
complete -c novarch -n "__fish_novarch_using_subcommand init" -l dry-run -d 'Show what would be done without making changes'
complete -c novarch -n "__fish_novarch_using_subcommand init" -s v -l verbose -d 'Increase output detail'
complete -c novarch -n "__fish_novarch_using_subcommand init" -s q -l quiet -d 'Suppress non-error output'
complete -c novarch -n "__fish_novarch_using_subcommand init" -s h -l help -d 'Print help'
complete -c novarch -n "__fish_novarch_using_subcommand install" -l dry-run -d 'Show what would be done without making changes'
complete -c novarch -n "__fish_novarch_using_subcommand install" -s v -l verbose -d 'Increase output detail'
complete -c novarch -n "__fish_novarch_using_subcommand install" -s q -l quiet -d 'Suppress non-error output'
complete -c novarch -n "__fish_novarch_using_subcommand install" -s h -l help -d 'Print help'
complete -c novarch -n "__fish_novarch_using_subcommand update" -l dry-run -d 'Show what would be done without making changes'
complete -c novarch -n "__fish_novarch_using_subcommand update" -s v -l verbose -d 'Increase output detail'
complete -c novarch -n "__fish_novarch_using_subcommand update" -s q -l quiet -d 'Suppress non-error output'
complete -c novarch -n "__fish_novarch_using_subcommand update" -s h -l help -d 'Print help'
complete -c novarch -n "__fish_novarch_using_subcommand info" -l dry-run -d 'Show what would be done without making changes'
complete -c novarch -n "__fish_novarch_using_subcommand info" -s v -l verbose -d 'Increase output detail'
complete -c novarch -n "__fish_novarch_using_subcommand info" -s q -l quiet -d 'Suppress non-error output'
complete -c novarch -n "__fish_novarch_using_subcommand info" -s h -l help -d 'Print help'
complete -c novarch -n "__fish_novarch_using_subcommand add" -s t -l to -d 'Target YAML file (e.g., development.yaml). Defaults to manual-install.yaml' -r
complete -c novarch -n "__fish_novarch_using_subcommand add" -l dry-run -d 'Show what would be done without making changes'
complete -c novarch -n "__fish_novarch_using_subcommand add" -s v -l verbose -d 'Increase output detail'
complete -c novarch -n "__fish_novarch_using_subcommand add" -s q -l quiet -d 'Suppress non-error output'
complete -c novarch -n "__fish_novarch_using_subcommand add" -s h -l help -d 'Print help'
complete -c novarch -n "__fish_novarch_using_subcommand remove" -l dry-run -d 'Show what would be done without making changes'
complete -c novarch -n "__fish_novarch_using_subcommand remove" -s v -l verbose -d 'Increase output detail'
complete -c novarch -n "__fish_novarch_using_subcommand remove" -s q -l quiet -d 'Suppress non-error output'
complete -c novarch -n "__fish_novarch_using_subcommand remove" -s h -l help -d 'Print help'
complete -c novarch -n "__fish_novarch_using_subcommand search" -l dry-run -d 'Show what would be done without making changes'
complete -c novarch -n "__fish_novarch_using_subcommand search" -s v -l verbose -d 'Increase output detail'
complete -c novarch -n "__fish_novarch_using_subcommand search" -s q -l quiet -d 'Suppress non-error output'
complete -c novarch -n "__fish_novarch_using_subcommand search" -s h -l help -d 'Print help'
complete -c novarch -n "__fish_novarch_using_subcommand diff" -l dry-run -d 'Show what would be done without making changes'
complete -c novarch -n "__fish_novarch_using_subcommand diff" -s v -l verbose -d 'Increase output detail'
complete -c novarch -n "__fish_novarch_using_subcommand diff" -s q -l quiet -d 'Suppress non-error output'
complete -c novarch -n "__fish_novarch_using_subcommand diff" -s h -l help -d 'Print help'
complete -c novarch -n "__fish_novarch_using_subcommand list" -l dry-run -d 'Show what would be done without making changes'
complete -c novarch -n "__fish_novarch_using_subcommand list" -s v -l verbose -d 'Increase output detail'
complete -c novarch -n "__fish_novarch_using_subcommand list" -s q -l quiet -d 'Suppress non-error output'
complete -c novarch -n "__fish_novarch_using_subcommand list" -s h -l help -d 'Print help'
complete -c novarch -n "__fish_novarch_using_subcommand which" -l dry-run -d 'Show what would be done without making changes'
complete -c novarch -n "__fish_novarch_using_subcommand which" -s v -l verbose -d 'Increase output detail'
complete -c novarch -n "__fish_novarch_using_subcommand which" -s q -l quiet -d 'Suppress non-error output'
complete -c novarch -n "__fish_novarch_using_subcommand which" -s h -l help -d 'Print help'
complete -c novarch -n "__fish_novarch_using_subcommand export" -s o -l output -d 'Output directory for generated YAML files (default: current directory)' -r
complete -c novarch -n "__fish_novarch_using_subcommand export" -l dry-run -d 'Show what would be done without making changes'
complete -c novarch -n "__fish_novarch_using_subcommand export" -s v -l verbose -d 'Increase output detail'
complete -c novarch -n "__fish_novarch_using_subcommand export" -s q -l quiet -d 'Suppress non-error output'
complete -c novarch -n "__fish_novarch_using_subcommand export" -s h -l help -d 'Print help'
complete -c novarch -n "__fish_novarch_using_subcommand completions" -l install -d 'Install completions to the appropriate system directory'
complete -c novarch -n "__fish_novarch_using_subcommand completions" -l dry-run -d 'Show what would be done without making changes'
complete -c novarch -n "__fish_novarch_using_subcommand completions" -s v -l verbose -d 'Increase output detail'
complete -c novarch -n "__fish_novarch_using_subcommand completions" -s q -l quiet -d 'Suppress non-error output'
complete -c novarch -n "__fish_novarch_using_subcommand completions" -s h -l help -d 'Print help'
complete -c novarch -n "__fish_novarch_using_subcommand help; and not __fish_seen_subcommand_from init install update info add remove search diff list which export completions help" -f -a "init" -d 'First-time setup: configure packages folder, AUR helper, and system repos'
complete -c novarch -n "__fish_novarch_using_subcommand help; and not __fish_seen_subcommand_from init install update info add remove search diff list which export completions help" -f -a "install" -d 'Sync packages: install declared packages, remove undeclared ones'
complete -c novarch -n "__fish_novarch_using_subcommand help; and not __fish_seen_subcommand_from init install update info add remove search diff list which export completions help" -f -a "update" -d 'Update system: refresh mirrors, upgrade packages, sync, clean orphans'
complete -c novarch -n "__fish_novarch_using_subcommand help; and not __fish_seen_subcommand_from init install update info add remove search diff list which export completions help" -f -a "info" -d 'Show current configuration and package counts'
complete -c novarch -n "__fish_novarch_using_subcommand help; and not __fish_seen_subcommand_from init install update info add remove search diff list which export completions help" -f -a "add" -d 'Install and track new packages'
complete -c novarch -n "__fish_novarch_using_subcommand help; and not __fish_seen_subcommand_from init install update info add remove search diff list which export completions help" -f -a "remove" -d 'Uninstall and untrack packages'
complete -c novarch -n "__fish_novarch_using_subcommand help; and not __fish_seen_subcommand_from init install update info add remove search diff list which export completions help" -f -a "search" -d 'Search for packages in repositories with YAML cross-reference'
complete -c novarch -n "__fish_novarch_using_subcommand help; and not __fish_seen_subcommand_from init install update info add remove search diff list which export completions help" -f -a "diff" -d 'Preview what would be installed or removed (no changes made)'
complete -c novarch -n "__fish_novarch_using_subcommand help; and not __fish_seen_subcommand_from init install update info add remove search diff list which export completions help" -f -a "list" -d 'List all declared packages grouped by YAML file'
complete -c novarch -n "__fish_novarch_using_subcommand help; and not __fish_seen_subcommand_from init install update info add remove search diff list which export completions help" -f -a "which" -d 'Find which YAML file(s) contain a package'
complete -c novarch -n "__fish_novarch_using_subcommand help; and not __fish_seen_subcommand_from init install update info add remove search diff list which export completions help" -f -a "export" -d 'Export currently installed packages to YAML files'
complete -c novarch -n "__fish_novarch_using_subcommand help; and not __fish_seen_subcommand_from init install update info add remove search diff list which export completions help" -f -a "completions" -d 'Generate shell completions'
complete -c novarch -n "__fish_novarch_using_subcommand help; and not __fish_seen_subcommand_from init install update info add remove search diff list which export completions help" -f -a "help" -d 'Print this message or the help of the given subcommand(s)'
