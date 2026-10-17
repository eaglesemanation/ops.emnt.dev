#!/bin/bash
set -eu

: "${PRINTER_IP:?set PRINTER_IP to the printer IP address}"
: "${PRINTER_MODEL:?set PRINTER_MODEL to the printer model, e.g. HL-L2390DW}"

# Register the printer with the Brother SANE driver (once per container)
if ! brsaneconfig4 -q | grep -q "$PRINTER_IP"; then
	brsaneconfig4 -a name=BROTHER model="$PRINTER_MODEL" ip="$PRINTER_IP"
fi
brsaneconfig4 -q | tail -3

stopping=0
sleeper=""
shutdown() {
	stopping=1
	[ -n "$sleeper" ] && kill "$sleeper" 2>/dev/null || true # wake the wait below
}
trap shutdown TERM INT

# brscan-skey daemonizes itself, so start it and then watch it
brscan-skey
sleep 2
brscan-skey -l || true
echo "brscan-skey running; waiting for button presses"

while [ "$stopping" = 0 ] && pgrep -f brscan-skey-exe >/dev/null; do
	sleep 30 &
	sleeper=$!
	wait "$sleeper" || true
done

if [ "$stopping" = 1 ]; then
	echo "signal received; stopping brscan-skey"
	pkill -TERM -f brscan-skey-exe || true
	for ((i = 0; i < 10; i++)); do
		pgrep -f brscan-skey-exe >/dev/null || break
		sleep 0.5
	done
	pkill -KILL -f brscan-skey-exe 2>/dev/null || true
	echo "stopped"
	exit 0
fi

echo "brscan-skey exited unexpectedly" >&2
exit 1
