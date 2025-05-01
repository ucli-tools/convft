#!/bin/bash

# Get the absolute path of the script
SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_NAME=$(basename "$SCRIPT_PATH")

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Help function
help() {
    clear
    echo -e "${BOLD}${BLUE}=========================================${NC}"
    echo -e "${BOLD}${BLUE}       ConvFT: File-Text Conversion     ${NC}"
    echo -e "${BOLD}${BLUE}=========================================${NC}"
    echo
    echo -e "${CYAN}A simple CLI tool for converting between file structures${NC}"
    echo -e "${CYAN}and single text file representations. Ideal for AI work, backup,${NC}"
    echo -e "${CYAN}sharing, and reconstructing complex directory hierarchies.${NC}"
    echo
    echo -e "${MAGENTA}Repository:${NC} ${BOLD}https://github.com/mik-tf/convft${NC}"
    echo -e "${MAGENTA}License:${NC}    ${BOLD}Apache 2.0${NC}"
    echo
    echo -e "${YELLOW}Usage:${NC} ${BOLD}convft [COMMAND] [OPTIONS]${NC}"
    echo
    echo -e "${GREEN}Commands:${NC}"
    echo -e "  ${BOLD}ft${NC}         Convert files to text"
    echo -e "  ${BOLD}tf${NC}         Convert text to files"
    echo -e "  ${BOLD}install${NC}    Install ConvFT (requires sudo)"
    echo -e "  ${BOLD}uninstall${NC}  Uninstall ConvFT (requires sudo)"
    echo -e "  ${BOLD}help${NC}       Display this help message"
    echo
    echo -e "${GREEN}Options for ft:${NC}"
    echo -e "  ${BOLD}-i --include [PATH...]${NC}   Process only specified files or directories (defaults to current directory if not used)"
    echo -e "  ${BOLD}-e --exclude [PATH...]${NC}   Exclude specific directories or files"
    echo -e "  ${BOLD}-t --tree-depth [DEPTH]${NC}  Set directory tree depth (default 1)"
    echo
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  ${BOLD}convft ft -i /my/project -t 3 -e /my/project/temp /my/project/build.sh${NC}"
    echo -e "  ${BOLD}convft ft -i /path/to/file1.txt /path/to/dir1${NC}"
    echo -e "  ${BOLD}convft tf${NC}"
    echo -e "  ${BOLD}sudo convft install${NC}"
    echo -e "  ${BOLD}sudo convft uninstall${NC}"
    echo
}

# Function to get directory tree
get_directory_tree() {
    local depth=$1
    local base_dir=$2 # Pass the base directory for tree
    if ! command -v tree &> /dev/null; then
        echo -e "${RED}Error: tree command not found. Please install it first.${NC}"
        # Don't exit, just skip the tree part if not found
        echo "tree command not found, skipping directory tree."
        return 1
    fi
    # Run tree in the specified base directory, ignoring common VCS/temp files
    (cd "$base_dir" && tree -a -L "$depth" -I '.git|.DS_Store|*.pyc|__pycache__|node_modules|.venv|env' --noreport) || echo "Error running tree on $base_dir"
}

# Function to check if a file should be ignored based on .gitignore patterns
# Uses git check-ignore if available for accuracy.
is_ignored_by_gitignore() {
    local file_path="$1"
    local resolved_file_path
    resolved_file_path=$(realpath -m "$file_path" 2>/dev/null)

    # If path cannot be resolved, assume not ignored
    [[ -z "$resolved_file_path" ]] && return 1

    # Find the nearest .git directory to determine the repo root
    local git_dir
    git_dir=$(git -C "$(dirname "$resolved_file_path")" rev-parse --show-toplevel 2>/dev/null)

    # If in a git repo and git command exists, use git check-ignore
    if command -v git &> /dev/null && [[ -n "$git_dir" ]] && [[ -d "$git_dir/.git" || -f "$git_dir/.git" ]]; then
        if git -C "$git_dir" check-ignore -q --no-index "$resolved_file_path"; then
            return 0 # Ignored by git
        else
            return 1 # Not ignored by git
        fi
    else
         # Basic fallback (less accurate, only checks parent dirs for .gitignore)
         local dir_path=$(dirname "$resolved_file_path")
         local gitignore_path=""
         while [[ "$dir_path" != "/" && "$dir_path" != "." ]]; do
             if [[ -f "$dir_path/.gitignore" ]]; then
                 gitignore_path="$dir_path/.gitignore"
                 # Very basic pattern matching (doesn't handle complex rules well)
                 if grep -qE "(^|/)$(basename "$resolved_file_path")\$" "$gitignore_path"; then
                     # Note: This is a very simplified check
                     # It doesn't handle negations, wildcards complexly, etc.
                     # Git check-ignore is strongly preferred.
                     return 0 # Found a potential match
                 fi
             fi
             dir_path=$(dirname "$dir_path")
         done
    fi

    return 1 # Not ignored (default)
}

