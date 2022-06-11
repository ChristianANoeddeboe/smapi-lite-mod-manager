#!/bin/bash

GAME_EXE="Stardew Valley"
MODS_FOLDER="Mods"
PROFILES_FOLDER="profiles"
PROFILE_TESTER_NAME_PREFIX="profile_"
DEFAULT_PROFILE_NAME="default"
SMAPI_MODS=("ConsoleCommands", "ErrorHandler", "SaveBackup")

active_profile=""

# Logic

gen_profiles_list() {
    profiles=("./$PROFILES_FOLDER"/*) # This creates an array of the full paths to all subdirs
    profiles=("${profiles[@]%/}")     # This removes the trailing slash on each item
    profiles=("${profiles[@]##*/}")   # This removes the path prefix, leaving just the dir names
}

# Create list of names of the folders in the profiles folder
profiles_list() {

    count=1
    for profile in "${profiles[@]}"; do
        echo "$count $profile"
        ((count += 1))
    done
}

get_active_profile() {
    # Check if a file with the prefix exists in the Mods folder, and split it on _ to get the profile name
    for file in "$MODS_FOLDER"/*; do
        if [ -f "$file" ]; then
            if [[ "${file}" =~ "${PROFILE_TESTER_NAME_PREFIX}" ]]; then
                active_profile="${file##*_}"
            fi
        fi
    done
}

create_profile() {
    profile_name="$1"
    if [ -d "$PROFILES_FOLDER/$profile_name" ]; then
        echo "Profile already exists."
        return 0
    fi
    mkdir "$PROFILES_FOLDER/$profile_name"
    touch "$PROFILES_FOLDER/$profile_name/PLACE_MODS_HERE"
    gen_profiles_list
    echo "Profile $profile_name created."
    return 1

}

deactivate_profile() {
    if [ ! -d "$PROFILES_FOLDER/$profile_name" ]; then
        echo "Profile does not exist."
        return 0
    fi

    existing_mods=("./$MODS_FOLDER"/*) # This creates an array of the full paths to all subdirs
    # Check if any existing mods are symlinked to the profile folder. If symlinked, remove them.
    for mod in "${existing_mods[@]}"; do
        if [ -L "$mod" ]; then
            rm "$mod"
        fi
    done
    if [ -f ./"$MODS_FOLDER"/"$PROFILE_TESTER_NAME_PREFIX$active_profile" ]; then
        rm ./"$MODS_FOLDER"/"$PROFILE_TESTER_NAME_PREFIX$active_profile"
    fi

}

activate_profile() {
    profile_name="$1"
    if [ ! -d "$PROFILES_FOLDER/$profile_name" ]; then
        echo "Profile does not exist."
        return 0
    fi

    deactivate_profile

    echo "Activating profile $profile_name"

    # Symlink all mods in the profile folder to the mods folder
    for mod in "$PROFILES_FOLDER/$profile_name"/*; do
        if [ -d "$mod" ]; then
            ln -s ../"$mod"/ ./"$MODS_FOLDER"/
        fi
    done

    # Create empty file with profile name to indicate that profile is active
    touch "$MODS_FOLDER/$PROFILE_TESTER_NAME_PREFIX$profile_name"
    get_active_profile

}

delete_profile() {
    profile_name="$1"
    if [ ! -d "$PROFILES_FOLDER/$profile_name" ]; then
        echo "Profile does not exist."
        return 0
    fi

    echo "Deleting profile $profile_name"

    # If profile is active, deactivate it
    if [ "$active_profile" == "$profile_name" ]; then
        deactivate_profile
    fi

    # Delete the profile folder
    rm -rf "$PROFILES_FOLDER/$profile_name"
    gen_profiles_list

    # If the profile was the last one, activate the default profile
    if [ "$active_profile" == "" ]; then
        # If the default profile doesn't exist, create it
        if [ ! -d "$PROFILES_FOLDER/$DEFAULT_PROFILE_NAME" ]; then
            create_profile "$DEFAULT_PROFILE_NAME"
        fi

        activate_profile "$DEFAULT_PROFILE_NAME"
    fi

    echo "Profile $profile_name deleted."

    return 1

}

migrate_existing_mods() {
    existing_mods=("./$MODS_FOLDER"/*) # This creates an array of the full paths to all subdirs
    count=0
    for mod in "${existing_mods[@]}"; do
        if [ ! -L "$mod" ]; then
            if [ -d "$mod" ]; then
                # Increment the count if the mod is not a symlink
                ((count += 1))
            fi
        fi
    done

    if [ "$count" = 3 ]; then
        return 0
    fi

    echo "Migrating existing mods to new profile folder structure."
    new_profile_created=false
    temp_profile_name="temp$date"
    for mod in "${existing_mods[@]}"; do
        mod_name="${mod##*/}"
        if [[ ! "${SMAPI_MODS[*]}" =~ "${mod_name}" ]]; then
            if [ "$new_profile_created" = false ]; then
                create_profile "$temp_profile_name"
                new_profile_created=true
            fi
            # Check if mod folder is a symlink.
            if [ ! -L "$mod" ]; then
                if [ -d "$mod" ]; then
                    mv "$mod" "$PROFILES_FOLDER/$temp_profile_name/"
                    echo "Moved $mod_name to $profile_name"
                fi
            fi

        fi
    done
    echo "Migration complete. Please transfer the files to a proper profile."
}

