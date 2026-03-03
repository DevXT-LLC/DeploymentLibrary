#!/bin/bash
# Deploy ezlocalai - Local AI Inference Server
# Clones ezlocalai, creates a Python venv, installs it, configures env vars, and starts the server.
# The ezlocalai CLI handles platform detection (Docker vs native for ARM64/Jetson).
set -e

INSTALL_DIR="${EZLOCALAI_INSTALL_DIR:-/opt/ezlocalai}"
DEFAULT_MODEL="${EZLOCALAI_DEFAULT_MODEL:-unsloth/Qwen3.5-4B-GGUF}"
LLM_MAX_TOKENS="${EZLOCALAI_MAX_TOKENS:-40000}"
EZLOCALAI_PORT="${EZLOCALAI_PORT:-8091}"
EZLOCALAI_API_KEY="${EZLOCALAI_API_KEY:-}"
WHISPER_MODEL="${EZLOCALAI_WHISPER_MODEL:-large-v3}"
IMG_MODEL="${EZLOCALAI_IMG_MODEL:-Tongyi-MAI/Z-Image-Turbo}"
TTS_ENABLED="${EZLOCALAI_TTS_ENABLED:-true}"
STT_ENABLED="${EZLOCALAI_STT_ENABLED:-true}"
QUANT_TYPE="${EZLOCALAI_QUANT_TYPE:-Q4_K_XL}"
LLM_BATCH_SIZE="${EZLOCALAI_BATCH_SIZE:-2048}"
VOICE_SERVER="${EZLOCALAI_VOICE_SERVER:-}"
PYTHON_VERSION="${PYTHON_VERSION:-3.11}"
REPO_URL="https://github.com/DevXT-LLC/ezlocalai.git"