# Function to process a single file (check type, add to output)
process_file() {
    local file="$1"
    local output_file="$2"
    local resolved_file
    resolved_file=$(realpath -m "$file" 2>/dev/null)

    # Skip if path is invalid or not a file
    if [[ -z "$resolved_file" ]] || [[ ! -f "$resolved_file" ]] || [[ ! -r "$resolved_file" ]]; then
        # echo -e "${YELLOW}Skipping invalid or unreadable file:${NC} $file" # Optional: Can be verbose
        return
    fi

    # Skip the output file itself (absolute path check)
    local resolved_output_file
    resolved_output_file=$(realpath -m "$output_file" 2>/dev/null)
    if [[ "$resolved_file" == "$resolved_output_file" ]]; then
        # echo "Debug: Skipping output file $resolved_file" # Debug
        return
    fi

    # Check for binary extensions first (quick filter)
    if [[ "$resolved_file" =~ \.(png|jpg|jpeg|gif|bmp|ico|pdf|zip|gz|tar|rar|7z|bin|exe|dll|so|dylib|class|pyc|o|a|lib|obj|iso|dmg|svg|psd|ttf|woff|woff2|eot|jar|war|ear|docx|xlsx|pptx|odt|ods|odp|db|sqlite|mdb|mp3|mp4|avi|mov|mkv|flv|webm)$ ]]; then
        echo -e "${YELLOW}Skipping binary file by extension:${NC} $file"
        return
    fi

    # Use the file command as a more robust check for text content
    # Look for common text types, scripts, markup, data formats, or empty files
    if file --brief --mime-type "$resolved_file" | grep -qE '^text/|application/json|application/xml|application/javascript|application/x-sh|inode/x-empty'; then
        echo -e "${CYAN}Processing:${NC} $file"
        # Use relative path for Filepath: if possible
        local display_path
        display_path=$(realpath --relative-to=. "$resolved_file" 2>/dev/null) || display_path="$resolved_file"

        echo "Filepath: $display_path" >> "$output_file"
        echo "Content:" >> "$output_file"
        cat "$resolved_file" >> "$output_file" # Use resolved path to read content
        echo -e "\n" >> "$output_file"
        return 0 # Indicate success
    else
        # File command didn't identify it as text-based
        echo -e "${YELLOW}Skipping non-text file:${NC} $file (Type: $(file --brief "$resolved_file"))"
        return 1 # Indicate skipped
    fi
}

