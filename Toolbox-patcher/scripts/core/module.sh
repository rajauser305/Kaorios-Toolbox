#!/usr/bin/env bash
# scripts/core/module.sh
# Module creation functions

create_module() {
    # local api_level="$1"  # Currently unused but kept for future use
    local device_name="$2"
    local version_name="$3"

    log "Creating module using FrameworkPatcherModule for $device_name (v$version_name)"

    local build_dir="build_module"
    rm -rf "$build_dir"

    # Copy FrameworkPatcherModule template
    cp -r "templates/framework-patcher-module" "$build_dir" || {
        err "FrameworkPatcherModule template not found: templates/framework-patcher-module"
        return 1
    }

    # Clean up unnecessary files from FrameworkPatcherModule template
    rm -f "$build_dir/.git" "$build_dir/.gitignore" "$build_dir/.gitattributes"
    rm -f "$build_dir/README.md" "$build_dir/changelog.md" "$build_dir/LICENSE"
    rm -f "$build_dir/update.json" "$build_dir/install.zip"
    rm -rf "$build_dir/common/addon" "$build_dir/zygisk"
    rm -f "$build_dir/system/placeholder" "$build_dir/common/addon/placeholder" "$build_dir/zygisk/placeholder"

    # Update module.prop for universal compatibility
    local module_prop="$build_dir/module.prop"
    if [ -f "$module_prop" ]; then
        # Update basic properties
        sed -i "s/^id=.*/id=mod_frameworks/" "$module_prop"
        sed -i "s/^name=.*/name=Framework Patch V2/" "$module_prop"
        sed -i "s/^version=.*/version=$version_name/" "$module_prop"
        sed -i "s/^versionCode=.*/versionCode=$version_name/" "$module_prop"
        sed -i "s/^author=.*/author=Jᴇғɪɴᴏ ⚝/" "$module_prop"
        sed -i "s/^description=.*/description=Framework patcher compatible with Magisk, KernelSU (KSU), and SUFS. Patched using jefino9488.github.io\/FrameworkPatcherV2/" "$module_prop"

        # Remove updateJson line
        sed -i "/^updateJson=/d" "$module_prop"

        # Add universal compatibility properties
        {
            echo "minMagisk=20400"
            echo "ksu=1"
            echo "minKsu=10904"
            echo "sufs=1"
            echo "minSufs=10000"
            echo "minApi=34"
            echo "maxApi=34"
            echo "requireReboot=true"
            echo "support=https://t.me/Jefino9488"
        } >>"$module_prop"
    fi

    # Update customize.sh with framework replacements
    local customize_sh="$build_dir/customize.sh"
    if [ -f "$customize_sh" ]; then
        # Replace the empty REPLACE section with our framework files
        sed -i '/^REPLACE="/,/^"/c\
REPLACE="\
/system/framework/framework.jar\
/system/framework/services.jar\
/system/system_ext/framework/miui-services.jar\
"' "$customize_sh"
    fi

    # Create required directories and copy patched files
    mkdir -p "$build_dir/system/framework"
    mkdir -p "$build_dir/system/system_ext/framework"

    # copy patched files (if present in cwd)
    [ -f "framework_patched.jar" ] && cp "framework_patched.jar" "$build_dir/system/framework/framework.jar"
    [ -f "services_patched.jar" ] && cp "services_patched.jar" "$build_dir/system/framework/services.jar"
    [ -f "miui-services_patched.jar" ] && cp "miui-services_patched.jar" "$build_dir/system/system_ext/framework/miui-services.jar"

    # Copy Kaorios Toolbox files if present
    if [ -d "kaorios_toolbox" ]; then
        log "Including Kaorios Toolbox components in module"
        mkdir -p "$build_dir/kaorios"
        
        # Copy APK and permission XML
        [ -f "kaorios_toolbox/KaoriosToolbox.apk" ] && cp "kaorios_toolbox/KaoriosToolbox.apk" "$build_dir/kaorios/"
        [ -f "kaorios_toolbox/privapp_whitelist_com.kousei.kaorios.xml" ] && cp "kaorios_toolbox/privapp_whitelist_com.kousei.kaorios.xml" "$build_dir/kaorios/"
        
        # Data files removed - app fetches from its own repository
        # Version info for tracking
        [ -f "kaorios_toolbox/version.txt" ] && cp "kaorios_toolbox/version.txt" "$build_dir/kaorios/"
        
        log "✓ Kaorios Toolbox files added to module"
    fi

    local safe_version
    safe_version=$(printf "%s" "$version_name" | sed 's/[. ]/-/g')
    local zip_name="Framework-Patcher-${device_name}-${safe_version}.zip"

    if command -v 7z >/dev/null 2>&1; then
        (cd "$build_dir" && 7z a -tzip "../$zip_name" "*" >/dev/null) || {
            err "7z failed to create $zip_name"
            return 1
        }
    elif command -v zip >/dev/null 2>&1; then
        (cd "$build_dir" && zip -r "../$zip_name" . >/dev/null) || {
            err "zip failed to create $zip_name"
            return 1
        }
    else
        err "No archiver found (7z or zip). Install one to create module archive."
        return 1
    fi

    log "Created module: $zip_name"
    echo "$zip_name"
}

