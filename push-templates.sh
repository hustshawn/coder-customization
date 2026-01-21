#!/bin/bash

# Script to automatically push Coder templates
# Usage: ./push-templates.sh [template-name]
# If no template name is provided, it will push all templates

set -e

TEMPLATES_DIR="templates"
TEMPLATE_NAME="$1"

# Function to push a single template
push_template() {
    local template="$1"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local template_path="$script_dir/$TEMPLATES_DIR/$template"

    echo "Pushing template: $template"

    if [ -d "$template_path" ]; then
        coder templates push "$template" --directory "$template_path" -y
        echo "✅ Successfully pushed $template"
    else
        echo "❌ Template directory $template_path not found"
        return 1
    fi
}

# Main logic
if [ -n "$TEMPLATE_NAME" ]; then
    # Push specific template
    push_template "$TEMPLATE_NAME"
else
    # Push all templates
    echo "No template specified, pushing all templates..."
    
    if [ ! -d "$TEMPLATES_DIR" ]; then
        echo "❌ Templates directory not found"
        exit 1
    fi
    
    # Find all template directories
    for template_dir in "$TEMPLATES_DIR"/*; do
        if [ -d "$template_dir" ]; then
            template_name=$(basename "$template_dir")
            echo ""
            push_template "$template_name"
        fi
    done
fi

echo ""
echo "🎉 Template push completed!"