# If IMG_MODEL doesn't contain a "/", treat it as disabled (empty)
if [[ "${IMG_MODEL}" != */* ]]; then
    IMG_MODEL=""
fi

echo "============================================="
echo "  ezlocalai Deployment Script"
echo "============================================="
echo ""
echo "Install directory: ${INSTALL_DIR}"
echo "Default model:     ${DEFAULT_MODEL}"
echo "Max tokens:        ${LLM_MAX_TOKENS}"
echo "Port:              ${EZLOCALAI_PORT}"
echo ""

# ------------------------------------------------------------------
# 1. Ensure Python is available
# ------------------------------------------------------------------
PYTHON_CMD=""
for candidate in "python${PYTHON_VERSION}" "python3" "python"; do
    if command -v "$candidate" &>/dev/null; then
        PYTHON_CMD="$candidate"
        break
    fi
done

if [ -z "$PYTHON_CMD" ]; then
    echo "ERROR: Python not found. Please install Python ${PYTHON_VERSION}+ first."
    echo "You can use the 'install-python' deployment script."
    exit 1
fi

PYTHON_VER=$("$PYTHON_CMD" --version 2>&1 | awk '{print $2}')
echo "Using Python: ${PYTHON_CMD} (${PYTHON_VER})"

# Ensure python3-venv package is available on Debian/Ubuntu
if command -v apt-get &>/dev/null; then
    if ! "$PYTHON_CMD" -m venv --help &>/dev/null 2>&1; then
        echo "Installing python3-venv package..."
        sudo apt-get update -qq
        sudo apt-get install -y "python${PYTHON_VERSION}-venv" 2>/dev/null || \
            sudo apt-get install -y python3-venv 2>/dev/null || true
    fi
fi

# ------------------------------------------------------------------
# 2. Ensure git is available
# ------------------------------------------------------------------
if ! command -v git &>/dev/null; then
    echo "ERROR: git is not installed. Please install git first."
    echo "You can use the 'install-git' deployment script."
    exit 1
fi

# ------------------------------------------------------------------
# 3. Clone or update the repository
# ------------------------------------------------------------------
if [ -d "${INSTALL_DIR}/.git" ]; then
    echo "Updating existing ezlocalai installation..."
    cd "${INSTALL_DIR}"
    git pull --ff-only || {
        echo "WARNING: git pull failed, continuing with existing code."
    }
else
    echo "Cloning ezlocalai repository..."
    sudo mkdir -p "$(dirname "${INSTALL_DIR}")"
    sudo git clone "${REPO_URL}" "${INSTALL_DIR}"
    sudo chown -R "$(whoami):$(id -gn)" "${INSTALL_DIR}"
    cd "${INSTALL_DIR}"
fi

# Ensure the install directory is owned by the current user
if [ -d "${INSTALL_DIR}" ] && [ ! -w "${INSTALL_DIR}" ]; then
    echo "Fixing ownership of ${INSTALL_DIR}..."
    sudo chown -R "$(whoami):$(id -gn)" "${INSTALL_DIR}"
fi

# ------------------------------------------------------------------
# 4. Create / update virtual environment
# ------------------------------------------------------------------
VENV_DIR="${INSTALL_DIR}/.venv"
if [ ! -d "${VENV_DIR}" ]; then
    echo "Creating virtual environment..."
    "$PYTHON_CMD" -m venv "${VENV_DIR}"
fi

# Activate venv
source "${VENV_DIR}/bin/activate"
echo "Virtual environment active: ${VENV_DIR}"

# Upgrade pip
pip install --upgrade pip -q

# ------------------------------------------------------------------
# 5. Install ezlocalai in editable mode + dependencies
# ------------------------------------------------------------------
echo "Installing ezlocalai..."
cd "${INSTALL_DIR}"
pip install -e . -q

# Install runtime dependencies (requirements.txt has uvicorn, fastapi, etc.)
# The ezlocalai CLI will handle GPU-specific deps (xllamacpp, etc.) on first start
if [ -f "${INSTALL_DIR}/requirements.txt" ]; then
    echo "Installing runtime dependencies..."
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        # On ARM64, try batch first (preserves pip version resolver),
        # fall back to individual install if batch fails.
        if pip install -r "${INSTALL_DIR}/requirements.txt" -q 2>/dev/null; then
            echo "All packages installed successfully."
        else
            echo "Batch install failed, installing packages individually..."
            FAILED_PKGS=()
            while IFS= read -r line; do
                line=$(echo "$line" | xargs)  # trim whitespace
                [[ -z "$line" || "$line" == \#* ]] && continue
                # Strip inline comments (e.g. "package>=1.0  # description")
                line=$(echo "$line" | sed 's/ #.*$//')
                [[ -z "$line" ]] && continue
                pip install "$line" -q 2>/dev/null || FAILED_PKGS+=("$line")
            done < "${INSTALL_DIR}/requirements.txt"
            if [ ${#FAILED_PKGS[@]} -gt 0 ]; then
                echo "⚠️  ${#FAILED_PKGS[@]} package(s) skipped (no ARM64 wheel):"
                for pkg in "${FAILED_PKGS[@]}"; do
                    echo "   - $pkg"
                done
            fi
        fi
    else
        pip install -r "${INSTALL_DIR}/requirements.txt" -q 2>&1 | tail -5 || true
    fi
fi

# ------------------------------------------------------------------
# 6. Write environment configuration
# ------------------------------------------------------------------
ENV_FILE="${INSTALL_DIR}/.env"
echo "Writing environment configuration to ${ENV_FILE}..."

cat > "${ENV_FILE}" <<ENVEOF
# ezlocalai configuration - generated by deployment script
DEFAULT_MODEL=${DEFAULT_MODEL}
LLM_MAX_TOKENS=${LLM_MAX_TOKENS}
EZLOCALAI_URL=http://0.0.0.0:${EZLOCALAI_PORT}
EZLOCALAI_API_KEY=${EZLOCALAI_API_KEY}
WHISPER_MODEL=${WHISPER_MODEL}
IMG_MODEL=${IMG_MODEL}
TTS_ENABLED=${TTS_ENABLED}
STT_ENABLED=${STT_ENABLED}
QUANT_TYPE=${QUANT_TYPE}
LLM_BATCH_SIZE=${LLM_BATCH_SIZE}
VOICE_SERVER=${VOICE_SERVER}
ENVEOF

echo "Configuration written."

echo ""
echo "============================================="
echo "  ezlocalai Deployment Complete!"
echo "============================================="
echo ""
echo "Installation directory: ${INSTALL_DIR}"
echo "Virtual environment:    ${VENV_DIR}"
echo "Configuration file:     ${ENV_FILE}"
echo ""
echo "Management commands (activate venv first):"
echo "  source ${VENV_DIR}/bin/activate"
echo "  ezlocalai start        # Start the server"
echo "  ezlocalai stop         # Stop the server"
echo "  ezlocalai restart      # Restart the server"
echo "  ezlocalai status       # Check server status"
echo "  ezlocalai logs -f      # Follow server logs"
echo ""
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || ip route get 1 2>/dev/null | awk '{print $7; exit}' || echo "localhost")
echo "Server will be available at: http://${LOCAL_IP}:${EZLOCALAI_PORT}"

# ------------------------------------------------------------------
# 7. Start the server
# ------------------------------------------------------------------
echo ""
echo "Starting ezlocalai..."
cd "${INSTALL_DIR}"
ezlocalai start --model "${DEFAULT_MODEL}"