# Legacy function for backward compatibility
create_magisk_module() {
    create_module "$1" "$2" "$3" "magisk"
}

create_kaorios_module() {
    local device_name="Generic"
    local version_name="1.0"
    local template_url="https://github.com/Zackptg5/MMT-Extended/archive/refs/heads/master.zip"
    local template_zip="templates/mmt_extended_template.zip"

    log "Creating Kaorios Framework module..."

    local build_dir="build_kaorios_module"
    rm -rf "$build_dir"
    
    # Ensure templates directory exists
    mkdir -p "templates"

    if [ ! -f "$template_zip" ]; then
        log "Downloading MMT-Extended template..."
        if command -v curl >/dev/null 2>&1; then
            curl -L -o "$template_zip" "$template_url" || {
                err "Failed to download template with curl"
                return 1
            }
        elif command -v wget >/dev/null 2>&1; then
            wget -O "$template_zip" "$template_url" || {
                err "Failed to download template with wget"
                return 1
            }
        else
            err "No download tool found (curl or wget)"
            return 1
        fi
    fi

    log "Extracting template..."
    unzip -q "$template_zip" -d "templates_extract_temp"
    
    
    # Move extracted contents to build_dir
    local extracted_root
    extracted_root=$(find "templates_extract_temp" -maxdepth 1 -mindepth 1 -type d | head -n 1)
    
    if [ -n "$extracted_root" ]; then
        mv "$extracted_root" "$build_dir"
    else
        err "Failed to find extracted template root"
        rm -rf "templates_extract_temp"
        return 1
    fi
    rm -rf "templates_extract_temp"

    # Manual Cleanup
    rm -f "$build_dir/README.md" "$build_dir/changelog.md" "$build_dir/LICENSE"
    rm -rf "$build_dir/.git" "$build_dir/.github"
    
    rm -f "$build_dir/config.sh" "$build_dir/customize.sh" "$build_dir/module.prop"
    rm -f "$build_dir/service.sh" "$build_dir/post-fs-data.sh" "$build_dir/system.prop"
    rm -f "$build_dir/sepolicy.rule" "$build_dir/uninstall.sh" "$build_dir/update.json"
    
    rm -rf "$build_dir/common" "$build_dir/system" "$build_dir/zygisk"
    
    
    mkdir -p "$build_dir/system/framework"
    mkdir -p "$build_dir/system/priv-app/KaoriosToolbox/lib"
    mkdir -p "$build_dir/system/etc/permissions"

    mkdir -p "$build_dir/system/etc/permissions"

    cat > "$build_dir/module.prop" <<EOF
id=kaorios_framework
name=Kaorios Framework Patch
version=v${version_name}
versionCode=1
author=Kousei
description=Patched framework.jar with Kaorios Toolbox integration.
minMagisk=20400
EOF

    cat > "$build_dir/customize.sh" <<EOF
SKIPUNZIP=1

# Extract module files
ui_print "- Extracting module files"
unzip -o "\$ZIPFILE" -x 'META-INF/*' -d "\$MODPATH" >&2

# Set permissions
set_perm_recursive "\$MODPATH" 0 0 0755 0644

# Install KaoriosToolbox as user app
if [ -f "\$MODPATH/service.sh" ]; then
  chmod +x "\$MODPATH/service.sh"
fi
EOF

    cat > "$build_dir/system.prop" <<EOF
# Kaorios Toolbox
persist.sys.kaorios=kousei
# Leave the value after the = sign blank.
ro.control_privapp_permissions=
EOF

    cat > "$build_dir/service.sh" <<EOF
#!/system/bin/sh
MODDIR=\${0%/*}

# Wait for boot to complete
while [ "\$(getprop sys.boot_completed)" != "1" ]; do
  sleep 1
done

# Install the APK if not already installed or if updated
APK_PATH="\$MODDIR/system/priv-app/KaoriosToolbox/KaoriosToolbox.apk"
PKG_NAME="com.kousei.kaorios"

if [ -f "\$APK_PATH" ]; then
    # Check if package is installed
    if ! pm list packages | grep -q "\$PKG_NAME"; then
        pm install -r "\$APK_PATH"
    fi
fi
EOF
    chmod +x "$build_dir/service.sh"

    chmod +x "$build_dir/service.sh"

    mkdir -p "$build_dir/system/framework"
    mkdir -p "$build_dir/system/priv-app/KaoriosToolbox/lib"
    mkdir -p "$build_dir/system/etc/permissions"

    mkdir -p "$build_dir/system/etc/permissions"

    if [ -f "framework_patched.jar" ]; then
        cp "framework_patched.jar" "$build_dir/system/framework/framework.jar"
        log "✓ Added framework_patched.jar"
    else
        warn "framework_patched.jar not found!"
    fi
    
     if [ -f "services_patched.jar" ]; then
        cp "services_patched.jar" "$build_dir/system/framework/services.jar"
        log "✓ Added services_patched.jar"
    fi

    local apk_source="kaorios_toolbox/KaoriosToolbox.apk"
    if [ -f "$apk_source" ]; then
        cp "$apk_source" "$build_dir/system/priv-app/KaoriosToolbox/"
        log "✓ Added KaoriosToolbox.apk"

        log "✓ Added KaoriosToolbox.apk"

        # Extract libs
        # We need to determine the architecture or just extract all supported ones
        # For simplicity, let's extract arm64-v8a and armeabi-v7a if present
        
        local temp_extract="temp_apk_extract"
        mkdir -p "$temp_extract"
        unzip -q "$apk_source" "lib/*" -d "$temp_extract" 2>/dev/null
        
        if [ -d "$temp_extract/lib" ]; then
             cp -r "$temp_extract/lib/"* "$build_dir/system/priv-app/KaoriosToolbox/lib/"
             log "✓ Extracted native libraries from APK"
        else
             warn "No native libraries found in APK or extraction failed"
        fi
        rm -rf "$temp_extract"
    else
        warn "KaoriosToolbox.apk not found at $apk_source"
    fi

    local perm_source="kaorios_toolbox/privapp_whitelist_com.kousei.kaorios.xml"
    if [ -f "$perm_source" ]; then
        cp "$perm_source" "$build_dir/system/etc/permissions/"
        log "✓ Added permission XML"
    else
        warn "Permission XML not found at $perm_source"
    fi

    local zip_name="kaoriosFramework.zip"
    rm -f "$zip_name"
    
    if command -v 7z >/dev/null 2>&1; then
        (cd "$build_dir" && 7z a -tzip "../$zip_name" "*" >/dev/null)
    elif command -v zip >/dev/null 2>&1; then
        (cd "$build_dir" && zip -r "../$zip_name" . >/dev/null)
    else
        err "No archiver found (7z or zip)"
        return 1
    fi

    log "Created module: $zip_name"
    echo "$zip_name"
}
