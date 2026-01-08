#!/bin/bash
# 𓅈 𓆲 𓅉 𓅂 𓅆 𓅇 𖤍 𓆲 𓅓 🐦‍🔥 𓅃
#    𝕗𝕒𝕝𝕔𝕠𝕟𝟘𝕩𝟙
#    0xDEADBEEF • RED TEAM • PHOENIX OPS
# 𓅈 𓆲 𓅉 𓅂 𓅆 𓅇 𖤍 𓆲 𓅓 🐦‍🔥 𓅃
# FalconServiceAnalyzer – Android Service Attack Surface Analyzer
# Made by: falcon0x1

VERSION="2.0"
ENABLE_JADX=false
TARGET_INPUT=""
INPUT_TYPE=""
START_TIME=$(date +%s)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

BASE_WORK_DIR=""
REPORT_DIR=""
DECOMPILED_DIR=""
MANIFEST=""
SKIP_EXTRACTION=false
PACKAGE_NAME=""

# Colors
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
NC="\033[0m"

print_banner() {
    echo -e "${CYAN}"
    cat << 'BANNER'
╔═══════════════════════════════════════════════════════════╗
║  𓅈 𓆲 𓅉 𓅂 𓅆 𓅇 𖤍 𓆲 𓅓 🐦‍🔥 𓅃                                   ║
║     𝕗𝕒𝕝𝕔𝕠𝕟𝟘𝕩𝟙                                              ║
║     0xDEADBEEF • RED TEAM • PHOENIX OPS                   ║
║  𓅈 𓆲 𓅉 𓅂 𓅆 𓅇 𖤍 𓆲 𓅓 🐦‍🔥 𓅃                                   ║
╠═══════════════════════════════════════════════════════════╣
║  FalconServiceAnalyzer v2.0                               ║
║  Android Service Attack Surface Analyzer                 ║
╚═══════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"
}

print_usage() {
    cat << EOF
${CYAN}╔═══════════════════════════════════════════════════════════╗
║  FalconServiceAnalyzer v${VERSION}                            ║
╚═══════════════════════════════════════════════════════════╝${NC}

${YELLOW}Usage:${NC}
    $0 [OPTIONS] <input>

${YELLOW}Input:${NC}
    • APK file          ${BLUE}→${NC} Will be decompiled automatically
    • Decompiled folder ${BLUE}→${NC} Fast mode (skips decompilation)

${YELLOW}Options:${NC}
    -j, --jadx     Enable Jadx decompilation for exported services
    -h, --help     Show this help message

${YELLOW}Examples:${NC}
    ${GREEN}# Analyze APK${NC}
    $0 app.apk

    ${GREEN}# Fast mode with decompiled folder${NC}
    $0 /path/to/decompiled_app/

    ${GREEN}# With Jadx support${NC}
    $0 -j app.apk

${CYAN}𓅈 Made by falcon0x1 • For authorized security testing only 𓅃${NC}
EOF
}

check_prerequisites() {
    echo -e "${BLUE}[𓅉]${NC} Checking prerequisites..."
    local missing_tools=()

    for tool in python3 jq; do
        if ! command -v "$tool" > /dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [ "$INPUT_TYPE" = "apk" ] && ! command -v apktool > /dev/null 2>&1; then
        missing_tools+=("apktool")
    fi

    if [ "$ENABLE_JADX" = true ] && ! command -v jadx > /dev/null 2>&1; then
        echo -e "${YELLOW}[𓅆]${NC} Jadx requested but not installed"
        missing_tools+=("jadx")
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}[𓅂]${NC} Missing tools: ${missing_tools[*]}"
        echo -e "${YELLOW}[𓆲]${NC} Install: sudo apt install ${missing_tools[*]}"
        return 1
    fi

    echo -e "${GREEN}[𓅇]${NC} All required tools available"
    return 0
}

detect_input_type() {
    if [ -f "$TARGET_INPUT" ]; then
        if [[ "$TARGET_INPUT" =~ \.apk$ ]]; then
            INPUT_TYPE="apk"
            echo -e "${BLUE}[𓅉]${NC} Input detected: APK file"
        else
            echo -e "${RED}[𓅂]${NC} Error: File must be an APK"
            exit 1
        fi
    elif [ -d "$TARGET_INPUT" ]; then
        INPUT_TYPE="folder"
        echo -e "${BLUE}[𓅉]${NC} Input detected: Decompiled folder ${MAGENTA}(fast mode)${NC}"
        if [ -f "$TARGET_INPUT/AndroidManifest.xml" ]; then
            echo -e "${GREEN}[𓅇]${NC} Valid decompiled APK folder"
        else
            echo -e "${RED}[𓅂]${NC} No AndroidManifest.xml found"
            echo -e "${RED}[𓅂]${NC} Not a valid decompiled APK folder"
            exit 1
        fi
    else
        echo -e "${RED}[𓅂]${NC} Input not found: $TARGET_INPUT"
        exit 1
    fi
}