setup() {
    if [ ! -f "$GAME_EXE" ]; then
        echo "Stardew Valley executable not found. Please move this script to the Stardew Valley folder."
        exit 1
    fi
    if [ ! -d "$MODS_FOLDER" ]; then
        echo "Mods folder not found. Please make sure SMAPI is installed correctly."
        exit 1
    fi
    if [ ! -d "$PROFILES_FOLDER" ]; then
        echo "No profiles folder found. Creating one..."
        mkdir "$PROFILES_FOLDER"
        create_profile "$DEFAULT_PROFILE_NAME"
    fi
    if [ ! -d "$PROFILES_FOLDER/$DEFAULT_PROFILE_NAME" ]; then
        echo "No default profile found. Creating one..."
        create_profile "$DEFAULT_PROFILE_NAME"
        activate_profile "$DEFAULT_PROFILE_NAME"
    fi
    migrate_existing_mods
    get_active_profile
}

# Menus

create_profile_menu() {
    echo "Create profile"
    echo "############"
    echo "Enter profile name:"
    read profile_name
    create_profile "$profile_name"
    open "$PROFILES_FOLDER/$profile_name"
    sleep 2
    main_menu
}

load_profile_menu() {
    clear
    echo "Load profile menu"
    echo "-----------------"
    echo "Profiles:"
    profiles_list
    echo "Enter profile number to activate:"
    read profile_number
    profile_name="${profiles[$((profile_number - 1))]}"
    activate_profile "$profile_name"
    sleep 2
    main_menu
}

remove_profiles_menu() {
    clear
    echo "Remove profiles menu"
    echo "---------------------"
    echo "Profiles:"
    profiles_list
    echo "Enter profile number to delete:"
    read profile_number
    profile_name="${profiles[$((profile_number - 1))]}"
    delete_profile "$profile_name"
    sleep 2
    main_menu
}

main_menu() {
    gen_profiles_list
    clear
    echo "Stardew Valley Mod Manager Lite"
    echo "--------------------------------"
    echo "Profiles:"
    profiles_list
    echo "--------------------------------"
    echo "Active profile: $active_profile"
    echo "1. Create profile"
    echo "2. Load profile"
    echo "3. Remove profile"
    echo "4. Exit"
    echo "--------------------------------"
    echo -n "Enter your choice: "
    read choice
    case $choice in
    1) create_profile_menu ;;
    2) load_profile_menu ;;
    3) remove_profiles_menu ;;
    4) exit ;;
    *)
        echo "Invalid choice"
        sleep 1
        main_menu
        ;;
    esac

}

setup

main_menu

# sleep 2

# create_profile "Test"
# sleep 2

# profiles_list

# activate_profile "Test"
# sleep 2

# get_active_profile

# deactivate_profile
# sleep 2

# rm -rf "$PROFILES_FOLDER/Test"
