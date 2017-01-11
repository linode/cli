_linode ()
{
    local OBJECTS='linode account domain nodebalancer stackscript'
    local ACTIONS='create start stop restart rename group resize delete list show'
    local cur
    local prev

    COMPREPLY=()
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD-1]}

    case "${prev}" in
        linode|account|domain|nodebalancer|stackscript)
            if [[ COMP_CWORD-1 -eq 0 ]]; then
                COMPREPLY=( $( compgen -W "$OBJECTS $ACTIONS" -- $cur ) )
            else
                COMPREPLY=( $( compgen -W "$ACTIONS" -- $cur ) )
            fi
            ;;
        *)
            COMPREPLY=( $( compgen -W "$OBJECTS $ACTIONS" -- $cur ) )
            ;;
    esac
}

if [[ "$SHELL" == *"zsh"* ]]
then
    autoload -U +X compinit && compinit
    autoload -U +X bashcompinit && bashcompinit
fi

complete -F _linode -o display linode
