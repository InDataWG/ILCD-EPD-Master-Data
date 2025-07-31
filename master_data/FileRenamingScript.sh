#!/bin/bash

# Script to rename XML files by prepending the name value to the original filename
# Works recursively through all subdirectories
# Uses different name elements based on the document type
# Falls back to German or any other language if English is not available

# Function to extract name with language fallbacks
get_element_with_fallback() {
    local file="$1"
    local element="$2"
    local namespace_pattern="$3"
    local value=""
    
    # Try with English first
    if [ "$namespace_pattern" = "with_ns" ]; then
        value=$(grep -o "<[^:]*:$element xml:lang=\"en\">[^<]*</[^:]*:$element>" "$file" 2>/dev/null | 
                sed "s/<[^:]*:$element xml:lang=\"en\">\(.*\)<\/[^:]*:$element>/\1/" | 
                head -1)
    else
        value=$(grep -o "<$element xml:lang=\"en\">[^<]*</$element>" "$file" 2>/dev/null | 
                sed "s/<$element xml:lang=\"en\">\(.*\)<\/$element>/\1/" | 
                head -1)
    fi
    
    # If not found, try with German
    if [ -z "$value" ]; then
        if [ "$namespace_pattern" = "with_ns" ]; then
            value=$(grep -o "<[^:]*:$element xml:lang=\"de\">[^<]*</[^:]*:$element>" "$file" 2>/dev/null | 
                    sed "s/<[^:]*:$element xml:lang=\"de\">\(.*\)<\/[^:]*:$element>/\1/" | 
                    head -1)
        else
            value=$(grep -o "<$element xml:lang=\"de\">[^<]*</$element>" "$file" 2>/dev/null | 
                    sed "s/<$element xml:lang=\"de\">\(.*\)<\/$element>/\1/" | 
                    head -1)
        fi
    fi
    
    # If still not found, try with any language attribute
    if [ -z "$value" ]; then
        if [ "$namespace_pattern" = "with_ns" ]; then
            value=$(grep -o "<[^:]*:$element xml:lang=\"[^\"]*\">[^<]*</[^:]*:$element>" "$file" 2>/dev/null | 
                    sed "s/<[^:]*:$element xml:lang=\"[^\"]*\">\(.*\)<\/[^:]*:$element>/\1/" | 
                    head -1)
        else
            value=$(grep -o "<$element xml:lang=\"[^\"]*\">[^<]*</$element>" "$file" 2>/dev/null | 
                    sed "s/<$element xml:lang=\"[^\"]*\">\(.*\)<\/$element>/\1/" | 
                    head -1)
        fi
    fi
    
    # If still not found, try without any language attribute
    if [ -z "$value" ]; then
        if [ "$namespace_pattern" = "with_ns" ]; then
            value=$(grep -o "<[^:]*:$element>[^<]*</[^:]*:$element>" "$file" 2>/dev/null | 
                    sed "s/<[^:]*:$element>\(.*\)<\/[^:]*:$element>/\1/" | 
                    head -1)
        else
            value=$(grep -o "<$element>[^<]*</$element>" "$file" 2>/dev/null | 
                    sed "s/<$element>\(.*\)<\/$element>/\1/" | 
                    head -1)
        fi
    fi
    
    echo "$value"
}

# Function to extract name and rename file
rename_file() {
    local file="$1"
    local filename=$(basename "$file")
    local directory=$(dirname "$file")
    local name_value=""
    local root_element=""

    # First, determine the root element type
    root_element=$(grep -o '<[^:]*\(DataSet\|dataSet\|GroupDataSet\)[^>]*>' "$file" | head -1 | sed 's/<\([^: ]*\).*/\1/')
    
    # Extract name based on root element type
    case "$root_element" in
        source|contact|ns*:source|ns*:contact)
            # For sourceDataSet or contactDataSet, use shortName
            name_value=$(get_element_with_fallback "$file" "shortName" "with_ns")
            
            # If not found with namespace, try without
            if [ -z "$name_value" ]; then
                name_value=$(get_element_with_fallback "$file" "shortName" "without_ns")
            fi
            ;;
            
        flow|ns*:flow)
            # For flowDataSet, use baseName
            name_value=$(get_element_with_fallback "$file" "baseName" "with_ns")
            
            # If not found with namespace, try without
            if [ -z "$name_value" ]; then
                name_value=$(get_element_with_fallback "$file" "baseName" "without_ns")
            fi
            ;;
            
        LCIA|unit|flowProperty|ns*:LCIA|ns*:unit|ns*:flowProperty)
            # For LCIAMethodDataSet, unitGroupDataSet, and flowPropertyDataSet, use name
            name_value=$(get_element_with_fallback "$file" "name" "with_ns")
            
            # If not found with namespace, try without
            if [ -z "$name_value" ]; then
                name_value=$(get_element_with_fallback "$file" "name" "without_ns")
            fi
            ;;
            
        *)
            # For any other type, try all patterns
            # First try shortName
            name_value=$(get_element_with_fallback "$file" "shortName" "with_ns")
            
            # Then try shortName without namespace
            if [ -z "$name_value" ]; then
                name_value=$(get_element_with_fallback "$file" "shortName" "without_ns")
            fi
            
            # Then try baseName
            if [ -z "$name_value" ]; then
                name_value=$(get_element_with_fallback "$file" "baseName" "with_ns")
            fi
            
            # Then try baseName without namespace
            if [ -z "$name_value" ]; then
                name_value=$(get_element_with_fallback "$file" "baseName" "without_ns")
            fi
            
            # Then try name
            if [ -z "$name_value" ]; then
                name_value=$(get_element_with_fallback "$file" "name" "with_ns")
            fi
            
            # Finally try name without namespace
            if [ -z "$name_value" ]; then
                name_value=$(get_element_with_fallback "$file" "name" "without_ns")
            fi
            ;;
    esac

    if [ -n "$name_value" ]; then
        # Replace spaces, commas, parentheses and other special characters with underscores
        local formatted_name=$(echo "$name_value" | sed 's/[[:space:],()]/_/g' | sed 's/__/_/g')
        
        # Create new filename by prepending the formatted name to the original filename
        local new_name="${formatted_name}_${filename}"
        
        echo "Renaming: $directory/$filename → $directory/$new_name"
        mv "$file" "$directory/$new_name"
    else
        echo "Could not find appropriate name in $file, skipping"
    fi
}

# Main function to process files recursively
process_directory() {
    local dir="$1"
    
    # Find all XML files in the current directory and subdirectories
    find "$dir" -type f -name "*.xml" | while read -r file; do
        rename_file "$file"
    done
}

# Start processing from the current directory
echo "Starting recursive file renaming process..."
process_directory "."
echo "Renaming process completed."
