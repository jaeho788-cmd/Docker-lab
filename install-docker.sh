#!/usr/bin/env bash
# =============================================================================
#  install-docker.sh — Ubuntu(WSL 포함)에 Docker Engine 설치
#
#  수업 흐름 대응
#    0-3  사전 패키지 (ca-certificates, curl)
#    2-1  충돌 패키지 정리
#    2-2  Docker 공식 저장소 등록
#    2-3  설치 · 기동 · 확인 (여섯 단계 ①③④)
#
#  사용법
#    chmod +x install-docker.sh
#    ./install-docker.sh
#
#  💾 실행 전 권장 (🪟 PowerShell):
#    wsl --shutdown
#    wsl --export Ubuntu D:\wsl-backup.tar
# =============================================================================
set -euo pipefail

# ---------- 출력 도우미 ----------
C_STEP='\033[1;36m'; C_OK='\033[1;32m'; C_WARN='\033[1;33m'; C_ERR='\033[1;31m'; C_RST='\033[0m'
step() { echo -e "\n${C_STEP}▶ $*${C_RST}"; }
ok()   { echo -e "${C_OK}✔ $*${C_RST}"; }
warn() { echo -e "${C_WARN}⚠ $*${C_RST}"; }
die()  { echo -e "${C_ERR}✘ $*${C_RST}" >&2; exit 1; }

# root 로 실행하면 sudo 없이, 일반 사용자면 sudo 사용
if [[ $EUID -eq 0 ]]; then SUDO=""; else SUDO="sudo"; fi

# ---------- 사전 점검 ----------
step "사전 점검"
[[ -r /etc/os-release ]] || die "/etc/os-release 가 없습니다. Ubuntu 가 맞나요?"
. /etc/os-release
[[ "${ID:-}" == "ubuntu" ]] || die "Ubuntu 전용 스크립트입니다. (감지된 OS: ${ID:-unknown})"
CODENAME="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
ARCH="$(dpkg --print-architecture)"
ok "Ubuntu ${VERSION_ID} (${CODENAME}) / ${ARCH}"

# WSL 이면 systemd 동작 여부 확인 (systemctl enable --now 에 필요)
if grep -qi microsoft /proc/version 2>/dev/null; then
  if [[ "$(ps -p 1 -o comm= 2>/dev/null)" != "systemd" ]]; then
    warn "WSL 에서 systemd 가 꺼져 있습니다."
    warn "/etc/wsl.conf 에 아래를 넣고 PowerShell 에서 'wsl --shutdown' 후 다시 실행하세요."
    echo -e "    [boot]\n    systemd=true"
    die "systemd 필요"
  fi
  ok "WSL + systemd 확인"
fi

# sudo 비밀번호를 미리 한 번 받아 둔다
[[ -n "$SUDO" ]] && $SUDO -v

# ---------- 0-3 사전 패키지 ----------
step "0-3 사전 패키지 설치 (ca-certificates, curl)"
$SUDO apt update
$SUDO apt install -y ca-certificates curl
ok "사전 패키지 준비 완료"

# ---------- 2-1 충돌 패키지 정리 ----------
step "2-1 충돌 패키지 정리"
for p in docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc; do
  if dpkg -s "$p" >/dev/null 2>&1; then
    echo "  - 제거: $p"
    $SUDO apt remove -y "$p"
  else
    echo "  - 없음: $p"
  fi
done
ok "충돌 패키지 정리 완료"

# ---------- 2-2 공식 저장소 등록 ----------
step "2-2 Docker 공식 저장소 등록"
$SUDO install -m 0755 -d /etc/apt/keyrings
$SUDO curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
$SUDO chmod a+r /etc/apt/keyrings/docker.asc

$SUDO tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${CODENAME}
Components: stable
Architectures: ${ARCH}
Signed-By: /etc/apt/keyrings/docker.asc
EOF

$SUDO apt update
ok "저장소 등록 완료 → /etc/apt/sources.list.d/docker.sources"

# ---------- 2-3 설치 · 기동 · 확인 ----------
step "2-3 ① 설치"
$SUDO apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

step "2-3 ③ 기동 (systemctl enable --now docker)"
$SUDO systemctl enable --now docker

step "2-3 ④ 확인"
STATE="$(systemctl is-active docker || true)"
[[ "$STATE" == "active" ]] || die "docker 서비스 상태: ${STATE}  →  'sudo journalctl -u docker' 로 확인하세요."
ok "systemctl is-active docker → ${STATE}"
docker --version
docker compose version

echo
ok "Docker 설치 완료 🐳"
echo "  다음 단계: sudo docker run hello-world"