# Function to convert files to text
file_to_text() {
    local output_file="all_files_text.txt"
    local include_paths=()
    local depth=1
    # Initialize exclude array with common ignores + output file (resolved later)
    local exclude=(".git" "venv" ".venv" "env" "__pycache__" "node_modules" "dist" "build" ".eggs" ".tox" "wheels" ".cache" "logs" ".idea" ".vscode" "$output_file")
    local exclude_patterns=() # Store resolved exclude paths/patterns
    local include_paths_provided=false

    # --- Parse Options ---
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--include)
                shift
                include_paths_provided=true
                while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                    local resolved_path
                    resolved_path=$(realpath -m "$1" 2>/dev/null)
                    if [[ -z "$resolved_path" ]]; then
                         echo -e "${YELLOW}Warning: Included path cannot be resolved, skipping:${NC} $1"
                    elif [[ ! -e "$resolved_path" ]]; then
                        echo -e "${YELLOW}Warning: Included path does not exist, skipping:${NC} $resolved_path"
                    else
                        include_paths+=("$resolved_path")
                    fi
                    shift
                done
                ;;
            -e|--exclude)
                shift
                while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                    # Add user exclusions to the main exclude list for later resolution
                    exclude+=("$1")
                    shift
                done
                ;;
            -t|--tree-depth)
                shift
                if [[ "$1" =~ ^[0-9]+$ ]]; then
                    depth="$1"
                else
                    echo -e "${RED}Error: Tree depth must be a number.${NC}"
                    exit 1
                fi
                shift
                ;;
            *)
                echo -e "${RED}Unknown option for ft: $1${NC}"
                help
                exit 1
                ;;
        esac
    done

    # --- Resolve Exclusion Paths ---
    local resolved_output_abs_path=$(realpath -m "$output_file" 2>/dev/null) # Resolve output file path
    for ex_item in "${exclude[@]}"; do
         local resolved_ex_path
         resolved_ex_path=$(realpath -m "$ex_item" 2>/dev/null)
         if [[ -n "$resolved_ex_path" ]]; then
             exclude_patterns+=("$resolved_ex_path")
             # If it's a directory, add a pattern with /* for matching contents
             if [[ -d "$resolved_ex_path" && "${resolved_ex_path: -1}" != "/" ]]; then
                  exclude_patterns+=("$resolved_ex_path/*")
             elif [[ -d "$resolved_ex_path" ]]; then
                  exclude_patterns+=("${resolved_ex_path}*")
             fi
         else
              # Maybe it's a pattern like *.log - keep it as is? Or just warn?
              # For simplicity, let's keep simple patterns/basenames too
              exclude_patterns+=("$ex_item")
              echo -e "${YELLOW}Warning: Excluded item '$ex_item' could not be resolved to an absolute path. Using as a basic pattern.${NC}"
         fi
    done
    # Ensure the resolved output file path is definitely in the patterns
    if [[ -n "$resolved_output_abs_path" && ! " ${exclude_patterns[@]} " =~ " $resolved_output_abs_path " ]]; then
        exclude_patterns+=("$resolved_output_abs_path")
    fi
    # Debug: echo "Exclude patterns: ${exclude_patterns[@]}"

    echo -e "${YELLOW}Starting conversion of files to text...${NC}"
    > "$output_file" # Clear the output file

    # --- Add Directory Tree ---
    local tree_base="."
    if [ "$include_paths_provided" = true ] && [ ${#include_paths[@]} -gt 0 ]; then
        # If paths included, try to use the first one as base if it's a directory
        if [[ -d "${include_paths[0]}" ]]; then
            tree_base="${include_paths[0]}"
        else
             # If first include is a file, use its parent directory
             tree_base=$(dirname "${include_paths[0]}")
        fi
        echo -e "${YELLOW}Generating tree relative to '$tree_base' (best effort based on includes).${NC}"
    fi
    echo "DirectoryTree (base: $tree_base, depth: $depth):" >> "$output_file"
    get_directory_tree "$depth" "$tree_base" >> "$output_file"
    echo "EndDirectoryTree" >> "$output_file"
    echo >> "$output_file"

    # --- Process Files ---
    local processed_files_count=0

    # Helper function to check ALL exclusions (user -e, .gitignore)
    should_exclude() {
        local file_to_check="$1"
        local resolved_file_to_check
        resolved_file_to_check=$(realpath -m "$file_to_check" 2>/dev/null)
        if [[ -z "$resolved_file_to_check" ]]; then return 0; fi # Exclude if cannot resolve

        # 1. Check against resolved -e patterns
        for pattern in "${exclude_patterns[@]}"; do
             # Direct match or directory prefix match
             if [[ "$resolved_file_to_check" == "$pattern" ]] || \
                ([[ "$pattern" == *"/*" ]] && [[ "$resolved_file_to_check" == "${pattern%/*}"* ]]) || \
                ([[ "$pattern" == *"/" ]] && [[ "$resolved_file_to_check" == "$pattern"* ]]) ; then
                 # echo "Debug Exclude: $resolved_file_to_check matches pattern $pattern" # Debug
                 return 0 # Exclude
             fi
             # Basic basename/pattern match (less precise)
             if [[ "$pattern" != *"/"* && "$resolved_file_to_check" == *"$pattern"* ]]; then
                 # echo "Debug Exclude: $resolved_file_to_check contains pattern $pattern" # Debug
                 return 0 # Exclude (e.g. excluding '.log')
             fi
        done

        # 2. Check against .gitignore
        if is_ignored_by_gitignore "$resolved_file_to_check"; then
            # echo "Debug Exclude: $resolved_file_to_check ignored by gitignore" # Debug
             return 0 # Exclude
        fi

        return 1 # Do NOT exclude
    }

    if [ "$include_paths_provided" = true ]; then
        # --- Mode: Process only explicitly included paths ---
        echo -e "${CYAN}Processing explicitly included paths...${NC}"
        if [ ${#include_paths[@]} -eq 0 ]; then
            echo -e "${YELLOW}Warning: -i was specified, but no valid include paths were found.${NC}"
        fi
        for item in "${include_paths[@]}"; do
            if [[ -f "$item" ]]; then
                if ! should_exclude "$item"; then
                    if process_file "$item" "$output_file"; then
                        processed_files_count=$((processed_files_count + 1))
                    fi
                else
                    echo -e "${YELLOW}Skipping excluded/ignored included file:${NC} $item"
                fi
            elif [[ -d "$item" ]]; then
                echo -e "${CYAN}Processing included directory:${NC} $item"
                # Use find within this specific directory
                # No need for extensive -not -path here as we check each file with should_exclude
                find "$item" -type f | sort | while IFS= read -r file; do
                    if ! should_exclude "$file"; then
                         if process_file "$file" "$output_file"; then
                             processed_files_count=$((processed_files_count + 1))
                         fi
                    # else
                         # echo -e "${YELLOW}Skipping excluded/ignored file within dir:${NC} $file" # Verbose
                    fi
                done
            # else: Handled during path resolution earlier
            fi
        done

    else
        # --- Mode: Process based on current directory (Git or Find) ---
        echo -e "${CYAN}Processing based on current directory (no -i specified)...${NC}"
        local base_dir="."
        if command -v git &> /dev/null && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            local repo_root
            repo_root=$(git rev-parse --show-toplevel)
            echo -e "${CYAN}Using git ls-files from repo root: $repo_root (respects .gitignore)${NC}"
            # Run git ls-files from repo root to get consistent relative paths
             (cd "$repo_root" && { git ls-files; git ls-files --others --exclude-standard; } | sort | uniq) | while IFS= read -r repo_relative_file; do
                 local file_abs_path="$repo_root/$repo_relative_file"

                 if [[ -f "$file_abs_path" ]]; then # Ensure it's a file
                     if ! should_exclude "$file_abs_path"; then
                          # Pass the path relative to CWD if possible, else absolute
                          local path_to_process
                          path_to_process=$(realpath --relative-to="$PWD" "$file_abs_path" 2>/dev/null) || path_to_process="$file_abs_path"

                          if process_file "$path_to_process" "$output_file"; then
                              processed_files_count=$((processed_files_count + 1))
                          fi
                     # else
                         # echo -e "${YELLOW}Skipping excluded/ignored git file:${NC} $repo_relative_file" # Verbose
                     fi
                 fi
             done
        else
            echo -e "${CYAN}Using find from current directory ('.') (no git repo detected or git not found)${NC}"
            # Use find from the current directory
            find "$base_dir" -type f | sort | while IFS= read -r file; do
                # Resolve to absolute path for exclusion check consistency
                local abs_file_path
                abs_file_path=$(realpath -m "$file" 2>/dev/null)
                if [[ -z "$abs_file_path" ]]; then continue; fi # Skip unresolvable

                if ! should_exclude "$abs_file_path"; then
                    # Pass original path (usually relative) to process_file
                    if process_file "$file" "$output_file"; then
                        processed_files_count=$((processed_files_count + 1))
                    fi
                # else
                    # echo -e "${YELLOW}Skipping excluded/ignored found file:${NC} $file" # Verbose
                fi
            done
        fi
    fi

    # --- Final Report ---
    if [[ $processed_files_count -eq 0 ]]; then
         echo -e "${YELLOW}Warning: No files were processed. Check include/exclude options and file types.${NC}"
    fi
    echo -e "${GREEN}Conversion completed. ${processed_files_count} file(s) processed. Output saved to ${BOLD}$output_file${NC}"
}


# Function to convert text back to files
text_to_file() {
    local input_file="all_files_text.txt"

    if [[ ! -f "$input_file" ]]; then
        echo -e "${RED}Error: $input_file not found in the current directory.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Starting conversion of text to files from ${BOLD}$input_file${NC}..."

    local in_tree_section=false
    local in_content_section=false
    local current_file=""
    local line_num=0
    local created_files=0
    local skipped_files=0

    while IFS= read -r line || [[ -n "$line" ]]; do # Process last line even if no newline
        ((line_num++))

        # Skip Tree Section
        if [[ "$line" == "DirectoryTree:"* ]]; then
            in_tree_section=true
            continue
        fi
        if [[ "$line" == "EndDirectoryTree" ]]; then
            in_tree_section=false
            continue
        fi
        if [[ "$in_tree_section" == true ]]; then
            continue
        fi

        # Detect Filepath
        if [[ "$line" == "Filepath: "* ]]; then
            current_file="${line#Filepath: }"
            in_content_section=false # Reset content flag for the new file

            # Basic sanitization/check
            if [[ -z "$current_file" || "$current_file" == "." || "$current_file" == "/" ]]; then
                 echo -e "${RED}Error line $line_num: Invalid filepath detected: '$current_file'. Skipping.${NC}"
                 current_file="" # Reset current file
                 continue
            fi

            # Check if file path seems reasonable (e.g., avoid writing to /) - basic check
            if [[ "$current_file" == /* && "$current_file" != "$PWD"* ]]; then
                 # This is a basic safety check, might block legitimate use cases if run from /
                 # Consider removing or refining if it causes issues
                 # echo -e "${YELLOW}Warning line $line_num: Absolute path '$current_file' detected outside current directory structure. Proceeding with caution.${NC}"
                 : # Allow absolute paths for now
            fi

             # Skip creating file if it looks like it might be ignored by git rules (optional safety)
            # if is_ignored_by_gitignore "$current_file"; then
            #     echo -e "${YELLOW}Skipping potentially ignored file based on gitignore rules:${NC} $current_file"
            #     current_file="" # Reset current file so content is skipped
            #     ((skipped_files++))
            #     continue
            # fi


            # Create directories if they don't exist
            local dir
            dir=$(dirname "$current_file")
            if [[ ! -d "$dir" ]]; then
                echo -e "${CYAN}Creating directory:${NC} $dir"
                mkdir -p "$dir"
                if [[ $? -ne 0 ]]; then
                    echo -e "${RED}Error line $line_num: Failed to create directory '$dir' for file '$current_file'. Skipping file.${NC}"
                    current_file="" # Reset current file
                    continue
                fi
            fi

            # Create/truncate the file
            echo -e "${CYAN}Creating/Updating:${NC} $current_file"
            # Truncate the file only when Filepath: is encountered
            > "$current_file"
             if [[ $? -ne 0 ]]; then
                 echo -e "${RED}Error line $line_num: Failed to create or clear file '$current_file'. Skipping.${NC}"
                 current_file="" # Reset current file
                 continue
             fi
            ((created_files++))
            continue # Move to next line after processing Filepath:
        fi

        # Detect Content section start
        if [[ "$line" == "Content:" && -n "$current_file" ]]; then
             in_content_section=true
             continue # Skip the "Content:" line itself
        fi

        # Write Content
        if [[ "$in_content_section" == true && -n "$current_file" ]]; then
             echo "$line" >> "$current_file"
             # Check for write errors? Might be slow.
        # else
             # Handle lines outside Filepath/Content blocks (e.g., empty lines between files)
             # Or lines appearing before the first Filepath
             # if [[ -n "$line" && "$line_num" -gt 1 && "$in_tree_section" == false ]]; then
             #      echo -e "${YELLOW}Warning line $line_num: Ignoring unexpected line outside Filepath/Content block: $line ${NC}"
             # fi
             : # Ignore empty lines between file blocks silently
        fi

    done < "$input_file"

    echo -e "${GREEN}Conversion completed. ${created_files} file(s) created/updated, ${skipped_files} skipped.${NC}"
}

# Function to install the script
install() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run the install command with sudo.${NC}"
        echo -e "${YELLOW}Example: sudo ./convft.sh install${NC}"
        exit 1
    fi

    local install_path="/usr/local/bin/convft"
    echo -e "${CYAN}Attempting to install script to ${install_path}...${NC}"

    # Ensure the source script path is absolute
    local source_script_path
    source_script_path=$(readlink -f "$0")
    if [[ ! -f "$source_script_path" ]]; then
        echo -e "${RED}Error: Could not determine the absolute path of the script '$0'.${NC}"
        exit 1
    fi

    if cp "$source_script_path" "$install_path"; then
        echo -e "${CYAN}Script copied successfully.${NC}"
    else
        echo -e "${RED}Error: Failed to copy script to ${install_path}. Check permissions.${NC}"
        exit 1
    fi

    if chmod +x "$install_path"; then
        echo -e "${CYAN}Execution permissions set successfully.${NC}"
    else
        echo -e "${RED}Error: Failed to set execution permissions on ${install_path}.${NC}"
        # Attempt cleanup
        rm -f "$install_path"
        exit 1
    fi

    echo -e "${GREEN}Installation successful! You can now use 'convft' from any directory.${NC}"
    echo -e "${YELLOW}Note: If you move or delete the original script file, the installed command will still work.${NC}"
}

# Function to uninstall the script
uninstall() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run the uninstall command with sudo.${NC}"
        echo -e "${YELLOW}Example: sudo convft uninstall${NC}"
        exit 1
    fi

    local install_path="/usr/local/bin/convft"
    echo -e "${CYAN}Attempting to uninstall script from ${install_path}...${NC}"

    if [ -f "$install_path" ]; then
        if rm "$install_path"; then
            echo -e "${GREEN}ConvFT has been uninstalled successfully from ${install_path}.${NC}"
        else
            echo -e "${RED}Error: Failed to remove ${install_path}. Check permissions or if the file is in use.${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}ConvFT is not installed in ${install_path}. Nothing to remove.${NC}"
    fi
}

# --- Main Script Logic ---
if [[ $# -eq 0 ]]; then
    help
    exit 0
fi

COMMAND="$1"
shift # Remove command from argument list

case "$COMMAND" in
    ft)
        file_to_text "$@" # Pass remaining arguments
        ;;
    tf)
        if [[ $# -gt 0 ]]; then
            echo -e "${YELLOW}Warning: The 'tf' command does not accept additional arguments currently. Ignoring: $@ ${NC}"
        fi
        text_to_file
        ;;
    install)
         if [[ $# -gt 0 ]]; then
            echo -e "${YELLOW}Warning: The 'install' command does not accept additional arguments. Ignoring: $@ ${NC}"
        fi
        install
        ;;
    uninstall)
         if [[ $# -gt 0 ]]; then
            echo -e "${YELLOW}Warning: The 'uninstall' command does not accept additional arguments. Ignoring: $@ ${NC}"
        fi
        uninstall
        ;;
    help|-h|--help)
        help
        ;;
    *)
        echo -e "${RED}Invalid command: '$COMMAND'. Use 'convft help' for usage information.${NC}"
        exit 1
        ;;
esac
