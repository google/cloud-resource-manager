#!/usr/bin/env bash
 
shopt -s extglob
 
red=$(tput setaf 1)
green=$(tput setaf 2)
blue=$(tput setaf 4)
reset=$(tput sgr0)
 
function select_option {
    # little helpers for terminal print control and key input
    ESC=$(printf "\033")
    cursor_blink_on() { printf "$ESC[?25h"; }
    cursor_blink_off() { printf "$ESC[?25l"; }
    cursor_to() { printf "$ESC[$1;${2:-1}H"; }
    print_option() { printf "   $1 "; }
    print_selected() { printf "  $ESC[7m $1 $ESC[27m"; }
    get_cursor_row() {
        IFS=';' read -sdR -p $'\E[6n' ROW COL
        echo ${ROW#*[}
    }
    key_input() {
        read -s -n3 key 2>/dev/null >&2
        if [[ $key = $ESC[A ]]; then echo up; fi
        if [[ $key = $ESC[B ]]; then echo down; fi
        if [[ $key = "" ]]; then echo enter; fi
    }
 
    # initially print empty new lines (scroll down if at bottom of screen)
    for opt; do printf "\n"; done
 
    # determine current screen position for overwriting the options
    local lastrow=$(get_cursor_row)
    local startrow=$(($lastrow - $#))
 
    # ensure cursor and input echoing back on upon a ctrl+c during read -s
    trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
    cursor_blink_off
 
    local selected=0
    while true; do
        # print options by overwriting the last lines
        local idx=0
        for opt; do
            cursor_to $(($startrow + $idx))
            if [ $idx -eq $selected ]; then
                print_selected "$opt"
            else
                print_option "$opt"
            fi
            ((idx++))
        done
 
        # user key control
        case $(key_input) in
        enter) break ;;
        up)
            ((selected--))
            if [ $selected -lt 0 ]; then selected=$(($# - 1)); fi
            ;;
        down)
            ((selected++))
            if [ $selected -ge $# ]; then selected=0; fi
            ;;
        esac
    done
 
    # cursor position back to normal
    cursor_to $lastrow
    printf "\n"
    cursor_blink_on
    return $selected
}
ORGANIZATIONS_LIST=$(gcloud organizations list)
ORGANIZATION_ID=$(sed -n -e '/ID/ {s/.*: *//p;q}' <<<"$ORGANIZATIONS_LIST")
CURRENT_ACCOUNT=$(gcloud auth list)
CURRENT_ACCOUNT_EMAIL=$(awk -F'ACCOUNT: ' '{print $2}' <<<"$CURRENT_ACCOUNT")
CURRENT_ACCOUNT_EMAIL="${CURRENT_ACCOUNT_EMAIL//+([[:space:]])/}"
FORMATTED_CURRENT_ACCOUNT_EMAIL="user:$CURRENT_ACCOUNT_EMAIL"
 
IAM_ROLES=$(gcloud organizations get-iam-policy $ORGANIZATION_ID --filter="bindings.members:$CURRENT_ACCOUNT_EMAIL" --flatten="bindings[].members" --format="table(bindings.role)")
IAM_ROLES=$(awk -F'ROLE: ' '{print $2}' <<<"$IAM_ROLES")
REQUIRED_ROLES=("roles/resourcemanager.organizationAdmin" "roles/resourcemanager.folderAdmin" "roles/resourcemanager.projectDeleter" "roles/accesscontextmanager.policyEditor")
 
echo "Welcome. If you are here, then you have been getting the error message 'You have active projects in Google Cloud Platform.' and you are having difficulty proceeding."
echo "This script will help you clear out existing PROJECTS, FOLDERS, and ACCESS CONTEXT MANAGER POLICIES, allowing you to proceed."
sleep 3s
echo " "

readarray -t unique < <(
    comm -23 \
        <(printf '%s\n' "${REQUIRED_ROLES[@]}" | sort) \
        <(printf '%s\n' "${IAM_ROLES[@]}" | sort)
)

echo "First, let's see if you have the necessary IAM permissions to perform the necessary operations..."
sleep 3s
echo " "
 
if [ ! -z "$unique" ]; then
    echo "${reset}Inspecting your current user, it looks like you have the following role(s) assigned:${green} "
    i=1
    for role in $(echo $IAM_ROLES); do
        echo "$i.${green} $role"
        i=$((i + 1))
    done
    echo "${reset}But are missing the following role(s):${red}"
    a=1
    for role in $(echo ${unique[@]}); do
        echo "$a. $role"
        a=$((a + 1))
    done
 
    echo "${reset}Please assign the IAM role(s) to your current user in order to perform the necessary deletions."
    echo "${reset}For more information on roles themselves, see here: "
    echo "${blue}https://cloud.google.com/iam/docs/understanding-roles#resource-manager-roles${reset}"
    echo "For more information on how to assign roles, see here: "
    echo "${blue}https://cloud.google.com/iam/docs/granting-changing-revoking-access#single-role"
 
    sleep 3s
    echo " "
 
    echo "${red}Attempt to programmatically bind necessary IAM role(s)?${reset}"
    echo
    options=("Yes" "No")
    select_option "${options[@]}"
    choice=$?
    if [ $choice == "0" ]; then
        for role in $(echo ${unique[@]}); do
            echo "adding role $role..."
            gcloud organizations add-iam-policy-binding $ORGANIZATION_ID --member="user:$CURRENT_ACCOUNT_EMAIL" --role=$role
        done
    else
        echo " "
    fi
else
    echo $reset"Looks like you have all of the necessary IAM permissions to perform this operation."
fi
 
echo "${red}Select an option using up/down keys and press enter to confirm your selection...${reset}"
echo
options=("Manage Resources" "Exit Script")
select_option "${options[@]}"
choice=$?
 
if [ $choice == "0" ]; then
    stayInMasterMenu="true"
    while [ $stayInMasterMenu == "true" ]; do
        echo ${red}"Select an option using up/down keys and press enter to confirm your selection...${reset}"
        echo
        options=("Delete active project(s)." "Delete active folder(s)." "Delete active Access Context Manager Policy(s)." "Recover recently deleted project(s)." "Exit Script")
        select_option "${options[@]}"
        choice=$?
        if [ $choice == "0" ]; then
            stayInDeleteProjectMenu="true"
            while [ $stayInDeleteProjectMenu == "true" ]; do
 
                ACTIVE_PROJECT_IDS=$(gcloud projects list --format='csv[no-heading](projectId)' |
                    while IFS="," read PROJECT_ID PROJECT_NUMBER; do
                        echo $PROJECT_ID
                    done)
 
                if [ -z "$ACTIVE_PROJECT_IDS" ]; then
                    echo "${reset}Looks like you have no active projects."
                    stayInDeleteProjectMenu="false"
                else
                    echo ${red}"Select an option using up/down keys and press enter to confirm your selection...${reset}"
                    echo ${green}"Here are your active project id(s):${reset}"
                    echo ${reset}"For more information on project deletion, see here: ${blue}https://cloud.google.com/sdk/gcloud/reference/projects/delete"${reset}
 
                    echo
                    options=($ACTIVE_PROJECT_IDS "Delete all active projects" "Back")
                    select_option "${options[@]}"
                    choice=$?
                    options_length=$((${#options[@]}))
                    delete_all_options_length=$(($options_length - 2))
                    exit_options_length=$(($options_length - 1))
                    if [ "$delete_all_options_length" == "$choice" ]; then
                        for project in $(echo ${ACTIVE_PROJECT_IDS[@]}); do
                            echo "deleting project...$project"
                            gcloud projects delete $project
                        done
                    elif [ "$exit_options_length" == "$choice" ]; then
                        stayInDeleteProjectMenu="false"
                    else
                        echo ${red}"Deleting project ${options[$choice]}..."
                        gcloud projects delete ${options[$choice]}
 
                    fi
                fi
            done
        elif [ $choice == "1" ]; then
            stayInDeleteFoldersMenu="true"
            while [ $stayInDeleteFoldersMenu == "true" ]; do
                ORGANIZATION_ID=$(gcloud organizations list --format='csv[no-heading](ID)')
                ACTIVE_FOLDER_IDS=$(gcloud resource-manager folders list --organization $ORGANIZATION_ID --format='csv[no-heading](ID)')
                ACTIVE_FOLDER_NAMES=$(gcloud resource-manager folders list --organization $ORGANIZATION_ID --format='csv[no-heading](DISPLAY_NAME)')
 
                if [ -z "$ACTIVE_FOLDER_IDS" ]; then
                    echo "${reset}Looks like you have no active folders."
                    stayInDeleteFoldersMenu="false"
                else
                    echo ${red}"Select an option using up/down keys and press enter to confirm your selection...${reset}"
                    echo ${green}"Here are your active folder id(s):"
                    echo ${reset}"For more information on folders deletion, see here: ${blue}https://cloud.google.com/sdk/gcloud/reference/resource-manager/folders/delete"${reset}
 
                    echo
                    options=($ACTIVE_FOLDER_IDS "Delete all active folders" "Back")
                    select_option "${options[@]}"
                    choice=$?
                    options_length=$((${#options[@]}))
                    delete_all_options_length=$(($options_length - 2))
                    exit_options_length=$(($options_length - 1))
                    if [ "$delete_all_options_length" == "$choice" ]; then
                        for folder in $(echo ${ACTIVE_FOLDER_IDS[@]}); do
                            echo "deleting folder...$folder"
                            gcloud resource-manager folders delete $folder
                        done
 
                    elif [ "$exit_options_length" == "$choice" ]; then
                        stayInDeleteFoldersMenu="false"
                    else
                        echo ${green}"Deleting folder ${options[$choice]}..."
                        gcloud resource-manager folders delete ${options[$choice]}
                    fi
                fi
            done
        elif [ $choice == "2" ]; then
            stayInDeleteAccessContextManagerPolicyMenu="true"
            while [ $stayInDeleteAccessContextManagerPolicyMenu == "true" ]; do
                ORGANIZATION_ID=$(gcloud organizations list --format='csv[no-heading](ID)')
                
                ACTIVE_ACCESS_CONTEXT_MANAGER_POLICY_IDS=$(gcloud access-context-manager policies list --organization $ORGANIZATION_ID --format='csv[no-heading](NAME)')
 
                if [ -z "$ACTIVE_ACCESS_CONTEXT_MANAGER_POLICY_IDS" ]; then
                    echo "${reset}Looks like you have no active access context manager policies."
                    stayInDeleteAccessContextManagerPolicyMenu="false"
                else
                    echo ${red}"Select an option using up/down keys and press enter to confirm your selection...${reset}"
                    echo ${green}"Here are your active access context manager policy id(s):"
                    echo ${reset}"For more information on policy deletion, see here: ${blue}https://cloud.google.com/access-context-manager/docs/manage-access-policy#delete"${reset}
 
                    echo
                    options=($ACTIVE_ACCESS_CONTEXT_MANAGER_POLICY_IDS "Delete all active policies" "Back")
                    select_option "${options[@]}"
                    choice=$?
                    options_length=$((${#options[@]}))
                    delete_all_options_length=$(($options_length - 2))
                    exit_options_length=$(($options_length - 1))
                    if [ "$delete_all_options_length" == "$choice" ]; then
                        for policy in $(echo ${ACTIVE_ACCESS_CONTEXT_MANAGER_POLICY_IDS[@]}); do
                            echo "deleting policy...$policy"
                            gcloud access-context-manager policies delete $policy
                        done
 
                    elif [ "$exit_options_length" == "$choice" ]; then
                        stayInDeleteAccessContextManagerPolicyMenu="false"
                    else
                        echo ${green}"Deleting policy ${options[$choice]}..."
                        gcloud access-context-manager policies delete ${options[$choice]}
                        
                    fi
                fi
            done
        elif [ $choice == "3" ]; then
            stayInRestoreRecentlyDeletedProjectMenu="true"
            while [ $stayInRestoreRecentlyDeletedProjectMenu == "true" ]; do
 
                RECENTLY_DELETED_PROJECT_IDS=$(gcloud projects list --filter='lifecycleState:DELETE_REQUESTED' --format='csv[no-heading](projectId)' |
                    while IFS="," read PROJECT_ID PROJECT_NUMBER; do
                        echo $PROJECT_ID
                    done)
 
                if [ -z "$RECENTLY_DELETED_PROJECT_IDS" ]; then
                    echo "${reset}Looks like you have no recently deleted projects."
                    stayInRestoreRecentlyDeletedProjectMenu="false"
                else
                    echo ${red}"Select an option using up/down keys and press enter to confirm your selection...${reset}"
                    echo ${green}"Here are your recently deleted project id(s):${reset}"
                    echo "For more information on projects restoration, see here: ${blue}https://cloud.google.com/sdk/gcloud/reference/projects/undelete"${reset}
 
                    echo
                    options=($RECENTLY_DELETED_PROJECT_IDS "Restore all recently deleted projects" "Back")
                    select_option "${options[@]}"
                    choice=$?
                    options_length=$((${#options[@]}))
                    restore_all_options_length=$(($options_length - 2))
                    exit_options_length=$(($options_length - 1))
                    if [ "$restore_all_options_length" == "$choice" ]; then
                        echo "$green restoring all recently deleted projects"
                        for project in $(echo ${RECENTLY_DELETED_PROJECT_IDS[@]}); do
                            echo "restoring project...$project"
                            gcloud projects undelete $project
                        done
                    elif [ "$exit_options_length" == "$choice" ]; then
                        stayInRestoreRecentlyDeletedProjectMenu="false"
                    else
                        echo ${green}"Restoring project ${options[$choice]}..."
                        gcloud projects undelete ${options[$choice]}
                    fi
                fi
            done
        else
            echo "Exiting..."
            stayInMasterMenu="false"
        fi
    done
else
    echo "Exiting..."
    exit
fi