setup_environment() {
    local app_name="unknown"

    if [ "$INPUT_TYPE" = "apk" ]; then
        app_name=$(basename "$TARGET_INPUT" .apk)
        BASE_WORK_DIR="./analysis_${app_name}_${TIMESTAMP}"
        DECOMPILED_DIR="$BASE_WORK_DIR/source"
        SKIP_EXTRACTION=false
    else
        app_name=$(basename "$TARGET_INPUT")
        BASE_WORK_DIR="./analysis_${app_name}_${TIMESTAMP}"
        DECOMPILED_DIR="$(cd "$TARGET_INPUT" && pwd)"
        SKIP_EXTRACTION=true
    fi

    REPORT_DIR="$BASE_WORK_DIR/reports"

    echo -e "${BLUE}[𓅉]${NC} Workspace: $BASE_WORK_DIR"

    mkdir -p "$BASE_WORK_DIR"
    mkdir -p "$REPORT_DIR/json"
    mkdir -p "$REPORT_DIR/html"
    mkdir -p "$REPORT_DIR/attack_scripts"

    if [ "$ENABLE_JADX" = true ]; then
        mkdir -p "$REPORT_DIR/java"
    fi

    echo -e "${CYAN}[🐦‍🔥]${NC} Analysis started at: $(date)"
}

extract_apk() {
    if [ "$SKIP_EXTRACTION" = true ]; then
        echo -e "${GREEN}[𓅇]${NC} Skipping decompilation (using existing folder)"
        MANIFEST="$DECOMPILED_DIR/AndroidManifest.xml"
        if [ ! -L "$BASE_WORK_DIR/source" ]; then
            ln -s "$DECOMPILED_DIR" "$BASE_WORK_DIR/source" 2>/dev/null || true
        fi
        return 0
    fi

    echo -e "${BLUE}[𓅉]${NC} Decompiling APK: $TARGET_INPUT"
    echo -e "${YELLOW}[𓆲]${NC} This may take a moment..."

    if [ ! -f "$TARGET_INPUT" ]; then
        echo -e "${RED}[𓅂]${NC} APK file not found"
        exit 1
    fi

    apktool d "$TARGET_INPUT" -o "$DECOMPILED_DIR" -f > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}[𓅂]${NC} APK decompilation failed"
        exit 1
    fi

    MANIFEST="$DECOMPILED_DIR/AndroidManifest.xml"
    echo -e "${GREEN}[𓅇]${NC} Decompilation complete"
}

extract_package_name() {
    PACKAGE_NAME=$(grep 'package=' "$MANIFEST" | head -1 | grep -o 'package="[^"]*"' | cut -d'"' -f2)
    if [ -z "$PACKAGE_NAME" ]; then
        PACKAGE_NAME="unknown.package"
    fi
    echo -e "${CYAN}[𖤍]${NC} Package: ${GREEN}${PACKAGE_NAME}${NC}"
}

java_to_smali_path() {
    echo "$1" | sed 's/\./\//g'
}

find_smali_file() {
    local smali_base="$1"
    local class_name
    class_name="$(basename "$smali_base")"
    find "$DECOMPILED_DIR" -type f -name "${class_name}.smali" 2>/dev/null | head -1
}

detect_obfuscation() {
    local service_name="$1"
    local score=0

    if [[ "${service_name##*.}" =~ ^[a-z]$ ]] || [[ "${service_name##*.}" =~ ^[A-Z]$ ]]; then
        score=$((score + 30))
    fi

    if [[ "$service_name" =~ ^[a-z]\.[a-z]\.[a-z]$ ]]; then
        score=$((score + 20))
    fi

    [ $score -ge 30 ]
}

