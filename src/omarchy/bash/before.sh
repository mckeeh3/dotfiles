# Timestamp delimiters keep separately saved commands distinct from multiline
# entries. Set this before ble.sh first reads/writes history, not after startup.
HISTTIMEFORMAT='%F %T '

# ble.sh must load before Omarchy initializes Starship and completion.
# Optional: keep a usable shell when the package has not been installed yet.
if [[ -z ${BLE_VERSION:-} && -r /usr/share/blesh/ble.sh && ${TERM:-dumb} != dumb ]]; then
  source /usr/share/blesh/ble.sh --noattach
fi
