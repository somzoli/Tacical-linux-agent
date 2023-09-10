#!/usr/bin/env bash

if [ $EUID -ne 0 ]; then
    echo "ERROR: Must be run as root"
    exit 1
fi


DEBUG=0
INSECURE=0
NOMESH=0
UPDATE=0

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
agentSvcName='tacticalagent.plist'
agentSysD="/Library/LaunchDaemons/${agentSvcName}"
meshDir='/usr/local/mesh_services/meshagent'
meshSystemBin="${meshDir}/meshagent"


RemoveOldAgent() {
  if [ -f /usr/local/mesh_services/meshagent/meshagent ]; then
    /usr/local/mesh_services/meshagent/meshagent -fulluninstall
  fi

  if [ -f /opt/tacticalmesh/meshagent ]; then
    /opt/tacticalmesh/meshagent -fulluninstall
  fi

  launchctl bootout system /Library/LaunchDaemons/tacticalagent.plist
  rm -rf /usr/local/mesh_services
  rm -rf /opt/tacticalmesh
  rm -f /etc/tacticalagent
  rm -rf /opt/tacticalagent
  rm -f /Library/LaunchDaemons/tacticalagent.plist
}

InstallMesh() {

    meshTmpDir='/tmp/meshtemp'
    mkdir -p $meshTmpDir

    meshTmpBin="${meshTmpDir}/meshagent"
    wget --no-check-certificate -q -O ${meshTmpBin} ${meshDL}
    chmod +x ${meshTmpBin}
    mkdir -p ${meshDir}
    chmod o+X ${meshDir}
    env LC_ALL=en_US.UTF-8 LANGUAGE=en_US XAUTHORITY=foo DISPLAY=bar ${meshTmpBin} -install --installPath=${meshDir}
    sleep 1
    rm -rf ${meshTmpDir}
}
RemoveMesh() {
  if [ -f /usr/local/mesh_services/meshagent/meshagent ]; then
    /usr/local/mesh_services/meshagent/meshagent -fulluninstall
  fi

  if [ -f /opt/tacticalmesh/meshagent ]; then
    /opt/tacticalmesh/meshagent -fulluninstall
  fi
  rm -rf /usr/local/mesh_services
  rm -rf /opt/tacticalmesh

}

Uninstall() {
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


# GO INSTALL
sudo rm -rf /usr/local/go
go_url_amd64="https://go.dev/dl/go1.18.3.darwin-amd64.tar.gz"
go_url_arm64="https://go.dev/dl/go1.18.3.darwin-arm64.tar.gz"

gocheck=$(command -v go)
system=$(uname -m)

if [ -z "$gocheck" ]; then
                ## Installing golang
                case $system in
                x86_64)
                wget -O /tmp/golang.tar.gz $go_url_amd64
                        ;;
                arm64)
                wget -O /tmp/golang.tar.gz $go_url_arm64
                ;;
                esac

                tar -xvzf /tmp/golang.tar.gz -C /usr/local/
                rm /tmp/golang.tar.gz
                export GOPATH=/usr/local/go
                export GOCACHE=/tmp/.cache/go-build
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
          env CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -ldflags "-s -w" -o /tmp/temp_rmmagent
        ;;
        arm64)
          env CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -ldflags "-s -w" -o /tmp/temp_rmmagent
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