detect_vulnerabilities() {
    local service_name="$1"
    local smali_file="$2"
    local vulns=()

    if [ ! -f "$smali_file" ]; then
        echo "[]"
        return
    fi

    if grep -q "Runtime\.exec\|getRuntime()" "$smali_file" 2>/dev/null; then
        vulns+=("Potential RCE via Runtime.exec")
    fi

    if grep -q "getExtras\|getStringExtra\|getIntExtra" "$smali_file" 2>/dev/null; then
        vulns+=("Accepts untrusted input via Intent extras")
    fi

    if grep -q "onBind" "$smali_file" 2>/dev/null \
       && grep -A10 "onBind" "$smali_file" 2>/dev/null | grep -q "return-object.*null"; then
        vulns+=("Exported but onBind returns null")
    fi

    if [ ${#vulns[@]} -gt 0 ]; then
        printf '%s\n' "${vulns[@]}" | jq -R . | jq -s .
    else
        echo "[]"
    fi
}

generate_html_report() {
    local json_file="$1"
    local output_file="$2"

    cat > "$output_file" << 'HTMLEOF'
<!DOCTYPE html>
<html dir="ltr">
<head>
    <meta charset="UTF-8">
    <title>FalconServiceAnalyzer Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
            color: #f1f5f9;
            padding: 20px;
            min-height: 100vh;
        }
        .header {
            text-align: center;
            margin-bottom: 40px;
            padding: 30px;
            background: rgba(15, 23, 42, 0.6);
            border-radius: 16px;
            backdrop-filter: blur(10px);
        }
        .falcon-banner {
            font-size: 1.3em;
            margin-bottom: 12px;
            letter-spacing: 2px;
        }
        .header-title {
            font-size: 2.5em;
            font-weight: 700;
            margin: 10px 0;
            background: linear-gradient(135deg, #60a5fa 0%, #a78bfa 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .header-sub {
            font-size: 1.1em;
            opacity: 0.85;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        .stats {
            background: linear-gradient(135deg, #1e293b 0%, #334155 100%);
            padding: 30px;
            border-radius: 16px;
            margin-bottom: 30px;
            border: 1px solid #334155;
        }
        .stats h3 {
            margin-bottom: 20px;
            font-size: 1.3em;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
        }
        .stat-box {
            background: rgba(51, 65, 85, 0.5);
            padding: 20px;
            border-radius: 12px;
            text-align: center;
            border: 1px solid #475569;
        }
        .stat-number {
            font-size: 2.5em;
            font-weight: 700;
            margin-bottom: 8px;
            background: linear-gradient(135deg, #60a5fa 0%, #a78bfa 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .stat-label {
            font-size: 0.95em;
            opacity: 0.9;
        }

        .card {
            background: #1e293b;
            border: 1px solid #334155;
            padding: 24px;
            margin-bottom: 20px;
            border-radius: 14px;
            border-left: 5px solid #3b82f6;
            transition: all 0.3s ease;
        }
        .card:hover {
            transform: translateY(-4px);
            box-shadow: 0 12px 40px rgba(59, 130, 246, 0.3);
            border-left-color: #60a5fa;
        }
        .exported-true {
            border-left-color: #ef4444;
            background: linear-gradient(135deg, #1e293b 0%, #371e23 100%);
        }
        .exported-true:hover {
            box-shadow: 0 12px 40px rgba(239, 68, 68, 0.3);
        }

        .service-header {
            margin-bottom: 16px;
        }
        .service-name {
            font-size: 1.2em;
            font-weight: 600;
            color: #f1f5f9;
            word-break: break-all;
            margin-bottom: 8px;
        }

        .tag {
            background: #334155;
            padding: 6px 14px;
            border-radius: 20px;
            font-size: 0.85em;
            margin-right: 8px;
            margin-bottom: 8px;
            display: inline-block;
            border: 1px solid #475569;
        }
        .tag-type { 
            background: #1e40af; 
            border-color: #3b82f6;
            color: #dbeafe;
        }
        .tag-exported { 
            background: #991b1b; 
            border-color: #ef4444;
            color: #fee2e2;
        }
        .tag-obfuscated { 
            background: #92400e; 
            border-color: #f59e0b;
            color: #fef3c7;
        }

        .attack-section {
            background: rgba(51, 65, 85, 0.4);
            border-radius: 12px;
            padding: 18px;
            margin-top: 18px;
            border: 1px solid #475569;
        }
        .attack-section h4 {
            margin-bottom: 12px;
            font-size: 1.05em;
            color: #60a5fa;
        }
        .attack-command {
            background: #0f172a;
            color: #6ee7b7;
            padding: 12px 16px;
            border-radius: 8px;
            font-family: "SF Mono", "Monaco", "Inconsolata", "Fira Code", "Courier New", monospace;
            font-size: 0.9em;
            margin: 10px 0;
            word-break: break-all;
            border: 1px solid #1e293b;
        }
        .attack-note {
            margin-top: 10px;
            font-size: 0.88em;
            color: #cbd5e1;
            line-height: 1.5;
        }

        .vuln {
            color: #fca5a5;
            font-weight: 600;
            margin-top: 18px;
            margin-bottom: 8px;
        }
        .vuln-list {
            background: rgba(153, 27, 27, 0.2);
            padding: 12px 16px;
            border-radius: 8px;
            border-left: 3px solid #ef4444;
        }
        .vuln-list ul {
            margin-left: 20px;
            line-height: 1.6;
        }

        .no-services {
            text-align: center;
            padding: 80px 20px;
            color: #94a3b8;
        }
        .no-services-icon {
            font-size: 4em;
            margin-bottom: 20px;
        }

        .footer {
            text-align: center;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #334155;
            color: #94a3b8;
            font-size: 0.9em;
        }
        .footer a {
            color: #60a5fa;
            text-decoration: none;
        }
        .footer a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="falcon-banner">𓅈 𓆲 𓅉 𓅂 𓅆 𓅇 𖤍 𓆲 𓅓 🐦‍🔥 𓅃</div>
        <div class="header-title">FalconServiceAnalyzer</div>
        <div class="header-sub">Android Service Attack Surface Analyzer</div>
    </div>

    <div class="container">
        <div class="stats" id="stats"></div>
        <div id="content"></div>

        <div class="footer">
            <div style="margin-bottom: 8px;">𓅈 𓆲 𓅉 𓅂 𓅆 𓅇 𖤍 𓆲 𓅓 🐦‍🔥 𓅃</div>
            <div>FalconServiceAnalyzer v2.0 • Made by <strong>falcon0x1</strong></div>
            <div style="margin-top: 8px; font-size: 0.85em;">For authorized security testing only</div>
        </div>
    </div>

    <script>
HTMLEOF

    echo "        const data = $(cat "$json_file");" >> "$output_file"

    cat >> "$output_file" << 'HTMLEOF'
        const container = document.getElementById('content');
        const stats = document.getElementById('stats');

        const totalServices = data.services.length;
        const exportedServices = data.services.filter(s => s.exported).length;
        const obfuscatedServices = data.services.filter(s => s.obfuscated).length;
        const vulnerableServices = data.services.filter(s => s.vulnerabilities.length > 0).length;

        stats.innerHTML = `
            <h3>𖤍 Service Statistics</h3>
            <div class="stats-grid">
                <div class="stat-box">
                    <div class="stat-number">${totalServices}</div>
                    <div class="stat-label">Total Services</div>
                </div>
                <div class="stat-box">
                    <div class="stat-number">${exportedServices}</div>
                    <div class="stat-label">Exported</div>
                </div>
                <div class="stat-box">
                    <div class="stat-number">${obfuscatedServices}</div>
                    <div class="stat-label">Obfuscated</div>
                </div>
                <div class="stat-box">
                    <div class="stat-number">${vulnerableServices}</div>
                    <div class="stat-label">With Findings</div>
                </div>
            </div>
        `;

        if (totalServices === 0) {
            container.innerHTML = `
                <div class="no-services">
                    <div class="no-services-icon">𓅃</div>
                    <h2>No Services Found</h2>
                    <p style="margin-top: 12px;">This application does not declare any services in AndroidManifest.xml</p>
                </div>
            `;
        } else {
            data.services.forEach((s, idx) => {
                let html = `<div class="card ${s.exported ? 'exported-true' : ''}">
                    <div class="service-header">
                        <div class="service-name">𓅉 ${s.name}</div>
                    </div>
                    <div>
                        <span class="tag tag-type">Type: ${s.type}</span>
                        <span class="tag ${s.exported ? 'tag-exported' : ''}">Exported: ${s.exported}</span>
                        <span class="tag ${s.obfuscated ? 'tag-obfuscated' : ''}">Obfuscated: ${s.obfuscated}</span>
                        ${s.permission ? `<span class="tag">Permission: ${s.permission}</span>` : ''}
                    </div>`;

                if (s.exported && s.attack_commands && (s.attack_commands.adb || s.attack_commands.note)) {
                    html += `<div class="attack-section">
                        <h4>🐦‍🔥 Attack Surface</h4>`;

                    if (s.attack_commands.adb) {
                        html += `
                            <div class="attack-command">${s.attack_commands.adb}</div>
                        `;
                    }

                    if (s.attack_commands.note) {
                        html += `<div class="attack-note">𓆲 ${s.attack_commands.note}</div>`;
                    }

                    html += `</div>`;
                }

                if (s.vulnerabilities.length > 0) {
                    html += '<div class="vuln">𓅂 Potential Issues:</div>';
                    html += '<div class="vuln-list"><ul>';
                    s.vulnerabilities.forEach(v => html += `<li>${v}</li>`);
                    html += '</ul></div>';
                }

                html += `</div>`;
                container.innerHTML += html;
            });
        }
    </script>
</body>
</html>
HTMLEOF
}

main_analysis() {
    echo
    echo -e "${CYAN}[🐦‍🔥]${NC} Starting static analysis..."

    if [ ! -f "$MANIFEST" ]; then
        echo -e "${RED}[𓅂]${NC} Manifest not found at $MANIFEST"
        exit 1
    fi

    extract_package_name

    local service_count
    service_count=$(grep -o "<service" "$MANIFEST" | wc -l)

    echo
    echo -e "${BLUE}[𖤍]${NC} Manifest components:"
    local activity_count receiver_count provider_count
    activity_count=$(grep -o "<activity" "$MANIFEST" | wc -l)
    receiver_count=$(grep -o "<receiver" "$MANIFEST" | wc -l)
    provider_count=$(grep -o "<provider" "$MANIFEST" | wc -l)

    echo -e "    ${CYAN}Activities${NC}: $activity_count"
    echo -e "    ${CYAN}Services${NC}  : $service_count"
    echo -e "    ${CYAN}Receivers${NC} : $receiver_count"
    echo -e "    ${CYAN}Providers${NC} : $provider_count"
    echo

    if [ "$service_count" -eq 0 ]; then
        echo -e "${YELLOW}[𓅆]${NC} No services found in AndroidManifest.xml"
        echo '{"services": []}' > "$REPORT_DIR/json/final_report.json"
        generate_html_report "$REPORT_DIR/json/final_report.json" "$REPORT_DIR/html/index.html"
        return 0
    fi

    local counter=0

    grep -n "<service" "$MANIFEST" | while IFS=: read -r line_num line_content; do
        counter=$((counter + 1))

        local service_block
        service_block=$(sed -n "${line_num},/\/service\|\/>/p" "$MANIFEST")

        local name
        name=$(echo "$service_block" | grep -o 'android:name="[^"]*"' | head -1 | cut -d'"' -f2)

        if [[ "$name" =~ ^\. ]]; then
            name="${PACKAGE_NAME}${name}"
        fi

        if [ -z "$name" ]; then
            continue
        fi

        echo -e "${GREEN}[𓅉]${NC} Service #$counter: ${BLUE}$name${NC}"

        local exported="false"
        if echo "$service_block" | grep -q 'android:exported="true"'; then
            exported="true"
            echo -e "    ${RED}[𓅂]${NC} Exported: ${RED}true${NC}"
        fi

        local permission
        permission=$(echo "$service_block" | grep -o 'android:permission="[^"]*"' | cut -d'"' -f2)

        if [ -n "$permission" ]; then
            echo -e "    ${YELLOW}[𓆲]${NC} Permission: $permission"
        fi

        local smali_path smali_file
        smali_path=$(java_to_smali_path "$name")
        smali_file=$(find_smali_file "$smali_path")

        local type="unknown"
        if [ -n "$smali_file" ] && [ -f "$smali_file" ]; then
            if grep -q "onStartCommand" "$smali_file" 2>/dev/null; then
                type="started"
            fi
            if grep -q "onBind" "$smali_file" 2>/dev/null; then
                if [ "$type" = "started" ]; then
                    type="hybrid"
                else
                    type="bound"
                fi
                if grep -q "\$Stub" "$smali_file" 2>/dev/null; then
                    type="bound (AIDL)"
                fi
                if grep -q "Messenger" "$smali_file" 2>/dev/null; then
                    type="bound (Messenger)"
                fi
            fi
        fi

        echo -e "    ${CYAN}[𖤍]${NC} Type: $type"

        local obfuscated="false"
        if detect_obfuscation "$name"; then
            obfuscated="true"
            echo -e "    ${YELLOW}[𓅆]${NC} Obfuscated: true"
        fi

        local vulns_json="[]"
        if [ -n "$smali_file" ] && [ -f "$smali_file" ]; then
            vulns_json=$(detect_vulnerabilities "$name" "$smali_file")
            local vuln_count
            vuln_count=$(echo "$vulns_json" | jq 'length')
            if [ "$vuln_count" -gt 0 ]; then
                echo -e "    ${RED}[𓅂]${NC} Findings: $vuln_count potential issue(s)"
            fi
        fi

        local attack_commands="{}"
        if [ "$exported" = "true" ]; then
            local adb_cmd=""
            local note=""

            case "$type" in
                started)
                    adb_cmd="adb shell am start-service -n ${PACKAGE_NAME}/${name}"
                    echo -e "    ${MAGENTA}[🐦‍🔥]${NC} Attack: ${GREEN}$adb_cmd${NC}"
                    ;;
                hybrid)
                    adb_cmd="adb shell am start-service -n ${PACKAGE_NAME}/${name}"
                    note="Hybrid service. ADB triggers onStartCommand; bound interface may need custom client."
                    echo -e "    ${MAGENTA}[🐦‍🔥]${NC} Attack: ${GREEN}$adb_cmd${NC}"
                    ;;
                bound*)
                    adb_cmd=""
                    note="Bound service. Requires client PoC or binder/Frida script, not simple ADB command."
                    echo -e "    ${YELLOW}[𓆲]${NC} Note: Bound service - needs PoC/Frida"
                    ;;
            esac

            if [ -n "$permission" ]; then
                if [ -n "$note" ]; then
                    note="${note} Requires permission: ${permission}."
                else
                    note="Requires permission: ${permission}."
                fi
            fi

            attack_commands=$(jq -n \
                --arg adb "$adb_cmd" \
                --arg note "$note" \
                '{adb: (if $adb != "" then $adb else null end),
                  note: (if $note != "" then $note else null end)}')
        fi

        local json_obj
        json_obj=$(jq -n \
            --arg id "$counter" \
            --arg name "$name" \
            --argjson exported "$exported" \
            --arg type "$type" \
            --argjson obfuscated "$obfuscated" \
            --argjson vulns "$vulns_json" \
            --arg permission "$permission" \
            --argjson attack_commands "$attack_commands" \
            '{id: ($id | tonumber),
              name: $name,
              exported: $exported,
              type: $type,
              obfuscated: $obfuscated,
              vulnerabilities: $vulns,
              permission: $permission,
              attack_commands: $attack_commands}')

        echo "$json_obj" > "$REPORT_DIR/json/service_${counter}.json"
        echo
    done

    echo -e "${BLUE}[𓅉]${NC} Generating reports..."

    if ls "$REPORT_DIR/json"/service_*.json > /dev/null 2>&1; then
        jq -n '{services: [inputs]}' "$REPORT_DIR/json"/service_*.json > "$REPORT_DIR/json/final_report.json"
        generate_html_report "$REPORT_DIR/json/final_report.json" "$REPORT_DIR/html/index.html"
        local final_count
        final_count=$(ls "$REPORT_DIR/json"/service_*.json 2>/dev/null | wc -l)
        echo -e "${GREEN}[𓅇]${NC} Successfully analyzed $final_count service(s)"
    else
        echo '{"services": []}' > "$REPORT_DIR/json/final_report.json"
        generate_html_report "$REPORT_DIR/json/final_report.json" "$REPORT_DIR/html/index.html"
    fi
}

main() {
    print_banner

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -j|--jadx) ENABLE_JADX=true ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            -*)
                echo -e "${RED}[𓅂]${NC} Unknown option: $1"
                echo
                print_usage
                exit 1
                ;;
            *)
                TARGET_INPUT="$1"
                ;;
        esac
        shift
    done

    if [ -z "$TARGET_INPUT" ]; then
        echo -e "${RED}[𓅂]${NC} No input specified"
        echo
        print_usage
        exit 1
    fi

    detect_input_type
    check_prerequisites || exit 1
    setup_environment
    extract_apk
    main_analysis

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - START_TIME))

    echo
    echo -e "${GREEN}[𓅇]${NC} Analysis complete"
    echo -e "${CYAN}[🐦‍🔥]${NC} Execution time: ${duration}s"
    echo -e "${BLUE}[𖤍]${NC} Output: $BASE_WORK_DIR"
    echo -e "${BLUE}[𖤍]${NC} HTML  : $REPORT_DIR/html/index.html"
    echo -e "${BLUE}[𖤍]${NC} JSON  : $REPORT_DIR/json/final_report.json"
    echo
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  𓅈 𓆲 𓅉 𓅂 𓅆 𓅇 𖤍 𓆲 𓅓 🐦‍🔥 𓅃  Analysis complete                ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
}

main "$@"
