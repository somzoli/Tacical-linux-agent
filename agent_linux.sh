#!/usr/bin/env bash

if [ $EUID -ne 0 ]; then
    echo "ERROR: Must be run as root"
    exit 1
fi

HAS_SYSTEMD=$(ps --no-headers -o comm 1)
if [ "${HAS_SYSTEMD}" != 'systemd' ]; then
    echo "This install script only supports systemd"
    echo "Please install systemd or manually create the service using your systems's service manager"
    exit 1
fi

if [[ $DISPLAY ]]; then
    echo "ERROR: Display detected. Installer only supports running headless, i.e from ssh."
    echo "If you cannot ssh in then please run 'sudo systemctl isolate multi-user.target' to switch to a non-graphical user session and run the installer again."
    exit 1
fi

DEBUG=0
INSECURE=0
NOMESH=0
UPDATE=0

if [ $UPDATE -eq 1 ]; then
  systemctl stop tacticalagent
fi

meshDL='MESHDLURL'

apiURL='https://SERVER'
token='TOKEN'
clientID='1'
siteID='1'
agentType='workstation'
proxy=''

agentBinPath='/usr/local/bin'
binName='tacticalagent'
agentBin="${agentBinPath}/${binName}"
agentConf='/etc/tacticalagent'
agentSvcName='tacticalagent.service'
agentSysD="/etc/systemd/system/${agentSvcName}"
meshDir='/opt/tacticalmesh'
meshSystemBin="${meshDir}/meshagent"
meshSvcName='meshagent.service'
meshSysD="/lib/systemd/system/${meshSvcName}"

deb=(ubuntu debian raspbian kali linuxmint)
rhe=(fedora rocky centos rhel amzn arch opensuse)

set_locale_deb() {
    locale-gen "en_US.UTF-8"
    localectl set-locale LANG=en_US.UTF-8
    . /etc/default/locale
}

set_locale_rhel() {
    localedef -c -i en_US -f UTF-8 en_US.UTF-8 >/dev/null 2>&1
    localectl set-locale LANG=en_US.UTF-8
    . /etc/locale.conf
}

RemoveOldAgent() {
    if [ -f "${agentSysD}" ]; then
        systemctl disable ${agentSvcName}
        systemctl stop ${agentSvcName}
        rm -f ${agentSysD}
        systemctl daemon-reload
    fi

    if [ -f "${agentConf}" ]; then
        rm -f ${agentConf}
    fi

    if [ -f "${agentBin}" ]; then
        rm -f ${agentBin}
    fi
}

InstallMesh() {
    if [ -f /etc/os-release ]; then
        distroID=$(
            . /etc/os-release
            echo $ID
        )
        distroIDLIKE=$(
            . /etc/os-release
            echo $ID_LIKE
        )
        if [[ " ${deb[*]} " =~ " ${distroID} " ]]; then
            set_locale_deb
        elif [[ " ${deb[*]} " =~ " ${distroIDLIKE} " ]]; then
            set_locale_deb
        elif [[ " ${rhe[*]} " =~ " ${distroID} " ]]; then
            set_locale_rhel
        else
            set_locale_rhel
        fi
    fi

    meshTmpDir='/root/meshtemp'
    mkdir -p $meshTmpDir

    meshTmpBin="${meshTmpDir}/meshagent"
    wget --no-check-certificate -q -O ${meshTmpBin} ${meshDL}
    chmod +x ${meshTmpBin}
    mkdir -p ${meshDir}
    env LC_ALL=en_US.UTF-8 LANGUAGE=en_US XAUTHORITY=foo DISPLAY=bar ${meshTmpBin} -install --installPath=${meshDir}
    sleep 1
    rm -rf ${meshTmpDir}
}

RemoveMesh() {
    if [ -f "${meshSystemBin}" ]; then
        env XAUTHORITY=foo DISPLAY=bar ${meshSystemBin} -uninstall
        sleep 1
    fi

    if [ -f "${meshSysD}" ]; then
        systemctl stop ${meshSvcName} >/dev/null 2>&1
        systemctl disable ${meshSvcName} >/dev/null 2>&1
        rm -f ${meshSysD}
    fi

    rm -rf ${meshDir}
    systemctl daemon-reload
}

Uninstall() {
    RemoveMesh
    RemoveOldAgent
}

if [ $# -ne 0 ] && [ $UPDATE -eq 0 ] && [ $1 == 'uninstall' ]; then
    Uninstall
    exit 0
fi

while [[ "$#" -gt 0 ]]; do
    case $1 in
    --debug) DEBUG=1 ;;
    --insecure) INSECURE=1 ;;
    --nomesh) NOMESH=1 ;;
    *)
        echo "ERROR: Unknown parameter: $1"
        exit 1
        ;;
    esac
    shift
done


