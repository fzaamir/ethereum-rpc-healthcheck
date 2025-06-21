#!/usr/bin/env bash
set -euo pipefail

REQUIRED_TOOLS=(curl jq awk bc)
MISSING=()
for t in "${REQUIRED_TOOLS[@]}"; do
  command -v "$t" >/dev/null 2>&1 || MISSING+=("$t")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "Installing missing tools: ${MISSING[*]}"
  if command -v apt >/dev/null 2>&1; then
    apt update -qq
    apt install -y -qq "${MISSING[@]}"
  else
    echo "Unsupported package manager. Please install: ${MISSING[*]}"
    exit 1
  fi
fi

N=10
PAUSE=1
ip=$(ip -4 route get 1 | awk '{for(i=1;i<=NF;i++)if($i=="src"){print $(i+1);exit}}' 2>/dev/null || echo 127.0.0.1)
EXEC="http://${ip}:8545"
BEACON="http://${ip}:3500"
TIMEOUT=3
if command -v tput &>/dev/null; then g=$(tput setaf 2) r=$(tput setaf 1) c=$(tput setaf 6) b=$(tput bold) x=$(tput sgr0); else g= r= c= b= x=; fi
jr(){ curl -m "$TIMEOUT" -s -o /dev/null -w '%{time_total}' -H 'Content-Type: application/json' --data '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}' "$EXEC"; }
br(){ curl -m "$TIMEOUT" -s -o /dev/null -w '%{time_total}' "$BEACON/eth/v1/node/health"; }
json(){ curl -m "$TIMEOUT" -s "$1" | jq -r "$2"; }
sum(){ awk '{s+=$1}END{print s}'; }
stats(){ readarray -t a; printf '%s %s %s %s\n' "$(printf '%s\n' "${a[@]}"|sort -n|head -1)" "$(printf '%s\n' "${a[@]}"|awk '{s+=$1}END{printf "%.3f",s/NR}')" "$(printf '%s\n' "${a[@]}"|sort -n|tail -1)" "${#a[@]}"; }
declare -a e_lat p_lat
e_ok=0; p_ok=0
for((i=1;i<=N;i++)); do
  e_t=$(jr 2>/dev/null || echo FAIL); p_t=$(br 2>/dev/null || echo FAIL)
  [[ $e_t != FAIL ]] && { e_lat+=("$e_t"); ((e_ok++)); }
  [[ $p_t != FAIL ]] && { p_lat+=("$p_t"); ((p_ok++)); }
  sleep "$PAUSE"
done
read e_min e_avg e_max e_cnt < <(printf '%s\n' "${e_lat[@]}" | stats)
read p_min p_avg p_max p_cnt < <(printf '%s\n' "${p_lat[@]}" | stats)
e_block_hex=$(json "$EXEC" '.result' 2>/dev/null || echo 0x0); e_block=$((16#${e_block_hex#0x}))
p_slot=$(json "$BEACON/eth/v1/beacon/headers/head" '.data.header.message.slot' 2>/dev/null || echo 0)
p_health_code=$(json "$BEACON/eth/v1/node/health" '.data|tonumber? // .data.health_status' 2>/dev/null || echo -1)
case $p_health_code in 0) p_health=OK;;1) p_health=Syncing;;2) p_health=Error;;*) p_health=Unknown($p_health_code);; esac
printf "\n${b}============== Sepolia Node Health (10-sec test) ==============${x}\n"
printf "${b}Execution RPC${x}  : %s\n" "$EXEC"
printf "  success          : %s/%s\n" "$e_ok" "$N"
printf "  latency s        : min %.3f  avg %.3f  max %.3f\n" "${e_min:-nan}" "${e_avg:-nan}" "${e_max:-nan}"
printf "  latest block     : %'d\n" "$e_block"
printf "\n${b}Beacon REST${x}    : %s\n" "$BEACON"
printf "  success          : %s/%s\n" "$p_ok" "$N"
printf "  latency s        : min %.3f  avg %.3f  max %.3f\n" "${p_min:-nan}" "${p_avg:-nan}" "${p_max:-nan}"
printf "  head slot        : %'d\n" "$p_slot"
printf "  health           : %s%s%s\n" "$( [[ $p_health == OK ]] && echo "${g}" || ([[ $p_health == Syncing ]] && echo "${c}" || echo "${r}" ))" "$p_health" "${x}"
[[ $e_ok -eq $N && $p_health == OK && $p_ok -eq $N ]] && overall="${g}PASS${x}" || overall="${r}ATTENTION${x}"
printf "\nOverall : %b\n" "$overall"
printf "===============================================================\n"
exit 0
