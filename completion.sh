_linode ()
{
    local OBJECTS='linode account domain nodebalancer stackscript'
    local LINODE_ACTIONS='create start stop restart rename rebuild ip-add group resize delete list show locations distros plans disk-list image-list image-create image-update image-delete'
    local ACCOUNT_ACTIONS='show'
    local DOMAIN_ACTIONS='create update delete list show record-create record-update record-delete record-list record-show'
    local NODEBALANCER_ACTIONS='create rename throttle delete list show config-create config-update config-delete config-list config-show node-create node-update node-delete node-list node-show'
    local STACKSCRIPT_ACTIONS='create update delete list show source'
    local cur
    local prev

    COMPREPLY=()
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD-1]}

    case "${prev}" in
        linode)
            if [[ COMP_CWORD-1 -eq 0 ]]; then
                COMPREPLY=( $( compgen -W "$OBJECTS $LINODE_ACTIONS" -- $cur ) )
            else
                COMPREPLY=( $( compgen -W "$LINODE_ACTIONS" -- $cur ) )
            fi
            ;;
        account)
            COMPREPLY=( $( compgen -W "$ACCOUNT_ACTIONS" -- $cur ) )
            ;;
        domain)
            COMPREPLY=( $( compgen -W "$DOMAIN_ACTIONS" -- $cur ) )
            ;;
        nodebalancer)
            COMPREPLY=( $( compgen -W "$NODEBALANCER_ACTIONS" -- $cur ) )
            ;;
        stackscript)
            COMPREPLY=( $( compgen -W "$STACKSCRIPT_ACTIONS" -- $cur ) )
            ;;
        *)
            COMPREPLY=( $( compgen -W "$OBJECTS" -- $cur ) )
            ;;
    esac
}

if [[ "$SHELL" == *"zsh"* ]]
then
    autoload -U +X compinit && compinit
    autoload -U +X bashcompinit && bashcompinit
fi

complete -F _linode -o display linode