#echo "Downloading tactical agent..."
#wget -q -O ${agentBin} "${agentDL}"
#if [ $? -ne 0 ]; then
#    echo "ERROR: Unable to download tactical agent"
#    exit 1
#fi
#chmod +x ${agentBin}

# GO INSTALL
go_url_amd64="https://go.dev/dl/go1.18.3.linux-amd64.tar.gz"
go_url_x86="https://go.dev/dl/go1.18.3.linux-386.tar.gz"
go_url_arm64="https://go.dev/dl/go1.18.3.linux-arm64.tar.gz"
go_url_armv6="https://go.dev/dl/go1.18.3.linux-armv6l.tar.gz"

gocheck=$(command -v go)
system=$(uname -m)

if [ -z "$gocheck" ]; then
                ## Installing golang
                case $system in
                x86_64)
                wget -O /tmp/golang.tar.gz $go_url_amd64
                        ;;
                x86)
                wget -O /tmp/golang.tar.gz $go_url_x86
                ;;
                arm64)
                wget -O /tmp/golang.tar.gz $go_url_arm64
                ;;
                armv6)
                wget -O /tmp/golang.tar.gz $go_url_armv6
                ;;
                esac

                tar -xvzf /tmp/golang.tar.gz -C /usr/local/
                rm /tmp/golang.tar.gz
                export GOPATH=/usr/local/go
                export GOCACHE=/root/.cache/go-build
                export PATH=$PATH:/usr/local/go/bin/

                echo "Golang Install Done !"
        else
                echo "Go is already installed"
        fi
## Compiling and installing tactical agent from github
        echo "Agent Compile begin"
        wget -O /tmp/rmmagent.zip "https://github.com/amidaware/rmmagent/archive/refs/heads/master.zip"
        unzip /tmp/rmmagent -d /tmp/
        rm /tmp/rmmagent.zip
        cd /tmp/rmmagent-master
        case $system in
        x86_64)
          env CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags "-s -w" -o /tmp/temp_rmmagent
        ;;
        x86)
          env CGO_ENABLED=0 GOOS=linux GOARCH=386 go build -ldflags "-s -w" -o /tmp/temp_rmmagent
        ;;
        arm64)
          env CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -ldflags "-s -w" -o /tmp/temp_rmmagent
        ;;
        armv6)
          env CGO_ENABLED=0 GOOS=linux GOARCH=arm go build -ldflags "-s -w" -o /tmp/temp_rmmagent
        ;;
        esac

        cd /tmp
        rm -R /tmp/rmmagent-master
        cp /tmp/temp_rmmagent ${agentBin}
        chmod +x ${agentBin}
        rm /tmp/temp_rmmagent

MESH_NODE_ID=""

if [[ $NOMESH -eq 1 ]]; then
    echo "Skipping mesh install"
else
    if [ -f "${meshSystemBin}" ]; then
        RemoveMesh
    fi
    echo "Downloading and installing mesh agent..."
    InstallMesh
    sleep 2
    echo "Getting mesh node id..."
    MESH_NODE_ID=$(env XAUTHORITY=foo DISPLAY=bar ${agentBin} -m nixmeshnodeid)
fi

if [ ! -d "${agentBinPath}" ]; then
    echo "Creating ${agentBinPath}"
    mkdir -p ${agentBinPath}
fi
if [ $UPDATE -eq 0 ]; then
    INSTALL_CMD="${agentBin} -m install -api ${apiURL} -client-id ${clientID} -site-id ${siteID} -agent-type ${agentType} -auth ${token}"
else
    MESH_NODE_ID=$(env XAUTHORITY=foo DISPLAY=bar ${agentBin} -m nixmeshnodeid)
    INSTALL_CMD="${agentBin} -m update -api ${apiURL} -client-id ${clientID} -site-id ${siteID} -agent-type ${agentType} -auth ${token}"
fi

if [ "${MESH_NODE_ID}" != '' ]; then
    INSTALL_CMD+=" --meshnodeid ${MESH_NODE_ID}"
fi

if [[ $DEBUG -eq 1 ]]; then
    INSTALL_CMD+=" --log debug"
fi

if [[ $INSECURE -eq 1 ]]; then
    INSTALL_CMD+=" --insecure"
fi

if [ "${proxy}" != '' ]; then
    INSTALL_CMD+=" --proxy ${proxy}"
fi

eval ${INSTALL_CMD}

tacticalsvc="$(
    cat <<EOF
[Unit]
Description=Tactical RMM Linux Agent

[Service]
Type=simple
ExecStart=${agentBin} -m svc
User=root
Group=root
Restart=always
RestartSec=5s
LimitNOFILE=1000000
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
)"
echo "${tacticalsvc}" | tee ${agentSysD} >/dev/null

systemctl daemon-reload
systemctl enable ${agentSvcName}
systemctl start ${agentSvcName}
if [ $UPDATE -eq 1 ]; then
    systemctl restart ${agentSvcName}
fi
